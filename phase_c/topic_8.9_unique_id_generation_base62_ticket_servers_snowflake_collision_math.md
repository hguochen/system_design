# 8.9 Unique ID Generation — base62, Ticket Servers, Snowflake, Collision Math

> **Topic:** Topic 8 — Database Fundamentals
> **Phase:** C — Data Storage Branch
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 8.1 (SQL vs. NoSQL), 8.4 (Indexing — B-tree, LSM-tree)
> **Date studied:** _____

---

## 0. 🧭 The Question This Answers

8.4 established that a B-tree's insert cost depends entirely on *where in the key space the insert lands* — a sequential key appends to the rightmost leaf and touches one hot page, a random key scatters across the whole index and touches a cold one every time. That was a statement about indexes. This subtopic asks where the key itself comes from, and it turns out the two questions are the same question: **the shape of your ID is a write-path performance decision disguised as a naming decision.**

The tension is that uniqueness is a *global* property — to know an ID is unique you need to know about every other ID ever minted — but you want to mint it *locally*, on one machine, with no network round trip, millions of times a second. Every scheme in this subtopic is a different answer to how you get a global guarantee without a global read, and each one pays for it in a different currency: latency, availability, index locality, or a residual probability of collision.

**The question:** *How do you mint an identifier that is unique across every machine in the fleet without any of them talking to each other on the write path — and what does the ID's shape cost you at the index?*

> **→ Next:** Before we compare schemes, we need to see what actually broke. What was wrong with just asking the database for the next number?

---

## 1. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §2 and come back here for revision.

```
§ 1  WHY IT EXISTS
A single database's AUTO_INCREMENT is a perfect ID generator: unique,
monotonic, 8 bytes, free. It works because the database is a single
coordinator that remembers every ID it has ever issued. Shard that database
and the coordinator disappears — each shard's counter restarts at 1 and the
shards collide. The instinctive replacements both fail in instructive ways.
A central ID service puts a network hop and a shared fate in front of every
single insert, so its availability becomes a ceiling on your write
availability. Random UUIDv4 removes coordination entirely but destroys the
index locality 8.4 spent its whole argument on — a random primary key means
every insert lands in a random B-tree leaf. The resolution is to PARTITION
the ID space rather than SERIALIZE access to it, and to put time in the high
bits so the keys stay roughly ordered anyway.

§ 2  WHAT IT IS — THE COORDINATION DIAL, FOUR POSITIONS
COORDINATE PER WRITE   AUTO_INCREMENT, central ID service. Perfect order,
                       8 bytes. Costs a round trip and shared fate per insert.
COORDINATE PER BATCH   Ticket server. Lease a block of 1000, mint locally
                       from it. Amortizes the round trip 1000:1. Costs gaps
                       on crash and loss of global monotonicity.
PARTITION THE SPACE    Snowflake. Each machine owns a disjoint slice by
                       construction, so collision is impossible with zero
                       runtime coordination. Costs you a worker-ID assignment
                       problem, moved from write time to deploy time.
REPLACE WITH           UUIDv4 — 122 random bits. No coordination ever.
PROBABILITY            Costs all ordering, so no index locality, and 16 bytes.
UUIDv7 sits between the last two: a 48-bit ms timestamp in the high bits plus
74 random bits — client-mintable like v4, k-sorted like Snowflake.

§ 3  THE MECHANISM — THE SNOWFLAKE BIT BUDGET
   1 bit  sign, unused (keeps the ID positive in a signed BIGINT / Java long)
  41 bits millisecond timestamp since a CUSTOM epoch → 2^41 ms ≈ 69.7 years
  10 bits machine id                                 → 1024 nodes
  12 bits sequence, per machine per millisecond      → 4096 IDs/ms/machine
  id = (ts << 22) | (machine_id << 12) | sequence
FLEET CEILING  1024 × 4096 = 4.19M IDs per millisecond ≈ 4.19 BILLION/sec.
THE FIELDS ARE A BUDGET, NOT A CONSTANT. Need 4096 machines? Take two bits
from the sequence: 41/12/10 gives 1024 IDs/ms/machine. Say this out loud —
it demonstrates you understand it as a parameterized design.
THE ONE INVARIANT  The timestamp must stay in the HIGH bits. Move it and you
lose the sort order, and with it the entire index-locality argument.

§ 4  USE / AVOID
AUTO_INCREMENT when: one logical database, not sharded. It is free, compact,
  and index-optimal. Reaching for Snowflake on a single-Postgres design is
  over-engineering and interviewers notice.
SNOWFLAKE when: sharded or multi-writer, the server mints the ID, you want
  8 bytes and k-sorted keys, and you can assign worker IDs authoritatively.
UUIDv7 when: the CLIENT must mint the ID before the write reaches a server
  (offline drafts, idempotency keys) but you still want index locality.
TICKET SERVER when: you want compact monotonic 64-bit integers and can accept
  one coordinator, amortized 1000:1. The cheap, boring, still-correct answer.
AVOID UUIDv4 as a clustered primary key in InnoDB — random inserts thrash the
  buffer pool, and the 16-byte PK is copied into every secondary index.
AVOID monotonic IDs as the PARTITION KEY of a hash-partitioned store. There
  the rule inverts: sequential keys concentrate every write on one partition.
AVOID hash-and-truncate for short codes unless you also build the retry loop.

§ 5  THE MATH — SIZING AND COLLISION
BASE62 SIZING (assigned keys — no collision possible)
  62^6 = 56.8 BILLION      62^7 = 3.52 TRILLION      62^8 = 218 TRILLION
  1B keys (100M/yr × 10yr) fits in 6 chars with room; 7 gives headroom.
BIRTHDAY BOUND (drawn keys — hashing, truncation, random codes)
  P(collision) ≈ 1 − e^(−k²/2N) ≈ k²/2N     50% point ≈ 1.177·√N
  THE POINT: collisions bite at √N, NOT at N.
  7-char truncated hash: N = 3.52e12, but 50% collision at ~2.2 MILLION keys.
  8-char: 50% at ~17 million. UUIDv4: N = 2^122, 50% at ~2.7e18 — never.
  At 1 billion keys in a 7-char space, k²/2N ≈ 142,000 — collisions certain.

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
UUID 16 bytes vs. BIGINT 8 bytes — and in InnoDB the clustered PK is embedded
  in EVERY secondary index, so the 8 bytes are paid many times over.
Snowflake epoch: Twitter used 2010-11-04. Pick your own; it buys the full 69
  years starting now instead of burning 40 of them on the Unix epoch.
Instagram: 41 bits ms + 13 bits logical shard (8192 shards) + 10 bits sequence.
Worker-ID by hash(hostname) % 1024 with only 40 pods collides ~53% of the time.
Ticket server refill at ~80% of the block; blocks of 1000 amortize 1000:1.

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "How do you generate the short code?"          → size base62 FIRST, then
                                                    say how the number is made
→ "What's the primary key, and where does        → name the scheme AND the
   it come from?"                                   index consequence
→ "You're sharded across 50 DBs — how do you     → partition the ID space,
   avoid two shards issuing the same ID?"           don't centralize it
→ "Can the client generate the ID?"              → UUIDv7, and say why not v4
GOTCHA #1: Saying "I'd use UUIDs, they're globally unique." Uniqueness was
  never the hard part. The hard part is uniqueness WITHOUT coordination AND
  WITHOUT destroying index locality, and UUIDv4 solves only the first half.
GOTCHA #2: "62^7 is 3.5 trillion, so 7 characters handles trillions of
  links." Only if you ASSIGN them. If you hash into them, the birthday bound
  puts your 50% collision point at 2.2 million.
GOTCHA #3: Naming clock skew as Snowflake's main risk. Clock skew fails
  LOUDLY — the generator refuses to issue. Duplicate worker IDs fail
  SILENTLY, producing perfectly well-formed IDs that collide occasionally.
```

