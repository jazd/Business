# Getting started — Business schema + Grok Build

This guide is for people who are **new to this schema** and **new to Grok Build**.  
Goal: clone (or open a release), launch Grok, and start recording **customers, quotes, invoices, inventory-style bills, books, and lists** with Grok as your clerk and bookkeeper.

**Alpha software.** The design may change. Snapshots make experiments easy to undo.

---

## Fastest path (recommended)

You **do not have to** copy files or set environment variables. Doing nothing
beyond clone + open Grok is fine.

1. **Clone or open** this repository (or a release unpack that includes `business.sqlite3` and `.grok/skills/business-bookkeeper/`).
2. **Launch Grok Build** with that folder as the workspace.
3. Run **`/business-bookkeeper`** (or just ask business questions — the skill should auto-apply when relevant).
4. Start talking, e.g.  
   *“My company is Acme Widgets. Customer City Library. Quote them 2 Bunny at 14.99.”*

**If you do nothing**, Grok assumes these defaults and bootstraps them:

| Default | Meaning |
|---------|---------|
| Live books | `~/business-shop/business.sqlite3` |
| Snapshots | `~/business-shop/snapshots/` |
| Template | Repo/release `business.sqlite3` (left pristine) |

On first use, if the live shop DB is missing, Grok **copies** the template into `~/business-shop/`, sets `SQLITE_DB`, creates `snapshots/`, and tells you the path.

**If you prefer control**, override anytime (Grok must honor this):

- Set `export SQLITE_DB=/your/path/books.sqlite3`
- Or say: “Use `/data/my-shop.sqlite3` as the database”
- Or copy the template yourself into `~/business-shop/` (or anywhere) before starting  

Existing live files are **not** overwritten by bootstrap.

---

## What you are installing

