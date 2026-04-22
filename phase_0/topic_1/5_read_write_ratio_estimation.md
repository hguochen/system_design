# 🧠 Subtopic 5 - Read/Write ratio Estimation

## **🎯 0. Goal of This Subtopic**

You want to be able to:

1. Instantly classify a system

Given a product → is it read-heavy or write-heavy?

 Examples:

* Twitter feed → read-heavy
* Chat system → balanced
* Logging system → write-heavy



1. Quantify read vs write load

Turn vague product behavior into:

```
Read QPS vs Writes QPS
Read : Write ratio (eg. 100:1)
```

1. Drive system design decisions

This is the REAL goal:

|If system is...	|You should think...	|
|---	|---	|
|Read-heavy	|Cache aggressively	|
|Write-heavy	|use queue, batching	|
|Balanced	|Optimize both paths	|

1. Combine with other estimations

* Traffic estimation
* Storage estimation
* Cache sizing
* DB scaling

* * *

## **🧾** 1. Cheat Sheet

|System Type	|Read : Write Ratio	|
|---	|---	|
|Social feed(Twitter, IG)	|100:1 - 1000:1	|
|Video streaming (Youtube)	|1000:1+	|
|E-commerce(Amazon)	|10:1 - 100:1	|
|Chat system	|1:1 - 5:1	|
|Logging/metrics	|1:10 - 1:100(write heavy)	|
|Banking/transactions	|1:1	|
|Search system	|100:1	|

* * *

## 🧠 2. Core Mental Model

Every system has:

```
Writes -> create/update data
Reads -> consume data
```

Your job is to answer:

```
How many reads happen per write
```

* * *

## 3. How to Estimate Quickly (Interview Flow)

### Step 1 - Define the type of system

System types:

* read-heavy
* write-heavy
* balanced

### Step 2 - Identify actions

Example: Twitter

* write: post tweet
* read: view timeline



### Step 3 - Estimate user behavior

Example:

```
1 user:
- post 2 times/day
- reads feed 200 times/day
```



### Step 4 - Convert to ratio

```
200 reads : 2 writes = 100 : 1
```



### Step 5 - Convert to QPS

```
Writes: 10K QPS
Reads: 1M QPS
```

* * *

## 4. Key Insight (Important)

Reads scale with consumption
Writes scale with content creation

Rule of thumb:

```
Consumers >> Creators -> Read-heavy
Creators >> Consumers -> Write-heavy
```

* * *

## 5. Architecture Implications

### Read-heavy System

```
Read >> Write
```

Use:

* CDN
* Caching (Redis)
* Read replicas
* Pre-computation

Examples:

* Feed
* Search
* Video

### Write-heavy System

```
Write >> Read
```

Use:

* Message queues (Kafka, SQS)
* Batching
* Write buffering
* Append-only logs

Examples:

* Logging
* Metrics
* Event ingestion



### Balanced system

```
Read ≈ Write
```

Use:

* Strong DB design
* Index optimization
* Careful scaling

Examples:

* Banking
* Chat

* * *

## 6. Fan-out Effect (Critical Insight)



### Fan-out on write (push model)

* Key idea: 1 write→ MANY writes
* When a user writes data, the system immediately pushes it to all consumers

```
User posts -> system writes -> push to all followers
```

Example:
User A has 1000 followers

```
1 write(tweet)
-> 1000 writes (fan-out to followers' timelines)

```

Pros:

* Super fast reads(timeline is precomputed)
* Great user experience
* No heavy computation during reads

Cons:

* Write explosion (can be millions of writes)
* Heavy storage cost (duplicate data)
* Hard to handle celebrities(10M followers)

When to use:

* read heavy systems
* users read frequently
* low/medium fan-out size



### Fan-out on Read(pull model)

* Key idea: 1 read → MANY reads
* Data is not precomputed - it is assembled when the user reads

```
User posts -> store once
User reads -> fetch all followees' posts -> merge -> rank -> return
```