---

## 2. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                          ┌────────────────────────────────────┐
                          │      UNIQUE ID GENERATION          │
                          │  "where does uniqueness come from  │
                          │   — and what does its shape cost?" │
                          └─────────────────┬──────────────────┘
                                            │
  ┌────────────────┬───────────────┬────────┴───────┬───────────────┬──────────────┐
  ▼                ▼               ▼                ▼               ▼              ▼
THE CONSTRAINTS  THE COORD.     THE SCHEMES     THE BIT BUDGET   THE MATH      REAL SYSTEMS
                 DIAL
├ globally      ├ per write    ├ AUTO_          ├ 41b ms ts      ├ base62      ├ Twitter
│  unique       │  central svc │  INCREMENT     │  ≈ 69.7 yrs    │  62^6=56.8B │  Snowflake
├ k-sorted      ├ per batch    ├ ticket server  ├ 10b machine    ├ 62^7=3.5T   ├ Instagram
│  (8.4 index   │  ticket srv  ├ Snowflake      │  = 1024 nodes  ├ birthday    │  per-shard
│   locality)   ├ partition    ├ UUIDv4         ├ 12b sequence   │  bound: √N  │  in Postgres
├ compact       │  the space   │  (122 rand)    │  = 4096/ms     ├ 7 chars →   ├ Flickr
│  8 vs 16 B    │  Snowflake   ├ UUIDv7 / ULID  ├ custom epoch   │  50% at     │  ticket srv
├ mintable      └ probability  └ hash+truncate  └ RE-CUT the     │  2.2M keys  ├ MongoDB
│  offline         UUIDv4         ⚠ collisions     fields — it's ├ UUIDv4 safe │  ObjectId
└ unguessable                                      a budget      │  to ~2.7e18 ├ UUIDv7
   ⚠ conflicts                                                   └ assigned ≠  │  RFC 9562
     with dense                                                     drawn      └ bit.ly
     & ordered                                                                    base62
```

**How to read it:** the **constraints** are mutually hostile — compact fights unguessable, ordered fights unguessable, no-coordination fights compact — so there is no best ID, only a resolved conflict. The **coordination dial** is the axis on which you resolve it, and each position on it produces one of **the schemes**. Choosing "partition the space" forces you into **the bit budget**, which is pure accounting. Choosing "probability" forces you into **the math**, which is the birthday bound. **Real systems** are the record of which conflict each company decided to lose.

---

## 3. 🔥 The Problem

For twenty years the primary key was a solved problem: `id BIGINT AUTO_INCREMENT PRIMARY KEY`. It is genuinely excellent. Eight bytes, perfectly monotonic, dense with no gaps, and index-optimal — every insert appends to the rightmost leaf page of the B-tree, so the hot working set is one page regardless of how large the table grows. It works for exactly one reason: **the database is a single coordinator that remembers every ID it has ever issued.** The counter *is* the memory of the entire ID history.

Shard that database and the coordinator vanishes. Each of your fifty shards now runs its own counter starting at 1, and within an hour every shard has issued an `id = 7`. The classic patch — set `auto_increment_offset` and `auto_increment_increment` so shard *n* issues only IDs congruent to *n* — works, and Flickr shipped it, but it is brittle: the increment is baked into every shard's config, so adding the fifty-first shard means the whole scheme has to be re-cut and existing IDs no longer fit the pattern. The counter was never designed to be sharded.

The first instinctive fix is to keep the coordinator but pull it out into its own service: one box, one counter, everyone asks it. This fails for a precise reason worth being able to state. It converts a **local** operation into a **distributed** one. Every insert in the entire system now carries a network round trip before it can begin, that service's p99 is added to every write's p99, and — the part that actually kills it — **its availability becomes a hard ceiling on your write availability.** If the ID service is down, nothing in the system can create anything. Replicating it doesn't help, because the counter is shared mutable state: the replicas must either coordinate on every ID (now you have consensus latency on the write path, which is worse) or partition the counter space between them — at which point you have abandoned the central service and arrived, accidentally, at the real answer.

The second instinctive fix is to abolish coordination entirely with a random UUIDv4 — 122 random bits, and the birthday bound says you will never see a collision. This is genuinely correct on uniqueness, and it is where most candidates stop. But 8.4's argument comes due immediately: a random primary key means every insert lands in a **random leaf page** of the B-tree. The working set is no longer the right edge of the index, it is the entire index; the buffer pool thrashes; and instead of cheap right-edge appends you get page splits in the middle of the tree, which fragment it. In InnoDB it is worse still, because the table *is* the clustered primary key index, and that 16-byte key is copied into every secondary index on the table. You solved uniqueness and paid for it in write throughput.

The insight that resolves it is small and worth memorizing: **uniqueness does not require serializing access to a counter — it requires that no two minters can produce the same value.** You can get that by giving each machine its own disjoint slice of the ID space, decided once at startup rather than once per write. And if you then spend the ID's high bits on a timestamp, the keys remain roughly ordered, so you keep 8.4's index locality for free. That is Snowflake, and everything else in this subtopic is a variation on where you put that dividing line.

**Before and after:**

```
  BEFORE — one counter, everyone asks it        AFTER — partition the space
  ─────────────────────────────────────         ──────────────────────────────
   ┌────────┐ ┌────────┐ ┌────────┐              ┌───────────────────────────┐
   │ app 1  │ │ app 2  │ │ app 3  │              │ app 1   worker id = 001   │
   └───┬────┘ └───┬────┘ └───┬────┘              │  mints  [ts|001|seq]      │
       │          │          │                   └───────────────────────────┘
       └──────────┼──────────┘                   ┌───────────────────────────┐
                  ▼  round trip on EVERY insert  │ app 2   worker id = 002   │
        ┌────────────────────┐                   │  mints  [ts|002|seq]      │
        │  ID SERVICE / DB   │                   └───────────────────────────┘
        │  counter = 41 302  │                   ┌───────────────────────────┐
        └────────────────────┘                   │ app 3   worker id = 003   │
                                                 │  mints  [ts|003|seq]      │
   ✓ perfectly monotonic, 8 bytes                └───────────────────────────┘
   ✗ a network hop before every write
   ✗ ITS availability caps YOUR               ✓ zero coordination at write time
     write availability                       ✓ collision impossible BY
   ✗ its throughput caps your writes            CONSTRUCTION, not by luck
   ✗ replicas don't help — the counter        ✓ time in high bits → still
     is shared mutable state                    k-sorted → 8.4 locality kept
                                              ✗ worker IDs must be assigned
                                                ONCE, AUTHORITATIVELY, at start
