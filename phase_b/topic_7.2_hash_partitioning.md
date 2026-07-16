# 7.2 Hash Partitioning

> **Topic:** Topic 7 — Data Partitioning / Sharding
> **Phase:** B — Scalability Branch
> **Date studied:** 2026-07-13

---

## 0. 🗺️ Topic Overview

### What This Topic Is About

Hash partitioning is the mechanism for deciding *which* shard a row lives on by running its partition key through a hash function and mapping the result to a partition. Where 7.1 told you *whether* to split rows horizontally, 7.2 answers *how to assign* those rows to shards. The whole point of hashing is **uniform, uncoordinated placement**: `hash(key)` scatters keys pseudo-randomly across the key space, so load spreads evenly across shards without any central lookup table or human curation. The price you pay is that hashing **destroys ordering** — two adjacent keys (`user_1000`, `user_1001`) land on unrelated shards — which kills range queries and makes hashing the natural rival of range partitioning (7.3). Mastering this subtopic means being able to compute where a key lands, explain why hashing distributes load, and — crucially — explain the `mod N` rebalancing catastrophe that motivates consistent hashing (7.4).

### 🎯 What to Focus On

**1. The two-step mapping.** Hash partitioning is always *hash the key → map the hash to a partition*. The naive map is `hash(key) mod N`. Keep these two steps distinct in your head; the mapping step is where consistent hashing later differs.

**2. Why it distributes load.** A good hash function is uniform: it turns any key distribution — even monotonic auto-increment IDs — into a flat, random spread across partitions. This is the single reason to choose hashing over range partitioning.

**3. What hashing costs you.** Ordering is gone. Range scans (`WHERE created_at BETWEEN ...`), prefix queries, and "next N rows" all become scatter-gather across every shard. If the dominant query is a range, hashing is the wrong tool.

**4. The `mod N` rebalancing bomb.** Adding or removing one node changes `N`, which changes `hash(key) mod N` for *almost every key* — forcing a near-total data reshuffle. This is the failure that consistent hashing (7.4) exists to fix. This is the most tested idea in the subtopic.

**5. Hashing does NOT fix single-key hotspots.** Hashing spreads *many keys* evenly; it cannot spread the traffic of *one* hot key, because that key deterministically hashes to exactly one partition. Know this — interviewers probe it constantly.

---

## 1. 🎯 Goal of This Subtopic

After studying this, you should be able to take any sharded design and specify a hash-partitioning scheme end to end: choose a partition key, apply a hash function, map to partitions, and route a read and a write to the correct shard. You should be able to justify hashing over range partitioning in terms of load distribution, explain precisely why `hash(key) mod N` makes adding capacity catastrophic, and pre-empt the two failure modes interviewers always chase — lost range-query locality and single-key hot partitions that hashing cannot solve.

---

## 2. ✅ What Mastery Looks Like

> *Concrete, testable proof that you own this concept — not just familiarity.*

- [x] Can define hash partitioning in one sentence and describe the two-step mapping (hash the key → map hash to partition)
- [x] Can explain *why* hashing produces even load distribution regardless of the input key distribution, and what property the hash function must have
- [x] Can trace a read and a write to the owning shard, computing `hash(key) mod N` for a concrete key
- [x] Can explain the `mod N` rebalancing problem: why adding one node remaps almost all keys, and why this motivates consistent hashing
- [x] Can explain why hash partitioning kills range queries and turns them into scatter-gather
- [x] Can explain why hashing does NOT solve a single hot key, and distinguish key skew from partition skew

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 3. 🗓️ Study Phases to Achieve Mastery

> *A progressive plan from first exposure to interview-ready. Work through each phase in order. Don't move to the next until you can honestly tick every item.*

### Phase 1 — Acquire 📖 💪💪
*Goal: Read deeply enough that you could explain the concept without the doc.*

- [ ] Read **"Designing Data-Intensive Applications" Chapter 6 — Partitioning by Hash of Key** (Martin Kleppmann) — the definitive treatment; note the trade-off vs. key-range partitioning
- [ ] Read **Amazon DynamoDB Developer Guide — "Partitions and data distribution"** (how the partition key hash places items)
- [ ] Read **Cassandra documentation — "Data distribution and Murmur3Partitioner"** (hash → token ring)
- [ ] Read through **Sections 5–9** (Core Definition → How It Works) carefully — don't skim
- [ ] Re-read the **Cheatsheet** (Section 4) and try to recite it from memory after

