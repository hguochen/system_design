# 🏗️ System Design Study Roadmap

## How to Use This Roadmap

This roadmap follows the structure of the **System Design Semantic Tree**:
- **Center (MUST)** → Core first principles. Master these before anything else.
- **Trunks** → Domain branches: Scalability, Data Storage, Networking, Reliability, Observability, Security
- **System Archetypes** → Apply all trunk knowledge to solve real interview problems

Each topic has:
- **Objectives** — what you will study and understand
- **Mastery Criteria** — concrete, testable proof that you own the topic
- **Subtopics** — the specific concepts to cover

After each phase, a set of the **20 canonical system design problems** unlock. The goal is progressive capability: each phase gives you the building blocks to tackle the next class of problems.

---

## The 20 Canonical System Design Problems

| # | Problem | Phase Unlocked |
|---|---------|----------------|
| 1 | URL Shortener (bit.ly) | After Phase B |
| 2 | Rate Limiter | After Phase B |
| 3 | Key-Value Store (Redis/DynamoDB-like) | After Phase C |
| 4 | Distributed Cache | After Phase C |
| 5 | Dropbox / Google Drive | After Phase C |
| 6 | Instagram / Photo Sharing | After Phase C |
| 7 | Distributed Message Queue (Kafka-like) | After Phase D |
| 8 | Web Crawler | After Phase D |
| 9 | Twitter / X Feed | After Phase H |
| 10 | Facebook News Feed | After Phase H |
| 11 | WhatsApp / Chat System | After Phase H |
| 12 | Live Streaming (Twitch) | After Phase H |
| 13 | Notification System | After Phase H |
| 14 | Distributed Job Scheduler | After Phase H |
| 15 | Google Search | After Phase I |
| 16 | Search Autocomplete / Typeahead | After Phase I |
| 17 | Uber / Lyft (Ride Sharing) | After Phase I |
| 18 | Google Maps / Location Service | After Phase I |
| 19 | YouTube (full, with recommendations) | After Phase J |
| 20 | TikTok / Video Recommendation Feed | After Phase J |

---

---

# Topic 1 ✅ — Back-of-the-Envelope Estimation

### Completion Status
> ✅ Topic 1 COMPLETE — 8 estimation practices completed. Practices 9 (Search Autocomplete) and 10 (Notification System) deferred — unfamiliar system concepts, revisit after covering relevant topics.

### 📋 Subtopics

- [x] 1.1 Unit conversions
- [x] 1.2 Time & data size memorization
- [x] 1.3 Traffic estimation
- [x] 1.4 Peak traffic estimation
- [x] 1.5 Read/write ratio estimation
- [x] 1.6 Storage estimation
- [x] 1.7 Bandwidth estimation
- [x] 1.8 Cache size estimation
- [x] 1.9 Server count estimation
- [x] 1.10 Database size estimation
- [x] 1.11 Replication overhead
- [x] 1.12 Retention & growth modeling
- [x] 1.13 Concurrent user estimation
- [x] 1.14 Object size estimation
- [x] 1.15 Assumption setting
- [x] 1.16 Sanity checking
- [x] 1.17 Interview communication
- [x] 1.18 System-specific estimation practice

**Full Estimation Practice (8 / 8 completed)**
- [x] Practice 1 — URL Shortener (e.g. bit.ly)
- [x] Practice 2 — Photo Sharing (e.g. Instagram)
- [x] Practice 3 — Video Streaming (e.g. YouTube)
- [x] Practice 4 — Microblogging / Feed (e.g. Twitter/X)
- [x] Practice 5 — Ride Sharing (e.g. Uber)
- [x] Practice 6 — Messaging App (e.g. WhatsApp)
- [x] Practice 7 — File Storage (e.g. Dropbox)
- [x] Practice 8 — Live Streaming (e.g. Twitch)
- [~] Practice 9 — Search Autocomplete *(deferred — revisit after Topic 30)*
- [~] Practice 10 — Notification System *(deferred — revisit after Topic 27)*

---

---

# 🧠 PHASE A — Core First Principles
> The center gold bubble of the semantic tree. These are the "MUST" concepts — the mental models that underpin every design decision you will ever make. Master these before moving to any branch.

---

