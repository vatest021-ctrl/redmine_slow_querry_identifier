# Установка, использование и удаление плагина

## 1. Назначение

Redmine Slow Query Logger фиксирует медленные web/API-запросы и SQL-запросы
Redmine. В журнале отображаются:

- пользователь Redmine;
- IP клиента;
- источник: портал, API, экспорт, feed, webhook или endpoint плагина;
- URL;
- `request_id`;
- длительность запроса;
- SQL и суммарное время SQL.

Плагин не изменяет задачи, проекты, пользователей и другие основные данные
Redmine. Для журнала используется отдельная таблица
`slow_query_logger_entries`.

## 2. Требования

- Redmine 6.0.x, проверяемая версия: 6.0.5;
- Rails 7.2 из состава Redmine 6;
- доступ к каталогу Redmine и возможность перезапустить приложение;
- резервная копия БД перед изменениями на production.

## 3. Установка из ZIP

Распакуйте архив в каталог `plugins` Redmine. После распаковки должен
существовать файл:

```text
/path/to/redmine/plugins/redmine_slow_query_logger/init.rb
```

Пример:

```bash
cd /path/to/redmine/plugins
unzip /path/to/redmine_slow_query_logger.zip
```

Выполните миграции:

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Перезапустите Redmine штатным способом. Для Passenger можно использовать:

```bash
touch tmp/restart.txt
```

Для systemd или Docker используйте штатную команду перезапуска сервиса или
контейнера.

## 4. Проверка установки

Откройте:

```text
Администрирование -> Плагины
```

В списке должен присутствовать `Redmine Slow Query Logger`.

Затем откройте:

```text
Администрирование -> Плагины -> Redmine Slow Query Logger -> Configure
```

## 5. Рекомендуемые production-настройки

Для фиксации событий дольше одной минуты:

```text
Write readable journal to database = enabled
Slow SQL threshold, ms = 60000
Slow request threshold, ms = 60000
Maximum stored SQL length = 4000
Maximum stored entries = 1000
Mask sensitive URL parameters = enabled
Mask SQL literals = по политике безопасности
```

`60000` мс = 60 секунд.

Не держите в production пороги `0` и переменные:

```text
REDMINE_SLOW_SQL_LOG_ALL=1
REDMINE_SLOW_REQUEST_LOG_ALL=1
```

Они фиксируют слишком много событий и нужны только для короткой проверки.

## 6. Просмотр журнала

Откройте:

```text
Администрирование -> Slow query log
```

Доступны фильтры по:

- типу события `request` / `sql`;
- источнику;
- логину;
- IP;
- `request_id`;
- периоду времени;
- минимальной длительности.

Клик по `request_id` позволяет увидеть сводку HTTP-запроса и связанные SQL.

Дополнительно события записываются в:

```text
/path/to/redmine/log/production.log
```

Просмотр:

```bash
tail -f log/production.log | grep redmine_slow_query_logger
```

## 7. Проверка через портал

Для короткого теста временно установите:

```text
Slow SQL threshold = 0
Slow request threshold = 0
```

Обычным пользователем откройте:

```text
/issues
```

В журнале должны появиться события с:

```text
source = portal
login = логин пользователя
path = /issues...
```

После проверки верните production-пороги.

## 8. Проверка через API

Выполните запрос с действующим API key:

```bash
curl -i \
  -H "X-Redmine-API-Key: ****" \
  "http://REDMINE_HOST/issues.json?limit=100"
```

В журнале должны появиться события с:

```text
source = api
login = владелец API key
path = /issues.json?...
```

Не публикуйте действующие API keys в переписке или диагностических материалах.

## 9. Генерация тестовой нагрузки

Из корня Redmine:

```bash
REDMINE_SLOW_SQL_MS=0 bundle exec rake redmine_slow_query_logger:db_load \
  RAILS_ENV=production USER_ID=1 ITERATIONS=3 PROJECT_LIMIT=100
```

Задача выполняет только читающие запросы `SELECT/COUNT(*)` и не изменяет задачи,
проекты или пользователей.

## 10. Обновление

При установке из Git:

```bash
cd /path/to/redmine/plugins/redmine_slow_query_logger
git pull

cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
touch tmp/restart.txt
```

При обновлении из ZIP замените каталог плагина новой версией, выполните
миграции и перезапустите Redmine.

## 11. Безопасное удаление

Перед удалением сделайте стандартную резервную копию БД.

Сначала откатите миграции плагина:

```bash
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate \
  NAME=redmine_slow_query_logger \
  VERSION=0 \
  RAILS_ENV=production
```

Команда удалит только таблицу `slow_query_logger_entries` и диагностический
журнал плагина. Основные данные Redmine не затрагиваются.

После успешного отката удалите каталог:

```bash
rm -rf /path/to/redmine/plugins/redmine_slow_query_logger
```

Перезапустите Redmine:

```bash
cd /path/to/redmine
touch tmp/restart.txt
```

В таблице `settings` может остаться неиспользуемая запись настроек плагина. Она
не влияет на данные и работу портала.

## 12. Дополнительная диагностика PostgreSQL

Для полноценного контроля рекомендуется использовать плагин вместе с:

- PostgreSQL `log_min_duration_statement`;
- `pg_stat_activity`;
- pgBadger.

Подробная методика:

```text
docs/PG_BADGER_INTEGRATION.md
```