```

### ✅ Checkpoint

1. Why can't you fix the central ID service's single-point-of-failure problem by putting three replicas behind a load balancer? Name the property of the counter that makes replication not a solution here, and explain what each of the two escape routes from that problem actually costs you.

   > 💡 *If you hesitate, re-read §3 paragraph three — the sentence about shared mutable state and what the replicas are forced to do.*

> **→ Next:** If the answer is to partition the ID space instead of serializing access to it, what exactly is being partitioned — and what are the other places on that same dial?

---

## 4. 💡 The Core Idea

**A unique ID scheme is a decision about where uniqueness comes from: you either coordinate on every write, coordinate once per batch, partition the ID space so that coordination is unnecessary, or replace coordination with a probability bound — and each choice buys uniqueness in a different currency: write latency, availability, index locality, or a residual collision risk.**

The five ideas below build on each other. Each one only makes sense because of the one before it.

**The build chain:**

```
 [UNIQUENESS IS ──▶ [THE COORDINATION ──▶ [THE BIT ──▶ [SORTABILITY IS ──▶ [ENCODING IS
  GLOBAL]            DIAL]                 BUDGET]      A BYPRODUCT]        SEPARATE]
   because you        therefore there       so partition-   which means         so base62 is
   must know          are exactly four      ing means       time in the high    presentation,
   something about    places to buy it,     slicing a       bits buys 8.4's     never
   every other ID     not two               fixed integer   locality for free   generation
