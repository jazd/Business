---
name: business-bookkeeper
description: >
  Run a solo / micro-business on the Business NoCRUD schema via local SQLite
  (Bash/sqlite scripts) or PostgreSQL procedures and views. Use for quotes,
  invoices, orders, inventory (part catalog, BOM/assembly, serial builds,
  cargo/bills), purchasing, double-entry books and reports (including
  French/Spanish culture), customers/vendors, email lists (subscribe/unsubscribe),
  and near-future bank/CC CSV import into accounts. Triggers: quote, invoice,
  order, cart, wish list, bill of lading, BOM, bill of materials, assembly,
  designator, GetPart, PutAssemblyPart, serial unit, build tracking, inventory
  on hand, bookkeeping, journal, ledger, AR payment, AR Sale, customer, vendor,
  part SKU, price schedule, mailing list, subscribe, unsubscribe, reconcile bank
  CSV, credit card import, accounting report es-MX/fr-FR, /business-bookkeeper.
  Use when the user runs /business-bookkeeper or acts as a one-person shop
  asking Grok Build to be their clerk + bookkeeper (including hardware BOM and
  serialized product builds).
user-invocable: true
metadata:
  short-description: "Solo business: quotes, BOM/inventory, books, lists"
---

# /business-bookkeeper — Solo shop clerk + bookkeeper

**New users (schema + Grok Build):** repo root `GETTING-STARTED.md` — setup,
copy `business.sqlite3` from the release, first prompts.

**Operator card (human one-pager):** `references/operator-card.md` — load for
quick say-this→do-that mapping; keep this file as full agent rules.

**Inventory / BOM / builds / sales deep dive:**  
`references/inventory-bom-builds.md` — load when the user manages parts,
BOMs, serial builds, purchase orders, or Wish→Receipt; keep this file as rules
and the reference as SQL playbooks.

You operate a **very small business** (often one human + Grok Build) on the
**Business** schema. Prefer **procedures / Bash Get\*·Put\*** for writes and
**views** for reads. Do **not** invent classical CRUD overwrites or DELETE of
history.

Canonical product examples live in sibling **`Business.wiki`**
(`Examples.md` **Parts** + **Inventory Movement**, `Concepts.md`,
`Introduction.md`, `Conventions.md`). Prefer those patterns over improvising SQL.

## Environment

| Layer | Role |
|-------|------|
| **SQLite + `Bash/sqlite/`** | Default for local Grok Build sessions (`SQLITE_DB`, scripts on `PATH` via `~/bin/sqlite` → repo `Bash/sqlite`) |
| **PostgreSQL procedures** | Same semantics when the user points at a live Business DB |
| **Views** | `LineItems`, `BillDocuments`, `InvoiceLineDetail`, `PartyAddresses`, `PartyPhones`, `BillReferences`, `JournalReport`, `LedgerReport`, `People`, `Entities`, `List`, `Parts`, `Assemblies`, … |

### Database location: defaults work with zero user setup; overrides always win

Users may **do nothing** (clone + chat) **or** set their own paths / copy the
DB themselves. Support both.

**If the user specifies an override, honor it** — e.g. `SQLITE_DB=…`, “use
`/data/mybooks.sqlite3`”, “keep the DB in the repo under `./shop.sqlite3`”,
or they already created `~/business-shop/` by hand. Do not relocate their DB
or re-copy over an existing live file without asking.

**If they do none of that**, bootstrap defaults yourself (do not block on
manual `cp` instructions unless bootstrap fails).

**Default paths (when nothing is overridden):**

| Role | Path |
|------|------|
| Live books | `$HOME/business-shop/business.sqlite3` |
| Snapshots | `$(dirname "$SQLITE_DB")/snapshots/` (default `~/business-shop/snapshots/`) |
| Pristine template | `$REPO/business.sqlite3` (repo/release; not a live write target unless user insists) |

**Resolve `SQLITE_DB` (once per session before first write):**

