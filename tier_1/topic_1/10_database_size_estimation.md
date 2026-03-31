# 🧠 Subtopic 10 - Database Size Estimation

* * *

>How much data will my system store over time?

# 0. 🎯 Goal of This Subtopic

You must be able to:

* Estimate total database size quickly (within 30-60 seconds)
* Break database sizing into:
    * Per-record size
    * Number of records
    * Retention period
* Account for:
    * Indexes
    * Replication
    * Metadata overhead

* * *


### 🏆 What Mastery Looks Like

You have mastered this subtopic when you can:


* Instantly choose the correct model:
    * User-based
    * Event-Based
    * Time-based
* Estimate row size without hesitation
* Apply multipliers automatically
    * index overhead
    * replication
* Catch mistakes via sanity checks

In Interview:
Each record ~ 1 KB x 100M records = 100 GB, with indexes and 3x replication → ~400 GB total.
* * *

# 1. 🧾 Cheat Sheet

```
# 1. Core Models

User-based:
Total = users x data per user

Event-based:
Daily = QPS x size x 100K
Total = Daily x days

Object-based:
Total = objects x size

# 2. Record Size Defaults
Small record -> ~100B
Medium record -> ~1KB
Large record -> ~10KB

# 3. Overhead
Indexes -> 1.5x - 2x
Replication -> 2x - 3x

Typical multiplier: ~3x - 5x total

# 4. Formula

Total DB size = 
(#records x record size)
x time
x index factor
x replication factor
(index + replication in total can apply a 3-5x multiplier)

# 5. Sanity check
- Is this TB-scale (most real problems are)
- Did i include time?
- Did i include overhead?
- Is record size realistic?

# 6. Default assumptions

Record size:
- simple → 100B
- normal → 1KB
- large → 10KB

Replication:
- default → 3x

Index:
- default → 1.5x

# 7. Interview template 

1. First estimate raw data size
   raw = rate × record size × time

2. If the prompt asks for real DB footprint:
   apply indexes / replication separately

3. If ambiguous:
   answer raw first, then mention provisioned size as optional

4. If retention exists:
   only count data still inside the retention window

# Ambiguous DB size question
Answer:
Raw size = X
If we include index/replication overhead, actual storage may be Y

# Retention
Retention is a rolling window, not discrete yearly buckets

# Best interview habit
Never silently assume overhead
State raw first unless the prompt explicitly asks for final/provisioned size
```

* * *


# 2. 🧩 Core Concepts

## 2.1 What are you actually measuring?

At its core:

>Database size = total bytes required to store all persistent data


Break that down:

```
Database Size =
Σ (all records stored over time)
```

### Key Insight

A database is not a snapshot - it’s **accumulated data over time**
This is why:

* Time(retention) is non-optional
* Event systems explode in size

## 2.2 The Fundamental Equation

Everything reduces to:

```
Total size = (#records) x (size per record)
```

Why this works?

Because databases store:

* Rows (SQL)
* Documents (NoSQL)
* Entries (KV stores)

All of them are just collections of records


## 2.3 Database two axes of growth

Every database grows along 2 dimensions


### Axis 1 - Record size

What is stored per entry?

```
Record Size = Σ(field sizes)
```

Typical components


|Field	|Size (approx)	|
|---	|---	|
|ID	|8B	|
|Timestamp	|8B	|
|UserID	|8B	|
|Content	|100B-1KB	|
|Metadata	|50-200B	|

Most candidates underestimate content + metadata size.
That’s where 90% of bytes come from.


### Axis 2 - Number of records

How many entries exist?
This depends on data generation pattern:


#### Case A - Static (User-based)

```
#records = #users
```

* Profiles
* Settings

Growth is **slow**


#### Case B - Dynamic (Event-based)

```
#records = QPS x time
```

* Messages
* Logs
* Transactions

Growth is **explosive**


#### **🔥 Critical Insight**

Event-based systems dominate storage. Why?

```
Even small records x huge volume = massive storage
```



## 2.4 Time is the hidden multiplier

Why time matters

Data is not deleted immediately

So:

```
Total records = rate x time
```

Example:

```
1K QPS -> 100M/day
100M/day x 365 = 36.5B records/year
```

Even at 1KB:

```
-> 36.5TB/year
```

Therefore, time turns “small systems” into TB-scale systems


## 2.5 Storage is not just raw data

Reality: DB size > raw data

Why? Because databases store:


### 2.5.1 Indexes

* B-trees / LSM structures
* Secondary indexes
    * +50% to 100%

### 2.5.2 Replication

* Data copied across nodes

```
2x - 3x
```

### 2.5.3 Storage engine overhead

* Row headers
* Versioning
* Padding/alignment

```
~10-30%
```

### **🔑 Insight**

Real DB size is usually 3x - 5x raw data


## 2.6 Why Event-based estimation uses QPS

Core reasoning

QPS = rate of data generation

So:

```
#records = rate x time
```

* * *


# 3. ⚙️ Key Formulas / Mental Models

The entire subtopic in one model:

```
Database Size =
(data generated per second)
x time
x overhead
```

Expanded

```
Database Size = 
(QPS x record size)
x time
x (index + replication)
```

* * *


## 4. 🧠 Intuition

Most people think 

```
Database size = storage calculation
```

But the real interpretation is:

```
Database size = system growth model
```

Why this intuition matters?
It determines:

* Sharding strategy
* Storage choice
* Cost
* Scalability limits

* * *


# 5. ⚡ Patterns & When to Use

## Pattern 1 - “Users storing data”

Use:

```
users x data per user
```



## Pattern 2 - “Continuous activity”

Use:

```
QPS x time x size
```



## Pattern 3 - “Files/media”

Use:

```
#objects x size
```

* * *


# 6. ⚠️ Common Pitfalls

## ❌ Mistake 1: Forgetting time dimension

Wrong:

```
QPS x size
```

Correct:

```
QPS x size x time
```

## ❌ Mistake 2: Unrealistic record size

Typical failure:

* Assuming 10B instead of 1KB

Off by 100x


## ❌ Mistake 3: Ignoring Indexes

Reality

* DB size != raw data size

## ❌ Mistake 4: Mixing cache with DB

* Cache = subset
* DB = full dataset

## ❌ Mistake 5: Overprecision

Bad:

```
17.36TB
```

Good:

```
~20TB
```


* * *