### Phase 2 — Consolidate ✍️ 💪💪💪
*Goal: Verify you can reproduce the knowledge in your own words without looking.*

- [ ] Close the doc — write out the **Core Definition** and the two-step mapping from memory, then compare
- [ ] Explain **First Principles** out loud without notes — what was painful about range/manual assignment that hashing fixed?
- [ ] Reconstruct the **`mod N` rebalancing problem** step by step from memory with a concrete example
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
- [ ] Tick off items in **What Mastery Looks Like** (Section 2) — only check a box if you can demonstrate it on demand
- [ ] Teach this concept out loud to an imaginary interviewer for 2 minutes without hesitation or notes

---

## 4. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*

### 🗺️ Hash vs. Range Partitioning Decision Map

```
Do you need to shard rows across nodes? (from 7.1)
└── Yes
    │
    ▼
What is the DOMINANT query pattern on the partition key?
│
├── Point lookups by key (get user 123, get cart abc)
│      │
│      ▼
│   HASH PARTITIONING  ✅
│   partition = hash(key) mod N  (or hash → token ring)
│   Even load, no hotspots from sequential keys, no lookup table.
│   ⚠️ Range queries become scatter-gather across ALL shards.
│   ⚠️ Adding a node with plain mod N remaps ~ALL keys → use consistent hashing.
│
├── Range / ordered scans (time ranges, "next 50", prefix)
│      │
│      ▼
│   RANGE PARTITIONING (see 7.3)
│   Keep ordering; range query hits 1 (or few) contiguous shards.
│   ⚠️ Sequential keys (timestamps, auto-inc IDs) → hot last shard.
│
└── Both point AND range on the same key?
       │
       ▼
    Compromise: hash a high-cardinality prefix, range within it
    (compound key), or maintain a separate ordered index / OLAP store.

REMEMBER: hashing spreads MANY keys evenly. It does NOT spread ONE hot key —
that key hashes to a single partition. Fix single-key skew separately (7.6).
```