```

### One Home for Uniqueness — why this is hard at all

Uniqueness is not a property of an ID. It is a property of the **set** of all IDs. To assert that the value you just generated is unique, you need to know something about every other value ever generated — which is why the naive implementation is a shared counter, and why the counter has to be shared. Every scheme that follows is a technique for obtaining that global guarantee without performing a global read. Hold on to that framing: when an interviewer asks how you'd generate IDs, they are asking *how you're going to avoid the global read*, and candidates who answer "UUIDs, they're unique" have answered a question nobody asked.

### The Coordination Dial — four positions, not two

Because the guarantee is global but the mint must be local, there are exactly four places to buy it, and naming all four (rather than the usual two) is what separates a designed answer from a recalled one.

**Coordinate on every write.** `AUTO_INCREMENT` on a single database, or a dedicated ID service. Perfect monotonic order, 8 bytes, dense. The price is a round trip and shared fate on every insert, as §3 laid out.

**Coordinate once per batch — the ticket server.** A writer leases a block of, say, 1000 IDs and then mints locally from that block until it runs out. The round trip is amortized 1000:1, and the coordinator is a boring MySQL box you already know how to operate. You pay in two coins: IDs are no longer globally monotonic (writer A holds 1000–1999 while writer B holds 2000–2999, and B may well commit first), and a crash abandons the unused remainder of a block, so the sequence has **gaps**. Both are usually fine; neither is free.

**Partition the space — Snowflake.** Each machine embeds its own identifier in the ID, so the space each machine can produce is disjoint from every other machine's by construction. Two machines *cannot* collide, and no runtime coordination is needed at all. The cost is honest and often glossed over: you must assign each machine a distinct worker ID, so you have not eliminated coordination — you have **moved it from write time to deploy time**, where a ZooKeeper ephemeral sequential node, an etcd lease, or a StatefulSet pod ordinal can handle it once per process lifetime instead of once per row.

**Replace coordination with probability — UUIDv4.** 122 random bits, and the birthday bound (§5) says the collision probability stays negligible past any volume a real system will produce. This is the only position on the dial where the guarantee is statistical rather than structural, and it is a perfectly respectable engineering choice — but it costs you every ordering property, which is where 8.4 comes back to collect.

### The Bit Budget — what Snowflake actually spends 64 bits on

Once you choose to partition the space, ID design becomes pure accounting: you have a fixed-width integer and you divide it into fields. Twitter's Snowflake spends 64 bits as **1 unused sign bit + 41 bits of millisecond timestamp + 10 bits of machine ID + 12 bits of sequence**, composed as `(ts << 22) | (machine_id << 12) | sequence`. The sign bit is left at zero so the value stays positive in a signed `BIGINT` or a Java `long` — which is also the reason the whole thing is 64 bits and not 128.

Each field is a capacity decision you should be able to defend. 41 bits of milliseconds is 2^41 ms ≈ **69.7 years**, measured from a *custom* epoch — Twitter used 2010-11-04, and choosing your own epoch matters because starting from the Unix epoch would burn decades of that budget before your system even launches. 10 bits of machine ID is **1024 nodes**. 12 bits of sequence is **4096 IDs per machine per millisecond**, i.e. 4.1 million per second per machine, giving a fleet ceiling of 1024 × 4096 = **4.19 million IDs per millisecond**, about 4.2 billion per second.

The interview-relevant point is that these widths are a **budget, not a constant**. If you need 4096 machines, take two bits from the sequence: 41/12/10 still gives 1024 IDs per millisecond per machine, which is 1 million per second — almost certainly more than one process needs. Saying this unprompted demonstrates you understand Snowflake as a parameterized design rather than a magic number you memorized. The one thing you may not move is the timestamp: it has to stay in the high bits, for the reason the next block gives.

### Sortability Is a Byproduct — where 8.4 gets paid back

Putting the timestamp in the most significant bits means numeric order approximates chronological order, and that single fact is where all the index benefit comes from. Consecutive inserts land in adjacent B-tree leaf pages near the right edge of the index, so the hot working set is a handful of pages rather than the whole tree, page splits are mostly the cheap right-edge kind rather than mid-tree fragmentation, and the buffer pool holds what you actually need. Two smaller wins come along for free: `ORDER BY id` is `ORDER BY created_at`, so a feed does not need a separate timestamp index; and in InnoDB, where the clustered PK is embedded in every secondary index, an 8-byte ordered key rather than a 16-byte random one shrinks every index on the table.

Be precise about the limit, because interviewers push here: Snowflake is **k-sorted**, not strictly sorted. Within a single millisecond, IDs from different machines interleave in machine-ID order, not in true issue order, so "roughly ordered to the millisecond" is the honest claim. If you need a strict total order across the fleet, you need a coordinated scheme, and you are back at position one on the dial.

### The Encoding Is Separate — base62 is not an ID scheme

The most common conceptual muddle on this subtopic is treating base62 as a way to *generate* IDs. It isn't. Base62 is an **encoding** — a way to render a number in the alphabet `[0-9a-zA-Z]` — and it generates nothing. It is chosen over base64 because base64's `+` and `/` are not URL-safe (and base64url's `-` and `_` read badly in a short link and get mangled by autolinkers), and over hex because base16 needs 2.6× more characters for the same key space.

What matters is the sizing, and it is arithmetic you should be able to do on a whiteboard: 62^6 ≈ **56.8 billion**, 62^7 ≈ **3.52 trillion**, 62^8 ≈ **218 trillion**. A URL shortener taking 100 million new links a year for ten years needs a billion keys, so six characters is comfortable and seven is generous. Then, separately, you decide where the number comes from — and there are only two options. You either **assign** it (encode a counter, a ticket-server value, or a Snowflake ID), in which case collisions are structurally impossible but the codes are enumerable; or you **draw** it (hash the URL and truncate, or generate randomly), in which case the codes are unguessable but you have entered the birthday-bound regime and owe the collision math in §5. Assigned versus drawn is the distinction that the whole short-code question turns on.

### ✅ Checkpoint

1. You are designing a Snowflake variant for a fleet that will grow to 3000 pods, with a peak fleet-wide write rate of 200,000 IDs per second and a requirement that the scheme outlive a 25-year product lifetime. Re-cut the 64-bit budget and justify each field width against a stated number — including why you are *not* using the standard 41/10/12.

   > 💡 *If you hesitate, re-read §4 — The Bit Budget, and note which field is the one you are allowed to shrink.*

2. Both "partition the space" and "replace coordination with probability" eliminate the round trip on the write path — yet only one of them also preserves the B-tree locality from 8.4. Explain why, and say what that difference tells you about which property is actually doing the work in a Snowflake ID.

   > 💡 *If you hesitate, trace the build chain above from THE BIT BUDGET to SORTABILITY IS A BYPRODUCT — the answer is about which bits are high-order, not about how many bits there are.*

> **→ Next:** You know the four positions and the bit layout. What physically happens, instruction by instruction, when a generator mints an ID — and what happens when the clock misbehaves?

---

## 5. ⚙️ How It Actually Works

**The Snowflake mint (happy path):**

1. Read the clock and compute `ts` = milliseconds since the custom epoch.
2. If `ts == last_ts`, increment the sequence counter and mask it to 12 bits. If it wraps to zero, the machine has already issued 4096 IDs this millisecond — **busy-wait until the clock advances**, then continue.
3. If `ts > last_ts`, reset the sequence to 0. (Several implementations randomize the starting value instead, so that low-traffic machines don't all emit IDs ending in `...000`.)
4. If `ts < last_ts` — the clock went backwards — **refuse to issue and throw.** This is the deliberate choice covered below.
5. Compose `(ts << 22) | (machine_id << 12) | sequence`, store `last_ts`, return.

There is no I/O, no network call, and no lock beyond a local mutex. A mint is sub-microsecond, which is the entire point: the ID is available before the write even reaches the database.

> 🗺️ **Mental model — the license plate.** A plate is `state code + issuing office + sequential number`. No two offices ever need to phone each other, because the office code makes their number spaces disjoint, and yet every plate in the country is unique. Snowflake is a license plate where "state code" is a timestamp. *Where it breaks down:* license plates have no rollover date and no clock you can accidentally wind backwards — and those are precisely Snowflake's two failure modes.

**The ticket server (the cheap, boring, correct alternative):**

1. A writer that needs IDs asks the ticket server for a block. Flickr's implementation is one line of MySQL against a single-row table: `REPLACE INTO Tickets64 (stub) VALUES ('a'); SELECT LAST_INSERT_ID();` — `REPLACE` rather than `INSERT` so the table never grows.
2. The server returns a range, say `[n, n+999]`.
3. The writer mints locally from that range with no further coordination, and asks for the next block at roughly 80% consumption so it never blocks on a refill.
4. High availability is achieved by partitioning the coordinator itself: two MySQL boxes, one configured `auto_increment_offset=1`, the other `=2`, both with `auto_increment_increment=2`. One serves odd IDs, the other even. Either can die without stopping ID generation — which is the "partition the space" trick applied one level up.

Instagram's variant is worth naming because it removes the service entirely: a Postgres stored procedure on each shard composes 41 bits of millisecond timestamp, 13 bits of **logical shard ID** (8192 shards), and 10 bits of a per-shard sequence. Because the procedure runs inside the same transaction as the insert, there is no window in which a generated ID can be lost, and no external component to keep alive.

**Mechanism flow:**

```
 ① SNOWFLAKE MINT — no I/O, no network, sub-microsecond
 ┌──────────────┐    ┌──────────────────┐    ┌─────────────────────┐   ┌─────────────┐
 │ read clock   │───▶│  ts == last_ts ? │─┬─▶│ seq = (seq+1)&0xFFF │──▶│ compose &   │
 │ ms since     │    └──────────────────┘ │  │ if it wrapped to 0: │   │ return      │
 │ CUSTOM epoch │             │ no     yes│  │   SPIN to next ms   │   │ (ts<<22)|   │
 └──────────────┘             ▼           │  └─────────────────────┘   │ (mid<<12)|  │
                    ┌──────────────────┐  │                            │  seq        │
                    │  ts >  last_ts ? │──┘                            └─────────────┘
                    │   yes → seq = 0  │
                    │   NO  → THE CLOCK WENT BACKWARDS
                    │         REFUSE TO ISSUE ──────▶ throw
                    └──────────────────┘

 ② TICKET SERVER — coordinate once per BLOCK, not once per ID
 ┌──────────┐  1 round trip   ┌────────────────────┐   ┌──────────────────────┐
 │  writer  │────────────────▶│   ticket server    │──▶│ block [n, n+999]     │
 │          │  per 1000 IDs   │ REPLACE INTO ...   │   │ mint LOCALLY from it │
 └──────────┘                 │ SELECT LAST_       │   │ refill at ~80%       │
                              │        INSERT_ID() │   └──────────────────────┘
                              └────────────────────┘
   HA  = two servers, offsets 1 and 2, increment 2 → odds and evens
   ✗ gaps on crash    ✗ no global monotonic order    ✓ compact, boring, correct
