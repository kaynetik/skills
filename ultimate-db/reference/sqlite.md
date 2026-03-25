# SQLite Reference

Covers SQLite 3.37+ unless noted. SQLite is an embedded, serverless, single-file database. It excels at local-first applications, mobile apps, CLI tools, edge functions, and test environments.

## When to use SQLite

- **Local-first and offline-capable applications** -- data lives on the device.
- **Edge computing** -- Cloudflare D1, Turso (libSQL), Fly.io LiteFS.
- **Embedded databases in desktop apps and CLI tools** -- no daemon, no install.
- **Development / test databases** -- fast setup, in-memory mode, zero configuration.
- **Prototyping** before migrating to PostgreSQL or MySQL.

**Avoid SQLite when:** you need high-concurrency writes from multiple processes (it allows only one writer at a time), or when you need features like advanced user/role management, row-level security, or full replication.

## Type system (affinity)

SQLite uses **type affinity**, not strict types. Any value can be stored in any column by default. This surprises developers coming from PostgreSQL.

| Affinity | Applies to | Stored as |
| :--- | :--- | :--- |
| TEXT | `TEXT`, `CHAR`, `CLOB` | UTF-8 string |
| NUMERIC | `NUMERIC`, `DECIMAL` | Integer or real depending on value |
| INTEGER | `INT`, `INTEGER`, `BIGINT` | Signed integer (1-8 bytes) |
| REAL | `REAL`, `FLOAT`, `DOUBLE` | 8-byte IEEE 754 |
| BLOB | `BLOB`, no type | Raw bytes |

Enable **strict mode** (SQLite 3.37+) to enforce type checking at the column level:

```sql
CREATE TABLE events (
    id         INTEGER PRIMARY KEY,
    event_type TEXT NOT NULL,
    payload    TEXT NOT NULL,       -- store JSON as TEXT
    created_at TEXT NOT NULL        -- ISO 8601 string; SQLite has no native DATETIME
) STRICT;
```

**Date and time:** SQLite has no native timestamp type. Store as:
- `TEXT` in ISO 8601 format: `'2025-01-15T14:30:00Z'`
- `INTEGER` as Unix epoch seconds
- `REAL` as Julian day number

Use built-in date functions: `datetime()`, `strftime()`, `unixepoch()`.

## WAL mode (essential for concurrent reads)

The default journal mode (`DELETE`) allows only one reader or writer at a time. Enable WAL for concurrent readers + one writer:

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;   -- safe with WAL; FULL is for DELETE journal
PRAGMA foreign_keys = ON;      -- disabled by default; always enable
PRAGMA busy_timeout = 5000;    -- wait up to 5s for a write lock before returning SQLITE_BUSY
```

Set these pragmas on every connection open, or use a connection URI:

```text
file:myapp.db?mode=rwc&_journal_mode=WAL&_foreign_keys=on&_busy_timeout=5000
```

## Indexing

SQLite supports B-tree indexes only. All the standard patterns apply.

```sql
-- Simple index
CREATE INDEX idx_events_type ON events (event_type);

-- Partial index: only index relevant rows
CREATE INDEX idx_events_pending ON events (created_at)
WHERE status = 'pending';

-- Expression index (SQLite 3.31+)
CREATE INDEX idx_users_email_lower ON users (lower(email));

-- Covering index
CREATE INDEX idx_orders_covering ON orders (user_id, status, total);
```

**SQLite-specific behavior:**
- The `INTEGER PRIMARY KEY` column is an alias for the `rowid` (64-bit signed integer). This is the only true clustered index.
- Prefer `WITHOUT ROWID` tables for tables with a non-integer primary key to avoid the hidden rowid:

```sql
CREATE TABLE kv_store (
    key   TEXT NOT NULL,
    value TEXT,
    PRIMARY KEY (key)
) WITHOUT ROWID;
```

## Query optimization

```sql
-- EXPLAIN QUERY PLAN: human-readable index usage
EXPLAIN QUERY PLAN
SELECT * FROM orders WHERE user_id = 42 ORDER BY created_at DESC;
-- Look for: "SEARCH orders USING INDEX" vs "SCAN orders" (full table scan)

