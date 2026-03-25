# Redis Reference

Covers Redis 7.x (open-source) and Valkey 7.x / 8.x (the FOSS fork, API-compatible). Hosted offerings: Redis Cloud, ElastiCache, UpStash.

## Data structures

| Structure | Commands | Typical use |
| :--- | :--- | :--- |
| String | `GET`, `SET`, `INCR`, `GETSET` | Simple cache, counters, feature flags |
| Hash | `HGET`, `HSET`, `HMGET`, `HGETALL` | Object fields; more efficient than one key per field |
| List | `LPUSH`, `RPOP`, `LRANGE`, `BLPOP` | Queues, activity feeds, ordered collections |
| Set | `SADD`, `SMEMBERS`, `SINTER`, `SUNION` | Unique tags, membership tests, set math |
| Sorted set | `ZADD`, `ZRANGE`, `ZRANGEBYSCORE` | Leaderboards, rate limiting, time-ordered events |
| Bitmap | `SETBIT`, `GETBIT`, `BITCOUNT` | Presence flags, daily active users |
| HyperLogLog | `PFADD`, `PFCOUNT` | Approximate unique count (error < 1%) |
| Stream | `XADD`, `XREAD`, `XREADGROUP` | Persistent message log, event sourcing |
| JSON (RedisJSON) | `JSON.SET`, `JSON.GET`, `JSON.ARRAPPEND` | Structured document storage with path queries |
| TimeSeries (RedisTimeSeries) | `TS.ADD`, `TS.RANGE` | Metrics, sensor data with downsampling |

## Caching patterns

### TTL and expiry

```text
SET user:42:profile "{...}" EX 3600          # expire in 1 hour
SET session:abc123 "..." EXAT 1735689600     # expire at Unix timestamp
PERSIST user:42:profile                      # remove expiry
TTL user:42:profile                          # seconds remaining (-1 = no expiry, -2 = gone)
```

### Cache-aside (lazy loading)

Application checks cache; on miss, loads from DB and writes to cache. This is the most common pattern.

```text
1. GET user:42:profile
2. If nil: load from database, SET user:42:profile <data> EX 3600
3. Return data
```

### Write-through

Write to cache and DB atomically on every write. Cache is always warm; adds write latency.

### Cache stampede prevention

Use `SET NX PX` to acquire a lock before populating the cache, preventing multiple processes from hammering the DB simultaneously.

```text
SET lock:user:42:profile 1 NX PX 500    # acquire lock for 500ms
# If acquired: load from DB, SET cache, DEL lock
# If not acquired: wait briefly and retry or serve stale
```

## Atomic operations and transactions

```text
# MULTI / EXEC (optimistic transaction)
MULTI
INCR user:42:credits
DECRBY account:42:balance 100
EXEC

# WATCH (optimistic locking: abort transaction if key changes)
WATCH balance:42
MULTI
DECRBY balance:42 50
EXEC   # returns nil if balance:42 was modified since WATCH
```

**Lua scripting** for atomic read-modify-write without WATCH/MULTI overhead:

```lua
-- Rate limiter: allow N requests per window (called with EVALSHA)
local key = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local current = redis.call("INCR", key)
if current == 1 then
    redis.call("EXPIRE", key, window)
end
if current > limit then
    return 0
end
return 1
```

## Sorted sets for rate limiting and leaderboards

```text
# Sliding window rate limiter
ZREMRANGEBYSCORE ratelimit:user:42 0 <now_minus_window>
ZADD ratelimit:user:42 <now> <request_id>
ZCARD ratelimit:user:42   # compare to limit

# Leaderboard
ZADD leaderboard 1500 "alice"
ZADD leaderboard 2300 "bob"
ZREVRANGE leaderboard 0 9 WITHSCORES   # top 10
ZRANK leaderboard "alice"              # rank (0-indexed)
```

## Streams (persistent message log)

