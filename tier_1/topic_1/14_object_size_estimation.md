# 🧠 Subtopic 14 - Object Size Estimation

Object Size Estimation is NOT about bytes. It’s about identifying:

* what dominates
* what multiplies 
* what scales

* * *


# 0. 🎯 Goal of This Subtopic

What you are learning

* Estimate size of a single object in a system(user, tweet, message, video, etc)

Why this matters

* Every system estimates builds on this:
    * Storage = object size x number of objects
    * Bandwidth = object size x QPS
    * Cache = object size x working set

If you object size is wrong → everything downstream is wrong.
* * *


## 🏆 What Mastery Looks Like

You have mastered this subtopic when you can 


* Instantly estimate:
    * user profile size
    * tweet / post size
    * image / video size
* break objects into components (metadata + payload)
* apply realistic overhead (index, encoding, replication)
* Sanity check answers quickly

* * *

# 1. 🧾 Cheat Sheet

```
# Object Size Estimation Cheat Sheet

## Typical Primitive Sizes
- char = 1B
- int = 4B
- long = 8B
- boolean = 1B
- timestamp = 8B

## String Estimation
- ASCII -> 1B/char
- Unicode -> 2-4B/char
- Rule of thumb -> 1-2B/char

## Common Objects
User Profile
- user_id -> 8B
- name (20 chars) -> 20 - 40B
- email -> 30B
- metadata -> 100 - 300B
≈ 200–500B total

Tweet/Post
- text (280 chars) -> 300B
- user_id -> 8B
- timestamp -> 8B
≈ ~350–500B

Message (chat)
≈ 200–500B

Image
- thumbnail -> 10-50KB
- medium -> 100 - 500KB
- high-res -> 1-5MB

Video
- 1 min HD -> ~5-10MB
- 1 hour HD -> ~3-6GB

## Anchors
User → 300B
Tweet → 500B
Message → 300B
Image → 100KB–1MB
Video → 5MB/min

## Overhead Multipliers
- JSON / serialization -> 1.5 - 2x
- Index -> 2-3x
- Replication -> 2-3x

## Final Rule
Final Size = Raw x Encoding x Index x Replication
```

* * *


# 2. 🧩 Core Concepts

## 2.1 Object = Metadata + Payload

Systems store:

* metadata(small, structured)
* payload(large, unstructured)

Example

Tweet:

* metadata → user_id, timestamp(~20B)
* payload → text (~300B)

Payload dominates for content systems
Metadata dominates for control systems(eg. configs)


## 2.2 Always Decompose Objects

Why?

* Humans are bad at guessing large sizes
* Breaking into fields ensures accuracy

Example
User profile:

* ID → 8B
* name → 20B
* email → 30B
* preferences → 200B

*Try to round off the numbers for easy calculation later*
→ total = 300B


## 2.3 Encoding Matters

What is encoding?
Definition

* Encoding is how your logical data is **represented in bytes** for storage/transmission
* Example:
    *    logical: {user_id: 123, name: "Gary"}
    *    encoded:
        *    JSON → text string with keys
        *    Protobuf → compact binary

Why?

* Same logical object → different physical size
* data structures in code are not what gets stored
* example:
    * java object → has pointers, padding, headers
    * network payload → serialized into JSON or binary

Interviews care about physical size


### 2.3.1 Encoding types

#### Text-based Encoding(JSON, XML)

Characteristics

* explanation
    * stores field names + values as text
    * human readable
* example

```
{"user_id":123,"name":"Gary"}
```

Cost

* field names are repeated → bloated
* example:
    *    "user_id" = 7 bytes (just key!)
    *    numbers stored as strings → inefficient

Rule of thumb

```
JSON ≈ 1.5x – 2.5x raw size
```

#### Binary Encoding(Protobuf, Avro)

Characteristics

* explanation
    * uses field IDs instead of names
    * compact numeric encoding
* example
    *    user_id → field #1 → 1 byte instead of 7 bytes

Cost

```
Binary ≈ 1x – 1.2x raw size
```

#### **Key Insight**

>JSON wastes space on structure
Binary optimizes for efficiency



## 2.4 Multipliers are Everywhere

Why?
Real systems store more than raw data:

* indexes
* replicas
* logs

Example
Raw tweet = 500B
Final:

* index → 2x
* replication → 3x

→ 500 x 2 x 3 = 3KB


## 2.5 Order of Magnitude Thinking

Why?

Interviews don’t need precision - they need correctness at scale

Example

* 300B vs 500B → doesn’t matter
* 300B vs 3KB → big mistake

* * *


# 3. 🧠 Mental Models

