# 🧠 Subtopic 9 - Server Count Estimation

* * *


## 0. 🎯 Goal of This Subtopic

By the end of this subtopic, you should be able to:

* Convert system load → number of machines
* Estimate servers for:
    * stateless services (API servers)
    * storage systems
    * caches
* Apply real-world constraints:
    * CPU limits
    * Memory limits
    * Network limits
* Include headroom + redundancy
* Do all of the above in <2 minutes verbally

* * *

### 🏆 What Mastery Looks Like

You have mastered this subtopic when you can confidently answer:

* “We need ~120 API servers based on QPS and CPU limits”
* “Storage requires ~300 nodes given disk + replication”
* “Cache cluster needs ~50 nodes for 2TB hot data”
* “We add 30% buffer → final = 160 servers”

You must be able to justify your numbers clearly and quickly
* * *

## 1. 🧾 Cheat Sheet

```
# Core Formula
Servers = Total Load / Per-Server Capacity

# Identify Bottleneck
CPU -> QPS-based
Memory -> Cache
Disk -> Storage
Network -> Bandwidth

# 3. QPS-based (API servers)
1 server = 1K-5K QPS

Servers = Total QPS / QPS per server

# 4. Memory-based (Cache)
1 server = 50 GB RAM

Servers = Cache Size / RAM per server

# 5. Storage-based (DB)
1 server = 2 - 10 TB

Servers = Total Storage / Disk per server

# 6. Replication
Total Storage = Raw x replication factor

# 7. Headroom
Final = servers x 1.3-2.0

# 8. Sanity Check
- Too few (<5)? suspicious
- Too many (>10K)? check assumptions

# 9. Common Defaults
CPU utilization target: 50 - 70%
Cache usable memory: ~70% of RAM
Disk usable: ~70-80%

# 10. Golden Rule
Better to slightly overestimate than underestimate
```

* * *

## 2. 🧩 Core Concepts

Server count is always:

```
Server Count = Total Load / Capacity per Server
```

The real skill is:

* figuring out what “capacity per server” means

* * *


## 3. ⚙️ Key Formulas / Mental Models

### Key Insight

Server count is NEVER exact, nor does the number actually matter.

What matters is:

* clear assumptions
* correct bottleneck
* reasonable magnitude


The 3 Types of Server Estimation:

### 3.1. QPS-based (CPU bound systems)

Used for:

* API servers
* stateless services
* web servers

```
Servers = Total QPS / QPS per server
```

Dd Not:

* apply replication

### 3.2. Storage-based (disk-bound systems)

Used for:

* databases
* object storage

```
Servers = Total Storage / Storage per server
```



### 3.3. Memory-based (RAM-bound systems)

Used for:

* caches (Redis / Memcached)

```
Servers = Total Cache Size / Memory per server
```

* * *


## 4. 🧠 Step-by-Step Framework

### Step 1 - Identify bottleneck

Ask:

* CPU? → QPS-based
* Memory? → cache
* Disk? → storage
* Network? → bandwidth

### Step 2 - Estimate total load

From previous subtopics:

* QPS
* Data size
* Bandwidth
* Cache size

### Step 3 - Estimate per-server capacity

Use standard assumptions

|Resource	|Typical assumption	|
|---	|---	|
|
API server	|
1K–10K QPS	|
|
Cache node	|
10–100 GB RAM	|
|
DB node	|
1–10 TB	|
|
Network	|
1–10 Gbps	|

### Step 4 - Add headroom

Real systems are not expected to run at 100% capacity. Always add for unforeseen issues:

```
Final = raw_servers x (1.3 ~ 2.0)
```

Why?

* traffic spikes
* uneven distribution
* failures

### Step 5 - Add redundancy

* replication
    * Replication improves durability and availability, not throughput capacity of stateless compute.
    * Use replication ONLY when:
        * data is stored multiple times
        * the problem explicitly says replication/redundancy
        * cache redundancy is specified
    * DO NOT APPLY replication to:
        * stateless API fleets
        * pure CPU sizing
        * pure bandwidth delivery fleets
