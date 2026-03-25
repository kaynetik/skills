# MongoDB Reference

Covers MongoDB 7.0+ (Community and Atlas) unless noted. MongoDB 8.0 introduced `bulkWrite` command and `updateOne` sort option.

## Document modeling

### Embed vs. reference

| Embed when | Reference when |
| :--- | :--- |
| One-to-few relationship | One-to-many or many-to-many |
| Data is always accessed together | Subdocument is large or changes frequently |
| Atomic update of parent + child is needed | Document would exceed 16 MB |
| Subdocument has no independent identity | Data is shared across multiple parents |

```javascript
// Embedded (one-to-few address per user)
{
  _id: ObjectId("..."),
  name: "Alice",
  addresses: [
    { type: "home", street: "1 Main St", city: "Portland" }
  ]
}

// Referenced (orders belong to user but are numerous)
// users collection
{ _id: ObjectId("u1"), name: "Alice" }

// orders collection
{ _id: ObjectId("o1"), user_id: ObjectId("u1"), total: 42.00 }
```

**Denormalize** only fields that are read on every access and written rarely (e.g., `user.name` on an order document).

## Indexing

### ESR rule for compound indexes

Equality first, Sort second, Range last -- same as SQL.

```javascript
// Query: { status: "active" }, sort: { priority: -1 }, filter: { created_at: { $gt: date } }
db.tasks.createIndex({ status: 1, priority: -1, created_at: 1 });
```

### Index types

```javascript
// Single field
db.users.createIndex({ email: 1 }, { unique: true });

// Compound
db.orders.createIndex({ user_id: 1, created_at: -1 });

// Multikey: auto-created when field is an array
db.posts.createIndex({ tags: 1 });

// Partial: index only matching documents
db.orders.createIndex(
  { user_id: 1, created_at: -1 },
  { partialFilterExpression: { status: { $in: ["pending", "processing"] } } }
);

// TTL: auto-delete documents after N seconds
db.sessions.createIndex({ created_at: 1 }, { expireAfterSeconds: 3600 });

// Text search (built-in)
db.articles.createIndex({ title: "text", body: "text" });

// Geospatial
db.locations.createIndex({ coordinates: "2dsphere" });

// Hidden: test removing an index without dropping it (7.0+)
db.orders.hideIndex("idx_name");
```

### Monitoring index usage

```javascript
// Per-index access counts since last restart
db.orders.aggregate([{ $indexStats: {} }]);

// Explain query plan
db.orders.find({ status: "active" }).explain("executionStats");
// Look for: COLLSCAN (no index) vs IXSCAN (index used)
// Check: totalDocsExamined vs totalDocsReturned -- large gap means filtering after scan
```

## Aggregation pipeline

**Rules:** `$match` and `$project` early to reduce document size through the pipeline. Put `$limit` after `$sort`.

```javascript
// Standard pattern
db.orders.aggregate([
  { $match: { status: "completed", created_at: { $gte: ISODate("2025-01-01") } } },
  { $group: { _id: "$user_id", total: { $sum: "$amount" }, count: { $sum: 1 } } },
  { $sort: { total: -1 } },
  { $limit: 10 },
  { $project: { _id: 0, user_id: "$_id", total: 1, count: 1 } }
]);

// $lookup: ensure the foreign field is indexed
db.orders.aggregate([
  { $match: { status: "shipped" } },
  {
    $lookup: {
      from: "users",
      localField: "user_id",
      foreignField: "_id",
      as: "user"
    }
  },
  { $unwind: "$user" }
]);

// $facet: parallel sub-pipelines for multi-dimensional results
db.products.aggregate([
  {
    $facet: {
      byCategory: [
        { $group: { _id: "$category", count: { $sum: 1 } } },
        { $sort: { count: -1 } }
      ],
      priceStats: [
        { $group: { _id: null, avg: { $avg: "$price" }, max: { $max: "$price" } } }
      ]
    }
  }
]);

// $graphLookup: recursive traversal (org charts, category trees)
db.employees.aggregate([
  { $match: { name: "CEO" } },
  {
    $graphLookup: {
      from: "employees",
      startWith: "$_id",
      connectFromField: "_id",
      connectToField: "manager_id",
      as: "reports",
      maxDepth: 5
    }
  }
]);
```