Below are the mental models you should equip with when estimating object sizes


## 3.1 Lego Model

Break object into blocks

```
Object = ID + core fields + optional fields + metadata
```

Why?

* prevents undercounting
* forces structured thinking

Example

Message:

* sender_id
* receiver_id
* content
* timestamp

## 3.2 Payload Dominance

Ask: What dominates size?

Why?

* avoid wasting time on tiny fields

Example
Video system:

* metadata = negligable
* video bytes = everything

## 3.3 Multiplication Pipeline

```
Raw → Encoding → Index → Replication
```

Why?

* Systems inflate data at every layer

Example

1KB object:

* JSON → 2KB
* index → 4KB
* replication → 12KB

## 3.4 Known Anchors

Memorize reference objects

Why?

* faster estimation via comparison

Examples

* tweet = 500B
* user = 300B
* image = 100KB - 1MB

* * *


# 4. ⚙️ Key Formulas

## 4.1 Basic Object Size

```
Object Size = Σ(field sizes)
```

Example
Tweet:

* text 300B
* user_id = 8B
* timestamp = 8B

→ 320B


## 4.2 With Overhead

```
Final Size = Raw × Encoding × Index × Replication
```

Example

* raw = 500B
* encoding = 2x
* index = 2x
* replication = 3x

→ 500B x 2 x 2 x3 = 6KB


## 4.3 String Size

```
String Size = #chars x bytes_per_char
```

Example

* 100 chars x 1B = 100B



## 4.4 Media Size

```
Size = bitrate x duration
```

Example

* 5Mbps x 60 sec = ~37MB

* * *


# 5. ⚡ Patterns

## 5.1 CRUD Systems (small objects)

Why?

* Data-heavy systems(users, messages)

Example

* user = 300B
* message = 500B

focus on metadata



## 5.2 Content Systems (medium objects)

Why

* payload starts dominating

Example

* posts with images → 100KB+

focus on payload



## 5.3 Media Systems (huge objects)

Why

* object size dominates entire system design

Example

* video streaming

bandwidth + storage explode


## 5.4 Sparse vs Dense Objects

Why

* optional fields inflate storage

Example

User:

* optional preferences → adds 100s of bytes

* * *


# 6. ⚠️ Common Pitfalls

## Pitfall 1 - Ignoring Encoding Overhead

Why it’s wrong

* JSON doubles size

Example
Raw = 500B → actual = 1KB+


## Pitfall 2 - Ignoring Index

Why it’s wrong

* DB indexes often 2-3x data



## Pitfall 3 - Ignoring Replication

Why it’s wrong

* production system always replicate

Example

RF = 3 → 3x storage


## Pitfall 4 - Over-optimizing precision

Why it’s wrong

* interview cares about scale, not exact bytes

## Pitfall 5 - Not identifying dominant field

Why it’s wrong

* wastes time

Example
Video system → don’t calculate metadata in detail


## Pitfall 6 - Assuming uniform object size

Why it’s wrong

* real systems vary

Example

* tweet: 10 chars vs 280chars

use averages
* * *


# 7. 🔗 2 Minute Teachings

## Topic - Object Size Estimation

### What?

Object Size Estimation is the process of estimating the size of core system data objects (e.g., messages, posts, users), which form the foundation of all system capacity planning.

### When?

Object size estimation is required when designing or scaling:

*    Data storage capacity
*    Network bandwidth requirements
*    Cache capacity

Because

```
Total system size = object size × number of objects
```



### How?

To reliably estimate object size, we first need to calculate the raw data size required. To get a reliable raw data size, we need to breakdown the object into it’s individual data fields and sum them up.


#### Step 1 - Decompose into fields

```
Breakdown of a chat system object:
- sender_id -> 8B
- receiver_id -> 8B
- timestamp -> 8B
- text -> 100B

Raw:
≈ 124B → round to 150B to factor for additional metadata required
```

#### Step 2 - Identify dominant field

* explanation: focus on the field contributing most to size
* example:
    * chat → text dominates
    * media → image/video domaintes

This avoid over-optimizing insignificant fields.


#### Step 3 - Apply multipliers(context-dependent)

Apply only if relevant:

Encoding

*    explanation: serialization format affects size
*    example:
*    JSON → ~2x
*    Protobuf → ~1–1.2x
*    ⚠️ Not needed for already compressed data (e.g., images, videos)

Index

*    explanation: depends on access patterns
*    example:
*    simple ID lookup → 1.1–1.5x
*    search-heavy systems → higher
*    ⚠️ May not apply for append-only systems (e.g., logs)


Replication

