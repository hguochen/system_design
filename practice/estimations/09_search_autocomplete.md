# Practice 9 — Search Autocomplete (e.g. Google Search)

## Given Assumptions
- 5B searches/day globally
- Each search triggers ~6 autocomplete requests (one per character typed, avg query = 6 chars)
- Each autocomplete request returns top 10 suggestions
- Average suggestion string: 30 characters = 30B
- Autocomplete response payload: 10 suggestions × 30B = 300B per response
- Autocomplete query string (inbound): avg 6B per request
- Trie/index data: top 10M most-searched queries cached in memory; avg query = 20B
- No persistent storage for autocomplete requests (stateless); only the index is stored
- Index refreshed daily from search logs
- Replication: 3× for index

## Your Task

Estimate all of the following. Show your working step by step. State any additional assumptions you make.

1. Total autocomplete requests/day
2. Autocomplete RPS
3. Inbound bandwidth (autocomplete queries)
4. Outbound bandwidth (autocomplete responses)
5. In-memory index size for top 10M queries
6. Number of servers needed (assume 1 server handles 50K RPS and has 256 GB RAM)
7. Why is this system almost entirely read-heavy, and what does that imply architecturally?

---

## Answer Key

### 1. Total Autocomplete Requests/Day
- 5B searches × 6 autocomplete requests = **30B autocomplete requests/day**

### 2. Autocomplete RPS
- 30B / 10^5 = **300,000 RPS**

### 3. Inbound Bandwidth
- 300K/s × 6B = 1,800,000 B/s = **~1.8 MB/s** (negligible)

### 4. Outbound Bandwidth
- 300K/s × 300B = 90,000,000 B/s = **~90 MB/s**

### 5. In-Memory Index Size (top 10M queries)
- 10M queries × 20B = 200,000,000 B = **~200 MB**

> The entire top-query index fits in memory on a single server — this is why autocomplete can be blazing fast.

### 6. Server Count
- RPS per server: 50K
- Raw servers needed: 300K / 50K = 6 servers
- With 2× buffer: **~12 servers**
- RAM per server: index is 200 MB → fits easily in 256 GB RAM
- In practice, you'd shard by query prefix across servers

### 7. Read-Heavy Nature
- Autocomplete is 100% reads — no user writes to the index directly
- Index is updated offline (batch rebuild from search logs once/day)
- Implication: optimise entirely for low-latency reads (in-memory trie/prefix tree), use aggressive caching, no need for write consistency guarantees
- A cache hit rate of >99% is achievable since top queries are highly concentrated (Zipf distribution)
