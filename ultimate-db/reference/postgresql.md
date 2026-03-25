# PostgreSQL Reference

Covers PostgreSQL 15+ unless noted. Skew toward production workloads.

## Schema

### Types

- `TEXT` over `VARCHAR(n)` -- same storage, no length overhead unless the constraint is intentional.
- `TIMESTAMPTZ` always. Bare `TIMESTAMP` silently drops timezone; this causes incorrect ordering across DST boundaries.
- `NUMERIC(p,s)` / `DECIMAL` for money. Never `FLOAT` or `DOUBLE PRECISION`.
- `UUID` native type with `gen_random_uuid()` (pg 13+, no extension needed).
- `CITEXT` extension or `lower(col)` expression index for case-insensitive text; avoid `ILIKE` on unindexed columns.
- `JSONB` for semi-structured data. Plain `JSON` stores the raw string and re-parses on every access -- avoid.

### Constraints and domains

```sql
-- Reusable domain with validation
CREATE DOMAIN positive_amount AS NUMERIC(18,6) CHECK (VALUE > 0);

-- Enum type
CREATE TYPE order_status AS ENUM ('pending', 'processing', 'shipped', 'cancelled');

-- Table-level temporal constraint
ALTER TABLE orders
    ADD CONSTRAINT chk_shipped_after_created
    CHECK (shipped_at IS NULL OR shipped_at >= created_at);
```

### Partitioning

Use for data lifecycle (DROP PARTITION instead of DELETE), not as an index substitute.

```sql
CREATE TABLE events (
    id         BIGSERIAL,
    event_type TEXT NOT NULL,
    user_id    BIGINT NOT NULL,
    payload    JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

CREATE TABLE events_2025_01 PARTITION OF events
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

-- Lifecycle: detach then drop (non-blocking detach in PG 14+)
ALTER TABLE events DETACH PARTITION events_2024_01 CONCURRENTLY;
DROP TABLE events_2024_01;
```

## Indexing

### Index types

| Type | Use case |
| :--- | :--- |
| B-tree (default) | Equality, range, sort, `IS NULL` |
| GIN | JSONB containment/existence, arrays, `tsvector` (FTS) |
| GiST | Geometric data, ranges, nearest-neighbor, PostGIS |
| BRIN | Very large append-only tables with natural physical ordering |
| Hash | Pure equality on large non-sortable keys (rare; not WAL-safe pre-PG10) |
| SP-GiST | IP ranges, quad-trees, radix trees |

### Common index patterns

```sql
-- Partial: only index the rows that matter
CREATE INDEX idx_orders_pending ON orders (created_at)
WHERE status = 'pending';

-- Expression: case-insensitive email
CREATE INDEX idx_users_email_lower ON users (lower(email));

-- Covering: satisfy query from index alone
CREATE INDEX idx_orders_covering ON orders (user_id, status)
INCLUDE (total, created_at);

-- GIN: JSONB containment
CREATE INDEX idx_events_payload ON events USING gin(payload jsonb_path_ops);

-- GIN: full-text search
CREATE INDEX idx_articles_fts ON articles USING gin(search_vec);

-- BRIN: time-series table with natural insert order
CREATE INDEX idx_logs_ts_brin ON logs USING brin(created_at);

-- Always use CONCURRENTLY in production to avoid table lock
CREATE INDEX CONCURRENTLY idx_users_email ON users (lower(email));
```

### Monitoring

```sql
-- Unused indexes (review before dropping)
SELECT schemaname, tablename, indexname, idx_scan,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- Table bloat (dead tuple ratio)
SELECT schemaname, tablename, n_dead_tup, n_live_tup,
       round(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
```

## Query optimization

### EXPLAIN

Always use `EXPLAIN (ANALYZE, BUFFERS)` -- plain `EXPLAIN` shows estimates only, not actuals.

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.name, COUNT(o.id)
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE u.created_at > '2024-01-01'
GROUP BY u.id, u.name;
```

**Signals to act on:**

| Signal | Cause | Fix |
| :--- | :--- | :--- |
| `Seq Scan` on large table | Missing index | Add index |
| Estimated rows far from actual | Stale statistics | `ANALYZE table` |
| `Shared Blks Read` >> `Shared Blks Hit` | Data not cached | Increase `shared_buffers`; check query |
| `Sort Method: external merge` | `work_mem` too low | Raise `work_mem` for session/query |
| `Hash Batches > 1` | Hash join spilling to disk | Increase `work_mem` |

### Pagination

```sql
-- Avoid: OFFSET scans from the start every time
SELECT * FROM products ORDER BY id OFFSET 100000 LIMIT 20;

-- Use: keyset (cursor) pagination
SELECT * FROM products
WHERE id > $last_id
ORDER BY id
LIMIT 20;
```

### CTEs and lateral joins

```sql
-- Recursive CTE for hierarchical data
WITH RECURSIVE category_tree AS (
    SELECT id, name, parent_id, 1 AS depth
    FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.id, c.name, c.parent_id, ct.depth + 1
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree ORDER BY depth, name;

-- LATERAL for per-row subquery
SELECT u.id, u.name, latest.created_at AS last_order
FROM users u
LEFT JOIN LATERAL (
    SELECT created_at FROM orders
    WHERE user_id = u.id
    ORDER BY created_at DESC
    LIMIT 1
) latest ON true;
```

## JSONB

```sql
-- Containment (uses GIN jsonb_path_ops index)
SELECT * FROM events WHERE payload @> '{"status": "active"}';

-- Key existence
SELECT * FROM events WHERE payload ? 'user_id';

-- Nested path
SELECT * FROM events WHERE payload -> 'user' ->> 'role' = 'admin';

-- JSONB aggregation
SELECT jsonb_agg(payload) FROM events WHERE payload ? 'order_id';

-- Build object on the fly
SELECT jsonb_build_object('id', id, 'name', name) FROM users;
```

## Full-text search

```sql
-- Generated tsvector column (PG 12+, auto-updated)
ALTER TABLE articles ADD COLUMN search_vec tsvector
    GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
    ) STORED;

