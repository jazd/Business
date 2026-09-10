---
name: business-sites
description: >
  Build multi-domain public websites on the Business NoCRUD schema (PostgreSQL
  0.2.11+): browser sessions, anonymous work before email, claim by email,
  mailing lists, paid membership, mail restore tokens, path-bound secrets.
  Use when creating a new HTTP site, signup, login-by-email, subscriptions,
  cookies, localStorage identity, or /business-sites. Not for quotes, invoices,
  or shop books (use /business-bookkeeper).
user-invocable: true
metadata:
  short-description: "Multi-site sessions, lists, and subscriptions"
---

# /business-sites — Multi-domain web identity on Business

**Audience:** Grok Build, skills, and other agents implementing **public HTTP
sites**. This file is **not** customer copy. Do not paste it onto HTML or mail.

**Requires Business 0.2.11** (`PostgreSQL/0.2.10-0.2.11.sql`). 0.2.10 has
Session / SessionToken / lists but **not** SessionPath, ClaimSession,
SessionToken.type, Path.port, PathPassword, or the report views below.

**PostgreSQL only** for the session join (`SetSession`, `ClaimSession`,
`AnonymousSession`). SQLite has Bash helpers for Path / IndividualPath /
SessionPath / PathPassword; it does **not** replace SetSession.

Shop books, quotes, invoices: **`/business-bookkeeper`**. Do not mix those
flows into this skill unless the user asked for both.

Worked SQL: `Sample/SQL/Session/Client.sql`. Diagram: `diagrams/web_session.png`.

---

## What you are building

One official join, reused on every host:

```text
browser token
  → SessionToken (site via SiteApplicationRelease, type session|mail|trial)
  → Session
  → SessionCredential (fromAddress, referring Path, optional Credential)
  → Credential → Individual + Email
  → lists (Pro / Terms / product set)
  → SessionPath (anonymous) then IndividualPath (after claim)
```

**Do not** add per-site `*_session`, view-key, or email-keyed tenant tables for
identity. Product telemetry (feature counters, throttle flags, TLS probe
cache, vendor webhook event ids) may live in the **application** schema. That
is not the same kind of fact as a party, a bill, or a session.

---

## NoCRUD (non-negotiable)

1. Procedures write; **views** read.
2. Append; end a current fact with `stop` / `unlist` / `revoked`. Do not DELETE
   user-typed emails, hosts, URLs, or list history.
3. Do not UPDATE those values in place. NULL → timestamp on `stop`/`timeout`/
   `revoked` is the allowed “end or fill this version” write.
4. Find-or-insert via `Get*` / `Set*` / `ClaimSession` / `ListSubscribeEmail`.
5. Do **not** `CreateIndividual()` on first anonymous page view. Anonymous
   work hangs on **SessionPath** until `ClaimSession`.
6. Do **not** store user hosts or webhook URLs in `SessionToken.items` (bytea
   bag). Use Path / SessionPath / IndividualPath.
7. `Word.value` is **varchar(25)**. Site names, list names, list sets, and
   SessionToken types must fit. Hostnames longer than 25 are **Path.host**
   (varchar 96), not Word.

---

## Widths and Path.port (0.2.11)

| Column | Type | Notes |
|--------|------|--------|
| `SessionToken.token` | varchar(128) | Cookie, UUID, or mail key. Unique with SAR. |
| `Path.host` | varchar(96) | DNS host **without** `:port` |
| `Path.port` | smallint NULL | NULL means 80 (insecure) or 443 (secure). Set only when not the default. |
| `Email.host` | varchar(96) | Domain part of the mailbox |

`GetPath(protocol, secure, host, value, get, port)` and `GetURL(secure, host,
value, get, port)` take **`inPort`**. Do not put `example.com:8443` in
`Path.host`.

**`Path.value` has no leading `/`.** The URL view is
`https://host[:port]/` **plus** `value`. Passing `r.URL.Path` (`/t/abc`)
stores `https://host//t/abc`. Strip leading slashes; empty path → NULL
(homepage `https://host/`).