Streams are the primary building block for durable async messaging in Redis 7+. They work like Kafka topics within a single Redis node.

```text
# Producer
XADD events * type "user.signup" user_id "42" email "alice@example.com"

# Consumer group: at-least-once delivery, each message to one consumer
XGROUP CREATE events my-service $ MKSTREAM
XREADGROUP GROUP my-service worker-1 COUNT 10 BLOCK 2000 STREAMS events >

# Acknowledge processed messages
XACK events my-service <message-id>

# Check pending (unacknowledged) messages
XPENDING events my-service - + 10
```

## Pub/Sub

Pub/Sub is fire-and-forget -- messages are not persisted. Use Streams if durability or replay is needed.

```text
# Subscriber
SUBSCRIBE notifications:user:42

# Publisher
PUBLISH notifications:user:42 "{\"type\":\"order_shipped\"}"

# Pattern subscribe
PSUBSCRIBE notifications:*
```

## Persistence

| Mode | Durability | Performance | When to use |
| :--- | :--- | :--- | :--- |
| No persistence | None | Highest | Pure cache; data is re-derivable |
| RDB snapshots | Point-in-time | Low overhead | Backup; acceptable data loss |
| AOF (appendonly) | Per-second to always | Moderate | Most production workloads |
| AOF + RDB | Best of both | Some overhead | Maximum durability |

```ini
# redis.conf: AOF with fsync every second (good balance)
appendonly yes
appendfsync everysec

# RDB snapshot (save <seconds> <changes>)
save 900 1      # after 900 sec if at least 1 key changed
save 300 10
save 60 10000
```

## High availability

### Sentinel

Automatic failover for a single primary + replicas. Sentinel monitors the primary and promotes a replica on failure. Minimum 3 Sentinel instances for quorum.

```ini
# sentinel.conf
sentinel monitor mymaster 127.0.0.1 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
```

### Cluster

Horizontal sharding across multiple primaries. Data is sharded across 16,384 hash slots. Each primary can have one or more replicas.

```bash
# Create a 3-primary + 3-replica cluster
redis-cli --cluster create \
  127.0.0.1:7000 127.0.0.1:7001 127.0.0.1:7002 \
  127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
  --cluster-replicas 1
```

**Cluster constraints:** `MULTI/EXEC` and Lua scripts only work if all keys belong to the same hash slot. Use hash tags `{user:42}` to co-locate related keys.

## Memory management

```text
# Memory usage and eviction policy
CONFIG SET maxmemory 4gb
CONFIG SET maxmemory-policy allkeys-lru   # evict least recently used when full

# Common policies:
# noeviction      -- return errors when full (default; wrong for cache use case)
# allkeys-lru     -- evict any key by LRU
# volatile-lru    -- evict only keys with TTL set, by LRU
# allkeys-lfu     -- evict by least frequently used (Redis 4+, often better than LRU)

# Per-key memory usage
MEMORY USAGE user:42:profile
DEBUG OBJECT user:42:profile
```

## Monitoring

```bash
# Real-time stats
redis-cli INFO stats
redis-cli INFO memory
redis-cli INFO replication

# Slow log (queries exceeding threshold in microseconds)
redis-cli CONFIG SET slowlog-log-slower-than 10000   # 10ms
redis-cli SLOWLOG GET 10

# Keyspace hit ratio (aim for > 95% in cache workloads)
redis-cli INFO stats | grep keyspace_hits
redis-cli INFO stats | grep keyspace_misses

# Monitor all commands (high overhead -- debug only)
redis-cli MONITOR
```

## Key naming conventions

- Use `:` as delimiter: `user:42:profile`, `session:abc123`.
- Prefix by domain: `cache:`, `lock:`, `ratelimit:`, `queue:`.
- Avoid overly long keys -- each character is stored.
- Use hash tags `{tag}` in cluster mode to control slot placement: `{user:42}:profile`.
