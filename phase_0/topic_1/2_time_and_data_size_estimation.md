# 🧠 Subtopic 2 - Time & Data Size Memorization

## **🎯 0. Goal of This Subtopic**

Build instant recall for:

* time units
* data sizes
* orders of magnitude

So that you can:

* avoid recomputing basics
* focus on system reasoning instead of arithmetic
* speak fluently during interviews

* * *

## 1. Core Idea

You are not memorizing everything.
You are memorizing a small set of anchors, and deriving everything else mentally.
* * *

## 2. The Only Things You Must Memorize

### 2.1. Time Conversions (CRITICAL)

```
1 second = 1 s

1 minute = 60 s
1 hour   = 3,600 s (~3.6K)
1 day    = 86,400 s (~1e5)
1 month  ≈ 30 days ≈ 2.6M s
1 year   ≈ 365 days ≈ 3.15e7 s (~3e7)
```

Key Anchors

* 1 day = 10^5 seconds
* 1 year = 3 * 10^7 seconds

Everything else derives from these.
* * *

### 2.2. Data Size Conversions

Use decimal (interview standard), not binary.

```
1 KB = 10^3 bytes
1 MB = 10^6 bytes
1 GB = 10^9 bytes
1 TB = 10^12 bytes
1 PB = 10^15 bytes
```

Key Anchors

* 1 MB = 1,000,000 Bytes
* 1 GB = 1,000,000,000 Bytes

* * *

### 2.3. Bits vs Bytes

```
1 Byte = 8 bits
```

Quick Conversions

* 1 MB/s = 8Mb/s
* 100Mb/s = 12.5MB/s

* * *

### 2.4. Human Friendly Data Sizes

Memorize these - they show up everywhere:


|ITEM	|SIZE	|
|---	|---	|
|
Character	|1 byte	|
|
Word	|~5–10 bytes	|
|
Tweet	|~200 bytes	|
|
Small JSON	|~1 KB	|
|
Image (compressed)	|~100 KB	|
|
HD Image	|~1 MB	|
|
Video (1 min)	|~10–100 MB	|
|	|	|

* * *

### 2.5. Request size heuristics

```
API request = 1 KB
API response = 1-10KB
```

* * *

## 3. Derivation Patterns (What you actually use)

### 3.1 Pattern 1 - PerDay → Per Second

```
X / day -> divide by 100K
```

Example:

```
10M requests/day -> 10M / 100K = 100 QPS
```



### 3.2 Pattern 2 - Per Second → Per Day

```
X QPS -> x 100K
```

Example:

```
500 QPS -> 50M / day
```

### 

### 3.3 Pattern 3 - Storage from Throughput

```
MB/s -> TB/day

1 MB/s = 86 GB/day = 0.086 TB/day
```

Key Anchor

```
1 MB/s = 0.1 TB/day
```

So:

```
10 MB/s = 1 TB/day
```



### 3.4 Pattern 4 - Data Volume Estimation

```
requests x size = total data
```

Example:

```
1M requests x 1 KB = 1 GB
```

* * *

## 4. Mental Compression Tricks

### 4.1 Trick 1 - Always Round

Bad:

```
86,400 seconds
```

Good:

```
~100K seconds
```



### 4.2 Trick 2 - Use Scientific Notation

```
1M = 10^6
1B = 10^9
```

### 4.3 Trick 3 - Keep Numbers in Head Friendly Form

Instead of:

```
2,600,000 seconds
```

Think:

```
~3M seconds
```

* * *

## 5. Interview Mini Checklist

When given a system:

```
1. Estimate users (DAU)
2. Convert → QPS
3. Estimate peak QPS
4. Estimate request/response size
5. Compute bandwidth
6. Compute storage/day
7. Compute total storage
8. Estimate server count
```

