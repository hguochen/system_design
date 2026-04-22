# 🧠 Subtopic 12 - Retention & Growth Modeling

* * *

# 0. 🎯 Goal of This Subtopic

What you must be able to do:

* Model data growth over time
* Model user growth & engagement decay
* Estimate steady state vs cumulative storage
* Handle retention policies(TTL, cold storage)
* Reason about system scaling over months/years

* * *


## 🏆 What Mastery Looks Like

You have mastered this subtopic when you can:

* Answer “How big will this system be in 1 year?”
* Distinguish:
    * bounded vs unbounded growth
    * retained vs discarded data
* Apply:
    * linear growth
    * exponential growth
    * decay curves

* * *

# 1. 🧾 Cheat Sheet

```
# Core Growth Models

1. Linear Growth
Total = rate x time

2. Retention-Bounded Storage
Storage = rate x retention_window

3. With Replication
Final Storage = raw x replication_factor

4. With Index Overhead
Final = raw x (1 + index_factor)

5. User Growth
Users(t) = initial x growth_rate^t

6. DAU Retention Model
Active users = total_users x retention_rate

7. Churn Model
Remaining = users x (1 - churn_rate)^t

8. Steady State System
If TTL exists:
Storage stabilizes at:
rate x TTL

9. Multi-tier Storage
Hot = recent window
Cold = historical archive

10. Backfill / Historical Load
Total = sum over time (not just steady rate)

11. Decay + Growth Equilibrium
// Active users (steady state) = New users per period / churn rate
A = N / (1-r)
---

# Quick Heuristics
- No deletion → UNBOUNDED growth
- TTL present → STEADY STATE
- Logs/events → linear growth
- Users/social → exponential early, then plateau
- Always ask: "Do we delete data?"
```

* * *


# 2. 🧩 Core Concepts

## Retention

Retention defines how long data is kept before deletion. With retention, storage grows until the retention window is filled, then stabilizes at write rate times retention. 
Without retention, storage grows indefinitely. In practice, retention often applies only to some data, and if write rate grows, even retention bounded storage can increase over time. 


## Growth Models

Growth models describe how the write rate or number of users evolves over time. Common models include linear growth with constant rate, exponential growth in early-stage systems, logistic growth where system plateau, and decay models like churn. These models determine the input rate, which combined with retention policies determines total storage.

## 2.1 Linear Growth (Default Model)

Most systems:

* logs
* messages
* events

```
Total Data = write_rate x time
```

Example:

* 100GB/day → 36.5TB/year

## 2.2 Retention Window (Critical Concept)

If system deletes old data:

```
Storage = write_rate x retention_period
```

Why this matters?

Without retention:

* system grows forever

With retention:

* system reaches steady state

## 2.3 Steady State vs Infinite Growth

|Scenario	|Behavior	|
|---	|---	|
|No deletion	|Infinite growth	|
|TTL = 30 days	|Fixed size	|
|Archival system	|Tiered growth	|

Mental shortcut:

```
If TTL exists -> system size is bounded
Else -> system grows forever
```

## 2.4 Retention Types

### Type 1 - Hard TTL

* delete after X days
* ex: logs, metrics

```
Storage = rate x TTL
```



### Type 2 - Soft Retention (Cold Storage)

* hot → cold → archive

```
Hot: last 7 days
Cold: last 1 year
```



### Type 3 - Forever Retention

* financial systems
* audit logs

must account for multi-year growth


## 2.5 Growth Models

### Model 1 - Linear Growth

* constant write rate



### Model 2 - Exponential Growth(early-stage startups)

```
Users(t) = U₀ × (1 + g)^t
```

* U₀ → initial number of users
* g → growth index.
    * say our user growth is 20%, growth index will be 0.2
* t → timeframe for growth
    * could be minute, hour, month, year etc

### Model 3 - Logistic Growth(realistic)

* fast early
* plateaus later



>Key Insight:
Assume exponential only if specified



## 2.6 User Retention & Churn

Retention

```
Active Users = Total Users x retention_rate
```

Churn

```
Remaining = users x (1 - churn)^t
```

Why it matters?

* affects traffic estimation
* affects storage growth



## 2.7 Write Amplification Over Time

Growth affects:

* storage
* replication
* indexing

```
Final size = raw x replication x indexing
```

* * *


# 3. ⚙️ Key Formulas

## 3.1 Total Data Growth

```
Total = rate x time
```



## 3.2 Retention-Bounded Storage

```
Storage = rate x retention_window
```



## 3.3 With Replication

```
Total = Rate x Time x Replication_factor
```