```sql
-- https://example.com/           (port NULL, value NULL)
SELECT GetURL(1, 'example.com', NULL, NULL);
-- https://example.com:8443/foo     value is 'foo', not '/foo'
SELECT GetURL(1, 'example.com', 'foo', NULL, 8443);
-- amqps://broker.example.com:5671/
SELECT GetPath('amqp', 1, 'broker.example.com', NULL, NULL, 5671);
```

Older 1-arg `GetURL` / `GetPath` still exist (port NULL).

---

## One product on one host (bootstrap)

Do this once per public site before serving traffic. Names are **examples**;
replace with the real product and apex.

| Fact | How |
|------|-----|
| Site | `Site.name` → Word. Use a **short** host label ≤ 25 chars (usually the apex without `www.`). There is **no** `GetSite(varchar)` procedure yet: `GetWord(host)` then find-or-insert `Site` (same Dual/LEFT JOIN shape as `GetApplication`). |
| Application | `GetApplication('Example')` |
| ApplicationRelease | `GetApplicationRelease(application, NULL)` until you seed a real Release |
| SiteApplicationRelease (SAR) | find-or-insert `(site, applicationrelease)` — this integer is passed to every `SetSession` |
| List name | Word: product name ≤ 25 (`Example`) |
| List sets | `Pro`, `Terms`, plus one product set (`Watch`, `Webhook`, `Feature notify`, …). `GetWord` creates them on first subscribe. |

Several products may share one DNS apex: each still gets its **own** Site
and/or Application + SAR + list name. Do not reuse another product’s SAR.

Cookie / `localStorage` name is application-owned (`ex_sid`). Token string is
what Business stores.

---

## Token types (SessionToken.type → Word)

| Word id | value | Use |
|---------|-------|-----|
| 18 | `session` | Browser cookie or localStorage. NULL type on old rows means this. |
| 19 | `mail` | Mailed restore link. Prefer `timeout` NULL (does not expire). |
| 20 | `trial` | Time-limited mailed token. Set `SessionToken.timeout` to seconds from `created`. |

Pass `inType` on **insert** of a new token (`SetSession(..., inType)`). An
existing token is not rewritten; `SetSession` only touches `Session.touched`
and may append `SessionCredential`.

There is **no** `SetSessionTimeout` procedure. Filling NULL timeout is
allowed:

```sql
UPDATE SessionToken
   SET timeout = 172800   -- 2 days, example
 WHERE token = $1
   AND siteApplicationRelease = $2
   AND timeout IS NULL;
```

Do not overwrite a non-NULL timeout in place.

Mint tokens as **unguessable** random strings (32–128 chars). Unique is
`(token, siteApplicationRelease)`. `ClaimSession(token, email)` looks up token
**without** SAR (`LIMIT 1`); do not reuse the same token string on two sites.

---

## Request cycle (every HTTP hit that needs identity)

1. Read cookie / `localStorage` / `Authorization`. If missing, generate a
   token and Set-Cookie (HttpOnly if the app can; `localStorage` is JS-visible).
2. Resolve client IP (honor `X-Forwarded-For` only from your proxy).
3. Optional: `GetURL` for the referring / request URL (https, host, path, get, port).
4. `SetSession(token, SAR, agentString, credential, referring, ip, location [, start] [, type])`
   - First hit: `credential` NULL, `type` `'session'` or NULL.
   - Returns `session.id`.
5. Load identity from views (not ad-hoc joins) when you need email/plan:

```sql
SELECT s.individual, s.email, s.tokenType, s.credential, w.value AS site
FROM IndividualSessions s
JOIN site st ON st.id = s.site
JOIN word w ON w.id = st.name
WHERE s.token = $1 AND s.site = $2
LIMIT 1;
```

Do **not** use `IndividualSessions.siteName`. `Site.name` is a **Word** id;
that column joins Sentence by the same integer and collides with unrelated
sentences. Always `site` → `word`.

Anonymous browsers **will not** appear in `IndividualSessions` (no
credential). They still have a `Session` / `SessionToken` / `Sessions` row.

Call `SetSession` on each relevant request so `touched` moves. Same idea as
the sample: keep the session alive.