```

**The bit budget, structurally:**

```
  64-BIT SNOWFLAKE ID
  bit 63   62 ──────────────────── 22   21 ────── 12   11 ────── 0
  ┌──────┬──────────────────────────┬───────────────┬──────────────┐
  │ sign │   TIMESTAMP  (41 bits)   │  MACHINE ID   │   SEQUENCE   │
  │  0   │   ms since CUSTOM epoch  │   (10 bits)   │  (12 bits)   │
  │unused│                          │               │              │
  └──────┴──────────────────────────┴───────────────┴──────────────┘
     1               41                     10             12
             2^41 ms ≈ 69.7 years      1024 nodes     4096 per ms
                                                      per machine

  id = (ts << 22) | (machine_id << 12) | sequence

  FLEET CEILING   1024 × 4096 = 4.19 MILLION IDs per millisecond
                              ≈ 4.19 BILLION per second

  RE-CUT IT — the widths are a budget, not a constant
    need 4096 nodes?      41 / 12 / 10  → 1024 IDs/ms/machine (1M/sec)
    need 139 years?       42 / 10 / 11  → 2048 IDs/ms/machine (2M/sec)
  ──────────────────────────────────────────────────────────────────
  THE ONE FIXED RULE: the timestamp stays in the HIGH bits. Move it
  and the IDs stop being k-sorted, and the entire 8.4 locality
  argument — the reason you chose this over UUIDv4 — evaporates.
```

**The collision math (this is the mastery criterion — be able to do it cold):**

When keys are **assigned** — a counter, a ticket-server value, a Snowflake ID — collisions are structurally impossible and there is no math to do. When keys are **drawn** — hashing and truncating, or generating random codes — you are in the birthday regime, and the governing fact is that collisions bite at **√N, not N**:

```
  P(at least one collision)  ≈  1 − e^(−k²∕2N)  ≈  k²∕2N   (when k ≪ √N)
  50% point                  ≈  1.177 · √N
      k = number of keys drawn        N = size of the key space

  ┌──────────────────────┬──────────────────┬─────────────────┬─────────────────┐
  │ SCHEME               │ N (key space)    │ 50% COLLISION   │ VERDICT         │
  ├──────────────────────┼──────────────────┼─────────────────┼─────────────────┤
  │ 7-char base62,       │ 62^7 = 3.52e12   │ ~2.2 MILLION    │ breaks at real  │
  │ truncated hash       │                  │ keys            │ product scale   │
  ├──────────────────────┼──────────────────┼─────────────────┼─────────────────┤
  │ 8-char base62,       │ 62^8 = 2.18e14   │ ~17 million     │ buys one order  │
  │ truncated hash       │                  │ keys            │ of magnitude    │
  ├──────────────────────┼──────────────────┼─────────────────┼─────────────────┤
  │ UUIDv4               │ 2^122 = 5.3e36   │ ~2.7e18 keys    │ never, in any   │
  │ (122 random bits)    │                  │                 │ real system     │
  ├──────────────────────┼──────────────────┼─────────────────┼─────────────────┤
  │ base62(Snowflake) or │ n/a — ASSIGNED,  │ never           │ structurally    │
  │ base62(counter)      │ not drawn        │                 │ impossible      │
  └──────────────────────┴──────────────────┴─────────────────┴─────────────────┘

  THE TRAP:  62^7 = 3.5 TRILLION reads as unlimited headroom.
             √(3.5e12) = 1.9 million. You get the SQUARE ROOT of the space.
  AT SCALE:  1 billion keys drawn into 62^7 → k²/2N ≈ 142,000.
             The approximation blows past 1, meaning collisions are CERTAIN.
