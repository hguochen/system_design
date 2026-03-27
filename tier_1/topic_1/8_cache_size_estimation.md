# 🧠 Subtopic 8 - Cache Size Estimation

* * *


## 0. 🎯 Goal of This Subtopic

You should be able to:

### 1. Instantly answer:

* How big should the cache be?
* How much memory do we need for Redis?
* Can we cache hot data?

### 2. Translate traffic → memory:

```
QPS → working set → cache size
```

### 3. Make Key design decision:

* Can cache hold hot data only?
* Or must it hold entire dataset?

* * *


### 🏆 What Mastery Looks Like

You have mastered this subtopic when you can:


- [ ] I know the core formula by heart
- [ ] I think in “working set”, not total data
- [ ] I can do mental math instantly
- [ ] I always include TTL + overhead
- [ ] I can estimate in <10 seconds and explain in 1 sentence

>“We have 100K QPS, hot set is 20%, objects are 1KB
→ cache ≈ 20K × 1KB × TTL window”

* * *

## 1. 🧾 Cheat Sheet

```
// Core Formula
Cache Size = QPS × Object Size × TTL × Hot Ratio

// Real world anchors
System -> Cache Type

Instagram feed -> hot posts
Twitter timeline -> fan-out cache
YouTube -> metadata cache
CDN -> edge cache

// Common Values
1 day -> 10^5 sec
1 hour -> 3600 sec
hot ratio -> 10 - 20%
overhead -> +30%

// When to use what
Case -> Formula

request cache -> QPS x size x TTL
user cache -> users x size
feed cache -> active users x feed size

// Model Selection Decision Tree
Do I see QPS + TTL?
→ YES → Request model

Do I see number of objects?
→ YES → Object model

Do I see users / sessions?
→ YES → User model

// All cache sizing models
1. Request-Based (TTL Model)
Cache = QPS x Object Size x TTL x Hot Ratio

2. Object-Based (Working Set Model)
Cache = #Cached Objects x Object Size

3. User-Based (State/Session Model)
Cache = Concurrent Users x Data per User

4. Hybrid Model
Feed system:
Cache = Active Users × Feed Size × Object Size
OR
Cache = QPS × TTL × size (for feed generation layer)

// Always say in interview
- "We only cache hot data, not full dataset"
- "Cache size depends on TTL window"
- "Add 30% overhead for Redis"
```


* * *


## 2. 🧩 Core Concepts / Mental Models

>“Cache sizing depends on the model — request-based (QPS × TTL), object-based (working set), or user-based (state).”

### Concept 1: Cache size is NOT total data size

```
Cache Size = Working Set Size
```

### Concept 2: Working Set Definition

```
Working Set = actively accessed data within a time window
```

Examples:

* Last 24h active users
* Trending posts
* Hot keys (top 1-20%)

### Concept 3: Cache is about time window, not total data

```
TTL ↑ → Cache size ↑
QPS ↑ → Cache size ↑
Hot ratio ↑ → Cache size ↑
```

* * *


## 3. ⚙️ Key Formulas

### 1. Basic Formula

```
Cache Size = QPS x Object Size x TTL
```

### 2. With hit rate / hot ratio

```
Cache Size = QPS x Object Size x TTL x Hot Ratio
```

### 3. Alternative (user-based)

```
Cache Size = Active Users x Data per User
```

When to use Which Formula

|Scenario	|Formula	|
|---	|---	|
|Request-based cache	|QPS x size x TTL	|
|User/session cache	|users x size	|
|Feed / timeline	|active users x feed size	|
|DB query cache	|hot % x dataset	|

Example:
1K QPS x 1 KB x 1 hour

```
= 1K x 1 KB x 3600s
= 3.6GB
```

### 4. Quick conversions

|QPS	|1 KB objects	|1 hour cache	|
|---	|---	|---	|
|
1K	|
→	|
~3.6 GB	|
|
10K	|
→	|
~36 GB	|
|
100K	|
→	|
~360 GB	|

* * *

## 4. 🧠 Intuition

Step by step method to estimating cache size

### Step 1 - Identify cache target

* What are we caching?
    * user profiles?
    * posts?
    * query results?

### Step 2 - Estimate Object Size

Typical values:

|Object	|Size	|
|---	|---	|
|
ID	|
8B	|
|
small JSON	|
1KB	|
|
feed item	|
1–5KB	|
|
image metadata	|
1KB	|

### Step 3 - Estimate QPS

```
QPS = daily requests / 10^5
```

### Step 4 - Decide TTL

|Use Case	|TTL	|
|---	|---	|
|
hot feed	|
seconds–minutes	|
|
user profile	|
minutes–hours	|
|
analytics	|
hours	|

### Step 5 - Apply Formula

```
Cache = QPS x size x TTL x hot ratio
```



### Step 6 - Add Overhead

Always add:

```
+ 20%–50% overhead
```

For:

* metadata
* replication
* fragmentation

* * *


## 5. ⚡ Patterns & When to Use

### 1. Hot Data Cache (Most Common)

```
Only cache top 10-20% data
```

Example:

* 1B total objects
* only 100M hot



### 2. Full Dataset Cache (RARE)

Used when:

* dataset small
* reads extremely high



### 3. Sliding Window Cache

```
Cache last X minutes of traffic
```

Used in:

* feeds
* realtime systems

* * *


## 6. ⚠️ Common Pitfalls

### ❌ Mistake 1: Using total storage

Wrong:

```
Cache = total DB size
```

Correct:

```
Cache = working set
```

### ❌ Mistake 2: Ignoring TTL

TTL directly scales memory!


### ❌Mistake 3: Ignoring hot ratio

Most systems:

```
80/20 rule (Pareto principle)
```



### ❌Mistake 4: Forgetting overhead

Redis memory != raw data

* * *

## **7. 🧠 Interview Shortcuts**

### Shortcut 1 - “1 hour rule”

```
Cache = QPS x size x 3600
```



### Shortcut 2 - “Hot 20% rule”

```
Cache = 20% of working dataset
```



### Shortcut 3 - “Active users rule”

```
Cache = daily active users x data per user
```

* * *


## 7. 🔗 How It Connects to Other Topics

* Related subtopics:
* Builds into:
* Depends on:

* * *


## 8. 🧪 Mini Drills (Active Recall)

### Example 1

System:

* 100K QPS
* object = 1KB
* TTL = 10 min (600s)
* hot ratio = 20%

Calculation

```
Cache = 100K × 1KB × 600 × 0.2
      = 12 GB
```

Add overhead:

```
= 15 - 18 GB
```

* * *

