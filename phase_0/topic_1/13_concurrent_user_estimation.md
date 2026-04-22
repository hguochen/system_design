# 🧠 Subtopic 13 - Concurrent User Estimation

* * *


# 0. 🎯 Goal of This Subtopic

What you should be able to do

* Convert total users → concurrent users → QPS
* Estimate:
    * DAU / MAU → active users
    * Active users → concurrent users
    * Concurrent users → request load
* Handle:
    * Peak vs average concurrency
    * Burst traffic scenarios
* Reason about:
    * How many users online right now?
    * How many are hitting my system simultaneously?

* * *


## 🏆 What Mastery Looks Like

You have mastered this subtopic when you can:

* Derive concurrency in <30 seconds
* Justify assumptions(not guess blindly)
* Connect: users → concurrent users → QPS → infra

* * *

# 1. 🧾 Cheat Sheet

```
# 1. Ratio based
Concurrent Users = Total active users x Concurrency ratio

# 2. Session Based Model
Concurrent Users = (Active Users x Avg Session Duration) / Time Window

# 3. Typical Ratios
Daily Active Users (DAU):
-> concurrency = 1% - 10%

Monthly Active Users (MAU):
-> concurrency = 0.1% - 1%

# 4. Peak Multiplier
Peak Concurrent User = Avg Concurrent x (2 to 5)

# 5. QPS Conversion
QPS = Concurrent Users x Requests per User per Second

# 6. Quick Defaults
Concurrency ratio:
-> Social: 5 - 10%
-> Saas: 1-5%
-> Background apps: 0.1-1%

Peak multiplier
-> 3x (safe default)

# 7. Key Shortcut
DAU → Concurrent:
→ divide by 20 (≈ 5%)

Example:
10M DAU → ~500K concurrent
```

* * *


# 2. 🧩 Core Concepts

## 2.1 What is a “Concurrent User”?

A user actively interacting with your system at the same time.
NOT:

* total users
* registered users
* even DAU

Think:
“How many users are simultaneously generating load?”


## 2.2 Why it matters?

Concurrency is what actually drives:

* QPS
* CPU load
* DB connections
* Network usage

Infrastructure scales with concurrent users, not total users


## 2.3 Two Ways to Estimate Concurrency

### 2.3.1 Ratio-Based(fastest)

```
Concurrent = DAU x % active at a moment
```

Use when:

* No session data available
* Early estimation phase

### 2.3.2 Session-based(more accurate)

```
Concurrent = (Users x Session Duration) / Time Window
```

Example:

* 1M users/day
* Avg session = 10 minutes
* Day = 1440 minutes

```
Concurrent = (1M x 10) / 1440 = 7K users
```

Estimating concurrent users by session is more grounded and explainable.
* * *


# 3. 🧠 Mental Models

## 3.1 “Concert Hall Model”

* Total users = people in the city
* Concurrent users = people inside the concert

Only people inside generate load


## 3.2 “Time Slice Model”

Think

```
Concurrency = total usage spread across time
```

* More spread → lower concurrency
* More concentrated  → higher concurrency



## 3.3 “Water Flow Model”

* Users = total water volume
* Concurrency = flow rate

System break from flow, not total volume


## 3.4 “Peak is reality”

Average is useless.

We should design for peak concurrent users.
* * *


# 4. ⚙️ Key Formulas

## 4.1 Ratio Model

```
Concurrent Users = DAU x Concurrency Ratio
```

Example:

```
800K concurrent users = 1M daily users x 8/10
```



## 4.2 Session Model

```
Concurrent Users = (Users x Session Duration) / Time Period
```

Example:

```
7K concurrent users = (1M users x 10min) / 1440min(1 day)
```



## 4.3 Peak Adjustment

```
Peak Concurrent = Average Concurrent x Peak Factor
```

Typical:

* 2x → stable systems
* 3x → normal assumption
* 5x → spiky systems(live events)



## 4.4 QPS Conversion

```
QPS = Concurrent users x Requests per user per second
```

Example:

```
QPS = 7K concurrent users x 10 requests per user/sec
QPS = 70K
```

## 

## 4.5 Reverse Estimation (important)

```
Concurrent users = QPS / requests per user
```

Useful when given QPS
* * *


# 5. ⚡ Patterns

## Pattern 1: DAU → Concurrent → QPS

```
10M DAU
-> 5% concurrent = 500K
-> 0.2 req/sec per user
-> 100K QPS
```



## Pattern 2: Session-based systems (Netflix, Youtube)

* long sessions
* lower concurrency ratio
* high sustained load



## Pattern 3: Burst systems (Twitter, Notifications)

* Short sessions
* High concurrency spikes
* Large peak multiplier



## Pattern 4: Enterprise SaaS

* Predictable working hours
* High peak during business hours



## Pattern 5: Real-Time Systems(Chat, Gaming)

* Very high concurrency
* Persistent connections
* Lower request frequency but constant presence

* * *


# 6. ⚠️ Common Pitfalls

## 6.1 ❌ Using total users instead of active users

