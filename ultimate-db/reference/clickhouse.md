# ClickHouse Reference

Covers ClickHouse 24.x (open-source) and ClickHouse Cloud unless noted.

## Critical constraints

1. **`ORDER BY` is immutable.** It defines the primary index (sparse index on the sort key). You cannot change it after table creation without recreating the table. Plan it before writing any DDL.
2. **Batch inserts only.** Single-row inserts create one part per insert, causing part explosion. Target 10,000--100,000 rows per INSERT; use async inserts for high-frequency small batches.
3. **Avoid mutations.** `ALTER TABLE ... UPDATE` and `ALTER TABLE ... DELETE` are asynchronous, resource-intensive, and block parts. Model to avoid them.

## Schema design

### Column ordering in ORDER BY (primary key)

Order columns **low-to-high cardinality**. The first column determines how well the sparse index prunes granules.

```sql
-- Good: tenant_id (dozens of values) -> event_type (hundreds) -> created_at (unique per row)
CREATE TABLE events (
    tenant_id   UInt32,
    event_type  LowCardinality(String),
    user_id     UInt64,
    payload     String,
    created_at  DateTime64(3, 'UTC')
)
ENGINE = MergeTree()
ORDER BY (tenant_id, event_type, created_at)
PARTITION BY toYYYYMM(created_at);

-- Bad: created_at first -- high cardinality kills index pruning for all other predicates
ORDER BY (created_at, tenant_id, event_type)
```

### Type selection

| Need | Type |
| :--- | :--- |
| Low-cardinality strings (< 10K unique values) | `LowCardinality(String)` -- dictionary encoding, 2-10x compression |
| Enumerations with known set | `Enum8('a'=1, 'b'=2)` or `Enum16(...)` |
| Timestamps | `DateTime64(3, 'UTC')` -- millisecond precision with timezone |
| Booleans | `Bool` (alias for `UInt8`) |
| Exact decimals | `Decimal128(6)` |
| Nullable fields | Avoid `Nullable(T)` -- adds a separate null bitmap column; use a sentinel value instead |
| Arrays | `Array(T)` |
| Nested data | `Nested(col1 T1, col2 T2)` -- stored as parallel arrays |
| JSON (dynamic schema) | `JSON` type (24.1+) or `String` + JSON functions for hot paths |

```sql
-- Prefer DEFAULT over Nullable
CREATE TABLE metrics (
    device_id  UInt64,
    value      Float64,
    label      LowCardinality(String) DEFAULT ''   -- empty string instead of Nullable
) ENGINE = MergeTree() ORDER BY (device_id);
```

### Partitioning

Keep total partition count to 100--1,000. Partitioning by day on a high-volume table creates thousands of parts and degrades merge performance.

```sql
-- Month partition for most event tables
PARTITION BY toYYYYMM(created_at)

-- Partition by both tenant and month for multi-tenant workloads
PARTITION BY (tenant_id, toYYYYMM(created_at))
```

## Table engines

| Engine | Use case |
| :--- | :--- |
| `MergeTree` | General-purpose; baseline for all variants |
| `ReplacingMergeTree(ver)` | Upsert semantics; deduplicates on same ORDER BY key, keeps row with highest `ver` |
| `AggregatingMergeTree` | Pre-aggregate states; used with materialized views |
| `CollapsingMergeTree(sign)` | Update/delete via sign column (+1 insert, -1 cancel) |
| `SummingMergeTree` | Auto-sum numeric columns during background merge |
| `ReplicatedMergeTree` | ClickHouse Keeper-based replication (any engine can be prefixed with `Replicated`) |

```sql
-- ReplacingMergeTree for upsert semantics
CREATE TABLE user_state (
    user_id    UInt64,
    status     LowCardinality(String),
    score      Float32,
    updated_at DateTime64(3, 'UTC')
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (user_id);

-- Query: use FINAL to force deduplication at read time (slower but consistent)
SELECT * FROM user_state FINAL WHERE user_id = 42;
```

## Insert strategy

```sql
-- Batch insert (10K-100K rows per statement)
INSERT INTO events (tenant_id, event_type, user_id, payload, created_at)
VALUES (...), (...), ...;   -- many rows

-- Async inserts: buffer small batches server-side (24.x)
SET async_insert = 1;
SET wait_for_async_insert = 1;   -- wait for acknowledgment before returning
INSERT INTO events ...;           -- can now send small batches; server merges them
```

**Never INSERT one row at a time in a loop.** Each insert creates a new part; background merges cannot keep up, leading to "too many parts" errors (`DB::Exception: Too many parts`).

## Mutation avoidance

