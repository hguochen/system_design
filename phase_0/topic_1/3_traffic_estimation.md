# 🧠 Subtopic 3 - Traffic Estimation

## **🎯 0. Goal of This Subtopic**

Traffic estimation answers:

>“How many requests does this system handle?”


It’s the foundation for:

* capacity planning
* scaling decisions
* database design
* caching strategy

* * *

## **🧾** 1. Cheat Sheet

```
Traffic Estimation

Core formula:
QPS ≈ total requests/day / 100K

When asked to estimate traffic, your answer structure should be:
1. I’ll estimate DAU first
2. Then estimate key user actions per day
3. Convert that to total daily requests
4. Convert to average QPS
5. Split reads vs writes
6. Call out any fanout or downstream internal traffic
7. Mention peak traffic will be higher than average

How to estimate:
1. Estimate DAU
2. Estimate actions per user per day
3. Multiply to get total daily requests
4. Divide by 100K to get QPS
5. Split by API / read / write

Common patterns:
- reads: DAU x reads/day
- writes: DAU x writes/day
- creator traffic: DAU x % creators x creations/day
- fanout: events/day x recipients/event

Always say:
- This is average QPS
- Peak QPS will be higher
- Reads and writes should be estimated separately
- Different APIs have different traffic levels
```

* * *

## 🧠 2. Core Mental Model

Traffic = how often users interact with your system

```
Traffic = Requests / Time
```

Most common units:

* QPS (queries per second)
* RPS (requests per second)
* Requests/day

* * *

## 3. The  3-Step Framework (You must Master)

### 3.1 Step 1 - Start with Users

Always begin with

```
#users x actions per user
```

Examples:

* DAU (daily active users)
* MAU (monthly active users)

### 3.2 Step 2 - Multiply by Behavior

Ask:

* What does each user do?

Examples:

* 10 page views/day
* 5 messages/day
* 2 uploads/day



### 3.3 Step 3 - Convert to QPS

Use your memorization:

```
1 day = 10^5 seconds
```

So:

```
QPS = total requests per day / 100K
```

* * *

## **🧩 4**. Canonical Formula

```
QPS = (DAU x actions per user per day) / 100,000
```

### 4.1 Example 1 - Social Media Feed

Assume:

* 100M DAU
* 10 feed loads per day

```
Total requests/day = 100M x 10 = 1B
QPS = 1B / 10^5 = 10,000 QPS
```

→ ~10K QPS


### 4.2 Example 2 - Message App

Assume:

* 50M DAU
* 20 messages sent/day

```
Total messages/day = 1B
QPS = 10K QPS
```



### 4.3 Example 3 - Video Platform(Uploads)

Assume:

* 10M DAU
* 1% upload videos
* 1 upload/day

```
Uploads/day = 10M x 1% = 100K
QPS = 100K / 10^5 = 1 QPS
```

→ Upload traffic is LOW
→ Read traffic is HIGH (important insight)
* * *

## 5. Critical Insight (VERY IMPORTANT)

Not all traffic is equal:

### 5.1 Read dominates writes

Typical systems:

|System	|Read:Write	|
|---	|---	|
|Social media	|100:1	|
|Search	|1000:1	|
|Messaging	|1:1	|

### 5.2 Different endpoints = different traffic

Example:

* GET /feed → high QPS
* POST /upload → low QPS

Always estimate per API

* * *

## **🧠 6**. **Interview Thinking Pattern**

When interviewer asks
→ Estimate traffic

You say:

1. Assume DAU
2. Estimate user behavior
3. Compute total requests/day
4. Convert to QPS
5. Break down read vs write

* * *

## **🧮 7**. **Common Assumptions (MEMORIZE)**

These are your default anchors:


|Metric	|Value	|
|---	|---	|
|1 day	|100K sec	|
|DAU % of MAU	|~10 - 20%	|
|Heavy user actions	|10-100/day	|
|Light user actions	|1-5/day	|

* * *

## **⚡8**. **Traffic Estimation Patterns**

### 8.1 Pattern 1 - Page based systems

```
DAU x page views
```



### 8.2 Pattern 2 - Event based systems

```
DAU x events per user
```

Examples:

* messages
* likes
* clicks



### 8.3 Pattern 3 - Percent-based actions

```
DAU x % users x action frequency
```

Example:

```
10M x 1% x 2 uploads = 200K uploads/day
```

* * *

## 🚨 9. Common Mistakes (YOU MUST AVOID)

### 9.1 Mistake 1 - Skipping user behavior

Wrong:

```
100M users -> 100M QPS **❌**
```

Correct:

```
users x actions -> requests
```



### 9.2 Mistake 2 - Forgetting time conversion

Always convert:

```
per day -> per second
```



### 9.3 Mistake 3 - Ignoring read/write split

Read & Write has different traffic behaviors


### 9.4 Mistake 4 - Unrealistic assumptions

Example:

```
each user uploads 100 videos/day **❌**
```

* * *

## **🧠** 10. **What Mastery Looks Like**

After mastering this topic, you should be able to:

* instantly estimate QPS in <30 seconds
* Break traffic into read vs write
* Identify hot endpoints
* Use traffic to justify architecture decisions

* * *

