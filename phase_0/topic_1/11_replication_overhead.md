# 🧠  Subtopic 11 — Replication Overhead

* * *


# 0. 🎯 Goal of This Subtopic

Be able to correctly account for replication multipliers in:

* storage estimation
* bandwidth estimation
* write amplification
* cost estimation

* * *


## 🏆 What Mastery Looks Like

You have mastered this subtopic when you can:

* Instantly apply replication factors (2x, 3x, etc) without forgetting
* Distinguish between:
    * Data Replication
    * Index Replication
    * Log Replication
* Explain why replication exists (not just multiply blindly)
* Adjust replication based on:
    * durability requirements
    * system type (DB vs cache vs logs)
* Catch common mistakes:
    * forgetting replication
    * double counting replication
    * applying replication to stateless services

* * *

# 1. 🧾 Cheat Sheet

```
# 🧠 Replication Overhead Cheat Sheet

# Core rule
Replication = multiply everything that is stateful

# Default assumptions
Replication factor = 3x (unless stated)

# Storage
Total Storage = Raw × Replication

# With index
Total Storage = Raw × Index × Replication

# Write amplification
Actual Write = Incoming Write × Replication

# Network overhead
Replication Traffic = Write × (Replication - 1)

# Applies to
✔ Databases
✔ Logs (Kafka)
✔ Search indexes
✔ Distributed storage

# Does NOT apply to
✘ Stateless services (API servers)
✘ Load balancers

# Typical values
DB replication = 3x
Kafka replication = 3x
Search replicas = 2–3x

# Interview shortcut
"Assume 3x replication unless specified"

# Mental model
Replication = durability + availability tradeoff vs cost
```

* * *


# 2. 🧩 Core Concepts

## 2.1 Replication  = Redundancy for Reliability

Definition

>Replication = storing multiple copies of the same data across nodes


Why it exists?

* Durability (data not lost)
* Availability (serve reads if node fails)
* Fault tolerance(survive machine / AZ failure)

Mental Model

```
No replication -> fragile system
Replication -> resilient system (but expensive)
```



## 2.2 Replication Multiplies Everything

Core Rule

```
Replication Factor (RF) multiplies ALL stateful resources
```

Applies to:

* Storage
* Write throughput
* Network traffic

Does NOT apply to:

* Stateless compute (API servers, load balancers)



## 2.3 Storage Overhead

Concept

>You store the same data multiple times


Formula

```
Total Storage = Raw Data x Replication Factor
```

Why it matters

* Dominates cost estimation
* Critical for capacity planning



## 2.4 Write Amplification

Concept

>Every write is executed multiple times


Formula

```
Actual Writes = Incoming Writes x Replication Factor
```

Why it matters

* Disk IO per second increases
* CPU usage increases
* Bottleneck often shifts to write path

Real-world tie

* Kafka: leader writes → followers replicate
* Cassandra: writes to multiple replicas



## 2.5 Network Amplification

Concept

>Replication creates internal network traffic


Formula

```
Replication Traffic = Write x (RF - 1)
```

Why it matters

* Internal bandwidth often exceeds external traffic
* Becomes bottleneck in large systems



## 2.6 Replication Factor (RF)

Definition

```
RF = number of copies of data
```

Typical Values

|System 	|RF	|
|---	|---	|
|
Kafka	|3	|
|
Cassandra	|3	|
|
HDFS	|3	|
|
MySQL replicas	|
2–3	|

Why RF=3 is standard

* 1 node can fail safely
* quorum still works (⅔)
* good durability vs cost balance



## 2.7 State vs Stateless Boundary

Critical distinction

```
Replication ONLY applies to stateful components
```

Stateful (replicate)

* databases
* logs
* storage systems
* search indexes

Stateless (DO NOT replicate)

* API servers
* load balancers
* workers



## 2.8 Combined Overhead (Realistic Systems)

Replication rarely exists alone.

Full Formula

```
Total Size = Raw Data x Index Overhead x Replication
```

Example:

```
Raw = 1 TB
Index = 3x
Replication = 3x
Total = 9 TB
```

Why this matters

* Real systems are not just x3
* Often 6x - 15x expansion



## 2.9 Tradeoff: Cost vs Reliability

Fundamental tradeoff

More Replication
Pros:

* Safer
* Available

Cons:

* Expensive

Less Replication
Pros:

* Cheaper
* Faster Writes

Cons:

* Risky

Insight:
Replication is a business decision, not just technical


## 2.10 Failure Model Awareness

Replication assumes failures:

* node crash
* disk failure
* AZ outage

Replication is useless unless:

* copies are independent
* copies are geographically distributed

## 2.11 Default Assumption Heuristic

In interviews:

```
If not specified -> assume RF = 3
```

Why?

* Industry standard
* Shows experience
* Avoids underestimation



## 2.12 5 Things You Must Say in Interviews

If replication is relevant, you should explicitly mention:

1. “Assume 3x replication for durability and reliability”
2. “Storage becomes X x 3”
3. “Write throughput is also multiplied by 3”
4. “This adds internal network overhead”
5. “Applies only to stateful systems”



## 2.13 What is Quorum?

Definition

>Quorum = minimum number of nodes that must agree for an operation to succeed


In replication systems

* You don’t need all replicas
* You only need a subset(quorum)

```
Total replicas = N

Write quorum = W nodes must acknowledge write
Read quorum = R nodes must respond for read
```

Rule:

```
W + R > N
```