1. **User override** — env `SQLITE_DB` set, or an explicit path in the request → use that path.  
   - If the file is missing but a template exists and the user asked to
     initialize there, create parent dirs and copy the template **to their
     path**.  
   - If the file is missing and they did not ask to create it → ask, or offer
     default bootstrap.
2. Else if **`$HOME/business-shop/business.sqlite3`** exists → use it
   (`export SQLITE_DB=…`).
3. Else **zero-config create defaults:**
   - Find template: `$PWD/business.sqlite3`, repo root `business.sqlite3`
     (walk up from cwd), or an obvious release download path.
   - If found:
     ```bash
     mkdir -p "$HOME/business-shop/snapshots"
     cp -a "$TEMPLATE" "$HOME/business-shop/business.sqlite3"
     test -f "$HOME/business-shop/business.sqlite3.pristine-0.2.9" \
       || cp -a "$TEMPLATE" "$HOME/business-shop/business.sqlite3.pristine-0.2.9"
     export SQLITE_DB=$HOME/business-shop/business.sqlite3
     ```
   - **Do not overwrite** an existing `~/business-shop/business.sqlite3`.
4. Ensure `PATH` includes bash helpers when present:  
   `export PATH="$REPO/Bash/sqlite:$HOME/bin/sqlite:$PATH"`.
5. **Tell the user once** which live file you are using (default or override).
6. If no template and no live DB → stop and explain what is missing.

**Never** require the user to run copies when defaults would work.  
**Never** silently overwrite a user-maintained DB with a fresh template.

If scripts are missing for a procedure, use equivalent SQL **only** when it
matches wiki/procedure behavior; say what is unavailable.

## NoCRUD rules (non-negotiable)

1. **Find-or-insert** via `Get*` / `CreateBill` / `AddCargo` / `Book` / `Post` / list subscribe helpers — not “INSERT customer row #1”.
2. **History is append + `stop`**, not UPDATE of past truth (prices, emails, list membership).
3. **Money** is decimal/`numeric` semantics (not float cents games). Quantities may stay float where schema says so (`Cargo.count`, schedule rate bands).
4. **Reads** go through **views** the wiki uses (`LineItems`, `JournalReport`, …).
5. **Culture** for reports: `ClientCulture()` / `inject_culture` (1033 en-US, 2058 es-MX, 1036 fr-FR) — see wiki Accounting I18N.

## Party model (customers & “you”)

- People and companies are **Individuals** (`People` / `Entities` views).
- Resolve parties with `GetIndividualEntity('Name')`, `GetIndividualPerson(...)`,
  `GetIndividualEmail('a@b.c')`, `GetEmail(...)`.
- Contacts: `GetPhone`, `GetPostal`, `GetAddress`, `SetIndividualEmail` /
  `SetIndividualPhone` / `SetIndividualAddress`, `DocumentParty`.
- Wiki pattern: supplier **Bunnies-R-Us**, consignee **Toys for Tots**.

Map user language: “my customer Alice” → entity/person + email + address;
“my company” → supplier entity used on bills.

Deep dive: **`references/parties-contacts-books.md`**.

## Commerce flow (wiki Inventory Movement)

Canonical chain (simple Bunny example in `Examples.md`):

```text
Wish → Cart → Quote → Order → Invoice → Receipt (payment)
         └──── MoveCargoToChild along the parent/child bill tree ────┘
```

Full SQL skeletons and AR books: **`references/inventory-bom-builds.md` § B1**.

| User says | Do this (conceptually) |
|-----------|-------------------------|
| Start a wish list / cart | `CreateBill(supplier, consignee, 'Wish'\|'Cart'[, parent])` |
| Add item / qty | `AddCargo(bill, part, count)` or move from parent |
| Quote from cart | Child bill type **`Quote`**; `MoveCargoToChild` with **price schedule** job |
| Order from quote | Child **`Order`** + move cargo; wiki often books **`AR Sale`** on this move |
| Invoice | Child **`Invoice`** + move cargo (quoted `unitprice` stays; don’t overwrite lines) |
| Pay / receipt | Child **`Receipt`**; move cargo with book **`AR Payment`** |
| Show lines / totals | `InvoiceLineDetail` / `LineItems` / `BillDocuments` for that bill |
| Price list for a customer | `GetIndividualJobSchedule` + `Schedule` bands + `AssemblyIndividualJobPrice` |
| Buy parts from a vendor | `CreateBill(vendor, shop, 'Order')` + `AddCargo` / `AddCargo --unit …` + `GetBillReference` for vendor SO/PO # |
| Attach PO / tracking # | `GetBillReference(bill, 'Sales Order'\|'Tracking'\|…, value)` |