```

> 🗺️ **Mental model — the birthday paradox is the whole of collision math.** In a room of 23 people there is a ~50% chance two share a birthday, even though there are 365 days — because you are counting *pairs*, and pairs grow quadratically. *Where it breaks down:* the classroom version makes the effect sound like a curiosity. At ID-space scale the reduction is brutal — a 3.5-trillion key space gives you 2.2 million safe keys, not 3.5 trillion, and no amount of intuition prepares you for that gap.

The practical resolution, which is what you actually say in an interview: don't truncate a hash and hope. Either assign the key (base62-encode a Snowflake or a counter, and collisions cannot occur), or — if unguessability requires you to draw it — make the insert conditional and retry with a fresh value on conflict: `INSERT ... ON CONFLICT DO NOTHING` in Postgres, or a `attribute_not_exists(pk)` condition expression in DynamoDB. The retry loop is what makes drawing safe; the probability calculation tells you how often you will pay for it. Note that a check-then-insert (`SELECT` to see if the code is taken, then `INSERT`) is *not* the same thing — it has a race window between the two statements, and under concurrency it will let a duplicate through.

**Failure and edge cases:**

- **Duplicate worker IDs — the real hazard.** If two processes come up with the same machine ID, they mint identical IDs whenever their clocks and sequences align, and those IDs are perfectly well-formed. This fails *silently*: it surfaces as an occasional primary-key conflict that looks like a random bug. Assignment must come from something authoritative — a ZooKeeper ephemeral sequential node, an etcd lease with a heartbeat, or a StatefulSet pod ordinal. `hash(hostname) % 1024` is the tempting shortcut and it has its own birthday problem: with only **40 pods** in 1024 slots, the probability that at least two collide is **≈53%**.
- **Clock skew and NTP steps.** If the wall clock jumps backwards, a naive generator will re-issue IDs it has already handed out. Reference implementations refuse to issue while `now < last_ts` and throw — trading availability for uniqueness, which is the right trade for a primary key. Mitigations: run NTP in slew mode rather than step mode, read a monotonic clock source where available, persist `last_ts` across restarts, and alarm on skew. Leap seconds were the classic trigger. This is the single most common Snowflake follow-up question.
- **Sequence exhaustion.** More than 4096 IDs in one millisecond on one machine causes the generator to spin until the clock advances. Under burst this shows up as *latency*, not as an error, which makes it easy to miss. If it is chronic, take bits from the machine-ID field.
- **Epoch rollover and epoch loss.** 41 bits gives ~69.7 years from your chosen epoch — not a problem you will personally hit, but the epoch is baked into every ID ever issued, so it must be documented and version-controlled. Losing it means you can no longer interpret your own timestamps.
- **Enumerability and information leakage.** Assigned IDs leak volume: `/order/1042` followed by `/order/1109` tells a competitor you processed 67 orders (the German tank problem). Snowflake leaks *time* — anyone holding an ID can extract its creation moment to the millisecond. If IDs are exposed publicly and either fact is sensitive, mint a separate opaque public identifier rather than exposing the internal key.

### ✅ Checkpoint

1. Walk through exactly what a Snowflake generator does when it reads a clock value **lower** than the last one it issued, and explain why the reference implementation chooses to throw rather than to keep counting forward from `last_ts`. State what is being traded for what, and name the operational settings that make this path rare.

   > 💡 *If you hesitate, re-read step 4 of the mint sequence and the clock-skew bullet in the failure cases.*

2. A team deploys 40 Snowflake generator pods and assigns worker IDs with `hash(hostname) % 1024`. Compute the approximate probability that at least two pods share a worker ID, describe precisely what goes wrong when they do, and explain why this failure is unusually hard to detect in production.

   > 💡 *If you hesitate, re-read the birthday-bound formula in the collision-math block, then the duplicate-worker-ID bullet — the detection difficulty is about what a duplicate ID looks like, not about how often it happens.*

> **→ Next:** You know how each scheme works and how each one fails. So in a live design, which do you actually reach for — and what exactly are you giving up?

---

## 6. ⚖️ The Decision — When, and What It Costs

The default is `BIGINT AUTO_INCREMENT`, and you should say so out loud. If the data lives in one logical database, the built-in counter is free, eight bytes, perfectly monotonic, dense, and index-optimal, and no distributed scheme beats it on any axis. Reaching for Snowflake in a design that has a single Postgres behind it is over-engineering, and an interviewer who sees you do it will read it as pattern-matching rather than judgment. You leave the default at one of three specific boundaries, and each boundary points at a different scheme.

**You shard, or you take writes on more than one master.** The counters now collide, so uniqueness has to come from somewhere else. Snowflake if you want 64 bits, k-sorted keys, and per-machine attribution; a ticket server if you would rather keep one boring coordinator and amortize it; UUIDv7 if you don't need either.

**You need the ID before the write reaches a server.** A mobile client drafting offline, a client-supplied idempotency key (3.5), a multi-service write where downstream calls must reference the row before it exists. Only client-mintable schemes work here, which rules out Snowflake and ticket servers entirely — the phone has no worker ID and no coordinator. UUIDv7 is the modern answer: RFC 9562's 48-bit millisecond timestamp in the high bits plus 74 random bits gives you UUIDv4's zero-coordination property *and* index locality, which is why it is displacing v4 as the default for new sharded systems.

**The ID is user-visible.** Now two new constraints appear that never mattered internally: it should be short and typeable, and — often — it should not be enumerable. This is the URL-shortener case, and it splits into sizing (base62 arithmetic) and generation (assigned versus drawn), which are separate decisions that candidates routinely fuse.

Four signals decide it in practice: **coordination tolerance on the write path**, **who mints** (server or client), **whether the ID is exposed**, and — the one most often skipped — **the shape of the store**. That last one is worth stating carefully, because the "sequential keys are better" rule is a *B-tree* rule and it **inverts** elsewhere. In an LSM-tree store (Cassandra, RocksDB), writes land in a memtable and are sorted on flush, so a random key does not cause the buffer-pool thrash that dominates the MySQL argument. And in a hash-partitioned store (DynamoDB, Cassandra), a *monotonic* partition key is actively harmful — consecutive writes all hash near each other in time and concentrate on one partition, which is 7.6's hot-partition problem created deliberately by your ID scheme. Being able to say "sequential is better in InnoDB and worse as a DynamoDB partition key, for opposite reasons" is a strong depth signal.

**Decision tree:**

```
                    Sharded / multi-writer / multi-master?
                                  │
                   ┌──────no──────┴───────yes──────┐
                   ▼                               ▼
        BIGINT AUTO_INCREMENT.        Must the CLIENT mint the ID
        Free, 8 bytes, dense,         before the write reaches a server?
        index-optimal. Done.                       │
        Do NOT over-engineer.            ┌───yes───┴────no────┐
                                         ▼                    ▼
                              Is the store hash-      Is the ID user-visible
                              partitioned by this     / must it be short?
                              key?                            │
                                    │                  ┌──yes─┴──no──┐
                             ┌─no───┴──yes─┐           ▼             ▼
                             ▼             ▼    base62-encode a  Do you need
                         UUIDv7        UUIDv4   Snowflake or a   per-machine
                        (sortable,    (random   counter. THEN    attribution or
                       client-mint)   spreads   decide assigned  a controlled
                                      load)     vs. drawn, and   bit budget?
                                                treat enumer-          │
                                                ability.         ┌─yes─┴──no──┐
                                                                 ▼            ▼
                                                            SNOWFLAKE     UUIDv7, or a
                                                            worker ID from  TICKET SERVER
                                                            ZK / etcd /     if you want a
                                                            StatefulSet     compact 64-bit
                                                            ordinal —       int and can
                                                            never           accept one
                                                            hash(hostname)  coordinator
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **AUTO_INCREMENT: 8 bytes, dense, perfectly monotonic** — the ideal B-tree key; every insert is a right-edge append and the hot set is one page | Requires a single coordinator, so it does not survive sharding or multi-master; the patch (`auto_increment_offset`/`increment`) bakes the shard count into every node's config and breaks when you add one |
| **Ticket server: amortizes coordination 1000:1** — one round trip per block, a coordinator you already know how to operate, still a compact 64-bit integer | IDs are no longer globally monotonic across writers, and every crash abandons the unused remainder of a block, so the sequence permanently has gaps; you still run and page for a coordinator |
| **Snowflake: zero runtime coordination and k-sorted 8-byte keys** — collision is impossible by construction, not by probability, and 8.4's index locality is preserved | You have moved coordination to deploy time, not removed it: worker IDs must be assigned authoritatively or the scheme fails *silently*. The generator also depends on wall-clock monotonicity and will refuse to issue during a backwards clock step |
| **UUIDv4: no coordination of any kind, client-mintable** — the only scheme that works on a device with no network and no assigned identity | 16 bytes and zero ordering, so as a clustered InnoDB primary key it scatters inserts across the whole index and is copied into every secondary index; and it leaks nothing, which also means it tells you nothing |
| **UUIDv7: v4's independence plus Snowflake's locality** — 48-bit ms timestamp in the high bits, 74 random bits, standardised in RFC 9562 | Still 16 bytes, and the timestamp in the high bits means every ID publicly discloses its creation time to the millisecond — the price of sortability is always disclosure |
| **base62 over an assigned number: short, typeable, collision-free** — 6–8 characters covers any realistic link volume with no retry loop | The codes are sequential and therefore enumerable, leaking both your content and your volume; making them unguessable means drawing instead of assigning, which puts you back in the birthday regime with a retry loop |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Twitter / X — Snowflake** | The origin of the 41/10/12 layout, 64-bit, from a custom epoch of 2010-11-04 | The original Scala service was open-sourced and later archived; the lasting contribution is the *format*, not the service. Because the timestamp sits in the high bits, anyone can extract a tweet's creation time directly from its ID — sortability and disclosure are the same property |
| **Instagram — per-shard IDs in Postgres** | A stored procedure on each shard composes 41 bits ms + 13 bits logical shard + 10 bits sequence | No external ID service at all: the ID is minted *inside the same transaction* as the insert, so there is no window in which a generated ID can be lost. 13 bits = 8192 **logical** shards, deliberately over-provisioned so logical shards can be relocated between physical machines without re-minting any IDs |
| **Flickr — ticket servers** | Two MySQL boxes, a single-row table, `REPLACE INTO` + `LAST_INSERT_ID()` | The HA story is the interesting part: `auto_increment_increment=2` with offsets 1 and 2 makes one server serve odd IDs and the other even. That is "partition the space" applied to the coordinator itself. They explicitly accepted gaps and non-monotonicity as the price |
| **MongoDB — ObjectId** | 12 bytes: 4-byte seconds timestamp + 5-byte per-process random value + 3-byte counter, generated client-side by the driver | Second-granularity timestamp, so it is only k-sorted to the second, not the millisecond. 12 bytes rather than 16 is a deliberate compactness choice while staying client-generatable — a middle position between Snowflake and UUID |
| **UUIDv7 — RFC 9562 (2024)** | 48-bit big-endian Unix millisecond timestamp, then 74 random bits, within the standard 128-bit UUID envelope | Standardisation is what makes it usable: Postgres, MySQL, and the major language runtimes ship generators, so it needs no bespoke library and no worker-ID infrastructure. It is now the default recommendation for new sharded systems that don't need per-machine attribution |
| **bit.ly / TinyURL-class shorteners** | base62 codes of 6–8 characters over a generated key | The real design question is assigned vs. drawn. Assigned (encode a counter or Snowflake) is collision-free but walkable; drawn (random, or truncated hash) is unguessable but needs a conditional insert with retry. Most production shorteners assign, then obscure the ordering, rather than drawing and hoping |