CREATE INDEX idx_articles_fts ON articles USING gin(search_vec);

-- Search with ranking and highlighted snippet
SELECT title,
       ts_rank(search_vec, q)             AS rank,
       ts_headline('english', body, q)    AS snippet
FROM articles, to_tsquery('english', 'database & indexing') q
WHERE search_vec @@ q
ORDER BY rank DESC;
```

## MVCC and VACUUM

PostgreSQL's MVCC creates a new row version on every UPDATE. Dead tuples accumulate until VACUUM reclaims them.

```sql
-- Manual VACUUM (non-blocking)
VACUUM ANALYZE orders;

-- VACUUM FULL rewrites the file and takes ACCESS EXCLUSIVE lock.
-- Prefer pg_repack in production to avoid downtime.

-- Transaction ID wraparound: monitor proximity to the 2-billion limit
SELECT datname, age(datfrozenxid) AS xid_age
FROM pg_database
ORDER BY xid_age DESC;
-- If age approaches ~1.5 billion, run: VACUUM FREEZE
```

**Autovacuum tuning knobs (postgresql.conf):**

```ini
autovacuum_max_workers = 5
autovacuum_vacuum_scale_factor = 0.01   # trigger at 1% dead tuples (default 20%)
autovacuum_analyze_scale_factor = 0.005
autovacuum_vacuum_cost_delay = 2ms      # reduce throttling on fast storage
```

## Row Level Security

```sql
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON documents
    FOR ALL TO app_role
    USING (tenant_id = current_setting('app.tenant_id')::INT);

-- Force RLS even for table owner
ALTER TABLE documents FORCE ROW LEVEL SECURITY;
```

## Replication

### Streaming (physical)

```ini
# postgresql.conf on primary
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
synchronous_commit = on          # set to 'remote_write' or 'off' for async
```

```sql
-- Replication lag (on primary)
SELECT client_addr, state, sync_state, write_lag, replay_lag
FROM pg_stat_replication;

-- Replication lag (on standby)
SELECT now() - pg_last_xact_replay_timestamp() AS lag;
```

**Failover:** Patroni is the community standard. repmgr and pg_auto_failover are lighter alternatives.

### Logical replication

```sql
-- Publisher (primary)
CREATE PUBLICATION app_pub FOR TABLE users, orders;

-- Subscriber (target, can be a different major version)
CREATE SUBSCRIPTION app_sub
    CONNECTION 'host=primary dbname=mydb user=replicator password=...'
    PUBLICATION app_pub;
```

Use for cross-version major upgrades, selective table sync, CDC pipelines feeding Debezium or pgoutput consumers.

## Connection pooling

Direct PostgreSQL connections are expensive (each spawns a backend process). Always pool in production.

| Pooler | Recommended mode | Notes |
| :--- | :--- | :--- |
| PgBouncer | transaction | Works for most web apps; incompatible with `SET` session vars and named prepared statements |
| PgBouncer | session | Required when using prepared statements or per-session `SET` |
| PgPool-II | -- | Adds load balancing and read/write splitting; heavier operationally |

```ini
# PgBouncer pgbouncer.ini
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
server_idle_timeout = 600
```

## Monitoring

```sql
-- Enable query statistics (add to shared_preload_libraries, then restart)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Top 10 queries by cumulative time
SELECT query, calls, total_exec_time, mean_exec_time, rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Long-running active queries
SELECT pid, now() - query_start AS duration, state, query
FROM pg_stat_activity
WHERE state != 'idle'
  AND query NOT LIKE '%pg_stat_activity%'
ORDER BY duration DESC;

-- Blocking queries
SELECT blocked.pid,
       blocked.query              AS blocked_query,
       blocking.pid               AS blocking_pid,
       blocking.query             AS blocking_query
FROM pg_stat_activity AS blocked
JOIN pg_stat_activity AS blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid));
```

## Zero-downtime migrations

```sql
-- 1. Add column nullable first (instant, no rewrite)
ALTER TABLE users ADD COLUMN verified BOOLEAN;

-- 2. Backfill in bounded batches (avoid one giant UPDATE)
UPDATE users SET verified = false
WHERE verified IS NULL AND id BETWEEN $start AND $end;

-- 3. Set NOT NULL after full backfill
ALTER TABLE users ALTER COLUMN verified SET NOT NULL;

-- 4. Index without locking
CREATE INDEX CONCURRENTLY idx_users_verified ON users (verified);

-- 5. Drop old column when safe
ALTER TABLE users DROP COLUMN legacy_col;
-- In PG 11+, dropping a column is a catalog change only (no rewrite).
```

## Useful extensions

| Extension | Purpose |
| :--- | :--- |
| `pg_stat_statements` | Query performance tracking |
| `pg_trgm` | Trigram similarity, `LIKE '%...%'` with GIN/GiST index |
| `uuid-ossp` / built-in `gen_random_uuid()` | UUID generation |
| `pgcrypto` | Password hashing (`crypt`, `gen_salt`) |
| `postgis` | Geospatial types and functions |
| `pg_partman` | Automated partition management |
| `citext` | Case-insensitive text type |
| `unaccent` | Strip accents for search normalization |
