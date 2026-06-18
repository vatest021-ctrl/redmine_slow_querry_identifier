# Redmine Slow Query Logger

Минимальный плагин для Redmine 6, который помогает понять, какой пользователь
Redmine инициирует медленные web/API-запросы и SQL-запросы. Плагин пишет обычные
строки в Rails-лог и ведет читаемый журнал в базе данных Redmine.

## Установка

Скопируйте или склонируйте плагин в каталог `plugins` Redmine:

```bash
cd /path/to/redmine/plugins
git clone https://github.com/vatest021-ctrl/redmine_slow_querry_identifier.git redmine_slow_query_logger

cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
touch tmp/restart.txt
```

Если Redmine запущен через systemd, Docker или другой процесс-менеджер,
используйте штатный перезапуск сервиса вместо `touch tmp/restart.txt`.

Плагин создает таблицу `slow_query_logger_entries` для читаемого журнала в
админке Redmine.

## Настройка

Откройте в Redmine:

```text
Администрирование -> Плагины -> Redmine Slow Query Logger -> Configure
```

В настройках можно:

- включить или отключить журнал в базе данных;
- задать порог медленного SQL;
- задать порог медленного web/API-запроса;
- задать максимальную длину сохраняемого SQL;
- задать максимальное количество записей журнала;
- включить маскирование чувствительных URL-параметров;
- включить маскирование SQL literals;
- открыть страницу журнала.

Переменные окружения переопределяют настройки из интерфейса. Это удобно для
временной проверки в production без сохранения постоянных настроек:

```bash
REDMINE_SLOW_SQL_MS=500
REDMINE_SLOW_REQUEST_MS=1000
REDMINE_SLOW_SQL_MAX_LENGTH=4000
```

Для короткой smoke-проверки можно временно фиксировать все события:

```bash
REDMINE_SLOW_SQL_MS=0
REDMINE_SLOW_REQUEST_MS=0
```

или:

```bash
REDMINE_SLOW_SQL_LOG_ALL=1
REDMINE_SLOW_REQUEST_LOG_ALL=1
```

Не держите эти значения включенными в production надолго.

## Что фиксирует плагин

Пример строки медленного SQL в `production.log`:

```text
[redmine_slow_query_logger] slow_sql duration_ms=812.4 threshold_ms=500 user_id=12 login="ivan" request_id="..." ip="10.0.0.5" source="api" method="GET" path="/issues.json?..." name="Issue Count" sql="SELECT COUNT(*) ..."
```

Пример строки медленного web/API-запроса:

```text
[redmine_slow_query_logger] slow_request duration_ms=1450.1 threshold_ms=1000 status=200 user_id=12 login="ivan" request_id="..." ip="10.0.0.5" source="portal" method="GET" path="/issues?..." sql_count=42 slow_sql_count=3 sql_duration_ms=1190.2
```

Читаемый журнал доступен здесь:

```text
Администрирование -> Slow query log
```

или из настроек плагина:

```text
Администрирование -> Плагины -> Redmine Slow Query Logger -> Configure -> Open slow query journal
```

Журнал поддерживает фильтры:

- тип события: `request` / `sql`;
- источник: `portal`, `api`, `export`, `feed`, `webhook`, `plugin_endpoint`, `public`, `unknown`;
- логин;
- IP;
- `request_id`;
- период времени;
- минимальная длительность;
- лимит вывода.

Клик по `request_id` показывает события одного Redmine-запроса: сводку
`request` и связанные SQL-события.

## Классификация источников

Классификация эвристическая:

- `portal` - обычные страницы Redmine;
- `api` - `.json`, `.xml`, JSON/XML-запросы;
- `export` - `.csv`, `.pdf`, `.xlsx`, `.xls`;
- `feed` - `.atom`, `.rss`;
- `webhook` - URL содержит `hook`, `hooks`, `webhook`, `webhooks`;
- `plugin_endpoint` - контроллер не входит в базовый список контроллеров Redmine;
- `public` - анонимный HTTP-запрос;
- `unknown` - нет request-контекста.

## Генерация тестовой нагрузки

Из корня Redmine:

```bash
REDMINE_SLOW_SQL_MS=0 bundle exec rake redmine_slow_query_logger:db_load RAILS_ENV=production USER_ID=1 ITERATIONS=5 PROJECT_LIMIT=1000
```

Задача выполняет Redmine/ActiveRecord-запросы, похожие на тяжелый `COUNT(*)`
со страницы списка задач. `USER_ID` необязателен, но полезен для проверки, что
плагин пишет пользователя Redmine в журнал.

Проверить Rails-лог:

```bash
tail -f log/production.log
```

Также проверьте журнал в интерфейсе Redmine. При `REDMINE_SLOW_SQL_MS=0`
rake-задача должна сразу создать SQL-записи.

## Достоверность данных

Плагин фиксирует `User.current` на уровне приложения Redmine.

Это достоверно для обычных web/API-запросов после того, как Redmine установил
текущего пользователя.

Ограничения:

- background/rake-задачи могут не иметь HTTP IP, URL и `request_id`;
- анонимные запросы будут отображаться как `anonymous`;
- общие учетные записи будут отображаться как один общий пользователь;
- кастомные API/auth-плагины могут не установить `User.current`;
- PostgreSQL и pgBadger сами по себе обычно не знают пользователя Redmine.

Для важных инцидентов сверяйте:

- журнал плагина;
- `log/production.log`;
- nginx/apache access log;
- PostgreSQL slow log;
- pgBadger-отчет.

## Чувствительные данные

По умолчанию маскируются URL-параметры с именами вроде:

```text
password, token, key, secret, session, cookie
```

SQL literals по умолчанию не маскируются, потому что точный SQL часто нужен для
диагностики. Если SQL может содержать чувствительные значения, включите
`Mask SQL literals` в настройках плагина.

## PostgreSQL и pgBadger

Для полноценного production-процесса используйте плагин вместе с:

- PostgreSQL `log_min_duration_statement`;
- `pg_stat_activity`;
- pgBadger-отчетами.

Подробная методика описана здесь:

```text
docs/PG_BADGER_INTEGRATION.md
```

Полная инструкция по установке, использованию, проверке и удалению:

```text
docs/INSTALLATION_USAGE_REMOVAL.md
```