* failover
* multi-AZ

* * *


## 5. ⚡ Patterns & When to Use

### Rule 1 - API Servers

```
1 server ≈ 1K–5K QPS
```

### Rule 2 - Cache

```
1 server ≈ 50 GB RAM usable
```

### Rule 3 - Storage

```
1 server ≈ 2–10 TB usable
```

### Rule 4 - Always add 30~100% buffer

* * *


## 6. ⚠️ Common Pitfalls

### ❌ 6.1 Ignoring bottleneck

Using QPS when system is memory-bound


### ❌ 6.2 No headroom

Real systems NEVER run at 100%


### ❌ 6.3 Unrealistic server capacity

Saying 1 server = 1M QPS


### ❌ 6.4 Mixing units

QPS vs MB/s vs TB


### ❌ 6.5 Forgetting replication

3x replication → 3x servers
* * *


## 7. **📦 Examples**

### Example: API Service

* 100K QPS
* 1 server handles 2K QPS

```
Servers = 100K / 2k = 50
// assume 1.5x buffer
With buffer -> 75 servers
```

### Example: Cache

* 2 TB hot data
* 50 GB per node

```
Servers = 2000 GB / 50 = 40
With buffer -> 60 nodes
```

### Example: Storage

* 300 TB data
* 3x replication → 900 TB
* 5 TB per server

```
Servers = 900 / 5 = 180
```

* * *

## 8. Quiz