**Bash commerce (SQLite shop):** `CreateBill`, `GetOutstandingBill`, `AddCargo`,
`MoveCargo`, `MoveCargoToChild`, `GetJob`, `GetSchedule`,
`GetIndividualJobSchedule`, `PutAssemblyJobPrice`, `GetBillReference`,
`DocumentLineItems`.

**Books (sales path from wiki):** **`AR Sale`** when order cargo is booked;
**`AR Payment`** on receipt. Catalog: `ListBooks` / `references/parties-contacts-books.md`.
Verify with `JournalReport`.

**Bill of lading / ship / receive:** wiki stubs — **do not invent** BOL tables.
Track fulfilment with Order/Invoice/Receipt + `LineItems`. Customer paper:
**`references/document-recipes.md`** (`DocumentLineItems`, `DocumentParty`,
optional `GetBillReference` Tracking).

Always re-read **`LineItems`** after moves (`outstanding` drops on parent when
cargo moves to child).

## Inventory, BOM, assembly builds & parts

Two layers (do not collapse them):

| Layer | Purpose | Writes | Reads |
|-------|---------|--------|-------|
| **Catalog + BOM + serial builds** | Engineering: hierarchy, designators, physical units | `GetPart*`, `PutAssemblyPart`, `GetPartbySerial` | `Parts`, `Assemblies`, `AssemblyParts` |
| **Commerce cargo** | Sales/purchase documents and qty movement | `CreateBill`, `AddCargo`, `MoveCargoToChild` | `LineItems` |

Load **`references/inventory-bom-builds.md`** for full playbooks and SQL.

| User says | Approach |
|-----------|----------|
| New category / SKU / package / MPN | `GetPart` → `GetPartWithParent(name, version, parentName, parentVersion)`; deep trees may need intermediate GetPartWithParent steps (category → subtype → package → MPN) |
| Versioned product / PCB kit | `GetPart('PCB')` + `GetPartWithParentVersion(name, GetVersionName(...), 'PBC', GetVersionName(...))` |
| BOM / designators (R1, U1, …) | `PutAssemblyPart` / `RemoveAssemblyPart`; list current BOM via **`AssemblyParts`** (`stop IS NULL`) |
| “Natural” refdes order (R2 before R10) | PostgreSQL: optional `natural_sort_key(designator)` helper (see reference); else sort in the agent |
| Serialized unit / build | `GetPartbySerial(assemblyVersion, serial)` then `PutAssemblyPart(id, GetPartbySerial(child, sn), designator, 1)` — **real serial required**, never `''` |
| List builds | `Assemblies WHERE serial IS NOT NULL`; `AssemblyParts` filtered by assembly id |
| “On hand” / stock | Prefer **cargo on bills** (vendor Order, cart, build bills) + serial units; **never** silent DELETE of history or invented `on_hand` tables |
| Wrong parent after GetPart | Prefer `GetPartWithParentNearest` / `GetPartWithAncestor` (PG) over DELETE of Part rows |
| Firmware on a board version | Wiki Application Release + `GetAssemblyApplicationRelease` (advanced) |

**Bash (SQLite):** `GetPart`, `GetPartWithParent`, `GetPartWithParentVersion`,
`GetVersionName`, `GetPartbySerial`, `PutAssemblyPart` when on `PATH`.

If a stock path has no complete wiki walkthrough, state the limitation and stay
on cargo/`LineItems` + assembly views.