| Piece | What it is |
|-------|------------|
| **Business schema** | A history-friendly (“NoCRUD”) SQL model: people/companies, parts, bills (wish → cart → quote → order → invoice → receipt), double-entry books, email lists, and more |
| **`business.sqlite3`** | Ready-made SQLite template (schema + **Static/** seeds + GeoNames postal sample + wiki addresses/ledger) — Grok copies this to your live shop path. Rebuild: `make rebuild-business-sqlite3` |
| **Grok skill `business-bookkeeper`** | Instructions so Grok Build uses the schema the intended way |
| **`Bash/sqlite/` scripts** | Command-line helpers for common Get/Put operations against SQLite |
| **Wiki** | Human docs and examples: [Business wiki](https://github.com/jazd/Business/wiki) |

You do **not** need PostgreSQL to get started. SQLite is enough for a one-person shop on a laptop.

---

## Optional: your own path or copies (overrides)

Skip this if you are fine with defaults. Use it to **override** where books live,
or to set up without Grok doing the first copy.

**Layout:**

```text
Business/business.sqlite3     # PRISTINE template (do not write shop data here)
~/business-shop/
  business.sqlite3            # live books
  snapshots/                  # session checkpoints
```

```bash
mkdir -p ~/business-shop/snapshots
cp /path/to/Business/business.sqlite3 ~/business-shop/business.sqlite3
export SQLITE_DB=$HOME/business-shop/business.sqlite3
```

Optional bash PATH:

```bash
mkdir -p ~/bin
ln -sfn /path/to/Business/Bash/sqlite ~/bin/sqlite
export PATH="$HOME/bin/sqlite:$PATH"
```

### First prompts (after bootstrap)

```text
/business-bookkeeper
My company is "Acme Widgets". Customer is "City Library".
Create a quote for 2 units of part "Bunny" at 14.99 each.
Show me the line items.
```

```text
/business-bookkeeper
Record that I paid $100 rent in cash.
Show the journal report.
```

### Demo title: **Grok Build as your small business bookkeeper**

**Tagline:** *Enable Grok Build to do true double-entry accounting!*  
**Skill:** `/business-bookkeeper` (Grok Build skill + Business schema)

**Demo GIFs:**

| Demo | File |
|------|------|
| Wikipedia books (Rent/Sale/… journal) | [`docs/grok-build-bookkeeper-demo.gif`](./docs/grok-build-bookkeeper-demo.gif) |
| Parts → order → invoice PDF → pay | [`docs/grok-build-invoice-commerce-demo.gif`](./docs/grok-build-invoice-commerce-demo.gif) |

Rebuild commerce GIF: `python3 scripts/build_invoice_commerce_demo_gif.py`

Short **books** script based on Wikipedia  
[Debits and credits — Further examples](https://en.wikipedia.org/wiki/Debits_and_credits#Further_examples):

```text
/business-bookkeeper
We paid $100 rent with cash.
We received $50 cash for a sale.
We bought $5200 of equipment with cash.
We borrowed $11000 cash as a loan.
We paid $5000 in salaries with cash.
Show me the journal report — do debits equal credits?
Now in Spanish.
Now in French.
```

Short **commerce** script (invoice PDF lands under `~/business-shop/invoices/`):

```text
/business-bookkeeper
Add products Widget-A 1.0 and Gadget-B 2.0 under Product/SKU.
City Library orders 3 Widget-A at 12.50 and 1 Gadget-B at 49.
Turn the cart into a quote, order, and invoice.
Create a PDF invoice.
Record full payment (receipt / AR Payment).
Show the journal — sales and cash.
```

Invoice PDF **limitations** (tax $0, no logo, no email-send, …) are listed in  
`.grok/skills/business-bookkeeper/references/document-recipes.md` — fill gaps when someone needs them.

Expected: **Total** debit **21350** / credit **21350** (balanced books), then the same totals with Spanish and French account/type names (wiki Accounting I18N).

---

## Mental model (5 minutes)

### NoCRUD (why it feels different)

- Prefer **adding** new rows over editing the past.
- Ending a relationship often means setting a **`stop`** time, not deleting history.
- **Get\*** helpers mean “give me the id; insert if missing.”
- **Views** (e.g. `LineItems`, `JournalReport`) are the normal way to **read**.

You and Grok should not “UPDATE the invoice line to fix a price” casually — use the quote/invoice/cargo patterns from the wiki.

### Commerce chain (sales paperwork)

From the wiki inventory examples:

```text
Wish → Cart → Quote → Order → Invoice → Receipt (payment)
```

Cargo (line items) **moves** down the chain with `MoveCargoToChild`. Parent lines show `outstanding` falling to zero as children take the quantity.

Sales books on that path (wiki): **AR Sale** when order cargo is booked, **AR Payment** on receipt.

### Parts, BOM, and serial builds

Hardware / product shops also use the **Parts** wiki section:

```text
GetPart categories → GetPartWithParent SKUs → PutAssemblyPart (BOM designators)
  → GetPartbySerial (physical unit) → PutAssemblyPart (serial children)
```

Read with views `Parts`, `Assemblies`, `AssemblyParts`. Skill deep dive:  
`.grok/skills/business-bookkeeper/references/inventory-bom-builds.md`.

Ship / bill of lading headings in the wiki are still stubs — track fulfilment via Order/Invoice cargo for now.

### Accounting

- Named **books** (e.g. Rent, Sale) post balanced journal lines.
- **JournalReport** / **LedgerReport** for statements.
- French/Spanish labels: culture inject (es-MX / fr-FR) then the same report views.

### Lists

Subscribe/unsubscribe people by email to named lists (e.g. newsletter sets) without deleting history.

---

## What to ask Grok (solo business)

| You want… | Example prompt |
|-----------|----------------|
| Customer | “Add customer *Pat Lee*, email pat@example.com” |
| Product / SKU | “Add 4.7k 1% resistor 0603 and 10k same package” |
| BOM | “Create PCB assembly *Alarm* Demo 1.0.0 and put Arduino Nano on A1, 1k on R4…” |
| Serial build | “Register board serial *10001* with MCU serial … on U1” |
| Quote | “Quote City Library 5 Bunny at 14.99” |
| Invoice from quote | “Turn that quote into an invoice” |
| Payment | “Record payment / receipt for that invoice” |
| Vendor PO | “Order 100 of part X from Mouser for our shop” |
| Expense | “Book rent 100 against cash” |
| Report | “Show ledger report” / “Journal in French” / “Show BOM for Alarm Demo 1.0.0” |
| Mailing list | “Subscribe pat@example.com to News/Monthly” |
| Bank CSV (near-term) | “Dry-run import this CSV and propose book entries; don’t write yet” |

More detail: skill **operator card**  
`.grok/skills/business-bookkeeper/references/operator-card.md`

Full agent rules:  
`.grok/skills/business-bookkeeper/SKILL.md`

Worked SQL examples:  
[Business wiki — Examples](https://github.com/jazd/Business/wiki/Examples)

---

## Instructions for Grok Build (agent defaults)

When the user opens this repo (or a release unpack) and starts working, the agent should **not** wait for them to copy files:

1. **Bootstrap** per skill zero-config rules: live DB at `~/business-shop/business.sqlite3`, create from repo `business.sqlite3` if needed, `snapshots/` dir, `PATH` includes `Bash/sqlite`.
2. **Export `SQLITE_DB`** for the session; use it for every `sqlite3` / bash helper call.
3. **Announce once:** “Recording into `~/business-shop/business.sqlite3` (from template …).”
4. Follow **`/business-bookkeeper`** for mutations; snapshot per skill rules.
5. Prefer **bash Get\*/Put\*** when available; for CreateBill / MoveCargo / Book use SQL only if those entry points exist in the SQLite build, otherwise use wiki/PostgreSQL procedures or explain the gap.

---

## Backup, snapshots, and “undo”

This schema is **NoCRUD**: normal operations **append history** (and often set
`stop`) instead of deleting. Grok can usually **compensate** a mistake
(another book entry, soft-stop a price, unsubscribe, etc.) without erasing the past.

For a solo shop, **file snapshots** are still the easy “go back to 10 minutes
ago” tool—especially after experiments or CSV imports.

### Layout

```text
~/business-shop/
  business.sqlite3                 # live books
  business.sqlite3.pristine-0.2.9  # release template restore (optional)
  snapshots/
    20260805-141502-session-start.sqlite3
    20260805-142230-pre-csv.sqlite3
    latest.sqlite3 -> …
```

### Commands Grok (or you) should use

```bash
export SQLITE_DB=$HOME/business-shop/business.sqlite3
SNAP_DIR="$(dirname "$SQLITE_DB")/snapshots"
mkdir -p "$SNAP_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
LABEL=session-start   # or pre-csv, post-invoice, …

# Preferred (safe while DB may be open)
sqlite3 "$SQLITE_DB" ".backup '$SNAP_DIR/${STAMP}-${LABEL}.sqlite3'"

# Restore (ask first unless you ordered it)
cp -a "$SNAP_DIR/${STAMP}-${LABEL}.sqlite3" "$SQLITE_DB"
```

- **Session start / before risky batches / periodic milestones** → snapshot.  
- **Logical undo** when you want the ledger history kept.  
- **Snapshot restore** when you want to drop a whole batch.  
- Never overwrite the **repo** pristine `business.sqlite3` with shop data.

- Keep the release `business.sqlite3` as a **template**; day-to-day work should use **your copy** under `~/business-shop/`.
- Alpha: upgrade paths and schema may change between releases — read release notes.

---

## Going further

| Topic | Where |
|-------|--------|
| Why NoCRUD / procedures / views | [Introduction](https://github.com/jazd/Business/wiki/Introduction) |
| Concepts (people, lists, contacts) | [Concepts](https://github.com/jazd/Business/wiki/Concepts) |
| SQL examples | [Examples](https://github.com/jazd/Business/wiki/Examples) |
| PostgreSQL server install | `README.md`, `make pgsqldb` (Static + GeoNames postal + procedures) |
| Rebuild SQLite template | `make schema.sqlite` then `make rebuild-business-sqlite3` (same seed order as PG, no PL/pgSQL) |
| Implementer rules | `AGENTS.md` (for contributors, not required for shop use) |
| **Submit your improvements as a GitHub PR** | Grok skill **`/contribute-pr`** (clone on Linux → feature branch → PR into `develop`) |

---

## Quick checklist

- [ ] Release/clone includes **`business.sqlite3`** + skill under `.grok/skills/business-bookkeeper/`
- [ ] Grok Build opened on that folder; skill visible (`/skills` or `/business-bookkeeper`)
- [ ] First ask to Grok — agent creates **`~/business-shop/`** and sets `SQLITE_DB` if needed
- [ ] One real task (customer, quote, or book entry) and a report/view check
- [ ] Optional: know that **snapshots/** holds checkpoints

You’re ready when Grok answers “what’s in my database?” by querying **`~/business-shop/business.sqlite3`** (or the path it announced) in plain language.
