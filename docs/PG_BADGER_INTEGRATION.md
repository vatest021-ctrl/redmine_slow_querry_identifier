# Redmine Slow Query Logger + PostgreSQL + pgBadger

This document describes a practical production/staging setup where:

- Redmine Slow Query Logger identifies the Redmine user, browser/API IP, URL, request id, and source.
- PostgreSQL slow query log records database-level slow SQL independently from Redmine.
- pgBadger builds readable reports from PostgreSQL logs.

The goal is to answer three questions:

- Who initiated the load in Redmine?
- Which SQL was slow in PostgreSQL?
- How can the events be correlated during an incident?

## 1. Recommended Architecture

```text
User / API / integration
        |
        v
Redmine HTTP request
        |
        | Redmine Slow Query Logger
        | - request_id
        | - user_id / login
        | - browser/API IP
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
        | - DB user
        | - DB client IP
        | - application_name
        | - slow SQL
        v
pgBadger HTML report
```

Redmine and PostgreSQL see different identities:

- Redmine sees the real Redmine user and the HTTP client IP.
- PostgreSQL usually sees only the Redmine DB user and the Redmine server IP.

The best correlation key is `request_id`.

## 2. Plugin Settings

For production monitoring of only very slow events:

```text
Write readable journal to database = enabled
Slow SQL threshold, ms = 60000
Slow request threshold, ms = 60000
Maximum stored SQL length = 4000
Maximum stored entries = 1000
Mask sensitive URL parameters = enabled
Mask SQL literals = disabled or enabled according to your security policy
```

`60000` ms means 60 seconds.

Avoid long-term production use of:

```text
REDMINE_SLOW_SQL_LOG_ALL=1
REDMINE_SLOW_REQUEST_LOG_ALL=1
Slow SQL threshold = 0
Slow request threshold = 0
```

These settings are useful only for short smoke tests.

## 3. PostgreSQL Slow Log

Enable PostgreSQL logging for SQL longer than 60 seconds.

Run as a PostgreSQL superuser:

```sql
ALTER SYSTEM SET log_min_duration_statement = '60000';
ALTER SYSTEM SET log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%h ';
SELECT pg_reload_conf();
```

Check current log settings:

```sql
SHOW log_min_duration_statement;
SHOW log_line_prefix;
SHOW logging_collector;
SHOW log_directory;
SHOW log_filename;
```

Typical log locations:

```text
/var/log/postgresql/postgresql-*.log
```

or inside the PostgreSQL data directory, depending on your installation.

## 4. pgBadger Installation

Debian/Ubuntu example:

```bash
apt-get update
apt-get install pgbadger
```

If packages are unavailable, install from the official pgBadger distribution
for your OS.

## 5. Generate a pgBadger Report

Example:

```bash
pgbadger \
  /var/log/postgresql/postgresql-*.log \
  -o /var/www/html/pgbadger-redmine.html
```

For a specific period:

```bash
pgbadger \
  --begin "2026-06-16 10:00:00" \
  --end "2026-06-16 14:00:00" \
  /var/log/postgresql/postgresql-*.log \
  -o /var/www/html/pgbadger-redmine-2026-06-16.html
```

Make sure access to the generated report is restricted. PostgreSQL logs can
contain sensitive SQL and data.

## 6. Correlation Workflow

### 6.1. From Redmine Journal to PostgreSQL / pgBadger

1. Open:

   ```text
   Administration -> Slow query log
   ```

2. Find a slow event.

3. Note:

   ```text
   Time
   request_id
   login
   user_id
   source
   path
   SQL text
   ```

4. Open pgBadger report for the same time range.

5. Search by:

   ```text
   SQL fragment
   table name
   timestamp
   pid/time window
   ```

6. Use Redmine journal for the human/application attribution:

   ```text
   login + source + path + HTTP IP
   ```

7. Use pgBadger for database evidence:

   ```text
   slow SQL + total time + frequency + DB client + app name
   ```

### 6.2. From pgBadger to Redmine Journal

1. Find the slow SQL in pgBadger.
2. Note timestamp and SQL fragment.
3. Open Redmine slow query journal.
4. Filter by time range and source if known.
5. Search visually for the SQL fragment or matching path.
6. Use `request_id` to view the full Redmine request group.

## 7. Optional Stronger Integration: PostgreSQL `application_name`

The cleanest future integration is to set PostgreSQL `application_name` per
Redmine request.

Desired value:

```text
redmine rid=<request_id> uid=<user_id> src=<source>
```

Then PostgreSQL log lines include:

```text
app=redmine rid=... uid=... src=api
```

With this, pgBadger can show the application context from PostgreSQL logs, while
the plugin journal can expand `request_id` into:

```text
login
HTTP IP
path
source
SQL events
```

Implementation notes:

- Set `application_name` at the start of a Redmine request.
- Reset it at the end of the request.
- Do not store long URLs in `application_name`.
- Use only short, sanitized fields: `request_id`, `user_id`, `source`.
- Be careful with DB connection pools: context must not leak to the next request.

This is intentionally not enabled by default in the current plugin version.
The current plugin is safe and read-only from the perspective of PostgreSQL
session settings.

## 8. Active Query Inspection and Manual Cancel

PostgreSQL can show currently running queries:

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

Soft cancel:

```sql
SELECT pg_cancel_backend(<pid>);
```

Hard terminate:

```sql
SELECT pg_terminate_backend(<pid>);
```

Use `pg_cancel_backend` first. Use `pg_terminate_backend` only when cancellation
does not work and the operational impact is acceptable.

## 9. Suggested Operational Procedure

### Normal Mode

Redmine plugin:

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
daily report or on-demand incident report
```

### Incident Mode

1. Check active DB queries with `pg_stat_activity`.
2. If needed, cancel a query with `pg_cancel_backend(pid)`.
3. Open Redmine slow query journal and filter by time/source/user.
4. Generate pgBadger report for the incident window.
5. Correlate Redmine user/path/source with PostgreSQL slow SQL.

### Short Smoke Test

Temporarily use:

```text
Slow SQL threshold = 0
Slow request threshold = 0
```

Then open `/issues` in the portal and run an API request:

```bash
curl -i \
  -H "X-Redmine-API-Key: ****" \
  "http://REDMINE_HOST/issues.json?set_filter=1&status_id=*&limit=100"
```

Verify in the journal:

```text
source = portal
source = api
request_id links request and SQL events
```

Return thresholds to production values immediately after testing.

## 10. Limitations

Redmine plugin limitations:

- Does not see SQL executed directly against PostgreSQL outside Redmine.
- Background/rake jobs may not have HTTP IP, path, or request id.
- API attribution depends on Redmine setting `User.current` correctly.

PostgreSQL / pgBadger limitations:

- Does not know the Redmine user by default.
- Usually sees only the DB user, for example `redmine`.
- Usually sees the Redmine server IP, not the browser/API client IP.

Therefore the recommended setup is a combination:

```text
Redmine Slow Query Logger for attribution
PostgreSQL slow log for database truth
pgBadger for readable DB reports
pg_stat_activity for live operational control
```