### ✅ Checkpoint

1. A team is designing the write path for a chat system storing messages in Cassandra with a primary key of `(conversation_id, message_id)` — `conversation_id` is the partition key and `message_id` the clustering key. An engineer proposes Snowflake IDs for `message_id` "because sequential keys are better for the index." Evaluate the proposal: is the stated reasoning correct, is the conclusion correct, and what would you actually do?

   > 💡 *If you hesitate, re-read the fourth signal in §6 — the shape of the store — and be careful about which part of the primary key the monotonic value is landing in.*

> **→ Next:** You can defend the choice. How does an interviewer actually put pressure on it?

---

## 7. 🎯 In the Interview

**When an interviewer asks / says:**

- "What's the primary key for this table, and where does it come from?"
- "How do you generate the short code — and how long does it need to be?"
- "You're sharded across fifty databases. How do you make sure two shards never issue the same ID?"
- "Can the client generate the ID, or does it have to come from the server?"
- "Someone could just guess other people's URLs, right?"

**What you say / do:**

This lands in the **data model / API design** phase, at the exact moment you write an `id` column onto a schema on the whiteboard — that column is a magnet, and the interviewer will point at it. It comes back in the **deep dive** twice: once when you shard the write path, and once when the ID is exposed in a URL. In URL shortener, paste bin, and any design where an identifier appears in a path, it is not a possible question but a guaranteed one.

Deliver it in a fixed order every time: **name the scheme → give the mechanism reason → price it unprompted → name the switch condition.** The mechanism reason must be about the index or the coordination path, never "it's unique" — uniqueness is table stakes and saying it signals you have not thought past the requirement.

**The trade-off statement (memorize this — sharded write path):**

> "I'd mint IDs with Snowflake — 41 bits of millisecond timestamp from a 2026 epoch, 10 bits of worker ID, 12 bits of sequence, in a 64-bit `BIGINT`. I'm choosing it over UUIDv4 because these rows land in an InnoDB clustered index, and a random 16-byte primary key means every insert hits a random leaf page: the working set becomes the entire index instead of the right edge, and InnoDB copies that 16-byte key into every secondary index on the table. Snowflake gives me 8 bytes and roughly-ordered inserts, plus `ORDER BY id` for free. What I'm giving up is real. I now depend on wall-clock monotonicity, so an NTP step backwards makes the generator refuse to issue rather than risk duplicates — that's an availability hit I'm accepting to protect the primary key. And I need worker IDs from something authoritative: a ZooKeeper ephemeral node or the StatefulSet ordinal, never `hash(hostname) % 1024`, which with only forty pods collides about 53% of the time and fails silently. I'd change my answer if the client had to mint the ID before the write reached the server — then it has to be UUIDv7, because a phone has no worker ID to assign."

**The second variant (memorize this too — the short-code redirection, which is how this question usually arrives):**

> "I'd size base62 first and generate second, because they're separate decisions. At 100 million new links a year for ten years that's a billion keys; 62^6 is 56.8 billion, so six characters is comfortable and seven gives real headroom. Then generation: I would specifically *not* hash the URL and truncate to seven characters. The birthday bound bites at the square root of the key space, not the key space — 62^7 is 3.52 trillion, but the 50% collision point is around 2.2 million links, so that scheme breaks well inside a normal product's first year. I'd base62-encode a Snowflake ID instead, which makes collisions structurally impossible rather than merely unlikely. The cost is that the codes become roughly sequential and therefore walkable — someone can enumerate my link space and infer my volume — so if non-enumerability is an actual requirement I'd generate random codes with a conditional insert and retry on conflict, and pay the retry rate the birthday math predicts. I'd switch to that the moment enumerability is a stated requirement rather than a nice-to-have."

### ⚠️ Traps

- ❌ **Trap:** "I'd use UUIDs for the primary key — they're globally unique."
  ✅ **Reality:** Uniqueness was never the hard part; the hard part is uniqueness *without coordination* **and** *without destroying index locality*, and UUIDv4 solves only the first half. A random 16-byte clustered key scatters every insert across the B-tree, thrashes the buffer pool, fragments the index with mid-tree page splits, and — in InnoDB specifically — is copied into every secondary index on the table. The fix is not to abandon client-side generation, it's UUIDv7: same independence, timestamp in the high bits, locality restored.

- ❌ **Trap:** "62^7 is three and a half trillion, so seven characters handles trillions of links."
  ✅ **Reality:** Only if you *assign* them. If you *draw* them — hash and truncate, or generate randomly — the birthday bound applies and the 50% collision point is at 1.177·√N ≈ **2.2 million**, not 3.5 trillion. That is a difference of six orders of magnitude and it is the single most reliable place to be caught out on this subtopic. Assigned versus drawn is the distinction; say which one you're doing before you quote a capacity number.

- ❌ **Trap:** "Snowflake needs a central ID service."
  ✅ **Reality:** Snowflake is a *library*, not a service — the whole point is that the mint is local, in-process, and involves no I/O. Twitter did originally run it as a Thrift service, but for organizational reasons rather than algorithmic ones; the algorithm requires no runtime coordination whatsoever. The only coordination is assigning a worker ID once at process startup. Calling it a service inverts the entire argument for choosing it.

- ❌ **Trap:** "Clock skew is the main risk with Snowflake."
  ✅ **Reality:** Worker-ID assignment is. Clock skew fails **loudly** — the generator detects `now < last_ts` and refuses to issue, so you get an outage and a page, which is bad but visible. Duplicate worker IDs fail **silently**: two processes emit perfectly well-formed IDs that collide only when their millisecond and sequence happen to align, surfacing as an intermittent primary-key conflict that looks like a random bug for months. Naming the silent failure over the loud one is the depth signal here.

