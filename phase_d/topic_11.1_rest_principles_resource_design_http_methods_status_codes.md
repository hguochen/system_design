# 11.1 REST — Principles, Resource Design, HTTP Methods, Status Codes

> **Topic:** Topic 11 — API Design & Service Boundaries
> **Phase:** D — Networking Branch
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 3.1 (Stateless vs. Stateful Architecture), 3.5 (Idempotency)
> **Date studied:** 2026-08-10

---

## 0. 🧭 The Question This Answers

3.1 established that a stateless server treats every request as self-contained, with no session memory tying one request to the next. 3.5 established that some operations can be repeated safely and some can't, and that the difference is a property of the operation, not an accident of implementation. REST is what you get when you take both of those constraints seriously and build an entire API style around them: **every resource gets one address, every operation on it goes through a small fixed vocabulary of HTTP methods whose safety and idempotency are already standardized, and every outcome is reported through a status code the client didn't have to be taught.**

The tension is that an API is a promise to every client who will ever call it, present and future, and you cannot renegotiate that promise per client. The obvious move — invent whatever endpoints and response shapes feel natural for today's feature — produces an API that only the person who wrote it can predict. REST's bet is that borrowing HTTP's own semantics, which browsers, proxies, caches, and load balancers already understand, is cheaper and more durable than inventing your own.

**The question:** *Given a domain of things your system manages, how do you name them, and which verb-and-status-code pairs do you use to let a client that has never seen your API correctly predict how to create, read, update, and delete each one?*

> **→ Next:** Before naming the rules, what actually broke when APIs were built without them?

---

## 1. 🎯 Interview Quick Reference Card

> *Not a summary — a live-recall tool, built for retrieval speed under interview pressure. If you need the reasoning behind anything here, that's what §2 (cheatsheet) and the rest of the doc are for.*

**The checklist — walk this on the whiteboard, in order:**

1. Name the resource (the noun) — `/orders`, not `/createOrder`
2. Split collection vs. item — `/orders` (list, create) vs. `/orders/{id}` (read, update, delete)
3. Assign a method per operation — GET / POST / PUT / PATCH / DELETE
4. Define the status code for the success case AND every failure case, per method
5. Push filter/sort/search into query params on the same resource — never a new endpoint

**Trigger → action:**

| Interviewer says | You do |
|---|---|
| "Design the API for this" | Resource first, method second, status code third — never start with a verb |
| "What if the user doesn't exist?" | `404`. Not `400` (400 = malformed request, not "not found") |
| "What if it exists but isn't theirs?" | `404` (hide existence) or `403` (explicit deny) — pick deliberately, say why |
| "Double-click / duplicate submit?" | `Idempotency-Key` header on POST, checked + stored transactionally with the write |
| "New endpoint or a query param?" | Query param, if it's filtering/sorting/paging the SAME resource |
| "How do you version this?" | Defer to 11.5 — but name URI vs. header versioning as the two options |

**Fast disambiguation — the pairs that get confused live:**

| Pair | The distinction |
|---|---|
| Safe vs. idempotent | Safe = no state change at all (GET). Idempotent = N calls leave the same end state as 1 (PUT, DELETE) — but the state DID change on the first call. Different axes. |
| PUT vs. PATCH | PUT = full replacement, omitted fields get nulled. PATCH = only touches fields present in the body. |
| 401 vs. 403 | 401 = not authenticated, go log in. 403 = authenticated, but never allowed — don't retry with new credentials. |
| 404 vs. 403 (privacy) | Return 404 instead of 403 when you don't want to confirm the resource exists at all. |
| 409 vs. 422 | 409 = conflicts with CURRENT STATE (concurrent edit) → retry after refetch. 422 = invalid regardless of state → fix the payload. |

**Status codes, one line each:**

```
2xx  200 OK · 201 Created (+Location) · 202 Accepted (async) · 204 No Content
3xx  301 Moved Permanently · 304 Not Modified (ETag)
4xx  400 malformed · 401 no auth · 403 forbidden · 404 not found · 409 conflict
     · 422 invalid · 429 rate limited
5xx  500 internal · 502 bad gateway · 503 unavailable · 504 timeout
```

**The script — say this close to verbatim:**

> "I'd model this as a resource — `/orders` as the collection, `/orders/{id}` for a single order — rather than action-style endpoints, so a client only has to learn the method vocabulary once and it applies everywhere. Creating an order is `POST /orders`, returning `201 Created` with a `Location` header. For duplicate submits, POST isn't idempotent by default, so I'd require a client-generated `Idempotency-Key` header — the same mechanism Stripe uses. Reading an order is `GET /orders/{id}`, returning `404` if it doesn't exist and `403` if it exists but belongs to someone else — different failures, different codes. The cost is that a client needing several resources in one screen still needs multiple round trips or a purpose-built aggregation endpoint; I'd only reach for GraphQL if that pattern repeated across many screens."

**If pushed on idempotency-key mechanics specifically:**
> Key + result must be stored in the SAME transaction as the write. Retry looks up the key BEFORE creating anything: found + completed → return the stored response verbatim; found + in-progress → don't race it, return 409/425 or wait; not found → proceed and record transactionally.

---

## 2. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §3 and come back here for revision.

