# Redmine Slow Query Logger

Minimal Redmine 6 plugin for checking which Redmine user triggers slow requests
and slow SQL queries. It writes normal Rails log lines and keeps a readable
admin journal in the Redmine database.

## Install

Copy this directory to Redmine:

```bash
cp -R redmine_slow_query_logger /path/to/redmine/plugins/
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
touch tmp/restart.txt
```

The plugin creates the `slow_query_logger_entries` table for the readable admin
journal.

## Configuration

Configure through environment variables before starting Redmine:

```bash
REDMINE_SLOW_SQL_MS=500
REDMINE_SLOW_REQUEST_MS=1000
REDMINE_SLOW_SQL_MAX_LENGTH=4000
```

In Redmine, open:

```text
Administration -> Plugins -> Redmine Slow Query Logger -> Configure
```

There you can enable or disable the readable database journal, set how many
entries to keep, configure default thresholds, enable URL parameter masking,
enable SQL literal masking, and open the journal page.

Environment variables override UI settings. This is useful when you need a
temporary production check without saving persistent settings.

For a quick smoke test, force all matching events into the log:

```bash
REDMINE_SLOW_SQL_MS=0
REDMINE_SLOW_REQUEST_MS=0
```

or:

```bash
REDMINE_SLOW_SQL_LOG_ALL=1
REDMINE_SLOW_REQUEST_LOG_ALL=1
```

## What It Logs

Slow SQL log example:

```text
[redmine_slow_query_logger] slow_sql duration_ms=812.4 threshold_ms=500 user_id=12 login="ivan" request_id="..." ip="10.0.0.5" method="GET" path="/issues?... " name="Issue Count" sql="SELECT COUNT(*) ..."
```

Slow request log example:

```text
[redmine_slow_query_logger] slow_request duration_ms=1450.1 threshold_ms=1000 status=200 user_id=12 login="ivan" request_id="..." ip="10.0.0.5" method="GET" path="/issues?..." sql_count=42 slow_sql_count=3 sql_duration_ms=1190.2
```

Readable UI journal:

```text
Administration -> Slow query log
```

or from plugin settings:

```text
Administration -> Plugins -> Redmine Slow Query Logger -> Configure -> Open slow query journal
```

The journal supports filters by event type, login, IP, request id, time range,
minimum duration, and result limit. Clicking a request id filters all entries
from the same Redmine request, which helps connect the slow request summary to
the SQL statements executed inside it.

## Generate DB Load

From Redmine root:

```bash
REDMINE_SLOW_SQL_MS=0 bundle exec rake redmine_slow_query_logger:db_load RAILS_ENV=production USER_ID=1 ITERATIONS=5 PROJECT_LIMIT=1000
```

This runs Redmine/ActiveRecord queries similar to the expensive issue-count
query from the issue list. `USER_ID` is optional, but useful for verifying that
the plugin writes a Redmine user into log lines.

Check:

```bash
tail -f log/production.log
```

Also check the Redmine UI journal. With `REDMINE_SLOW_SQL_MS=0`, the rake task
should create SQL entries immediately.

## Data Accuracy Notes

The plugin records `User.current` at the Redmine application layer. This is
accurate for normal web requests after Redmine authentication has set the
current user. Background jobs, anonymous requests, shared accounts, or custom
API/auth flows can have missing or less precise user attribution. Use
`request_id`, IP, Redmine `production.log`, reverse proxy logs, and DB slow logs
for cross-checking important incidents.

## Sensitive Data

By default, URL parameters with names like `password`, `token`, `key`, `secret`,
`session`, or `cookie` are masked. SQL literals are not masked by default because
keeping exact SQL is often useful during diagnosis; enable `Mask SQL literals`
in plugin settings if SQL may contain sensitive values.