## CRUD patterns

```javascript
// Upsert
db.users.updateOne(
  { email: "alice@example.com" },
  { $set: { name: "Alice", updated_at: new Date() }, $setOnInsert: { created_at: new Date() } },
  { upsert: true }
);

// MongoDB 8.0: updateOne with sort (deterministic which document is updated)
db.tasks.updateOne(
  { status: "pending" },
  { $set: { status: "processing" } },
  { sort: { priority: -1 } }
);

// Atomic find-and-modify
db.orders.findOneAndUpdate(
  { _id: orderId, status: "pending" },
  { $set: { status: "processing" } },
  { returnDocument: "after" }
);

// MongoDB 8.0: cross-collection bulkWrite (atomic within a transaction)
db.bulkWrite([
  { namespace: "mydb.orders",   update: { filter: { _id: orderId }, update: { $set: { status: "shipped" } } } },
  { namespace: "mydb.shipments", insert: { document: { order_id: orderId, carrier: "UPS" } } }
]);
```

## Pagination

```javascript
// Avoid: large skip() scans from the beginning
db.products.find().sort({ _id: 1 }).skip(100000).limit(20);

// Use: range-based pagination
db.products.find({ _id: { $gt: lastId } }).sort({ _id: 1 }).limit(20);
```

## Transactions

```javascript
// Multi-document transactions (replica set or sharded cluster required)
const session = client.startSession();
session.startTransaction();
try {
  await db.collection("accounts").updateOne(
    { _id: "acc1" }, { $inc: { balance: -100 } }, { session }
  );
  await db.collection("accounts").updateOne(
    { _id: "acc2" }, { $inc: { balance: 100 } }, { session }
  );
  await session.commitTransaction();
} catch (err) {
  await session.abortTransaction();
  throw err;
} finally {
  session.endSession();
}
```

Transactions carry a performance overhead. Prefer single-document atomic operations when possible; embed related data to avoid cross-document transactions.

## Replication

```javascript
// Initialize a replica set
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo1:27017", priority: 2 },
    { _id: 1, host: "mongo2:27017", priority: 1 },
    { _id: 2, host: "mongo3:27017", priority: 0, hidden: true }   // hidden: backup member
  ]
});

// Check status and lag
rs.status();

// Replication lag per member
rs.printSecondaryReplicationInfo();
```

**Read preferences:**

| Mode | Use |
| :--- | :--- |
| `primary` (default) | Always read fresh data |
| `primaryPreferred` | Fall back to secondary if primary unavailable |
| `secondary` | Offload reads; may see stale data |
| `nearest` | Lowest latency; may be primary or secondary |

## Atlas Search (vector and full-text)

```javascript
// Atlas Search index definition (JSON in Atlas UI or Atlas CLI)
{
  "mappings": {
    "dynamic": false,
    "fields": {
      "title": { "type": "string", "analyzer": "lucene.english" },
      "embedding": { "type": "knnVector", "dimensions": 1536, "similarity": "cosine" }
    }
  }
}

// $search aggregation stage
db.articles.aggregate([
  {
    $search: {
      index: "default",
      text: { query: "database indexing", path: "title" }
    }
  },
  { $limit: 10 },
  { $project: { title: 1, score: { $meta: "searchScore" } } }
]);

// Vector search (ANN)
db.articles.aggregate([
  {
    $vectorSearch: {
      index: "vector_index",
      path: "embedding",
      queryVector: [/* 1536 floats */],
      numCandidates: 150,
      limit: 10
    }
  }
]);
```

## $queryStats (MongoDB 6.0.7+, enhanced in 8.1/8.2)

```javascript
// Analyze query workload patterns (requires Atlas or self-managed with the privilege)
db.adminCommand({ aggregate: 1, pipeline: [{ $queryStats: {} }], cursor: {} });
```

## Query Settings (MongoDB 8.0+)

```javascript
// Persistent index hint -- survives query plan cache eviction
db.adminCommand({
  setQuerySettings: {
    find: "orders",
    filter: { status: "active" },
    $db: "mydb"
  },
  settings: { indexHints: [{ ns: { db: "mydb", coll: "orders" }, allowedIndexes: ["status_1"] }] }
});
```
