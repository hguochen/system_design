# 1. Unit Conversions

* * *

## 🧠 What “Unit Conversion Mastery” Means

You should be able to:

* convert in your head
* do it in <2 seconds
* avoid unit mistakes

* * *

## 0. Cheat Sheet

```
TIME
1 day ≈ 10^5 sec
1 year ≈ 3 x 10^7 sec

DATA
1 KB = 10^3 B
1 MB = 10^6 B
1 GB = 10^9 B
1 TB = 10^12 B

TRAFFIC
1M/day ≈ 10 QPS
10M/day ≈ 100 QPS
100M/day ≈ 1k QPS
1B/day ≈ 10k QPS

BANDWIDTH
Bandwidth = QPS × payload
1 MB/s ≈ 100 GB/day
10 MB/s ≈ 1 TB/day

STORAGE
1M × 1KB = 1 GB
1B × 1KB = 1 TB

TRAP
1 byte = 8 bits
```

* * *

## 1. The only 3 unit categories you need

Forget everything else - system design only uses:


1. Time
2. Data Size
3. Throughput(derived)

Everything else reduces to these.
* * *

## 2. Time conversions (Must memorize)

### Core constants

```
TIME CONVERSIONS

Basic
1 minute = 60 seconds
1 hour = 60 minutes
1 day = 24 hours
1 week = 7 days
1 year = 12 months

Expanded
1 hour = 3,600 seconds
1 day = 1,440 minutes
1 day = 86,400 seconds

1 week = 168 hours
1 week = 10,080 minutes
1 week = 604,800 seconds

Common larger units
1 month ≈ 30 days                  (rough estimate)
1 month ≈ 4 weeks                  (rough estimate)
1 year = 365 days                  (normal year)
1 leap year = 366 days
1 year = 52 weeks + 1 day          (normal year)
1 year = 52 weeks + 2 days         (leap year)

Year expanded
1 year = 8,760 hours               (365 × 24)
1 year = 525,600 minutes
1 year = 31,536,000 seconds

Leap year expanded
1 leap year = 8,784 hours
1 leap year = 527,040 minutes
1 leap year = 31,622,400 seconds

Useful system design approximations
1 second = 1,000 milliseconds
1 millisecond = 1,000 microseconds
1 microsecond = 1,000 nanoseconds

1 minute = 60,000 milliseconds
1 hour = 3.6 million milliseconds
1 day = 86.4 million milliseconds

Quick reference
1 min   = 60 sec
1 hr    = 60 min = 3,600 sec
1 day   = 24 hr = 1,440 min = 86,400 sec
1 week  = 7 days = 168 hr
1 month ≈ 30 days
1 year  = 365 days = 8,760 hr = 31.5M sec
```

🔥 Key Insight

* Seconds is the stand unit of time measurement
* Always convert to seconds 

Because

```
QPS(Queries Per Second) = requests / second
```

### Mental shortcuts

```
1 day ≈ 10^5 seconds
1 year ≈ 3 x 10^7 seconds
```

This makes division easy.

Example:

```
500M requests/day

-> 500M / 100K
= 5000 QPS
```

* * *

## 3. Data Size Conversions (Must memorize)

### Core constants

```
Basic (Binary - used in systems)

1 bit = 0 / 1

1 Byte(B) = 8 bits
1 KB (Kilobyte) = 1,024  B     = 2^10 B
1 MB (Megabyte) = 1,024 KB     = 2^20 B
1 GB (Gigabyte) = 1,024 MB     = 2^30 B
1 TB (Terabyte) = 1,024 GB     = 2^40 B
1 PB (Petabyte) = 1,024 TB     = 2^50 B
```

🔥 Key Insight

* Always think in powers of 10 (not 1024)
* Even though computers use 1024, interviews use 10^x for speed.

### Expanded Values

```
1 KB = 1,024 B

1 MB = 1,048,576 B                (~10^6)
1 GB = 1,073,741,824 B            (~10^9)
1 TB = 1,099,511,627,776 B        (~10^12)
1 PB = 1,125,899,906,842,624 B.   (~10^15)
```

### Decimal (SI - used in networking/marketing)

```
1 KB = 1,000 B
1 MB = 1,000 KB
1 GB = 1,000 MB
1 TB = 1,000 GB
```

Key rule:

* Storage (OS, memory) → uses 1024(binary)
* Networking / bandwidth / disks marketing → uses 1000 (decimal)

### System design shortcuts

```
1 KB ≈ 10^3 B
1 MB ≈ 10^6 B
1 GB ≈ 10^9 B
1 TB ≈ 10^12 B

1 KB ≈ 1,000 B
1 MB ≈ 1,000,000 B
1 GB ≈ 1,000,000,000 B
```

