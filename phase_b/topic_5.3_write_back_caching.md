# 5.3 Write-Back (Write-Behind) Caching

> **Topic:** Topic 5 — Caching Systems
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-05-28

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Write-back (also called write-behind) caching is a write strategy where data is written to the cache immediately and acknowledged to the client, but the write to the backing database is deferred — buffered and flushed asynchronously at a later time. It is the most performance-aggressive of the three core caching strategies: it trades durability risk for dramatically lower write latency. Mastering this strategy means understanding exactly what data is at risk in the window between cache write and DB flush — and designing systems to make that risk acceptable.

### 🎯 What to Focus On

**1. The deferred write contract — and its durability gap.** The client gets an ACK as soon as the cache write completes. The database does not see the write immediately. If the cache node fails before flushing, those writes are lost. Know this cold — it is the defining trade-off.

**2. Dirty buffer management.** The cache tracks which keys have been written but not yet flushed ("dirty"). Know how dirty entries are managed: mark-on-write, flush triggers (time-based, count-based, LRU eviction), and what happens when a dirty entry must be evicted before flushing.

**3. When write-back is justified vs. dangerous.** Write-back is ideal for write-heavy, high-throughput workloads where latency matters and some data loss is tolerable (e.g., analytics counters, log buffering, game state). It is dangerous for financial transactions, inventory, or anything where losing a flush window means lost money or user data.

**4. Flush failure handling.** What happens if the database is unavailable during a scheduled flush? Know the retry mechanism, the dirty buffer growth risk, and the cache-as-SOT (source of truth) failure mode.

**5. Contrast with cache-aside and write-through.** Write-back is the third point on the performance-consistency triangle. Know where each strategy sits and how to pick and justify the right one for a given workload in a design interview.

---

## 1. 🎯 Goal of This Subtopic

> *Why are you studying this? What should you be able to do after this session?*

Be able to choose write-back caching for a given workload, explain the deferred-flush mechanism and its durability implications precisely, and contrast it with write-through in a structured trade-off discussion. Specifically: explain what a dirty buffer is, when data loss occurs, and how production systems mitigate it — all without referring to notes.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [ ] Can explain the write-back sequence (client → cache ACK → async DB flush) and identify exactly when data loss occurs
- [ ] Can describe dirty buffer management: what "dirty" means, how flush is triggered, and what happens to a dirty evicted entry
- [ ] Can choose write-back over write-through or cache-aside for a given scenario and justify with a concrete trade-off statement
- [ ] Can name two production systems that use write-back semantics and explain why durability risk is acceptable there
- [ ] Can propose a durability mitigation strategy for a write-back cache (WAL, replication, periodic snapshotting)

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] **Designing Data-Intensive Applications** (Kleppmann) — Ch. 5, write buffering and replication lag section
- [ ] **ByteByteGo "Top Caching Strategies"** — Alex Xu, YouTube / ByteByteGo newsletter
- [ ] **AWS ElastiCache Write-Behind Pattern** — docs.aws.amazon.com/AmazonElastiCache
- [ ] Read through **Sections 5–9** (Core Definition → How It Works) carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** from memory, then compare
- [ ] Explain **First Principles** out loud without notes — what problem does this solve and why?
- [ ] Reconstruct the **write-back flush sequence** step by step from memory (including failure cases)
- [ ] Restate each **Trade-off** row in your own words — if you can't explain the cost, you don't own it yet

### Phase 3 — Apply 🔧 💪💪💪💪
*Goal: Connect to real systems and simulate interview scenarios.*

- [ ] Go through **Real-World System Examples** (Section 10) — verify each claim independently and add anything missed to **My Notes**
- [ ] Practice the **Interview Application** (Section 12) out loud — say the trigger phrases and your response as if in a live interview
- [ ] Work through **Common Misconceptions** (Section 13) — for each, make sure you can explain *why* the misconception is wrong, not just that it is
- [ ] Trace the **Relationships to Other Concepts** (Section 14) — can you explain each connection without looking?