Example:
User follows 1000 people:

```
Read request ->
-> fetch posts from 1000 users
-> merge + sort
-> return feed
```

Pros:

* Cheap writes
* No data duplication
* Easier to maintain consistency

Cons:

* Slow reads (heavy computation)
* High read QPS to backend
* Hard to scale for large follow graphs

When to use:

* write heavy systems
* users don’t read often
* large fan-out(celebrity problem)

### Hybrid model

Combine fan-out write and fan-out read based on user type or system constraints

Key Idea:

* Optimize both write and read paths

Strategy:

* Normal users → fan-out on write
* Celebrities → fan-out on read

Example:
User A (100 followers):

```
-> push posts to followers (fan-out write)
```

User B (10M followers):

```
-> DO NOT push
-> followers fetch on read (fan-out read)
```

Pros:

* balanced system
* Fast reads for most users
* Avoids write explosion for celebrities

Cons:

* more complex system
* requires routing logic
* needs user classification

|&lt;b&gt;Aspect&lt;/b&gt;	|&lt;b&gt;Fan-out Write&lt;/b&gt;	|&lt;b&gt;Fan-out Read&lt;/b&gt;	|&lt;b&gt;Hybrid&lt;/b&gt;	|
|---	|---	|---	|---	|
|
Write cost	|
❌ High	|
✅ Low	|
⚖️ Medium	|
|---	|---	|---	|---	|
|
Read cost	|
✅ Low	|
❌ High	|
⚖️ Medium	|
|
Latency (read)	|
⚡ Fast	|
🐢 Slow	|
⚡ Fast	|
|
Storage	|
❌ High	|
✅ Low	|
⚖️ Medium	|
|
Complexity	|
Medium	|
Medium	|
❌ High	|

TLDR

* Fan-out write = Precompute everything
    * Do the work early
* Fan-out read = Compute on demand
    * Do the work later
* Hybrid = Be smart about it
    * Do the work where it’s cheaper

When asked:
How would you design a feed system?

We say:

```
This is a read-heavy system.

We can use fan-out on write to precompute feeds for fast reads.
However, for high-fanout users (celebrities), this causes write explosion.

So we use a hybrid approach:
- fan-out write for normal users
- fan-out read for celebrities

This balances write amplification and read latency.
```

* * *

## 7. Hidden Reads

Not all reads are obvious:

|Type	|Example	|
|---	|---	|
|Cache miss reads	|DB fallback	|
|Internal reads	|joins, lookups	|
|Background reads	|ranking, ML	|
|Retry reads	|failures	|

Real systems often have:

```
Actual reads = 2x - 10x user reads
```

* * *

## 8. Interview Short Answer Template

When asked:

```
What's the read/write ratio?
```

Answer like this:

```
// 1. define the system type. read-heavy/write-heavy/balanced
This system is highly read-heavy.

// 2. estimate user behavior
Assuming each user:
-  writes ~2 times/day
- reads ~200 times/day

// 3. convert to ratio
That gives ~100:1 read/write ratio

// 4. estimate traffic/day
Assume:
- 1B DAU
- 2B writes/day
- 200B reads/day

- 20K average write QPS
- 2M average read QPS

// 5. determine the focus direction of our design
So reads dominate traffic, and we should prioritize caching and read scalability
```

When estimating read:write ratio, always use this format:

```
Reads = ?
Writes = ?
Read : Write = Reads : Writes
Simplify
```

* * *

## 9. Red Flags (Common Mistakes)

* ❌ Forgetting fan-out
* ❌ Ignoring user behavior
* ❌ Treating all systems as read-heavy
* ❌ Not connecting ratio → architecture 

* * *

## 10. Mastery Checklist

You’ve mastered this subtopic when you can:

* instantly classify any system (read vs write heavy)
* derive ratio in <30 seconds
* Convert to QPS mentally
* Explain architecture impact clearly
* Adjust for fan-out and hidden reads

