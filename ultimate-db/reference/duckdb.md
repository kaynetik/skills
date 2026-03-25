# DuckDB Reference

Covers DuckDB 1.x unless noted. DuckDB is an in-process, columnar OLAP database. It runs embedded in Python, R, Node.js, Rust, Go, Java, and as a CLI -- no server required.

## When to use DuckDB

- **Local analytics** -- query Parquet, CSV, JSON, Arrow, and Iceberg files directly without loading them.
- **ETL and data pipelines** -- transform and aggregate data faster than pandas/polars for most workloads.
- **Replacing heavy analytics servers** -- many BI-tier queries that previously required Redshift or BigQuery run locally in DuckDB.
- **Notebook and exploratory analysis** -- low setup, high throughput.
- **Test environment for OLAP queries** -- develop against local files, deploy to MotherDuck or another server.

**Avoid DuckDB when:** you need high-concurrency writes from multiple processes, OLTP workloads (row-level updates), or multi-user concurrent access to the same database file. DuckDB is optimized for analytical reads.

## Core concepts

DuckDB is columnar, vectorized, and SIMD-accelerated. It scans columns, not rows. Queries that touch few columns on large tables are fast; queries that touch many columns per row are less advantaged.

**Multi-version concurrency:** one writer and multiple readers can coexist. Multiple simultaneous writers are not supported on the same file.

## Querying files directly

DuckDB can query files without importing them. This is one of its most valuable features.

```sql
-- Parquet (single file or glob)
SELECT * FROM 'data/events.parquet' LIMIT 10;
SELECT count(*), event_type FROM 'data/events/*.parquet' GROUP BY event_type;

-- CSV (auto-detects delimiter, types, and headers)
SELECT * FROM read_csv_auto('data/users.csv');

-- JSON
SELECT * FROM read_json_auto('data/records.jsonl');

-- Remote (HTTP or S3)
SELECT * FROM 'https://example.com/data.parquet';
SELECT * FROM 's3://my-bucket/data/*.parquet';   -- requires httpfs extension

-- Iceberg (via iceberg extension)
SELECT * FROM iceberg_scan('s3://bucket/warehouse/table');
```

## Schema and types

DuckDB supports the full SQL type system:

| Type | Notes |
| :--- | :--- |
| `BIGINT`, `INTEGER`, `HUGEINT` | Integer sizes up to 128-bit |
| `DOUBLE`, `FLOAT` | IEEE 754 |
| `DECIMAL(p,s)` | Exact; use for money |
| `VARCHAR` | Unlimited length, UTF-8 |
| `TIMESTAMP WITH TIME ZONE` | Stored as UTC |
| `DATE`, `TIME`, `INTERVAL` | Native temporal types |
| `BOOLEAN` | Native |
| `BLOB` | Binary |
| `STRUCT(field TYPE, ...)` | Named nested record |
| `LIST(T)` / `T[]` | Variable-length array |
| `MAP(K, V)` | Key-value map |
| `UNION(name T, ...)` | Tagged union (1.0+) |
| `JSON` | Stored as `VARCHAR`; use `json_extract` / arrow syntax |

```sql
-- Struct and list columns
SELECT
    {'name': 'Alice', 'age': 30}          AS person,
    [1, 2, 3, 4]                          AS values,
    {'a': 1, 'b': 2}::MAP(VARCHAR, INT)  AS kv;
```

## SQL extensions

DuckDB extends standard SQL significantly.

### Positional and column list shortcuts

```sql
-- GROUP BY position
SELECT event_type, count(*) FROM events GROUP BY 1;

-- Wildcard EXCEPT / REPLACE
SELECT * EXCLUDE (password, ssn) FROM users;
SELECT * REPLACE (lower(email) AS email) FROM users;

-- COLUMNS expression (select all matching a pattern)
SELECT COLUMNS('amount.*') FROM orders;
```

### PIVOT and UNPIVOT

```sql
-- PIVOT: rows to columns
PIVOT orders ON status USING sum(amount) GROUP BY user_id;

-- UNPIVOT: columns to rows
UNPIVOT wide_table ON (jan, feb, mar) INTO NAME month VALUE amount;
```

### Sampling

```sql
-- Random 1% sample (Bernoulli method)
SELECT * FROM events USING SAMPLE 1%;

-- Fixed row count
SELECT * FROM events USING SAMPLE 10000 ROWS;
```

### Window functions (fully supported)