```sql
-- BAD: ALTER UPDATE is async and expensive
ALTER TABLE events UPDATE status = 'archived' WHERE created_at < '2023-01-01';

-- GOOD (option 1): ReplacingMergeTree -- reinsert the updated row
INSERT INTO user_state (user_id, status, updated_at) VALUES (42, 'archived', now64());

-- GOOD (option 2): Lightweight DELETE (ClickHouse 22.8+)
DELETE FROM events WHERE tenant_id = 5 AND toYYYYMM(created_at) = 202301;

-- GOOD (option 3): Drop entire partition
ALTER TABLE events DROP PARTITION '202301';
```

## Materialized views

ClickHouse materialized views are insert-triggered -- they process only new data written after creation.

```sql
-- Source table
CREATE TABLE raw_events (...) ENGINE = MergeTree() ORDER BY (tenant_id, created_at);

-- Aggregate target
CREATE TABLE hourly_stats (
    tenant_id  UInt32,
    hour       DateTime,
    event_type LowCardinality(String),
    count      UInt64,
    total_ms   UInt64
) ENGINE = SummingMergeTree()
ORDER BY (tenant_id, hour, event_type);

-- Materialized view wires source to target
CREATE MATERIALIZED VIEW mv_hourly_stats TO hourly_stats AS
SELECT
    tenant_id,
    toStartOfHour(created_at)   AS hour,
    event_type,
    count()                     AS count,
    sum(duration_ms)            AS total_ms
FROM raw_events
GROUP BY tenant_id, hour, event_type;
```

## Query optimization

```sql
-- EXPLAIN: see query plan
EXPLAIN SELECT count() FROM events WHERE tenant_id = 5 AND created_at > now() - INTERVAL 7 DAY;

-- EXPLAIN PIPELINE: see physical execution
EXPLAIN PIPELINE SELECT ...;

-- Key optimization: filters must use ORDER BY prefix columns for index pruning
-- This is efficient (tenant_id is first in ORDER BY):
SELECT count() FROM events WHERE tenant_id = 5;

-- This causes a full scan (skips the primary index):
SELECT count() FROM events WHERE user_id = 99;
-- Fix: add a skipping index
ALTER TABLE events ADD INDEX idx_user_id (user_id) TYPE bloom_filter GRANULARITY 4;

-- JOIN: put smaller table on the right; ClickHouse builds a hash table from the right side
SELECT e.event_type, u.name
FROM events AS e
JOIN (SELECT id, name FROM users WHERE active = 1) AS u ON e.user_id = u.id;

-- Use ANY JOIN when only one matching row is needed per left-side row
SELECT e.*, u.name
FROM events AS e
ANY LEFT JOIN users AS u ON e.user_id = u.id;
```

## Skipping indexes

```sql
-- Bloom filter: probabilistic, good for high-cardinality equality lookups
ALTER TABLE events ADD INDEX idx_user_bloom (user_id) TYPE bloom_filter GRANULARITY 4;

-- Set: exact equality on low-cardinality columns
ALTER TABLE events ADD INDEX idx_status_set (status) TYPE set(100) GRANULARITY 4;

-- MinMax: range queries on numeric columns with local ordering
ALTER TABLE metrics ADD INDEX idx_value_minmax (value) TYPE minmax GRANULARITY 4;
```

## Replication (ClickHouse Keeper)

```sql
-- Replicated engine (Keeper quorum required)
CREATE TABLE events ON CLUSTER '{cluster}' (
    ...
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/events', '{replica}')
ORDER BY (tenant_id, created_at)
PARTITION BY toYYYYMM(created_at);
```

ClickHouse Keeper replaced ZooKeeper as the coordination service in 22.4. Run Keeper on 3 or 5 nodes for quorum.

## Monitoring

```sql
-- Part count per table (high count = insert batching problem)
SELECT database, table, count() AS parts, sum(rows) AS total_rows
FROM system.parts
WHERE active
GROUP BY database, table
ORDER BY parts DESC;

-- Slow queries
SELECT query, query_duration_ms, read_rows, memory_usage
FROM system.query_log
WHERE type = 'QueryFinish' AND query_duration_ms > 1000
ORDER BY query_duration_ms DESC
LIMIT 20;

-- Merge activity
SELECT database, table, elapsed, progress, rows_read, rows_written
FROM system.merges
ORDER BY elapsed DESC;

-- Replication lag
SELECT database, table, replica_name, absolute_delay
FROM system.replicas
WHERE absolute_delay > 10
ORDER BY absolute_delay DESC;
```

## Configuration reference

```xml
<!-- config.xml: key performance settings -->
<max_memory_usage>10000000000</max_memory_usage>        <!-- per-query memory limit: 10 GB -->
<max_bytes_before_external_group_by>5000000000</max_bytes_before_external_group_by>
<max_bytes_before_external_sort>5000000000</max_bytes_before_external_sort>

<!-- background merge threads -->
<background_pool_size>16</background_pool_size>
<background_merges_mutations_concurrency_ratio>2</background_merges_mutations_concurrency_ratio>
```