```
§ 1  WHY IT EXISTS
Horizontal sharding (7.1) needs a rule to assign each row to a shard. Two bad options:
manual assignment (a lookup table that grows and must be maintained) and range
assignment (sequential keys pile onto the newest shard → hotspot). Hashing solves both:
run the partition key through a uniform hash function and the keys scatter pseudo-
randomly across shards. No lookup table (placement is computed, not stored) and no
sequential hotspot (a monotonic input becomes a flat random spread). Even distribution
with zero coordination is the entire value proposition.

§ 2  THE TWO-STEP MAPPING
STEP 1  hash the key:    h = hash(partition_key)      // uniform, deterministic
STEP 2  map to partition: p = h mod N                  // naive scheme, N = shard count
                          (better: place h on a token ring — see consistent hashing 7.4)
Read/write WITH key: compute p → route to that one shard (+ its replicas). ~1 hop.
Hash function: needs UNIFORMITY + DETERMINISM, not cryptographic strength.
  Common: MurmurHash, xxHash, CRC. (Avoid Java String.hashCode — poorly distributed.)

§ 3  WHAT HASHING COSTS (vs range)
Ordering is DESTROYED: adjacent keys (user_1000, user_1001) land on unrelated shards.
  → Range queries / ordered scans / prefix lookups = SCATTER-GATHER across all N shards,
    bounded by the slowest shard. If the dominant query is a range, DON'T hash.
Point lookups stay cheap (1 shard); ranges become expensive. Choose by query pattern.

§ 4  THE mod N REBALANCING BOMB (most tested)
partition = hash(key) mod N depends on N. Change N (add/remove a node) → the modulus
changes → hash(key) mod N changes for ALMOST EVERY key → near-total data reshuffle.
  Example: 4→5 nodes remaps ~80% of keys. This is catastrophic at scale.
FIX: consistent hashing (7.4) — adding a node moves only ~1/N of keys, not ~all.

§ 5  HASHING ≠ HOTSPOT-PROOF (key skew vs partition skew)
Hashing evens out load ONLY when load is spread across MANY distinct keys.
A single hot key (celebrity user, viral product) hashes to ONE partition → that
partition is hot no matter how good the hash is. Hashing cannot split one key.
  Also: low-cardinality keys (country, boolean) → few distinct hashes → skew.
Distinguish: KEY skew = one value too popular; PARTITION skew = uneven value→shard map.

§ 6  USE / AVOID
Use HASH:   dominant access is point lookup by a high-cardinality key; you want even
            load and no manual placement; sequential keys would otherwise hotspot.
Use RANGE:  dominant access is ordered/range scans; you can tolerate hotspot mitigation.
Avoid HASH: range queries dominate; OR a single key carries a huge share of traffic
            (fix that separately); OR you're using plain mod N and expect to rescale
            often (use consistent hashing instead).

§ 7  INTERVIEW TRIGGERS + FTAC
Triggers: "How do you decide which shard a row goes to?" / "How do you spread load
  evenly?" / "What happens when you add a shard?" / "Why not just mod the ID by N?"
F  "I need to place each row on a shard. Hashing the partition key gives even,
   coordination-free distribution — but it destroys ordering."
T  "Hash buys uniform load and no sequential hotspot; it costs range-query locality
   (scatter-gather) and, with plain mod N, a full reshuffle when N changes."
A  "Assuming reads are point lookups by user_id and there's no single dominant hot key —"
C  "I'd hash user_id (MurmurHash) onto a consistent-hash ring so adds move only ~1/N of
   keys, replicate each shard, and push any range/analytics queries to a separate store."

§ 8  NUMBERS & GOTCHA
mod N reshuffle:  4→5 nodes remaps ~80% of keys; consistent hashing moves only ~1/N.
Redis Cluster:    CRC16(key) mod 16384 fixed hash slots (slots move, not the formula).
Cassandra:        Murmur3 → 64-bit token ring; DynamoDB hashes the partition key.
Hash fn:          pick uniform + fast (MurmurHash/xxHash), NOT cryptographic (too slow).
GOTCHA: candidates say "hashing removes hot partitions." FALSE — it removes hotspots
  caused by sequential/skewed key ranges, but a single high-traffic KEY still lands on
  one partition. And plain hash(key) mod N is a trap: it works until the first rescale,
  then remaps almost everything. Reach for consistent hashing before you're asked.
```

---

## 5. 🧠 Core Definition

> *What is it, in one sentence?*

**Hash partitioning** assigns each row to a shard by applying a hash function to its partition key and mapping the resulting hash value to a partition (classically `partition = hash(key) mod N`, or better, by placing the hash on a token ring) — producing an even, computed, coordination-free distribution of keys across shards at the cost of destroying key ordering.

---

## 6. 📦 Core Concepts

> *The essential building blocks of this subtopic — the terms and ideas you must have solid before going deeper.*

