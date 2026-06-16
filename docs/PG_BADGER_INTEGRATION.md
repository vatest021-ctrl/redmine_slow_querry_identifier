# Связка Redmine Slow Query Logger + PostgreSQL + pgBadger

Документ описывает практическую схему для стенда или production, где:

- Redmine Slow Query Logger определяет пользователя Redmine, IP браузера/API, URL, `request_id` и источник запроса.
- PostgreSQL slow query log независимо от Redmine фиксирует медленные SQL на уровне базы данных.
- pgBadger строит читаемые HTML-отчеты по PostgreSQL-логам.

Цель связки - отвечать на три вопроса:

- кто инициировал нагрузку в Redmine;
- какой SQL был медленным в PostgreSQL;
- как сопоставить события Redmine и PostgreSQL во время инцидента.

## 1. Рекомендуемая архитектура

```text
Пользователь / API / интеграция
        |
        v
HTTP-запрос в Redmine
        |
        | Redmine Slow Query Logger
        | - request_id
        | - user_id / login
        | - IP браузера/API
        | - path
        | - source: portal/api/export/feed/webhook/plugin_endpoint/public/unknown
        v
ActiveRecord SQL
        |
        v
PostgreSQL
        |
        | PostgreSQL slow log
        | - pid
        | - пользователь БД
        | - IP клиента БД
        | - application_name
        | - медленный SQL
        v
HTML-отчет pgBadger
```

Redmine и PostgreSQL видят разные идентификаторы:

- Redmine видит реального пользователя Redmine и HTTP IP клиента.
- PostgreSQL обычно видит только DB-пользователя Redmine и IP сервера Redmine.

Лучший ключ для сопоставления событий - `request_id`.

## 2. Настройки плагина

Для production-мониторинга только очень медленных событий:

```text
Write readable journal to database = enabled
Slow SQL threshold, ms = 60000
Slow request threshold, ms = 60000
Maximum stored SQL length = 4000
Maximum stored entries = 1000
Mask sensitive URL parameters = enabled
Mask SQL literals = disabled или enabled по политике безопасности
```

`60000` мс = 60 секунд.

Не используйте долго в production:

```text
REDMINE_SLOW_SQL_LOG_ALL=1
REDMINE_SLOW_REQUEST_LOG_ALL=1
Slow SQL threshold = 0
Slow request threshold = 0
```

Эти настройки нужны только для короткой smoke-проверки.

## 3. PostgreSQL slow log

Включите логирование SQL дольше 60 секунд.

Выполнить от PostgreSQL superuser:

```sql
ALTER SYSTEM SET log_min_duration_statement = '60000';
ALTER SYSTEM SET log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%h ';
SELECT pg_reload_conf();
```

Проверить текущие настройки логирования:

```sql
SHOW log_min_duration_statement;
SHOW log_line_prefix;
SHOW logging_collector;
SHOW log_directory;
SHOW log_filename;
```

Типичные расположения логов:

```text
/var/log/postgresql/postgresql-*.log
```

или каталог внутри PostgreSQL data directory. Это зависит от установки.

## 4. Установка pgBadger

Пример для Debian/Ubuntu:

```bash
apt-get update
apt-get install pgbadger
```

Если пакета нет в репозитории ОС, установите pgBadger из официальной поставки
для вашей системы.

## 5. Генерация отчета pgBadger

Пример:

```bash
pgbadger \
  /var/log/postgresql/postgresql-*.log \
  -o /var/www/html/pgbadger-redmine.html
```

Отчет за конкретный период:

```bash
pgbadger \
  --begin "2026-06-16 10:00:00" \
  --end "2026-06-16 14:00:00" \
  /var/log/postgresql/postgresql-*.log \
  -o /var/www/html/pgbadger-redmine-2026-06-16.html
```

Ограничьте доступ к HTML-отчету. PostgreSQL-логи могут содержать чувствительный
SQL и данные.

## 6. Сценарии сопоставления событий

### 6.1. От журнала Redmine к PostgreSQL / pgBadger

1. Открыть:

   ```text
   Администрирование -> Slow query log
   ```

2. Найти медленное событие.

3. Записать:

   ```text
   Time
   request_id
   login
   user_id
   source
   path
   SQL text
   ```

4. Открыть pgBadger-отчет за тот же период.

5. Искать по:

   ```text
   фрагменту SQL
   имени таблицы
   времени события
   pid/временному окну
   ```

6. Журнал Redmine использовать для прикладной атрибуции:

   ```text
   login + source + path + HTTP IP
   ```

