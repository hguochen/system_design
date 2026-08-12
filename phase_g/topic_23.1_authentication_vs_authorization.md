# 23.1 Authentication vs. Authorization

> **Topic:** Topic 23 — Security
> **Phase:** G — Security Branch
> **Depth Tier:** 🥇 T1 (Core) — budget ~3h
> **Prereqs:** 3.2 (Session Management Approaches), 3.4 (JWT as Stateless Session Token)
> **Date studied:** 2026-08-11

---

## 0. 🧭 The Question This Answers

3.2 established how a server recognizes a returning client across requests — a session ID or token that proves "this request came from the same party as that earlier login." 3.4 established JWT as a way to carry that identity statelessly, self-contained and signed, with no server-side lookup required. Both of those subtopics answer the same underlying question: **who is making this request?** Nothing in either one answers a completely different question that comes immediately after: **now that you know who they are, what are they actually allowed to do?**

The tension is that these two questions get conflated constantly, in real production systems, not just in interview answers. A request arrives with a valid, correctly-signed token — authentication succeeds — and it is tempting to treat "the token is valid" as equivalent to "the request should be allowed to proceed." It isn't. A valid token proves identity, not permission. The moment a system has more than one role, more than one tenant, or resources that belong to specific owners, collapsing those two checks into one is exactly how a logged-in customer ends up reading another customer's invoices, or a support agent ends up able to delete production data they were only supposed to view.

**The question:** *Given a request that has already proven who is sending it, how do you separately and explicitly decide whether that specific identity is allowed to perform this specific action on this specific resource — and where in the system does that decision actually get made?*

> **→ Next:** Before naming the two mechanisms, what actually breaks when systems don't separate them?

---

## 1. 🎯 Interview Quick Reference Card

> *Not a summary — a live-recall tool, built for retrieval speed under interview pressure. If you need the reasoning behind anything here, that's what §2 (cheatsheet) and the rest of the doc are for.*

**The checklist — walk this on the whiteboard, in order:**

1. Say both words out loud and define them in one line each: authentication = who are you, authorization = what can you do
2. Name where authentication happens — usually terminated once, near the edge (API gateway / auth middleware), producing a verified identity attached to the request context
3. Name where authorization happens — as close to the resource as possible, re-checked at every layer, never assumed from the edge alone
4. Name the mechanism for each: authentication → session lookup or JWT signature verification; authorization → RBAC role check, ABAC attribute check, or ACL/relationship check
5. Name the failure code for each independently: authentication fails → `401`; authorization fails → `403`
6. Call out the specific vulnerability class this whole topic exists to prevent: broken object-level authorization (IDOR/BOLA) — checking "is this token valid" but never checking "does this specific resource belong to this identity"

**Trigger → action:**

| Interviewer says | You do |
|---|---|
| "How would you handle access control for this API?" | Two separate checks, two separate answers — never one combined "is this user allowed" blob |
| "What if a user tries to access another user's data?" | Name IDOR/BOLA directly — check resource ownership, not just token validity |
| "How do you design permissions for a multi-tenant app?" | RBAC for role-shaped permissions, ABAC/ReBAC when permission depends on the resource's own attributes (tenant ID, ownership) |
| "What if a user's role changes mid-session?" | Depends on where authorization state lives — JWT-embedded claims are stale until expiry; server-side lookup is instantly fresh. Name the trade-off. |
| "Should the gateway or the service check permissions?" | Both, for different grains — gateway does coarse-grained (route-level), service does fine-grained (resource-level). Never skip the service-level check. |

**Fast disambiguation — the pairs that get confused live:**

| Pair | The distinction |
|---|---|
| Authentication vs. authorization | AuthN proves identity (a fact about the requester). AuthZ decides permission (a policy decision about that identity plus a specific resource and action). |
| 401 vs. 403 | 401 = not authenticated at all, go log in. 403 = authenticated, but this identity is not allowed to do this — don't retry with the same credentials expecting a different result. |
| RBAC vs. ABAC | RBAC = permission depends on a fixed role assigned to the subject. ABAC = permission depends on dynamic attributes (resource owner, tenant, time of day) evaluated at request time. |
| Coarse-grained vs. fine-grained authorization | Coarse = "can this role call this endpoint at all" (gateway-level). Fine = "can this specific identity act on this specific resource instance" (service/resource-level). Both are required; neither substitutes for the other. |
| Stale JWT claims vs. live session lookup | JWT-embedded roles are frozen at issuance — a revoked permission still works until the token expires. A server-side session/policy lookup is checked fresh on every request but costs a lookup. |

**High-yield anchors:**

```
OWASP API Security Top 10 (2023): API1 — Broken Object Level Authorization
  is the #1 ranked risk — the exact "valid token, wrong resource" failure
  this subtopic exists to prevent.
401 Unauthorized = authentication failure. 403 Forbidden = authorization
  failure. (401's name is historically misleading — it means "unauthenticated.")
Google Zanzibar (2019 paper) — the relationship-based access control system
  powering Google Docs/Drive sharing at global scale.
AWS IAM — explicit Deny always overrides any Allow, evaluated per
  (principal, action, resource) triple.
```

**The script — say this close to verbatim:**

> "I'd split this into two explicit checks rather than one. Authentication happens once, near the edge — the gateway verifies the JWT signature and attaches a verified identity to the request context. Authorization is separate and happens again at the resource layer: for a multi-tenant document app, that means checking not just 'is this a valid user' but 'does this specific document belong to this user's tenant, and does their role allow this action' — I'd use RBAC for the role part (admin/editor/viewer) and an ownership check for the resource part, which is really a relationship-based check, the same shape as Google's Zanzibar. The cost is that this fine-grained check has to run on every single request that touches a resource, not just once at the gateway — skipping it there is exactly how broken object-level authorization vulnerabilities happen, which OWASP ranks as the top API security risk. I'd only centralize this into a dedicated policy engine like OPA if the same complex policy logic needed to be consistently enforced across many services."

**If pushed on the revocation problem specifically:**
> A role change or permission revocation only takes effect immediately if authorization is checked against a live, server-side source of truth. If the permission is baked into a JWT claim at issuance, the old permission remains valid until that token expires — the fix is either short-lived tokens with frequent re-issuance, or moving the authorization check itself out of the token and into a server-side lookup evaluated fresh per request.

---

## 2. 📋 Cheatsheet

> *Everything you need to recall this concept in 30 seconds — for quick review before an interview.*
>
> ⏭️ **First time through this topic?** Skip to §3 and come back here for revision.