### The Hash Function
A deterministic function that maps a partition key to a fixed-range integer, chosen so that any distribution of inputs produces a near-uniform spread of outputs. The critical properties are **uniformity** (outputs evenly fill the range, so shards get equal shares) and **determinism** (the same key always hashes to the same value, so routing is reproducible without a lookup table). Cryptographic strength is *not* required — production systems use fast non-cryptographic hashes like MurmurHash, xxHash, or CRC. A poor choice (e.g., Java's `String.hashCode`, which clusters) produces uneven partitions.

### The Two-Step Mapping (hash → partition)
Placement is always two steps: first `h = hash(key)`, then map `h` to one of `N` partitions. The naive mapping is `h mod N`. Keeping these steps separate matters because consistent hashing (7.4) keeps step 1 identical and only changes step 2 (map the hash onto a ring of positions instead of taking it mod N), which is what fixes the rebalancing problem.

### Uniform Load Distribution
The reason to hash at all. Because a good hash scrambles inputs, even a pathological key distribution — monotonically increasing IDs, timestamps, sequential order numbers — comes out as a flat random spread. This eliminates the "all new writes hit the newest shard" hotspot that plagues range partitioning, without anyone having to hand-balance shards.

### The `mod N` Rebalancing Problem
The defining weakness of naive hash partitioning. Because the partition is `hash(key) mod N`, the assignment depends on `N`. Change `N` by adding or removing a node and the modulus changes, so `hash(key) mod N` changes for *almost every key* — forcing a near-total reshuffle of data across the cluster. This is why plain `mod N` is unsuitable for elastic clusters and why consistent hashing exists.

### Key Skew vs. Partition Skew
Two distinct failure modes. **Partition skew** (the standard term is **data skew**) is uneven key→shard mapping — some shards hold far more keys/load than others — caused by a **low-cardinality *and* unevenly-popular** key (e.g., `country`, where most users cluster into a handful of values, so a huge fraction hashes onto one shard) or a weak hash function. **Key skew** (the standard term is **load skew** / access skew) is a single key carrying a disproportionate share of traffic (a celebrity user, a viral product). Hashing fixes neither perfectly: it assumes load is spread across many keys, and it deterministically sends one key to one partition, so a single hot key remains hot regardless of hash quality (handled in 7.6). Note the two modes aren't perfectly orthogonal — low-cardinality partition skew is essentially key skew at the *value* level (a popular value behaves like a hot key).

---

## 7. 🔍 First Principles — Why Does This Exist?

> *What fundamental problem does this concept solve? Why was it invented?*

Once you've decided to shard rows horizontally (7.1), you face an unavoidable question: given a row, which shard owns it? The answer must be cheap to compute, must spread data evenly so no node is overloaded, and ideally must require no central coordinator to consult on every request. The obvious naive answers all fail. A **lookup table** ("key → shard" stored somewhere) works but becomes a bottleneck and a single point of failure, and it grows with the data. **Range assignment** (shard 1 gets IDs 0–1M, shard 2 gets 1M–2M) preserves ordering but creates a brutal hotspot: because most systems generate keys monotonically (auto-increment IDs, timestamps, snowflake IDs), *every new write lands on the last shard* while earlier shards go cold.

Hashing is the insight that a good hash function is a *coordination-free load spreader*. Run the key through it and you get a pseudo-random position that is (a) computed on the fly with no stored table, (b) identical every time for the same key, and (c) uniformly distributed even if the input keys are sequential or clustered. That converts the placement problem into pure arithmetic and turns a monotonic write stream into an evenly balanced one. The remaining wrinkle — that the simplest mapping, `mod N`, breaks when the cluster resizes — is precisely the gap that consistent hashing was invented to close, which is why 7.2 sets up 7.4.

---

## 8. 🗺️ Mental Models

> *Intuition frames that help you reason about this concept fast — especially under interview pressure.*

### Model 1: The Coat-Check Ticket
When you hand your coat to a coat check, they don't file it by your name (which would clump all the "S" surnames together); they give you a hash — a numbered ticket — and store the coat in the slot matching that number. Retrieval is a pure computation: ticket → slot, no searching, no ordering. Hash partitioning is the same: the key's hash *is* the ticket, and the slot is the shard. It works because numbers spread evenly across slots regardless of how names cluster. Where it breaks down: if the cloakroom adds slots (more shards), every ticket's slot number changes under `mod N` — you'd have to re-file every coat. That's the rebalancing problem made physical.

### Model 2: Shuffling a Deck vs. Sorting It
Range partitioning is a *sorted* deck: cards in order, so "give me the 10 through King of hearts" is one contiguous grab — but every new card gets added to the same end (hotspot). Hash partitioning *shuffles* the deck: any card is equally likely to be anywhere, so dealing evenly across N hands is trivial and no single hand fills up first — but "give me the hearts in order" now means searching every hand (scatter-gather). The model captures the core trade instantly: shuffling buys balance and costs order; sorting buys order and costs balance. Where it breaks down: real hashing is deterministic, not random — the "shuffle" is fixed per key, which is what makes lookups reproducible.

### Model 3: The Modulus Trap Frame
When you hear "shard by `id % number_of_servers`," a mental alarm should fire: *what happens the day we add a server?* Picture keys 0–11 across 3 servers (`% 3`): key 7 → server 1. Add a fourth server (`% 4`): key 7 → server 3. Nearly every key moved. This frame — "does the placement formula depend on N?" — instantly tells you whether a hashing scheme is elastic. If yes (plain mod N), it's a trap; if the formula is N-independent (consistent hashing's ring), it's safe. Where it breaks down: it's a diagnostic, not a design — knowing mod N is bad is only useful if you can then reach for the ring.

---

## 9. ⚙️ How It Works — Mechanics

> *Step-by-step or layered explanation of the internal mechanism.*

