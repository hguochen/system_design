# Worked Example: Design Twitter Feed

---

## 0. Outline Approach
- Define Scale: 300M DAU, global, read-heavy
- Derive math: traffic, bandwidth, storage, cache, servers
- Design system: feed generation, storage, delivery

---

## 1. Scope

**In scope:**
- Post a tweet (text, image, video)
- Follow/unfollow users
- View home feed (chronological or ranked)
- Like, retweet

**Out of scope:**
- DMs
- Search
- Trending topics
- Notifications

**NFRs:**
- Latency: feed load < 200ms p99
- Availability: 99.99%
- Consistency: eventual (feed staleness acceptable)

**System type:** Read-heavy, fan-out at scale

---

## 2. Scale
- DAU: 300M
- MAU: 500M
- Concurrent users: ~10% DAU = 30M
- Global: US-heavy but worldwide

---

## 3. Behavior

| Action | Per User/Day | Total/Day |
|---|---|---|
| Post tweet | 0.1 | 30M |
| Read feed | 10 | 3B |
| Like/RT | 2 | 600M |

- Read:Write ratio ≈ 100:1
- Peak multiplier: 3x

---

## 4. Traffic Pattern
- Steady baseline with spikes (breaking news, live events)
- Bursty writes during major events
- Read spikes correlate with write spikes (people refresh feed)

---

## 5. Data

**Tweet object:**
| Field | Size |
|---|---|
| tweet_id | 8B |
| user_id | 8B |
| text | 280B |
| timestamp | 8B |
| media_url | 50B |
| like_count | 8B |
| **Total** | ~362B ≈ 400B |

**Dominant field:** text (280B), media stored separately in object storage

---

## 6. Retention
- Hot tweets: 30 days → SSD / in-memory cache
- Warm tweets: 1 year → HDD
- Cold tweets: indefinite → object storage (S3)
- Storage: **unbounded** (tweets are never deleted by default)

---

## 7. Infrastructure Assumptions
- Encoding overhead: 2x
- Indexing overhead: 2x
- Cache hit ratio: 99% (feed is hot data)
- Replication factor: 3x

---

## 8. Derive Traffic

```
Total requests/day = 3B (reads) + 30M (writes) + 600M (likes/RT)
                   ≈ 3.63B requests/day

QPS = 3.63B / 10^5 ≈ 36,300 QPS

Read QPS  = 30,000
Write QPS = 300
Likes QPS = 6,000

Peak (3x):
  Read QPS  = 90,000
  Write QPS = 900
```

---

## 9. Derive Bandwidth

```
Read  = 30,000 QPS x 400B = 12 MB/s   → peak: 36 MB/s
Write = 300 QPS x 400B    = 0.12 MB/s → peak: 0.36 MB/s

Media (images avg 200KB, ~20% of tweets):
  Write media = 300 x 0.2 x 200KB = 12 MB/s → peak: 36 MB/s

Total peak bandwidth ≈ ~72 MB/s inbound, ~36 MB/s outbound (text feed)
```

---

## 10. Derive Storage

```
Daily writes = 30M tweets x 400B = 12 GB/day (text)
Retention    = 5 years = 1,825 days

Raw = 12 GB x 1,825 = 21.9 TB

Apply:
  Encoding  x2 = 43.8 TB
  Indexing  x2 = 87.6 TB
  Replication x3 = 262.8 TB ≈ 263 TB

Media (images):
  30M x 0.2 x 200KB = 1.2 TB/day x 1,825 x 3 (replication) ≈ 6.6 PB
```

---

## 11. Derive Cache

**Working set:** Top 20% of tweets drive 80% of reads (Pareto)
```
Hot tweets in 24h = 30M x 400B = 12 GB
Working set (20%) = 2.4 GB
Cache (with overhead) ≈ 10 GB per region
```

**Placement:**
- CDN: static media (images, videos)
- App layer (Redis): precomputed feed per user, tweet objects
- DB layer: query result cache (rarely needed given Redis hit rate)

