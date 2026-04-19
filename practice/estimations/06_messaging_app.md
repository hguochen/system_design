# Practice 6 — Messaging App (e.g. WhatsApp)

## Given Assumptions
- 2B DAU
- Each user sends 40 messages/day
- 80% of messages are text; 20% contain media (images/video)
- Average text message size: `msg_id` (8B) + `sender_id` (8B) + `receiver_id` (8B) + `text` (200B) + `created_at` (8B)
- Average media message payload: 1 MB
- Messages retained for 1 year
- Replication: 3×
- Assume persistent connections (WebSocket) for concurrent user estimation

## Your Task

Estimate all of the following. Show your working step by step. State any additional assumptions you make.

1. Total messages/day
2. Write RPS (messages sent/sec)
3. Text message record size
4. Total raw text message storage (1 year)
5. Total raw media storage (1 year)
6. Total storage footprint (with replication)
7. Inbound bandwidth (text + media)
8. Peak concurrent connections (assume 20% of DAU are online at any given time)

---

## Answer Key

### 1. Total Messages/Day
- 2B × 40 = **80B messages/day**

### 2. Write RPS
- 80B / 10^5 = **800,000 msg/sec**

### 3. Text Message Record Size
- 8+8+8+200+8 = **232B ≈ 250B**

### 4. Total Raw Text Message Storage (1 year)
- Text messages: 80B × 80% = 64B/day × 365 = 23.36T messages/year
- Storage: 23.36T × 250B = 5,840,000 GB ≈ **~5.84 PB**

### 5. Total Raw Media Storage (1 year)
- Media messages: 80B × 20% = 16B/day × 365 = 5.84T messages/year
- Storage: 5.84T × 1 MB = 5,840,000 TB ≈ **~5.84 EB**

### 6. Total Storage Footprint
| Component | Raw | × Replication | Total |
|---|---|---|---|
| Text (1 yr) | 5.84 PB | × 3 | ~17.5 PB |
| Media (1 yr) | 5.84 EB | × 3 | **~17.5 EB** |
| **Combined** | | | **~17.5 EB** (media dominates) |

### 7. Inbound Bandwidth
| Type | Calculation | Result |
|---|---|---|
| Text | 800K × 80% × 250B | **~160 MB/s** |
| Media | 800K × 20% × 1 MB | **~160 GB/s** |

> Media inbound is 1000× larger than text — media handling (compression, chunking, CDN offload) is critical.

### 8. Peak Concurrent Connections
- Concurrent users: 2B × 20% = 400M
- Each holds 1 persistent WebSocket connection
- **~400M concurrent connections**

> This is the defining infrastructure challenge of messaging apps — maintaining hundreds of millions of long-lived connections requires a connection gateway layer separate from the application servers.
