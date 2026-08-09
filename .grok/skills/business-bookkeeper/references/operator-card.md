# Operator card — business-bookkeeper

**One-screen cheat sheet** for a solo human + Grok Build.  
**First-time setup:** repo root [`GETTING-STARTED.md`](../../../../GETTING-STARTED.md) (or `references/getting-started.md`).  
Full rules: `../SKILL.md`.  
**Parts / BOM / builds / sales SQL:** [`inventory-bom-builds.md`](inventory-bom-builds.md).  
Wiki: `Business.wiki/Examples.md` (**Parts**, **Inventory Movement**).

## Invoke

- Slash: `/business-bookkeeper` or `/local:business-bookkeeper`
- Menu: `/skills` → enable if listed but inactive
- CWD under the **Business** repo (or user skill under `~/.grok/skills/`)
- **Zero config:** clone → open Grok → start talking. Agent copies template →  
  `~/business-shop/business.sqlite3` if needed (you need not `cp`).  
- **Override:** set `SQLITE_DB` or tell Grok a path; agent honors it and won’t  
  clobber an existing live DB.

## Say this → get that

| You say | System does |
|---------|-------------|
| New customer / company | `GetIndividualEntity` / `GetIndividualPerson` + `GetIndividualEmail` / `SetIndividualEmail` |
| Phone / address on file | `GetPhone` / `GetPostal` / `GetAddress` + `SetIndividualPhone` / `SetIndividualAddress` |
| Show customer card | `DocumentParty <id>` |
| New category / SKU / package / MPN | `GetPart` → `GetPartWithParent` (deep chains as needed) |
| Versioned board / kit | `GetPartWithParentVersion` + `GetVersionName` |
| Add / replace BOM line (R1, U1, …) | `PutAssemblyPart` |
| Remove BOM line / whole BOM | `RemoveAssemblyPart` (sets `AssemblyPart.stop`) |
| Show / export current BOM | `DocumentBOM` / `AssemblyParts` (`stop IS NULL`) |
| Register built unit + chip serials | `GetPartbySerial` + `PutAssemblyPart` serial children |
| Wish / cart / quote / order / invoice / pay | `CreateBill` + `AddCargo` / `MoveCargoToChild` (+ job price + **AR Sale** / **AR Payment**) |
| Buy parts from vendor | `CreateBill(vendor, shop, Order)` + `AddCargo --unit` + `GetBillReference` |
| Export invoice lines | `DocumentLineItems <bill> tsv` |
| Invoice PDF (QB-style) | `InvoicePDF <bill_id>` → `~/business-shop/invoices/` |
| List named books | `ListBooks` |
| Paid rent / cash sale / … | `Book Rent\|Sale\|… <amt>` |
| Credit / return (books) | `Sales Credit`, `AR Sale Credit`, `Equipment Return`, `Supply Return` |
| Manual journal | `Post <debit> <amount> <credit> [date]` |
| Show journal | `JournalReport` |
| Report in French / Spanish | inject culture **1036** / **2058**; clear after |
| Mailing list on/off | `ListSubscribeEmail` / `ListUnSubscribe` |
| Bank CSV (near-term) | dry-run map → Book/Post; approve before write |

## Flow (commerce)

```text
Wish → Cart → Quote → Order → Invoice → Receipt
         MoveCargoToChild (parent → child)
Books:  …………… AR Sale (order) ……… AR Payment (receipt)
```

After every move: re-check **`LineItems`** (parent `outstanding` falls; child rises).

## Flow (engineering inventory)

```text
GetPart categories → GetPartWithParent leaves → PutAssemblyPart BOM
       → GetPartbySerial(board) → PutAssemblyPart serial children (U1/U2/…)
```

## Demo: Grok Build as your small business bookkeeper

**Tagline:** *Enable Grok Build to do true double-entry accounting!*  
**Skill:** `/business-bookkeeper` · Wikipedia:  
`https://en.wikipedia.org/wiki/Debits_and_credits#Further_examples`

Plain language → `Book`, then `JournalReport` (en / es / fr):

```text
Paid $100 rent in cash          → Book Rent 100
Cash sale $50                   → Book Sale 50
Bought equipment $5200 cash     → Book Equipment 5200
Borrowed $11000 cash            → Book Loan 11000
Paid $5000 salaries in cash     → Book Salary 5000
Show the journal / does it balance? → JournalReport
Now in Spanish                  → JournalReport es
Now in French                   → JournalReport fr
# Total debit 21350 = credit 21350 (true double-entry, all three languages)
```

## Environment

| Item | Default / note |
|------|----------------|
| Live DB | `~/business-shop/business.sqlite3` (agent creates from template if missing) |
| Template | Repo/release `business.sqlite3` — never the live write target |
| Bash helpers | `Bash/sqlite/` (link as `~/bin/sqlite`) |
| Postgres | procedures in `PostgreSQL/procedures.d/`; views in schema |
| Money | decimal/`numeric` — not float pennies |
| History | append + `stop`; no DELETE “fixes” |

## Do / don’t

| Do | Don’t |
|----|--------|
| Get\* / CreateBill / MoveCargo / Book / Post | Invent CRUD UPDATE of past truth |
| Read via views | Hand-join base tables unless skilled |
| Soft-stop price/email/list changes | Overwrite invoice unit prices in place |
| Clear culture inject after i18n reports | Leave inject_culture stuck on es/fr |
| Ask before bulk CSV import | Silent chart-of-accounts invention |

## Gaps (honest)

- **Ship / bill of lading:** wiki stubs — use Order/Invoice cargo + `DocumentLineItems` / Tracking `GetBillReference`  
- **Invoice PDF:** tax $0, no logo, terms/due derived, no email-send — see `document-recipes.md`  
- **Qty on hand ERP:** cargo on bills + serial units; no free-floating `on_hand`  
- **Empty serials:** never; only real unit ids  
- **Cargo multi-ship returns:** wiki complicated example still stub — prefer named credit books + careful cargo  

## Demo GIFs

- Books (Wikipedia debits/credits): `docs/grok-build-bookkeeper-demo.gif`  
- Commerce (parts → order → invoice PDF → pay): `docs/grok-build-invoice-commerce-demo.gif`  

## Schema views (commerce)

`BillDocuments` · `InvoiceLineDetail` · `PartyAddresses` · `PartyPhones` · `BillReferences`  
(Prefer over entity-only `Bills` when parties may be people.)

## Deep dives

- [`parties-contacts-books.md`](parties-contacts-books.md) · [`inventory-bom-builds.md`](inventory-bom-builds.md) · [`document-recipes.md`](document-recipes.md)

## Snapshots (easy undo)

NoCRUD can compensate mistakes in-ledger; **file snapshots** undo whole batches.

```bash
SNAP_DIR=~/business-shop/snapshots; mkdir -p "$SNAP_DIR"
STAMP=$(date +%Y%m%d-%H%M%S); LABEL=auto
sqlite3 "$SQLITE_DB" ".backup '$SNAP_DIR/${STAMP}-${LABEL}.sqlite3'"
```

- **When:** session start, before CSV/bulk/experiment, every few major writes, on “checkpoint”  
- **Restore:** `cp -a snapshots/<file>.sqlite3 "$SQLITE_DB"` (confirm with user)  
- **Not** on the pristine repo template  

## Quick verify after a task

1. Names + ids of parties, bills, **assemblies**, **designators**, **serials** as relevant  
2. `AssemblyParts` / `LineItems` / `JournalReport` match the story  
3. One-sentence “next step” (e.g. BOM complete / unit registered / ready to invoice / AR open)  
4. If a snapshot was taken, path noted briefly  