**Placement (write path, happy case):**
1. Application writes a row with partition key `k`, e.g., `user_id = 12345`.
2. The routing layer computes `h = hash(k)` using a uniform hash (MurmurHash, CRC16, Murmur3, etc.).
3. It maps `h` to a partition. Naive: `p = h mod N`. The row is written to shard `p`'s primary, which then replicates to its own replicas.
4. Because different keys hash to different values, writes spread evenly across all shards — aggregate write throughput scales with shard count.

**Point read (happy case):**
1. A read keyed by the partition key, e.g., `SELECT * FROM users WHERE user_id = 12345`.
2. Router computes `hash(12345) mod N` → the owning shard.
3. Query goes to that one shard (and optionally a read replica). Cost ≈ single-node lookup, one hop. This is hashing's sweet spot.

**Range query (the failure mode):**
1. A query over a range or order, e.g., `WHERE user_id BETWEEN 10000 AND 20000` or `ORDER BY created_at LIMIT 50`.
2. Because hashing scattered adjacent keys across unrelated shards, the router cannot localize the range to any subset of shards.
3. It must **scatter-gather**: fan the query to all N shards, each scans its local slice, the coordinator merges/sorts. Latency is bounded by the slowest shard and cost grows with N. This is why hashing is wrong when ranges dominate.

**The `mod N` rebalancing catastrophe (concrete):**
1. Start with N = 4 shards; a key with `hash(k) = 100` lives on shard `100 mod 4 = 0`.
2. Add one shard → N = 5. Now the same key maps to `100 mod 5 = 0` — but consider `hash(k) = 101`: was `101 mod 4 = 1`, now `101 mod 5 = 1`... in aggregate, roughly `1 − 1/N` of all keys change shards.
3. Adding a 5th node to 4 remaps ~80% of keys, triggering a massive data migration and cache invalidation storm. Elastic clusters therefore cannot use plain `mod N`.

**Why consistent hashing fixes it (preview of 7.4):**
1. Instead of `mod N`, place both keys and nodes on a fixed ring of positions (e.g., 0 to 2³²−1) by hashing them.
2. A key belongs to the first node clockwise from its position. Adding a node only steals the keys between it and its predecessor — about `1/N` of keys — leaving everything else untouched.

**Key parameters to reason about:**
- **Hash function**: uniform + fast, not cryptographic. Poor distribution (clustering) causes partition skew.
- **Partition key cardinality**: must be high; low-cardinality keys produce few distinct hashes → skew.
- **Mapping scheme**: plain `mod N` (simple, not elastic) vs. consistent hashing / fixed hash slots (elastic). Redis Cluster uses a fixed 16384-slot space precisely so the *formula* never changes even as slots are reassigned between nodes.

---

## 10. 🏭 Real-World System Examples

> *Where does this appear in production systems you know?*

| System | How This Concept Applies | Notes |
|--------|--------------------------|-------|
| **Amazon DynamoDB** | The **partition key** is hashed to determine which internal partition stores the item; even distribution across partitions is the basis of DynamoDB's scaling and throughput model | A single hot partition key still throttles (key skew); AWS added *adaptive capacity* and recommends high-cardinality keys or write-sharding suffixes to mitigate |
| **Apache Cassandra** | Uses a **partitioner** (default `Murmur3Partitioner`) to hash the partition key into a 64-bit token, placing rows on a token ring — consistent hashing with virtual nodes | Range queries on partition keys are not supported efficiently; clustering keys give ordering *within* a partition, not across |
| **Redis Cluster** | Keys are mapped by `CRC16(key) mod 16384` to one of **16384 fixed hash slots**; slots are distributed across nodes | The formula is N-independent by design — rescaling moves *slots* between nodes, not the hashing rule; hash tags `{...}` force related keys into the same slot |
| **Apache Kafka (producer)** | Default partitioner sends a record to `hash(key) mod partition_count` so all records with the same key land on the same partition (ordering per key) | Changing partition count breaks the key→partition mapping — a classic `mod N` gotcha for Kafka operators |
| **Memcached (client-side)** | Clients hash the key to choose a server; naive `mod N` clients reshuffle almost all keys when a server is added/removed | The pain of `mod N` here is exactly what popularized consistent hashing (Ketama) in memcached clients |

---

## 11. ⚖️ Trade-offs

