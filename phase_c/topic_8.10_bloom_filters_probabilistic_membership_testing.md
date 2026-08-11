# 8.10 Bloom Filters — Probabilistic Membership Testing

> **Topic:** Topic 8 — Database Fundamentals
> **Phase:** C — Data Storage Branch
> **Depth Tier:** 🥈 T2 (Depth) — budget ~1h
> **Prereqs:** 8.4 (Indexing — B-tree, LSM-tree), 8.7 (Read vs. Write Optimization)
> **Date studied:** _____

> 🥈 **T2 means:** this is a follow-up probe, not a core design decision. You need
> to explain it confidently and name its trade-off — you do not need to design
> a system around it from scratch.

---

## 0. 🧭 The Question This Answers

8.4 introduced the LSM-tree, and 8.7 named the bill it leaves on the read side: a point read may have to check the memtable plus every un-compacted SSTable before it can answer, because a key could in principle be in any of them. That bill is only "bounded, not eliminated" by one specific mechanism — this subtopic is that mechanism.

The tension is that checking whether a key is absent from a file should be cheap, but the only fully correct way to know is to actually look — and looking means a disk seek per file, for files that, most of the time, don't contain the key at all. Storing every key in memory to answer exactly would be correct but defeats the entire point of using disk-backed storage in the first place.

**The question:** *How do you cheaply and quickly rule out "this key isn't here" for most files, without paying for an actual lookup or storing the full key set — and what do you give up to get that speed?*

> **→ Next:** Before naming the mechanism, what specifically goes wrong with the two obvious fixes — check every file, or keep every key in memory?

---

## 1. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds.*
>
> ⏭️ **First time through?** Skip to §2 and come back here for revision.

```
§ 1  WHY IT EXISTS
An LSM-tree point read (8.4, 8.7) may need to check several SSTables before
answering, and each check that turns up nothing is a wasted disk seek. Storing
every key in memory to answer exactly would avoid the waste but costs O(n)
memory proportional to the full key set — the exact cost disk-backed storage
was chosen to avoid. The gap is a structure that's cheap like memory but
correct enough, most of the time, to skip real lookups entirely.

§ 2  WHAT IT IS
BLOOM FILTER       A fixed-size bit array plus k independent hash functions
                   that answers "possibly present" or "definitely absent" for
                   a key, using far less space than storing the key itself.
FALSE POSITIVE     The filter says "possibly present" for a key that was
                   never inserted. Expected and tunable — never eliminated.
FALSE NEGATIVE     The filter says "definitely absent" for a key that WAS
                   inserted. Architecturally impossible by construction —
                   this is the one guarantee that never breaks.
k HASH FUNCTIONS   Independent functions mapping a key to k positions in the
                   m-bit array. Same k functions used for insert and query.

§ 3  THE MECHANISM
INSERT             Compute k hash positions for the key, set each bit to 1.
                   Idempotent — setting an already-1 bit changes nothing.
QUERY              Compute the same k positions. Any bit still 0 → key was
                   definitely never inserted (that slot was never touched).
                   All k bits 1 → "maybe" — those bits could be 1 from other
                   keys' overlapping hashes, not necessarily this one.
FALLBACK ON MAYBE  A "maybe" always triggers the real, expensive check
                   (disk read, DB lookup) — the filter only ever saves work
                   on definite-absent answers, never replaces the real check.

§ 4  USE / AVOID
USE when: the real lookup is expensive (disk seek, network hop, DB query),
  false positives are tolerable IF a fallback check follows, and false
  negatives are unacceptable — you can never afford to say "not here" when
  it is.
AVOID when: you need EXACT membership with no fallback path, you need to
  enumerate members (Bloom filters can't list what they hold), or you need
  to delete entries from a filter already in use — a plain Bloom filter
  can't safely unset a bit shared by other keys.
AVOID assuming a Bloom filter replaces the real lookup — it only ever
  reduces how often you pay for it.

§ 5  NUMBERS TO ANCHOR THE DISCUSSION
~10 bits per key is the standard sizing to hit roughly a 1% false-positive
  rate — dramatically less than 8+ bytes per key for a real key or hash set
  entry.
False positive rate p ≈ (1 − e^(−kn/m))^k, where m = bits, n = elements,
  k = hash functions. The optimal k ≈ (m/n)·ln2 for a given m and n.
FPR is NOT fixed once sized — inserting more elements than the filter was
  built for (n grows past design capacity) drives the fill ratio up and the
  false-positive rate climbs, silently, with no error thrown.
Cassandra defaults bloom_filter_fp_chance to ~0.01 (1%) per SSTable — a
  direct, tunable production instance of this trade-off.

§ 6  INTERVIEW TRIGGERS + GOTCHA
→ "How do you avoid hitting the DB for keys      → Bloom filter in front of
   that almost never exist?"                        the expensive check
→ "This LSM-tree does a lot of point reads       → Bloom filter per SSTable,
   against cold SSTables — how speed it up?"        skip files on a "no"
→ "How would you stop your cache from being      → Bloom filter as an
   polluted by one-hit-wonder traffic?"             admission filter
→ "What's a space-efficient way to check          → Bloom filter, then
   set membership?"                                 immediately name the FPR
GOTCHA: Saying "it tells you if something is in the set." It never does —
  it tells you "definitely not" or "maybe," and "maybe" is not "yes." Skipping
  the fallback-check requirement is the single most common depth failure.
```

