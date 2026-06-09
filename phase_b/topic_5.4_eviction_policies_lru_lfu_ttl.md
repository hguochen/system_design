# 5.4 Eviction Policies — LRU, LFU, TTL

> **Topic:** Topic 5 — Caching Systems
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-05-28

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Cache memory is finite. When a cache fills up, it must decide which entries to evict to make room for new ones — this decision is governed by an **eviction policy**. The policy you choose directly affects cache hit rate, latency, and correctness. Getting it wrong can mean evicting hot data, retaining cold data, and underperforming a naively larger cache.

### 🎯 What to Focus On

**1. Understand what each policy optimizes for.** LRU optimizes for recency, LFU optimizes for frequency, TTL optimizes for freshness. Each assumes a different access pattern; the wrong choice can tank hit rate.

**2. Know the data structures behind each policy.** LRU is implemented via a doubly linked list + hashmap. LFU is harder — it requires a frequency map and a min-heap or doubly bucketed list. These come up in coding interviews too.

**3. Know when LFU beats LRU.** In frequency-skewed workloads (e.g., CDN, top-N content), LFU dramatically outperforms LRU. Candidates who only know LRU get caught here.

**4. TTL is not an eviction policy in the algorithmic sense** — it's an expiry mechanism. In practice, systems combine TTL with LRU/LFU. Know how they interact.

**5. The hot key / scan resistance problem.** A large sequential scan (e.g., full table scan, batch job) can evict all hot data from an LRU cache — this is called cache pollution. Know how to detect and mitigate it.

---

## 1. 🎯 Goal of This Subtopic

> *Why are you studying this? What should you be able to do after this session?*