## Financial accounting & reports

| User says | Approach |
|-----------|----------|
| Record a simple book entry | `Book <name> <amount>` (bash) or `Book('Name', amount)` (SQL) |
| What books exist? | `ListBooks` — Rent, Sale, Sales Credit, Equipment/Return, Loan/Payment, Salary, Supply/Return, Petty Cash, AR Sale/Credit/Payment, commission books, … |
| Split / commission style | `Book 'Sale Jane Doe' 1000` when seeded |
| Manual journal | `Post <debit> <amount> <credit> [date]` — debit left, credit right |
| Book + show lines | `BookBalance <name> <amount>` |
| Return / credit memo (books) | `Sales Credit`, `AR Sale Credit`, `Equipment Return`, `Supply Return` — not free-form DELETE |
| P&L-ish / T-accounts | `LedgerReport` |
| Journal detail | `JournalReport` (bash or view; order by entry / rightSide) |
| Report in **Spanish / French** | Inject culture **2058** (es-MX) or **1036** (fr-FR), query same views, clear inject after |
| Sale paid on credit then cash | Invoice + Receipt + **`AR Payment`** book |

Prefer **named books** from static General Ledger (`ListBooks`) over inventing account ids.
See **`references/parties-contacts-books.md`**.

### Demo: Grok Build as your small business bookkeeper

**Title:** Grok Build as your small business bookkeeper  
**Tagline:** *Enable Grok Build to do true double-entry accounting!*  
**Skill:** `/business-bookkeeper` (this Grok Build skill; needs the Business schema / shop DB)