A system has strong **consistency** if W + R node overlaps is more than the replica count.

Why this rule exists?

* Guarantees read sees latest write

Because:

* at least one node overlaps
* that node has the latest data


Case 1 - Strong consistency

```
W = 2
R = 2

W + R = 4 > 3 ✅
```

What happens:

* write goes to 2 nodes
* read queries 2 nodes
* At least 1 node overlaps → fresh data

Case 2 - Weak consistency

```
W = 1
R = 1

W + R = 2 ≤ 3 ❌
```

What happens:

* Write may hit node A
* Read may hit node B
* B may not have latest data → stale read

### Common Configurations

Strong Consistency

```
N=3
W=2
R=2
```

Write Optimized

```
N=3
W=1
R=3
```

Read Optimized

```
N=3
W=3
R=1
```

* * *


# 3. ⚙️ Mental Models

Where replication applies

|Layer	|Replicated?	|Why	|
|---	|---	|---	|
|
Database	|✅ Yes	|durability	|
|
Logs / Kafka	|✅ Yes	|replay + fault tolerance	|
|
Search index	|✅ Yes	|availability	|
|
Cache	|⚠️ Sometimes	|failover	|
|
Stateless API	|❌ No	|no data	|

⚡ Golden Rule

**Only replicate stateful data**
* * *


# 4. 🧠 Intuition

## 4.1 Replication impacts:

### Latency (sync vs async)

Sync replication

* write must wait for multiple replicas (W nodes)
* Latency = slowest replica (tail latency)
* ❌ Higher latency
* ✅ Stronger guarantees

Async replication

* Write returns after primary only
* Replicas updated later
* ✅ Low latency
* ❌ Risk of data loss / stale reads

### Consistency guarantees

Strong consistency requires:

```
W + R > N
```

Sync Replication → easier to guarantee consistency
Async Replication → eventual consistency
More replicas != strong consistency (depends on quorum)


### Failure modes

With replication

* Can tolerate node failures (depends on RF)
* Reads can be served from replicas
* System remains available



### Write amplification bottlenecks

* Every write → RF writes
* Bottlenecks:
    * network(replication traffic)
    * disk (multiple writes)
    * coordination(quorum/sync)

* * *


# 5. ⚡ Patterns

## 5.1 Storage Replication

Formula

```
Total Storage = Raw Data x Replication Factor
```

Example

```
Raw = 10 TB
Replication = 3x
Total = 30 TB
```



## 5.2 Write Amplification

Replication multiplies writes.

Formula

```
Effective Write Throughput = Incoming Writes x Replication Factor
```

Why this matters

* Leader writes → followers replicate
* Network + disk load increases

Example

```
Incoming = 100MB/s
Replication = 3

Actual system load = 300MB/s
```



## 5.3 Network Overhead

Replication = internal traffic explosion

```
Network = Write Bandwidth × (Replication Factor - 1)
```

Example

```
Write = 100MB/s
Replication = 3

Extra network = 200MB/s
```



## 5.4 Index + Metadata Overhead

Often overlooked

```
Total = Raw × Index Multiplier × Replication
```

Typical

* index: 2-5x
* replication: 2-3x

Example

```
Raw = 1TB
Index = 3x
Replication = 3x

Total = 9TB
```

* * *


# 6. ⚠️ Common Pitfalls

## Mistake 1 - Forgetting replication

## Mistake 2 - Replicating stateless services

Wrong:

```
API servers x 3 for replication
```

Correct:

* API scaling = load-based, not replication

## Mistake 3 - Double counting replication

Example:

```
Raw × 3 (replication)
Then × 3 again (incorrect)
```

## Mistake 4 - Ignoring write amplification

You size storage but forget:

* disk throughput
* network bandwidth

* * *

# 7. Step by Step Interview Template

## 1. Estimate raw data

## 2. Apply index multiplier

## 3. Apply replication factor 

## 4. Apply growth/retention



## Verbal Template

Use this every time:

```
"We have X raw data. Assuming 3x replication for durability, that becomes 3X.
If we include indexing overhead (~2x), total storage becomes ~6X."
```



# 7. 🧪 Q & A

1. Why does replication increase network traffic?

Replication increases network traffic because every write must be propagated to other nodes over the network. So instead of 1 write, we now have RF writes, most of which are inter-node network transfers.

* Replication is cross-node communication
* Writes must be shipped over the network to replicas



1. Why is RF=3 better than RF=2?

With RF=3, we can tolerate 1 failure and still maintain quorum (⅔). With RF=2, losing 1 node leaves only 1 copy, so no quorum is possible. RF=3 is the smallest number that supports both fault tolerance and quorum-based consistency.

1. Does replication affect read QPS?

Yes - Replication increases read QPS because reads can be distributed across replicas. Instead of one node handling all reads, multiple replicas can serve them in parallel.

Key insight

```
Replication:
- hurts writes ❌
- helps reads ✅
```

This is very important in system design.

1. When would you choose RF=1?

When data is non-critical, easily recomputable, or ephemeral(eg. caches, temporary data), we can use RF=1 to reduce cost and improve write performance.


1. Why can replication become the write bottleneck?

Replication bottlenecks come from:

* Synchronous replication latency
* Slowest replica determines write latency
* Network + disk contention

Replication can become a bottleneck because each write must be propagated to multiple replicas. In synchronous systems, the write latency is determined by slowest replica. This increases latency and puts pressure on network and disk throughput.
* * *

