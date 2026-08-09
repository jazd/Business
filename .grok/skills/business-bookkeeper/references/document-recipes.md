# Document recipes (exports, not new schema)

Customer-facing paper and operator TSVs from **views**. These are skill recipes —
not new Business procedures or bill-of-lading tables.

Ship / BOL wiki sections remain stubs; use **Order / Invoice / Receipt** cargo
state plus these exports for packing lists and invoices.

---

## Schema views (all dialects — `schema.xml`)

Prefer these for invoice/PDF/SQL exports (added for commerce demos; portable SQL):

| View | Purpose |
|------|---------|
| **`BillDocuments`** | Wish…Receipt bills with entity **or person** names, `subtotal`, `invoiceNumber` (`INV-` + id) |
| **`InvoiceLineDetail`** | Friendly `LineItems` projection (product, qty, rate, amount) |
| **`PartyAddresses`** | Active addresses per individual + type (Billing/Shipping/…) |
| **`PartyPhones`** | Active phones per individual + type |
| **`BillReferences`** | Active PO / Sales Order / Tracking refs on a bill |

Older **`Bills`** still **INNER JOIN Entities only** — person-only parties need **`BillDocuments`**.  
`InvoicePDF` uses the new views when present, else falls back to Bills/LineItems joins.

PG upgrade: `PostgreSQL/0.2.9-0.2.10.sql`. Fresh SQLite: `make rebuild-business-sqlite3`.

## Bash helpers

| Command | Output |
|---------|--------|
| `DocumentLineItems <bill_id> [column\|tsv\|csv]` | Line items / totals for a bill |
| `DocumentBOM <assembly_part_id> [column\|tsv\|csv]` | Designators for a catalog BOM |
| `DocumentParty <individual_id>` | Name + emails + phones + addresses |
| `InvoicePDF <bill_id> [out.pdf]` | QB-style PDF → `~/business-shop/invoices/` |

```bash
# After invoice stage
INV=$(GetOutstandingBill "$SUP" "$CON" Invoice)
DocumentLineItems "$INV" tsv > /tmp/invoice-$INV.tsv
DocumentParty "$CON" > /tmp/party-$CON.txt

# BOM for assembly version part id
DocumentBOM "$ASM" tsv > /tmp/bom.tsv
```

---

## Invoice pack (operator checklist)

1. Resolve parties (`DocumentParty` supplier + consignee).  
2. Ensure bill is **Invoice** (or **Order** if pre-invoice packing list).  
3. `DocumentLineItems <bill> tsv` → attach or paste into PDF/docx skill if needed.  
4. Optional: query `Addresses` for ship-to type.  
5. Do **not** claim a formal BOL number unless user stores one via  
   `GetBillReference <bill> Tracking '<carrier-tracking>'`.

---

## SQL shapes (any engine)

### Bill header (prefer BillDocuments)

```sql
SELECT bill, documentType, documentDate, supplierName, consigneeName,
       subtotal, invoiceNumber, parent, parentType
FROM BillDocuments
WHERE bill = :bill_id;
```

### Line items

```sql
-- Preferred
SELECT product, description, qty, rate, amount, outstanding
FROM InvoiceLineDetail
WHERE bill = :bill_id
ORDER BY line;

-- Classic
SELECT typeName, consigneeName, line, item, count,
       unitprice, currentUnitPrice, totalPrice, outstanding
FROM LineItems
WHERE bill = :bill_id
ORDER BY line;
```

### Party card

```sql
SELECT * FROM PartyAddresses WHERE individual = :id;
SELECT * FROM PartyPhones WHERE individual = :id;
SELECT * FROM BillReferences WHERE bill = :bill_id;
```

### BOM

```sql
SELECT designator, partname, versionname, quantity
FROM AssemblyParts
WHERE assembly = :assembly_part_id
ORDER BY designator;
```

### Bill references (PO / tracking)

```sql
SELECT br.id, w.value AS type, br.value, br.sequence
FROM BillReference br
JOIN Word w ON w.id = br.type AND w.culture IS NULL
WHERE br.bill = :bill_id AND br.stop IS NULL;
```

---

## PDF invoice (QuickBooks-style)

**Default location:** `~/business-shop/invoices/invoice-<bill_id>.pdf`

```bash
export SQLITE_DB=$HOME/business-shop/business.sqlite3
export PATH="$REPO/Bash/sqlite:$PATH"

# bill_id of an Invoice (or Order) from Bills / GetOutstandingBill
InvoicePDF 5
# → ~/business-shop/invoices/invoice-00005.pdf

InvoicePDF 5 /tmp/custom-name.pdf   # optional path
```

Python entry point: `scripts/invoice_pdf.py` (reportlab). Reads **Bills**,
**LineItems**, party emails/phones/addresses (`Individual*` + **Addresses** /
**Phones**), and **BillReference** (PO / Sales Order).

Optional shop views (not required by the script):  
`sqlite3 "$SQLITE_DB" < SQLite/views-invoice.sql` → `InvoiceDocument`, `InvoiceLineDetail`.

**Layout (QB-like):** company header + green INVOICE title, invoice # / date /
due (Net 30) / balance due banner, Bill To / Ship To, line table
(product, qty, rate, amount), subtotal / tax $0 / total / paid / balance due.

**Before first invoice:** give supplier and customer address + email
(`GetAddress` / `SetIndividualAddress` / `SetIndividualEmail`) so the PDF is not
name-only.

### Invoice / PDF limitations (honest — fill later if demand)

| Limitation | Today | Future if someone needs it |
|------------|--------|----------------------------|
| **Sales tax** | Always **$0.00** on PDF | Tax schedule / line tax fields |
| **Due date / terms** | Derived (invoice date + 30 / “Net 30”), not stored on `Bill` | Columns or bill attributes |
| **Logo / letterhead** | Text company name only | Image from `GetFile` / shop branding path |
| **Multi-currency** | Single unit (USD-style formatting) | Currency on bill / books |
| **Partial payments** | Receipt child totals summed when present; simple | Multi-receipt allocation UI |
| **Person consignees** | `Bills` view is entity-oriented; PDF falls back to `People` | Broader invoice header view |
| **Ship / BOL** | Not a schema bill type; packing list = Order/Invoice export | Wiki Ship Order when implemented |
| **Email send** | PDF file only; no SMTP from skill | Optional mail attachment helper |
| **PDF layout polish** | QB-*inspired*, not a pixel clone of QuickBooks | Templates / CSS HTML→PDF |

Do **not** claim ERP completeness. Skill stays micro-business clerk + bookkeeper.