Ground truth: [Debits and credits — Further examples](https://en.wikipedia.org/wiki/Debits_and_credits#Further_examples)  
and `Business.wiki` Accounting **Book Entries**. Same five books as seeded: Rent, Sale, Equipment, Loan, Salary.

When the user narrates **ordinary business events** (not accounting jargon), map to `Book` and then show `JournalReport`:

| User-style phrasing (examples) | Execute |
|--------------------------------|---------|
| “We paid \$100 rent in cash” / “Pay rent 100 from cash” | `Book Rent 100` |
| “Customer paid us \$50 cash for a sale” / “Cash sale of 50” | `Book Sale 50` |
| “Bought equipment for \$5200 cash” | `Book Equipment 5200` |
| “Borrowed \$11000 cash (loan)” | `Book Loan 11000` |
| “Paid \$5000 salaries in cash” | `Book Salary 5000` |
| “Show the journal / debits and credits / does it balance?” | `JournalReport` (en-US) |
| “Now in Spanish” / “en español” / “es-MX” | `JournalReport 1 es` (or `JournalReport es`) |
| “Now in French” / “en français” / “fr-FR” | `JournalReport 1 fr` (or `JournalReport fr`) |

Spanish/French labels match wiki Accounting I18N (`es-MX` 2058, `fr-FR` 1036): e.g. Rent→Alquiler/Louer, Cash→Dinero en efectivo/encaisser. Amounts and **Total 21350/21350** stay the same. On PostgreSQL, culture inject (`inject_culture`) also works with the view; on SQLite use **`JournalReport` with culture** (I18N views are fixed to en-US).

**Demo flow for videos/gifs** (open with title + tagline on screen or voiceover):

1. Bootstrap shop DB (defaults).
2. Optional snapshot `pre-wiki-demo`.
3. Accept five natural-language events (wiki order: rent→sale→equipment→loan→salary).
4. Run the five `Book` commands (or SQL `SELECT Book(...)`).
5. “Show the journal — do debits equal credits?” → **JournalReport** (en-US), Total **21350/21350** — prove **true double-entry** (debits = credits).
6. “Now in Spanish” → **JournalReport es** (same numbers, Spanish names/types).
7. “Now in French” → **JournalReport fr**.

Do **not** make the user say “debit expense credit cash”; translate plain language into the named books above. If they use different amounts, still use the matching book names and their amounts; only the classic wiki amounts yield Total 21350.

### Near future: bank / credit-card CSV

When the user wants CSV import/reconcile (not fully productized yet):

1. Inspect CSV headers; map date, amount, payee, memo.
2. Propose **chart mapping**: each distinct payee/memo class → Book name or
   Post(debit, credit) pair; create missing accounts only via schema-legal
   paths (GetWord/Sentence + AccountName/Book if procedures exist—otherwise
   plan + stop for approval).
3. Prefer **import as Book/Post rows** with a clear source memo; do not
   overwrite prior journal lines.
4. Offer dry-run (parse + proposed entries) before write.
5. If tooling is incomplete, produce a reviewable SQL/script plan rather than
   half-importing.

## Email lists (wiki List)

| User says | Approach |
|-----------|----------|
| Subscribe | `ListSubscribeEmail(listName, listSet, email)` |
| Unsubscribe one list | `ListUnSubscribe(listName, listSet, individual)` |
| Show memberships | `List` view for that individual |
| Unsubscribe all | `INSERT INTO ListIndividual (individual) VALUES (...)` with null list id pattern from wiki; clear global unList when re-activating |

Do not “delete list rows”; membership is transactional.

## Document exports (invoices, BOM, packing lists)

Recipes: **`references/document-recipes.md`**. Prefer schema views when reading.

| Need | View / Bash |
|------|-------------|
| Bill header + subtotal | **`BillDocuments`** (entity **or person** names; `invoiceNumber`) |
| Line items (friendly cols) | **`InvoiceLineDetail`** or `DocumentLineItems` |
| Addresses / phones | **`PartyAddresses`**, **`PartyPhones`**, `DocumentParty` |
| PO / tracking on bill | **`BillReferences`** or `GetBillReference` |
| **Invoice PDF (QB-style)** | `InvoicePDF <bill_id>` → `~/business-shop/invoices/` |

**Invoice PDF limitations** (do not oversell): tax always $0, due/terms derived not stored,
no logo, no email-send, Ship/BOL still stubs — full table in
`references/document-recipes.md`. Expand only when a user needs them.

### Demo GIFs

| Demo | File |
|------|------|
| Wikipedia books (Rent/Sale/… → journal en/es/fr) | `docs/grok-build-bookkeeper-demo.gif` |
| Parts → order → invoice PDF → AR payment → journal | `docs/grok-build-invoice-commerce-demo.gif` |

Rebuild commerce GIF: `python3 scripts/build_invoice_commerce_demo_gif.py`

### Findings from building the demos (agent notes)

1. **Seed SQLite like PG** — template must load `Static/` + GeoNames postal + addresses; empty Postal breaks `GetAddress`. Rebuild: `make rebuild-business-sqlite3`.
2. **Classic `Bills` is entity-only** — INNER JOIN `Entities`. Person customers need **`BillDocuments`** (COALESCE entity/person names).
3. **Price schedule before Quote move** — `GetIndividualJobSchedule` + `PutAssemblyJobPrice` (and optional `Schedule` bands); otherwise unit prices stay null.
4. **AR books on cargo move** — Order move with **`AR Sale`** (Receivable/Sales); Receipt move with **`AR Payment`** (Cash/Receivable). Multi-line orders may post one journal entry per cargo line; totals still balance.
5. **PDF is a projection** — source of truth remains Bill + LineItems + Journal; store under **`~/business-shop/invoices/`**.
6. **Contacts before pretty PDF** — set supplier/customer address + email or header is name-only.
7. **PO numbers** — `GetBillReference` uses **GetIdentifier** (Word with culture NULL); list via **`BillReferences`**.
8. **Honest gaps** — tax, logo, stored terms/due, email-send, Ship/BOL — document only; do not invent schema mid-session.

## Other solo-shop asks (handle if schema supports)

- **Contacts:** see parties-contacts-books (GetPhone/Postal/Address + SetIndividual*).
- **Holidays / “are we open”:** `TimePeriod` / Periods (wiki Period).
- **Multi-language labels:** Word/Sentence + culture inject (not only accounting).
- **Application / firmware on a device:** Application Release examples (advanced).
- **Org chart / family graph:** DAG Edges (advanced; usually not micro-retail).
- **Identity / certs for devices:** EST Put\* (PublicKey, CSR, Certificate)—only if user is in that product lane.

## Snapshots and rollback (SQLite sessions)

NoCRUD means most mistakes are **compensated** (soft-stop, reverse Book/Post,
new cargo move)—not deleted. That is correct long-term bookkeeping, but it is
not always the fastest “undo this whole experiment.” For solo Grok sessions,
use **file snapshots** of the live shop DB as a coarse undo stack.

**Live file:** `$SQLITE_DB` (default `~/business-shop/business.sqlite3`).  
**Never snapshot-overwrite the repo pristine template.**

### When to snapshot

1. **Session start** — if the shop DB exists and you will write, take one
   labeled snapshot (or confirm a recent one from today).
2. **Before risky batches** — bank/CC CSV import, bulk subscribe, multi-step
   quote→invoice→pay chains the user called experimental, chart redesign.
3. **Periodic during a long session** — after each major milestone the user
   cares about (e.g. “customer + quote done”, “invoice posted”), or about
   every **5–10 write operations**, whichever comes first. Do not spam a
   snapshot after every single Get\*.
4. **On user request** — “checkpoint”, “backup”, “snapshot”, “save point”.

### How to snapshot

Prefer SQLite’s online backup API (safe if anything has the DB open):

```bash
# SNAP_DIR next to the live DB
SNAP_DIR="$(dirname "$SQLITE_DB")/snapshots"
mkdir -p "$SNAP_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
LABEL="${1:-auto}"   # e.g. session-start, pre-csv, post-quote
sqlite3 "$SQLITE_DB" ".backup '$SNAP_DIR/${STAMP}-${LABEL}.sqlite3'"
# Tell the user the path of the new snapshot.
```

Fallback if `.backup` fails:

```bash
cp -a "$SQLITE_DB" "$SNAP_DIR/${STAMP}-${LABEL}.sqlite3"
```

Optional: keep a moving pointer for “last good”:

```bash
ln -sfn "${STAMP}-${LABEL}.sqlite3" "$SNAP_DIR/latest.sqlite3"
```

### How to roll back

1. Prefer **logical NoCRUD undo** when the user wants history preserved
   (compensating Book, soft-stop price, reverse list sub, etc.).
2. Prefer **snapshot restore** when the user wants to discard a whole batch
   or experiment:

```bash
# Stop writers; then:
cp -a "$SNAP_DIR/<chosen>-.sqlite3" "$SQLITE_DB"
# Or from latest:
cp -a "$SNAP_DIR/latest.sqlite3" "$SQLITE_DB"
```

3. After restore, re-open / re-check `SQLITE_DB` and confirm to the user
   (“restored to snapshot …; last actions after that are gone”).
4. **Ask before restore** unless the user explicitly ordered that snapshot
   name. Never restore onto the pristine template path.

### Retention

- Keep session snapshots under `~/business-shop/snapshots/` (or
  `$(dirname "$SQLITE_DB")/snapshots/`).
- Do not delete old snapshots unless the user asks; if the directory grows
  large, suggest pruning with their OK (e.g. keep last 20 or last 7 days).
- Distinguish **pristine release image**
  (`business.sqlite3.pristine-0.2.9`) from **session snapshots**.

## Agent workflow (every request)

1. **Bootstrap defaults** if needed (zero-config section): ensure live
   `SQLITE_DB=~/business-shop/business.sqlite3`, snapshots dir, PATH to
   `Bash/sqlite`.
2. **Parse intent** into: party, document type (quote/invoice/…), **catalog/BOM/build**,
   inventory cargo, book, list, report, or import. For parts/BOM/serial/sales
   cargo, open **`references/inventory-bom-builds.md`**.
3. **Snapshot** when the rules above say so (start / pre-risk / periodic / asked)—
   especially before bulk BOM lines or multi-step quote→pay chains.
4. **Resolve ids** with Get\* / outstanding bill helpers; print human names + ids
   (and designators / serials when relevant).
5. **Mutate** with GetPart\* / PutAssemblyPart / GetPartbySerial / CreateBill /
   AddCargo / MoveCargoToChild / Book / Post / List\*.
6. **Verify** with views: `AssemblyParts`, `LineItems` / `InvoiceLineDetail`,
   `BillDocuments`, `JournalReport`, …
7. **Summarize** in plain language: what changed, balances/totals, next step
   (“BOM has 40 lines”, “unit serial … registered”, “ready to invoice”, “AR open”,
   “subscribed…”); mention new snapshot path if one was taken.
8. **Stop and ask** before destructive bulk imports, chart redesign, snapshot
   restore, inventing Ship/BOL schema, or anything not grounded in wiki/procedures.

## Bash quick map (local SQLite)

When `Bash/sqlite` is available (`PATH` includes repo `Bash/sqlite` or `~/bin/sqlite`):

| Area | Scripts |
|------|---------|
| Words | `GetWord`, `GetSentence`, `GetIdentifier`, `GetVersionName` |
| Parties | `GetIndividualEntity`, `GetIndividualPerson`, `GetEmail`, `GetIndividualEmail`, `SetIndividualEmail` |
| Contacts | `GetPhone`, `GetPostal`, `GetAddress`, `SetIndividualPhone`, `SetIndividualAddress`, `DocumentParty` |
| Parts/BOM | `GetPart*`, `GetPartbySerial`, `PutAssemblyPart`, `RemoveAssemblyPart`, `DocumentBOM` |
| Commerce | `CreateBill`, `GetOutstandingBill`, `AddCargo`, `MoveCargo`, `MoveCargoToChild`, `GetBillReference` |
| Pricing | `GetJob`, `GetSchedule`, `GetIndividualJobSchedule`, `PutAssemblyJobPrice` |
| Accounting | `Book`, `BookBalance`, `Post`, `ListBooks`, `JournalReport` |
| Documents | `DocumentLineItems`, `DocumentBOM`, `DocumentParty`, **`InvoicePDF`** |
| EST | `PutAssemblyPublicKey`, `PutCertificateSigningRequest`, `PutAssemblyCertificateSigningRequest`, `PutCertificate` |

Default live DB: `SQLITE_DB` → `$HOME/business-shop/business.sqlite3` (override anytime).

## Anti-patterns

- Overwriting invoice unit prices in place; use cargo move + schedule at quote/invoice time.
- DELETE FROM journal / list / individual / **Part** “to fix a mistake” without a
  compensating entry, soft-stop, nearest/ancestor GetPart, or **snapshot restore**.
- Empty serials on `GetPartbySerial` / treating serials as optional for unit tracking.
- Inventing Ship / BOL / on_hand tables or claiming full logistics ERP.
- Restoring a snapshot without telling the user, or writing snapshots over the pristine template.
- Reporting in another language without culture inject.
- Claiming full ERP (payroll, tax filing, multi-entity consolidation) — stay micro-business.
- Putting product-internal extension table names into customer-facing docs or skill copy.

## Reference

- **`references/inventory-bom-builds.md`** — parts taxonomy, BOM, serial builds, sales/purchase, BOL gaps
- **`references/parties-contacts-books.md`** — parties, contacts, named books, returns
- **`references/document-recipes.md`** — invoice/BOM/party exports
- **`references/operator-card.md`** — human one-pager
- Sibling wiki (repo parent or checkout): `Business.wiki/Examples.md` — Language,
  Individuals, Email, List, Period, **Parts**, **Accounting**, **Inventory Movement**,
  Application Release, Sessions, DAG
- `Business.wiki/Concepts.md` — People/entities, lists, contacts
- `Business.wiki/Introduction.md` — Why NoCRUD / procedures / views
- Repo: `Bash/sqlite/`, `PostgreSQL/procedures.d/`, `AGENTS.md` (implementer rules)