-- Full EXPLAIN (opcodes) for deep analysis
EXPLAIN SELECT ...;
```

**Common issues:**

| Issue | Fix |
| :--- | :--- |
| Full table scan on large table | Add index on WHERE / ORDER BY columns |
| `LIKE '%term%'` is never indexed | Use FTS5 for full-text queries |
| Slow with many concurrent readers | Ensure WAL mode is enabled |
| `SQLITE_BUSY` errors | Set `busy_timeout`; restructure to minimize write contention |
| Date comparisons wrong | Store dates consistently; use `strftime` for comparisons |

## Full-text search (FTS5)

```sql
-- Create FTS5 virtual table
CREATE VIRTUAL TABLE articles_fts USING fts5(title, body, content='articles', content_rowid='id');

-- Populate from existing table
INSERT INTO articles_fts(articles_fts) VALUES('rebuild');

-- Trigger to keep FTS in sync
CREATE TRIGGER articles_ai AFTER INSERT ON articles BEGIN
    INSERT INTO articles_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;

-- Search
SELECT a.* FROM articles a
JOIN articles_fts ON a.id = articles_fts.rowid
WHERE articles_fts MATCH 'database indexing'
ORDER BY rank;
```

## JSON support

SQLite has built-in JSON functions (no extension needed in 3.38+). Store JSON as `TEXT`.

```sql
-- Extract fields
SELECT json_extract(payload, '$.user_id')   AS user_id,
       json_extract(payload, '$.event_type') AS event_type
FROM events;

-- Filter by JSON field (no index; use generated column for frequent queries)
SELECT * FROM events WHERE json_extract(payload, '$.status') = 'active';

-- Generated column for indexable JSON path (3.31+)
ALTER TABLE events ADD COLUMN status TEXT
    GENERATED ALWAYS AS (json_extract(payload, '$.status')) STORED;

CREATE INDEX idx_events_status ON events (status);
```

## Transactions

```sql
-- Default: autocommit per statement
-- Explicit transaction for batching writes (dramatically faster)
BEGIN;
INSERT INTO events ...;   -- repeat many times
INSERT INTO events ...;
COMMIT;

-- Use IMMEDIATE to acquire write lock upfront and avoid deadlocks
BEGIN IMMEDIATE;
UPDATE ...;
COMMIT;

-- EXCLUSIVE: block all other connections (use sparingly)
BEGIN EXCLUSIVE;
...
COMMIT;
```

**Batch insert performance:** wrapping 1,000 inserts in a single transaction is typically 50-100x faster than one transaction per insert.

## libSQL / Turso (SQLite at the edge)

[libSQL](https://turso.tech/libsql) is an open-source SQLite fork with extensions for edge and distributed use:

- Embedded replicas: read from a local replica, write to a remote primary.
- HTTP API compatible with Turso Cloud.
- `ATTACH` remote databases.

```typescript
import { createClient } from "@libsql/client";

const db = createClient({
  url: "libsql://my-db.turso.io",
  authToken: process.env.TURSO_TOKEN,
  syncUrl: "file:local.db",   // local replica for offline reads
});

await db.execute("SELECT * FROM users WHERE id = ?", [42]);
```

## Useful pragmas reference

```sql
PRAGMA journal_mode;           -- check current mode
PRAGMA journal_mode = WAL;     -- enable WAL
PRAGMA wal_checkpoint(FULL);   -- flush WAL to main database file

PRAGMA page_size;              -- default 4096; set before first write for new DB
PRAGMA cache_size = -64000;    -- negative = KB; 64 MB page cache

PRAGMA auto_vacuum = INCREMENTAL;  -- reclaim space without VACUUM (incremental mode)
PRAGMA incremental_vacuum(100);    -- free up to 100 pages

PRAGMA integrity_check;        -- full integrity verification
PRAGMA quick_check;            -- faster integrity check

PRAGMA table_info('orders');   -- column names and types
PRAGMA index_list('orders');   -- indexes on a table
PRAGMA index_info('idx_name'); -- columns in an index
```