```
§ 1  WHY IT EXISTS
RPC-style APIs (getUser, updateUserEmail, deleteUserAccount) work fine for one
team, one client, one week. They stop working as an API surface, because
every verb is bespoke: nothing about the name tells you whether it's safe to
retry, whether it can be cached, or what "success" looks like — every client
has to read the docs (or the source) for every single endpoint. REST's fix is
to stop inventing verbs and instead map your domain onto HTTP's own, already-
standardized vocabulary: a fixed set of methods with known safety/idempotency/
cacheability properties, and a fixed set of status codes with known meaning.
The API surface shrinks from "one convention per endpoint" to "one convention,
applied consistently."

§ 2  WHAT IT IS
RESOURCE            A noun in your domain — a user, an order, a link — addressed
                    by a URI. Not a verb, not an action.
COLLECTION vs. ITEM  /orders is a collection; /orders/{id} is one item in it.
                    Same noun, two granularities, two different valid method sets.
UNIFORM INTERFACE    The core REST constraint: every resource, no matter its
                    domain, is manipulated through the SAME small set of HTTP
                    methods — not a bespoke method per resource.
SAFE                Doesn't change server state (GET, HEAD, OPTIONS).
IDEMPOTENT          N identical requests = the same server state as 1 request
                    (GET, PUT, DELETE — but NOT POST, and NOT always PATCH).

§ 3  THE MECHANISM
NAME THE RESOURCE    Nouns, plural collections: /orders not /getOrders.
PICK THE METHOD      GET reads, POST creates (non-idempotent), PUT replaces
                    wholesale (idempotent), PATCH updates partially, DELETE
                    removes (idempotent).
PICK THE STATUS CODE  2xx = it worked, 3xx = go elsewhere, 4xx = YOU (the
                    client) did something the server won't honor, 5xx = the
                    SERVER failed, not you. The class must match who's at fault.
STAY STATELESS       No server-side session; every request carries everything
                    needed to process it (auth token, pagination cursor, etc.)
                    — this is 3.1's constraint, and it's what makes horizontal
                    scaling and edge caching of a REST API possible at all.

§ 4  USE / AVOID
USE PUT when: the client sends the full resource representation and the
  operation is naturally idempotent (replace-in-place).
USE PATCH when: the client sends only the fields that changed.
USE POST when: creating a new resource whose URI the server assigns, or for
  a genuinely non-idempotent action with no natural resource identity.
AVOID verbs in the URL (/createOrder, /getUserById) — that's RPC wearing a
  REST costume; the method (POST/GET) already carries the verb.
AVOID returning 200 OK with `{"success": false}` in the body — this is the
  single most common REST anti-pattern; the status code IS the outcome.
AVOID nesting resources more than ~2 levels deep (/orders/{id}/items is fine;
  /orders/{id}/items/{id}/reviews/{id}/comments is not — flatten with a
  top-level resource + filter instead).

§ 5  STATUS CODE TAXONOMY
2xx  200 OK · 201 Created (+Location header) · 202 Accepted (async, not done
     yet) · 204 No Content (success, empty body — typical for DELETE/PUT)
3xx  301 Moved Permanently · 304 Not Modified (conditional GET via ETag —
     the cache-validation payoff of statelessness)
4xx  400 Bad Request (malformed) · 401 Unauthorized (no/bad credentials) ·
     403 Forbidden (authenticated, but not allowed) · 404 Not Found ·
     405 Method Not Allowed · 409 Conflict (concurrent write collision) ·
     422 Unprocessable Entity (well-formed, semantically invalid) ·
     429 Too Many Requests (rate limited)
5xx  500 Internal Server Error · 502 Bad Gateway · 503 Service Unavailable
     (often WITH a Retry-After header) · 504 Gateway Timeout
THE RULE: 4xx = client's fault, fix the request. 5xx = server's fault, retry
  later (ideally with backoff). Never blur that line to avoid admitting a bug.

§ 6  NUMBERS TO ANCHOR THE DISCUSSION
GET/HEAD/OPTIONS are safe AND idempotent. PUT/DELETE are idempotent but NOT
  safe (they change state). POST is neither. PATCH is neither, by default,
  though a specific PATCH body CAN be written to be idempotent.
Stripe's idempotency key: a client-generated key on POST, honored for 24
  hours — this is 3.5's idempotency retrofitted onto the one REST method
  that doesn't get it for free.
RFC 9110 (HTTP Semantics, obsoletes 7231) defines the methods and status
  codes; RFC 5789 defines PATCH; RFC 7807 / 9457 defines the "problem
  details" JSON error body shape.
GitHub's REST API paginates via the `Link` header (`rel="next"`) rather than
  a body field — pagination metadata living in HTTP, not your JSON schema.

§ 7  INTERVIEW TRIGGERS + GOTCHA
→ "Design the API for this system"              → resources first, methods
                                                    second, status codes third
→ "What would you return if the user doesn't    → 404, and know WHY not 400
   exist?"                                         (400 = malformed request,
                                                    not "doesn't exist")
→ "How do you handle a duplicate submit /       → idempotency key on POST,
   double-click on this create endpoint?"          or make it PUT if you can
→ "Should this be a new endpoint or a query      → query param, if it's
   parameter?"                                     filtering/sorting the
                                                    same resource
GOTCHA: Treating "idempotent" and "safe" as the same property. PUT is
  idempotent but NOT safe — calling it once vs. one thousand times leaves
  the SAME end state, but it still changed something on the first call. GET
  is both. Confusing the two is the fastest way to look like you memorized
  a table instead of understanding it.
```

---

## 3. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                          ┌──────────────────────────────────┐
                          │      REST — API DESIGN            │
                          │  "one address per resource, one   │
                          │   fixed vocabulary to act on it"  │
                          └──────────────────┬─────────────────┘
                                             │
   ┌────────────────┬────────────────────────┼────────────────────┬────────────────┐
   ▼                ▼                        ▼                    ▼                ▼
THE PRINCIPLES   RESOURCE DESIGN         HTTP METHODS         STATUS CODES     REAL SYSTEMS
├ client-server  ├ nouns, not verbs     ├ GET — safe,        ├ 2xx success    ├ Stripe —
├ stateless      │  /orders not          │  idempotent,        (200/201/       idempotency
│  (3.1)         │  /getOrders           │  cacheable          202/204)        keys
├ uniform        ├ collection vs. item  ├ POST — unsafe,     ├ 3xx redirect   ├ GitHub —
│  interface      │  /orders vs.          │  NOT idempotent,    (301/304)       Link header
│  (the core      │  /orders/{id}         │  creates          ├ 4xx client     pagination
│   constraint)   ├ nest ≤ 2 levels      ├ PUT — idempotent,   fault (400/    ├ Shopify —
├ cacheable       ├ query params for      │  full replace       401/403/404/    leaky-bucket
│  (via headers)  │  filter/sort/search  ├ PATCH — partial,    409/422/429)     rate limits
└ layered system  └ plural, consistent    │  not always        └ 5xx server    ├ Google AIP —
  ⚠ HATEOAS —       casing                 │  idempotent          fault (500/     standard +
    rarely built                         └ DELETE —              502/503/504)   custom methods
    in practice                            idempotent          ⚠ never 200     └ Richardson
                                          ⚠ safe ≠ idempotent    with an          Maturity Model
                                            — different axes     error body       — grades "how
                                                                                    RESTful"