```
§ 1  WHY IT EXISTS
Early systems with one role (or "logged in = full access") could get away
with a single check: does a valid session exist? As soon as a system has
more than one role, more than one tenant, or resources with individual
owners, "logged in" stops meaning "allowed to do this specific thing."
Treating authentication's yes/no answer as if it also answered the
permission question is the single most common root cause of broken access
control — an attacker doesn't need to break your login, just find an
endpoint that only checked that a token was valid, never whose it was.

§ 2  WHAT IT IS
AUTHENTICATION (AuthN)   Verifying identity — proving the requester is who
                        they claim to be. Answers "who are you?"
AUTHORIZATION (AuthZ)    Evaluating permission — deciding whether that
                        identity may perform a specific action on a
                        specific resource. Answers "what can you do?"
SUBJECT / ACTION /       The three inputs every authorization decision
RESOURCE                 needs: who is asking, what they want to do, and
                        what they want to do it to.
ENFORCEMENT POINT        Wherever a check actually blocks or allows a
                        request — can and should exist at multiple layers
                        (gateway, service, resource), not just one.

§ 3  THE MECHANISM
AUTHENTICATE ONCE       Verify identity near the edge — session lookup
                        (3.2) or JWT signature check (3.4) — attach the
                        verified identity to the request context.
AUTHORIZE PER REQUEST    Re-evaluate permission for THIS action on THIS
                        resource, every time, as close to the resource
                        as possible — never cached from a prior request.
PICK THE POLICY MODEL    RBAC (role-based) for permissions that map
                        cleanly to a small role set. ABAC (attribute-
                        based) or ReBAC (relationship-based) when
                        permission depends on resource ownership, tenant,
                        or other request-time attributes a fixed role
                        can't capture.
FAIL WITH THE RIGHT CODE  401 = not authenticated. 403 = authenticated but
                        not permitted. Never blur the two — they tell the
                        client to do completely different things next.

§ 4  USE / AVOID
USE RBAC when: a small, stable set of roles (admin/editor/viewer) maps
  cleanly onto permissions across the whole system.
USE ABAC/ReBAC when: permission depends on the relationship between the
  subject and the specific resource instance — ownership, tenant match,
  sharing grants — which no fixed role can express.
USE a centralized policy engine (e.g. OPA) when: many services need to
  enforce the same complex policy consistently and auditably.
AVOID checking authorization only at the API gateway and trusting every
  downstream service — an internal call that bypasses the gateway, or a
  compromised service, has no enforcement left standing behind it.
AVOID embedding permissions in a long-lived JWT and assuming they're
  current — they're frozen at issuance and stay valid until expiry, even
  after being revoked server-side.
AVOID checking "is this token valid" as a substitute for "does this
  resource belong to this identity" — that gap IS broken object-level
  authorization (IDOR/BOLA), OWASP's #1 ranked API risk.

§ 5  NUMBERS TO ANCHOR THE DISCUSSION
OWASP API Security Top 10 (2023): API1 — Broken Object Level Authorization
  ranked #1. This is literally "authenticated but not authorized correctly."
401 Unauthorized = authentication failure (misleading name — really means
  "unauthenticated"). 403 Forbidden = authorization failure.
Google Zanzibar (2019) — the relationship-based access control model
  behind Google Docs/Drive sharing; permissions expressed as tuples:
  object#relation@user (e.g. doc:123#editor@alice).
AWS IAM evaluates every request as (principal, action, resource) and an
  explicit Deny always overrides any Allow, regardless of order.

§ 6  INTERVIEW TRIGGERS + GOTCHA
→ "How would you handle access control here?"    → two separate checks,
                                                     name both explicitly
→ "What if a user accesses another user's data?"  → name IDOR/BOLA, check
                                                     resource ownership
→ "Permissions for a multi-tenant app?"            → RBAC for roles, ABAC/
                                                     ReBAC for ownership
→ "What if the gateway already checked auth?"      → gateway = coarse-
                                                     grained only; fine-
                                                     grained still runs at
                                                     the resource
GOTCHA: Treating "the token is valid" as "the request is allowed." A
  valid signature proves identity, not permission — the two checks are
  answering different questions and must both run, separately, every time.
```

---

## 3. 🧠 The Mindmap

> *The picture to hold in your head while you study. Everything below hangs off this.*

```
                    ┌─────────────────────────────────────────┐
                    │    Does this request get to proceed?     │
                    └────────────────────┬──────────────────────┘
                                         │
                 ┌────────────────────────┴────────────────────────┐
                 ▼                                                 ▼
   ┌───────────────────────────────┐   runs    ┌───────────────────────────────┐
   │     🔑 AUTHENTICATION           │   FIRST   │     🔒 AUTHORIZATION            │
   │     "who are you?"              │ ────────▶ │     "what can you do?"          │
   ├───────────────────────────────┤           ├───────────────────────────────┤
   │ MECHANISM                       │           │ MECHANISM                       │
   │  session (3.2) · JWT (3.4) ·    │           │  RBAC · ABAC · ReBAC             │
   │  OAuth token (23.2)             │           │  (Zanzibar-style)                │
   ├───────────────────────────────┤           ├───────────────────────────────┤
   │ WHERE ENFORCED                  │           │ WHERE ENFORCED                  │
   │  ONCE — near the edge           │           │  EVERY layer — gateway          │
   │  (gateway / middleware)         │           │  (coarse) + resource (fine)     │
   ├───────────────────────────────┤           ├───────────────────────────────┤
   │ OUTPUT                          │           │ OUTPUT                          │
   │  verified identity attached     │           │  allow/deny for (identity,      │
   │  to request context             │           │  action, resource)              │
   ├───────────────────────────────┤           ├───────────────────────────────┤
   │ FAILS →  401 Unauthorized       │           │ FAILS →  403 Forbidden          │
   ├───────────────────────────────┤           ├───────────────────────────────┤
   │ ⚠ real systems: Auth0, Okta     │           │ ⚠ real systems: Zanzibar,       │
   │ ⚠ risk: stolen long-lived       │           │   AWS IAM, OPA, GitHub          │
   │   tokens replay as the          │           │ ⚠ risk: IDOR/BOLA (OWASP #1),   │
   │   original identity             │           │   stale JWT permission claims   │
   └────────────────┬────────────────┘           └────────────────┬────────────────┘
                    │                                             │
                    └──────────────────────┬──────────────────────┘
                                           ▼
                    ┌─────────────────────────────────────────────┐
                    │  REQUEST ALLOWED only if BOTH gates pass,    │
                    │  in order: authenticate → authorize          │
                    │  (401 if gate 1 fails · 403 if gate 2 fails) │
                    └─────────────────────────────────────────────┘
```