### Phase 4 — Validate 🧪 💪💪💪💪💪
*Goal: Confirm you actually own it, not just recognize it.*

- [ ] Answer every **Self-Check Quiz** question (Section 15) out loud without looking at your notes
- [ ] Recite the **Cheatsheet** (Section 4) from memory — if you can't, re-do Phase 2
- [ ] Tick off items in **What Mastery Looks Like** (Section 2) — only check a box if you can demonstrate it on demand, not just if it sounds familiar
- [ ] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation or notes

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

![5.3 Write-Back Caching — Mindmap](../assets/images/topic_5.3_write_back_caching_mindmap.png)

```
╔══════════════════════════════════════════════════════════════╗
║  5.3  WRITE-BACK (WRITE-BEHIND) CACHING                     ║
╠══════════════════════════════════════════════════════════════╣
║  § 1  WHY IT EXISTS                                         ║
║  Write-through makes DB the write bottleneck — every ACK    ║
║  waits for cache + DB I/O. Write-back removes DB from the   ║
║  critical path: buffer in cache, flush async.               ║
╠══════════════════════════════════════════════════════════════╣
║  § 2  WHAT IT IS                                            ║
║  Write to cache → ACK client → flush dirty entries to DB    ║
║  asynchronously. Cache is source of truth; DB is stale      ║
║  until flushed.                                             ║
╠══════════════════════════════════════════════════════════════╣
║  § 3  THE 3 CORE CONCEPTS                                   ║
║  1. DIRTY BUFFER — unflused entries. Flush on: time /       ║
║     count / eviction. Evict dirty without flush = data loss.║
║  2. WRITE COALESCING — N writes/key in flush window = 1 DB  ║
║     write. 500 writes/s + 1s flush = 1 DB write/key/s.     ║
║  3. DURABILITY GAP — dirty buffer lost on crash. Size =     ║
║     flush interval. Mitigate: WAL, replication, snapshots.  ║
╠══════════════════════════════════════════════════════════════╣
║  § 4  USE / AVOID                                           ║
║  USE:   write-heavy + eventual persistence OK               ║
║         (counters, leaderboards, session state)             ║
║  AVOID: every write must be immediately durable             ║
║         (financial, inventory, billing)                     ║
╠══════════════════════════════════════════════════════════════╣
║  § 5  INTERVIEW TRIGGERS                                    ║
║  → "DB is a write bottleneck"                               ║
║  → "Field updated hundreds of times per second"             ║
║  → "Design a leaderboard / counter / session store"         ║
╠══════════════════════════════════════════════════════════════╣
║  § 6  FTAC                                                  ║
║  F  "Tension: write latency vs. durability. At 500          ║
║     writes/sec, write-through saturates the DB."            ║
║  T  "Write-through: consistent but DB on critical path.     ║
║     Write-back: sub-ms + 100–500x DB write reduction,       ║
║     but dirty buffer lost on crash."                        ║
║  A  "Assuming ≤1s data loss is tolerable — users expect     ║
║     eventual, not immediate, persistence."                  ║
║  C  "Write-back, 1s flush. Cost: node crash = up to 1s      ║
║     of writes lost. Add WAL if that's unacceptable."        ║
╠══════════════════════════════════════════════════════════════╣
║  § 7  NUMBERS & GOTCHA                                      ║
║  ~1ms write (cache only) vs ~6ms (write-through)            ║
║  Coalescing: 500 writes/s + 1s flush = 1 DB write/key/s     ║
║  GOTCHA: evict dirty entry without flush = silent data loss  ║
╚══════════════════════════════════════════════════════════════╝
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

Write-back caching writes data to the cache and immediately acknowledges the client, then asynchronously flushes the dirty cache entries to the backing database at a later time — decoupling write latency from database I/O at the cost of durability.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### Deferred Write Path
The client writes to the cache and receives an ACK without waiting for the database. The database write is queued and handled out-of-band by a flush process. This makes the write path as fast as a cache write (sub-millisecond for Redis), completely decoupling client-facing write latency from the far slower database I/O path.

### Dirty Buffer
A dirty entry is a cache key whose in-cache value has not yet been persisted to the database. The cache maintains a dirty set (or dirty flag per key). Dirty entries must be flushed before eviction — if a dirty entry is evicted without flushing, the write is lost unless explicitly handled (e.g., forced flush on eviction).

### Flush Trigger Mechanisms
Write-back caches flush dirty entries based on one or more triggers: time-based (flush every N seconds), count-based (flush when dirty count > threshold), eviction-triggered (flush before evicting a dirty entry), or explicit application-triggered. Most production implementations combine time-based and count-based for predictable behavior.

### Durability Gap
The period between a cache write and its corresponding DB flush is the durability gap. Any data written during this window is at risk if the cache node fails. The size of the gap is controlled by the flush interval. Shorter intervals reduce risk but increase DB write pressure, partially eroding the performance benefit.

### Write Coalescing
One of write-back's key advantages is that multiple writes to the same key within a flush window can be coalesced — only the final value is written to the database. If a key is written 100 times per second and the flush interval is 5 seconds, only one DB write occurs per 5-second window instead of 500. This is especially valuable for counters, metrics, and frequently-updated mutable state.

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

The root problem: databases are slow relative to caches, and forcing every write to touch the database — even when the database is not on the read critical path — imposes unnecessary latency on write-heavy workloads.

Write-through solves the stale-read problem but creates a new one: every write now waits for two I/O operations, and the database becomes the bottleneck for write throughput. For systems that are update-heavy — social media like counters, game scores, analytics event aggregators, session state — the database simply cannot absorb the write rate at acceptable latency.

Write-back was invented to break the coupling: let the fast cache absorb writes at full speed, batch them up, and flush to the database at a rate the DB can handle. The underlying insight is that for many workloads, the database does not need to see every write immediately — it just needs to see the latest state eventually. Write-back trades a consistency guarantee for performance headroom, and for many high-throughput systems, that trade is not just acceptable but necessary.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: The Outbox Buffer
Think of write-back like an email outbox. You write an email and it goes to your outbox immediately — you can move on without waiting for it to send. The email client flushes the outbox in the background. If your laptop crashes before it sends, the email is gone. The outbox is the dirty buffer; "sent" is the DB flush; the crash is the durability gap in action. This model makes the risk vivid: the outbox is volatile until flushed.

**Where it breaks down:** Email clients typically retry on reconnect. Write-back caches may not retry on crash — dirty data is gone unless you've implemented WAL or replication. Don't carry the analogy too far on recovery semantics.

### Model 2: CPU L1/L2 Cache
Hardware CPU caches use write-back by default. When the CPU writes to a cache line, the value is held in L1/L2 and not immediately written back to main memory. The dirty cache line is flushed to RAM on eviction or cache coherence events. Modern CPUs accept this risk (power loss = lost CPU state) because the performance gain is enormous. This is exactly the same trade-off — write-back is what makes CPU caches viable at all.

**Where it breaks down:** CPU caches have hardware-level coherency protocols that don't map to distributed systems. The analogy explains the concept, not the implementation.

### Model 3: The Batching Amplifier
Write-back isn't just deferred writes — it's a write multiplier in reverse. Write-through writes 1 DB record per cache write. Write-back writes 1 DB record per *N* cache writes (where N = the coalescing factor within a flush window). For counters updated 1000x/second with a 1-second flush interval, write-back reduces DB write load by 1000x. Frame it this way in interviews when justifying write-back for high-frequency writes.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Normal Write Path:**
1. Client sends a write request to the application
2. Application writes to the cache (Redis, Memcached, etc.) — cache returns ACK immediately
3. Application ACKs the client — write is complete from the client's perspective
4. The cache entry is marked dirty (pending flush)
5. A background flush process (timer, thread, or eviction handler) picks up dirty entries
6. Dirty entries are written to the database in batches (often sorted by key for sequential I/O efficiency)
7. On successful DB write, the dirty flag is cleared

**Read Path:**
Reads are served from cache. If the key is dirty (not yet flushed), the read still returns the latest value from cache — this is correct, since cache holds the ground truth. The database may be stale during the flush window, but reads go to cache, not DB.

**Eviction of Dirty Entries:**
If the cache runs out of space and must evict a dirty entry (one that hasn't been flushed yet), the eviction handler must flush that entry to the DB before eviction. Failing to do this means silent data loss. This is a critical implementation detail — naive LRU eviction without dirty-check handling silently drops writes.

**Flush Failure Handling:**
If the DB is unavailable during a scheduled flush, the dirty buffer continues to grow. The cache must handle: retry with backoff, dirty buffer size limits (reject new writes if buffer is full), and alerting. If the DB is down for longer than cache memory can absorb, writes will be dropped or the cache must degrade to write-through mode.

**Durability Enhancement — WAL:**
High-stakes write-back implementations log dirty writes to a Write-Ahead Log (WAL) on durable storage before ACKing. On cache restart, the WAL is replayed to reconstruct dirty state. This recovers the durability of write-through while preserving most of the latency benefit — but adds I/O complexity.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| CPU L1/L2 Cache | Hardware default write policy — dirty cache lines flushed to RAM on eviction or coherence events | Foundational example; write-back is why CPU caches are practical |
| Redis with write-behind plugin | Dirty keys queued in Redis, background worker flushes to DB (PostgreSQL, MySQL) | Used in write-heavy app layers where DB write latency is unacceptable |
| Cassandra memtable | Writes go to in-memory memtable first, flushed to SSTables on disk asynchronously | Memtable is effectively a write-back buffer; WAL (commit log) provides durability |
| Linux page cache | OS page cache absorbs writes; dirty pages flushed to disk by `pdflush`/`writeback` daemons | `sync()` call forces immediate flush; `vm.dirty_ratio` controls max dirty buffer size |
| MySQL InnoDB buffer pool | Write pages buffered in InnoDB buffer; flushed to disk by background checkpoint thread | Controlled by `innodb_flush_log_at_trx_commit` — setting 2 is write-back semantics |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Lowest write latency — DB removed from write critical path | Durability gap: data in dirty buffer is lost on cache node failure |
| Write coalescing — N writes to same key = 1 DB write | DB can become stale during flush window — DB reads bypass cache at risk |
| DB write throughput reduced — absorbs bursty writes | Complex implementation: dirty tracking, flush ordering, eviction safety |
| Scales write-heavy workloads without DB bottlenecking | Flush backpressure risk: if DB slows, dirty buffer grows unboundedly |
| Read performance unaffected (cache still serves reads) | Harder to reason about consistency — cache is SOT, not DB |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "The service has very high write throughput — how do you handle that?"
- "Users are updating this counter/field hundreds of times per second"
- "We need low write latency but the database is becoming a bottleneck"
- "How would you design caching for a leaderboard / analytics counter / session store?"

**What you say / do:**
In the deep dive phase, after identifying a write-heavy bottleneck, introduce write-back as a way to decouple write latency from database I/O. Immediately follow with: "The trade-off is durability — writes in the dirty buffer are at risk if the cache node fails, so this is appropriate when some data loss is acceptable, or when we add a WAL for recovery." This shows you know the trade-off, not just the pattern.

**The trade-off statement (memorize this pattern):**
> "If we choose write-back, we get sub-millisecond write latency and write coalescing that dramatically reduces DB load, but we pay with a durability gap — dirty writes are lost on cache failure. For this system [e.g., like counts, view counters, leaderboard scores], that trade is acceptable because eventual consistency is sufficient and the data can be reconstructed or approximated."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** Write-back means writes are eventually consistent with the database, so reads from DB will be fine.
  ✅ **Reality:** During the flush window, the database is stale — any read that bypasses the cache (e.g., a replica, a direct DB query, another service) will see old data. Write-back only works correctly when all reads go through the same cache that holds dirty state.

- ❌ **Misconception:** Write-back is just write-through with a delay — the data is safe in the cache.
  ✅ **Reality:** Cache memory is volatile. A node crash, OOM kill, or hardware failure will permanently lose all dirty data that hasn't been flushed. "In the cache" is not the same as "durable."

- ❌ **Misconception:** You can use write-back with LRU eviction without any special handling.
  ✅ **Reality:** LRU eviction of a dirty entry without first flushing it causes silent data loss. Correct write-back implementations must check dirty status before eviction and flush synchronously if the entry is dirty.

- ❌ **Misconception:** Write-back and write-behind are different strategies.
  ✅ **Reality:** They are the same strategy — different names for the same deferred-flush pattern. "Write-behind" emphasizes the buffering aspect; "write-back" emphasizes the return-from-cache aspect. Use them interchangeably.

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** 5.1 Cache-aside and 5.2 Write-through — write-back is the third vertex of the write strategy triangle; you need to know all three to make the contrast argument in an interview
- **Enables:** 5.6 Cache stampede and thundering herd — understanding write-back's flush burst behavior connects to thundering herd under recovery; also enables 5.7 Hot key problem (write-back + coalescing is a key hot-key mitigation for write-heavy keys)
- **Tension with:** 17.1 Linearizability — write-back is fundamentally incompatible with linearizability since the DB is stale during the flush window; it lives in the eventual consistency tier of the spectrum

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. What is write-back caching, and at what point is the client ACKed?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 5.*

Write-back caching is a caching mechanism where clients send a write request to the application. The application writes the data to the cache and immediately responds to the client with an acknowledgement, then asynchronously flushes the dirty entry to the database for persistent storage. 

2. A leaderboard service updates user scores 500 times per second. Write-through caching is causing DB bottleneck. Would you switch to write-back? What's the key condition that must hold?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 12.*

In a condition where we have 500 writes per second, it will likely saturate the dB, and dB write itself becomes a bottleneck. To alleviate the bottleneck, we can introduce a write-back approach. We will now have a durability gap window between data returned to cache versus data persisted to DB. In this window, we can have N number of writes for 500 writes per second. In a one-second flush window, we can coalesce these 500 writes into one single DB write and thereby reduce the load for DB. 

Yes. Write-back with a 1s flush interval coalesces 500 writes/sec into 1 DB write/key/s — 500x load reduction. The key condition: leaderboard scores can tolerate eventual persistence. Losing up to 1s of score updates on a crash is acceptable. If scores were financial balances, this trade-off fails.

3. What is a dirty buffer and what happens if a dirty cache entry is evicted without being flushed?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 6.*

A dirty entry is a cache key whose value has been written to cache but not yet persisted to the database. The dirty buffer is the set of all such entries awaiting flush. If a dirty entry is evicted without flushing first, that write is permanently and silently lost — no DB record, no log. Correct implementations must synchronously flush a dirty entry to DB before allowing its eviction.

4. Name a real production system that uses write-back semantics and explain exactly why it does so.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 10.*

Cassandra writes to an in-memory memtable first and ACKs the client immediately — write-back semantics. The memtable flushes to immutable SSTables on disk asynchronously on time or size threshold. Cassandra accepts the durability gap because its commit log (WAL), written to durable storage before the ACK, allows full recovery on crash. High write throughput is Cassandra's core design goal — write-back is what makes that possible.

5. An interviewer asks: "You're using write-back caching but your cache cluster crashes before the flush — what happens and how do you mitigate it?" Walk through the failure and at least two mitigations.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9.*

Without mitigation: all dirty entries in the flush window are permanently lost — no DB record exists for them. Three mitigations: (1) WAL on independent durable storage — every write is logged before ACK; on recovery the cache replays the log to reconstruct dirty state. (2) Cache replication — dirty entries mirrored to a replica; replica survives primary crash and can complete the flush. (3) Periodic snapshots — dirty buffer serialized to durable storage at intervals; on recovery, load latest snapshot and flush remaining entries.

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **Designing Data-Intensive Applications** (Kleppmann) — Ch. 5, buffered writes and replication lag
- [ ] **ByteByteGo "Top Caching Strategies"** — Alex Xu, YouTube / ByteByteGo newsletter
- [ ] **AWS ElastiCache Caching Strategies** — docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/Strategies.html
- [ ] **Linux kernel writeback documentation** — kernel.org/doc/html/latest/admin-guide/sysctl/vm.html (dirty_ratio, dirty_expire_centisecs)
- [ ] **Cassandra write path** — cassandra.apache.org/doc/latest/cassandra/architecture/storage-engine.html (memtable + commit log)

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

Problem
The problem with Writing to the database is slow compared to writing to cache. If we have heavy writes to a database, that will saturate the DBs and crash the database in terms of the load. With a write-back mechanism, we basically separate writing to cache versus writing to database. In this approach, we have effectively reduced the latency of writing to DB. As such, we can achieve low latency with just writing to cache and returning an acknowledgement to the client. This comes with a trade-off, because we gain the low latency, but now we pay with a data durability gap. This is the gap where data sits in our cache, in our cache entry, and has not been flushed to the database. In the event of a crash, a cache crash, we might potentially lose this data. 

What is write back caching mechanism
Write back caching mechanism: the application receives the request from the client and writes to cache upon successful writes. The application immediately responds to the client with an acknowledgement and then asynchronously flushes Cache the entry data into the database. The time between data sitting in cache and not sitting in the database is what we call a flush window, and it's considered a durability gap where data is not persisted to a durable data store. 

Use / Avoid
We should use a write-back mechanism if the data is not essential and demands strong consistency. For example, the data like counters or leaderboard states do not need to always reflect the latest data states. So we can use the write-back mechanism to have the trade-off between data having a durability gap versus the low latency that the write-back mechanism gives us. If the application is characterized by a write-heavy load, we can also use a writeback mechanism. One way this can work is through write coalescing, where n number of writes is essentially coalesced into one single DB write within a flash window. 

We should avoid using write-back cache mechanism if the nature of the data demands strong consistency, such as financial data, transaction data, billing data, and so on. This kind of data tolerates no data loss And demand correctness at scale. As such, we cannot afford the risk of having a durability gap between the cache and the database for such data. 

Interview template
  F  "Tension: write latency vs. durability. At 500 writes/sec,
     write-through saturates the DB."
  T  "Write-through: consistent but DB on critical path.
     Write-back: sub-ms + 100–500x DB write reduction,
     but dirty buffer lost on crash."
  A  "Assuming ≤1s data loss is tolerable — users expect
     eventual, not immediate, persistence."
  C  "Write-back, 1s flush. Cost: node crash = up to 1s of writes
     lost. Add WAL if that's unacceptable."

A write to cache typically takes about 1ms. while a write to DB takes about 5ms.

Issues that can arise out of a write back mechanism are cache failure/restart For the entries are returned to the database. To mitigate this approach, we can introduce a write-ahead log that independently sits outside of the cache. If the cache fails or restarts and recovers later, it can pick up the write-ahead log and maintain reference to the dirty cache. This prevents data loss during the crash failure window. The other failure is when the database is unavailable during a sync flush event beyond a flush window. In this case, we will need to try an exponential backoff approach to try to flush previous data again. In addition, we also need to make sure the cache is not evicting a dirty entry before it is returned to the database. In such a case, for every cache eviction of a dirty entry, we need to synchronously update the dirty entry into the database. 