## 6.2 ❌ Ignoring time distribution

* Users don’t spread evenly
* Peak hours dominate

Always apply peak multiplier


## 6.3 ❌ Confusing QPS with users

* QPS != users
* One user can generate multiple requests

## 6.4 ❌ Unrealistic concurrency ratio

Bad assumptions:

* 50% concurrent (almost never true)

Safe ranges:

* 1 - 10%

## 6..5 ❌ Ignoring session length

* short sessions → lower concurrency
* long sessions → higher concurrency

## 6.6 ❌ Not matching product type

Different systems → different behavior:


|System	|Concurrency	|
|---	|---	|
|Chat	|High	|
|Banking 	|Low	|
|Streaming	|Medium high	|
|Batch jobs	|near zero	|

## 6.7 ❌ Forgetting Peak vs Average

Always say:

>“Let’s estimate peak concurrent users“

* * *


# 7. 🔗 2 Minute Teachings

## Topic - User Concurrency

### What?

User concurrency is the number of users actively interacting with the system at the same time. Concurrency is driven by overlapping user sessions, not total users.

It represents the overlap of user activity over time.

### When?

We estimate user concurrency to understand peak system load.

This directly drives:

* QPS / RPS estimation
* Capacity planning (servers, DB connections, etc.)
* Scaling decisions

Systems scale with concurrent users, not total users.

### How?

Estimating user concurrency is often done based on 2 formulas.

Ratio based
Ratio-based estimation is a quick approximation when session behavior is unknown or not meaningful.

```
Average Concurrent users = Total users x concurrency ratio
```

For ratio based estimations, here are the typical ratios used realistically.

```
Daily Active Users (DAU):
-> concurrency = 1% - 10%

Monthly Active Users (MAU):
-> concurrency = 0.1% - 1%
```

Session based

```
Average Concurrent users = Active users x session_length / time window
```

This formula comes from the idea that:

Concurrent users = total user time / total time window

Where:

* users × session_length = total user time
* dividing by time window converts it into average overlap


Average concurrency smooths out traffic over time, but real systems experience spikes.

Therefore, we must design for peak concurrency.our system should be designed with peak concurrent user counts in mind, NOT average concurrent user counts.

```
Peak Concurrent User = Avg Concurrent x (2 to 5)
```

```
- 2x → stable systems
- 3x → general default
- 5x → highly bursty systems (e.g., social, live events)
```

* * *


# 8. 🧪 Q & A

## 8.1 Why does session-based estimation divide by time?

Question
Why do we compute:

```
Concurrent = (Users × Session Duration) / Time Window
```

instead of just using:

```
Users × Session Duration
```

What exactly does dividing by time represent?


```
We’re converting total user time into a rate (concurrency)

Users x Session Duration gives total user time consumed.

Dividing by the time window converts total usage into an average rate,
which represents how much of that usage overlaps at any moment.

So:
- numerator = total time spent by all users
- denominator = total available time

-> result = average number of users active simultaneously
```



## 8.2 When would ratio-based estimation be more appropriate than session-based?


Question
In what scenarios would you prefer:

```
Concurrent = DAU × concurrency ratio
```

over session-based estimation?

👉 Give concrete system examples.


```
Ratio-based estimation is preferred when:

1. Session duration is unknown or unreliable
2. The system is not session-oriented(eg. APIs, search queries)
3. We need quick estimation without detailed modeling

Example:
- Weather API -> request based, no session
- Search engine -> short, discrete queries

In these cases, concurrency is better approximated as a % of active users.
```



## 8.3 Why can a system with shorter sessions have higher peak concurrency than one with longer sessions?


Question
Explain how a system with 5-minute sessions can have higher peak concurrency than one with 60-minute sessions.


```
Concurrency = arrival rate x session duration

Even though longer sessions increases concurrency, peak concurrency is dominated by
arrival rate (synchronization).

Short session systems often have highly synchronized arrivals (eg. breaking news),
which creates spikes.

Long session systems are more evenly distributed.

So:
- long sessions -> higher baseline concurrency
- bursty arrivals -> higher peak concurrency
```



## 8.4 What assumptions are hidden in the session-based formula?


Question
The formula assumes:


```
Concurrent = (Users × Session Duration) / Time Window
```

What assumptions are we implicitly making about user behavior?

List at least 2–3.


```
Key assumptions:

1. Users are uniformly distributed across the time window
2. Sessions are independent (no mass synchronization)
3. Session duration is consistent enough to use an average
4. User behavior is stable over time

If these assumptions break (e.g., live events),
the model underestimates peak concurrency.
```



## 8.5 How does changing the time window affect concurrency?


Question
If everything else stays the same:


    *    Users = 10M
    *    Session = 10 min

How does concurrency change if:

    *    traffic is spread over 24 hours
    *    vs concentrated in 6 hours

👉 Explain intuitively (not just mathematically)


```
Smaller time window → same total usage compressed
→ higher overlap → higher concurrency

Larger time window → usage spread out
→ less overlap → lower concurrency
```

* * *