### BITS vs BYTES

```
1 Byte = 8 bits

1 KB = 8 Kb
1 MB = 8 Mb
1 GB = 8 Gb
```

**Uppercase B = Byte, lowercase b = bit**


### Bandwidth conversions

```
1 Mbps = 1,000,000 bits/sec

Convert to MB/s:
1 Mbps ≈ 0.125 MB/s

Examples:
10 Mbps ≈ 1.25 MB/s
100 Mbps ≈ 12.5 MB/s
1 Gbps ≈ 125 MB/s
```

### Quick reference

```
1 KB ≈ 1,000 bytes
1 MB ≈ 1 million bytes
1 GB ≈ 1 billion bytes

1 GB ≈ 10^9 B
1 second ≈ 10^0 sec
1 day ≈ 10^5 sec
1 year ≈ 3 × 10^7 sec
```

Example:

```
1M users x 1KB each = 1GB
```

* * *

## 4. Throughput conversions

### 4.1 Core definition

```
Throughput = amount of data processed per unit time

Common units:
- requests/sec (QPS / RPS)
- bytes/sec (B/s)
- bits/sec (bps)
```

### 4.2 Bits ↔ Bytes

```
1 Byte = 8 bits
1 B/s = 8 bps
1 KB/s = 8 Kbps
1 MB/s = 8 Mbps
1 GB/s = 8 Gbps
```

Rule:

* Network → bits (bps)
* Storage → bytes (B/s)

### 4.3 Bandwidth ↔ Data Rate

```
1 Mbps = 0.125 MB/s
8 Mbps = 1 MB/s
```

Common conversions

```
10  Mbps = 1.25 MB/s
100 Mbps = 12.5 MB/s
1   Gbps = 125MB/s
10  Gbps = 1.25 GB/s
```

### 4.4 Time-based Throughput

Per second ↔ per day

```
1 day = 86,400 sec = 10^5 sec
```

Convert B/s → per day

```
X B/s x 10^5 = per day
```

Convert per day → B/s

```
X per day / 10^5 = per second
```

Example:

```
1TB/day = 10^12 / 10^5 =10,000,000 10^7 B/s = 10 MB/s
```

### 4.5 Requests ↔ Data throughput

Core formula

```
QPS = requests / second

Bandwidth = QPS × size per request
```

Example 1

```
1,000 requests/sec x 1KB
= 10^3 x 10^3 = 10^6 B/s = 1 MB/s
```

Example 2

```
1M users/day x 10 KB per request

= 10^6 x 10^4 = 10^10 B/day
= 10 GB/day
```

### 4.6 QPS Conversions

```
1 QPS = 1 request/sec

1K QPS = 10^3 req/sec
1M QPS = 10^6 req/sec
```

Daily → QPS


```
QPS = total_requests / 10^5
```

Example:

```
10M requests/day = 10^7 / 10^5 = 100 QPS
```


QPS → Daily

```
QPS x 10^5 = requests/day
```

Example:

```
100 QPS x 10^5 = 10^7 = 10M requests/day
```

### 4.7 Interview shortcuts

```
1 day = 10^5 sec

1 KB = 10^3 B
1 MB = 10^6 B
1 GC = 10^9 B

1 Mbps = 0.125 MB/s

Throughput:
B/s = QPS x size
```



### 4.8 Common patterns

Pattern 1: User → QPS

```
1M daily users
= 10 QPS (average)
= 100 QPS (peak)
```

Pattern 2: Storage growth

```
10MB/s
-> 1 TB/day
-> 365 TB/year
```

Pattern 3: API traffic

```
10K QPS x 1 KB
= 10 MB/s
= 1 TB/day
```

Must memorize core set

```
1 MB/s = 100 GB/day
1TB/day = 10MB/S

1Mbps = 0.125MB/s

QPS = total / 10^5

Throughput = QPS x size
```

## 

## 5. 3 Conversion patterns you must master

Pattern 1: Divide by time

```
X per day -> QPS
= divide by 10^5
```

Pattern 2: Multiply by size

```
QPS x size -> bandwidth
```

Pattern 3: Multiply over time

```
daily storage x 365 -> yearly storage
```

## 6. Full mental model

```
Users -> Requests -> QPS -> Data size -> Throughput -> Storage
```



## 7. 5 Most common conversions in interviews

1. Requests/day → QPS

```
100M/day -> ~1K QPS
```

1. QPS → Bandwidth

```
10K QPS x 1KB = 10MB/s
```

1. Bandwidth → Daily data

```
10MB/s -> ~ 1TB/day
```

1. Object count → storage

```
1B objects x 1KB = 1TB
```

1. Daily growth → Yearly storage

```
10TB/day -> ~3.6PB/year
```