```sql
SELECT
    event_type,
    created_at,
    count() OVER (PARTITION BY event_type ORDER BY created_at
                  RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW) AS rolling_1h,
    lag(created_at, 1) OVER (PARTITION BY event_type ORDER BY created_at) AS prev_event_time
FROM events;
```

### Asof join

Match each row to the nearest row by time, useful for time-series data:

```sql
-- Match each trade to the most recent price quote before the trade time
SELECT t.*, q.price
FROM trades t
ASOF JOIN quotes q ON t.symbol = q.symbol AND t.ts >= q.ts;
```

## Parquet integration

```sql
-- Write query result to Parquet
COPY (SELECT * FROM events WHERE event_type = 'purchase')
TO 'output/purchases.parquet' (FORMAT PARQUET, COMPRESSION ZSTD);

-- Write partitioned Parquet (Hive-style directory layout)
COPY events TO 'output/' (FORMAT PARQUET, PARTITION_BY (event_type, year));

-- Read with predicate pushdown (DuckDB pushes WHERE filters into Parquet row groups)
SELECT count(*) FROM 'events.parquet' WHERE event_type = 'purchase' AND year = 2025;
```

## Extensions

```sql
-- Load extensions (auto-downloaded on first use)
INSTALL httpfs;   LOAD httpfs;     -- S3, GCS, HTTP file access
INSTALL iceberg;  LOAD iceberg;    -- Apache Iceberg tables
INSTALL delta;    LOAD delta;      -- Delta Lake tables
INSTALL spatial;  LOAD spatial;    -- GeoPandas-compatible geospatial functions
INSTALL json;     LOAD json;       -- additional JSON functions (bundled by default in 1.x)

-- Configure S3 credentials
SET s3_region = 'us-east-1';
CREATE SECRET (TYPE S3, KEY_ID '...', SECRET '...', REGION 'us-east-1');
```

## Python integration

```python
import duckdb

# In-memory database (default)
con = duckdb.connect()

# Persistent database file
con = duckdb.connect("analytics.db")

# Query a pandas DataFrame directly (zero-copy via Arrow)
import pandas as pd
df = pd.read_parquet("events.parquet")
result = con.execute("SELECT event_type, count(*) FROM df GROUP BY 1").df()

# Polars integration
import polars as pl
lf = pl.scan_parquet("events.parquet")
result = con.execute("SELECT * FROM lf WHERE event_type = 'login'").pl()

# Parameterized queries
con.execute("SELECT * FROM users WHERE id = ?", [42]).fetchall()
```

## Performance

DuckDB parallelizes automatically across all available CPU cores. Configuration is minimal.

```sql
-- Control thread count (default: all cores)
SET threads = 8;

-- Memory limit
SET memory_limit = '16GB';

-- Temporary directory for spilling large sorts/joins
SET temp_directory = '/fast-ssd/duckdb-tmp';

-- Check current settings
SELECT * FROM duckdb_settings() WHERE name LIKE '%thread%' OR name LIKE '%memory%';
```

**Performance tips:**
- Read Parquet/Arrow instead of CSV -- column pruning and predicate pushdown work on columnar formats.
- Filter early in the query; DuckDB pushes predicates into file scans.
- Use `ZSTD` compression for Parquet output -- smaller files, fast decompression.
- For repeated queries on the same file, load into a DuckDB table: `CREATE TABLE t AS SELECT * FROM 'file.parquet'`.

## MotherDuck (serverless DuckDB cloud)

```python
import duckdb

# Connect to MotherDuck (requires MOTHERDUCK_TOKEN env var or token param)
con = duckdb.connect("md:my_database")

# Hybrid execution: local files joined to cloud tables
con.execute("""
    SELECT l.*, r.name
    FROM 'local_events.parquet' l
    JOIN my_database.users r ON l.user_id = r.id
""").df()
```

## Useful introspection

```sql
-- Show all tables in the database
SHOW TABLES;
SHOW ALL TABLES;   -- includes attached databases

-- Describe table schema
DESCRIBE events;
PRAGMA table_info('events');

-- Query plan
EXPLAIN SELECT count(*) FROM events WHERE event_type = 'login';
EXPLAIN ANALYZE SELECT ...;   -- run the query and show actual row counts

-- Profile query execution (detailed timing per operator)
PRAGMA enable_profiling;
SELECT ...;
PRAGMA disable_profiling;
```