`AnonymousSession(...)` is the older UA-parser path **without** a token. Prefer
**token + SetSession** for new sites. Use AnonymousSession only if you must
log a hit before a cookie exists.

---

## Anonymous work before email (SessionPath)

If the user can add data (hosts, a webhook destination, a draft) **before**
typing an email:

```sql
SELECT SetSessionPath(sessionId, 'Watch', pathId);
-- latest unstopped per session+type:
SELECT session, type, path, host, url FROM SessionURL WHERE session = $1;
SELECT session, type, path, url FROM SessionPaths WHERE session = $1;
```

`StopSessionPath(session, type, path)` sets `stop` on the current row only.
Partial unique: `(session, type, path) WHERE stop IS NULL`.

Cap (e.g. 3 free items) is **application** logic: count unstopped SessionPath
or IndividualPath of that type. Do not DELETE the oldest row to make room;
`Stop` it or ask the user to stop one.

---

## Claim (signup, checkout, restore)

```sql
SELECT ClaimSession(sessionId, 'user@example.com');
-- or
SELECT ClaimSession('the-browser-or-mail-token', 'user@example.com');
```

`ClaimSession` does **not** subscribe to lists. It:

1. `GetIndividualEmail` (creates Individual + IndividualEmail if needed)
2. Ensures an unrevoked Credential (individual + email)
3. `SetSession` on each token of that session (writes IndividualSessionCreated)
4. Copies each **unstopped** SessionPath → `SetIndividualPath` (does **not**
   stop or delete SessionPath)
5. Returns `individual.id` (NULL if session/email missing)

Idempotent: a second claim of the same email+session succeeds as a no-op.

Then the **site** subscribes:

```sql
SELECT ListSubscribeEmail('Example', 'Watch', 'user@example.com');
SELECT ListSubscribeEmail('Example', 'Terms', 'user@example.com');
-- paid:
SELECT ListSubscribeEmail('Example', 'Pro', 'user@example.com');
-- cancel paid:
SELECT ListUnSubscribe('Example', 'Pro', individualId);
```

Current members: view `List` (`unlist IS NULL`). History including stopped:
view **`SiteMembership`** (`unlist` populated). Never use only `List` when you
need “were they Pro last month.”

Paid vs free is **list set `Pro`** (or your set name). Do not add a
subscriptions table that duplicates lists. Stripe customer ids, if any, are
application data — not required for plan.

---

## Mail restore / change browser

Issue a **new** SessionToken on the same SAR with the credential already set:

```sql
-- type mail, no timeout = durable list link
SELECT SetSession($mailToken, $sar, $agent, $credential, $referring, $ip, $location, NULL, 'mail');
```

On click, either:

- **Adopt:** Set-Cookie to the mailed token (this browser **is** that session), or
- **Bind:** `ClaimSession(existingBrowserToken, email)` so this anonymous
  session gains the credential and copies SessionPath.

Keep `/t/{token}` and `/l/{token}` as **application routes**. Business only
stores the token string. Do not invent a second view-key table.

Trial: type `'trial'` and fill `timeout` once. Application rejects the token
when `created + timeout seconds` is past.

---

## Paths the person owns (after claim)

```sql
SELECT SetIndividualPath(individualId, 'Watch', pathId);
SELECT StopIndividualPath(individualId, 'Watch', pathId);

SELECT individual, type, path, host, url FROM IndividualPaths
 WHERE individual = $1;           -- unstopped
SELECT * FROM IndividualPathHistory WHERE individual = $1;
SELECT * FROM IndividualURL WHERE individual = $1;
```

Type `'Home'` is Word 10 (seeded). Product types (`Watch`, `Webhook`) are
created by `GetWord` on first `Set*Path`.

---

## Path-bound secrets (PathPassword)

Public webhook URLs, signing secrets, and similar hang on **Path**, not on a
tenant table.

1. `GetURL` / `GetPath` for the public URL (`Path.value` may hold the public id).
2. Insert `Password` (`value` = secret; `revoked` NULL). Never commit secrets.
3. `SetPathPassword(pathId, passwordId)`.
4. Rotate: `RevokePathPassword` then Set a new Password + SetPathPassword.

