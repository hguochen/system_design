# Throttling Pattern

## what is it?
- a design pattern used to control the rate at which requests or operations are allowed in the system.
- helps prevent overload, ensure fair resource usage and maintain system stability. especially under high load or abuse.

## Core Idea
Throttling limits how often a system can be called, based on policies such as:
- requests per second
- concurrent users
- resource usage

## How does it work?
```
Client makes request
    ↓
Check current request count / tokens
    ↓
[Yes] → Allow → Process → Update counter
[No]  → Reject → Return HTTP 429 or queue
```

## Use Cases
- APIs receiving a high volume of requests(eg. public REST APIs)
- Preventing abuses such as search spamming, repeated login attempts
- Controlling load on limited backend resources
- Protecting downstream services or databases

## Common Throttling Strategies
| Strategy           | Description                                                                 |
|--------------------|-----------------------------------------------------------------------------|
| Fixed Window       | Limit requests per time window (e.g. 100 req/min)                           |
| Sliding Window     | Similar to fixed but smoother by using overlapping intervals                |
| Token Bucket       | Tokens are added at a rate, and each request consumes one. Bursts are allowed up to a bucket limit. |
| Leaky Bucket       | Requests are queued and processed at a fixed rate. Excess is dropped        |
| Concurrency Limit  | Limits the number of concurrent operations                                  |

## Benefits
- Protects resources from overload
- Prevents denial-of-service(intentional or accidental)
- Ensures fair usage across clients
- Improves quality of service by rejecting excess early

## Drawbacks
- May reject legitimate users under burst traffic
- Adds complexity to request handling
- Needs fine-tuning
    - too strict => underutilization
    - too loose = overload risk

## When to use it?
- Preventing system overload
    - stops a flood of requests from crashing services
- Protecting shared resources
    - limits how fast clients can hit expensive or rate-limited services
- Mitigating DDoS or brute-force attacks
    - Drops suspiciously high-volume traffic
- Protect downstream dependencies
    - Prevents cascading failures due to pressure on external systems

## When NOT to use it?
- when every requres is critical and must be served(eg. healthcare emergency alerts)
- when throttling might cause loss of critical business actions
- premature optimization
