# Database Selection Cheatsheet

## Decision Tree
Priority order - walk top to bottom, first match wins

```
1. Need multi-row/table ACID transactions?
   (money movement, inventory decrement, seat booking)
   │
   ├─ YES → Also need horizontal write scale beyond one primary?
   │         (sustained >~10K writes/sec, or multi-TB write growth)
   │         │
   │         ├─ YES → NEWSQL (Spanner / CockroachDB / Vitess)
   │         └─ NO  → RDBMS (Postgres / MySQL)
   │
   └─ NO → continue to Q2

2. Is the core query a multi-hop relationship traversal?
   (friends-of-friends, fraud rings, recommendation paths, shortest path)
   │
   ├─ YES → GRAPH (Neo4j)
   └─ NO  → continue to Q3

3. Are access patterns known upfront AND you need extreme
   scale / low-latency lookups by key?
   │
   ├─ YES → Is it write-heavy with range scans by a clustering key
   │         (time-series, logs, IoT), or simple point lookups?
   │         │
   │         ├─ Write-heavy / range scans → WIDE-COLUMN (Cassandra / Bigtable)
   │         └─ Simple key→value, need managed/serverless → KEY-VALUE (DynamoDB / Redis)
   │
   └─ NO → continue to Q4

4. Does the schema evolve per record / is data naturally
   a self-contained aggregate (profile, order, catalog entry)?
   │
   ├─ YES → DOCUMENT (MongoDB)
   └─ NO  → DEFAULT: RDBMS (Postgres / MySQL)
```

## Trade-off Statement Template
```
I'd [start with / choose] [DATABASE OR FAMILY] because [DOMAIN REQUIREMENT] —
[CONCRETE EXAMPLE FROM THIS SYSTEM]. [DATABASE] gives me that via [MECHANISM:
the specific engine feature/protocol responsible].

The cost is [SPECIFIC COST], because [WHY THAT MECHANISM CAUSES THE COST] —
[REAL NUMBER OR METRIC where possible].

I'd switch to [ALTERNATIVE] once [NUMERIC OR CONDITION-BASED TRIGGER],
because at that point I'm trading [WHAT YOU GIVE UP] for [WHAT YOU GAIN].
```

- DOMAIN REQUIREMENT + CONCRETE EXAMPLE — ties the choice to this system, not databases in the abstract. Interviewers dock points for generic answers.

- MECHANISM — must name the actual engine internals (MVCC, row-level locking, consistent hashing, Raft, partition-key hashing), not just the feature name. This is what separates a memorized fact from demonstrated understanding.

- SPECIFIC COST — the part people skip. Always state it unprompted, before the interviewer asks "but what's the downside."

- REAL NUMBER — order-of-magnitude is fine (10–20K writes/sec, 50ms cross-region latency) but must be a number, not "a lot" or "significant."

- SWITCH CONDITION — the exit criteria. This is what proves you're reasoning about trade-offs rather than reciting a preference.

## Decision Axes between SQL vs NoSQL

1. Consistency Requirements
- Need ACID transactions across multiple rows/tables?

2. Data shape and relationships
- Is the data relational by nature, or it's more self-contained?

3. Query Patterns
- Are access patterns known and stable, or is it more ad hoc queries later on?

4. Schema Volatility
- Do schema change often?
    - change often -> NoSQL, schema-on-read.
    - rarely changes -> SQL, schema-on-write

5. Scale and Throughput
- Will the usage hit the DB's scaling ceiling?
    - SQL DBs horizontal sharding are harder. Why harder?
        - Joins need co-located data
        - ACID transactions crossing shard boundaries are expensive
        - Foreign Key constraints only enforced within 1 node. you are responsible for data integrity beyond 1 node
        - No clear partition key. Here's what you do manually with sharding SQL DBs:
            - pick shard key
            - build routing layer
            - handle resharding manually
            - solve ID collisions across shards