## 🧠 Topic 2 — System Design Core Principles & Scalability Fundamentals

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The CAP theorem and its practical implications for distributed system design
- PACELC as an extension of CAP that adds latency into the trade-off picture
- How to reason about latency vs. throughput and their relationship
- The fundamental tension between consistency and availability in real systems
- When to scale vertically vs. horizontally, and the limits of each
- How to identify bottlenecks and reason about resource constraints
- A repeatable framework for making and justifying design trade-offs in an interview

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Given a system requirement, identify where it falls on the CAP spectrum (CP vs. AP) and justify the choice with a concrete example
- Explain PACELC and describe one real system that illustrates the latency/consistency trade-off (e.g., DynamoDB, Cassandra, Spanner)
- Calculate effective throughput given average latency and parallelism (Little's Law)
- Look at an architecture diagram and identify the likely bottleneck and its resource type (CPU, memory, disk I/O, network)
- Articulate at least three scenarios where eventual consistency is the correct choice over strong consistency, and explain why
- Explain stateless vs. stateful architectures and the scaling implications of each
- Walk through a design trade-off out loud in a structured way: identify the forces at play, state your assumption, make a choice, explain the cost

### 📋 Subtopics
- [ ] 2.1 CAP theorem and its three properties
- [ ] 2.2 PACELC — extending CAP with latency
- [ ] 2.3 Latency vs. throughput — definitions and relationship
- [ ] 2.4 Little's Law and its application
- [ ] 2.5 Consistency vs. availability — spectrum of trade-offs
- [ ] 2.6 Horizontal vs. vertical scaling — when each applies
- [ ] 2.7 Stateless vs. stateful systems
- [ ] 2.8 Bottleneck identification and resource constraints (CPU, memory, disk, network)
- [ ] 2.9 Backpressure fundamentals
- [ ] 2.10 Design trade-off reasoning framework

---

---

# ⚡ PHASE B — Scalability Branch
> The Scalability trunk of the semantic tree. These are the building blocks every scalable system is constructed from: distributing load, caching hot data, distributing storage, and keeping services independently scalable.

---

## ⚖️ Topic 3 — Load Balancing

> ⏱️ **Recommended Hours: 3h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The difference between L4 and L7 load balancing and what each operates on
- The major routing algorithms and the trade-offs between them
- How health checks and failover work to maintain availability
- The role of reverse proxies and when to use them
- When sticky sessions are necessary and why they complicate scaling

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain the difference between L4 (TCP/UDP) and L7 (HTTP) load balancing with a concrete example of when you'd choose each
- Select the appropriate routing algorithm (round robin, least connections, IP hash, weighted round robin) for a given scenario and justify why
- Design a load balancing setup with health checks and automatic failover that has no single point of failure
- Explain the trade-offs of sticky sessions: what problem they solve and why they hurt horizontal scalability
- Describe how a reverse proxy differs from a load balancer and name a use case for each

### 📋 Subtopics
- [ ] 3.1 L4 vs. L7 load balancers
- [ ] 3.2 Routing algorithms (round robin, least connections, IP hash, weighted)
- [ ] 3.3 Health checks and failure detection
- [ ] 3.4 Failover and redundancy
- [ ] 3.5 Reverse proxies
- [ ] 3.6 Sticky sessions — trade-offs and alternatives
- [ ] 3.7 Global vs. local load balancing

---

## ⚡ Topic 4 — Caching Systems

> ⏱️ **Recommended Hours: 6h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The three core caching strategies (cache-aside, write-through, write-back) and when each is appropriate
- How eviction policies work and the trade-offs between LRU, LFU, and TTL
- The challenges of cache consistency and invalidation
- The hot key problem and how to mitigate it
- Multi-level caching and where each layer fits in a system

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Choose between cache-aside, write-through, and write-back for a given read/write pattern and explain the consistency and performance implications of each
- Explain cache stampede (thundering herd), describe when it occurs, and propose a solution (probabilistic expiry, locking, background refresh)
- Design a complete cache layer for a read-heavy system: what gets cached, TTL strategy, eviction policy, and invalidation approach
- Explain the hot key problem, how it causes imbalance, and describe at least two mitigation strategies (local caching, key sharding, read replicas)
- Explain the difference between LRU and LFU and identify a use case where LFU is clearly better

### 📋 Subtopics
- [ ] 4.1 Cache-aside (lazy loading)
- [ ] 4.2 Write-through caching
- [ ] 4.3 Write-back (write-behind) caching
- [ ] 4.4 Eviction policies — LRU, LFU, TTL
- [ ] 4.5 Cache consistency and invalidation strategies
- [ ] 4.6 Cache stampede and thundering herd
- [ ] 4.7 Hot key problem and mitigation
- [ ] 4.8 Multi-level caching (L1/L2, local + distributed)

---

## 🌍 Topic 5 — CDN

> ⏱️ **Recommended Hours: 3h**

### 🎯 Objectives
By the end of this topic, you will understand:
- What a CDN is, how it works, and why it improves latency for geographically distributed users
- The difference between pull and push CDN models
- How cache invalidation at the edge works and its challenges
- When CDNs are effective and when they provide little value

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain how a CDN's PoP network reduces latency for a user in Singapore accessing a US-hosted service
- Compare pull CDN vs. push CDN and select the appropriate model for static assets vs. frequently updated content
- Design a cache invalidation strategy at the edge (TTL-based, versioned URLs, API-based purge)
- Identify which components of a given system design benefit from CDN and which don't (e.g., API responses vs. static assets vs. user-generated media)
- Describe how CDNs are used beyond static files: dynamic content acceleration, DDoS protection at edge, and SSL termination

### 📋 Subtopics
- [ ] 5.1 CDN architecture — PoPs and edge servers
- [ ] 5.2 Pull CDN vs. push CDN
- [ ] 5.3 Cache invalidation at the edge
- [ ] 5.4 Geo-routing and anycast
- [ ] 5.5 CDN for static assets vs. dynamic content
- [ ] 5.6 CDN for media delivery (images, video)
- [ ] 5.7 CDN as DDoS mitigation layer

---

## 🔄 Topic 6 — Stateless Services

> ⏱️ **Recommended Hours: 3h**

### 🎯 Objectives
By the end of this topic, you will understand:
- Why stateless services are easier to scale horizontally
- The approaches to externalizing state (session stores, token-based auth)
- What idempotency means and why it matters for distributed systems
- The difference between stateful and stateless API design

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Take a stateful service design and refactor it into a stateless one by externalizing the session to Redis or a JWT
- Explain why a stateless service can be load-balanced freely while a stateful one requires sticky sessions or session replication
- Define idempotency, give two examples of idempotent and non-idempotent operations, and explain how to make a non-idempotent API idempotent using an idempotency key
- Describe the trade-offs between server-side sessions and JWT-based auth from a scalability perspective
- Explain what "share-nothing architecture" means and why it enables horizontal scaling

### 📋 Subtopics
- [ ] 6.1 Stateless vs. stateful architecture — definitions and scaling implications
- [ ] 6.2 Session management approaches (server-side, cookie-based, token-based)
- [ ] 6.3 Externalizing state to Redis / distributed stores
- [ ] 6.4 JWT as stateless session token
- [ ] 6.5 Idempotency — definition, importance, and design patterns
- [ ] 6.6 Share-nothing architecture
- [ ] 6.7 Horizontal scaling of stateless tiers

---

## 🔀 Topic 7 — Data Partitioning / Sharding

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The major sharding strategies and their access-pattern implications
- How consistent hashing works and why it minimizes resharding cost
- How to detect and mitigate hot partitions
- The challenges of cross-shard queries and distributed joins

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Compare hash partitioning vs. range partitioning and select the right one given a specific access pattern (e.g., range queries vs. random key lookups)
- Walk through consistent hashing step by step: how keys are mapped to nodes, how virtual nodes help, and how nodes are added/removed
- Identify a hot shard in a design and propose a mitigation (shard splitting, write spreading, application-level routing)
- Explain the challenge of cross-shard queries and describe how you'd handle them (scatter-gather, denormalization, application-level joins)
- Estimate the number of shards required for a given data volume and query rate

### 📋 Subtopics
- [ ] 7.1 Horizontal partitioning vs. vertical partitioning
- [ ] 7.2 Hash partitioning
- [ ] 7.3 Range partitioning
- [ ] 7.4 Consistent hashing — algorithm and virtual nodes
- [ ] 7.5 Rebalancing — adding and removing nodes
- [ ] 7.6 Hot partitions — detection and mitigation
- [ ] 7.7 Cross-shard queries and distributed joins

---

> ### 🔓 Phase B Unlocks
> You are now conceptually equipped to solve:
> - **#1 URL Shortener** — hashing, KV lookup, load balancing, caching, rate limiting preview
> - **#2 Rate Limiter** — sharding counters, caching, stateless service design

---

---

# 🗄️ PHASE C — Data Storage Branch
> The Data Storage trunk of the semantic tree. Covers the four storage types in the mindmap: Relational DB, NoSQL, Data Warehouse, and Blob/Object Store.

---

## 🗄️ Topic 8 — Database Fundamentals

> ⏱️ **Recommended Hours: 7h**

### 🎯 Objectives
By the end of this topic, you will understand:
- When to choose SQL vs. NoSQL and the design implications of each
- How indexes work and how to design them for a given query pattern
- What ACID guarantees mean and when you need them
- The difference between OLTP and OLAP workloads
- Common query optimization pitfalls

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Given a data model and access pattern, choose between SQL and NoSQL and justify the choice (schema flexibility, query patterns, consistency needs, scale)
- Design a database schema for a given use case with appropriate primary keys, foreign keys, and indexes
- Explain all four ACID properties with a concrete example of what breaks if each one is violated
- Explain the difference between a B-tree index and an LSM-tree and which storage engines use each
- Identify and resolve an N+1 query problem in a given query pattern
- Explain why denormalization is sometimes necessary and its trade-offs

### 📋 Subtopics
- [ ] 8.1 SQL vs. NoSQL — when to use each
- [ ] 8.2 OLTP vs. OLAP workloads
- [ ] 8.3 Data modeling — normalization and denormalization
- [ ] 8.4 Indexing — B-tree, LSM-tree, composite indexes
- [ ] 8.5 Query patterns and optimization
- [ ] 8.6 ACID transactions — properties and enforcement
- [ ] 8.7 Read vs. write optimization
- [ ] 8.8 N+1 query problem

---

## 📦 Topic 9 — Blob / Object Storage

> ⏱️ **Recommended Hours: 4h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How object stores like S3 are architected internally
- The separation between metadata storage and data storage
- How large-file uploads (multipart) work
- How durability guarantees are achieved
- When to use object storage vs. block storage vs. file storage

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Design a blob storage system that separates metadata (stored in a database) from raw binary data (stored on chunk servers)
- Walk through the multipart upload flow for a 10GB video file: chunking, parallel upload, reassembly, and failure recovery
- Explain how S3 achieves 11 nines of durability through erasure coding and cross-region replication
- Identify when to use object store (unstructured, large files), block store (databases, OS volumes), or file system (shared access, hierarchical)
- Design a content-addressable storage system using checksums as keys

### 📋 Subtopics
- [ ] 9.1 Object store architecture — metadata vs. data separation
- [ ] 9.2 Chunk servers and data nodes
- [ ] 9.3 Multipart and resumable uploads
- [ ] 9.4 Durability through erasure coding and replication
- [ ] 9.5 Object versioning
- [ ] 9.6 Object store vs. block store vs. file storage — when to use each
- [ ] 9.7 Content-addressable storage

---

## 📊 Topic 10 — Data Warehouse & Analytics Storage

> ⏱️ **Recommended Hours: 4h**

### 🎯 Objectives
By the end of this topic, you will understand:
- Why columnar storage is better suited for analytics queries
- The difference between data lakes and data warehouses
- Star and snowflake schema design for analytical workloads
- ETL vs. ELT patterns

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain why columnar storage (e.g., Parquet, Redshift) outperforms row storage for aggregation queries, using I/O patterns as the reason
- Design a star schema for a given analytics use case (e.g., e-commerce orders)
- Explain the difference between a data lake and a data warehouse, and when a lakehouse architecture makes sense
- Compare ETL and ELT and identify which is better suited for cloud-native environments
- Describe partitioning strategies in a data warehouse (e.g., by date) and explain how they improve query performance

### 📋 Subtopics
- [ ] 10.1 Columnar vs. row storage — I/O trade-offs
- [ ] 10.2 OLAP data modeling — star schema and snowflake schema
- [ ] 10.3 Data lake vs. data warehouse vs. lakehouse
- [ ] 10.4 ETL vs. ELT patterns
- [ ] 10.5 Partitioning strategies in analytical storage
- [ ] 10.6 Query engines (overview: Presto, Spark SQL, BigQuery)

---

> ### 🔓 Phase C Unlocks
> You are now conceptually equipped to solve:
> - **#3 Key-Value Store** — consistent hashing (T7) + storage fundamentals (T8) + replication preview
> - **#4 Distributed Cache** — caching strategies (T4) + consistent hashing (T7) + eviction policies
> - **#5 Dropbox / Google Drive** — blob storage (T9) + chunking + metadata DB (T8)
> - **#6 Instagram / Photo Sharing** — blob storage (T9) + CDN (T5) + DB fundamentals (T8)

---

---

# 🌐 PHASE D — Networking Branch
> The Networking trunk. Covers how services talk to each other: API boundaries, async messaging, protocol selection, and service-to-service infrastructure.

---

## 🔌 Topic 11 — API Design & Service Boundaries

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The trade-offs between REST, gRPC, and GraphQL
- How to design clean microservice boundaries
- API versioning strategies and their operational implications
- The role of an API gateway

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Choose between REST, gRPC, and GraphQL for a given use case and justify based on coupling, performance, and consumer type
- Design a RESTful API with correct resource naming, HTTP method usage, status codes, and pagination
- Explain the challenges of microservice decomposition: data ownership, service coupling, distributed transactions
- Design an API versioning strategy (URI versioning, header versioning) and explain the operational trade-offs
- Describe the responsibilities of an API gateway (auth, rate limiting, routing, SSL termination) and explain why it belongs at the edge

### 📋 Subtopics
- [ ] 11.1 REST — principles, resource design, HTTP methods, status codes
- [ ] 11.2 gRPC — Protocol Buffers, streaming, when to use over REST
- [ ] 11.3 GraphQL — query flexibility, N+1 problem, when to use
- [ ] 11.4 Microservice decomposition — domain boundaries and ownership
- [ ] 11.5 API versioning strategies
- [ ] 11.6 API contracts and backward compatibility
- [ ] 11.7 API gateway patterns

---

## 📨 Topic 12 — Message Queues & Event Systems

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The difference between a message queue and an event stream
- The three delivery guarantee models and their implementation requirements
- How backpressure works and how consumers signal it
- Retry patterns and dead-letter queues

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain the semantic difference between a queue (point-to-point, consumed once) and a topic/stream (pub/sub, replayable)
- Compare at-most-once, at-least-once, and exactly-once delivery: what each guarantees, what it costs, and which systems provide each
- Design a retry mechanism with exponential backoff and a dead-letter queue for poison messages
- Explain how consumer-driven backpressure works and design a system that handles a slow consumer without data loss
- Compare Kafka, RabbitMQ, and SQS for a given use case based on ordering guarantees, replay capability, and delivery semantics

### 📋 Subtopics
- [ ] 12.1 Message queue vs. event stream semantics
- [ ] 12.2 Pub/sub model
- [ ] 12.3 Delivery guarantees — at-most-once, at-least-once, exactly-once
- [ ] 12.4 Backpressure — how consumers signal and producers respond
- [ ] 12.5 Retry mechanisms and exponential backoff
- [ ] 12.6 Dead-letter queues
- [ ] 12.7 Kafka vs. RabbitMQ vs. SQS — comparison

---

## 📡 Topic 13 — Protocols

> ⏱️ **Recommended Hours: 4h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How HTTP has evolved from 1.1 to 2 to 3 and the performance implications
- When to use WebSockets vs. SSE vs. long polling for realtime communication
- How WebRTC enables peer-to-peer communication
- Protocol selection trade-offs for different application types

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain HTTP/2 multiplexing and how it eliminates head-of-line blocking at the application layer
- Explain HTTP/3's use of QUIC and why it improves performance on lossy networks
- Choose between WebSockets, SSE, and long polling for a given realtime use case based on directionality, latency requirements, and infrastructure constraints
- Explain how WebRTC establishes a peer-to-peer connection (signaling, ICE, STUN/TURN) and when a TURN server is needed
- Explain TCP vs. UDP trade-offs and identify which is preferred for gaming, video streaming, and financial transactions respectively

### 📋 Subtopics
- [ ] 13.1 HTTP/1.1 — keep-alive, pipelining, limitations
- [ ] 13.2 HTTP/2 — multiplexing, header compression, server push
- [ ] 13.3 HTTP/3 and QUIC
- [ ] 13.4 WebSockets — full-duplex, handshake, use cases
- [ ] 13.5 Server-Sent Events (SSE) — unidirectional streaming
- [ ] 13.6 Long polling — mechanics and trade-offs
- [ ] 13.7 WebRTC — signaling, ICE, STUN/TURN
- [ ] 13.8 TCP vs. UDP trade-offs

---

## 🕸️ Topic 14 — Service Mesh

> ⏱️ **Recommended Hours: 3h**

### 🎯 Objectives
By the end of this topic, you will understand:
- What a service mesh is and what problems it solves
- The sidecar proxy pattern and how Envoy/Istio implement it
- How mTLS is established between services in a mesh
- Service discovery mechanisms

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain the sidecar proxy pattern: how the data plane (Envoy) and control plane (Istio) interact
- Describe how mTLS is transparently applied to all service-to-service traffic in a mesh without application code changes
- Compare DNS-based service discovery vs. registry-based service discovery (Consul, etcd)
- Identify when a service mesh adds genuine value (large microservice footprint, zero-trust networking) vs. when it is over-engineering
- Explain how a service mesh provides observability (traces, metrics, logs) at the network level

### 📋 Subtopics
- [ ] 14.1 What service meshes solve — observability, security, traffic management
- [ ] 14.2 Sidecar proxy pattern — data plane vs. control plane
- [ ] 14.3 Envoy and Istio — architecture overview
- [ ] 14.4 mTLS — establishment and certificate management in a mesh
- [ ] 14.5 Service discovery — DNS-based vs. registry-based
- [ ] 14.6 Traffic management — circuit breaking, retries, canary routing in a mesh
- [ ] 14.7 When service mesh is and is not appropriate

---

> ### 🔓 Phase D Unlocks
> You are now conceptually equipped to solve:
> - **#7 Distributed Message Queue (Kafka-like)** — T12 delivery guarantees + T7 partitioning + T15 replication (preview)
> - **#8 Web Crawler** — T12 queues + T11 API design + T6 stateless workers

---

---

# 🛡️ PHASE E — Reliability Branch
> The Reliability trunk. Covers how distributed systems stay correct and available under failure: replication, consistency, consensus, and resilience patterns.

---

## 🖥️ Topic 15 — Distributed Storage Systems

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How replication ensures durability and availability in distributed storage
- How quorum-based reads and writes balance consistency and availability
- The role of leader/follower in a storage cluster

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain leader/follower replication, including what happens to reads and writes during a leader failure
- Calculate quorum thresholds (R + W > N) for a given N and explain the consistency and availability trade-off at different R/W values
- Explain the difference between synchronous and asynchronous replication in terms of durability guarantees and write latency
- Design a durable storage system specifying replication factor, quorum settings, and failover behavior
- Explain what replication lag is and how it creates read anomalies

### 📋 Subtopics
- [ ] 15.1 Replication — why and how
- [ ] 15.2 Leader/follower model
- [ ] 15.3 Quorum reads and writes — R + W > N
- [ ] 15.4 Durability guarantees and replication factor
- [ ] 15.5 Synchronous vs. asynchronous replication trade-offs
- [ ] 15.6 Replication lag and read anomalies

---

## 🔁 Topic 16 — Replication Strategies

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The full spectrum of replication models beyond single-leader
- How conflicts arise in multi-leader systems and how to resolve them
- How leaderless replication achieves availability without a single coordinator

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Compare single-leader, multi-leader, and leaderless replication on the dimensions of availability, consistency, and conflict potential
- Explain how write conflicts arise in multi-leader setups and describe conflict resolution strategies: last-write-wins, vector clocks, and CRDTs
- Design a read replica architecture for a read-heavy system: which queries go to replicas, how lag is managed, what happens on failover
- Explain how Dynamo-style leaderless replication works and why it is used in systems like Cassandra and DynamoDB
- Explain replication lag's impact on user experience and describe a read-after-write consistency strategy

### 📋 Subtopics
- [ ] 16.1 Single-leader replication — recap and failure modes
- [ ] 16.2 Multi-leader replication — use cases and conflict potential
- [ ] 16.3 Conflict resolution — LWW, vector clocks, CRDTs
- [ ] 16.4 Leaderless replication — Dynamo-style
- [ ] 16.5 Read replicas — architecture and failover
- [ ] 16.6 Write propagation and replication lag

---

## 🎚️ Topic 17 — Consistency Models

> ⏱️ **Recommended Hours: 6h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The spectrum from strong to eventual consistency and the cost of each
- How consistency models map to real-world system requirements
- Read-after-write consistency and how to achieve it
- How the CAP theorem plays out in practice for real systems

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Place linearizability, sequential consistency, causal consistency, and eventual consistency on a spectrum and explain what each guarantees
- Identify which consistency model is appropriate for a given use case: financial ledger, social media likes, shopping cart, DNS
- Explain read-after-write consistency: when it fails in an eventually consistent system and two approaches to achieve it
- Apply the CAP theorem to a real system (e.g., explain why Cassandra is AP and HBase is CP)
- Explain PACELC in terms of a concrete system trade-off (e.g., choosing lower latency replication at the cost of consistency)

### 📋 Subtopics
- [ ] 17.1 Linearizability (strong consistency)
- [ ] 17.2 Sequential consistency
- [ ] 17.3 Causal consistency
- [ ] 17.4 Eventual consistency
- [ ] 17.5 Read-after-write consistency — failure modes and solutions
- [ ] 17.6 CAP theorem in practice — mapping real systems to CP vs. AP
- [ ] 17.7 PACELC applied to real system choices

---

## 🗳️ Topic 18 — Consensus & Leader Election

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- Why distributed consensus is a hard problem
- How the Raft algorithm achieves consensus at an intuitive level
- What leader election is and why systems need it
- The split-brain problem and how to prevent it

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain the core challenge of distributed consensus: why you can't have both safety and liveness in the presence of network partitions (FLP impossibility intuition)
- Walk through Raft's leader election process: what triggers it, how votes are cast, and how a new leader is established
- Explain how Raft ensures log consistency: what happens when a new leader is elected with a stale log
- Describe split-brain and explain why odd-numbered cluster sizes (3, 5) prevent it
- Distinguish when you need a consensus protocol (e.g., distributed lock, leader election, config management) vs. when simpler approaches suffice

### 📋 Subtopics
- [ ] 18.1 The consensus problem — safety, liveness, FLP impossibility intuition
- [ ] 18.2 Raft — leader election
- [ ] 18.3 Raft — log replication and commitment
- [ ] 18.4 Paxos — intuition and comparison to Raft
- [ ] 18.5 Split-brain — cause and prevention
- [ ] 18.6 When consensus is and is not needed

---

## 🛡️ Topic 19 — Fault Tolerance & Resilience

> ⏱️ **Recommended Hours: 4h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The patterns for making distributed services resilient to partial failures
- How to design retry logic that doesn't amplify failures
- The circuit breaker pattern and when to open/close it
- How to design for graceful degradation

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Design a retry strategy with exponential backoff and jitter, and explain why jitter is necessary to avoid thundering herd on recovery
- Implement circuit breaker logic conceptually: define the three states (closed, open, half-open), set thresholds, and describe the state machine
- Identify all single points of failure in a given architecture and propose a redundancy strategy for each
- Design a system that degrades gracefully: identify the critical path, define what features are non-critical and can be disabled, and describe the fallback behavior
- Explain the bulkhead pattern and how it prevents one failing service from exhausting resources across the entire system

### 📋 Subtopics
- [ ] 19.1 Retries — naive vs. exponential backoff
- [ ] 19.2 Jitter — why it matters and how to add it
- [ ] 19.3 Circuit breaker — states, thresholds, and state machine
- [ ] 19.4 Graceful degradation — critical path vs. non-critical features
- [ ] 19.5 Redundancy patterns — active-active, active-passive
- [ ] 19.6 Bulkhead pattern
- [ ] 19.7 Timeout strategies

---

## 💾 Topic 20 — Backup & Recovery

> ⏱️ **Recommended Hours: 3h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The difference between RPO and RTO and how they drive backup strategy
- The three backup types and when each is used
- Point-in-time recovery and how it works
- Disaster recovery architecture patterns

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Define RPO and RTO, explain the cost-reliability trade-off, and specify target RPO/RTO for a given business requirement (e.g., financial system vs. analytics dashboard)
- Compare full, incremental, and differential backup strategies on cost, storage, and recovery time
- Explain how point-in-time recovery works using a base backup plus WAL/binary log replay
- Design a multi-region disaster recovery architecture with automatic failover, specifying RPO, RTO, and failover trigger conditions
- Explain the difference between backup and replication and when each is necessary

### 📋 Subtopics
- [ ] 20.1 RPO vs. RTO — definitions and business implications
- [ ] 20.2 Full, incremental, and differential backups
- [ ] 20.3 Point-in-time recovery — WAL/binary log replay
- [ ] 20.4 Backup storage — location, encryption, and retention
- [ ] 20.5 Disaster recovery patterns — pilot light, warm standby, active-active
- [ ] 20.6 Backup vs. replication — complementary roles

---

## 🌪️ Topic 21 — Chaos Engineering

> ⏱️ **Recommended Hours: 2h**

### 🎯 Objectives
By the end of this topic, you will understand:
- What chaos engineering is and what class of problems it is designed to find
- How to design a chaos experiment with controlled blast radius
- How chaos engineering fits into an SRE culture

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain what chaos engineering validates that unit and integration tests cannot
- Design a chaos experiment: state the hypothesis, define the steady state, identify the blast radius, describe the failure injection, and specify the rollback trigger
- Explain the Chaos Monkey pattern and what specific failure mode it exercises
- Identify what chaos engineering cannot catch (e.g., logical bugs, data corruption from bad input)
- Explain how gamedays and chaos experiments are used to build confidence in resilience

### 📋 Subtopics
- [ ] 21.1 Chaos engineering principles — hypothesis-driven experimentation
- [ ] 21.2 Chaos Monkey and the Simian Army
- [ ] 21.3 Designing a chaos experiment — steady state, blast radius, rollback
- [ ] 21.4 Failure injection patterns — node kill, network partition, latency injection
- [ ] 21.5 Chaos in production vs. staging
- [ ] 21.6 Gamedays and chaos as an SRE practice

---

> ### 🔓 Phase E Unlocks
> You are now conceptually equipped to solve:
> - **#3 Key-Value Store (full)** — consistent hashing + replication (T15-16) + consistency models (T17)
> - **#4 Distributed Cache (production-grade)** — add replication, failover (T19), and eviction at scale
> - All Phase B and C designs are now production-ready with reliability patterns applied

---

---

# 👁️ PHASE F — Observability Branch
> The Observability trunk. Covers the three pillars of production visibility: logging, metrics, and distributed tracing.

---

## 👁️ Topic 22 — Observability Systems

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The three pillars of observability and how each serves a different debugging need
- How to design a logging strategy for a distributed system
- How metrics, SLOs, and alerting work together
- How distributed tracing connects a request across service boundaries

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain the difference between logging, metrics, and tracing, and describe which you'd use to debug a given production incident
- Design a structured logging strategy for a distributed system: log levels, correlation IDs, sampling, and storage/retention
- Define SLO, SLA, and SLI for a given service, write a concrete SLO (e.g., 99.9% of requests served in <200ms), and design an alert that fires before the SLO is breached
- Explain how distributed tracing works: trace IDs, span propagation across service calls, and how to use a flame graph to find latency hotspots
- Compare counters, gauges, and histograms and describe which metric type is appropriate for request rate, queue depth, and request latency

### 📋 Subtopics
- [ ] 22.1 Logging — structured logging, log levels, correlation IDs
- [ ] 22.2 Log aggregation and storage (ELK Stack, Splunk, Loki)
- [ ] 22.3 Metrics — counters, gauges, histograms, and summaries
- [ ] 22.4 Metrics systems (Prometheus, Grafana, Datadog)
- [ ] 22.5 SLO, SLA, SLI — definitions and alert design
- [ ] 22.6 Distributed tracing — trace IDs, spans, propagation
- [ ] 22.7 Tracing systems (Jaeger, Zipkin, OpenTelemetry)
- [ ] 22.8 Alerting — what to alert on vs. what to log

---

> ### 🔓 Phase F Note
> All prior system designs are now fully observable: you can instrument them with logging, metrics, and tracing and reason about their production behavior.

---

---

# 🔐 PHASE G — Security Branch
> The Security trunk — entirely new coverage. Applies to every system you will ever design.

---

## 🔐 Topic 23 — Security

> ⏱️ **Recommended Hours: 7h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The difference between authentication and authorization
- How OAuth2, JWT, and RBAC work and when to use each
- How TLS protects data in transit and encryption at rest protects stored data
- How DDoS attacks work and the layers of mitigation available

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain the difference between authentication (who are you?) and authorization (what can you do?) and give a concrete example of each failing independently
- Walk through the OAuth2 Authorization Code flow step by step, identifying what each party (client, authorization server, resource server) does
- Explain JWT structure (header, payload, signature), how signature verification works, and the security implications of algorithm confusion attacks
- Design an RBAC system for a multi-tenant SaaS application: define roles, permissions, and the enforcement point in the request path
- Explain the TLS handshake at a conceptual level: what is negotiated, what the certificate proves, and why you need both server and (optionally) client certificates
- Design a DDoS mitigation strategy for a public API: CDN-level blocking, rate limiting at edge, CAPTCHA for suspicious clients

### 📋 Subtopics
- [ ] 23.1 Authentication vs. authorization
- [ ] 23.2 OAuth2 — authorization code flow, client credentials, token refresh
- [ ] 23.3 JWT — structure, signing, validation, and security pitfalls
- [ ] 23.4 RBAC — roles, permissions, policy enforcement points
- [ ] 23.5 API keys — issuance, scoping, rotation
- [ ] 23.6 TLS/SSL — handshake, certificates, mTLS
- [ ] 23.7 Encryption at rest — key management, envelope encryption
- [ ] 23.8 DDoS protection — CDN, rate limiting, CAPTCHA, geo-blocking
- [ ] 23.9 Secrets management (Vault, AWS Secrets Manager)

---

> ### 🔓 Phase G Note
> All prior system designs are now security-hardened. You can discuss auth flows, encryption, and abuse protection as part of any design review.

---

---

# 🏗️ PHASE H — System Archetypes
> Applying all trunk knowledge to six common system patterns that appear repeatedly across real interview problems.

---

## 📰 Topic 24 — Feed / Timeline Systems

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The fan-out problem and the two strategies for solving it
- How to handle high-follower accounts (celebrities) in a fan-out system
- Feed ranking and storage strategies at scale

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Compare fan-out-on-write and fan-out-on-read: explain the write amplification vs. read latency trade-off and choose for a given follower distribution
- Design a hybrid fan-out strategy that handles high-follower accounts differently from normal users
- Design a feed storage model: what gets pre-computed, what is assembled at read time, and what the cache layer looks like
- Estimate the write amplification for a Twitter-scale fan-out system given average and celebrity follower counts
- Describe a feed ranking pipeline: how posts are scored, filtered, and ordered before delivery

### 📋 Subtopics
- [ ] 24.1 Fan-out-on-write — pre-computed feed delivery
- [ ] 24.2 Fan-out-on-read — pull model
- [ ] 24.3 Hybrid fan-out — handling celebrities and high-follower accounts
- [ ] 24.4 Feed storage — timeline tables, Redis sorted sets
- [ ] 24.5 Ranking and scoring pipelines
- [ ] 24.6 Feed pagination and cursor design

---

## 🚦 Topic 25 — Rate Limiting Systems

> ⏱️ **Recommended Hours: 4h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The four major rate limiting algorithms and their behavioral differences
- How to implement distributed rate limiting using Redis
- Rate limiting at multiple layers (edge, gateway, service)

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain token bucket, leaky bucket, fixed window counter, and sliding window log algorithms — describe the burst behavior and edge cases of each
- Implement a sliding window rate limiter using Redis sorted sets: describe the data structure, the increment operation, and the expiry logic
- Design rate limiting at three layers: CDN/edge (IP-level), API gateway (user/app-level), and service (resource-level)
- Explain how to return rate limit information to clients via headers (X-RateLimit-Limit, X-RateLimit-Remaining, Retry-After)
- Design a rate limiter that handles distributed counter consistency across multiple gateway nodes

### 📋 Subtopics
- [ ] 25.1 Token bucket algorithm
- [ ] 25.2 Leaky bucket algorithm
- [ ] 25.3 Fixed window counter
- [ ] 25.4 Sliding window log and sliding window counter
- [ ] 25.5 Distributed rate limiting with Redis
- [ ] 25.6 Rate limiting at CDN, gateway, and service layers
- [ ] 25.7 Client-facing rate limit headers and retry guidance

---

## 🔴 Topic 26 — Realtime Systems

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How to scale WebSocket connections to millions of concurrent users
- How presence systems (online/offline indicators) work at scale
- How event streaming enables realtime updates without polling

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Design a WebSocket-based system at scale: connection routing, session affinity, message fan-out, and reconnection logic
- Choose between WebSockets, SSE, and long polling for a given realtime use case (chat, live feed, notifications) with clear reasoning
- Design a presence system for a messaging app: how online status is tracked, how it is propagated to subscribers, and how stale state is handled
- Explain how a pub/sub layer (e.g., Redis Pub/Sub or Kafka) is used to fan-out realtime events across multiple connection servers
- Estimate the number of WebSocket connection servers required given concurrent user count and memory per connection

### 📋 Subtopics
- [ ] 26.1 WebSockets at scale — connection servers, session affinity
- [ ] 26.2 Message fan-out across connection servers using pub/sub
- [ ] 26.3 Long polling — mechanics and resource implications
- [ ] 26.4 SSE — use cases and limitations
- [ ] 26.5 Presence systems — tracking, propagation, and TTL-based expiry
- [ ] 26.6 Reconnection logic and message deduplication

---

## 🔔 Topic 27 — Notification Systems

> ⏱️ **Recommended Hours: 4h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The end-to-end push notification flow from service to device
- How fan-out to millions of subscribers is handled efficiently
- Delivery guarantees and deduplication strategies

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Walk through the complete push notification flow: app server → notification service → APNs/FCM → device
- Design a fan-out architecture that sends a notification to 10M users within a time budget, including queue partitioning and worker scaling
- Design at-least-once delivery with client-side deduplication using a notification ID
- Handle notification preferences: per-channel opt-out, quiet hours, batching, and digest delivery
- Explain how notification delivery receipts and read status are tracked at scale

### 📋 Subtopics
- [ ] 27.1 Push notification architecture — APNs and FCM
- [ ] 27.2 Fan-out strategies for large subscriber bases
- [ ] 27.3 Delivery guarantees and at-least-once with deduplication
- [ ] 27.4 Notification preferences — opt-out, quiet hours, batching
- [ ] 27.5 Delivery receipts and read status tracking
- [ ] 27.6 Email and SMS notification channels

---

## 🔒 Topic 28 — Distributed Locking & Coordination

> ⏱️ **Recommended Hours: 4h**

### 🎯 Objectives
By the end of this topic, you will understand:
- When distributed locking is necessary and when it can be avoided
- How to implement a distributed lock correctly using Redis
- The role of fencing tokens in preventing stale lock issues
- How ZooKeeper and etcd are used for distributed coordination

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain why a naive distributed lock using SET NX in Redis is insufficient for certain failure scenarios
- Walk through the Redlock algorithm: why multiple Redis nodes are used, what the quorum condition is, and what failure modes remain
- Explain fencing tokens: what they are, how they prevent stale lock holders from corrupting state, and how the storage layer enforces them
- Describe three use cases for ZooKeeper or etcd: leader election, distributed config, and service registry
- Identify scenarios where distributed locking can be eliminated by redesigning with idempotency and optimistic concurrency control

### 📋 Subtopics
- [ ] 28.1 When distributed locking is needed
- [ ] 28.2 Redis SET NX — naive lock and its failure modes
- [ ] 28.3 Redlock algorithm — multi-node quorum locking
- [ ] 28.4 Fencing tokens — preventing stale lock holders
- [ ] 28.5 ZooKeeper and etcd — use cases and architecture overview
- [ ] 28.6 Alternatives to locking — idempotency and optimistic concurrency

---

## ⚙️ Topic 29 — Background Processing Systems

> ⏱️ **Recommended Hours: 4h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How job queues are designed with priorities and retry logic
- How distributed schedulers (cron-like) work
- How worker pools scale dynamically

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Design a job queue with priority levels, retry logic, and a dead-letter queue for persistently failing jobs
- Design an idempotent job: explain what makes a job safe to retry and how the worker enforces exactly-once execution semantics
- Design a distributed cron scheduler: how job definitions are stored, how the scheduler avoids double-firing on multi-node deployments, and how missed runs are handled
- Design a dynamic worker pool that scales based on queue depth, specifying the scale-up and scale-down triggers
- Handle partial completion in a long-running job: checkpointing, resumability, and progress tracking

### 📋 Subtopics
- [ ] 29.1 Job queue design — data model and enqueueing
- [ ] 29.2 Priority queues
- [ ] 29.3 Retry logic and dead-letter queues
- [ ] 29.4 Idempotent jobs — design for safe retry
- [ ] 29.5 Distributed cron scheduler — avoiding double-fire
- [ ] 29.6 Worker pool scaling — queue depth as signal
- [ ] 29.7 Job checkpointing and partial completion

---

> ### 🔓 Phase H Unlocks
> You are now conceptually equipped to solve:
> - **#9 Twitter / X Feed** — fan-out (T24) + caching (T4) + realtime (T26)
> - **#10 Facebook News Feed** — hybrid fan-out (T24) + ranking + feed storage
> - **#11 WhatsApp / Chat System** — realtime (T26) + presence (T26) + message storage (T8) + delivery guarantees (T12)
> - **#12 Live Streaming (Twitch)** — realtime (T26) + media systems preview + CDN (T5)
> - **#13 Notification System** — T27 end-to-end
> - **#14 Distributed Job Scheduler** — T29 + distributed locking (T28) + consensus (T18)

---

---

# 🔍 PHASE I — Search & Location Systems

---

## 🔍 Topic 30 — Search Systems

> ⏱️ **Recommended Hours: 6h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How an inverted index is built and queried
- How search results are ranked using term frequency and relevance signals
- How a search indexing pipeline processes incoming documents
- How autocomplete/typeahead systems work

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain how an inverted index is constructed from a document corpus: tokenization, normalization, posting lists
- Describe how a query is resolved against an inverted index: lookup, intersection, and scoring
- Explain TF-IDF at a conceptual level and describe one way BM25 improves on it
- Design a typeahead/autocomplete system: data structure (trie or sorted prefixes), storage, ranking, and low-latency serving
- Design a search indexing pipeline: ingestion, parsing, enrichment, indexing, and handling document updates and deletions

### 📋 Subtopics
- [ ] 30.1 Inverted index — construction and structure
- [ ] 30.2 Tokenization, stemming, and normalization
- [ ] 30.3 Query processing — lookup, intersection, ranking
- [ ] 30.4 TF-IDF and BM25 — relevance scoring concepts
- [ ] 30.5 Search indexing pipeline — ingestion to query readiness
- [ ] 30.6 Handling document updates and deletes
- [ ] 30.7 Autocomplete / typeahead — trie, ranked prefix search
- [ ] 30.8 Fuzzy matching and typo tolerance

---

## 🗂️ Topic 31 — Massive Distributed Search

> ⏱️ **Recommended Hours: 4h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How search indexes are sharded and replicated at web scale
- How query serving achieves low latency under high QPS
- How index freshness is balanced against query latency

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Design a distributed search index: how documents are sharded, how queries are scatter-gathered across shards, and how results are merged
- Explain the trade-off between index freshness and query latency: how near-real-time indexing (e.g., Elasticsearch's refresh interval) creates a freshness window
- Design a query serving layer that handles ranking, filtering, and pagination at low latency
- Describe how a web-scale crawl-index-serve pipeline works end to end (crawling → parsing → indexing → query serving)
- Explain how Elasticsearch's segment-based architecture supports both write throughput and query performance

### 📋 Subtopics
- [ ] 31.1 Distributed indexing — sharding strategies for search
- [ ] 31.2 Scatter-gather query execution
- [ ] 31.3 Result merging and re-ranking across shards
- [ ] 31.4 Index freshness vs. query latency trade-off
- [ ] 31.5 Segment-based index architecture (Lucene / Elasticsearch model)
- [ ] 31.6 Web-scale crawl-index-serve pipeline overview

---

## 📍 Topic 32 — Location & Geospatial Systems

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How geospatial indexes enable proximity search at scale
- How real-time location tracking works for high-frequency updates
- How map tile serving handles global geographic data efficiently

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain geohashing: how a coordinate is encoded as a string, how precision relates to cell size, and how neighboring cells are queried
- Explain quadtree indexing and compare it to geohashing for the use case of finding nearby drivers
- Design a "find nearby drivers" system (Uber-style): location update flow, indexing, querying, and scaling to millions of active drivers
- Design a map tile serving system: how the world is divided into tiles at multiple zoom levels, how tiles are generated and cached, and how CDN accelerates delivery
- Explain the H3 hexagonal indexing system and why uniform cell area matters for density-based analytics

### 📋 Subtopics
- [ ] 32.1 Geohashing — encoding, precision, and neighbor queries
- [ ] 32.2 Quadtree indexing — structure and range queries
- [ ] 32.3 H3 hexagonal indexing — uniform area and hierarchical queries
- [ ] 32.4 Proximity search at scale — "find nearby X" pattern
- [ ] 32.5 Real-time location updates — high-frequency write design
- [ ] 32.6 Map tile serving — zoom levels, tile generation, CDN caching
- [ ] 32.7 Routing algorithms overview (Dijkstra, A*, contraction hierarchies)

---

> ### 🔓 Phase I Unlocks
> You are now conceptually equipped to solve:
> - **#15 Google Search** — T30 + T31 (distributed indexing at scale)
> - **#16 Search Autocomplete / Typeahead** — T30.7 (trie + ranked prefix)
> - **#17 Uber / Lyft** — T32 (location indexing + realtime tracking) + T26 (realtime updates)
> - **#18 Google Maps** — T32 (tile serving + geospatial) + T5 (CDN)

---

---

# 📊 PHASE J — Data & Analytics Systems

---

## 🌊 Topic 33 — Stream Processing Systems

> ⏱️ **Recommended Hours: 6h**

### 🎯 Objectives
By the end of this topic, you will understand:
- Kafka's architecture and how it achieves high throughput with ordering guarantees
- How stream processing frameworks (Flink, Spark Streaming) handle stateful computation
- Windowing strategies and how to handle late-arriving data

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain Kafka's topic/partition/consumer-group model: how partitioning enables parallelism, and how consumer group offsets enable at-least-once delivery
- Explain how Kafka achieves high throughput: sequential disk I/O, zero-copy, batch compression
- Design a real-time analytics pipeline using Kafka and Flink for a given use case (e.g., real-time fraud detection, live view counts)
- Explain tumbling, sliding, and session windows with a concrete example of each
- Describe how late-arriving data is handled: watermarks, grace periods, and the out-of-order event problem

### 📋 Subtopics
- [ ] 33.1 Kafka architecture — brokers, topics, partitions, consumer groups
- [ ] 33.2 Kafka throughput — sequential I/O, zero-copy, compression
- [ ] 33.3 Flink / Spark Streaming — stateful stream processing
- [ ] 33.4 Windowing — tumbling, sliding, session
- [ ] 33.5 Watermarks and late-arriving data
- [ ] 33.6 Stream-table joins and stateful operators
- [ ] 33.7 Real-time pipeline design patterns

---

## 🏭 Topic 34 — Batch Processing Systems

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How MapReduce processes large datasets through map and reduce phases
- How ETL and ELT pipelines are designed for data warehouses
- How batch jobs handle failure, partial completion, and reprocessing

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain MapReduce with a non-trivial example: describe the map phase, shuffle/sort phase, and reduce phase for a log analytics problem
- Design an ETL pipeline from raw event logs to a cleaned analytics table, specifying each transformation stage and failure handling
- Explain the difference between ETL and ELT and when each is appropriate for cloud data warehouses
- Design a daily batch job that processes 1TB of data: partitioning strategy, parallelism, checkpointing, and idempotent reprocessing
- Explain how data lineage and data quality checks are incorporated into a batch pipeline

### 📋 Subtopics
- [ ] 34.1 MapReduce — map phase, shuffle/sort, reduce phase
- [ ] 34.2 Spark — RDDs, DAG execution, shuffle optimization
- [ ] 34.3 ETL pipeline design — extraction, transformation, loading
- [ ] 34.4 ETL vs. ELT — when each applies
- [ ] 34.5 Batch job failure handling — checkpointing and idempotent reprocessing
- [ ] 34.6 Data quality checks and lineage
- [ ] 34.7 Scheduling batch pipelines (Airflow overview)

---

## 🎯 Topic 35 — Recommendation Systems

> ⏱️ **Recommended Hours: 6h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The two-stage recommendation pipeline (retrieval → ranking)
- How collaborative filtering and content-based filtering work
- What a feature store is and why the offline/online split matters
- How to handle the cold-start problem

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Describe the two-stage recommendation pipeline: why retrieval (fast, coarse) and ranking (slow, fine-grained) are separated
- Explain collaborative filtering: user-based vs. item-based, and how matrix factorization enables it at scale
- Explain content-based filtering and describe a use case where it outperforms collaborative filtering
- Design a feature store: what features are stored, how offline (batch) and online (low-latency) serving differ, and how consistency between training and serving is maintained
- Describe two approaches to the cold-start problem (new user, new item) and explain the trade-offs

### 📋 Subtopics
- [ ] 35.1 Two-stage pipeline — retrieval and ranking
- [ ] 35.2 Collaborative filtering — user-based and item-based
- [ ] 35.3 Matrix factorization and embeddings
- [ ] 35.4 Content-based filtering
- [ ] 35.5 Feature store — offline vs. online serving
- [ ] 35.6 Cold-start problem and mitigation strategies
- [ ] 35.7 A/B testing and experimentation for recommendations

---

## 🤖 Topic 36 — ML Infrastructure Systems

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How model serving systems are architected for low-latency inference
- The full ML training pipeline from data to deployed model
- How to safely deploy model updates (shadow deployment, canary)
- How feature store consistency between training and serving is maintained

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Design a model serving system with versioning, rollback capability, and A/B traffic splitting
- Explain the difference between online inference (synchronous, low-latency) and batch inference (asynchronous, high-throughput) and choose for a given use case
- Walk through an ML training pipeline: feature engineering, training job, evaluation, registration, and deployment
- Explain shadow deployment and canary deployment for ML models and describe how production metrics are used to validate a new model
- Explain the training-serving skew problem: what causes it, how a feature store prevents it

### 📋 Subtopics
- [ ] 36.1 Model serving — versioning, rollback, and traffic splitting
- [ ] 36.2 Online vs. batch inference
- [ ] 36.3 Training pipeline — feature engineering to model registry
- [ ] 36.4 Shadow deployment and canary deployment for ML
- [ ] 36.5 Training-serving skew — causes and prevention
- [ ] 36.6 Model monitoring — data drift and performance degradation

---

> ### 🔓 Phase J Unlocks
> You are now conceptually equipped to solve:
> - **#19 YouTube (full)** — blob storage (T9) + CDN (T5) + stream processing (T33) + recommendation pipeline (T35-36)
> - **#20 TikTok / Video Recommendation** — recommendation (T35) + ML infra (T36) + feed system (T24) + stream processing (T33)

---

---

# 🚀 PHASE K — Advanced Distributed Systems
> The most complex tier. These topics handle global scale, cross-service correctness, and specialized media delivery.

---

## 🗺️ Topic 37 — Global Multi-Region Systems

> ⏱️ **Recommended Hours: 4h**

### 🎯 Objectives
By the end of this topic, you will understand:
- The architectures for deploying a system across multiple geographic regions
- How conflict resolution works in active-active multi-region setups
- How latency-based routing directs traffic to the nearest healthy region

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Compare active-active and active-passive multi-region architectures on availability, cost, and complexity
- Explain the write conflict problem in active-active geo-replication and describe how CRDTs or LWW handle it
- Design a DNS-based latency routing system using health checks and weighted failover
- Describe a concrete data sovereignty challenge in multi-region design and how it constrains region placement
- Design a multi-region failover runbook: what triggers failover, how traffic is rerouted, and how data consistency is maintained during the switchover

### 📋 Subtopics
- [ ] 37.1 Active-active vs. active-passive multi-region architectures
- [ ] 37.2 Geo-replication — data consistency and conflict resolution
- [ ] 37.3 Latency-based and geo-aware routing
- [ ] 37.4 Multi-region failover — triggers, traffic cutover, data sync
- [ ] 37.5 Data sovereignty and compliance constraints
- [ ] 37.6 Cost trade-offs of multi-region deployments

---

## 💳 Topic 38 — Distributed Transactions

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- Why distributed transactions are hard and why 2PC is rarely used at scale
- How the Saga pattern provides a practical alternative
- The difference between choreography and orchestration in Saga design

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Explain two-phase commit: the prepare phase, commit phase, and the blocking failure scenario that makes it impractical for high-availability systems
- Design a Saga for a distributed transaction (e.g., e-commerce order: reserve inventory → charge payment → dispatch fulfillment) using the orchestration pattern
- Write the compensation logic for each step: what happens when payment fails after inventory is reserved
- Compare choreography (event-driven) and orchestration (central coordinator) Sagas and explain when each is appropriate
- Explain how idempotency is critical for Saga steps to handle retries correctly

### 📋 Subtopics
- [ ] 38.1 Two-phase commit — protocol and failure modes
- [ ] 38.2 Why 2PC is avoided at scale
- [ ] 38.3 Saga pattern — definition and motivation
- [ ] 38.4 Choreography-based Saga — event-driven coordination
- [ ] 38.5 Orchestration-based Saga — central coordinator
- [ ] 38.6 Compensation logic — designing rollback steps
- [ ] 38.7 Idempotency in Saga steps

---

## 🎬 Topic 39 — Large Media Systems

> ⏱️ **Recommended Hours: 5h**

### 🎯 Objectives
By the end of this topic, you will understand:
- How video upload and transcoding pipelines work at scale
- How adaptive bitrate streaming (HLS/DASH) works and why it improves user experience
- How live streaming achieves low end-to-end latency
- How CDN is integrated for global video delivery

### ✅ Mastery Criteria
You have mastered this topic when you can:
- Design a video upload pipeline: chunked upload, storage, queuing for transcoding, and status tracking
- Explain adaptive bitrate streaming (HLS/DASH): how segments are generated at multiple bitrates, how the client manifest works, and how the player selects bitrate based on bandwidth
- Explain the latency sources in a live streaming pipeline (capture → encode → ingest → transcode → CDN → player) and identify which stages dominate
- Design a transcoding pipeline that parallelizes work across multiple worker nodes and handles failures gracefully
- Explain how a CDN handles video delivery at scale: segment caching, cache hit rate optimization, and edge-to-origin request reduction

### 📋 Subtopics
- [ ] 39.1 Video upload pipeline — chunked upload and storage
- [ ] 39.2 Transcoding pipeline — parallelism and job management
- [ ] 39.3 Adaptive bitrate streaming — HLS and DASH
- [ ] 39.4 Video segment caching at CDN
- [ ] 39.5 Live streaming pipeline — latency sources and optimization
- [ ] 39.6 Resumable uploads and fault-tolerant ingestion
- [ ] 39.7 WebRTC for ultra-low-latency live video

---

> ### 🔓 Phase K Unlocks
> You are now equipped to tackle any FAANG-level system design:
> - Multi-region variants of all 20 canonical problems
> - Payment and financial transaction systems (T38 Sagas + T17 consistency)
> - Global video platforms at YouTube/Netflix scale (T39 + T5 CDN + T33 stream processing)

---