```

**How to read it:** **the principles** are the constitution — everything else is a consequence of taking statelessness and the uniform interface seriously. **Resource design** is the noun layer: what you name and how you shape the URI space. **HTTP methods** are the verb layer: the fixed vocabulary the uniform interface promises, each with a specific safety/idempotency/cacheability signature. **Status codes** are the outcome layer: how the server reports what the verb did, with the 4xx/5xx boundary encoding whose fault it was. **Real systems** are where you check your design instincts against APIs that get paid to be right.

---

## 4. 🔥 The Problem

Before REST hardened into a convention, most HTTP APIs were RPC dressed up in a browser-friendly transport: `/getUser?id=42`, `/updateUserEmail`, `/deleteUserAccount`. Each endpoint was a bespoke function call, and functionally this works — you can build a complete product on it. The trouble shows up the moment more than one person, or one client, has to use the API without asking the author questions. Nothing about `/updateUserEmail` tells a caller whether retrying it after a timeout is safe, whether a proxy is allowed to cache the response, or what the response shape looks like on failure versus success — because none of that is standardized, it's whatever the author happened to do that day. Multiply this across fifty endpoints written by different engineers over two years, and the API becomes a pile of one-off conventions that only the docs (if they're current) can decode.

The instinctive first fix is "let's just agree on conventions as a team" — a style guide, a wiki page, code review discipline. This helps, but it doesn't survive scale for a specific reason: a convention that lives in a wiki is not enforced by anything, so it decays the moment the person who wrote it stops reviewing every PR. It also doesn't help external consumers at all — a third-party developer integrating with your API has no way to know your team's internal wiki exists, let alone what it says. The convention needs to live somewhere a caller can rely on without reading your source: the protocol itself.

That's the insight REST is built on. HTTP already has a small, standardized vocabulary of methods, each with a documented safety and idempotency contract, and a standardized set of status codes with documented meaning — and every HTTP-aware piece of infrastructure (browsers, CDNs, load balancers, proxies, curl) already understands them. Instead of inventing a bespoke contract per endpoint, REST maps your domain onto resources (nouns) and lets HTTP's existing verbs and status codes carry the semantics that used to live in ad hoc function names and undocumented response shapes. A client who has learned "GET is safe, POST creates, 404 means it's not there, 409 means someone else changed it first" can now predict the behavior of an endpoint they have never called.

**Before and after:**

```
  BEFORE — one bespoke verb per action        AFTER — resources + uniform interface
  ───────────────────────────────────────     ─────────────────────────────────────
   POST /getUser?id=42                          GET /users/42
   POST /createUser                             POST /users
   POST /updateUserEmail                        PATCH /users/42
   POST /deleteUserAccount                      DELETE /users/42
   POST /listUsersByStatus?status=active        GET /users?status=active

   ✓ works for the team that wrote it           ✓ retry safety is KNOWN, not
   ✗ retry safety unknowable from the name          guessed — from the method alone
   ✗ caching impossible — everything is POST     ✓ GET is cacheable by default,
   ✗ every response shape is bespoke,               proxies/CDNs already know this
     success or failure                          ✓ one response-shape convention,
   ✗ new consumer must read source or docs          reused across every resource
     for every single endpoint                   ✓ a caller who's never seen this
                                                     API can predict its shape
```

### ✅ Checkpoint

1. A teammate argues: "We already have a wiki page documenting our endpoint conventions — isn't that the same protection REST gives us?" Explain precisely what's missing, using the distinction between a convention enforced by the protocol versus one enforced by team discipline.

   > 💡 *If you hesitate, re-read the second paragraph — the part about what a wiki page does and doesn't survive.*

> **→ Next:** If the fix is to borrow HTTP's own vocabulary, what exactly does that vocabulary consist of, and how do the pieces build on each other?

---

## 5. 💡 The Core Idea

**REST is the discipline of modeling your domain as addressable resources (nouns) and manipulating every one of them through the same small, standardized set of HTTP methods and status codes — trading the flexibility of a bespoke API surface for the predictability of a uniform one.**

**Visual required:** build-chain diagram.

```
 [RESOURCES, NOT ──▶ [THE UNIFORM ──▶ [STATUS CODES ARE ──▶ [STATELESSNESS
  ACTIONS]            INTERFACE]       THE CONTRACT]          MAKES IT ALL WORK]
   because a noun      therefore every   so the outcome of     which means every
   can be addressed    resource is       every method call     request self-
   once and acted      manipulated       is reported through   describes, so the
   on repeatedly        through the       a vocabulary the      uniform interface
                        SAME small        client already        can be cached and
                        verb set          knows                 scaled horizontally