```
1.  Why is server count estimation fundamentally about identifying the bottleneck resource, not just dividing total load?
The bottleneck resource is what actually affects the reliability and scalability of the system. Identifying the correct bottleck resource and optimizing for it gives you the highest returns on your investments.
-> Because throughput is limited by the slowest resource
Adding more servers only helps if that resource is the constraint
2.  In what situations would QPS-based estimation give you a completely wrong answer?
If your system is storage, bandwidth or memory based, sizing servers with QPS-based estimation will not address the system bottleneck adequetely.
3.  Why can two systems with the same QPS require drastically different numbers of servers?
It's likely the 2 systems have different bottleneck resource. One could be CPU bound while the other could be Disk bound.
->  •   request complexity matters
    •   payload size matters
    •   read vs write matters
👉 Example:
    •   100K QPS (1KB reads) vs 100K QPS (1MB writes) → huge difference
4.  What does “capacity per server” actually depend on in real systems?
It depends on what we define capacity as in a server. it could be CPU compute capability, RAM size, Bandwidth size, Disk size and/or a mix of these different resources.
5.  Why is it dangerous to assume a fixed number like “1 server = 5K QPS” without context?
1 server = 5K QPS is making the assumption that we are dealing with a CPU-bound system where traffic is the bottleneck requirement. This may not be true in a Disk bound, Memory bound or Bandwidth bound system.
6.  How do you determine whether a system is:
•   CPU-bound -> a system serving API request/response traffic and is measured by QPS
•   memory-bound -> a system serving hot data as its primary responsibility
•   disk-bound -> a system mainly used as data storage 
•   network-bound -> a system that is reliant on the throughput of its data streaming over the network
👉 Real detection:
    •   CPU-bound → CPU ~80–100%
    •   Memory-bound → OOM / cache misses
    •   Disk-bound → high I/O wait
    •   Network-bound → bandwidth saturation
7.  Give an example where:
•   CPU is NOT the bottleneck, even with high QPS
Let's say we have a video streaming service where we continuously stream data over the network to end users. The reliability of the service is network bound rather than CPU bound. Because the service's throughput affects how smooth its video data is streamed over the network, of which is determined by its bandwidth size. 
8.  Why are cache systems almost always memory-bound instead of CPU-bound?
Cache based systems relies on fast retrieval of data. As such, data needs to sit in RAM which makes data fetching as fast as possible. The internals of a cache data retrieval is not computationally intensive enough to be the major factor. Instead, the hit ratio of the cache system is the limitation. Having a larger memory will increase the hit ratio, reducing the chances of a more expensive DB request.
9.  In a media streaming system, why is network often the bottleneck instead of CPU?
Because the service's throughput affects how smooth its video data is streamed over the network, of which is determined by its bandwidth size. Transmitting data over the network is not computationally intensive as compared to the throughput requirements.
10. Can a system have multiple bottlenecks at once? How do you handle that in estimation?
Yes. Let's say a system is bottlenecked on both CPU and Disk space. We need to identify and justify the dominant bottleneck first. After which, our server estimation needs to primarily address the dominant bottleneck while having 'just-enough' resource for the second bottleneck.
-> Servers = max(
  CPU-based servers,
  memory-based servers,
  disk-based servers,
  network-based servers
)
👉 You don’t “pick one”
👉 You satisfy all constraints
11. Why do we only use ~70% of:
•   CPU
•   memory
•   disk
instead of 100%?
We need to factor in for unforeseen circumstances such as faulty hardware, load irregularities and natural disasters. In such cases, our system should have some resilience in handling extra load instead of failing at the first sign of distress.
-> 🔥 Correct reasoning:
    •   traffic spikes
    •   uneven load distribution
    •   GC pauses / jitter
    •   hardware variance
    •   failover scenarios
👉 Not “natural disasters” 😄
12. What happens if you size your system assuming 100% utilization?
Our system will not be resilient is prone to failure due to unforeseen circumstances.
13. Why is “usable memory” always less than total RAM?
We can rarely access the full RAM capacity for a server due to metadata needs, OS configurations and possibly hardware defects. We need to realistically factor for contingency knowing that we cannot fully resolve unforeseen issues.
-> Memory:
    •   OS usage
    •   fragmentation
    •   cache overhead
14. Why does disk capacity per server not equal “raw disk size”?
There could be many reasons disk capacity are not equal to raw disk size such as OS buffer requirements that reserves a portion of disk size, hardware defects on the disk and/or shared disk usage for other business critical needs. As such, we should generally assume a server has about 70% disk capacity available for use.
-> Disk:
    •   filesystem overhead
    •   replication buffers
    •   compaction (LSM systems)
15. What factors can reduce QPS per server in real systems?
-> 🔥 Correct factors:
    •   heavier requests (CPU cost)
    •   larger payloads
    •   DB calls / I/O latency
    •   locking / contention
    •   GC pauses
    •   inefficient code
👉 Load balancer does NOT reduce capacity
It only distributes traffic
16. Why does replication increase server count but NOT increase system capacity linearly?
-> Replication:
    •   duplicates data → consumes resources
    •   does NOT increase write throughput
    •   may improve read throughput (read replicas)
👉 So:
    •   3x servers ≠ 3x capacity
17. What’s the difference between:
•   scaling for capacity
•   scaling for reliability
Scaling for capacity is when you increase/decrease your resources because your system's service demands have increased/decreased. In the event of an increase in service demands, we scale up our resources to handle a large amount of load.
Scaling for reliability is when you are actively improving the usage experience of your service's consumers. they could be in the form of a faster response time, smoother streaming experience, consistency in data access through different regions etc.
-> 🔥 Correct:
    •   Capacity scaling → handle more load
    •   Reliability scaling → survive failures

18. Why is 3× replication commonly used?
i'm unsure if 3x replication is actually commonly used. but generally replication factors is a balance act between cost effectiveness and contingency risks. a higher replication factor will arguably reduce the chances of unforeseen disasters affecting the reliability of the system.
-> 3 replicas allow:
    •   1 node failure → still available
    •   quorum (2/3) → consistency + availability
    •   balance between cost and durability
19. How does replication affect:
•   storage estimation
a higher replication factor for storage directly increase the amount of storage requirements
•   server count
replication factor directly affects how many more servers we need to provision for.
20. Why must server estimation include failures and failover scenarios?
Because we need to factor in unforeseen circumstances in which will cause a server to fail. We want our system to continuously operate at such times, therefore designing for contingency improves the reliability of the system.
```

* * *
