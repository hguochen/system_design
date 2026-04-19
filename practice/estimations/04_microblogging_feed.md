# Practice 4 — Microblogging / Feed (e.g. Twitter/X)

## Given Assumptions
- 500M DAU
- Each user reads 100 tweets/day (feed reads)
- 5% of users post 3 tweets/day
- Average tweet size: `tweet_id` (8B) + `user_id` (8B) + `text` (280B) + `created_at` (8B) + `media_url` (100B, optional)
- 20% of tweets contain media; average media size: 2 MB
- Tweets retained for 10 years
- Replication: 3×

## Your Task

Estimate all of the following. Show your working step by step. State any additional assumptions you make.

1. Write RPS (tweets/sec)
2. Read RPS (tweet reads/sec)
3. Read:Write ratio
4. Tweet record size (text only)
5. Total raw tweet metadata storage after 10 years
6. Total raw media storage after 10 years
7. Total storage footprint (metadata + media, with replication)
8. Inbound and outbound bandwidth

---

## Answer Key

### 1. Write RPS
- Tweeters: 500M × 5% = 25M users posting
- Tweets/day: 25M × 3 = 75M tweets/day
- Write RPS: 75M / 10^5 = **750 writes/sec**

### 2. Read RPS
- Reads: 500M × 100 = 50B reads/day
- Read RPS: 50B / 10^5 = **500,000 reads/sec**

### 3. Read:Write ratio
- 500K : 750 ≈ **667:1** (extremely read-heavy)

### 4. Tweet record size
- 8 + 8 + 280 + 8 + 100 = **404B ≈ 400B**

### 5. Total raw tweet metadata after 10 years
- Tweets: 75M/day × 365 × 10 = 273.75B tweets
- Storage: 273.75B × 400B = 109,500 GB ≈ **~110 TB**

### 6. Total raw media storage after 10 years
- Media tweets: 273.75B × 20% = 54.75B media items
- Storage: 54.75B × 2 MB = 109,500,000 GB ≈ **~109 PB**

### 7. Total storage footprint
| Component | Raw | × Replication | Total |
|---|---|---|---|
| Metadata | 110 TB | × 3 | ~330 TB |
| Media | 109 PB | × 3 | **~327 PB** |
| **Combined** | | | **~327 PB** (media dominates) |

### 8. Bandwidth
| Direction | Calculation | Result |
|---|---|---|
| Write inbound (text) | 750/s × 400B | ~300 KB/s |
| Write inbound (media) | 750 × 20% × 2 MB | ~300 MB/s |
| Read outbound (text) | 500K/s × 400B | ~200 MB/s |
| Read outbound (media) | 500K × 20% × 2 MB | **~200 GB/s** |

> Note: Media outbound (200 GB/s) completely dominates — CDN is non-negotiable.