```

### Resources, Not Actions

Everything starts with naming: a resource is a noun in your domain — a user, an order, a link, a message — addressed by a single URI, not a verb describing an action. `/orders` names a *collection* of orders; `/orders/{id}` names one *item* within it, and the same noun supports both granularities at different specificity. This single shift is what separates REST from RPC: instead of `createOrder`, `getOrder`, `cancelOrder` as three unrelated function names, you have one resource, `/orders`, and three different HTTP methods applied to it. Naming conventions follow from this directly — plural collection names (`/orders`, not `/order`), lowercase and hyphenated (not camelCase) paths, and nesting kept shallow: `/orders/{id}/items` is a legitimate one-level nesting (items genuinely belong to an order), but `/orders/{id}/items/{id}/reviews/{id}/comments` should be flattened into a top-level `/comments?item_id=...` resource instead, because deep nesting couples every client to your internal ownership hierarchy.

### The Uniform Interface

Once resources are nouns, the uniform interface is the promise that *every* resource, regardless of domain, is manipulated through the *same* fixed set of HTTP methods — not a bespoke method per resource. `GET` reads without changing anything. `POST` creates a new resource whose URI the server typically assigns, or triggers a genuinely non-idempotent action. `PUT` replaces a resource wholesale with the representation the client sends. `PATCH` applies a partial update. `DELETE` removes it. This is the single biggest leverage point in REST: a client that understands these five verbs in the abstract can correctly guess the behavior of an endpoint on a resource it has never seen before, because the verb's meaning doesn't change per resource.

### Status Codes Are the Contract

The uniform interface tells you *what you did*; the status code tells you *what happened*. This is where safety and idempotency (3.5) become externally visible: the response has to communicate not just success or failure, but which category of failure, because a client's correct reaction differs completely between "retry me" and "don't ever retry me with the same input." `2xx` means it worked, `3xx` means look elsewhere, `4xx` means the fault is in the request the client sent, `5xx` means the fault is on the server and the client did nothing wrong. Getting this class right is not bikeshedding — a client's retry logic, its error UI, and its logging pipeline all branch on this exact classification, and a misclassified code (returning `500` for a validation failure, say) actively breaks automated retry behavior for every consumer of the API.

### Statelessness Makes It All Work

None of the above holds together without 3.1's constraint: no session lives on the server between requests. Every request must carry everything needed to process it — an auth token, a pagination cursor, the full intent of the call — because the server is not allowed to remember the previous one. This is what makes a `GET` response cacheable by an intermediary that has never talked to your application server directly: the response only depends on the request itself, not on some hidden server-side state the cache can't see. It's also what makes REST APIs horizontally scalable behind a plain load balancer with no sticky sessions (3.1's own payoff) — any server can answer any request, because no server is privileged with memory of what came before.

### ✅ Checkpoint

1. Explain why `PATCH` is the method most likely to be *accidentally* non-idempotent, using a concrete example of a PATCH body that breaks idempotency and one that doesn't.

   > 💡 *If you hesitate, re-read "The Uniform Interface" and think about what a PATCH body can contain besides literal field values.*

2. A teammate proposes `POST /orders/{id}/cancel` instead of a `PATCH /orders/{id}` that sets `status: "cancelled"`. Using the build chain above, explain what's actually being traded, and say whether this is a violation of REST or a legitimate design choice.

   > 💡 *If you hesitate, trace the build chain from RESOURCES, NOT ACTIONS through STATUS CODES ARE THE CONTRACT — the answer is about whether "cancel" has a legitimate resource-state reading.*

> **→ Next:** You know the vocabulary. What actually happens, endpoint by endpoint, when you sit down to design one?

---

## 6. ⚙️ How It Actually Works

**Happy path — designing an endpoint:**

1. Identify the resource: what noun does this represent, and does it live at the top level (`/orders`) or nested under a parent it's genuinely owned by (`/orders/{id}/items`)?
2. Decide collection vs. item operations: `GET /orders` (list, paginated) and `POST /orders` (create) live on the collection; `GET/PUT/PATCH/DELETE /orders/{id}` live on the item.
3. For each method the resource supports, define the success status code (`201` + `Location` header for creation, `200` for a read/update that returns a body, `204` for a delete or an update with no body to return) and every plausible failure status code (`404` if the item doesn't exist, `409` if a concurrent write conflicts, `422` if the body is well-formed JSON but violates a business rule).
4. Decide what's a *new resource* versus a *query parameter* on an existing one: filtering, sorting, and pagination (`GET /orders?status=pending&sort=-created_at&cursor=...`) are the same resource, narrowed — not a new endpoint per filter combination.
5. Shape the error body consistently across every endpoint (RFC 7807/9457 "problem details" is the standard convention: `{"type", "title", "status", "detail"}`), so a client's error-handling code doesn't branch per endpoint.

> 🗺️ **Mental model — the library checkout desk.** A library doesn't invent a new procedure for every book; every book (resource) has one call number (URI), and the desk offers the same fixed set of actions on any of them — check out (create a loan, `POST`), look up (`GET`), renew in place (`PUT`/`PATCH`), return (`DELETE`). You don't need to ask the librarian how "checking out" works differently for a specific book; the procedure is uniform across the entire catalog. *Where it breaks down:* a librarian can use judgment on an edge case ("this book is reference-only, no checkout"); a REST API has to encode that judgment explicitly as a status code (`403`) rather than relying on a human to notice.

**Failure & edge cases:**

- **The "always 200" anti-pattern.** A team under deadline pressure starts returning `200 OK` for every response and putting `{"success": false, "error": "..."}` in the body for failures. This defeats HTTP-aware infrastructure entirely — a caching proxy will happily cache a `200` error response, load balancer health checks and automated monitoring stop being able to distinguish real failures from successes without parsing every response body, and every client has to implement bespoke error detection instead of checking the status code.
- **PUT used as a partial update.** A client sends `PUT /users/42` with only the changed fields, expecting the rest to be left alone. PUT's contract is *full replacement* — a compliant server implementation nulls out every field the client didn't include, silently destroying data the client never intended to touch. This is a PATCH use case wearing PUT's method name.
- **409 vs. 422 confusion.** A `409 Conflict` means the request is fine in isolation but collides with the *current state* of the resource (two users editing the same order simultaneously, an optimistic-lock version mismatch). A `422` means the request itself is semantically invalid regardless of current state (an end date before a start date). Conflating them tells the client the wrong thing to do next: retry-after-refetch (`409`) versus fix-the-payload (`422`).
- **Pagination drift under concurrent writes.** Offset-based pagination (`?page=2&limit=20`) shifts under you if rows are inserted or deleted between page fetches — a client can see the same item twice or skip one entirely. Cursor-based pagination (`?cursor=<opaque_token>`, referencing a stable sort key like an ID or timestamp) avoids this because each cursor is anchored to a specific row, not a row *count*.

**The design pipeline, end to end:**

```
① identify        ──▶ ② split into      ──▶ ③ assign method  ──▶ ④ define status
   the resource        collection vs.        per operation         code per method
   (the noun)          item URIs                                   × outcome
                                                                          │
                                                                          ▼
                                              ⑤ filters/sort/page   ──▶  DONE —
                                                 as query params          consistent
                                                 on the SAME resource,    error body
                                                 never a new endpoint     shape across
                                                                          every endpoint
```

**HTTP method properties, structurally:**

```
  METHOD    SAFE?      IDEMPOTENT?          CACHEABLE?      PURPOSE
  ┌───────┬──────────┬────────────────────┬──────────────┬─────────────────────┐
  │ GET    │  YES      │  YES               │  YES (default)│  read a resource     │
  │ HEAD   │  YES      │  YES               │  YES          │  read headers only   │
  │ OPTIONS│  YES      │  YES               │  NO           │  discover allowed    │
  │        │           │                    │               │  methods / CORS      │
  ├───────┼──────────┼────────────────────┼──────────────┼─────────────────────┤
  │ POST   │  NO       │  NO (by default)   │  NO (rare)    │  create; non-idempo- │
  │        │           │  → fixable with an │               │  tent action         │
  │        │           │    idempotency key │               │                      │
  │ PUT    │  NO       │  YES               │  NO           │  replace wholesale   │
  │ PATCH  │  NO       │  NOT GUARANTEED    │  NO           │  partial update      │
  │        │           │  → depends on the  │               │                      │
  │        │           │    body semantics  │               │                      │
  │ DELETE │  NO       │  YES               │  NO           │  remove              │
  └───────┴──────────┴────────────────────┴──────────────┴─────────────────────┘

  THE TRAP: "safe" and "idempotent" are DIFFERENT axes. GET is both. PUT and
  DELETE are idempotent but NOT safe — they change state, but calling them
  1 time or 100 times leaves the SAME end state. Collapsing the two into one
  property is the single most common REST misconception.