**How to read it:** the two columns are parallel tracks answering different questions, not independent unordered facts — authentication runs first, and its output (a verified identity) is exactly what authorization consumes, so the arrow between the columns encodes a real dependency, not just a comparison. Each track carries the same four dimensions — mechanism, where enforced, output, failure code — so you can read straight across a row and see precisely where the two diverge (once vs. every layer, 401 vs. 403). The footnote rows attach real systems and failure modes to the side of the comparison they actually belong to, rather than floating as unrelated branches. The convergence at the bottom is the actual rule this whole subtopic teaches: a request is allowed only if both gates pass, in that order.

---

## 4. 🔥 The Problem

Early systems, or systems with a single class of user, can get away with collapsing authentication and authorization into one check: does a valid session exist? If every logged-in user is allowed to do everything the application supports, "are you logged in?" and "are you allowed to do this?" happen to have the same answer, and nobody notices they're actually two different questions. This works fine — right up until the system grows a second role, a second tenant, or a resource that belongs to a specific owner rather than to "logged-in users" as an undifferentiated group.

The moment that happens, the naive approach breaks in a specific and predictable way. An endpoint checks "does this request carry a valid token?" — that's authentication, and it passes. It does not separately check "does the resource this token's owner is requesting actually belong to them, or does their role permit this specific action?" — that's authorization, and nobody wrote the check. The result is a fully authenticated, perfectly legitimate user reading or modifying data that was never meant to be theirs, simply by changing an ID in a URL or a request body. This is not a hypothetical: OWASP's API Security Top 10 ranks exactly this failure — Broken Object Level Authorization — as the single most common and highest-impact API vulnerability class in production systems.

The instinctive first fix is to sprinkle permission checks wherever someone notices they're missing: an `if user.role == 'admin'` here, a manual ownership comparison there, added ad hoc as bugs get reported. This doesn't survive scale for a structural reason — the checks live scattered across dozens of endpoints, written by different engineers at different times, with no single place to audit "what can this role actually do" or "is every resource-touching endpoint actually checking ownership." Some endpoints get the check; others, added in a hurry, don't. The insight that resolves this is to stop treating "allowed" as a side-effect of "logged in" and instead build authorization as its own explicit, separately-evaluated decision — one that takes an identity, an action, and a resource as inputs, runs *after* authentication has already succeeded, and runs again at every layer that touches the resource, not just once at the front door.

**Before and after:**

```
  BEFORE — one conflated check                AFTER — two separate, explicit checks
  ─────────────────────────────────           ─────────────────────────────────────
   if valid_token(request):                    identity = authenticate(request)
       allow()                                 if not identity:
                                                    return 401

                                                if not authorize(identity, action,
                                                                  resource):
                                                    return 403
                                                allow()

   ✓ works when every logged-in user           ✓ authentication answers "who" —
     is allowed to do everything                  once, at the edge
   ✗ "valid token" silently becomes             ✓ authorization answers "what" —
     "allowed to do anything"                      re-evaluated per resource, every
   ✗ IDOR/BOLA: change an ID in the                request
     URL, access someone else's data            ✓ a missing authorization check is
   ✗ permission checks scattered ad hoc            visible as a missing call, not a
     wherever a bug got reported                   silently-passing token check
   ✗ no single place to audit "what           ✓ policy logic centralizable and
     can this role actually do"                    auditable in one place
```

### ✅ Checkpoint

1. A teammate says: "Our gateway already validates the JWT on every request — isn't that enough access control?" Explain precisely what question the gateway's check answers and what question it leaves completely unanswered, using a concrete example of a request that would pass the gateway's check but should still be rejected.

   > 💡 *If you hesitate, re-read the second paragraph — the part distinguishing "does this request carry a valid token" from "does this resource belong to this identity."*

MODEL ANSWER — §4 Checkpoint (gateway JWT question, closing out both examples)

WHAT THE GATEWAY'S CHECK ANSWERS
  Authentication only — it verifies the JWT's signature and confirms
  the request carries a valid, unexpired token issued to a known
  identity. That's it. It proves "this request comes from user X."

WHAT IT LEAVES UNANSWERED
  Authorization — whether user X is allowed to perform THIS action
  on THIS resource. The gateway doesn't know what resource is being
  targeted or the caller's role/ownership relationship to it; it only
  knows the token is valid.

CONCRETE EXAMPLE — AUTHORIZATION FAILS, AUTHENTICATION PASSES
  A logged-in social media user has a valid JWT (user 123). They send
  PUT /users/456/profile to edit someone else's profile. The gateway
  validates the token — passes. The service must separately check:
  does the identity in the token match the resource being edited?
  It doesn't, so this is rejected with 403, even though the gateway's
  check passed cleanly.

CONCRETE EXAMPLE — AUTHENTICATION FAILS (never reaches authorization)
  The same user's JWT has expired, or the request carries no
  Authorization header at all. The gateway's signature/expiry check
  fails immediately — 401, before any identity is established.
  Authorization is never evaluated, because there's no identity yet
  to evaluate it against.

WHY THIS MATTERS
  These are two independent, separately-testable failure paths — one
  can fail while the other would have passed. An expired token editing
  THEIR OWN profile still gets 401 — authorization never got a chance
  to say yes. A valid token editing SOMEONE ELSE'S profile gets 403 —
  authentication already said yes, and it didn't matter.

> **→ Next:** If the fix is two separate checks, what exactly does each one consist of, and how do they build on each other?

---

## 5. 💡 The Core Idea

**Authentication and authorization are two independent decisions — verifying who is making a request, and separately deciding what that verified identity is permitted to do — and treating them as one collapsed check is the root cause of most broken access control.**

**Visual required:** build-chain diagram.

```
 [TWO DIFFERENT ──▶ [AUTHENTICATION ──▶ [AUTHORIZATION ──▶ [ENFORCEMENT MUST
  QUESTIONS]          ESTABLISHES         EVALUATES POLICY    HAPPEN AT EVERY
   because "who        IDENTITY]           AGAINST THAT       LAYER, NOT JUST
   are you" and         therefore every     IDENTITY]           THE EDGE]
   "what can you        request needs a     so the identity      which means a
   do" require            verified,          alone is never       compromised or
   separate answers      trustworthy         enough — action     bypassed layer
                          subject before      + resource must     can't fall back
                          anything else       be checked too       on a check that
                          can happen                                only ran once
```

### Two Different Questions