6. CAP trade-off
- should system favor consistency or availability?
    - SQL typically lean CP, EC
    - NoSQL typicall lean AP, EL

## SQL vs NoSQL — Axes × DB Families

| DB Family | Examples | Consistency | Data Shape & Relationships | Query Patterns | Schema Volatility | Scale & Throughput | CAP Lean |
|---|---|---|---|---|---|---|---|
| **RDBMS** | Postgres, MySQL | Full ACID, multi-row/table transactions | Normalized relational; FKs; many-to-many via join tables | Ad-hoc SQL, joins, aggregations, rich secondary indexes | Fixed; migrations required for changes | Vertical scale + read replicas; horizontal write sharding is manual and painful* | CP (single-node) — distributed replicas favor consistency |
| **NewSQL / Distributed SQL** | Spanner, CockroachDB, Vitess | Full ACID even across shards (consensus-based, e.g. TrueTime) | Same relational model as RDBMS, distributed | SQL interface, same join/aggregation power | Fixed | Horizontal scale-out with SQL semantics; write latency higher due to consensus rounds | CP — trades some availability for consistency during partitions |
| **Document** | MongoDB | Single-document atomic by default; multi-doc ACID txns available but cost throughput | Denormalized aggregates; nested/embedded docs; embed-vs-reference tradeoff | Rich query on nested fields, secondary indexes; joins (`$lookup`) exist but are expensive | Flexible/schema-less per document | Built-in horizontal sharding; good for medium-high scale | CP by default (majority write concern), tunable toward AP |
| **Key-Value** | DynamoDB, Redis | Single-item atomic; DynamoDB offers transactional API (up to 100 items) at latency/cost | Flat key → opaque value; no modeled relationships | Lookup by primary key (+sort key) only; no joins, no ad-hoc filtering | Schema-less; value is app-defined blob | Best-in-class horizontal scale; millisecond latency; massive write throughput | AP by default (DynamoDB tunable to strong-consistency reads at cost) |
| **Wide-Column** | Cassandra, Bigtable, HBase | Eventual consistency by default, tunable via quorum (R+W); no multi-row txns; single-partition CAS via lightweight transactions (Paxos) | Rows with dynamic columns; partition key + clustering key; denormalized wide rows | Query by partition key (+clustering range) only; no ad-hoc filtering without secondary index/materialized view | Flexible columns within column families | Designed for petabyte scale, linear horizontal scalability, very high write throughput | AP — the canonical AP system |
| **Graph** | Neo4j | ACID within a single instance | Nodes + edges; optimized for traversal; many-to-many is native, not bolted on | Multi-hop traversal queries (Cypher) that would be expensive cascading joins in SQL | Flexible property sets on nodes/edges | Scales less gracefully horizontally; deep traversals degrade with size; typically vertical/read-replica scaling | CP — causal clustering favors consistency |

### Why RDBMS?
- PostGres
- MySQL

#### Sharding
```
No clear shard type, depends on system core use case
```

#### Queries
- relational JOINS
- aggregates(AVG, SUM, COUNT)
- ad hoc queries supported

#### Use When
- ACID guarantee is a requirement
- Strong consistency is a requirement
- ad hoc queries expected
- needs to enforce Schema

#### Avoid When
- extrememly high write volume
- has natural partition key
- cross shard joins is expected on hot path

#### Pros

- ACID transactions
- Data integrity enforced by engine
    - FKs, unique constraints
- Flexible ad hoc querying
    - joins, aggregations, filters without pre defining access patterns
- Normalization
    - No data duplicates and drift issues
- SQL query language is widely known

#### Cons

- Horizontal write scaling is hard
    - No clear partition key. Here's what you do manually with sharding SQL DBs:
        - pick shard key
        - build routing layer
        - handle resharding manually
        - solve ID collisions across shards
- Vertical scaling has ceiling
- Schema rigidity
    - every schame shape change needs a migration
- Joins degrade at large scale, especially across shards
- Poor fit for unstructured data
- Global distribution with strong consistency is hard
    - Cross region replication adds latency