Be able to choose the right eviction policy for a given access pattern and justify the decision in an interview. Be able to explain the implementation mechanics of LRU and LFU at a data structure level, describe how TTL interacts with memory-based policies, and identify when cache pollution from scan-heavy workloads is a concern.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can explain LRU, LFU, and TTL eviction mechanics without notes and describe when each is the right choice
- [ ] Can describe the O(1) LRU implementation using a doubly linked list + hashmap
- [ ] Can explain why LFU outperforms LRU in frequency-skewed workloads and give a concrete example
- [ ] Can identify the cache pollution problem and propose a mitigation (2Q, LRU-K, key exclusion)
- [ ] Can explain how TTL and LRU/LFU interact in a combined eviction strategy

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **DDIA Chapter 5** (replication and caching foundations) and **Redis documentation on eviction policies** (https://redis.io/docs/manual/eviction/)
- [ ] Read **ByteByteGo System Design Interview Vol 1, Chapter 6** (designing a cache)
- [ ] Read through **Sections 5–9** carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** from memory, then compare
- [ ] Explain **First Principles** out loud without notes — what problem does this solve and why?
- [ ] Reconstruct the **How It Works** mechanics step by step from memory
- [ ] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [ ] Go through **Real-World System Examples** (Section 10) — verify each claim independently and add anything missed to **My Notes**
- [ ] Practice the **Interview Application** (Section 12) out loud — say the trigger phrases and your response as if in a live interview
- [ ] Work through **Common Misconceptions** (Section 13) — for each, make sure you can explain *why* the misconception is wrong
- [ ] Trace the **Relationships to Other Concepts** (Section 14) — can you explain each connection without looking?

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [ ] Answer every **Self-Check Quiz** question (Section 15) out loud without looking at your notes
- [ ] Recite the **Cheatsheet** (Section 4) from memory — if you can't, re-do Phase 2
- [ ] Tick off items in **What Mastery Looks Like** (Section 2) — only check a box if you can demonstrate it on demand
- [ ] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation or notes

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

![5.4 Eviction Policies — LRU, LFU, TTL — Mindmap](../assets/images/topic_5.4_eviction_policies_lru_lfu_ttl_mindmap.png)

```
§ 1  WHY IT EXISTS
  Cache memory is finite. Without a policy you either reject new entries
  (OOM errors) or evict randomly (unpredictable hit rate, may kill hot data).
  Eviction policies maximize hit rate by formalizing temporal / frequency
  locality into deterministic algorithms.

§ 2  WHAT EACH POLICY IS
  LRU  — evict the entry accessed furthest back in time.
         O(1) via doubly linked list (access order) + hashmap (key lookup).
  LFU  — evict the entry with the lowest access count.
         O(1) via frequency-bucket doubly linked list + min-freq pointer.
  TTL  — evict entries whose age exceeds a configured threshold.
         Freshness mechanism — orthogonal to memory pressure.

§ 3  THE 3 KEY DISTINCTIONS
  1. LRU vs LFU: LRU = recency, LFU = frequency.
     LFU wins for Zipfian workloads (top 5% of keys = 80% of traffic).
     LFU is scan-resistant; scan entries stay at freq=1 and evict first.
  2. TTL != eviction policy: TTL answers "is this valid?",
     LRU/LFU answers "which to remove when full?" — combine both.
  3. Cache pollution: sequential scan -> LRU evicts entire hot dataset.
     Fix: LFU, 2Q (probationary + protected queue), or LRU-K.

§ 4  USE / AVOID
  LRU:  recency-biased workloads (general-purpose, session stores)
  LFU:  Zipfian / freq-skewed (music, CDN, social media feeds)
  TTL:  data with known validity window (auth tokens, API responses)
  AVOID LRU when: batch jobs or full table scans share the data path.

§ 5  INTERVIEW TRIGGERS
  -> "How does your cache decide what to evict when full?"
  -> "The hot dataset keeps getting evicted under load"
  -> "5% of items account for 80% of reads" (-> LFU)
  -> "How do you prevent stale data?" (-> TTL)

§ 6  FTAC
  F  "Tension: hit rate vs. workload pattern. LRU is O(1) and simple,
     but a single sequential scan evicts the entire hot dataset."
  T  "LRU: simple, works for recency workloads, scan-vulnerable.
     LFU: higher hit rate for Zipfian traffic, scan-resistant,
     more complex + needs counter decay to avoid stale popularity."
  A  "Assuming this is a read-heavy social feed — top ~1% of posts
     get ~80% of traffic — Zipfian distribution holds."
  C  "LFU with Redis allkeys-lfu. Cost: slightly more complex config,
     need to tune lfu-decay-time. TTL per key for freshness."

§ 7  NUMBERS & GOTCHA
  Redis default: noeviction (throws OOM at capacity — must configure!)
  Redis LRU: approximate — samples 5 keys, evicts least recent among sample
  Redis LFU: logarithmic counter 0-255, lfu-decay-time controls staleness
  GOTCHA: LRU is NOT scan-resistant — one full table scan evicts all hot data
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

An **eviction policy** is the algorithm a cache uses to decide which entry to remove when it reaches capacity. The three dominant policies are **LRU** (evict the least recently accessed entry), **LFU** (evict the least frequently accessed entry), and **TTL** (evict entries whose age exceeds a configured threshold).

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic.*

### LRU — Least Recently Used
LRU maintains an implicit temporal ordering: the entry that was accessed furthest back in time is the first candidate for eviction. It assumes that recently used data is likely to be used again soon (temporal locality). Implemented in O(1) for both get and put using a **doubly linked list** (to maintain access order) combined with a **hashmap** (for O(1) key lookup); on every access, the node is moved to the head of the list, and eviction removes from the tail.

### LFU — Least Frequently Used
LFU tracks how many times each entry has been accessed and evicts the entry with the lowest count. It assumes that frequently accessed data will remain popular (frequency locality). LFU outperforms LRU in workloads where a small set of items receives the majority of traffic (Zipfian distribution — e.g., top songs, viral posts). The naive implementation uses a min-heap (O(log n) updates), but an O(1) implementation exists using a doubly linked list of frequency buckets.

### TTL — Time To Live
TTL is a time-based expiry mechanism: each cache entry is stamped with a creation or last-update time, and it is invalidated once the elapsed time exceeds the configured TTL value. TTL is primarily about **data freshness and consistency** rather than memory pressure — it ensures that stale data is not served even if the cache is not full. Most systems combine TTL with a memory-based policy: an entry can be evicted by either being too old (TTL) or being displaced by a newer entry (LRU/LFU).

### Cache Pollution
Cache pollution occurs when a workload (typically a sequential scan or batch job) reads a large volume of one-time-use data, filling the cache and evicting hot, frequently reused entries. This is a known failure mode of pure LRU. Solutions include: LFU (immune to scans because cold scan entries never accrue frequency), 2Q (two-queue: probationary queue for new entries, protected queue for those accessed twice), and LRU-K (evict based on K-th most recent access rather than most recent).

### Approximate vs. Exact Eviction
Exact LRU and LFU require maintaining precise access metadata, which has memory and CPU overhead proportional to cache size. Production systems often use **approximate** implementations: Redis LRU randomly samples a configurable number of keys and evicts the least recent among the sample — this is fast and good enough at scale. Redis LFU uses a logarithmic counter per key with a decay factor to approximate historical frequency without unbounded counter growth.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve?*

Cache memory is finite — typically orders of magnitude smaller than the dataset it serves. As new entries arrive, old ones must be discarded. Without a policy, you're forced to either reject new entries (no-eviction) or remove entries randomly. Both are terrible: no-eviction errors at capacity; random eviction has unpredictable hit rates and can evict the hottest entry in the dataset.

The core insight is that not all cached entries are equally valuable. Entries that have been recently accessed are more likely to be accessed again soon (temporal locality). Entries that have been accessed many times are likely to remain popular (frequency locality). Entries older than a known data validity window are likely wrong. Eviction policies formalize these intuitions into deterministic algorithms that maximize hit rate for a given cache size.

The stakes are high: a cache that is 80% hit rate vs. 95% hit rate can mean the difference between 10x and 20x reduction in database load. Poor eviction policy choice is often the silent cause of unexpectedly high cache miss rates in production.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast.*

### Model 1: The Bookshelf
Imagine a physical bookshelf with limited space. LRU means: when you need to add a new book, remove the one you picked up least recently. LFU means: remove the one you've opened the fewest times. TTL means: any book older than 6 months gets removed regardless of access. The failure mode of LRU is obvious here — if you do one big research project reading 50 rarely-used books sequentially, all your favorite frequently-read books get pushed off the shelf.

### Model 2: The Frequency Ladder
Think of LFU as a leaderboard ranked by access count. New entries start at count=1, at the bottom. Every access moves an entry up one rung. Eviction always removes from the bottom rung. The weakness: entries that were popular a long time ago but are now cold will have a high count and won't be evicted — this is the "cache pollution of the past" problem. The decay factor in Redis LFU addresses this by gradually reducing counts for entries that aren't accessed, allowing stale-but-formerly-popular entries to become eligible for eviction.

### Model 3: TTL as a Freshness Contract
TTL is best understood as a **contract between the cache and the data source**: "I guarantee that this cached value is no more than X seconds out of date." This makes it distinct from LRU/LFU — those optimize memory utilization; TTL optimizes data correctness. The practical failure mode is stale reads when the TTL is too long, and high miss rates / cache stampedes when the TTL is too short. The right TTL is tied to how fast the underlying data changes, not to memory pressure.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step explanation of the internal mechanism.*

**LRU Mechanics (O(1) implementation)**

The standard O(1) LRU cache uses two data structures: a **doubly linked list** where the head represents most recently used and the tail represents least recently used, and a **hashmap** mapping keys to their corresponding list nodes.

- `GET(key)`: Look up the node via hashmap. If found (hit), move the node to the head of the list (most recently used). Return value. O(1).
- `PUT(key, value)`: If key exists, update value and move node to head. If not: create node, insert at head. If cache is at capacity, remove the tail node (LRU entry) and delete from hashmap. O(1).

Eviction target: always the tail node.

**LFU Mechanics (O(1) implementation)**

An O(1) LFU uses three structures: a `key→value` map, a `key→frequency` map, and a `frequency→[keys]` doubly linked list map, plus a pointer to the current minimum frequency.

- `GET(key)`: Look up value. Increment key's frequency. Move key from frequency bucket F to bucket F+1. If bucket F is now empty and F == minFrequency, increment minFrequency. O(1).
- `PUT(key, value)`: If at capacity, evict the LRU entry from the minFrequency bucket (each frequency bucket is itself a recency-ordered list, so the tail of the minFrequency bucket is the eviction candidate). Insert new key at frequency 1. Set minFrequency = 1. O(1).

**TTL Mechanics**

Each cache entry stores a timestamp (creation time or last-write time) alongside the value. On access, the cache checks `now - timestamp > TTL` — if true, the entry is a miss even if the key exists (lazy expiry). Most caches also run a background sweep (active expiry) periodically to reclaim memory from expired entries without waiting for them to be accessed. The TTL duration is configured per-key or globally; some systems support sliding TTL (reset on access) vs. absolute TTL (never reset).

**TTL + LRU Combined (Redis allkeys-lru)**

When memory pressure exists, Redis uses LRU to select the eviction candidate from all keys (including unexpired ones). When an entry's TTL expires, it becomes a miss regardless of LRU position. The two mechanisms are independent: LRU responds to memory pressure; TTL responds to data age.

**Cache Pollution and 2Q**

The 2Q algorithm maintains two queues: a small FIFO probationary queue for new entries, and a larger LRU queue for entries accessed more than once. New entries enter the probationary queue. If accessed again before being evicted, they graduate to the protected LRU queue. If evicted from the probationary queue without a second access (e.g., a scan entry), they never pollute the LRU queue. This halves the impact of scan workloads on hot data.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **Redis** | Supports 8 eviction policies: noeviction, allkeys-lru, volatile-lru, allkeys-lfu, volatile-lfu, allkeys-random, volatile-random, volatile-ttl | allkeys-lru is the most common production choice; allkeys-lfu preferred for frequency-skewed workloads (e.g., CDN key caching) |
| **Memcached** | Uses LRU by default; supports per-slab LRU with TTL expiry | Each memory slab has its own LRU list; eviction is slab-local, not global |
| **CPU L1/L2/L3 Caches** | Hardware uses pseudo-LRU (PLRU) or set-associative LRU approximations | Exact LRU is too expensive in hardware; approximate variants are used |
| **Varnish (HTTP cache)** | Uses a combination of TTL (from Cache-Control headers) and LRU for memory management | TTL here maps directly to HTTP cache freshness semantics |
| **CDN edge nodes (Cloudflare, Fastly)** | LRU for object eviction; TTL derived from origin Cache-Control headers | Cache-Control: max-age sets the TTL; LFU-like policies are used for large media files |
| **MySQL InnoDB Buffer Pool** | Modified LRU with a midpoint insertion strategy (new pages enter at 3/8 from the tail, not the head) | Specifically designed to be scan-resistant — prevents full table scans from evicting hot index pages |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost.*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **LRU** — simple O(1) implementation, works well for most recency-biased workloads | Vulnerable to cache pollution from scan workloads; one sequential scan can evict the entire hot dataset |
| **LFU** — higher hit rate for frequency-skewed (Zipfian) workloads; scan-resistant | More complex to implement O(1); frequency counters can be "stale" — old-popular entries block eviction of newer popular ones |
| **TTL** — guarantees data freshness; prevents serving stale data past a known validity window | Does not respond to memory pressure; short TTL → high miss rate and potential cache stampede; long TTL → stale data risk |
| **Approximate LRU (Redis)** — low overhead, scales to millions of keys | Not exact; under adversarial or highly skewed workloads, approximation error may reduce hit rate compared to exact LRU |
| **LFU with decay (Redis)** — avoids "stale popularity" problem; adapts to changing access patterns over time | Decay rate tuning is non-trivial; too fast decay → behaves like LRU; too slow → long tail of old-popular entries stays in cache |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview?*

**When an interviewer asks / says:**
- "How does your cache decide what to evict when it's full?"
- "Your cache is only N GB — how do you make sure the hottest data stays in cache?"
- "How do you prevent stale data from being served?"
- "You're designing a distributed cache for a social media feed — what's your eviction strategy?"

**What you say / do:**
In the cache design or deep dive section, proactively state your eviction policy choice and justify it with the access pattern. For social/media systems with Zipfian access distributions, call out LFU. For session/auth caches with known expiry windows, call out TTL. For general-purpose caches, default to LRU and note the scan pollution risk if batch processing is present.

**The trade-off statement (memorize this pattern):**
> "If we choose LRU, we get a simple O(1) implementation that handles recency-biased workloads well, but we risk cache pollution if our pipeline includes batch or scan jobs. For this system — a read-heavy social feed — LFU is the right call because the top 1% of content accounts for ~80% of reads, and LFU will protect those hot entries even under scan traffic."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong?*

- ❌ **Misconception:** LRU is always good enough — it's what everyone uses in production.
  ✅ **Reality:** LRU is the most common default but fails badly for frequency-skewed workloads. Redis itself recommends LFU for use cases like CDN key caching, session management at scale, or any workload where a small number of keys account for the majority of accesses.

- ❌ **Misconception:** TTL is an eviction policy like LRU or LFU.
  ✅ **Reality:** TTL is a freshness/consistency mechanism, not a memory management algorithm. It answers "should this entry be considered valid?" not "which entry to remove when full?" Most production caches combine TTL (for freshness) with LRU or LFU (for memory pressure).

- ❌ **Misconception:** LFU retains the most recently popular items forever.
  ✅ **Reality:** Without a decay mechanism, LFU suffers from "historical frequency pollution" — an entry that was hot a week ago but is now cold will have a high counter and block eviction of newer hot entries. Redis LFU uses a logarithmic counter with configurable decay (lfu-decay-time) to reduce counter values for entries that haven't been accessed recently.

- ❌ **Misconception:** Eviction only matters when the cache is full.
  ✅ **Reality:** Eviction policy affects hit rate continuously, not just at capacity. A well-chosen policy maintains a higher hit rate at the same cache size, which is equivalent to getting more throughput headroom from the same hardware budget.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics?*

- **Builds on:** 5.1 Cache-aside, 5.2 Write-through, 5.3 Write-back — eviction policy is only relevant once you know *what data is in the cache*; caching strategies determine how data gets there.
- **Enables:** 5.5 Cache consistency and invalidation — TTL-based expiry is one of the primary invalidation mechanisms; understanding its interaction with LRU/LFU is prerequisite for designing invalidation strategies.
- **Tension with:** 5.6 Cache stampede — short TTLs (chosen for freshness) increase the risk of simultaneous cache misses on expiry; the choice of TTL directly impacts stampede probability.
- **Also relates to:** 5.7 Hot key problem — LFU's scan resistance and ability to protect high-frequency keys is directly relevant to mitigating hot key concentration; local caching strategies at the application layer also pair with LFU to protect against hot key eviction.

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking?*

1. What data structures are used to implement an O(1) LRU cache, and why are both necessary?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6 (Core Concepts) and Section 9 (Mechanics).*
A doubly linked list and a hash map. This is used to move the most recent access data into the top of the list and thereby pushing the less recently used data to the tail of the list. When the cache is full, we will first remove the tail data sets. The hash map has a key-value star where the key is the accessing key and the value will be the reference to the pointer in the doubly linked list. We will need O1 access for any of the keys, so that's the reason for using the hashmap. 

Two data structures: a doubly linked list and a hashmap.

Doubly linked list: maintains access order. Head = most recently used,
tail = least recently used. On every access, move the node to the head.
On eviction, remove the tail. O(1) for both operations because we have
direct node references.

Hashmap: maps key → node pointer in the linked list. Provides O(1)
lookup so we can find any key instantly without traversing the list.

Why both are necessary: the linked list alone gives O(1) eviction but
O(n) lookup. The hashmap alone gives O(1) lookup but no ordering.
Together they give O(1) for get, put, and eviction.

2. You're designing a cache for a music streaming service where 5% of songs account for 80% of plays. Should you use LRU or LFU? Why?

   > 💡 *Think through the access distribution before answering — if you're unsure, revisit Section 6 (LFU concept) and Section 8 (Frequency Ladder mental model).*
We should use an LFU cache. The forces in contention for choosing this cache are basically the tension between:
- the memory capacity
- the hit rate for the cache
- the data freshness
The assumption for the music streaming service is that we have a small working set of hot data that is contributing to the majority of the plays. We need to make sure this small working set of data is sitting in cache in order to guarantee a high cache rate. So this also gives the natural assumption that, because they have a small subset and are being accessed repeatedly, they naturally have a high frequency for this small subset of data. By choosing an LRU cache, we can  guarantee that the small working set can sit inside our cache to maintain a high hit rate. The trade-off of using an LFU cache is that, because now we measure the relevancy of cached data via frequency and not via recency, some of the lower-frequency but more recently used data set (or, in this case, the songs) will not be in the cache. That will incur a DBE, and that's what we hit. For our usage pattern here, which is high-frequency small working dataset, using an LFU cache is the right call because we want to maintain the highest hit rate possible with a fixed memory capacity. By using frequency as the metric for caching, we can guarantee that those small working sets will be inside the cache, and this is not possible with an LRU cache. In addition, we will also need to introduce a TTL expiry for every single cache entry to serve as a guarantee that data within this window is considered fresh. Once they are no longer fresh, they need to have a way to be evicted from the cache. 

LFU. This is a Zipfian workload — 5% of songs = 80% of plays.

LFU is correct because:
- Small hot working set with high repeat access = high frequency counts
- LFU protects high-frequency entries from eviction by design
- LRU would fail here: a hot song not played in the last N minutes
  gets evicted even if it's the most-played song overall

Trade-off: lower-frequency but recently played songs may be evicted.
Acceptable — they contribute minimally to total traffic.

Also combine with TTL for data freshness (song metadata validity window).

3. What is cache pollution, and what specific workload pattern causes it in an LRU cache?

   > 💡 *Think through the mechanics of how LRU tracks access order — if you can't explain the failure mode, revisit Section 6 (Cache Pollution) and Section 9.*
Cache pollution more often happens in an LRU cache. It is the situation where we have an entirely different access pattern hitting our otherwise live traffic cache access pattern. One such example would be: let's say we have a batch job that runs at midnight to do a full export of data. This batch job will pull all of the data, by definition of what was working inside the cache, and then they all get put into the cache as the most recently accessed data. The problem is this data is only accessed once and not touched again. When the cache is full, our system will actually flush the least recently used data, which incidentally is the hot working set per the live traffic source. We are thereby reducing our cache rate by using a different access pattern to flush out our intended live traffic access pattern data. 

Cache pollution: a workload reads a large volume of one-time-use data,
flooding the cache and evicting the hot working set.

Root cause: LRU has no knowledge of frequency. It treats a key accessed
once during a batch scan identically to a key accessed 10,000 times by
live traffic — recency is all it sees.

Specific pattern: sequential scan or batch export job. Each key is
accessed exactly once, moved to the LRU head, and pushes hot live-traffic
keys toward the tail. When the cache fills, the hot working set gets
evicted first.

Fixes: LFU (scan entries stay at freq=1, evict first), 2Q (probationary
queue for first-access entries), LRU-K (requires K accesses before
competing with established entries).

4. A Redis instance is configured with allkeys-lru and maxmemory 4GB. A key has a TTL of 60s and was accessed 10 seconds ago. Under what conditions will it be evicted before its TTL expires?

   > 💡 *Think through how TTL and LRU interact — if you're unsure, revisit Section 9 (TTL + LRU Combined).*
It's possible that this key can be evicted before it expires if we have a high traffic load and our cache has hit full memory capacity of 4 GB. That warrants the least recently used data to be removed from the cache. That means that data that is served 10 seconds or more ago is now considered least recently used, and by the LRU eviction mechanism, we are removing the data even though it's within the TTL window. 


The key will be evicted before TTL expiry if memory pressure forces
eviction and this key is selected as the LRU candidate.

Mechanics: Redis allkeys-lru samples N keys (default 5) and evicts the
least recently accessed among the sample. If this key (accessed 10s ago)
is selected in a sample where it is the least recent, it gets evicted —
regardless of its remaining TTL.

TTL and LRU are independent: TTL answers "is this data still valid?",
LRU answers "which entry to remove under memory pressure?" Memory
pressure can trigger LRU eviction before TTL expiry.

The higher the memory pressure and the larger the key space, the more
likely a recently accessed key gets caught in an unlucky sample.

5. What happens to an LFU cache entry that was extremely popular 6 months ago but hasn't been accessed since? What mechanism prevents it from permanently occupying cache space?

   > 💡 *Think through the counter-decay mechanism — if you hesitate, revisit Section 9 and Section 13 (Misconception 3).*
So, an extremely popular cache entry six months ago will, by definition, have a high frequency count in the RFU cache, but since then it has not received any counts. In the default approach, they will sit in the cache forever because of virtue of having high frequency counts. What we need is to introduce a decay mechanism where their frequency count for working data sets gets reduced over time so that eventually, without enough excess frequency, they will now be subjected to the mean frequency threshold and thereby get removed in the subsequent cycle of the cache eviction operation. 

Without decay: the entry retains its high frequency count permanently
and is never evicted — this is the stale popularity problem. It blocks
eviction of newer, currently popular entries.

The fix: counter decay. Redis LFU uses a logarithmic counter (0–255)
with a configurable lfu-decay-time. The counter is decremented
periodically for entries that haven't been accessed. Over time, a
formerly-popular but now-idle entry's count drops toward the minimum
frequency level, making it eligible for eviction.

The decay rate is tunable:
- Too fast → behaves like LRU (recency dominates)
- Too slow → stale popular entries linger too long

---

## 16. 📚 Further Reading

> *Resources for deeper understanding.*

- [ ] **Redis Eviction Policies** — official documentation with all 8 policy options explained: https://redis.io/docs/manual/eviction/
- [ ] **Designing Data-Intensive Applications (DDIA)** — Martin Kleppmann, Chapter 5 (replication and caching foundations)
- [ ] **ByteByteGo System Design Interview Vol 1** — Chapter 6: Design a Key-Value Store (covers cache eviction in the context of system design)
- [ ] **LFU O(1) Algorithm** — "An O(1) algorithm for implementing the LFU cache eviction scheme" by Shah et al. (2010): http://dhruvbird.com/lfu.pdf
- [ ] **MySQL InnoDB Buffer Pool** — scan-resistant LRU design: https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool.html

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

What's a eviction policy?
Eviction policy is an algorithm the cache uses to decide which entry to remove when it reaches capacity. 

What's in tension for caches in general?
A cache, in general, has a constant tension between the memory capacity versus the hit rate and the index freshness. The idea for cache is to, within the bounds of a fixed memory capacity, attain the highest hit rates for cached data while guaranteeing that the data is fresh within a pre-configured window. 

How many eviction policies are there? 
Types of eviction policies:
1. The LRU, which is to remove the least recently used entry.
2. The LFU, which removes the least frequently accessed entry.
3. TTL, which evicts an entry based on when a data reaches the threshold timestamp.

TTL is not a capacity eviction policy — it's a time-based expiry. Pair TTL with LRU or LFU: LRU/LFU manages capacity, TTL manages freshness.

When do we use LRU eviction mechanism? 
LRU eviction mechanism is the default eviction policy for most caches. This mechanism basically lines data by their recency of usage. The most recently used data will be cached in the cache, and the least recently accessed data will be removed from the cache when the memory is full. One example of using an LRU mechanism is if the user accesses data via a single session. It is likely that he will access data that is more recently accessed. Our LRU cache can effectively cache the most recently accessed data with the intent that it will be accessed again within the window. When the session window expires, then we can go about removing all of the recently accessed cache data in that window. 

When do we avoid LRU eviction mechanism?
We need to avoid using LRU eviction mechanism if our cache eviction pattern is not based on data recency. For example, if we have a social media app where the access pattern is based on the number of reads on a post and high-frequency posts get the most views, we will need to cache the high-frequency post data to effectively read and reduce our traffic workload. 

When do we use the LFU eviction mechanism? 
LFU eviction mechanism is suitable for systems with access patterns where a small number of working set data contributes to the majority of our traffic. For example, a social media application, a small working set of hot posts, will contribute to the majority of the traffic because most people will read the hot posts. 

When do we avoid LFU eviction mechanism?
We want to avoid using an LFU cache if the access pattern is more smoothed out and we do not have any single small subset of working sets that contribute to the majority of the use cases. For example, if we have a profile system in which it is equally likely for any profile to be accessed, then using an LFU cache will not guarantee that our cache has the highest hit rate. 

Name an issue with LRU Cache and how to mitigate it.
One issue with LRU is that if we are running batch jobs or sequential scans for a wide spectrum of data where they're only, by definition, accessed once. This job itself will flush out all of the hot working sets in the cache and thereby reduce the hit rate of your cache drastically. Here is how we can have a two-queue approach for LRU, in which the first queue is a probationary queue. And the second queue is our intended queue for live traffic. New entries will come in through and sit in the probationary queue as they are assessed. Once they are assessed more than once, then they will graduate to move to the secondary queue. In this case, the batch scan will put a lot of entries into the probationary queue. When they are not being assessed again, they do not get promoted to the secondary queue, and then over time we will first go about removing entries from the probationary queue. 

Name an issue with LFU Cache and how to mitigate it.
LFU cache has a stale popularity problem. Where previously popular working sets have accrued a high number of frequency and they sit in the frequency table without ever being evicted from the cache, even when they are no longer being accessed. We want to introduce a natural decay to frequency datasets such that they will over time reduce their frequency counts. Eventually, over a longer period of time, when they do not get access, they will drop to the minimum frequency or the least queue and eventually get removed from the cache. 

Give an actual interview answer for choosing LRU cache.
Let's say we have a system that is a profile-based system where each person's profile is accessed an equal number of times in a day.
The forces in contention here will be:
- to have memory capacity
- the cache hit rate
- the index freshness of the data
If we choose an LRU-based system, we are basically able to keep the most recently accessed data in the cache and maintain a higher hit rate as opposed to an LFU cache. It is because the working set pattern is equally likely among the different data sets. The data sets do not differentiate themselves via frequency, but more via how recently they are being accessed. The The trade-off of using an LRU cache means that if we are running a different access pattern (for example, a batch load that loads all of the data for export operations), then they will all have been moved into cache via the recency pattern and thereby definitionally flushed out of the actual live traffic hot working sets. The way to deal with this will be to introduce a two queue with probationary queues to make sure that we separate the data that's only accessed once via the batch access pattern versus the live traffic (that is, the actual hot working data).
The assumption we are making here is that our traffic, the working set data, do not differentiate themselves via the frequency of access, but more so on how recently they are being accessed. 
Using LRU cache here is the right call because we do not care about frequency, and no small amount of working sets contributes to any significant majority of the traffic. The traffic distribution is actually quite even. We care more about how recent that data is, and the likelihood of it being accessed is higher because of temporal locality. Point out that using an LRU cache only satisfies the memory management aspect of the cache. We will also need to guarantee the index freshness of the data, and for that we will use a TTL timestamp to check that data is fresh within a certain timestamp window. If it goes beyond that timestamp, the data is considered stale and should not be served. 

Give a actual interview answer for choosing LFU cache
We have a system that is a social media application in which there are a small number of celebrities having posts that are viewed by a lot of people. This, by definition, creates a small working set contributing to the majority of our traffic. 
The forces in contention here are to balance the memory capacity with the cache hit rate and the index freshness of the data. 
If we use an LFU cache, we are basically ensuring that the most frequently accessed working set sits inside the cache, and they will effectively reduce the amount of traffic that hits our database. The trade-off is that, because now we are making the access pattern via frequency, some of the data which has lower frequency but is more recently used might not sit in the cache and thereby experience a cache miss. Assumption here is that the majority of the traffic is contributed by a small working set of hot data, which are, by definition, the highest frequency data. By storing this higher frequency, we are able to, to the biggest extent, the largest and the highest cache hit rate. So, using an LFU cache here is the right call because we are now able to store the working set that actually matters and that contributes to the highest load to the system. We make them cheap to serve and have a low latency. In addition, we avoid having a disk I/O hit for these working sets. 

How is LRU implemented?
O(1) access time complexity. Uses a doubly linked list where recently used data is moved to head of list, least recently accessed data sits in tail of the list and gets removed when cache is full. A hashmap where key is the acess key and value is the reference to data pointer in the linked list. 

How is LFU implemented?
O(1) access time complexity. 3 Hashmaps:
1. hashmap 1: key value store of the actual accessing key and the corresponding data value
2. hashmap 2: key frequency store of the actual accessing key and the frequency count of the data being accessed so far
3. hashmap 3: frequency key with ordered list value of data that's being accessed
a minFrequency variable that points to the least frequency data list to be evicted from cache

How does TTL lazy vs active expiry work?
TTL lazy expiry basically checks whether the current timestamp is beyond the expiry timestamp. If it is, it will remove the timestamp and serve a cache miss, even though the data is, at the point in time, still sitting in cache. At active expiry, we run a regular job that scans our cache and removes expired TTL data from the cache. We will need to use both approaches in our cache in order to safely and reliably evict data from our cache. 
