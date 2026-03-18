# 🏗 System Design Mastery Roadmap

---

# Tier 1 — Absolute Foundations

## Topic 1 — Back-of-the-Envelope Estimation
### Subtopics
- Unit conversions
- Time & data size memorization
- Traffic estimation
- Peak traffic estimation
- Read/write ratio estimation
- Storage estimation
- Bandwidth estimation
- Cache size estimation
- Server count estimation
- Database size estimation
- Replication overhead
- Retention & growth modeling
- Concurrent user estimation
- Object size estimation
- Assumption setting
- Sanity checking
- Interview communication
- System-specific estimation practice

### Practice Requirements
- 20 estimation drills
- 5 full-system estimations
- 1 cheat sheet
- 1 test ≥ 90%
- verbal estimation < 2 min


## Topic 2 — Scalability Fundamentals
### Subtopics
- Latency vs throughput
- Vertical scaling
- Horizontal scaling
- Bottlenecks
- Stateless vs stateful services
- Resource constraints (CPU, memory, disk, network)
- Backpressure basics
- Throughput limits

### Practice Requirements
- 20 concept questions
- 2 essence systems
- 5 variations
- 1 cheat sheet
- 1 diagram


## Topic 3 — Load Balancing
### Subtopics
- L4 vs L7 load balancers
- Routing algorithms
- Health checks
- Failover
- Reverse proxies
- Sticky sessions
- Traffic routing

### Practice Requirements
- 20 concept questions
- 2 essence systems
- 5 variations
- 1 cheat sheet
- 1 diagram


## Topic 4 — Stateless Services
### Subtopics
- Stateless vs stateful architecture
- Session management
- Externalizing state
- Idempotency
- Horizontal scaling patterns

### Practice Requirements
- 20 concept questions
- 2 essence systems
- 5 variations
- 1 cheat sheet
- 1 diagram


## Topic 5 — Caching Systems
### Subtopics
- Cache-aside
- Write-through
- Write-back
- Eviction policies (LRU, LFU, TTL)
- Cache consistency
- Cache invalidation
- Hot key problem
- Multi-level caching

### Practice Requirements
- 20 concept questions
- 2 essence systems
- 5 variations
- 1 cheat sheet
- 1 diagram


## Topic 6 — Database Fundamentals
### Subtopics
- SQL vs NoSQL
- OLTP vs OLAP
- Data modeling
- Indexing
- Query patterns
- Transactions (ACID)
- Read vs write optimization

### Practice Requirements
- 20 concept questions
- 2 essence systems
- 5 variations
- 1 cheat sheet
- 1 diagram


## Topic 7 — Data Partitioning (Sharding)
### Subtopics
- Horizontal partitioning
- Hash partitioning
- Range partitioning
- Consistent hashing
- Rebalancing
- Hot partitions
- Cross-shard queries

### Practice Requirements
- 20 concept questions
- 2 essence systems
- 5 variations
- 1 cheat sheet
- 1 diagram

---

# Tier 2 — Core Distributed Systems

## Topic 1 — Distributed Storage Systems
### Subtopics
- Replication
- Leader/follower
- Quorum reads/writes
- Durability
- Data consistency basics

### Practice Requirements
- 20 concept questions
- 2 essence systems
- 5 variations
- 1 cheat sheet
- 1 diagram


## Topic 2 — Replication Strategies
### Subtopics
- Synchronous vs asynchronous replication
- Multi-leader
- Leaderless replication
- Read replicas
- Write propagation

### Practice Requirements
- same as above


## Topic 3 — Consistency Models
### Subtopics
- Strong consistency
- Eventual consistency
- Causal consistency
- Read-after-write
- CAP theorem basics

### Practice Requirements
- same as above


## Topic 4 — Consensus & Leader Election
### Subtopics
- Leader election
- Raft basics
- Paxos intuition
- Failure handling
- Split brain

### Practice Requirements
- same as above


## Topic 5 — Message Queues & Event Systems
### Subtopics
- Pub/sub
- Queues vs streams
- Delivery guarantees
- Backpressure
- Retry mechanisms

### Practice Requirements
- same as above


## Topic 6 — API Design & Service Boundaries
### Subtopics
- REST vs gRPC
- Microservices
- Service ownership
- Versioning
- API contracts

### Practice Requirements
- same as above

---

# Tier 3 — Large Scale System Archetypes

## Topic 1 — Feed / Timeline Systems
### Subtopics
- Fan-out on write
- Fan-out on read
- Ranking
- Storage strategies

### Practice Requirements
- same structure


## Topic 2 — Search Systems
### Subtopics
- Inverted index
- Ranking
- Index pipeline
- Query processing


## Topic 3 — Realtime Systems
### Subtopics
- WebSockets
- Long polling
- Event streaming
- Presence systems


## Topic 4 — Rate Limiting Systems
### Subtopics
- Token bucket
- Leaky bucket
- Sliding window
- Distributed counters


## Topic 5 — Notification Systems
### Subtopics
- Push systems
- Fan-out
- Delivery guarantees
- Retry systems

---

# Tier 4 — Reliability & Infrastructure Patterns

## Topic 1 — Fault Tolerance & Resilience
### Subtopics
- Retries
- Circuit breakers
- Graceful degradation
- Redundancy


## Topic 2 — Observability Systems
### Subtopics
- Logging
- Metrics
- Tracing
- Alerting


## Topic 3 — Distributed Locking & Coordination
### Subtopics
- Leader election
- Locks
- ZooKeeper / etcd concepts


## Topic 4 — Background Processing Systems
### Subtopics
- Batch jobs
- Pipelines
- Schedulers
- Workers

---

# Tier 5 — Data & Analytics Systems

## Topic 1 — Stream Processing Systems
### Subtopics
- Kafka
- Flink
- Real-time pipelines
- Windowing


## Topic 2 — Batch Processing Systems
### Subtopics
- MapReduce
- ETL pipelines
- Data warehouses


## Topic 3 — Recommendation Systems
### Subtopics
- Candidate generation
- Ranking
- Feature stores
- Offline/online pipeline

---

# Tier 6 — Advanced Distributed Systems

## Topic 1 — Global Multi-Region Systems
### Subtopics
- Geo-replication
- Multi-region failover
- Latency routing


## Topic 2 — Distributed Transactions
### Subtopics
- Two-phase commit
- Saga pattern
- Compensation logic


## Topic 3 — Large Media Systems
### Subtopics
- Chunking
- CDN
- Transcoding
- Streaming


## Topic 4 — Massive Search / Index Systems
### Subtopics
- Distributed indexing
- Ranking pipelines
- Query serving


## Topic 5 — ML Infrastructure Systems
### Subtopics
- Feature stores
- Model serving
- Offline/online pipelines
- Training pipelines