---

## 2. 🧠 The Mindmap

> *The picture to hold in your head while you study.*

```
                    ┌──────────────────────────────────────┐
                    │      BLOOM FILTERS                    │
                    │  "cheap NO, honest MAYBE, never a     │
                    │   false NO"                           │
                    └───────────────────┬────────────────────┘
                                        │
        ┌───────────────┬───────────────┼───────────────┬───────────────┐
        ▼               ▼               ▼               ▼               ▼
  THE GUARANTEE     THE MECHANISM    THE COST         WHERE USED      VARIANTS
  ├ no false        ├ m-bit array    ├ space vs.      ├ LSM-tree      ├ counting
  │  negatives,       + k hashes       FPR tuning        SSTables       Bloom filter
  │  ever                                                (8.4, 8.7)     — adds
  ├ false           ├ insert: set    ├ no deletion    ├ cache/CDN       deletion
  │  positives         k bits          (plain form)     admission
  │  expected,                                          filters       ├ cuckoo
  │  tunable         ├ query: check  ├ no member      ├ crawler URL     filter —
                       k bits          enumeration       dedup           alt. with
  └ asymmetric       └ same k funcs  └ silent FPR     └ existence       native
    by design           both ways      drift if          checks         deletion
                                        overfilled        (9.x, 30.x)
```

**How to read it:** the top branches describe the shape of the promise — **the guarantee** is the one-way asymmetry that makes the structure trustworthy at all, **the mechanism** is how that asymmetry is physically produced, **the cost** is what you pay for the compression, **where used** is the recurring interview-relevant deployment, and **variants** exist specifically to relax the one limitation (no deletion) that the base structure accepts.

---

## 3. 🔥 The Problem

An LSM-tree's read path (8.4, 8.7) can legitimately need to check the memtable plus several on-disk SSTables before it knows whether a key exists, because any of them could hold it. The obvious fix — check every candidate file — is correct but expensive: each check that finds nothing is still a disk seek that was paid for and returned no value, and the number of un-compacted files only grows under sustained write load.

The equally obvious reverse fix is to keep an exact record of every key in memory — a hash set — so membership can be answered without touching disk at all. This is correct and fast, but it costs memory proportional to the full key set, at roughly the same per-key overhead as the keys themselves. For a dataset large enough to justify disk-backed storage in the first place, holding every key in memory defeats the reason that storage engine was chosen — you'd need enough RAM to hold what you're explicitly trying to keep on disk.