> *Every design decision has a cost. What are you giving up?*

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| Even, uniform load distribution even for monotonic/sequential keys — no "newest shard" hotspot | Ordering is destroyed: range queries, ordered scans, and prefix lookups become scatter-gather across all shards |
| Coordination-free placement — the shard is computed from the key, no lookup table to store or bottleneck | A single hot key still lands on one partition; hashing does not solve key skew (only spreads many keys) |
| Simple to implement and reason about (`hash(key) mod N`) | Plain `mod N` remaps ~all keys when N changes — catastrophic reshuffle; needs consistent hashing to be elastic |
| Point lookups by key are a single-shard, single-hop operation | Requires a high-cardinality, well-distributed partition key; low-cardinality keys cause partition skew |
| Works identically for any key type once hashed (strings, UUIDs, composite keys) | You lose the ability to answer "give me the next N in order" cheaply — you must maintain a separate ordered index/store |

---

## 12. 🎯 Interview Application

> *How do you use this concept in a design interview? What triggers it?*

**When an interviewer asks / says:**
- "How do you decide which shard a given row goes to?"
- "How do you make sure load is spread evenly across shards?"
- "You suggested `user_id % number_of_servers` — what happens when we add a server?"
- "Why not just range-partition by ID? / Why hash instead of range?"
- "This key is monotonically increasing — how do you avoid a hotspot?"

**What you say / do:**
Introduce hashing in the deep-dive/data-partitioning phase, and lead with the trade-off, not the mechanism. "I'd hash the partition key so load spreads evenly — that avoids the sequential-write hotspot you'd get from range partitioning. The cost is that I lose ordering, so any range or ordered query becomes scatter-gather; I'd handle those from a separate index or OLAP store." Then pre-empt the two things the interviewer is waiting to hear: (1) don't use plain `mod N` — "I'd use consistent hashing so adding a node moves only ~1/N of keys instead of reshuffling everything," and (2) hashing doesn't fix a single hot key — "if one key is disproportionately hot, I'd shard that key's writes with a suffix or cache it, separately from the hashing scheme."

**The trade-off statement (memorize this pattern):**
> "Hash partitioning buys me even load distribution and coordination-free placement, but it destroys key ordering — so range queries become scatter-gather across all shards. For this system, since the dominant access is point lookups by `user_id` and keys are monotonically generated, hashing is the right call over range partitioning. I'd map via consistent hashing rather than `mod N` so scaling only moves ~1/N of keys, and I'd handle single hot keys separately since hashing sends one key to exactly one partition."

---

## 13. ⚠️ Common Misconceptions & Gotchas

> *What do candidates get wrong? What nuance is the interviewer probing for?*

- ❌ **Misconception:** Hash partitioning eliminates hot partitions.
  ✅ **Reality:** It eliminates hotspots caused by *sequential or clustered key ranges* (e.g., all new IDs hitting the newest shard). It does **not** eliminate a hotspot caused by a single high-traffic *key* — that key deterministically hashes to one partition, so that partition is hot no matter how good the hash. Key skew is a separate problem (7.6).

