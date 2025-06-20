# Sharding Pattern

## what is it?
- a data partitioning strategy used to scale out systems horizontally.
- it scales horizontally by splitting data across multiple databases or storage nodes, called shards.
- each shard contains a subset of the data, and together they form the complete data set.

## Core idea
Split large datasets across multiple nodes, each handling a fraction of the total load. Clients access the right node based on a shard key.

## How it works
1. Define a shard key - a field used to determine which shard stores a particular piece of data
2. Distribute data - use a consistent rule(eg. hashing, range) to assign records to shards
3. Route requests - client or middleware routes operations to the appropriate shard

## Example
Let's say we want to store user data:
- Shard key: user_id
- Shards:
    - Shard 1: user ids 1 - 1,000,000
    - Shard 2: user ids 1,000,000 - 2,000,000
    - Shard 3: user ids 2,000,000 - 3,000,000

## Sharding strategies
- Range based
    - Partition based on value ranges(eg. A - F, G - L)
- Hash based
    - Apply a hash function to the key and assign to shard
- Geo based
    - Partition by region or physical location
- Directory based
    - Central directory maps each record to a shard

## Benefits
- Horizontal Scalability
    - add more shards to handle more data/traffic
- Improved performance
    - shards reduce load on individual databases
- Parallelism
    - Queries and writes can be processed in parallel

## Drawbacks
- Complex joins
    - Cross shard joins are expensive or unsupported
- Data skew
    - Poor shard key choice can lead to hot spots
- Resharding
    - Hard to rebalance data when shards are imbalanced
- Operational overhead
    - More shards = more monitoring, backups, etc

## When to use it?
- Your dataset is too large for a single machine or DB node
- Your read/write traffic exceeds what one node can handle
- You need to scale out with minimal downtime
- You're okay with relaxed consistency and complex query trade-offs

## When NOT to use sharding?
- Small dataset or moderate traffic - unnecessary complexity
- Strong consistency and transactional support is a must
- Queries often require cross-partition joins or aggregates