The insight that resolves this is to stop demanding an exact answer. Most queries against most files are going to be negative — the key genuinely isn't in that particular SSTable — so what's actually needed is a structure that can say "definitely not here" cheaply and correctly nearly all the time, is allowed to occasionally be wrong in the safe direction (a wasted check on a key that turns out not to be there), and is never allowed to be wrong in the unsafe direction (claiming absence for a key that's actually present, which would silently return a wrong answer). Trading a small, controlled rate of wasted work for a large reduction in memory is the entire design.

### ✅ Checkpoint

1. Why can't you just keep every key in an in-memory hash set to avoid disk reads entirely, if a hash set would also give you a correct, fast answer?

   > 💡 *If you hesitate, re-read the second paragraph — the reverse mistake and why it defeats the purpose of disk-backed storage.*

MODEL ANSWER — §3 Checkpoint

THE MECHANISM (why exactness has a cost)
  A hash set of every key costs memory roughly proportional to
  n × key size — the same order of magnitude as storing the keys
  themselves. That's correct and fast, but it isn't free; it's
  just moved the storage problem into RAM.

WHY IT DEFEATS THE POINT
  The entire reason a large dataset lives in an LSM-tree on disk
  is that it doesn't fit affordably in memory. If avoiding a disk
  read requires holding every key in memory anyway, you haven't
  solved the problem — you've quietly reintroduced the exact
  memory requirement the disk-backed design was chosen to avoid.

THE ROOT CAUSE
  The naive fixes fail for opposite reasons: checking every file
  is correct but slow (real I/O for empty results); keeping every
  key in memory is correct but not actually cheaper. A Bloom
  filter targets the gap between them — approximate, but with a
  bounded, tunable, small memory footprint.

ONE-LINE VERSION
  Exactness costs memory proportional to the data; a Bloom filter
  buys near-exactness at a small, fixed fraction of that cost.

> **→ Next:** If the fix is to accept a controlled kind of wrongness, what exactly is the structure that produces "definitely not / maybe," and how does it connect insert and query?

---

## 4. 💡 The Core Idea

**A Bloom filter is a compact, probabilistic data structure that answers "is this key possibly in the set" using a fixed-size bit array and several independent hash functions, guaranteeing zero false negatives while allowing a tunable, non-zero rate of false positives.**

**Visual required:** build-chain diagram.

```
 [BIT ARRAY + HASHES] ──▶ [INSERT SETS BITS] ──▶ [QUERY CHECKS BITS] ──▶ [THE ASYMMETRIC GUARANTEE]
   because you need a       therefore each key       so checking those        so "maybe" always needs
   fixed, shared space       stamps a small,          same positions            a fallback, but "no"
   for every key             known pattern            reveals whether           is trustworthy on
                             into that space           any part is missing      its own
```

### The Bit Array and Hash Functions

The structure starts as an `m`-bit array, every bit initialized to 0, paired with `k` independent hash functions that each map any key to a position between 0 and `m − 1`. Neither the array nor the hash functions know anything about the actual keys yet — they're just fixed machinery, sized in advance based on how many keys you expect to insert and how much false-positive rate you're willing to tolerate.

### Insert Sets Bits

Inserting a key means running it through all `k` hash functions to get `k` positions, then setting the bit at each of those positions to 1. This is idempotent — if a bit is already 1 because some other key's hash landed on the same position, setting it again changes nothing and loses no information about the fact that it's set. Nothing about which key set a given bit is recorded; the array only remembers that the position was touched by *something*.

### Query Checks Bits

Checking whether a key is present, referencing the same insert machinery, means hashing the query key with the same `k` functions and checking those same `k` positions. If even one of them is still 0, the key was definitely never inserted — no insert could have left that bit at 0 if this exact key had gone through the same hash functions. If all `k` positions are 1, the honest answer is "maybe" — those bits could have been set by this key, by some other key whose hashes happened to overlap, or by some combination of several other keys.

### The Asymmetric Guarantee

This is where the two prior blocks combine into the property that makes the whole thing usable: a bit can only ever be set, never unset by a query, so a bit being 0 is unimpeachable proof of absence — a false negative would require a bit to somehow be 0 despite having been set, which the mechanism makes impossible. A bit being 1 proves nothing about any single key, because multiple keys' hashes accumulate onto the same shared space — which is exactly why false positives are possible and expected, not a flaw to be engineered away.

### ✅ Checkpoint

1. Two keys that were never inserted happen to hash to exactly the k bit positions that other, real keys already set. What does a query for either of these non-inserted keys return, and why is that consistent with the Bloom filter's guarantee rather than a violation of it?

   > 💡 *If you hesitate, re-read "The Asymmetric Guarantee" — what a 1 bit does and doesn't prove.*

MODEL ANSWER — §4 Checkpoint

WHAT THE QUERY RETURNS
  "Maybe present" — a false positive. All k positions for each
  non-inserted key happen to already be 1, because other real
  keys' hashes set them first.

WHY THIS IS CONSISTENT, NOT A BUG
  The guarantee the structure makes is narrower than "tells you
  what's in the set" — it's specifically "never says absent for
  something present." Nothing in that guarantee promises that a
  "maybe" answer corresponds to a real member. A shared bit array
  with k hash functions per key will, by construction, eventually
  produce coincidental all-1 patterns for keys that were never
  inserted — that's the price paid for using less space than
  storing every key.

THE ASYMMETRY, NAMED
  Absence (any 0 bit) is provable. Presence (all bits 1) is only
  suggestive. That's not a symmetric coin flip — it's an
  intentionally one-sided guarantee, which is exactly why every
  "maybe" must be followed by a real check and no system may treat
  "maybe" as "yes."

ONE-LINE VERSION
  Overlap is expected, not a defect — it's the entire mechanism
  by which the filter stays small.

> **→ Next:** You know how insert and query use the same k positions. What does this look like end to end, and where specifically does it fail or degrade?

---

## 5. ⚙️ How It Actually Works

**Happy path — sizing, inserting, and querying:**

1. Decide the target false-positive rate and expected element count `n`, and size the bit array `m` and hash count `k` accordingly (roughly 10 bits per key for a ~1% target FPR).
2. Initialize the `m`-bit array to all zeros.
3. For each key inserted (e.g., each key written into an SSTable during a flush or compaction), compute its `k` hash positions and set those bits to 1.
4. On a lookup, compute the same `k` positions for the query key.
5. If any position is 0, return "definitely absent" and skip the expensive real check entirely (e.g., skip reading this SSTable from disk).
6. If all positions are 1, return "maybe present" and fall through to the real check — the filter never substitutes for it, only decides whether to skip it.

> 🗺️ **Mental model — a shared ink-stamp guest list.** Each real guest, on arrival, gets k random spots on a shared card stamped with ink. To check if someone got in, you stamp the same k spots on a fresh card and hold it up to the shared one: if any spot you stamped is blank on the shared card, that person never came through — no guest's arrival could have left it blank. If every spot matches, it might be them, or it might just be that enough other guests' stamps happened to cover the same spots. *Where it breaks down:* real ink doesn't have a precisely computable "how full is the card" number the way a Bloom filter's bit-fill ratio directly determines its false-positive rate via a closed-form formula — the analogy captures the shared-space collision but not the tunable math behind it.

**Failure & edge cases:**

- **No safe deletion.** Unsetting a bit to "remove" a key risks unsetting it for every other key whose hash also touched that position, silently reintroducing false negatives — the one guarantee that must never break. Deletion requires a counting variant (a small counter per position instead of a single bit) or rebuilding the filter from scratch.
- **Silent FPR drift under overfill.** Inserting more elements than the filter was sized for isn't rejected or flagged — the array simply fills up faster than planned, more bits reach 1, and the false-positive rate climbs above its design target with no error or warning, only a gradually less useful filter.
- **No enumeration.** The structure can answer "is X a member" for a candidate X you already have, but it cannot produce a list of what it contains — there's no way to walk the bit array backward into a set of keys.
- **Not resizable in place.** Growing `m` after the fact means rebuilding the filter from the full key set, not adjusting the existing array — in an LSM-tree, this happens naturally as a side effect of compaction rewriting SSTables, not as a special-cased maintenance step.

**Insert / query flow:**

```
INSERT key ──▶ hash_1(key)…hash_k(key) ──▶ set bit at each position (idempotent)

QUERY key  ──▶ hash_1(key)…hash_k(key) ──▶ check bit at each position
                                                    │
                              ┌─────────────────────┴─────────────────────┐
                              ▼                                           ▼
                     any bit == 0                                 all bits == 1
                              │                                           │
                              ▼                                           ▼
                  DEFINITELY ABSENT                               MAYBE PRESENT
                  skip the real lookup                            fall through to the
                  (e.g. skip this SSTable)                        real, expensive check
```

### ✅ Checkpoint

1. A Bloom filter sized for 100,000 keys is instead used to hold 2,000,000 keys, because a teammate reused it to "save engineering time." What happens to lookup behavior, mechanically — and would the filter visibly report that anything is wrong?

   > 💡 *If you hesitate, re-read "Silent FPR drift under overfill."*

MODEL ANSWER — §5 Checkpoint

WHAT HAPPENS MECHANICALLY
  20x more keys than the filter was sized for means roughly 20x
  more (key, hash-position) insert operations landing on the same
  m-bit array. The fraction of bits set to 1 climbs well past what
  the design FPR (e.g. ~1%) assumed, because that FPR formula
  assumes a specific n was respected.

EFFECT ON QUERIES
  As the fill ratio approaches saturation, an increasing — and
  eventually overwhelming — fraction of queries for genuinely
  absent keys return "maybe present" instead of "definitely
  absent," because nearly every bit position is 1 regardless of
  which specific key is being checked. At the extreme, the filter
  returns "maybe" for almost everything, and its entire benefit —
  skipping most real lookups — disappears.

DOES IT VISIBLY REPORT THE PROBLEM
  No. There's no error, exception, or rejected insert. The filter
  keeps accepting inserts and keeps answering queries; it just
  becomes steadily less useful. This is exactly why it's a "silent"
  failure mode — it has to be caught by monitoring the fill ratio
  or observed FPR, not by any signal the structure raises itself.

THE THROUGH-LINE
  A Bloom filter's correctness guarantee (no false negatives) never
  breaks under overfill — but its usefulness (a low false-positive
  rate) degrades silently and is entirely the operator's
  responsibility to monitor and correct via resizing.

> **→ Next:** Given what a Bloom filter buys and costs, when do you actually reach for one in a design, and what do real systems do with it?

---

## 6. ⚖️ The Decision — When, and What It Costs

The default question is **do you need an exact answer, or can a "maybe" be verified cheaply enough that a false positive just costs one extra real check?** If exactness is mandatory and there's no fallback path to verify a "maybe" — for instance, the Bloom filter itself would be the only source of truth — it's the wrong structure entirely; use a real index or exact set. If a fallback exists and the real lookup is materially more expensive than a bit-array check (a disk seek, a network round trip, a full database query), a Bloom filter earns its place by turning most of those expensive checks into cheap in-memory ones. The remaining decision is whether entries need to be deleted from the filter over its lifetime: a plain Bloom filter can't safely unset a bit, so any workload that needs eviction — a crawler retiring stale URLs, a cache admission filter for content that ages out — needs a counting Bloom filter or a cuckoo filter instead, both of which trade a bit more space or complexity for safe deletion.

**Decision tree:**

```
              Do you need an exact, guaranteed-correct membership answer?
                                      │
                    ┌────────yes─────┴─────no, "maybe + fallback" is fine──┐
                    ▼                                                       ▼
          USE AN EXACT STRUCTURE                          Is the real lookup meaningfully
          (hash set / real index) —                       more expensive than a bit-array
          a Bloom filter alone can't                      check (disk, network, DB)?
          be your source of truth.                                  │
                                                     ┌────no──────────┴───────yes──┐
                                                     ▼                              ▼
                                          PROBABLY NOT WORTH IT —          Do entries need to be
                                          the filter adds complexity        deleted from the filter
                                          for a saving that's already       over its lifetime?
                                          small.                                     │
                                                                     ┌──────yes───────┴───no──┐
                                                                     ▼                          ▼
                                                        COUNTING BLOOM FILTER          PLAIN BLOOM FILTER.
                                                        or CUCKOO FILTER —             Size for expected n,
                                                        pay extra space for            monitor fill ratio,
                                                        safe deletion.                 rebuild on growth.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Extremely space-efficient** — ~10 bits per key for a ~1% false-positive rate, vs. 8+ bytes per key for a real key or hash-set entry | **Never exact** — false positives are guaranteed to occur at a non-zero, tunable rate; every "maybe" needs a real fallback check |
| **O(k) constant-time insert and query**, independent of how many elements are already stored | **No deletion** in the plain form — unsetting a bit can silently reintroduce false negatives, the one guarantee that must never break |
| **Fixed size regardless of key length or content** — a 64-byte URL and a 4-byte integer cost the same per-key overhead | **FPR degrades under overfill**, silently, with no built-in signal — must be sized upfront and monitored or rebuilt as n grows |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Cassandra / RocksDB / LevelDB** | One Bloom filter per SSTable; a "definitely absent" result skips reading that file from disk entirely on a point read | `bloom_filter_fp_chance` (Cassandra, default ~0.01) is directly tunable; a lower FPR costs more bits per key, trading memory for fewer wasted disk reads |
| **CDN / cache admission filters** (e.g., Akamai-style "one-hit wonder" avoidance) | A Bloom filter tracks "has this URL been requested before"; content is only cached on a repeat request, avoiding cache pollution from one-off traffic | The filter's false positives mean a small fraction of genuinely first-time requests get cached prematurely — an accepted cost, not a bug, given how much pollution it prevents |
| **Web crawlers (URL frontier dedup)** | A Bloom filter tracks "have I already queued/crawled this URL" to avoid expensive re-crawls or duplicate queue entries at billions-of-URLs scale | Standard (non-counting) filters are the norm here because the URL set is effectively append-only; retiring URLs at scale would require a counting variant |
| **Bigtable / HBase** | A Bloom filter per SSTable-equivalent (HFile) avoids disk seeks for reads against rows or column families that don't exist in that file | Same LSM-tree read-amplification mitigation as Cassandra/RocksDB — this is the general pattern, not a one-off optimization |
| **Chrome Safe Browsing (historical design)** | A locally-stored, compact filter let the browser cheaply rule out "definitely not a known-malicious URL" before making a network call to verify a "maybe" | Illustrates the fallback requirement at product scale: a "maybe" never blocked a page on its own, it only triggered a real check against the authoritative list |

### ✅ Checkpoint

1. You're designing a web crawler's URL dedup system, deciding between a plain Bloom filter and a Cuckoo filter for tracking "have I already crawled this URL." What's the deciding factor, and what pushes you toward each option?

   > 💡 *If you hesitate, re-read the deletion branch of the decision tree.*

MODEL ANSWER — §6 Checkpoint

THE DECIDING FACTOR
  Whether URLs are ever retired or re-eligible for crawling —
  i.e., whether the filter needs safe deletion over its lifetime,
  not just inserts.

PUSHED TOWARD A PLAIN BLOOM FILTER
  If the dedup set is effectively append-only — once crawled,
  always considered crawled, with no recrawl-then-forget cycle —
  a plain Bloom filter is simpler and more space-efficient per key
  than any deletion-capable variant, and there's no need to pay
  for a feature that's never used.

PUSHED TOWARD A CUCKOO FILTER (OR COUNTING BLOOM FILTER)
  If the crawler periodically retires old entries so those URLs
  become eligible for recrawl again (freshness policy, TTL-based
  eviction), the filter must support safe deletion. A plain Bloom
  filter can't unset a bit without risking a false negative for
  some other URL that shares that bit — so this workload requires
  a cuckoo filter (comparable space efficiency, native deletion)
  or a counting Bloom filter (small counters instead of single
  bits, more space overhead but simpler to reason about).

THE THROUGH-LINE
  This isn't a performance decision, it's a correctness one — the
  "no false negatives, ever" guarantee only survives deletion if
  the structure is explicitly designed to support it.

> **→ Next:** Can you deliver this cleanly under interview pressure, including when the interviewer pushes on the exact cost you're claiming?

---

## 7. 🎯 In the Interview

**When an interviewer asks / says:**
- "How would you avoid hitting the database for keys that almost never exist?"
- "This LSM-tree does a lot of point reads against cold SSTables — how would you speed that up?"
- "How would you stop your cache from being polluted by one-off traffic?"
- "What's a space-efficient way to check set membership without storing every key?"

**What you say / do:**
This surfaces right after committing to an LSM-tree engine (8.4) and naming read amplification as its cost (8.7), the moment the interviewer asks how to make point reads faster without giving up the write throughput you just justified. Name the structure, state the guarantee precisely (no false negatives, tunable false positives), price the space and the fallback-check requirement unprompted, and name the condition that would change your answer.

**The trade-off statement:**
> "Since this store's SSTables accumulate over time and a point read may need to check several before compaction has merged them down, I'd put a Bloom filter in front of each one — a compact bit array with a handful of hash functions per key, sized for roughly 10 bits per key to hit about a 1% false-positive rate. On a lookup, if the filter says a key is definitely absent, I skip that file's disk read entirely; if it says maybe-present, I still pay for the real read, because the filter can produce false positives but is guaranteed never to produce a false negative. The cost is that roughly 1% of lookups against files that don't actually contain the key still do an unnecessary disk read, and the filter can't have entries safely removed or be resized in place — it gets rebuilt naturally whenever compaction rewrites the SSTable. I'd change my answer if I needed exact membership with no fallback check available, or the ability to enumerate what's stored — a Bloom filter can't do either of those, and I'd reach for a real index instead."

### ⚠️ Traps

- ❌ **Trap:** "A Bloom filter tells you if something is in the set."
  ✅ **Reality:** It never confirms presence — only "definitely absent" or "maybe present." Any "maybe" requires a real check before you can call it a "yes." Treating "maybe" as "yes" reintroduces exactly the wrong-answer risk the filter was supposed to prevent.

- ❌ **Trap:** "We can use the Bloom filter to see what's stored, instead of querying the full index."
  ✅ **Reality:** Bloom filters answer membership for a candidate key you already have — they cannot enumerate their contents. There's no operation that walks the bit array back into a list of members.

- ❌ **Trap:** "We'll just clear the bits for stale entries to keep the filter accurate."
  ✅ **Reality:** A shared bit can be set by many keys' overlapping hashes. Unsetting it to "delete" one key can silently produce a false negative for a different key that also depends on that bit — the one guarantee the structure must never break. Deletion needs a counting variant or a full rebuild.

- ❌ **Trap:** "We're seeing false positives, so there must be a bug in the filter."
  ✅ **Reality:** False positives are expected and guaranteed by design at a non-zero rate. The actual bug to look for, if the rate is higher than intended, is an undersized filter or one that's been overfilled past its planned element count — not the mechanism itself.

### ✅ Checkpoint — adversarial stress test

1. You've told the interviewer you'd size a Bloom filter for 1,000,000 keys at a 1% false-positive rate. They push: *"Six months later this SSTable has grown to 5,000,000 keys and the filter was never resized. Walk me through what happens to lookup performance, why, and how you'd detect and fix it."*

   > 💡 *This is the gate. A complete answer covers: the fill ratio climbing 5x past design capacity and the false-positive rate rising superlinearly (not just proportionally) as bits saturate toward all-1, the resulting erosion of the filter's benefit as more "maybe" answers force real disk reads, that the structure raises no error or signal on its own so this must be caught by monitoring observed FPR or bit-fill ratio, and the fix — rebuild the filter sized for the current key count, which in an LSM-tree happens naturally as SSTables are rewritten during compaction rather than as a special maintenance step. If you can't answer this cleanly, you are not done.*

MODEL ANSWER — §7 Adversarial Stress Test

WHAT HAPPENS TO LOOKUP PERFORMANCE
  With 5x the keys the filter was sized for, far more (key,
  position) pairs are competing for the same m bits than the
  sizing formula assumed. The fraction of 1 bits rises well past
  design levels, and because false-positive rate is driven by how
  saturated the array is, the FPR doesn't just scale linearly with
  the overfill — it climbs sharply as the array approaches
  saturation, potentially far above the original ~1% target.

WHY, MECHANICALLY
  Every additional key's k hash positions are increasingly likely
  to land on bits that are already 1, purely from crowding. Once
  most bits are 1, nearly every query — including for keys that
  were never inserted — checks out as "all bits set," so the
  filter starts answering "maybe" almost unconditionally, which
  means almost every lookup falls through to the real, expensive
  disk read the filter existed to avoid.

DETECTION — nothing is thrown, so you have to watch for it
  There's no exception or rejected insert; the filter keeps working
  and keeps degrading silently. Detecting this requires monitoring
  the observed false-positive rate (or the simpler proxy, bit-fill
  ratio) in production against the design target, not just trusting
  the initial sizing forever.

THE FIX
  Rebuild the filter sized for the current (or projected) key
  count — a plain Bloom filter can't be resized in place. In an
  LSM-tree specifically, this isn't an awkward special-cased
  maintenance task: every SSTable rewrite during compaction is
  already an opportunity to build a freshly-sized filter for the
  new file, so the fix falls out of the storage engine's normal
  lifecycle rather than requiring a bespoke rebuild job.

THE THROUGH-LINE
  The no-false-negatives guarantee never broke here — that part of
  the contract is unconditional. What broke is the filter's
  usefulness, and usefulness was never guaranteed independent of
  respecting the sizing assumptions it was built on.

---

## 8. 🔗 Connections & Sources

**Builds on:** **8.4 Indexing — B-tree, LSM-tree, composite indexes**, which introduced the SSTable structure a Bloom filter sits in front of, and **8.7 Read vs. Write Optimization**, which named read amplification as the specific, unavoidable cost of write-optimized LSM engines and identified Bloom filters as the mechanism that bounds — never eliminates — that cost.

**Enables:** **9.x Object storage** (existence checks before an expensive metadata or blob lookup) and **30.x Search index term lookups**, both referenced in the roadmap as places this exact mechanism resurfaces without being re-derived from scratch.

**Tension with:** **8.6 ACID Transactions**, which established exactness and correctness as defaults for a system of record — a Bloom filter deliberately trades exactness for space efficiency, which is only safe because it is never the source of truth, only an optimization layer sitting in front of one.

### 📚 Further reading

- [ ] **Designing Data-Intensive Applications, Chapter 3 — Storage and Retrieval** — Kleppmann — introduces Bloom filters directly in the LSM-tree section as the standard SSTable point-read optimization
- [ ] **Burton H. Bloom — "Space/Time Trade-offs in Hash Coding with Allowable Errors" (1970)** — the original paper; primary source for the guarantee and the false-positive-rate math
- [ ] **RocksDB Wiki — "RocksDB Bloom Filter"** — https://github.com/facebook/rocksdb/wiki/RocksDB-Bloom-Filter — production tuning knobs: bits-per-key, block-based vs. full filters
- [ ] **Apache Cassandra docs — "Bloom filters"** — https://cassandra.apache.org/doc/latest/cassandra/operating/bloom_filters.html — `bloom_filter_fp_chance` as a live, tunable production trade-off

---

## 9. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