- ❌ **Trap:** "Sequential IDs are better for the index, so use them everywhere."
  ✅ **Reality:** That is a **B-tree** rule and it inverts under hash partitioning. In an LSM store, writes buffer in a memtable and sort on flush, so the random-key penalty largely disappears. And as a *partition key* in DynamoDB or Cassandra, a monotonic ID is actively harmful: consecutive writes concentrate on one partition and you have manufactured 7.6's hot-partition problem in your ID scheme. Sequential is better in InnoDB and worse as a DynamoDB partition key, for opposite reasons.

### ✅ Checkpoint — adversarial stress test

1. You shipped Snowflake IDs six months ago. On-call reports a handful of duplicate primary keys per day, all in one table, all perfectly well-formed 64-bit values. The interviewer says: *"Using only the duplicate IDs themselves, tell me how you'd distinguish a clock-rewind cause from a duplicate-worker-ID cause. Then tell me what you do about the rows already written, and what you'd have built at deploy time so this class of bug couldn't happen silently."*

   > 💡 *This is the gate. A complete answer decomposes the offending IDs back into their three fields and reasons from the distribution — a worker-ID collision clusters duplicates on one worker value across many timestamps, while a rewind clusters them on one worker at timestamps the generator has already passed. It then covers remediation for existing rows (you cannot re-mint a key other rows reference), and the deploy-time fix: an authoritative worker-ID lease with a heartbeat, persisted `last_ts` across restarts, and a startup assertion. If you can't answer this cleanly, you are not done.*

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 8. 🧪 Mastery Gate

> *Synthesis only. Each question requires combining two or more sections.*

1. **(§3 + §5 + 8.4)** A team migrates a two-billion-row MySQL table from `AUTO_INCREMENT` to UUIDv4 primary keys in preparation for sharding. Write throughput drops roughly 60% on identical hardware, before a single shard has been added. Explain the mechanism using 8.4's B-tree material, explain what specifically about InnoDB's *clustered* index makes this worse than it would be in a heap-organized table, and name the single change that recovers most of the loss without reintroducing a coordinator.

2. **(§4 + §6, applied to a system not mentioned in this doc)** Design the ID scheme for a multi-tenant document editor where clients create documents **offline** and sync later, documents are stored in DynamoDB partitioned by `tenant_id`, and document URLs are shared publicly. Decide the internal primary key and the public URL slug **separately**, justify each against the four decision signals, and make sure at least one of your two choices is a scheme you explicitly rejected for the other — and say why the same scheme was right in one place and wrong in the other.

3. **(§5 + §6 + §7)** A URL shortener generates codes as `base62(md5(url)[:42 bits])` and deduplicates by checking whether the code already exists before inserting it. Compute the volume at which this design becomes unsafe, identify the race condition in the check-then-insert, and give the two-line fix. Then say what the design gains that a counter-based scheme does not — because it does gain something, and the complete answer names it.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can compare auto-increment, UUIDv4, UUIDv7, ticket server, and Snowflake and justify a choice against a stated write rate and key-locality requirement
- [ ] Can size a base62 short code for a given total-key count, showing the arithmetic
- [ ] Can compute the collision probability of a truncated-hash scheme from the birthday bound, and state the 50% point as 1.177·√N
- [ ] Can explain why a random primary key degrades B-tree insert performance, and name two schemes that avoid it
- [ ] Can lay out the Snowflake bit budget from memory and re-cut it for a stated fleet size and lifetime
- [ ] Can name the four positions on the coordination dial and what each one costs
- [ ] Can explain why the "sequential keys are better" rule inverts for a hash-partitioned store

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 9. 🔗 Connections & Sources

**Builds on:** **8.4 Indexing — B-tree, LSM-tree, composite indexes** — this is the direct parent. 8.4 established that insert cost depends on where in the key space an insert lands; 8.9 is the consequence, since the ID scheme is what *decides* where it lands. Also **8.1 SQL vs. NoSQL**, because the store's physical organisation (clustered B-tree vs. LSM vs. hash-partitioned) is the signal that determines whether ID ordering helps or hurts. And **7.2 Hash partitioning**, since the ID is very often the partition key, and a monotonic partition key is a hot partition by construction.

**Enables:** **8.6 ACID transactions** — Instagram's per-shard generator is a stored procedure that runs *inside* the insert's transaction, so the ID and the row commit atomically and no generated ID can be orphaned. **7.6 Hot partitions**, which is what a monotonic ID does to a hash-partitioned store. **3.5 Idempotency**, where a client-minted UUID exists precisely so a retried request can be recognised as the same request. And **28.6 coordination avoidance**, which revisits the framing — Snowflake partitions the space so you never coordinate, a ticket server coordinates once per batch, UUID eliminates coordination via probability — as a callback rather than new material.

**Tension with:** **8.4 itself**, in the store-shape inversion: the sequential-is-better rule that 8.4 establishes for B-trees reverses when the same key becomes a hash partition key. And with **security and privacy generally**: the properties that make an ID a good key — compact, dense, ordered — are exactly the properties that make it a bad public identifier, because dense and ordered means enumerable and time-in-the-high-bits means every ID discloses its creation moment.

### 📚 Further reading

- [ ] **Instagram Engineering — "Sharding & IDs at Instagram"** — https://instagram-engineering.com/sharding-ids-at-instagram-1cf5a71e5a5c — the best single source; the per-shard Postgres stored procedure and the reasoning for 41/13/10
- [ ] **Flickr Code — "Ticket Servers: Distributed Unique Primary Keys on the Cheap"** — https://code.flickr.net/2010/02/08/ticket-servers-distributed-unique-primary-keys-on-the-cheap/ — the `REPLACE INTO` trick and the odd/even HA split, in about 800 words
- [ ] **Twitter Snowflake (archived)** — https://github.com/twitter-archive/snowflake — read the README for the bit layout and the clock-rewind behaviour; ignore the Scala
- [ ] **RFC 9562 — Universally Unique IDentifiers (UUIDs)** — https://www.rfc-editor.org/rfc/rfc9562.html — §5.4 (v4) and §5.7 (v7); the v7 rationale section is the clearest published statement of the locality argument
- [ ] **Percona — "Store UUID in an optimized way"** — https://www.percona.com/blog/store-uuid-optimized-way/ — measured InnoDB numbers for random vs. ordered primary keys; this is where the "60% drop" style figures come from
- [ ] **Designing Data-Intensive Applications, Ch. 3 (B-trees / LSM-trees) and Ch. 9 (ordering guarantees)** — Kleppmann — Ch. 9's treatment of Lamport timestamps and total order is the theory underneath "k-sorted, not sorted"

---

## 10. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