- ❌ **Misconception:** `hash(key) mod N` is a fine long-term sharding scheme.
  ✅ **Reality:** It works until the first time you change `N`. Because the mapping depends on the modulus, adding or removing one node remaps *almost every key* (~`1 − 1/N`), forcing a near-total data migration. Elastic clusters must use consistent hashing (or a fixed slot space like Redis's 16384 slots) instead.

- ❌ **Misconception:** Hash partitioning lets you do range queries as long as you keep an index.
  ✅ **Reality:** Hashing itself provides *no* range locality — adjacent keys are scattered across unrelated shards, so a range query is inherently scatter-gather on the hashed table. You can support ranges only by maintaining a *separate* ordered structure (a range-partitioned secondary index or an OLAP store), which is extra machinery, not a property of hashing.

- ❌ **Misconception:** Any hash function will do — even `String.hashCode()`.
  ✅ **Reality:** The hash must be *uniform*. Weak hashes (Java's `String.hashCode`, naive sums) cluster outputs and produce partition skew — some shards overloaded, others idle. Production systems deliberately use uniform, fast, non-cryptographic hashes (MurmurHash, xxHash, CRC, Murmur3).

---

## 14. 🔗 Relationships to Other Concepts

> *How does this connect to adjacent subtopics in this topic or across the roadmap?*

- **Builds on:** 7.1 Horizontal Partitioning — hashing is one of the two *mechanisms* for assigning rows to horizontal shards; and the partition-key concept from 7.1 (a good hash is only as good as the cardinality/distribution of the key you feed it)
- **Enables:** 7.4 Consistent Hashing — the direct fix for this subtopic's `mod N` rebalancing problem; 7.5 Rebalancing — hashing determines how much data must move when nodes change; and it underpins hash-based routing used in caching (5.7 hot key, 5.8 multi-level) and load balancing (4.2 IP hash)
- **Tension with:** 7.3 Range Partitioning — the direct rival; hashing gives even load but no range locality, range gives locality but risks sequential hotspots — you pick based on the dominant query pattern. Also in tension with 7.6 Hot Partitions, since hashing cannot resolve a single hot key

---

## 15. 🧪 Self-Check Quiz

> *Can you answer these without looking? If not, you haven't internalized it yet.*

1. Define hash partitioning in one sentence and describe the two-step mapping from a key to a shard.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 5.*
HASH PARTITIONING: assign each row to a shard by hashing its partition key and mapping
the hash to a partition, giving even, computed, coordination-free placement.
TWO STEPS: (1) h = hash(key) — uniform, deterministic; (2) map h to a partition —
naively p = h mod N, or better, place h on a token ring (consistent hashing).

2. Why does hashing produce even load even when the input keys are monotonically increasing IDs, and what single property must the hash function have?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Sections 6 and 7.*
A uniform hash scrambles inputs so that even a sequential stream of keys comes out as a
flat, pseudo-random spread across the output range — so consecutive IDs land on
unrelated shards instead of piling onto the newest one. The required property is
UNIFORMITY (outputs evenly fill the range). Determinism is also needed for reproducible
routing, but uniformity is what delivers even load. Cryptographic strength is NOT needed.

3. You shard with `hash(key) mod 4`. You add a fifth node. What happens, and why is it a problem?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 9 (mod N catastrophe).*
The modulus changes from 4 to 5, so hash(key) mod N changes for almost every key —
roughly 1 − 1/N ≈ 80% of keys are remapped to a different shard. That triggers a
near-total data migration and cache-invalidation storm across the cluster. It's a
problem because scaling should be cheap; plain mod N makes it catastrophic. Fix:
consistent hashing, where adding a node moves only ~1/N of keys.

4. Name a real system that uses hash partitioning and describe the routing consequence of its scheme.

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Section 10.*
Redis Cluster: keys map via CRC16(key) mod 16384 to one of 16384 fixed hash slots,
and slots are distributed across nodes. Because the slot count (the modulus) is fixed,
rescaling moves SLOTS between nodes rather than changing the hashing formula — avoiding
the mod N reshuffle. (Alternatives: Cassandra hashes to a Murmur3 token ring;
DynamoDB hashes the partition key; Kafka sends hash(key) mod partitions.)

5. A candidate says "we'll hash the key, so we'll never have a hot partition." A celebrity user with 50M followers is on the system. What's wrong?

   > 💡 *Think through your answer before expanding — if you hesitate, revisit Sections 6 and 13.*
Wrong: hashing spreads MANY keys evenly, but a SINGLE key deterministically hashes to
exactly ONE partition. The celebrity's key lands on one shard, and all that traffic
concentrates there — a hot partition hashing cannot prevent. Hashing removes hotspots
from sequential/clustered key ranges (KEY-range skew), not from one disproportionately
popular key (KEY skew). Fix separately (7.6): write-sharding the hot key with a suffix,
caching it, or replicating it — not a better hash.

---

## 16. 📚 Further Reading

> *Optional: links, chapters, or resources for deeper understanding.*

- [ ] **"Designing Data-Intensive Applications" — Chapter 6, Partitioning by Hash of Key** (Martin Kleppmann) — the definitive treatment; contrast hash vs. key-range partitioning and note the loss of range-query support
- [ ] **Amazon DynamoDB Developer Guide — "Partitions and data distribution"** — https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.Partitions.html — how the partition key hash places items and why key cardinality matters
- [ ] **Cassandra — "How data is distributed" (Murmur3Partitioner)** — https://cassandra.apache.org/doc/latest/cassandra/architecture/dynamo.html — hashing the partition key to a token ring
- [ ] **Redis — "Cluster specification: hash slots"** — https://redis.io/docs/reference/cluster-spec/ — CRC16 mod 16384 fixed-slot hashing and hash tags
- [ ] **ByteByteGo — "Consistent Hashing"** — https://blog.bytebytego.com/p/consistent-hashing — sets up why `mod N` fails and motivates 7.4

---

## 17. ✍️ My Notes

> *Personal observations, things that confused me, analogies that helped.*

CRITERION 1 — MODEL ANSWER
Definition (one-liner):
  "Hash partitioning assigns each row to a shard by hashing its partition key,
   giving even, computed-on-the-fly placement (no lookup table) — at the cost
   of destroying key ordering."
Two-step mapping:
  1. h = hash(partition_key)   → uniform value (key: high cardinality + even distribution)
  2. p = h mod N               → shard index; store the row on shard p

CRITERION 2 — MODEL ANSWER
Why even load (even for sequential keys):
  A good hash has NO correlation between input adjacency and output (avalanche):
  1000 and 1001 produce unrelated, spread-out values. Across many keys the outputs
  fill the range uniformly → each shard gets ~equal share. Sequential structure
  in the INPUT is destroyed, so no "newest shard" hotspot.
Property split:
  Uniformity   → even load (outputs evenly fill the range)
  Determinism  → reproducible routing, no lookup table (same key → same shard)

CRITERION 3 — MODEL ANSWER
Route: hash("user:77") = 930418 → 930418 mod 8 = 2 → shard 2
Write: request → hash → mod 8 → shard 2's PRIMARY → replicate to shard 2's replicas
       (async = fast, small loss window; sync/quorum = durable, slower)
Read:  request → hash → mod 8 → shard 2 (primary or a replica) → return. 1 shard, 1 hop.
Principle: partitioning → capacity + throughput; replication under each shard → durability + availability.

CRITERION 4 — MODEL ANSWER
mod N problem:
  Placement = hash(key) mod N depends on N. Add a shard (4→5) → modulus changes →
  hash(key) mod N changes for ~(N−1)/N of keys (≈80%). e.g. hash=22: 22 mod 4 = 2,
  22 mod 5 = 2 → stays (the lucky minority); most keys land on a new shard → mass migration.
Consistent hashing fix:
  Hash BOTH keys and nodes onto a ring; a key belongs to the next node clockwise.
  Adding a node drops it at one point and it only steals the arc behind it → ~1/N keys move,
  not ~all.

CRITERION 5 — MODEL ANSWER
Why range → scatter-gather:
  Hashing scattered adjacent user_ids across unrelated shards (no ordered storage),
  so the router can't localize BETWEEN 1000 AND 2000 to any subset. It must fan out
  to ALL shards, each scans locally, coordinator merges.
Latency: bounded by the SLOWEST shard; cost also grows with shard count.
Fix: serve ranges from a separate ordered index / OLAP store, or use range partitioning (7.3).

CRITERION 6 — MODEL ANSWER
Why hashing doesn't help: hashing spreads MANY keys uniformly, but determinism sends
  one user_id to exactly one shard. A better hash can't split a single key.
Key skew:       one key carries a disproportionate share of traffic (celebrity, viral item).
Partition skew: uneven key→SHARD mapping — some shards hold far more keys/load
                (low-cardinality or unevenly-popular key, e.g. country; or a weak hash).
Celebrity case = KEY skew. Fix lives in 7.6 (write-sharding, caching, replication) — not hashing.

STRESS-TEST — MODEL ANSWER
1. Consistent hashing does NOT fix the hot key. It only bounds rebalancing to ~1/N on
   resize; determinism still pins one key to one shard. Different problem.
2. Fix: write-shard the hot key — append a suffix (celebrity_id#0..#M), so it hashes
   across M shards. (Random/rotating suffix general; semantic suffix like country only
   if reads know it.)
3. New problem: reads for that key can no longer be 1 hop — must query all M sub-keys
   and merge → scatter-gather (read amplification). If applied to EVERY user, every read
   pays that fan-out. So apply ONLY to hot keys → now you must DETECT hot keys and keep
   routing state. Trade: write hotspot → read fan-out + tracking complexity.