**Eviction:** LRU (feed access is recency-biased)

**Invalidation:** TTL-based (5 min for feed), event-driven on new tweets from followed users

---

## 12. Derive Servers

```
Read QPS peak = 90,000
Assume each server handles 1,000 QPS (network-bound, JSON serialization)

Feed servers = 90,000 / 1,000 = 90 servers

Write QPS peak = 900
Write servers  = 900 / 1,000 = 1 server (round up to 3 for HA)
```

---

## 13. Sanity Check

| Metric | Value | Sanity |
|---|---|---|
| Read QPS | 90K peak | ✅ (Twitter ~400K, we're a subset) |
| Storage (text) | ~263 TB | ✅ order of magnitude reasonable |
| Cache size | ~10 GB/region | ✅ fits in memory easily |
| Servers | ~90 | ✅ reasonable for a cluster |

---

## 14. High Level Design

**Request flow (read feed):**
```
Client → CDN (media) → Load Balancer → Feed Service → Redis Cache
                                                      ↓ (cache miss)
                                               Feed DB (precomputed)
                                                      ↓ (cold user)
                                              Fan-out Service → Tweet DB
```

**Major components:**
- **Feed Service** — serves precomputed feed from cache
- **Tweet Service** — handles tweet creation
- **Fan-out Service** — pushes new tweets to followers' feed cache
- **User Graph Service** — stores follow relationships
- **Media Service** — upload/serve images/video via CDN
- **Feed DB** — stores precomputed feed lists (Redis + persistent store)
- **Tweet DB** — stores tweet objects (Cassandra)

---

## 15. Component Deep Dive

### Hardest component: Fan-out Service

**Problem:** A user with 10M followers posts a tweet. Do we write to 10M feed caches?

**Two strategies:**

| | Fan-out on Write (Push) | Fan-out on Read (Pull) |
|---|---|---|
| Feed latency | Low (pre-built) | High (compute at read) |
| Write amplification | High (celebrities) | None |
| Best for | Regular users | Celebrities |

**Hybrid approach:**
- Push to followers if follower count < 10K
- Pull from celebrity tweets at read time, merge with pre-built feed

---

### API Design

```
GET  /v1/feed?user_id=&cursor=&limit=20       → paginated feed
POST /v1/tweets                                → create tweet
POST /v1/tweets/{id}/like                      → like tweet
POST /v1/users/{id}/follow                     → follow user
```

---

### SQL vs NoSQL Decision

| Store | Choice | Reason |
|---|---|---|
| Tweet objects | Cassandra (NoSQL) | High write throughput, wide rows by user_id+timestamp |
| User graph (follows) | Redis / Graph DB | Fast adjacency lookups |
| Feed lists | Redis (sorted set) | O(log n) insert, range queries by score (timestamp) |
| Media | S3 + CDN | Blob storage, not relational |

---

## 16. Tradeoffs

**Consistency vs Availability:**
- Chose eventual consistency for feed — users tolerate slight staleness
- Strong consistency for tweet writes (you must see your own tweet immediately) → read-your-writes guarantee via sticky session or write-to-cache

**Latency vs Cost:**
- Pre-computing feeds (fan-out on write) reduces read latency but increases storage and write cost
- Hybrid model balances both — push for normal users, pull for celebrities

**Fan-out depth:**
- Deeper fan-out = lower read latency, higher write cost and lag for popular users

---

## 17. Summary

| Decision | Choice |
|---|---|
| Feed generation | Hybrid push/pull (threshold: 10K followers) |
| Tweet store | Cassandra |
| Feed cache | Redis sorted sets |
| Media delivery | S3 + CDN |
| Consistency model | Eventual (feed), read-your-writes (own tweets) |
| Servers | ~90 feed servers, 3 write servers |
| Storage | ~263 TB text, ~6.6 PB media over 5 years |
