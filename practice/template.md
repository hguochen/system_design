# System Design: [SYSTEM NAME]

---

## 0. Outline Approach
- Define Scale: 
- Derive math: 
- Design system: 

---

## 1. Scope

**In scope:**
- 

**Out of scope:**
- 

**NFRs:**
- Latency: 
- Availability: 
- Consistency: 

**System type:** 

---

## 2. Scale
- DAU:
- MAU:
- Concurrent users:
- Global/regional:

---

## 3. Behavior

| Action | Per User/Day | Total/Day |
|---|---|---|
|  |  |  |
|  |  |  |
|  |  |  |

- Read:Write ratio ≈
- Peak multiplier:

---

## 4. Traffic Pattern
- 

---

## 5. Data

**[Object] fields:**
| Field | Size |
|---|---|
|  |  |
|  |  |
| **Total** |  |

**Dominant field:** 

---

## 6. Retention
- Hot:
- Warm:
- Cold:
- Storage: bounded / unbounded

---

## 7. Infrastructure Assumptions
- Encoding overhead: 2x
- Indexing overhead: 2x
- Cache hit ratio:
- Replication factor: 3x

---

## 8. Derive Traffic

```
Total requests/day =

QPS = total / 10^5 =

Read QPS  =
Write QPS =

Peak (Nx):
  Read QPS  =
  Write QPS =
```

---

## 9. Derive Bandwidth

```
Read  = QPS x object size =
Write = QPS x object size =

Total peak bandwidth ≈
```

---

## 10. Derive Storage

```
Daily writes = x object size =
Retention    = days

Raw =

Apply:
  Encoding  x2 =
  Indexing  x2 =
  Replication x3 =
```

---

## 11. Derive Cache

**Working set:**
```
Hot data in 24h      =
Working set (20%)    =
Cache (with overhead) ≈
```

**Placement:**
- CDN:
- App layer (Redis):
- DB layer:

**Eviction:** 

**Invalidation:** 

---

## 12. Derive Servers

```
Peak QPS        =
QPS per server  =
Server count    =
```

---

## 13. Sanity Check

| Metric | Value | Sanity |
|---|---|---|
| Read QPS |  |  |
| Storage |  |  |
| Cache size |  |  |
| Servers |  |  |

---

## 14. High Level Design

**Request flow:**
```
Client → ... → 
```

**Major components:**
- **[Service]** —
- **[Service]** —
- **[DB]** —
- **[Cache]** —

---

## 15. Component Deep Dive

### Hardest component: [NAME]

**Problem:** 

**Options:**

| | Option A | Option B |
|---|---|---|
| Latency |  |  |
| Throughput |  |  |
| Tradeoff |  |  |

**Decision:** 

---

### API Design

```
GET    /v1/...    →
POST   /v1/...    →
PUT    /v1/...    →
DELETE /v1/...    →
```

---

### SQL vs NoSQL Decision

| Store | Choice | Reason |
|---|---|---|
|  |  |  |
|  |  |  |
|  |  |  |

---

## 16. Tradeoffs

**Consistency vs Availability:**
- 

**Latency vs Cost:**
- 

---

## 17. Summary

| Decision | Choice |
|---|---|
|  |  |
|  |  |
|  |  |