7. pgBadger использовать как доказательство на уровне БД:

   ```text
   slow SQL + total time + frequency + DB client + app name
   ```

### 6.2. От pgBadger к журналу Redmine

1. Найти медленный SQL в pgBadger.
2. Записать время и фрагмент SQL.
3. Открыть журнал Redmine Slow Query Logger.
4. Отфильтровать события по периоду и источнику, если источник понятен.
5. Визуально найти совпадающий SQL или URL.
6. Через `request_id` открыть полную группу событий одного Redmine-запроса.

## 7. Возможная усиленная интеграция через PostgreSQL `application_name`

Наиболее чистая будущая интеграция - выставлять PostgreSQL `application_name`
на время Redmine-запроса.

Желаемый формат:

```text
redmine rid=<request_id> uid=<user_id> src=<source>
```

Тогда PostgreSQL log line будет содержать:

```text
app=redmine rid=... uid=... src=api
```

В этом случае pgBadger сможет показывать application context из PostgreSQL-лога,
а журнал плагина сможет раскрыть `request_id` в подробности:

```text
login
HTTP IP
path
source
SQL events
```

Важные требования к реализации:

- выставлять `application_name` в начале Redmine-запроса;
- сбрасывать значение в конце запроса;
- не записывать длинный URL в `application_name`;
- использовать только короткие очищенные поля: `request_id`, `user_id`, `source`;
- учитывать connection pool, чтобы контекст одного запроса не протекал в следующий.

В текущей версии плагина это намеренно не включено по умолчанию. Текущий плагин
безопасен с точки зрения PostgreSQL session settings и не меняет их.

## 8. Просмотр активных запросов и ручная отмена

PostgreSQL может показать запросы, выполняющиеся прямо сейчас:

```sql
SELECT
  pid,
  now() - query_start AS duration,
  usename,
  datname,
  application_name,
  client_addr,
  state,
  wait_event_type,
  wait_event,
  query
FROM pg_stat_activity
WHERE state <> 'idle'
  AND now() - query_start > interval '60 seconds'
ORDER BY query_start;
```

Мягкая отмена SQL:

```sql
SELECT pg_cancel_backend(<pid>);
```

Жесткое завершение backend-соединения:

```sql
SELECT pg_terminate_backend(<pid>);
```

Сначала используйте `pg_cancel_backend`. `pg_terminate_backend` применяйте
только если отмена не сработала и операционный риск приемлем.

## 9. Рекомендуемый порядок эксплуатации

### Обычный режим

Плагин Redmine:

```text
Slow SQL threshold = 60000
Slow request threshold = 60000
Maximum stored entries = 1000
```

PostgreSQL:

```text
log_min_duration_statement = 60000
```

pgBadger:

```text
ежедневный отчет или отчет по требованию во время инцидента
```

### Режим инцидента

1. Проверить активные DB-запросы через `pg_stat_activity`.
2. При необходимости отменить запрос через `pg_cancel_backend(pid)`.
3. Открыть журнал Redmine и отфильтровать по времени/source/user.
4. Сгенерировать pgBadger-отчет за окно инцидента.
5. Сопоставить Redmine user/path/source с PostgreSQL slow SQL.

### Короткая smoke-проверка

Временно поставить:

```text
Slow SQL threshold = 0
Slow request threshold = 0
```

Затем открыть `/issues` в портале и выполнить API-запрос:

```bash
curl -i \
  -H "X-Redmine-API-Key: ****" \
  "http://REDMINE_HOST/issues.json?set_filter=1&status_id=*&limit=100"
```

Проверить в журнале:

```text
source = portal
source = api
request_id связывает request и SQL-события
```

После проверки сразу вернуть production-пороги.

## 10. Ограничения

Ограничения Redmine-плагина:

- не видит SQL, выполненный напрямую в PostgreSQL вне Redmine;
- background/rake-задачи могут не иметь HTTP IP, path и `request_id`;
- API-атрибуция зависит от того, корректно ли Redmine устанавливает `User.current`.

Ограничения PostgreSQL / pgBadger:

- по умолчанию не знают пользователя Redmine;
- обычно видят только пользователя БД, например `redmine`;
- обычно видят IP сервера Redmine, а не IP браузера/API-клиента.

Поэтому рекомендованная схема - комбинация:

```text
Redmine Slow Query Logger для прикладной атрибуции
PostgreSQL slow log для истины на уровне БД
pgBadger для читаемых DB-отчетов
pg_stat_activity для оперативного управления активными запросами
```