Unique unrevoked is **`(path, password)`**, so more than one live secret per
path is allowed (overlap during rotation). Application picks the current one
(latest `created` where `revoked IS NULL`). There is no one-secret-per-path
unique.

Inbound vendor events (Stripe event id, etc.) are **application** tables, not
Business.

---

## Reports (same SQL on every site)

Filter in `WHERE`; do not bake a product name into a new view.

| View | What |
|------|------|
| **IndividualSessions** | Individual ↔ session, token, tokenType, site, email, credential, touched. Omits anonymous hits. **Ignore `siteName`** (Word vs Sentence); join `site`+`word`. |
| **Sessions** | Hit log including anonymous SessionCredential |
| **SiteMembership** | individual, email, listNameValue, listSetValue, **unlist**, created (from ListIndividual, not the current-only `List` view) |
| **IndividualPaths** / **IndividualPathHistory** | Person-owned URLs |
| **SessionPaths** / **SessionPathHistory** / **SessionURL** | Anonymous session URLs |
| **List** | Current list members only |

Do not `SELECT` mailbox values into git, chat, or public pages unless the
operator asked for that row.

---

## What stays in the application (not Business)

| Need | Where |
|------|--------|
| Feature counters, 429 throttle flags | App table (append-only). Session use-from-address is already SessionCredential. |
| TLS/probe observations, “already mailed 30/14/7/1” | App table keyed by Path id and/or individual |
| Vendor event ids (webhooks) | App table keyed by Path id |
| HttpOnly cookie flags, CSRF, rate limits | App |
| HTML / legal copy / Stripe Checkout | App. Public pages never name schema tables. |

---

## New site — code framework (do this)

When asked to create a new site, produce a small HTTP service that **only**
talks to Business through procedures and the views above. Go is a good default
(one shared session package, many hosts). Python is fine if the rest of the
product is Python; still call the same SQL.

Suggested layout (names are local):

```text
cmd/<site>/main.go          # bind, env, Serve
internal/session/           # Identify, Claim, lists, mail token
internal/http/              # routes, cookies
```

**Env (no secrets in git):** `PG*` to the Business database, public base URL,
cookie name, Secure flag.

**Minimum routes:**

| Route | Behavior |
|-------|----------|
| Any HTML / API | `Identify`: cookie token → `SetSession` → JSON `{plan, email?, terms?}` from lists + IndividualSessions |
| `POST /api/watch` or product equivalent | `GetPath`/`GetURL` + `SetSessionPath` while anonymous; after email, `SetIndividualPath` |
| `POST /api/signup` | email + token → `ClaimSession` + `ListSubscribeEmail` (product set + Terms if they checked) |
| `POST /api/checkout` success / webhook | `ListSubscribeEmail(..., 'Pro', email)`; optional ClaimSession if cookie present |
| `POST /api/cancel` | `ListUnSubscribe(..., 'Pro', individual)` |
| `POST /api/restore` | if already Pro (or has product list), mint mail token, send link; generic 200 so you do not leak membership |
| `GET /t/{token}` or `/l/{token}` | Adopt cookie and/or ClaimSession bind |

**Identify algorithm:**

1. Token from cookie else new random (32–128 chars).
2. `SetSession(token, sar, …, type 'session')`.
3. Plan = `Pro` if `SiteMembership` (or `List`) has list set Pro and `unlist` IS NULL; else free.
4. Caps from plan (application constants), counts from `IndividualPaths` /
   `SessionPaths`.

**Tests:** ClaimSession copies SessionPath; second claim does not duplicate
unstopped IndividualPath; Stop then Set is a new row; mail token type is
`mail`; Pro unlist hides paid UI.

**Do not** start from a 0.2.10 database. Apply `PostgreSQL/0.2.10-0.2.11.sql`
as the Business role (not a superuser for app objects) or install fresh 0.2.11.