```

### ✅ Checkpoint

1. Walk through exactly what happens to a `users` row if a client sends `PUT /users/42` with a body containing only `{"email": "new@example.com"}`, omitting the `name` and `phone` fields that were previously set. Explain why this is a design bug and what the client should have sent instead.

   > 💡 *If you hesitate, re-read the "PUT used as a partial update" failure case.*

2. A client polls `GET /orders?page=3&limit=20` while other users are actively creating and cancelling orders. Explain precisely how it can end up seeing the same order twice across two page fetches, and name the specific pagination scheme that avoids it.

   > 💡 *If you hesitate, re-read the "Pagination drift" failure case and the difference between anchoring on a row count versus a row identity.*

> **→ Next:** You can design and build an endpoint correctly. In a live design, which choices do you actually defend, and what do they cost?

---

## 7. ⚖️ The Decision — When, and What It Costs

The default for a CRUD-shaped API — the majority of internal admin tools, most public product APIs, most resource-oriented backends — is resource-oriented REST over HTTP with JSON bodies, and you should be able to say so without hedging. It has the largest tooling ecosystem of any API style, every HTTP-aware piece of infrastructure (CDNs, browsers, proxies, API gateways, curl) already speaks it, and a human can debug it by reading a URL and a status code without special tooling. You leave that default at specific, nameable boundaries, and each boundary points toward one of REST's alternatives (covered in depth in 11.2 and 11.3, but worth naming here as the edges of REST's territory).

**The client needs to shape exactly which fields it gets, across multiple resources, in one round trip.** REST's resource shape is fixed by the server — a mobile client that only needs a user's name and avatar still gets the full user object, and a client that needs a user *and* their last five orders has to make two round trips (or you build a bespoke aggregation endpoint, which is REST quietly re-inventing RPC). This is REST's over-fetching/under-fetching problem, and it's the entire reason GraphQL (11.3) exists.

**The call is internal, high-fanout, and latency-sensitive service-to-service traffic, not a public or browser-facing surface.** JSON-over-HTTP/1.1's text parsing and per-request overhead cost real latency and CPU at high call volume between your own services. gRPC (11.2) trades REST's human-readability and universal tooling for a binary wire format and code-generated clients, and is a common choice for the service mesh, not the public edge.

**The resource genuinely has no natural CRUD shape.** Some operations are actions with real side effects, not state transitions on a single resource (`POST /payments/{id}/refund` triggering a multi-system workflow). REST tolerates this via action-style POST endpoints, but if the majority of your API looks like this, resource modeling has stopped paying for itself and you may be looking at an RPC-shaped problem that REST is being forced onto.

**Decision tree:**

```
              What does the client actually need from this call?
                                   │
     ┌─────────CRUD on a well-defined resource─────┼───needs exact field shape
     │                                              │   across several resources
     ▼                                              │                          ▼
  RESOURCE-ORIENTED REST.                           │                 GraphQL (11.3).
  JSON over HTTP. Default.                          │                 Accept added
  Human-debuggable, huge                            │                 complexity for
  tooling, cacheable by                              ▼                query flexibility.
  proxies/CDNs for free.              Is this call internal,
                                       high-fanout, service-to-
                                       service, latency-sensitive?
                                              │
                                    ┌────no────┴────yes────┐
                                    ▼                       ▼
                          Stick with REST.          gRPC (11.2). Binary,
                          Public/browser-facing      code-generated,
                          traffic wants HTTP's        streaming — pay
                          ubiquity, not raw           setup cost for
                          throughput.                 raw performance.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **Cacheable by default via HTTP semantics** — GET responses can be cached by proxies/CDNs with zero application code, using standard headers (`Cache-Control`, `ETag`) | The resource shape is fixed server-side; a client needing a different shape either over-fetches (wastes bandwidth) or under-fetches (needs N follow-up calls) — REST has no native way to let the client specify exactly which fields it wants |
| **Universal tooling and human debuggability** — curl, browser dev tools, every API gateway and load balancer already understands HTTP methods and status codes with zero custom integration | Chatty for deeply related data — fetching a resource and its nested relations often means multiple round trips (or a bespoke aggregation endpoint that quietly breaks the uniform-interface promise) |
| **Versionable and evolvable at the URI or header level** without breaking clients who don't opt in (deep dive in 11.5) | No native support for streaming or bidirectional communication — a REST endpoint is fundamentally request/response, so real-time or long-lived connections need a different protocol layered alongside it (WebSockets, SSE — Topic 13) |
| **Statelessness (3.1) gives you free horizontal scaling** — any server behind the load balancer can answer any request, no sticky sessions or shared session store required | JSON-over-text has real serialization and parsing overhead compared to a binary format, which matters at high internal service-to-service call volume even though it rarely matters at the public edge |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Stripe** | Textbook resource modeling (`/customers`, `/charges`, `/subscriptions`), plus a client-supplied `Idempotency-Key` header honored for 24 hours on POST | This is 3.5's idempotency retrofitted onto the one uniform-interface method that doesn't get it for free — POST is inherently non-idempotent, so Stripe adds an explicit mechanism rather than pretending the problem doesn't exist |
| **GitHub REST API** | Pagination metadata lives in the `Link` response header (`rel="next"`, `rel="last"`), not in the JSON body | Keeps pagination out of your response schema entirely — it's HTTP infrastructure, not application data, which is exactly the statelessness argument applied to a concrete design choice |
| **Shopify** | Leaky-bucket rate limiting communicated via response headers, with `429 Too Many Requests` and a `Retry-After` value when exceeded | The status code alone isn't enough — a well-designed 429 response tells the client exactly how long to back off, rather than leaving it to guess-and-retry |
| **Google API Improvement Proposals (AIPs)** | Standard methods (`List`, `Get`, `Create`, `Update`, `Delete`) map directly onto REST's GET/POST/PATCH/DELETE, plus explicitly-named "custom methods" (`:cancel`, `:batchGet`) for actions that don't fit CRUD | An explicit, documented escape hatch for the "genuinely an action, not a state transition" case from the decision rule above — rather than silently abusing PATCH or inventing ad hoc verbs |
| **Richardson Maturity Model** | A framework (levels 0–3: single endpoint/RPC → resources → HTTP verbs → HATEOAS) for grading how RESTful an API actually is | Most production APIs — including Stripe's and GitHub's — deliberately stop at level 2 (resources + verbs + status codes) and skip HATEOAS (level 3, hypermedia links driving client navigation); this is a legitimate, load-bearing engineering choice, not an incomplete implementation |

### ✅ Checkpoint

1. A team is designing an internal API that a mobile app will call directly to render a dashboard requiring a user's profile, their last 10 orders, and each order's shipment status — three logically separate resources in one screen. Using the decision tree above, would you reach for plain REST, and if not, what would you actually do? Justify against the specific cost you'd be accepting either way.

   > 💡 *If you hesitate, re-read the first boundary condition — the client needing an exact field shape across multiple resources — and the trade-off row about chatty nested data.*

