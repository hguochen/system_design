# 🧠 Subtopic 6 - Storage Estimation

## **🎯 0. Goal of This Subtopic**

The goal is to make you able to:


### Instantly estimate:

* Total storage(TB / PB / EB)
* Storage growth over time
* Per-user/per-object storage cost
* Storage per day / per year
* Storage with replication

### In Interviews, you should be able to:

Within 30-60 seconds:

* estimate storage for any system (Twitter, YouTube, Chat, etc)
* Justify assumptions clearly
* Apply replication + retention
* Sanity check results

### What mastery looks like

You can:

* Convert QPS → storage/day → storage/year
* Estimate storage from object size x count
* Handle:
    * replication
    * retention
    * compression
* Detect when numbers are off by 10x

* * *

## **🧾** 1. Cheat Sheet

```
// Flow -> Storage
Storage/day = QPS x size x 10^5

// Yearly Storage
Storage/year = Storage/day x 365

// With Replication
Total storage = raw x replication_factor

// With Retention
Total storage = daily x retention_days

// Common object sizes
1 Tweet = 1 KB
1 Chat Message = 100 B - 1000 B
1 Image = 100 KB - 1 MB
1 Video = 1 MB/sec

// Quick conversions
1K QPS x 1 KB = 1 MB/s → ~100 GB/day
10K QPS x 1 KB = 10 MB/s → ~1 TB/day
100K QPS × 1 KB → 100 MB/s → ~10 TB/day
1M objects/day × 10 MB ≈ 10 TB/day
1 GB/s = 100 TB/day
100 GB/day × 365 ≈ 36.5 TB/year
1 TB/day × 365 ≈ 365 TB/year

// Order-of-Magnitude anchors
1 TB/day → ~365 TB/year
1 PB → 1000 TB
1 EB → 1000 PB
```

100 GB/day × 365 ≈ 36.5 TB/year
* * *

## 🧠 2. Core Mental Model

### 2.1. Two Ways to Estimate Storage

Method A - Flow based (most common)

```
QPS x size x time = total storage
```

Example:

```
10K writes/sec × 1 KB × 86400 sec/day
≈ 864 GB/day ≈ 1 TB/day
```

Method B - Entity-based

```
#objects x size per object
```

Example:

```
1B users x 1 MB profile
= 1 PB
```


When to use which?

* Use flow-based for logs/events
* Use entity-based for users/media

* * *

### 2.2 Time Scaling

|&lt;b&gt;Time&lt;/b&gt;	|&lt;b&gt;Multiplier&lt;/b&gt;	|
|---	|---	|
|
1 day	|~10^5 sec	|
|---	|---	|
|
1 year	|~3 × 10^7 sec	|

### 2.3 Storage Scaling

|&lt;b&gt;Unit&lt;/b&gt;	|&lt;b&gt;Value&lt;/b&gt;	|
|---	|---	|
|
1 KB	|10^3 B	|
|---	|---	|
|
1 MB	|10^6 B	|
|
1 GB	|10^9 B	|
|
1 TB	|10^12 B	|
|
1 PB	|10^15 B	|

### 2.4 Replication Multiplier

|&lt;b&gt;Setup&lt;/b&gt;	|&lt;b&gt;Multiplier&lt;/b&gt;	|
|---	|---	|
|
No replication	|
×1	|
|---	|---	|
|
3 replicas (common)	|
×3	|
|
Multi-region	|
×3–5	|

### 2.5 Retention Multiplier

|&lt;b&gt;Retention&lt;/b&gt;	|&lt;b&gt;Effect&lt;/b&gt;	|
|---	|---	|
|
7 days logs	|×7	|
|---	|---	|
|
1 year data	|×365	|
|
Infinite	|grows forever	|

### 2.6 Compression Factor

|&lt;b&gt;Data Type&lt;/b&gt;	|&lt;b&gt;Compression&lt;/b&gt;	|
|---	|---	|
|
logs	|3–10×	|
|---	|---	|
|
images	|low	|
|
videos	|already compressed	|

## 3. Interview Flow (Script)

When asked:

```
Estimate storage for X
```

Say:


1. Assumptions
    1. QPS or users
    2. object size
2. Daily storage

```
QPS x size x 10^5
```

1. Apply retention

```
x retention_days
```

1. Apply replication

```
x3
```

1. Final answer + sanity check