Everything starts with recognizing that "who is this?" and "what are they allowed to do?" are not the same question wearing different names — they have different inputs, different failure modes, and different correct responses. Authentication takes a set of credentials (a password, a token, a certificate) and produces a single yes-or-no answer plus, on success, an identity. Authorization takes that identity, plus the specific action being attempted, plus the specific resource it targets, and produces a separate yes-or-no answer. A system can authenticate a request perfectly and still be completely wrong to allow it — those are independent facts, and a design that only checks one of them is only half-built, no matter how solid that half is.

### Authentication Establishes Identity

Once the two questions are separated, authentication's job is narrow and well-defined: verify that the requester is who they claim to be, and produce a verified identity the rest of the system can trust. The mechanisms are the ones 3.2 and 3.4 already covered — a server-side session looked up by a session ID (3.2), or a JWT whose signature is checked locally without a database round trip (3.4) — plus delegated mechanisms like OAuth2 tokens (23.2) issued by a third-party identity provider, or mutual TLS certificates for service-to-service calls. Whichever mechanism is used, authentication typically happens once per request, as early as possible — often at an API gateway or auth middleware layer — and its output is a verified identity attached to the request context that every downstream layer can read without re-verifying credentials itself.

### Authorization Evaluates Policy Against That Identity

Authentication's output — a trusted identity — is authorization's input, but authorization needs two more things authentication never had: the specific action being attempted (read, write, delete, refund) and the specific resource it targets (this order, this document, this account). The policy model that maps `(identity, action, resource)` to `allow`/`deny` is a real design choice, not a formality: RBAC (Role-Based Access Control) assigns permissions to roles and roles to identities, which works well when permissions map cleanly onto a small, stable set of roles like admin/editor/viewer. ABAC (Attribute-Based Access Control) and ReBAC (Relationship-Based Access Control, the model behind Google's Zanzibar) evaluate permission against dynamic attributes or relationships at request time — does this identity's `tenant_id` match this resource's `tenant_id`, does this identity own this specific document — which RBAC's fixed roles can't express because the permission depends on the resource instance, not just the subject's role.

### Enforcement Must Happen at Every Layer

None of the above matters if it only runs once, at the edge, and every downstream service assumes it's already been done. This is the direct consequence of separating the two checks: authentication genuinely can be centralized at one layer, because identity doesn't change as a request travels deeper into the system — but authorization must be re-evaluated at every layer that touches a resource, because a gateway checking "does this role allow calling this endpoint at all" (coarse-grained) has no way to know "does this specific document belong to this specific identity" (fine-grained) without knowing about that document. A service that trusts the gateway's coarse check as a substitute for its own fine-grained check is exactly how a valid, authenticated request reaches a resource it should never have touched — the confused deputy problem, and the direct mechanism behind IDOR/BOLA.

### ✅ Checkpoint

1. Explain, using the build chain above, why it's structurally correct to authenticate a request once at the edge but structurally wrong to authorize it only once at the edge. What's different about what each check needs to know?

   > 💡 *If you hesitate, re-read "Authentication Establishes Identity" and "Enforcement Must Happen at Every Layer" — the answer is about what information each check depends on and whether that information is available at the edge.*

MODEL ANSWER — §5 Checkpoint 1 (why authenticate once, authorize every layer)

WHAT'S INVARIANT vs. WHAT ISN'T
  Authentication's output — a verified identity — doesn't change as a
  request travels deeper into the system. The same subject is the
  same subject at the gateway, in the service, and at the resource
  layer. Nothing about moving deeper changes who the requester is,
  so verifying it once is sufficient — there's no new information
  further down that would change the answer.

  Authorization's inputs (action + resource) are NOT invariant. A
  gateway only sees a route; it has no idea which specific document,
  order, or account is being targeted, or what precisely will be
  done to it. Only the layer that actually owns the resource has
  that information. So the SAME identity has to be re-evaluated
  against a DIFFERENT (action, resource) pair at each layer that
  adds resource-specific context the earlier layer didn't have.

ONE-LINE VERSION
  Authenticate once because identity is a fact about the requester.
  Authorize repeatedly because permission is a fact about the
  requester PLUS a specific action PLUS a specific resource — and
  only the deepest layer knows the resource.

2. A teammate proposes hardcoding `if user.role == 'admin'` checks directly inside each service's business logic instead of using RBAC role definitions or a policy engine. Using the build chain, explain what's being traded, and say whether this is ever a legitimate choice.

   > 💡 *If you hesitate, trace from AUTHORIZATION EVALUATES POLICY through ENFORCEMENT MUST HAPPEN AT EVERY LAYER — the answer is about consistency and auditability versus simplicity for a small, stable permission set.*

MODEL ANSWER — §5 Checkpoint 2 (hardcoded admin check — legitimate?)

WHEN IT'S FINE
  Exactly when the role IS the full permission, with no exceptions —
  "admin can do literally everything, on every resource, with no
  restriction ever." At that point the check has degenerated into a
  pure identity check with no action/resource dependency, so a
  centralized RBAC table or policy engine would just always answer
  "yes" anyway — there's no real decision being encoded, so nothing
  is lost by skipping the infrastructure for it.

WHEN IT BREAKS
  The moment ANY restriction needs to exist — "admin can do
  everything EXCEPT delete another tenant's billing records," say —
  the hardcoded check has no way to express the exception without
  scattering a new conditional at every place that exception applies.
  This reintroduces exactly the problem §4 already diagnosed: checks
  spread across the codebase with no single place to audit "what can
  this role actually do."

THE TRADE, PRECISELY
  Hardcoding buys simplicity (no policy table, no lookup) at the
  cost of expressiveness — it can only encode "yes, unconditionally"
  or "no, unconditionally" per role. Any conditional permission
  requires moving to RBAC (or further, ABAC/ReBAC) specifically
  because that's what buys you the ability to say "yes, except."

> **→ Next:** You know the two mechanisms. What actually happens, request by request, once you sit down to enforce them?

---

## 6. ⚙️ How It Actually Works

**Happy path — a request that touches a specific resource:**

1. Client sends a request carrying credentials — a session cookie, a bearer JWT, or an OAuth access token.
2. The authentication layer (typically at the gateway or auth middleware) verifies those credentials: a session lookup against a store (3.2), or a local signature check against a JWT (3.4). On success, it attaches a verified identity (a subject ID, plus whatever claims came with it) to the request context. On failure, the request stops here with `401`.
3. The request proceeds toward the resource it's targeting. Before the business logic runs, the authorization layer evaluates a policy decision: does *this* identity have permission to perform *this* action on *this specific resource instance* — not just "is this endpoint allowed for this role" but "does this document/order/account belong to this identity, or does their role grant access to it."
4. If the policy check fails, the request stops with `403` — the identity is known and valid, it simply isn't permitted to do this. If it passes, the business logic runs.
5. Every subsequent internal call that touches the same or a different resource re-evaluates its own authorization check — the earlier pass does not carry forward as a blanket permission.

> 🗺️ **Mental model — the office building badge system.** A badge reader at the building's front entrance authenticates you: it verifies you're a real employee, once, when you walk in. But every individual door past the lobby — the server room, the finance floor, the executive suite — has its *own* reader that checks whether *your specific badge* is authorized for *that specific door*, every single time you walk through it. Getting past the front desk never implies you can open every door behind it. *Where it breaks down:* a building's interior doors are physical and finite, so a determined attacker who slips past the lobby still has to defeat each door individually and in person. A software system has none of that friction — a single missing authorization check on one internal endpoint is instantly and remotely exploitable, with no equivalent of a hallway to walk down or a guard to notice you.

**Failure & edge cases:**

- **Broken object-level authorization (IDOR/BOLA).** An authenticated user changes an ID in a URL or request body (`GET /invoices/1042` → `GET /invoices/1043`) and the endpoint only checks that the token is valid, never that invoice 1043 belongs to this identity. This is OWASP's #1 ranked API security risk precisely because it's easy to introduce (one missing `WHERE owner_id = :identity` clause) and trivial to exploit (increment an integer).
- **Stale permissions in a long-lived JWT.** A JWT that bakes role or permission claims into its payload at issuance is only as current as the moment it was issued. Revoke a user's admin role server-side, and their existing JWT — still cryptographically valid — keeps granting admin access until it expires, because nothing about revoking the role changed the token's signature. This is 3.4's statelessness trade-off resurfacing as a security problem: the token doesn't know the server changed its mind.
- **Trusting the gateway as the only enforcement point.** A service assumes "the gateway already checked auth, so I don't need to" and skips its own resource-level check entirely. This collapses the moment any request reaches that service without going through the gateway — a compromised adjacent service, a debug endpoint, a service-to-service call inside the same network — because there is no enforcement left standing behind the assumption.
- **Confusing 401 and 403 in the response.** Returning `403` for a missing or expired token (instead of `401`) tells the client "you are who you say you are, but you're not allowed" — which sends a legitimate client down the wrong remediation path (it won't think to re-authenticate) and, in security-sensitive contexts, can leak information about what does or doesn't exist.

**Enforcement points along the request path:**

```
CLIENT                EDGE / GATEWAY              SERVICE                RESOURCE LAYER
  │                         │                         │                         │
  │  request + credentials  │                         │                         │
  ├────────────────────────▶│                         │                         │
  │                         │  AUTHENTICATE           │                         │
  │                         │  (session/JWT check)    │                         │
  │                         │  ── verified identity ──│                         │
  │                         │      attached to ctx    │                         │
  │                         │                         │                         │
  │                         │  AUTHORIZE (coarse) ────▶│                         │
  │                         │  "can this role call     │                         │
  │                         │   this endpoint at all?" │                         │
  │                         │                         │  AUTHORIZE (fine) ──────▶│
  │                         │                         │  "does THIS resource     │
  │                         │                         │   belong to THIS         │
  │                         │                         │   identity?"             │
  │                         │                         │                         │
  │◀────────── 401 if authentication fails, anywhere before this point ─────────│
  │◀────── 403 if EITHER authorization check fails — coarse OR fine-grained ────│
  │◀───────────────────── 2xx only if all checks pass ───────────────────────── │

  THE RULE: authentication happens ONCE, near the edge. Authorization is
  re-evaluated at EVERY layer that touches a resource — the fine-grained
  check at the resource layer is never optional, no matter what the
  coarse check upstream already confirmed.
```

**Mechanism flow, end to end:**

```
① credentials    ──▶ ② authenticate     ──▶ ③ authorize        ──▶ ④ authorize
   arrive               (identity check,       (coarse — role         (fine — does
                         once, at the edge)      vs. endpoint)          THIS resource
                                                                          belong to
                                                                          THIS identity)
                                                                              │
                                                                              ▼
                              ⑤ 401 if step ② failed,   ──▶   business logic runs
                                 403 if step ③ or ④ failed,     ONLY if every prior
                                 2xx only if every check          check passed
                                 passed
```

### ✅ Checkpoint

1. Walk through exactly what happens when a valid, unexpired JWT for a user whose `admin` role was revoked five minutes ago is used to call a privileged endpoint. Does the request succeed or fail, and why — tying your answer to what specifically is (and isn't) checked at each step.

   > 💡 *If you hesitate, re-read "Stale permissions in a long-lived JWT" and trace which of the two checks (authentication vs. authorization) actually depends on current server-side state.*

MODEL ANSWER — §6 Checkpoint 1 (revoked role, unexpired JWT)

VERDICT
  The request succeeds. The revocation has zero effect until the
  token expires.

WHAT'S CHECKED AT EACH STEP
  Every layer that evaluates this request — endpoint-level and
  resource-level alike — reads the SAME source: the role claim
  baked into the JWT's payload at issuance. None of them queries a
  live, current record of the user's actual role.

WHY THE REVOCATION DOESN'T MATTER
  Revoking the role server-side changes a database row. It does not
  touch the token's signature or its payload — the token is a
  self-contained, already-signed artifact. Since nothing in this
  design re-derives authorization from current state, the token's
  frozen-at-issuance claim keeps winning at every layer, all the way
  to expiry.


2. A service behind the gateway receives a request directly from another internal service, bypassing the gateway entirely (a legitimate internal call, not an attack). Explain precisely what breaks if that service has no authorization check of its own and was relying entirely on the gateway having already checked it.

   > 💡 *If you hesitate, re-read "Trusting the gateway as the only enforcement point" and the enforcement-points diagram — think about what happens to a request that never passes through the box performing the check.*

MODEL ANSWER — §6 Checkpoint 2 (gateway-bypassing internal call)

WHAT'S ACTUALLY MISSING
  Not a weaker check — no check at all. If the service assumes the
  gateway already handled authorization and never verifies anything
  itself, then a request that arrives without passing through the
  gateway is evaluated against nothing.

WHY THIS BREAKS EVEN FOR A "LEGITIMATE" CALLER
  A caller with genuinely narrow permissions is only ever restricted
  BY a check. Remove the check, and narrow permissions become
  meaningless — that caller now has the same unconditional access as
  anyone else who can reach the endpoint over the network, because
  there is nothing left to distinguish "allowed" from "not allowed."

THE GENERAL LESSON
  Centralizing authentication at the gateway is safe because identity
  doesn't change downstream (§5). Centralizing authorization at the
  gateway is NOT safe, because any path that bypasses that single
  enforcement point — compromised service, debug tool, internal
  service-to-service call — inherits zero protection, not degraded
  protection.

> **→ Next:** You can design and enforce both checks correctly. In a live design, which policy model do you actually pick, and what does each one cost?

---

## 7. ⚖️ The Decision — When, and What It Costs

The default for any system with more than one role or more than one resource owner is: authenticate once near the edge, authorize again at the resource layer, and never let one substitute for the other — that part isn't a judgment call, it's a baseline. The actual decision is *which policy model* implements authorization, and that choice depends on how permission actually varies across your domain.

**Permissions map cleanly onto a small, stable set of roles.** If "admin can do everything, editor can read and write, viewer can only read" fully describes your permission structure, RBAC is the right default: it's simple to reason about, simple to audit ("what can an editor do?" has one answer), and cheap to implement as a role-to-permission lookup table. Most internal admin tools and a large share of B2B SaaS products never need more than this.

**Permission depends on the relationship between the identity and the specific resource instance.** The moment "can this user edit this document" depends on *which* document — do they own it, is it shared with them, does it belong to their tenant — a fixed role can't express the answer, because the answer varies per resource, not per subject. This is ABAC or, more specifically for ownership/sharing graphs, ReBAC — the model Google's Zanzibar paper describes, expressing permissions as tuples like `doc:123#editor@alice` and answering "can alice edit doc:123?" by checking the relationship graph, not a role table.

**The same complex policy needs to be enforced consistently across many services.** When RBAC or ABAC logic starts getting duplicated — and inevitably drifting — across a dozen services, a centralized policy engine (Open Policy Agent is the common production choice) becomes worth its cost: services send `(identity, action, resource)` to a dedicated policy decision point and get back allow/deny, so the policy logic lives and gets audited in exactly one place instead of a dozen slightly different reimplementations.

**Decision tree:**

```
              Does the permission depend on which specific resource
              instance is being accessed (ownership, tenant, sharing)?
                                   │
                    ┌─────yes──────┴──────no, just role───┐
                    ▼                                      ▼
        ABAC / ReBAC (Zanzibar-style).            RBAC. Small, stable role
        Ownership/tenant/relationship               set → permission mapping.
        checked per resource instance.              Simple, auditable,
                                                      cheap to reason about.
                    │
                    ▼
     Does the SAME complex policy need to be enforced
     consistently across many independent services?
                    │
          ┌───no─────┴─────yes────┐
          ▼                        ▼
   Keep the check in-service.   Centralize in a policy engine
   Lower latency, no new         (e.g. OPA). One auditable
   dependency, fine for a        source of truth, at the cost
   handful of services.          of a network hop per check
                                  and a new critical dependency.
```

### Trade-offs

| ✅ Benefit | ❌ Cost / Limitation |
|-----------|---------------------|
| **RBAC is simple and auditable** — "what can an editor do?" has exactly one answer, defined in exactly one place | RBAC cannot express permission that depends on the specific resource instance (ownership, tenant match) — it answers "what role" not "which document," so it silently under- or over-permits the moment resource-level nuance matters |
| **JWT-embedded permission claims need zero server-side lookup** — the signature check alone is enough, which is fast and requires no shared state (3.4's core payoff) | Revoked or changed permissions stay valid until the token expires — there is no way to instantly force a stale claim to stop working without shortening token lifetimes or adding the server-side lookup you were trying to avoid |
| **Fine-grained, per-resource authorization checks close the IDOR/BOLA gap** — the #1 OWASP API risk, directly addressed | Must be applied consistently on every single resource-touching endpoint; one missed endpoint reintroduces the exact vulnerability, and there is no way to verify completeness except deliberate audit or a centralized enforcement layer |
| **A centralized policy engine (OPA) gives one auditable source of truth** across every service, instead of N slightly-drifted reimplementations | Adds a network hop and a latency cost to every authorization decision, and becomes a new critical-path dependency — if the policy engine is unreachable, every downstream authorization check is blocked too |

### In production

| System | How it applies | The nuance |
|--------|----------------|------------|
| **Google Zanzibar** | Relationship-based access control (ReBAC) expressing permissions as tuples — `object#relation@user` — powering sharing across Docs, Drive, and Cloud at global scale | Chosen specifically because RBAC's fixed roles can't express "this document is shared with this specific person" — permission is a graph relationship, not a role assignment |
| **AWS IAM** | Every request evaluated as `(principal, action, resource)` against attached policy documents; an explicit `Deny` always overrides any `Allow`, regardless of evaluation order | The explicit-deny-wins rule exists specifically so a broad, accidentally-permissive policy can always be overridden by a narrower, deliberate restriction — safety by default |
| **GitHub** | Hybrid model: coarse RBAC roles per repository (read/write/admin/maintain) layered with fine-grained, individually-scoped Personal Access Tokens that further restrict what even an admin-role token can do | Demonstrates RBAC and fine-grained scoping working together rather than as alternatives — the role sets the ceiling, the token scope can only narrow it further |
| **Open Policy Agent (OPA)** | Deployed as a sidecar or centralized service at companies like Netflix and Pinterest; services send `(identity, action, resource)` and receive an allow/deny decision from policy written in Rego | The canonical production answer to "the same complex policy needs enforcing consistently across dozens of services" — the trade-off table's centralization row, in practice |
| **Auth0 / Okta** | Identity providers that deliberately separate authentication (login, MFA, session issuance) from authorization entirely — they hand back a verified identity and let each application define and enforce its own permission model | A clean illustration that authentication is a solved, outsourceable problem while authorization is inherently domain-specific and can't be fully delegated to a third party |

### ✅ Checkpoint

1. You're designing permissions for a multi-tenant project-management SaaS: each company (tenant) has its own workspace, users have roles (admin/member/viewer) within their own workspace, and a document can additionally be shared with specific individuals outside the normal role hierarchy. Using the decision tree above, name which policy model(s) you'd combine, and justify against the specific cost each one adds.

   > 💡 *If you hesitate, re-read the second and third boundary conditions — tenant/ownership scoping needs one model, individual sharing on top of a role hierarchy needs another; they aren't mutually exclusive.*

MODEL ANSWER — §7 Checkpoint (multi-tenant SaaS policy model)

RBAC — for the workspace role hierarchy
  admin/member/viewer within a tenant maps cleanly to a fixed role
  set. Simple, auditable, no per-resource lookup needed.

ABAC/ReBAC — for the cross-hierarchy document share
  "Shared with this specific individual" depends on the relationship
  between THIS document and THIS person, not on their role — no
  fixed role can express it. This is literally Zanzibar's use case:
  doc:123#viewer@bob, evaluated independently of workspace role.

THE COMBINED COST
  Not just "manage two policy tables" — RBAC's cost is now paired
  with standing up a second evaluation path (a relationship/attribute
  store plus the query logic to check it) alongside the RBAC lookup,
  and every access decision may now need to consult BOTH before
  answering allow/deny.

> **→ Next:** Can you defend this under interview pressure — and hold up when the interviewer pushes on the cost you claimed you'd pay?

---

## 8. 🎯 In the Interview

**When an interviewer asks / says:**
- "How would you handle access control for this API?"
- "What happens if a user tries to access another user's data by changing an ID?"
- "How would you design permissions for a multi-tenant SaaS application?"
- "The gateway already validates the token — isn't that enough?"

**What you say / do:**
This lands right after you've decided how identity is established (session vs. JWT vs. OAuth — 3.2/3.4/23.2) in the high-level design phase, and it resurfaces hard in the deep dive the instant the interviewer proposes a scenario involving more than one user or more than one role. Say both words and define them in one breath before doing anything else: authentication is identity, authorization is permission. Then name where each check runs — authentication once, near the edge; authorization again, at the resource — before naming the specific policy model (RBAC/ABAC/ReBAC) you'd use for this domain.

**The trade-off statement (memorize this pattern):**
> "I'd separate this into two explicit checks. Authentication happens once, at the gateway — it verifies the JWT signature and attaches a verified identity to the request. Authorization happens again, separately, at the resource layer: for this multi-tenant document system, I'd use RBAC for the role part — admin, editor, viewer, within a workspace — combined with an ownership check for the resource part, confirming the document's `tenant_id` matches the identity's tenant before allowing access, which is really a relationship check, the same shape as what Google's Zanzibar system does for Docs sharing. The cost is that this fine-grained check has to run on every single resource-touching endpoint, not just once at the gateway — skipping it there is exactly how broken object-level authorization vulnerabilities happen, which OWASP ranks as the top API security risk. I'd only reach for a centralized policy engine like OPA if this same complex policy needed to be enforced consistently across many more services than the two or three in this design."

**A second trade-off variant — the revocation pushback:**
> "If the interviewer pushes on 'what happens when you revoke someone's access' — the honest answer is that it depends entirely on where the permission lives. If it's baked into a JWT claim at issuance, revocation doesn't take effect until that token expires, because nothing about revoking server-side changed the token's signature. I'd either keep access tokens short-lived — 15 minutes is a common default — so the staleness window is small, or move the authorization check itself out of the token and into a server-side lookup checked fresh on every request, which trades a small latency cost for instant revocation. Which one I pick depends on how sensitive instant revocation actually needs to be for this system — a banking app needs the live lookup; a low-stakes internal tool can tolerate a 15-minute staleness window."

### ⚠️ Traps

- ❌ **Trap:** "If the request has a valid token, it's authenticated, so it's fine to proceed."
  ✅ **Reality:** A valid token proves identity, nothing more. Whether that identity is allowed to do *this specific thing* to *this specific resource* is a completely separate question that a valid token has not answered. Treating "authenticated" as "authorized" is the single most common root cause of broken access control.

- ❌ **Trap:** "The gateway already checks the token on every request, so individual services don't need their own permission checks."
  ✅ **Reality:** The gateway can only do coarse-grained authorization — "can this role call this endpoint at all" — because it doesn't know about the specific resource instance being requested. Only the service that owns the resource can check "does this document belong to this identity." Skipping that check anywhere is exactly how IDOR/BOLA vulnerabilities happen.

- ❌ **Trap:** "401 and 403 are basically interchangeable — just return whichever is easier to implement."
  ✅ **Reality:** They tell the client to do completely different things. 401 means "I don't know who you are — authenticate and try again." 403 means "I know exactly who you are, and the answer is still no — don't bother re-authenticating." Conflating them breaks a client's retry logic and, in privacy-sensitive contexts, can leak whether a resource exists at all.

- ❌ **Trap:** "We use JWTs, so revoking a user's access is instant — we just stop issuing new tokens with that permission."
  ✅ **Reality:** Every already-issued token with the old permission remains cryptographically valid and keeps working until it expires, regardless of what changed server-side. Instant revocation requires either a live server-side check or deliberately short token lifetimes — it is never a property JWTs give you for free.

### ✅ Checkpoint — adversarial stress test

1. You've designed a document-sharing system using RBAC (owner/editor/viewer roles within a workspace) plus a per-document ownership check. The interviewer pushes: *"A user is removed from a workspace — their role is deleted server-side. They still hold a JWT issued ten minutes ago with `role: editor` baked into its claims, and it doesn't expire for another twenty minutes. Walk me through exactly what happens if they call `PATCH /documents/{id}` on a document in that workspace during those twenty minutes, and tell me precisely what you'd change about the design so removal takes effect immediately instead of waiting for token expiry."*

   > 💡 *This is the gate. A complete answer covers: with role claims baked into the JWT, the request WILL succeed during the remaining token lifetime — the signature is still valid, and the server has no mechanism in this design to know the role was revoked, because authorization was being read directly off the token instead of checked against current state. It names the fix precisely: either (a) don't embed role/permission claims in the JWT at all — use the JWT only for identity, and check the current role via a server-side lookup (session store, database, or policy engine) on every request, trading a lookup cost for instant revocation, or (b) keep short-lived access tokens (e.g. 5 minutes) with a refresh flow, bounding the staleness window instead of eliminating it, which is a legitimate answer ONLY if the interviewer accepts a bounded-but-nonzero window as acceptable for this system's risk profile. A complete answer states which of the two it's choosing and why, rather than describing both and refusing to commit.*

MODEL ANSWER — §8 Adversarial Stress Test (JWT staleness vs. workspace removal)

```
WHAT HAPPENS DURING THE 20-MINUTE WINDOW
  The PATCH request succeeds. The JWT's signature is cryptographically
  valid — nothing about deleting the workspace role changed the token
  itself — and if authorization is implemented as "trust the role claim
  in the token," the server has literally no signal that anything changed.
  This is the exact failure mode from §6's "stale permissions" edge case,
  now forced to a concrete, timed scenario.

WHY THIS IS A DESIGN CHOICE, NOT A JWT FLAW
  JWTs are not broken here — they are doing exactly what they're built to
  do: prove a claim was true AT ISSUANCE, verifiable without a server
  round trip. The bug is using that property (stateless verification) for
  data (authorization) that needs to be current, not just once-true.

THE FIX — COMMIT TO ONE
  Option A (live lookup): strip role/permission claims out of the JWT
  entirely. The JWT proves identity only. Authorization re-checks the
  CURRENT role from a server-side source (session store, DB, or a policy
  engine like OPA) on every request. Removal takes effect on the very
  next request — no window at all. Cost: a lookup on every authorization
  decision, reintroducing some of the latency JWTs were meant to avoid.

  Option B (bounded staleness): keep role claims in the JWT, but shrink
  access-token lifetime to something small — 5 minutes is a common
  choice — paired with a refresh-token flow. Removal takes effect within
  one token lifetime, not immediately. Cost: more frequent re-issuance
  traffic, and a NONZERO window during which a removed user can still act.

WHICH ONE — AND WHY IT MATTERS
  For a document-sharing system, Option A is the safer default: workspace
  removal is a security-sensitive event (the whole point of removing
  someone is usually because they shouldn't have access anymore, right
  now), so a live lookup is worth its latency cost. Option B is acceptable
  only if the interviewer explicitly signals that a short, bounded window
  is tolerable for this system's threat model — never as an unexamined
  default.
```

> **→ Next:** Can you combine what you've learned across sections, not just recall each one?

---

## 9. 🧪 Mastery Gate

> *Synthesis only. Each question must require combining two or more sections.*

1. **(§5 + §6 + 3.4)** A junior engineer argues that embedding a user's full permission set directly into the JWT (instead of just their identity) is strictly better, because it means the resource layer never needs a database lookup to authorize a request. Using the build chain from §5 and the stale-claims failure mode from §6, explain exactly what this trades away, and name the specific production scenario where that trade becomes a real security incident, not a theoretical concern.

2. **(§7 + §8, applied to a system not mentioned elsewhere in this doc)** You're designing access control for a hospital's electronic health records system, where a doctor should be able to read and write records for patients currently under their care, a nurse should be able to read (but not write) the same records, and a billing clerk should be able to read only the billing-relevant fields of any patient's record, never clinical notes. Decide which policy model(s) this requires, and justify why plain RBAC (doctor/nurse/billing-clerk roles alone, with no resource-level or field-level nuance) is or isn't sufficient here.

3. **(§4 + §6 + §8)** An interviewer asks you to explain, end to end, how a request to `DELETE /workspaces/{id}/members/{user_id}` should be authorized in a multi-tenant SaaS product, where only a workspace's owner (not just any admin) can remove another member, and a member can always remove themselves. Walk through what gets checked, in what order, and what specifically would go wrong if the check only verified "is the caller an admin of some workspace" rather than "is the caller the owner of THIS workspace, or removing THEMSELVES."

### Mastery criteria — tick only what you can demonstrate on demand

- [ ] Can explain the difference between authentication (who are you?) and authorization (what can you do?) and give a concrete example of each failing independently
- [ ] Can name and explain broken object-level authorization (IDOR/BOLA) as the concrete failure mode of skipping resource-level authorization
- [ ] Can choose between RBAC, ABAC, and ReBAC for a novel domain and justify the choice against how permission actually varies (by role alone, vs. by resource/relationship)
- [ ] Can explain why authorization must be re-checked at every enforcement layer while authentication can be centralized at the edge
- [ ] Can explain the revocation trade-off between JWT-embedded permission claims and a live server-side authorization lookup, including at least one concrete mitigation
- [ ] Can correctly distinguish 401 from 403 and justify which one applies to a given failure scenario

> 💡 **Rule of thumb:** If you can teach it to someone else and field their follow-up questions, you've mastered it.

---

## 10. 🔗 Connections & Sources

**Builds on:** **3.2 Session Management Approaches**, which supplies one of the two concrete mechanisms (server-side session lookup) that authentication in this subtopic actually relies on to establish identity. **3.4 JWT as Stateless Session Token**, which supplies the other mechanism (signature verification with no server round trip) and, critically, the exact statelessness trade-off (3.4's payoff) that resurfaces here as the stale-permissions security problem in §6 and §8.

**Enables:** **23.2 OAuth2**, the delegated-authentication mechanism for letting a third party authenticate a user on your behalf, which still requires this subtopic's separate authorization step once the OAuth token is validated. **23.3 JWT — Structure, Signing, Validation, and Security Pitfalls**, the deep dive on the exact token mechanics this subtopic used at a conceptual level. **23.4 RBAC — Roles, Permissions, Policy Enforcement Points**, the full depth treatment of the policy model introduced here in §5 and §7. **11.7 API Gateway Patterns**, where the edge-level authentication and coarse-grained authorization described in §6's enforcement-points diagram get implemented concretely.

**Tension with:** **3.4 JWT as Stateless Session Token** directly, on the statelessness-vs-revocability axis — the exact property that makes JWTs attractive (no server-side lookup) is the exact property that makes authorization decisions embedded in them impossible to revoke instantly, and neither is strictly better, only better for a given staleness tolerance. Also **4.6 Sticky Sessions** — a live, server-side authorization lookup pulls a system back toward needing consistent, current state per request, in tension with the horizontally-scalable statelessness that sessions and load balancing (Phase B) were built to achieve.

### 📚 Further reading

- [ ] **OWASP API Security Top 10 (2023)** — https://owasp.org/API-Security/editions/2023/en/0x11-t10/ — API1: Broken Object Level Authorization, ranked #1; read this one entry closely, it is the concrete failure mode this whole subtopic exists to prevent
- [ ] **Google — "Zanzibar: Google's Consistent, Global Authorization System" (2019)** — https://research.google/pubs/pub48190/ — the relationship-based access control model referenced throughout §5–§7; read the tuple model (`object#relation@user`), skip the consistency-protocol internals
- [ ] **AWS IAM — Policy Evaluation Logic** — https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html — the authoritative source for the explicit-deny-overrides-allow rule referenced in §7
- [ ] **NIST — Role Based Access Control (RBAC) standard, INCITS 359-2004** — https://csrc.nist.gov/projects/role-based-access-control — the formal definition of RBAC referenced in §5 and §7
- [ ] **Auth0 — "Authorization Policies: RBAC vs. ABAC"** — https://auth0.com/docs/manage-users/access-control — a practitioner-level comparison of the two policy models covered in §7's decision tree
- [ ] **Open Policy Agent (OPA) documentation** — https://www.openpolicyagent.org/docs/latest/ — the centralized-policy-engine pattern referenced in §7's "In production" table

---

## 11. ✍️ My Notes

> *Personal observations, model answers from drilling sessions, things that confused me.*