*    explanation: ensures durability and availability
*    example:
*    RF = 3 → ~3x storage
*    ⚠️ Not applicable for transient data (e.g., RPC)

Critical distinction

```
Stored size ≠ Read payload size ≠ Cache size
```

*    Stored size → includes encoding, index, replication
*    Read payload → only what is transmitted
*    Cache size → only what is stored in cache layer

* * *


# 8. 🧪 Mini Drills (Active Recall)

```
❓ Q1 — Chat Message

Design WhatsApp:
    •    text length = 100 chars avg
    •    includes:
    •    sender_id
    •    receiver_id
    •    timestamp
    •    message text

👉 Estimate final stored size per message

Breakdown:
- sender_id -> 8B
- receiver_id -> 8B
- timestamp -> 8B
- text -> 100B

Raw:
≈ 124B → round to 150B

Multipliers:
- encoding: 1.5–2x if JSON/text-based
- index: 1.1–1.5x for light indexing
- replication: 3x

Final:
≈ 150B × 2 × 1.2 × 3
≈ 1.1KB
⸻

❓ Q2 — Twitter Post

Design Twitter:
    •    tweet avg length = 120 chars
    •    includes:
    •    user_id
    •    tweet_id
    •    timestamp
    •    text

👉 Estimate final stored size per tweet

Breakdown:
- user_id -> 8B
- tweet_id -> 8B
- timestamp -> 8B
- text -> 120B

Raw:
≈ 144B → round to 150–200B

Multipliers:
- encoding: 1.5–2x
- index: 1.2–1.5x in primary store
- replication: 3x

Final:
≈ 180B × 2 × 1.3 × 3
≈ 1.4KB
⸻

❓ Q3 — Instagram Post (Trap inside)

Design Instagram:
    •    caption = 200 chars
    •    image = 500KB avg
    •    metadata = 200B

👉 Estimate final stored size per post

⚠️ Watch for trap

Breakdown:
- image -> 500KB
- caption -> 200B
- metadata -> 200B
- user_id + timestamp -> ~20B

Raw:
≈ 500KB

Multipliers:
- encoding: ~1.0–1.1x
- index: ~1.0–1.2x on metadata, negligible on image blob
- replication: 3x

Final:
≈ 500KB × 1.1 × 1.1 × 3
≈ 1.8MB
⸻

❓ Q4 — User Profile

Design user system:
    •    name = 20 chars
    •    email = 30 chars
    •    preferences/settings = 300B
    •    id + timestamps

👉 Estimate final stored size per user

Breakdown:
- user_id -> 8B
- name -> 20B
- email -> 30B
- preferences -> 300B
- timestamps -> 16B

Raw:
≈ 374B → round to 400B

Multipliers:
- encoding: 1.5–2x
- index: 1.2–1.5x
- replication: 3x

Final:
≈ 400B × 2 × 1.3 × 3
≈ 3.1KB
⸻

❓ Q5 — Video System (Hard)

Design YouTube:
    •    10 min video
    •    bitrate = 5 Mbps
    •    metadata = 1KB

👉 Estimate final stored size per video

⚠️ Multiple traps here

Breakdown:
- video: 5 Mbps = 0.625 MB/s
- duration: 600s
- raw video: 0.625 × 600 = 375MB
- metadata/title/captions: ~1–2KB, negligible

Raw:
≈ 375MB

Multipliers:
- encoding/transcoding: already reflected in bitrate, so do not add another generic encoding multiplier
- index: negligible on blob; metadata indexing only
- replication: 3x

Final:
≈ 375MB × 3
≈ 1.1GB

Breakdown:
- ...

Dominant:
- ...

Multipliers:
- encoding:
- index:
- replication:

Final:
≈ X
⸻


❓ Q1 — Simple CRUD Object

Design a notification system
    •    message text = 80 chars
    •    user_id
    •    notification_id
    •    timestamp

👉 Estimate final stored size per notification

Breakdown:
- user_id -> 8B
- notification_id -> 8B
- timestamp -> 8B
- message -> 80B
Raw = ~100B

Dominant:
- message

Multipliers:
- encoding: x2. # encode into JSON based 
- index: x1.2 # access will mostly be on the user_id and notification_id to pull the message
- replication: x3

Final:
≈ 720B

⸻

❓ Q2 — Average vs Max (Trap)

Design comments system:
    •    max comment = 500 chars
    •    avg comment = 120 chars

👉 Which do you use and estimate final size per comment

We should use average comment size to estimate final size.
The size of comments follows a uniform distribution curve. ie. most comments will be around average size.
Using max comment size to estimate final size would lead to over provisioning of storage and cost inefficiency

⸻

❓ Q3 — Encoding Judgment

Design internal RPC system:
    •    message = 200B raw
    •    uses Protobuf (binary)

👉 Estimate final stored/transmitted size

⚠️ Trap: encoding assumption

Breakdown:
- unique_id -> 8B
- timestamp -> 8B
- metadata -> 8B
- message -> 200B
Raw = ~220B

Dominant:
- message

Multipliers:
- encoding: not needed. # uses Protobuf, no further encoding required
- index: x1.1. # reads and writes are rare once RPC round trip is completed. maybe minimal indexing for referencing/debugging purposes. indexing unique_id will suffice.
- replication: x3

Final:
≈ 720B

⸻

❓ Q4 — Index Dependency (Trap)

Design analytics event logging:
    •    event = 300B
    •    append-only
    •    queried only in batch jobs

👉 Estimate final stored size per event

⚠️ Trap: index


Breakdown:
- id -> 8B
- event -> 300B
- timestamp -> 8B
Raw = ~300B

Dominant:
- event size

Multipliers:
- encoding: x2 # encode into JSON
- index: not needed. # event object is rarely accessed and queries are aggregates
- replication: x2 # assuming system behaves as analytics as a service, we do a simple 2x replication to improve durability

Final:
≈ 1.2KB

⸻

❓ Q5 — Metadata vs Payload

Design image storage:
    •    image = 1MB
    •    metadata = 500B

👉 Estimate final stored size

⚠️ Trap: dominant factor vs multipliers

Breakdown:
- id -> 8B
- timestamp -> 8B
- metadata -> 500B
- image -> 1MB
Raw = ~1MB
Dominant:
- image size

Multipliers:
- encoding: not needed. # image are already encoded with JPEG format etc.
- index: x1.1 # image are accessed primarily via their id. so simply id indexing is sufficent
- replication: x3 # min replication factor to improve durability and reliability while satisfying quorum requirements

Final:
≈ 3.3MB

⸻

❓ Q6 — Double Encoding Trap

System:
    •    client sends JSON
    •    server stores in binary format

Raw object = 400B

👉 Estimate final stored size

⚠️ Trap: double encoding


Multipliers:
- encoding: not needed.# storage encoding is different from network encoding. we expect system to convert JSON back into binary format, which has similar size to raw data size
- index: x1.1 # access to object directly via their id, so simple indexing will suffice
- replication: x3 # min replication factor to improve durability and reliability while satisfying quorum requirements

Final:
≈ 1.32 KB
⸻

❓ Q7 — Partial Indexing (Staff-level)

Design user search system:
    •    user object = 500B
    •    only name and email are indexed

👉 Estimate final stored size

⚠️ Trap: index granularity

Breakdown:
- id -> 8B
- object -> 500B
- name -> 8B
- email -> 16B
- timestamp -> 8B
- metadata -> 24B
Raw = 560B

Dominant:
- object size

Multipliers:
- encoding: x2. # encoding into JSON
- index: x 1.2 # objects are accessed via name/email only, so a small indexing overhead will suficef
- replication: x3 # min replication factor to improve durability and reliability while satisfying quorum requirements

Final:
≈ ~4KB
⸻

❓ Q8 — Media Bitrate (Critical)

Design video system:
    •    5 min video
    •    bitrate = 4 Mbps

👉 Estimate final stored size

⚠️ Trap: encoding already included

Breakdown:
- id -> 8B
- timestamp -> 8B
- video -> 0.5MB/s * 5 * 60 = 150MB
Raw = ~150MB

Dominant:
- video

Multipliers:
- encoding: not needed. # video is already encoded since it's bitrate
- index: x1.1. # minimal id indexing 
- replication: x3 # min replication factor to improve durability and reliability while satisfying quorum requirements

Final:
≈ 495MB
⸻

❓ Q9 — Distribution Awareness

Design tweet system:
    •    avg = 100 chars
    •    heavy tail: 10% tweets = 280 chars

👉 What size do you use and estimate final size

⚠️ Trap: distribution

We use average tweet size of 100 chars

Breakdown:
- id -> 8B
- timestamp -> 8B
- metadata -> 16B
- tweet -> 100B
Raw = ~130B

Dominant:
- tweet size

Multipliers:
- encoding: x2. # encoding into JSON will be used for both storage and network transmission. this is to avoid repeatedly encoding between storage and transmission
- index: x1.1 # tweets are mainly accessed via id, so minimal indexing required
- replication: x3 # min replication factor to improve durabiltiy and reliability whiel satisfying quorum requirement

Final:
≈ 858B

⸻

❓ Q10 — Object vs System Thinking (Hard)

System:
    •    user = 400B
    •    message = 300B
    •    100M users
    •    10B messages

👉 Which dominates storage and why?
(no need exact bytes)

⚠️ Trap: per-object vs total

Message size will dominate storage.
total user storage: 40MB
total message storage: 3GB

we have x100 more messages than users. while both storage will scale linearly, message storage is expected to increase 100x faster than user storage
⸻

```