### Why NewSQL/Distributed SQL?

#### Pros
- Combines ACID transaction + SQL query model with horizontal scalability
- Distributed transactions handled via consensus(Paxos/Raft)
    - no app level 2PC needed
- Auto sharding and rebalancing built into engine
- Global distribution with strong consistency
    - geo-replicated
    - linearizable reads across regions

#### Cons
- Higher write latency
    - consensus adds coordination overhead to every transaction
- Operationally complex
    - distributed consensus hard to run, debug
- Expensive
    - geo-distributed, strongly consistent systems (Spanner) cost significantly more to operate
- Still fundamentally CP
    - during a network partition it sacrifices availability for consistency, same trade-off as RDBMS, just at larger scale


### Why Key-Value Store DBs?
- Redis
- DynamoDB

#### Sharding
```
hash(key) -> value
```

#### Queries
```
GET(key)
SET(key, value)
SET() EX TTL
INCR
```

#### Use When
- caller holds `key`
- doesn't care about value type
- need single digit ms latency 

#### Avoid When
- find records without key
- need ranges for ordering
- need joins

#### Pros
- Best-in-class horizontal scale and throughput
    - 10million ops/sec achievable
- Low latency lookups by key
- Partition key hashing handles distribution automatically
- DynamoDB: fully managed, auto-scaling
- Redis: in-memory speed for caching/sessions/leaderboards/rate-limiting

#### Cons
- No ad-hoc queries
    - must define access pattern upfront for optimal performance
    - Non key lookups needs a GSI or full scan
- No joins
- Weak consistency by default, tunable to be consistent
- Value is opaque to engine
    - no schema enforcement, no constraints


### Why Document DBs?
- MongoDB

#### Sharding
```
1 key per collection
```

#### Queries
```
GET(id) -> entire object FILTER(inner_field = ?)
FIND (inner_field = ?)
```

#### Use When
- read/write as a unit
- children can't exist independently
- data locality is expected

#### Avoid When
- routine cross collection JOINs
- child data grows unbounded(MongoDB 16MB cap)
- cross document analytics
- strict ACID requirements multi doc (> 100 docs)

#### Pros
- Built-in horizontal sharding
- Flexible schema
    - evolve document shape without schemas
- Natural data aggregation
    - child data must be under parent data umbrella
- Query language on inner nested fields
- Multi doc ACID transaction for <= 100 Docs within same shard

#### Cons
- Denormalization
    - duplicate data can drift out of sync
- JOINS are limited and expensive
- Schema flexibility chaos without app-level discipline


### Why Wide-Column DBs?
- Cassandra
- HBase
- BigTable

#### Sharding
```
Partition key,
Clustering key
```

#### Queries
```
WHERE pk = ? AND clustering > ? ORDER BY clustering LIMIT N;
```

#### Use When
- query "the last N X for this Y, newest first"
- append only

#### Avoid When
- heavy modify/delete to existing data
- low write volume

#### Pros
- massive horizontal scalability
    - petabyte scale
- very high write throughput
    - built for write-heavy workloads(time series, logging, IoT)
- tunable consistency
    - trade consistency vs latency per query or vice versa
- built-in multi-datacenter replication

#### Cons
- Query limited to partition key + clustering key range
- Requires 'query-first' table design
- No JOINs or ad-hoc queries without secondary indexes/materialized views
- Eventual consistency
    - apps must tolerate stale reads
- Operationally complex
    - compaction, tombstones, hot-partition tuning

### Why Graph DBs?
- Neo4J
- Neptune

#### Pros
- Native multi-hop traversal
    - >= hops ideal
- Data model matches domain
    - social graphs, fraud detection, knowledge graphs
- ACID within single node

#### Cons
- Sharding a graph DB is hard since edges cross shard boundaries
    - typicall vertical/read-replica scaling only
- Unbounded traversals degrade performance at scale
- Rarely SOR for everything
    - usually paired with another primary DB