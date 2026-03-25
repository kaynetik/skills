# MySQL Reference

Covers MySQL 8.0+ and MariaDB 10.6+ unless noted. InnoDB is assumed throughout.

## Schema

### Charset and collation

Always declare `utf8mb4 COLLATE utf8mb4_unicode_ci` at the table (or global) level. The legacy `utf8` charset is a 3-byte subset that silently truncates characters outside the BMP (emoji, some CJK).

```sql
ALTER DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### Types

- `DECIMAL(p,s)` for money. Never `FLOAT` or `DOUBLE` for exact values.
- `DATETIME` or `TIMESTAMP` for time. `TIMESTAMP` is stored as UTC and auto-converts on read; `DATETIME` stores the literal value. Use `DATETIME` with UTC discipline at the application layer when you need the full range (1000-9999).
- `TINYINT(1)` for booleans (MySQL has no native `BOOLEAN` storage; the type alias maps to `TINYINT(1)`).
- `BINARY(16)` for UUIDs stored compactly; use `UUID_TO_BIN(uuid, 1)` (swap flag = 1 reorders time-high for better B-tree locality in PK).
- `JSON` type (MySQL 8.0+) stores validated JSON with path operator support; create generated columns to index specific paths.

### Table DDL

```sql
CREATE TABLE orders (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id     INT UNSIGNED NOT NULL,
    amount      DECIMAL(18,6) NOT NULL,
    currency    ENUM('USD','EUR','GBP','JPY') NOT NULL,
    status      ENUM('pending','processing','shipped','cancelled') NOT NULL DEFAULT 'pending',
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_status  (user_id, status),
    INDEX idx_created      (created_at),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### JSON with generated columns

```sql
CREATE TABLE events (
    id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    payload    JSON NOT NULL,
    -- Indexed generated column for a frequently queried path
    user_id    INT UNSIGNED AS (payload ->> '$.user_id') STORED,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

## Indexing

InnoDB uses B-tree for all standard indexes. The primary key is the clustered index -- every secondary index carries the PK value as a hidden suffix.

```sql
-- Composite (follow ESR: equality, sort, range)
CREATE INDEX idx_orders_user_date ON orders (user_id, created_at);

-- Covering index: all needed columns in the index itself
CREATE INDEX idx_orders_covering ON orders (user_id, status, created_at, amount);

-- Prefix index for long TEXT/VARCHAR (when full-column index is too large)
CREATE INDEX idx_articles_title ON articles (title(100));

-- Fulltext index
ALTER TABLE articles ADD FULLTEXT INDEX ft_content (title, body);

-- Functional index (MySQL 8.0+)
CREATE INDEX idx_email_lower ON users ((LOWER(email)));
```

**InnoDB implicit behavior:** any column not in the PK is appended to secondary index entries. Keep PKs narrow.

### Monitoring

```sql
-- Index usage statistics
SELECT table_schema, table_name, index_name, seq_in_index, column_name, cardinality
FROM information_schema.STATISTICS
WHERE table_schema = 'mydb'
ORDER BY table_name, index_name, seq_in_index;

-- Table sizes
SELECT table_name,
       ROUND(data_length  / 1024 / 1024, 2) AS data_mb,
       ROUND(index_length / 1024 / 1024, 2) AS index_mb,
       table_rows
FROM information_schema.TABLES
WHERE table_schema = 'mydb'
ORDER BY data_length DESC;
```

## Query optimization

```sql
-- EXPLAIN FORMAT=JSON gives the most detail
EXPLAIN FORMAT=JSON
SELECT u.name, COUNT(o.id) AS orders
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at > '2024-01-01'
GROUP BY u.id;
```

**Common fixes:**

| EXPLAIN signal | Cause | Fix |
| :--- | :--- | :--- |
| `type: ALL` | Full table scan | Add index |
| `Using filesort` | Sort not covered by index | Extend or add index for ORDER BY |
| `Using temporary` | Temp table for GROUP BY / DISTINCT | Index the GROUP BY columns |
| `rows` estimate far from actual | Stale stats | `ANALYZE TABLE t` |

### Pagination

```sql
-- Avoid OFFSET on large offsets
SELECT id, title FROM articles ORDER BY id LIMIT 20 OFFSET 100000;

-- Keyset pagination instead
SELECT id, title FROM articles
WHERE id > $last_id
ORDER BY id
LIMIT 20;
```

### Fulltext search

```sql
-- Natural language mode
SELECT * FROM articles
WHERE MATCH(title, body) AGAINST('database indexing' IN NATURAL LANGUAGE MODE);

-- Boolean mode (explicit operators)
SELECT * FROM articles
WHERE MATCH(title, body) AGAINST('+postgresql -oracle' IN BOOLEAN MODE);

-- With relevance score
SELECT *, MATCH(title, body) AGAINST('replication') AS score
FROM articles
WHERE MATCH(title, body) AGAINST('replication')
ORDER BY score DESC;
```

## Transactions

```sql
-- InnoDB default isolation: REPEATABLE READ
-- Use READ COMMITTED for most web workloads (fewer gap locks, better concurrency)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

START TRANSACTION;

UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;

COMMIT;
-- or ROLLBACK on error
```

**Deadlock handling:** InnoDB detects deadlocks and rolls back one transaction automatically. Catch `ER_LOCK_DEADLOCK` (1213) and retry with exponential backoff.

## Replication

MySQL uses binary logging (binlog) for replication. Use **row-based** binlog format (`binlog_format = ROW`) for correctness; statement-based replication is non-deterministic with functions like `NOW()` or `RAND()`.

```ini
# my.cnf on primary
[mysqld]
server-id        = 1
log_bin          = mysql-bin
binlog_format    = ROW
binlog_row_image = MINIMAL      # log only changed columns
gtid_mode        = ON
enforce_gtid_consistency = ON
```

```sql
-- Monitor replication lag on replica
SHOW REPLICA STATUS\G
-- Look at Seconds_Behind_Source
```

**CDC / streaming:** Debezium + MySQL connector reads the binlog and publishes row events to Kafka.

## Configuration reference

```ini
[mysqld]
# Memory
innodb_buffer_pool_size  = 70%_of_RAM    # primary cache; set to 70-80% on dedicated server
innodb_log_file_size     = 1G            # larger = fewer checkpoints, slower crash recovery

# Durability
innodb_flush_log_at_trx_commit = 1       # 1 = fsync on commit (safest); 2 = OS buffer
sync_binlog                    = 1       # flush binlog on every commit

# Connections
max_connections     = 300
wait_timeout        = 300
interactive_timeout = 300

# Slow query log
slow_query_log      = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time     = 1                  # seconds
log_queries_not_using_indexes = 1
```

## Maintenance

```sql
-- Update optimizer statistics
ANALYZE TABLE orders;

-- Reclaim fragmented space (rebuilds table -- avoid on large tables in production)
OPTIMIZE TABLE orders;

-- Check integrity
CHECK TABLE orders;

-- Current active queries
SHOW FULL PROCESSLIST;

-- InnoDB engine status (deadlocks, lock waits)
SHOW ENGINE INNODB STATUS\G
```
