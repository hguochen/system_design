# Practice 5 — Ride Sharing (e.g. Uber)

## Given Assumptions
- 20M daily active riders
- 5M active drivers at peak
- Each rider takes 1 trip/day on average
- Each driver sends a GPS location update every 4 seconds while active
- Average driver is active for 8 hours/day
- Trip record: `trip_id` (8B) + `rider_id` (8B) + `driver_id` (8B) + `start_location` (16B) + `end_location` (16B) + `start_time` (8B) + `end_time` (8B) + `fare` (8B)
- Location update record: `driver_id` (8B) + `lat` (8B) + `lng` (8B) + `timestamp` (8B)
- Trip data retained for 3 years
- Location updates retained for 30 days only
- Replication: 3×

## Your Task

Estimate all of the following. Show your working step by step. State any additional assumptions you make.

1. Trip write RPS
2. GPS location update write RPS
3. Trip record size
4. Location update record size
5. Total raw trip storage after 3 years
6. Total raw location update storage (30-day retention)
7. Total storage footprint (with replication)
8. Dominant write bandwidth source

---

## Answer Key

### 1. Trip Write RPS
- Trips/day: 20M
- Trip RPS: 20M / 10^5 = **200 trips/sec**

### 2. GPS Location Update Write RPS
- Active drivers: 5M
- Updates/driver/sec: 1 per 4s = 0.25/sec
- GPS RPS: 5M × 0.25 = **1,250,000 location updates/sec (1.25M/sec)**

### 3. Trip Record Size
- 8+8+8+16+16+8+8+8 = **80B**

### 4. Location Update Record Size
- 8+8+8+8 = **32B**

### 5. Total Raw Trip Storage (3 years)
- Trips: 20M/day × 365 × 3 = 21.9B trips
- Storage: 21.9B × 80B = 1,752 GB ≈ **~1.75 TB**

### 6. Total Raw Location Storage (30 days)
- Updates/day: 1.25M/sec × 10^5 = 125B updates/day
- 30 days: 125B × 30 = 3,750B updates
- Storage: 3,750B × 32B = 120,000 GB ≈ **~120 TB**

### 7. Total Storage Footprint
| Component | Raw | × Replication | Total |
|---|---|---|---|
| Trips (3 yr) | 1.75 TB | × 3 | ~5.25 TB |
| Location (30d) | 120 TB | × 3 | **~360 TB** |
| **Combined** | | | **~365 TB** (location dominates) |

### 8. Dominant Write Bandwidth
- GPS updates: 1.25M/sec × 32B = **~40 MB/s**
- Trip writes: 200/sec × 80B = ~16 KB/s (negligible)

> Key insight: GPS location updates are the dominant write load by several orders of magnitude — this drives the need for a write-optimised, time-series-friendly data store.