The hop `SET search_path TO business, public` and checks `pg_namespace =
'business'`. If tables already live in **`public`** (common when the database
is named `business` but objects were created on `public`), run the hop with
`search_path` `public` and treat the version check as `schemaversion` 0.2.10,
not the namespace name.

`ALTER COLUMN` on `Email.host` / `Path.host` fails while views depend on
those columns (`EmailAddress`, `URL`, `File`, …). The hop drops and
recreates the official views. Extra app views on those columns must be
dropped first, then rebuilt.

`psql` without `-q` prints `INSERT 0 1` next to `RETURNING id`. Use
`psql -qAt` (or parse the last **digit** line) when capturing new ids.

---

## Anti-patterns

- Sidecar `site_session(uuid, email)` when ClaimSession exists.
- `CreateIndividual()` on first GET /.
- Host:port stuffed into `Path.host` after 0.2.11.
- Leading `/` on `Path.value` (double slash in the URL view).
- `IndividualSessions.siteName` as the DNS host (join `site`+`word`).
- Site / list names longer than 25 characters (use Path.host for FQDNs).
- DELETE of watches to enforce a free cap.
- Treating `List` as history (stopped Pro disappears).
- Putting Stripe or TLS probe columns on Path or Individual.
- Promoting feature-throttle logs into Business.
- Customer HTML that mentions SessionToken, SAR, or this skill.
- Reusing one SAR across two public hosts.
- Same token string on two SiteApplicationReleases (ClaimSession token lookup
  is not SAR-scoped).

---

## Process (QA / deploy smoke)

`Process` / `Step` / `ProcessStep` / `ProcessRun` / `ProcessRunResult` are
the PCB/assembly QA tables (`schema.xml` order 850, comments “untested”).
There are **no** writer procedures. Use them to record a named checklist
(site smoke, hardware test) without inventing a stats table.

| Table | Fact |
|-------|------|
| **Process** | `name` → Sentence (`GetSentence`). Optional description / version. |
| **Step** | `name` → Sentence. One checklist item. |
| **ProcessStep** | Process + Step + `sequence`. Seed once (idempotent on process+sequence). |
| **ProcessRun** | One execution. `assembly` → **Part** (`GetPart` then `GetPartbySerial` for a unique serial). `tester` → **AssemblyApplicationRelease** (`GetPart` + `GetApplicationRelease` + `GetAssemblyApplicationRelease`), **not** SiteApplicationRelease. `supervisor` Individual optional. |
| **ProcessRunResult** | `run`, `processStep`, `pass` / `marginal` / `failure`. Append only. |

Word names for Application/Part must fit varchar(25). Sentence names can be
longer. Insert Process/Step with Dual/LEFT JOIN so a second seed is a no-op.
Do not DELETE runs.

---

## Procedure cheat sheet (PostgreSQL)

| Call | Role |
|------|------|
| `GetWord` / `GetEmail` / `GetIndividualEmail` | Words, mailbox, person |
| `GetApplication` / `GetApplicationRelease` | App + release |
| `GetPath` / `GetURL` | Path id (`inPort` on 0.2.11) |
| `SetSession` | Cookie token ↔ session; optional credential + type |
| `SetSessionPath` / `StopSessionPath` | Anonymous paths |
| `SetIndividualPath` / `StopIndividualPath` | Claimed paths |
| `ClaimSession` | Email owns this session |
| `ListSubscribeEmail` / `ListUnSubscribe` | Membership |
| `SetPathPassword` / `RevokePathPassword` | Secret on a Path |
| `AnonymousSession` | Optional UA-parsed hit without a token |

---

## Related

- `/business-bookkeeper` — parties, lists (shop), books, bills
- `/contribute-pr` — PRs into jazd/Business `develop`
- `Sample/SQL/Session/Client.sql`
- `Sample/PostgreSQL/Go/business/session.go` — older AnonymousSession helper
- `PostgreSQL/procedures.d/70-session.sql`, `40-contacts.sql`, `50-lists.sql`
- `PostgreSQL/0.2.10-0.2.11.sql` — 0.2.10 → 0.2.11 hop
- Wiki Sessions (human); this skill wins on 0.2.11 identity for agents
