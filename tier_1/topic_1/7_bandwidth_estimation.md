# 🧠 Subtopic 7 - Bandwidth Estimation

## **🎯 0. Goal of This Subtopic**

By the end, you should be able to:


### 1. Instantly convert traffic → bandwidth

* QPS x payload → MB/s → GB/day

### 2. Detect bottlenecks in seconds

* “This system is network-bound, not CPU-bound”

### 3. Estimate infrastructure requirements

* NIC limits
* CDN needs
* cross-region cost

### 4. Speak like a Staff engineer

Instead of:

>“This might be high traffic“


You say:

>“We’re pushing ~800 MB/s ingress, so we’ll saturate a 10 Gbps link - we need horizontal scaling or compression”


* * *

## **🧾** 1. Cheat Sheet

```
// 1. Core Formula
Bandwidth (bytes/sec) = QPS x Request Size

// 2. Key Conversions
1 KB  ≈ 10^3 bytes
1 MB  ≈ 10^6 bytes
1 GB  ≈ 10^9 bytes

// 3. Bandwidth -> Storage
1 MB/s  ≈ 100 GB/day
10 MB/s ≈ 1 TB/day
100 MB/s ≈ 10 TB/day
1 GB/s ≈ 100 TB/day

// 4. QPS -> Bandwidth
1K QPS × 1 KB  = 1 MB/s
10K QPS × 1 KB = 10 MB/s
100K QPS × 1 KB = 100 MB/s
1M QPS × 1 KB = 1 GB/s

// 5. Payload Size Heuristics
Tiny request (ID, metadata)        → 0.5–1 KB
API request/response               → 1–10 KB
JSON object                        → 1–50 KB
Image                             → 100 KB – 5 MB
Video stream                      → 1–10 MB/s per user

// 6. Read vs Write Bandwidth
Total Bandwidth =
    Write QPS × Write Size
  + Read QPS × Read Size

Example:
Writes: 10K QPS × 1 KB = 10 MB/s
Reads:  100K QPS × 5 KB = 500 MB/s
Total:  510 MB/s

// 7. Fan-out Multiplier

If 1 write triggers N reads:

Effective Read QPS = Write QPS × N

Example:
1K writes × 100 followers
→ 100K read deliveries

→ 100K × payload size → bandwidth

// 8. Peak vs Average
Peak QPS ≈ 2–5× average

ALWAYS compute:
- avg bandwidth
- peak bandwidth (used for capacity planning)

// 9. Network Limits
1 Gbps ≈ 125 MB/s
10 Gbps ≈ 1.25 GB/s
100 Gbps ≈ 12.5 GB/s

Rule of thumb:
- Single server tops out ~1–10 Gbps
- Beyond that → horizontal scaling

// 10. Cross region cost awareness

Bandwidth is $$$

Example:
1 GB/s → 100 TB/day
→ massive cost if cross-region

Always ask:
"Is this intra-DC or inter-region?"

// 11. Compression Effect
Compression ratio:
2x–10x reduction

Example:
10 MB/s → 2 MB/s after compression

// 12. CDN Offload (Read Heavy)
Without CDN:
All traffic hits origin

With CDN:
90–99% traffic offloaded

Example:
1 GB/s → only 10 MB/s hits backend

// 13. Sanity check tricks
If:
QPS × KB → MB/s

Then:
MB/s × 100 → GB/day

Example:
50 MB/s → 5 TB/day

// 14. Interview Checklist
Always mention:

[ ] Avg QPS
[ ] Peak QPS
[ ] Request size
[ ] Read vs write split
[ ] Fan-out
[ ] Compression
[ ] CDN / caching
[ ] Network limits
```

* * *

## 🧠 2. Mental Model

Bandwidth is:

```
Bandwidth = Throughput of data per second
```

Think:

```
QPS x Size per request = Bandwidth
```

This is the core equation of this subtopic.
* * *

## 3. Common Mistakes

### ❌ Forgetting unit alignment

* KB x QPS → MB/s

### ❌ Mixing MB vs Mb (bits vs bytes)

* Always assume bytes unless told otherwise

### ❌ Not converting to per second first

* Always normalize to MB/s first

### ❌ Losing powers of 10

* Stick to: 1 day =0.143 wk 10^5 seconds