> **→ Next:** Can you defend this under interview pressure — and hold up when the interviewer pushes on the cost you claimed you'd pay?

---

## 8. 🎯 In the Interview

**When an interviewer asks / says:**
- "Design the API for this system — what would the endpoints look like?"
- "What status code would you return if the user tries to fetch an order that doesn't exist / belongs to someone else?"
- "How would you handle someone double-clicking submit on this create-order button?"
- "Should this be a new endpoint, or a parameter on the existing one?"

**What you say / do:**
This lands immediately after the data model in the high-level design phase, right as you sketch endpoints on the whiteboard — and it resurfaces hard in the deep dive the moment the interviewer asks about a specific edge case (duplicate submits, concurrent edits, a resource that doesn't exist). Lead with the resource, not the verb: name the noun, then walk through which HTTP methods it supports and why, then the status codes each one can return. Never present an endpoint as `POST /doSomething` without first asking yourself what resource it's actually operating on.

**The trade-off statement (memorize this pattern):**
> "I'd model this as a resource — `/orders` as the collection, `/orders/{id}` for a single order — rather than action-style endpoints, so a client only has to learn the method vocabulary once and it applies everywhere. Creating an order is `POST /orders`, returning `201 Created` with a `Location` header pointing at the new resource. For the double-click case specifically, POST isn't idempotent by default, so I'd require a client-generated `Idempotency-Key` header — the same mechanism Stripe uses — and the server rejects or short-circuits a duplicate key within a bounded window instead of creating two orders. Reading an order is `GET /orders/{id}`, returning `404` if it doesn't exist and `403` if it exists but belongs to someone else — those are different failures with different client reactions, so I keep them as different codes rather than collapsing both into a generic error. The cost of this approach is that a mobile client rendering a dashboard across several resources still needs multiple round trips or a purpose-built aggregation endpoint; I'd only reach for something like GraphQL if that pattern repeated across many screens with genuinely different field needs, not for one fixed layout."

### ⚠️ Traps

- ❌ **Trap:** "I'd just use POST for everything, it's simpler and I don't have to think about which verb applies."
  ✅ **Reality:** This throws away the entire point of the uniform interface — safety, idempotency, and cacheability all become unknowable from the outside, and every caching proxy, retry policy, and monitoring tool in the request path loses the ability to reason about the call. "Simpler for me to write today" and "predictable for every future caller" are different goals, and REST optimizes for the second.

- ❌ **Trap:** "Return 200 OK with `{success: false}` in the body — that way the client always gets the same top-level shape."
  ✅ **Reality:** This is the single most common REST anti-pattern. It defeats every piece of HTTP-aware infrastructure that reasons about status codes — caches will cache the "failure," monitoring can't distinguish real errors from successes without parsing bodies, and automated retry logic that correctly backs off on 5xx will retry a "success" response forever. The status code IS the outcome; don't duplicate it inconsistently in the body.

- ❌ **Trap:** "404 and 401 are basically the same thing when the resource doesn't exist for this user — just return whichever is easier."
  ✅ **Reality:** They tell the client to do completely different things. 401 means "you're not authenticated at all, go log in." 403 means "you're authenticated, but not allowed — don't retry with different credentials, you'll never be allowed." 404 means "this doesn't exist" — and is often deliberately returned instead of 403 for another user's private resource, specifically to avoid leaking that the resource exists at all. Which one you pick is a real security and UX decision, not a coin flip.

- ❌ **Trap:** "PUT and PATCH are basically interchangeable, I'll just use whichever one I remember."
  ✅ **Reality:** PUT replaces the entire resource; a client that sends a partial PUT body silently nulls out every field it omitted. PATCH updates only what's present in the body. Using PUT for a partial update is a data-loss bug waiting for the first client that doesn't send every field.

### ✅ Checkpoint — adversarial stress test

1. You've designed `POST /orders` with a client-generated `Idempotency-Key` header to handle duplicate submits. The interviewer pushes: *"Your mobile client is on a flaky connection. It sends the POST, the server creates the order and starts writing the response, and the connection drops before the client receives it. The client, seeing a timeout, retries with the SAME idempotency key. Walk me through exactly what the server needs to have stored, and at what point in the original request's lifecycle, for the retry to return the correct result instead of either creating a second order or hanging."*

   > 💡 *This is the gate. A complete answer covers: the idempotency key and its result must be persisted transactionally WITH the order creation itself (same transaction or a durable, atomically-committed record), not as an afterthought written after the response is sent — otherwise a crash between "order created" and "key recorded" reintroduces the duplicate. It covers the retry path: look up the key BEFORE attempting creation; if found with a completed result, return that stored result (same status code, same body) rather than re-executing the creation logic; if found but still in-progress (the original request hasn't finished), the retry should NOT proceed concurrently — it needs to either wait or return a 409/425-style "still processing" response, because letting both requests race is exactly the concurrent-duplicate bug the key was supposed to prevent. If you can't answer this cleanly, you are not done.*

MODEL ANSWER — §8 Adversarial Stress Test (idempotency-key retry race)

THE THREE-STATE KEY, NOT TWO
  A naive design treats the key as binary (exists / doesn't exist).
  The scenario specifically breaks that: the key must carry a STATE —
  "in-process" or "completed(+result)" — not just presence/absence.

WHEN THE KEY GETS WRITTEN
  "in-process" is written to the store at the START of the first
  request, BEFORE order creation runs — not after. This is what
  closes the race: if it were written only after the order is
  created, two near-simultaneous retries could both see "not found"
  and both create an order before either finishes. Writing the
  marker first means the second request always finds SOMETHING to
  react to.

THE RETRY PATH, BY STATE
  - Key not found          → new request, proceed to create the order
  - Key = "in-process"     → an identical request is already running;
                              do NOT proceed concurrently — block/poll
                              until it resolves, or return a
                              409/425 "still processing" response
  - Key = "completed" + result → return the STORED result verbatim
                              (same status code, same body) instead
                              of re-running creation logic

WHY THIS SURVIVES THE EXACT SCENARIO
  Server creates the order, then updates the key from "in-process" to
  the completed result — the connection dropping is a CLIENT-side
  event; server-side processing runs to completion regardless. The
  retry arrives, finds "completed," and returns the already-computed
  result. No duplicate order, no hang.

REMAINING EDGE CASE (worth knowing, not required for the gate)
  If the server crashes between "order created" and updating the key
  to "completed," the key is stuck at "in-process" forever (or until
  TTL). A blocking retry with no timeout hangs indefinitely. A more
  complete design adds a timeout on the wait, and/or a reconciliation
  check against the orders table itself if the key stays in-process
  past a bounded window.

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 9. 🧪 Mastery Gate

> *Synthesis only. Each question must require combining two or more sections.*

1. **(§5 + §6 + 3.1)** A junior engineer argues that adding a server-side session (storing the last resource a client viewed, to support a "back" navigation shortcut) is a minor, harmless addition to an otherwise REST-compliant API. Using the build chain from §5 and the caching mechanics from §6, explain everything that specifically breaks once that session exists — not in the abstract, but naming the concrete infrastructure behavior that stops working.

2. **(§7 + §8, applied to a system not mentioned elsewhere in this doc)** You're designing the API for a real-time collaborative document editor (think Google Docs) where two users can edit overlapping sections of the same document within seconds of each other. Decide how PUT, PATCH, and status codes (specifically around conflict handling) apply to a document's content field, and justify why plain last-write-wins PUT semantics are or are not acceptable here.

3. **(§4 + §6 + §8)** An interviewer asks you to design pagination for an infinite-scroll social feed where new posts are inserted at the top constantly, and the client is expected to keep scrolling for tens of thousands of posts across a long session. Explain why naive offset pagination fails here specifically (not generically), and design the cursor scheme that avoids it — including what the cursor is anchored to and why.

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can design a resource-oriented URI structure (collections, items, nesting depth, query params for filter/sort/search) for a novel domain
- [ ] Can correctly assign HTTP methods to CRUD operations and explain each method's safe/idempotent/cacheable properties without confusing safe and idempotent
- [ ] Can select the correct status code for a given outcome, including the 4xx-vs-5xx fault-attribution boundary and the 409-vs-422 and 401-vs-403 distinctions
- [ ] Can design pagination (cursor vs. offset) and explain precisely why offset pagination fails under concurrent writes
- [ ] Can explain why statelessness is a precondition for HTTP-level caching and horizontal scaling of a REST API, not an unrelated constraint
- [ ] Can name the boundary conditions where REST stops being the right default and gRPC or GraphQL become the better choice

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 10. 🔗 Connections & Sources

**Builds on:** **3.1 Stateless vs. Stateful Architecture**, which supplies the constraint that makes HTTP-level caching and horizontal scaling of a REST API possible at all — every request self-describing is a REST precondition, not a REST feature. Also **3.5 Idempotency**, which supplies the exact vocabulary (safe, idempotent) this subtopic applies to each HTTP method, and which is what Stripe's idempotency-key pattern retrofits onto POST.

**Enables:** **11.2 gRPC**, the direct alternative when internal, high-fanout, latency-sensitive service-to-service calls make binary serialization and code generation worth their setup cost over REST's text-based ubiquity. **11.3 GraphQL**, which exists specifically to solve REST's over-fetching/under-fetching problem for clients that need field-level shape control across multiple resources. **11.5 API Versioning**, which is the deep dive on how a REST API evolves its resource shapes without breaking existing clients. **11.7 API Gateway Patterns**, where the REST endpoints designed here get fronted by a gateway that handles auth, rate limiting, and routing at the edge.

**Tension with:** **11.3 GraphQL** directly, on the fixed-shape-vs-client-driven-shape axis — REST's uniform interface is exactly the constraint GraphQL relaxes, and neither is strictly better, only better for a given consumer shape. Also **8.5 Query patterns and optimization** — a REST resource's shape is a public contract that's expensive to change, while the underlying query patterns serving it may need to evolve freely, creating pressure between API stability and storage-layer flexibility.

### 📚 Further reading

- [ ] **Roy Fielding's dissertation, Chapter 5 — "Representational State Transfer (REST)"** — https://ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm — the original source; read it once for the constraints (client-server, stateless, cacheable, layered system, uniform interface), skip the rest
- [ ] **RFC 9110 — HTTP Semantics** — https://www.rfc-editor.org/rfc/rfc9110.html — the authoritative definition of every method's safety/idempotency/cacheability properties and every status code's meaning
- [ ] **RFC 9457 (obsoletes 7807) — Problem Details for HTTP APIs** — https://www.rfc-editor.org/rfc/rfc9457.html — the standard JSON error-body shape referenced in §6
- [ ] **Stripe API Reference** — https://stripe.com/docs/api — widely regarded as the best-designed production REST API; read the idempotency and pagination sections specifically
- [ ] **Google AIP (API Improvement Proposals)** — https://google.aip.dev/ — the standard-methods-plus-custom-methods framework referenced in §7's "In production" table
- [ ] **Martin Fowler — "Richardson Maturity Model"** — https://martinfowler.com/articles/richardsonMaturityModel.html — the levels-0-through-3 framework for grading how RESTful an API actually is

---

## 11. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*

---

**MODEL ANSWER — §4 Checkpoint** (wiki vs. protocol enforcement)

```
WHAT'S MISSING FROM THE WIKI
  Discipline-enforced, not mechanism-enforced: nothing stops a new
  endpoint from violating it, and it decays the moment reviewers stop
  checking. It also never reaches external consumers — a third-party
  integrator has never seen your wiki and has no way to find it.

WHY THE PROTOCOL VERSION SURVIVES
  HTTP's method semantics (GET is safe/cacheable, POST isn't) are
  already written into the code of every HTTP-aware tool — proxies,
  CDNs, browsers, gateways — because those tools were built against a
  public standard (the HTTP spec), not against your team's wiki. The
  proxy isn't "familiar with your conventions" in the way a teammate
  is; it's running code that implements HTTP correctly, full stop.
  Nobody has to teach it anything, because the enforcement shipped
  with the software before your API was written.

ONE-LINE VERSION
  A wiki page has to be read and remembered; HTTP's vocabulary is
  already compiled into the infrastructure.
```

**MODEL ANSWER — §5 Checkpoint 1** (PATCH idempotency)

```
NON-IDEMPOTENT EXAMPLE
  PATCH /orders/{id} with {"add_item": "sku_123"} — a relative
  operation. Retry after a timeout and sku_123 gets added twice,
  because each call means "add one more," not "make the list equal
  to X."

IDEMPOTENT EXAMPLE
  PATCH /orders/{id} with {"status": "shipped"} — an absolute set.
  Retry it any number of times and the order ends up "shipped"
  either way, because the semantic is "make this field equal to X,"
  not "change it by some amount."

WHY PATCH IS THE METHOD MOST AT RISK
  PUT never has this ambiguity — it always sends the full resource,
  so "set the whole thing to X" is idempotent by construction. PATCH
  gives you the flexibility to express either an absolute set or a
  relative adjustment, and idempotency becomes a property of the
  SPECIFIC body you chose to send, not something the method
  guarantees for free.
```

**MODEL ANSWER — §5 Checkpoint 2** (POST /cancel vs. PATCH status)

```
VERDICT
  Not a violation — a legitimate, context-dependent fork.

THE PATCH-STATUS SIDE (uniform interface reading)
  "Cancelled" is just another value of the order's status field.
  The uniform interface handles it with zero new vocabulary — no
  method or endpoint pattern needs to be learned beyond what every
  other resource already uses.

THE POST-CANCEL SIDE (action-resource reading)
  Legitimate specifically when "cancel" carries real side effects —
  refund initiation, inventory release, a notification — that don't
  fit the "flip a field" model. Modeling it as an action makes those
  side effects explicit and discoverable, rather than buried inside
  whatever a PATCH handler happens to do.

WHAT'S ACTUALLY BEING TRADED
  PATCH-status buys uniformity but risks hiding non-trivial side
  effects behind what looks like a simple field update. POST-cancel
  buys explicitness for those effects but costs one more non-uniform
  endpoint per action verb, chipping away at the "one small
  vocabulary, everywhere" promise the uniform interface makes.

REAL-WORLD ANCHOR
  Stripe uses POST-action endpoints for subscription cancellation
  precisely because the side effects (proration, billing changes) are
  the point of the call, not an incidental consequence of a status
  change.
```

**MODEL ANSWER — §6 Checkpoint 1** (PUT as partial update)

```
WHAT HAPPENS TO THE ROW
  PUT treats the request body as the COMPLETE new representation.
  Whatever the body doesn't mention isn't "left alone" — a compliant
  server sets it to null/default, because it has no way to tell
  "the client forgot this field" apart from "the client wants it
  cleared." name and phone are silently destroyed.

WHY IT'S A DESIGN BUG, NOT JUST A CLIENT MISTAKE
  The client's actual INTENT was a partial update — that's a PATCH
  operation wearing PUT's method name. The fix isn't "remember to
  always send every field," it's using the method whose contract
  matches the intent.

THE FIX
  PATCH /users/42 with {"email": "new@example.com"} — by definition
  touches only the fields present in the body, leaving name and
  phone untouched.
```

**MODEL ANSWER — §6 Checkpoint 2** (pagination drift)

```
MECHANISM
  Offset pagination is "skip N, take M" — a POSITION in a mutable,
  ordered result set, not a reference to specific rows. An insertion
  before the current window shifts every subsequent row's position
  down by one; a deletion shifts everything up by one.

WHY THAT PRODUCES A DUPLICATE
  The offset value in the next request (e.g. 40) doesn't change, but
  what sits AT that position does. A row the client already saw as
  the last item of page 2 can shift into the first slot of page 3 —
  same offset, different (already-seen) row.

WHY IT CAN ALSO SKIP A ROW
  A deletion shifts rows the other direction: a row that would have
  been the first item of page 3 slides backward into a position the
  client already paged past on page 2, and is never returned at all.

THE FIX
  Cursor-based pagination, anchored to a stable row identity (last-
  seen order ID or created_at timestamp) instead of a row count.
  "Give me the next 20 after THIS row" is immune to insertions or
  deletions anywhere else in the set, because it never depends on
  absolute position.
```

**MODEL ANSWER — §7 Checkpoint** (dashboard aggregation: REST vs. GraphQL)

```
VERDICT
  Plain REST, with a purpose-built GET /dashboard aggregation
  endpoint — not GraphQL.

WHY
  This is one screen with a fixed, known shape. The three-round-trip
  problem is real, but /dashboard solves it directly: one endpoint,
  fetches/joins the three pieces server-side, returns one JSON shape.
  No new query layer, no resolver complexity, no N+1 risk to build
  tooling around, and GET responses keep HTTP-level caching for free.

THE COST I'M ACCEPTING
  /dashboard isn't a clean domain resource — it's a named exception
  to pure resource modeling, and it only serves this one screen. That's
  acceptable as a deliberate, flagged exception, not a pattern to
  repeat casually.

THE SWITCH CONDITION
  If this need repeats across many different screens with genuinely
  different field combinations — not just this one fixed layout —
  building a new bespoke aggregation endpoint per screen becomes the
  exact sprawl REST was meant to avoid. That repeated variability is
  what GraphQL actually solves; a single dashboard is not that case.

WHAT WENT WRONG ON THE FIRST TWO PASSES (worth remembering)
  The instinct was to reach for the heavier tool (GraphQL) and then
  engineer around its downsides (a custom N+1-solving query
  optimizer) rather than asking whether the heavy tool was
  proportionate to begin with. That's the trap this checkpoint is
  built to catch — proposing new infrastructure to patch a tool's
  cost, instead of reconsidering the tool.
```

**MODEL ANSWER — §8 Adversarial Stress Test** (idempotency-key retry race)

```
THE THREE-STATE KEY, NOT TWO
  A naive design treats the key as binary (exists / doesn't exist).
  The scenario specifically breaks that: the key must carry a STATE —
  "in-process" or "completed(+result)" — not just presence/absence.

WHEN THE KEY GETS WRITTEN
  "in-process" is written to the store at the START of the first
  request, BEFORE order creation runs — not after. This is what
  closes the race: if it were written only after the order is
  created, two near-simultaneous retries could both see "not found"
  and both create an order before either finishes. Writing the
  marker first means the second request always finds SOMETHING to
  react to.

THE RETRY PATH, BY STATE
  - Key not found          → new request, proceed to create the order
  - Key = "in-process"     → an identical request is already running;
                              do NOT proceed concurrently — block/poll
                              until it resolves, or return a
                              409/425 "still processing" response
  - Key = "completed" + result → return the STORED result verbatim
                              (same status code, same body) instead
                              of re-running creation logic

WHY THIS SURVIVES THE EXACT SCENARIO
  Server creates the order, then updates the key from "in-process" to
  the completed result — the connection dropping is a CLIENT-side
  event; server-side processing runs to completion regardless. The
  retry arrives, finds "completed," and returns the already-computed
  result. No duplicate order, no hang.

REMAINING EDGE CASE (worth knowing, not required for the gate)
  If the server crashes between "order created" and updating the key
  to "completed," the key is stuck at "in-process" forever (or until
  TTL). A blocking retry with no timeout hangs indefinitely. A more
  complete design adds a timeout on the wait, and/or a reconciliation
  check against the orders table itself if the key stays in-process
  past a bounded window.
```
