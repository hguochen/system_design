# System Design Interview Format Step by Step

## 0. Outline Approach
- Define Scale
- Derive math
- Design system

## 1. Scope
- Functional requirements
    - what features are in/out of scope
- Non functional requirements
    - what's the SLAs the system must accomplish
        - availability, consistency, durability, latency
- System type

## 2. Scale
- DAU / MAU
- Concurrent users
- Global/regional usage

## 3. Behavior
- User actions per day
    - Split into read/write
- Read:write ratio
- Peak multipliers

## 4. Traffic Pattern
- Bursty/steady/spikes etc.

## 5. Data
- Data field breakdown
- Dominant data field

## 6. Retention
- Storage tiers
- Storage bounded/unbounded

## 7. Infrastructure Assumptions
- Encoding overhead
- Indexing
- Cache hit ratio
- Replication factor

## 8. Derive Traffic
- QPS = total requests / 10^5
- Split read vs write
- Apply peak multiplier

## 9. Derive Bandwidth
- Bandwidth = QPS x object size
- Separate read vs write

## 10. Derive Storage
- Daily write x retention
- Apply:
    - Encoding 2x
    - Indexing 2x
    - Replication 3x

## 11. Derive Cache
- Define working set
- Cache = working set
- Cache placement
    - CDN / app / DB layer
- Eviction policy
- Invalidation strategy

## 12. Derive Servers
- CPU bound / network bound
- Server count = max constraint

## 13. Sanity Check
- Check order of magnitude

## 14. High Level Design
- Request flow
- Major components

## 15. Component Deep Dive
- Identify and design the hardest/riskiest component first
- API design
- SQL vs NoSQL decision

## 16. Tradeoffs
- Consistency vs availability
- Latency vs cost

## 17. Summary
- Recap key decisions