```
🎓 Full System Test — Photo Sharing System

Design a simple Instagram-like photo sharing system.

Users can:
    •    upload photo posts
    •    view posts in feed
    •    view user profiles

You only need to solve the estimation part.

⸻

📌 Given

Traffic
    •    20M DAU
    •    each DAU uploads 2 photo posts/day
    •    each DAU views 100 feed posts/day
    •    peak traffic multiplier = 5x

⸻

Post object

Each post contains:
    •    photo = 800KB average
    •    caption = 150 chars average
    •    metadata = 300B
    •    user_id
    •    post_id
    •    timestamp

⸻

User profile object

Each user profile contains:
    •    name = 20 chars
    •    bio = 100 chars
    •    profile metadata/settings = 500B
    •    user_id
    •    timestamps

⸻

Storage assumptions
    •    photo is already compressed
    •    metadata objects are stored in JSON
    •    replication factor = 3
    •    only metadata is indexed
    •    metadata index overhead = 1.2x
    •    photos are kept forever
    •    user profiles are kept forever

⸻

Cache assumptions
    •    10% of daily viewed posts are hot and cached
    •    cache stores full post metadata + image reference only
    •    image blobs themselves are not cached in this layer
    •    image reference pointer = 100B

⸻

🧪 Your Tasks

⸻

Q1. Estimate the raw size per post object

Use proper breakdown.

⸻

Q2. Estimate the final stored size per post

Be careful:
    •    what gets JSON overhead?
    •    what gets index overhead?
    •    what gets replication?
    •    what does not get index overhead?

⸻

Q3. Estimate the raw size per user profile

Use proper breakdown.

⸻

Q4. Estimate the daily write storage added

From new photo posts only.

⸻

Q5. Estimate the total feed-read QPS at peak

Only for feed post views.

⸻

Q6. Estimate the peak read bandwidth

Assume each feed read returns full post metadata + image reference only, not the image blob.

⸻

Q7. Estimate the cache size needed

Based on hot viewed posts/day.

⸻

Q8. Identify the top 3 dominant factors in this system’s estimation

Not numbers — reasoning.

⸻

Q1.
Breakdown:
- user_id -> 8B
- post_id -> 8B
- timestamp -> 8B
- metadata -> 300B
- caption -> 150B
- photo -> 800KB

Raw:
≈ 800KB

Q2.
Metadata part:
Raw = ~500B # here we include every field except photo as part of metadata for a post
Multipliers:
- encoding: 2x # stored as JSON
- index 1.2x # metadata index overhead
- replication: 3x

Final metadata: 3.6KB

Photo part:
Raw = 800KB

Multipliers:
- encoding: none # photo is already compressed
- index: none
- replication: 3x

Final photo: 2.4MB

Final:
≈ ~2.4MB per post

Q3.
Breakdown:
- user_id -> 8B
- timestamp -> 8B
- profile metadata -> 500B
- name -> 20B
- bio -> 100B

Raw:
≈ ~650B

Q4.
Posts/day: 20M x 2 = 40M posts per day
each post size = 2.4MB

Storage/day: 40M * 2.4MB = 96TB


Q5.
Feed views/day: 20M * 100 = 2B views/day

Avg QPS: 2B / 10^5 = 20K QPS

Peak QPS: 100K QPS
...

Q6.
Per read payload:
- metadata raw ≈ 500B
- JSON encoded ≈ 1KB
- image reference ≈ 100B

Total:
≈ 1.1KB/read

Peak bandwidth:
100K × 1.1KB
≈ 110MB/s

Q7.
Hot posts/day:
2B × 10% = 200M

Per cached item:
≈ 1.1KB

Cache size:
≈ 220GB


Q8.
1. photo blob storage size. photo blob size accounts for almost all of the storage requirement per post
2. post metadata storage size. metadata size directly determines how big the cache size should be
3. Post peak read QPS. peak read QPS directly determines the bandwidth size this system should provision for

1.1. Photo blob size dominates write storage growth.
2.1. Feed-read QPS dominates serving bandwidth requirements.
3.1. Metadata payload size dominates cache footprint and read payload efficiency.
```