## 3.4 With Indexing

```
Total = raw x (1 + index_overhead)
```



## 3.5 User Growth

```
Users(t) = U₀ × (1 + g)^t
```

* U₀ → initial number of users
* g → growth index.
    * say our user growth is 20%, growth index will be 0.2
* t → timeframe for growth
    * could be minute, hour, month, year etc

## 3.6 Churn Model (Decay curve)

```
Users(t) = U₀ × (1 - churn)^t
```

* U₀ → initial number of users
* churn → churn index.
    * say our user drop rate is 20%, churn index will be 0.2
* t → timeframe for growth
    * could be minute, hour, month, year etc

## 3.7 Active Users

```
DAU = total_users x activity_rate
```



## 3.8 Steady State Storage

```
Storage = write_rate x TTL
```

* * *


# 4. 🧠 Mental Models

## 4.1 “Bucket vs River”

* River = incoming data
* Bucket = storage

Cases:

* No drain → overflow (infinite growth)
* Drain (TTL) → stable bucket



## 4.2 Hot vs Cold Data

Think in tiers:

```
Hot -> frequently accessed
Cold -> rarely accessed
Archive -> never accessed
```



## 4.3 Snapshot vs Flow

* Snapshot → current size
* Flow → growth rate



## 4.4 Steady State Equilibrium

System stabilizes when:

```
incoming_rate == deletion_rate
```

## 4.5 Early vs Mature System

```
Stage -> Growth

Startup -> Exponential
Scale -> Linear
Mature -> plateau
```

* * *


# 5. ⚡ Patterns

## Pattern 1 - Log/Metrics System

* linear growth
* TTL enforced

```
Storage = rate x TTL
```



## Pattern 2 - Messaging System

* growth tied to users

```
messages/day = users x msgs/user
```



## Pattern 3 - Social Media

* exponential → linear transition
* heavy read amplification



## Pattern 4 - Financial / Audit Systems

* no deletion
* infinite growth

requires:

* partitioning
* archival strategy



## Pattern 5 - Tiered Storage System

```
Hot (fast, expensive)
Cold (cheap, slower)
Archive (very cheap)
```



## Pattern 6 - Backfill Spike

When system launches:

```
Initial load ≠ steady load
```


* * *


# 6. ⚠️ Common Pitfalls

❌ Forgetting retention
→ massively overestimates storage

❌ Assuming infinite growth when TTL exists
→ wrong system sizing

❌ Ignoring replication
→ underestimation

❌ Ignoring indexing
→ underestimation

❌ Not projecting into future
→ weak system thinking
* * *


# 7. 2 Minute Teachings

## Topic: Retention

### What?

Retention defines how long data is kept before deletion.

It determines whether a system:

* grows forever (no retention)
* or reaches a steady state (with TTL)

### When?

Retention applies to persisted data with lifecycle constraints, such as:

* logs
* metrics
* user activity

Not all data has retention:

* some data(eg. financial records) is stored forever

### How?

Core Formula

```
Storage = write_rate x retention_window
```

But only at steady state

System behavior has two phases

```
Ramp-up: storage grows linearly
Steady state: storage stabilizes at rate × TTL
```

Retention applies only to some data, not all

```
Total storage = retained_data + permanent_data
```

With growth

```
Storage(t) = write_rate(t) × retention_window
```

event with TTL, storage can grow over time


## Topic Growth Model

### What?

Growth models describe how data or user activity increases over time.

>How does write_rate(t) change over time?

### When?

Used when estimating:

* future storage
* traffic scaling
* capacity planning

### How?

1. Linear Growth

```
write_rate = constant
total = write_rate x time
```

1. Exponential Growth (early stage systems)

```
Users(t) = U₀ × (1 + g)^t
```

write rate grows with users


1. Logistic Growth (real-world systems)

* fast early growth
* slows down
* reaches saturation

1. Decay(Churn)

```
Users(t) = U₀ × (1 - churn)^t
```

reduces active users over time


1. Growth + Decay Equilibrium

```
active_users stabilizes when:
incoming_users = churned_users
```

Let:

*    A_t = active users at time t
*    N = new users per period
*    r = retention rate (e.g. 0.8 means 80% stay)
*    c = 1 - r = churn rate

Recurrence equation

```
A_{t+1} = r × A_t + N
```

At equilibrium
System stabilizes → A_{t+1} = A_t = A

So:

```
A = rA + N
```

Solve

```
A - rA = N
A(1 - r) = N

// Active users (steady state) = New users per period / churn rate
A = N / (1-r)
```

total
* * *
