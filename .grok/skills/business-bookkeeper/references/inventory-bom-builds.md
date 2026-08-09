# Inventory, BOM, builds, orders, invoice & payment

Operator deep dive for `/business-bookkeeper`.  
Canonical SQL shapes: sibling **`Business.wiki/Examples.md`** → **Parts** and **Inventory Movement**.  
Full agent rules: `../SKILL.md`.

Two layers stay separate in the operator’s head:

| Layer | What it is | Main entry points | Read via |
|-------|------------|-------------------|----------|
| **A. Catalog + BOM + unit builds** | Part hierarchy, kit/BOM designators, serial-numbered assemblies | `GetPart*`, `GetVersionName`, `PutAssemblyPart`, `GetPartbySerial` | `Parts`, `Assemblies`, `AssemblyParts` |
| **B. Commerce cargo** | Wish→…→Receipt (sales) and supplier **Order** bills (purchases) | `CreateBill`, `AddCargo`, `MoveCargoToChild`, price schedule helpers | `LineItems`, `JournalReport` |

Do **not** invent classical stock-qty tables or “UPDATE on_hand”. Track stock with **cargo on bills** and **serialized parts** when the business needs unit identity.

---

## A1. Part catalog (taxonomy)

Parts form a **parent hierarchy**: kind → package/subtype → MPN / value / version.  
`Get*` is find-or-insert (NoCRUD).

### Category root

```sql
SELECT GetPart('Resistor');
SELECT GetPart('Capacitor');
SELECT GetPart('MOSFET');
SELECT GetPart('Module');
SELECT GetPart('PCB');
-- also: Thermistor, Regulator, Transistor, Diode, Bridge, Transceiver, Crypto, …
```

### Named value under a parent (wiki shape)

```sql
-- GetPartWithParent(name, version, parentName, parentVersion)
SELECT GetPartWithParent('Arduino Nano', 'v3.x', 'Module', 'Micro Controller');
SELECT GetPartWithParent('470pF', '50v', 'Capacitor', 'Ceramic Disc');
SELECT GetPartWithParent('4.7k', '1%', 'Resistor', '0603');
SELECT GetPartWithParent('ESP32-S3-WROOM', '1-N16', 'Module', 'Micro Controller');
```

### Deeper chains (category → flavor → package → MPN)

Build parents first, then the leaf MPN. Prefer **one** of:

```sql
-- Explicit intermediate nodes
SELECT GetPartWithParent(GetPart('MOSFET', 'P-Channel'), GetPart('MOSFET'));
SELECT GetPartWithParent('MOSFET', 'SOT', 'MOSFET', 'P-Channel');
SELECT GetPartWithParent('AO3401A', '23', 'MOSFET', 'SOT');

SELECT GetPartWithParent(GetPart('Transistor', 'NPN'), GetPart('Transistor'));
SELECT GetPartWithParent('Transistor', 'SOT', 'Transistor', 'NPN');
SELECT GetPartWithParent('L8050QLT1G', '23', 'Transistor', 'SOT');

SELECT GetPartWithParent(GetPart('Bridge', 'USB to UART'), GetPart('Bridge'));
SELECT GetPartWithParent('Bridge', 'QFN', 'Bridge', 'USB to UART');
SELECT GetPartWithParent('CP2102N-Axx', '28', 'Bridge', 'QFN');
```

If a leaf lands under the wrong parent (no-parent / wrong package):

- Prefer **`GetPartWithParentNearest`** / **`GetPartWithAncestor`** (PostgreSQL) over DELETE/UPDATE of Part history.
- Do not hand-delete parts to “fix” hierarchy in production books.

### Versioned product assembly (PCB / kit root)

```sql
SELECT GetPart('PCB');
-- GetPartWithParentVersion(name, version, parentName, parentVersion)
SELECT GetPartWithParentVersion(
  'Alarm',
  GetVersionName('Demo', '1', '0', '0'),
  'PBC',
  GetVersionName('Demo')
);
-- Hardware product example shape (names are user-chosen):
SELECT GetPartWithParentVersion(
  'AI0',
  GetVersionName('Dev', '0', '0', '0'),
  'PBC',
  GetVersionName('Development')
);
```

### Catalog listing (wiki)

```sql
SELECT parent.name AS part,
  parts.name,
  parent.version || parts.version AS type
FROM Parts, Parts AS Parent
WHERE Parent.part = Parts.parent
  AND Parent.version != ''
ORDER BY Parent.name;
```

**Bash (SQLite shop):** `GetPart`, `GetPartWithParent`, `GetPartWithParentVersion`, `GetVersionName` when on `PATH`.

---

## A2. BOM = assembly + designators

A **BOM** is an assembly part with child rows via `PutAssemblyPart`.

```text
PutAssemblyPart(assembly, part, designator, quantity)
RemoveAssemblyPart(assembly [, part [, designator]])
```

- `assembly` — result of `GetPart(...)` / `GetPartWithParentVersion(...)` for the board/kit version  
- `part` — discrete component or sub-module id  
- `designator` — refdes (`R1`, `U1`, `C3`, `TH1`, …)  
- `quantity` — `NULL` for “one footprint / designator row” (typical BOM); use a real number when the schema call expects count (serialized builds often pass `1`)

**`AssemblyParts`** includes only rows with `AssemblyPart.stop IS NULL`.  
**`RemoveAssemblyPart`** sets `stop` on matching active rows.

| Action | Behavior |
|--------|----------|
| `PutAssemblyPart` same active line | No insert (row already present with `stop IS NULL`) |
| `PutAssemblyPart` different part/qty on same designator | Sets `stop` on prior active designator row(s); inserts new row |
| `RemoveAssemblyPart(assembly, part, designator)` | Sets `stop` on matching active row(s) |
| `RemoveAssemblyPart(assembly)` | Sets `stop` on all active rows for assembly |
| **`Assemblies` view** | Distinct assemblies that appear in `AssemblyPart` (any `stop` value) |

### Wiki Alarm Demo shape

```sql
SELECT PutAssemblyPart(
  GetPart('Alarm', GetVersionName('Demo', '1', '0', '0')),
  GetPart('IRF540NPBF', GetVersionName('220')),
  'Q1', NULL);
-- … more designators …
```

### Hardware BOM shape (same API)

```sql
-- Module on board
SELECT PutAssemblyPart(
  GetPart('AI0', GetVersionName('Dev', '0', '0', '0')),
  GetPart('ESP32-S3-WROOM', GetVersionName('1-N16')),
  'U1', NULL);

-- Passives with parent package
SELECT PutAssemblyPart(
  GetPart('AI0', GetVersionName('Dev', '0', '0', '0')),
  GetPartWithParent('4.7k','1%','Resistor','0603'),
  'R1', NULL);
SELECT PutAssemblyPart(
  GetPart('AI0', GetVersionName('Dev', '0', '0', '0')),
  GetPartWithParent('0','jumper','Resistor','0603'),
  'R6', NULL);
```

### Read BOM

```sql
SELECT parentname, name, version, versionname FROM Assemblies;

SELECT assemblyname, assemblyversionname, designator, partname, versionname
FROM AssemblyParts
ORDER BY designator;

-- Richer join (category + package/version string)
SELECT
  AssemblyParts.designator,
  Parent.name AS part,
  AssemblyParts.partname AS name,
  Parent.version || Parts.version AS type
FROM AssemblyParts
JOIN Parts ON Parts.part = AssemblyParts.part
JOIN Parts AS Parent ON Parent.part = Parts.parent
WHERE assembly = GetPart('AI0', GetVersionName('Dev', '0', '0', '0'))
ORDER BY partname, designator;
```

### Natural designator sort (PostgreSQL helper)

Refdes like `R2` before `R10` needs numeric-aware sort. If the DB has (or you add as a **local helper**, not a product requirement):

```sql
CREATE OR REPLACE FUNCTION natural_sort_key(s text)
RETURNS text[]
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
AS $$
  SELECT array_agg(
    CASE
      WHEN p ~ '^[0-9]+$' THEN lpad(p, 20, '0')
      ELSE p
    END
    ORDER BY ord
  )
  FROM unnest(
    regexp_split_to_array(
      regexp_replace(s, '([0-9]+)', E'\u0001\\1\u0001', 'g'),
      E'\u0001'
    )
  ) WITH ORDINALITY AS t(p, ord);
$$;

-- then:
ORDER BY partname, natural_sort_key(designator);
```

SQLite shops: order by designator string or sort in the agent after `AssemblyParts`.

**Bash:**  
`PutAssemblyPart <assemblyId> <partId> [designator] [qty]`  
`RemoveAssemblyPart <assemblyId> [partId] [designator]`

---

## A3. Serialized unit builds (track a physical board)

When a **physical unit** exists (MAC, chip SN, barcode):

1. Create the **serial instance** of the assembly version.  
2. Attach **serialized** (or catalog) children on designators.

```sql
-- Board instance (serial = real id only — never invent empty '')
SELECT GetPartbySerial(
  GetPartWithParentVersion(
    'AI0',
    GetVersionName('Dev', '0', '0', '1'),
    'PBC',
    GetVersionName('Development')
  ),
  '10B41DD5DAA0'   -- e.g. MAC / board serial
);  -- returns assembly id

-- MCU serial on U1 (often same as board MAC for Wi-Fi modules)
SELECT PutAssemblyPart(
  <assembly_id>,
  GetPartbySerial(GetPart('ESP32-S3-WROOM', GetVersionName('1-N16R8')), '10B41DD5DAA0'),
  'U1', 1);

-- USB-UART chip serial on U2
SELECT PutAssemblyPart(
  <assembly_id>,
  GetPartbySerial(GetPartWithParent('CP2102N-A02', '28', 'Bridge', 'QFN'), '<silabs_serial>'),
  'U2', 1);

-- Crypto secure-element serial on U5
SELECT PutAssemblyPart(
  <assembly_id>,
  GetPartbySerial(GetPartWithParent('ATECC608B', 'SSHDA', 'Crypto', 'SOIC'), '<seser_hex>'),
  'U5', 1);
```

### Verify builds

```sql
SELECT * FROM Assemblies WHERE serial IS NOT NULL ORDER BY assembly;

SELECT assembly, assemblyversionname, assemblyserial,
       designator, partname, versionname, serial
FROM AssemblyParts
WHERE assembly = <assembly_id>
ORDER BY designator;
```

Wiki baseline (unserial BOM + one serial unit):

```sql
SELECT GetPartbySerial(
  GetPart('Alarm', GetVersionName('Demo', '1', '0', '0')),
  '10001');
```

**Rules**

- **Real serials only.** Empty string is not “unknown unit.”  
- Catalog BOM (`serial` null) vs unit build (`serial` set) are different part rows.  
- Optional **firmware on assembly**: wiki **Application Release** + `GetAssemblyApplicationRelease` (advanced).  
- Optional **device certs**: EST `PutAssemblyPublicKey` / CSR / `PutCertificate` — only if the user is in that lane (see main skill).  
- Do **not** document product-specific extension tables (customer “thing” registries) as core Business; stay on `Parts` / `Assemblies` / `AssemblyParts`.

**Bash:** `GetPartbySerial <parentPartId> <serial>`.

---

## B1. Sales chain (customer order → pay)

Wiki **Inventory Movement** simple example (Bunnies-R-Us → Toys for Tots).

```text
Wish → Cart → Quote → Order → Invoice → Receipt
         MoveCargoToChild (parent → child bill)
```

| Step | CreateBill type | Cargo move notes | Accounting book |
|------|-----------------|------------------|-----------------|
| Wish list | `Wish` | `AddCargo(bill, part, qty)` | — |
| Cart | `Cart` (parent = Wish) | `MoveCargoToChild(parent, NULL, NULL)` | — |
| Price list | — | `GetIndividualJobSchedule` + `Schedule` bands + `AssemblyIndividualJobPrice` | — |
| Quote | `Quote` (parent = Cart) | Move with **price schedule** job so unit prices lock | — |
| Order | `Order` (parent = Quote) | Move; may pass book **`AR Sale`** | AR Sale (Receivable / Sales) |
| Invoice | `Invoice` (parent = Order) | Move cargo | inherits quoted/order economics |
| Payment | `Receipt` (parent = Invoice) | Move with book **`AR Payment`** | Cash / Receivable |

### Skeleton (replace party/part names)

```sql
-- Wish
SELECT CreateBill(
  GetIndividualEntity('Bunnies-R-Us'),
  GetIndividualEntity('Toys for Tots'),
  'Wish');

SELECT AddCargo(
  GetOutstandingBill(GetIndividualEntity('Bunnies-R-Us'),
    GetIndividualEntity('Toys for Tots'), 'Wish'),
  GetPart('Bunny'), 1);

-- Cart child + move all
SELECT CreateBill(
  GetIndividualEntity('Bunnies-R-Us'),
  GetIndividualEntity('Toys for Tots'),
  'Cart',
  GetOutstandingBill(GetIndividualEntity('Bunnies-R-Us'),
    GetIndividualEntity('Toys for Tots'), 'Wish'));

SELECT MoveCargoToChild(
  GetOutstandingBill(GetIndividualEntity('Bunnies-R-Us'),
    GetIndividualEntity('Toys for Tots'), 'Wish'),
  NULL, NULL);

-- Price schedule (once per customer job)
SELECT GetIndividualJobSchedule(
  GetIndividualEntity('Toys for Tots'),
  GetJob('Default'), GetSchedule('Default'));
-- INSERT INTO Schedule (schedule, fromCount, toCount, rate) … as needed
INSERT INTO AssemblyIndividualJobPrice (assembly, individualJob, price)
VALUES (
  GetPart('Bunny'),
  GetIndividualJobSchedule(
    GetIndividualEntity('Toys for Tots'),
    GetJob('Default'), GetSchedule('Default')),
  14.99);

-- Quote + lock schedule on move
SELECT CreateBill(..., 'Quote', GetOutstandingBill(..., 'Cart'));
SELECT MoveCargoToChild(
  GetOutstandingBill(..., 'Cart'),
  NULL, NULL,
  GetIndividualJobSchedule(..., GetJob('Default'), GetSchedule('Default')));

-- Order (book AR Sale on move when following wiki)
SELECT CreateBill(..., 'Order', GetOutstandingBill(..., 'Quote'));
SELECT MoveCargoToChild(
  GetOutstandingBill(..., 'Quote'),
  NULL, NULL, NULL, NULL,
  'AR Sale');

-- Invoice
SELECT CreateBill(..., 'Invoice', GetOutstandingBill(..., 'Order'));
SELECT MoveCargoToChild(GetOutstandingBill(..., 'Order'), NULL, NULL, NULL, NULL);

-- Receipt / payment (AR Payment)
SELECT CreateBill(..., 'Receipt', GetOutstandingBill(..., 'Invoice'));
SELECT MoveCargoToChild(
  GetOutstandingBill(..., 'Invoice'),
  NULL, NULL, NULL, NULL,
  'AR Payment');
```

### Always verify

```sql
SELECT typeName, consigneeName, count, line, item,
       currentUnitPrice, unitprice, totalprice, outstanding
FROM LineItems
WHERE bill = GetOutstandingBill(supplier, consignee, 'Invoice' /* or stage */);
```

Parent **`outstanding`** falls as cargo moves to children.  
After **AR Sale** + **AR Payment**, `JournalReport` shows Receivable/Sales then Cash/Receivable (wiki totals).

**Price change rule:** stop old `IndividualJob` / soft-stop price, insert new price — **quoted `unitprice` stays**; `currentUnitPrice` can move. Never overwrite historical invoice lines in place.

**Bash (SQLite shop):**

```bash
SUP=$(GetIndividualEntity 'Bunnies-R-Us')
CON=$(GetIndividualEntity 'Toys for Tots')
WISH=$(CreateBill "$SUP" "$CON" Wish)
AddCargo "$WISH" "$(GetPart Bunny)" 1
CART=$(CreateBill "$SUP" "$CON" Cart "$WISH")
MoveCargoToChild "$WISH"
IJ=$(GetIndividualJobSchedule "$CON" "$(GetJob Default)" "$(GetSchedule Default)")
PutAssemblyJobPrice "$(GetPart Bunny)" "$IJ" 14.99
QUOTE=$(CreateBill "$SUP" "$CON" Quote "$CART")
MoveCargoToChild "$CART" '' '' "$IJ"
ORDER=$(CreateBill "$SUP" "$CON" Order "$QUOTE")
MoveCargoToChild "$QUOTE" '' '' '' 'AR Sale'
INV=$(CreateBill "$SUP" "$CON" Invoice "$ORDER")
MoveCargoToChild "$ORDER"
RCP=$(CreateBill "$SUP" "$CON" Receipt "$INV")
MoveCargoToChild "$INV" '' '' '' 'AR Payment'
DocumentLineItems "$INV"
JournalReport
```

---

## B2. Purchasing (vendor inventory in)

Component stock is typically **cargo on supplier Order bills** (and optional **Build** bills that reference a BOM), not a free-floating qty column.

```bash
VENDOR=$(GetIndividualEntity 'Mouser Electronics')
SHOP=$(GetIndividualEntity 'My Shop')
PO=$(CreateBill "$VENDOR" "$SHOP" Order)
MPN=$(GetPartWithParent '4.7k' '1%' Resistor 0603)
AddCargo --unit "$PO" "$MPN" 100 0.05
GetBillReference "$PO" 'Sales Order' '280825725'
DocumentLineItems "$PO"
```

SQL shape:

```sql
SELECT CreateBill(
  GetIndividualEntity('<Vendor Name>'),
  GetIndividualEntity('<Your Shop>'),
  'Order'
);

SELECT GetBillReference(<order_bill>, 'Sales Order', '<vendor_po_number>');
```

**Build / kitting bills** (advanced): some shops create a bill whose cargo lines are **BOM-derived quantities** for N units, then link those lines via `CargoState` to vendor order lines as parts arrive. Prefer documented `AddCargo` / `MoveCargoToChild` / `AddCargoAlternate` over raw DELETE. If the user pastes a full build↔order trail, follow **their** ids and re-verify with `LineItems` / cargo views — do not invent a second BOM language.

**AP books** (`AP Purchase`, etc.) must already exist in the chart (`BookName` / static GL). Do not invent book names without checking `Book` / `JournalReport` seeds.

---

## B3. Shipping & bill of lading (honest gap)

Wiki headings under Inventory Movement:

- **Ship Order** — stub  
- **Received Order** — stub  
- **Flow** — outline only: *Inventory Bin → Shipper (received) → Carrier (loaded/delivered)*  
- **More complicated example** (split ship / return / credit) — stub  

**What the skill may do today**

| Allowed | Not allowed |
|---------|-------------|
| Keep cargo on **Order** / **Invoice** / **Receipt** and report status from `LineItems` | Invent BOL tables or “Ship” bill types not in schema |
| Use existing bill types and cargo moves if the user’s DB already has a ship procedure | Claim full BOL / multi-package carrier ERP |
| Note “wiki Ship Order not implemented; tracking via Order/Invoice cargo” | Fake a PDF BOL as a Business procedure unless user only wants a document export |

If the user needs a **customer-facing packing list / invoice PDF**, generate that as a **document** from `LineItems` + party addresses — separate from inventing inventory procedures.

---

## Operator playbooks (say → do)

### “Add these resistors/caps to the catalog”

1. Snapshot if many writes.  
2. `GetPart('Resistor')` (or category).  
3. `GetPartWithParent(value, tolerance/package-version, category, package)`.  
4. Show `Parts` parent listing.  
5. Summarize new SKUs.

### “Build / update the BOM for board X version Y”

1. Resolve assembly: `GetPartWithParentVersion` / `GetVersionName`.  
2. Ensure each leaf part exists (`GetPartWithParent` chains).  
3. `PutAssemblyPart(assembly, part, designator, NULL)` per refdes.  
4. `SELECT … FROM AssemblyParts WHERE assembly = …` (natural sort if available).  
5. Report row count by designator prefix (R/C/U/…).

### “Register built unit serial S with chip serials …”

1. `GetPartbySerial(assemblyVersion, S)` → id.  
2. `PutAssemblyPart(id, GetPartbySerial(component, sn), designator, 1)` for each serialized child.  
3. `AssemblyParts` for that id; confirm serials.  
4. Optional EST / Application Release only if asked.

### “Quote / sell product to customer C”

1. Resolve supplier (you) + consignee C.  
2. Ensure price schedule + `AssemblyIndividualJobPrice`.  
3. Walk Wish→… or start at Cart/Quote if user skips steps (still use legal bill parent chain).  
4. Move cargo; verify `LineItems` each stage.  
5. Invoice → Receipt with **AR Payment**.  
6. Show `JournalReport` / open AR if unpaid.

### “Order parts from Digi-Key / Mouser”

1. `CreateBill(vendor, shop, 'Order')`.  
2. `AddCargo` lines for each MPN/qty/(cost).  
3. Optional `GetBillReference` for vendor SO #.  
4. Show lines; do not invent receiving BOL.

### “What’s on the BOM / what did we build?”

- BOM (catalog): `AssemblyParts` for version part (serial null).  
- Builds: `Assemblies WHERE serial IS NOT NULL` + `AssemblyParts` filtered by assembly id.

---

## Gaps & anti-patterns (inventory-specific)

| Do | Don’t |
|----|--------|
| Get\* find-or-insert for parts | Manual INSERT/DELETE on Part to “fix” hierarchy |
| PutAssemblyPart / RemoveAssemblyPart for BOM edits | DELETE FROM AssemblyPart; query base table without `stop IS NULL` when current BOM is needed |
| Real serials on GetPartbySerial | Empty serial “placeholders” |
| Cargo + LineItems for commercial qty | Invent on_hand integer tables |
| AR Sale / AR Payment named books | Random Post without matching sale story |
| Admit Ship/BOL stubs | Claim full logistics |
| Scrub product-internal names from customer docs | Leak internal codenames into invoices |

---

## Quick API map

| Intent | Procedures / scripts |
|--------|----------------------|
| Category / SKU | `GetPart`, `GetPartWithParent`, `GetPartWithParentVersion`, `GetVersionName` |
| Ambiguous parent | `GetPartWithParentNearest`, `GetPartWithAncestor` (PG) |
| BOM / unit line | `PutAssemblyPart`, `RemoveAssemblyPart` (active = `AssemblyParts` view) |
| Serial unit | `GetPartbySerial` |
| Firmware link | `GetAssemblyApplicationRelease` (wiki Application Release) |
| Sales docs | `CreateBill`, `AddCargo`, `MoveCargo` / `MoveCargoToChild`, `GetOutstandingBill` |
| PO / tracking | `GetBillReference` |
| Prices | `GetJob`, `GetSchedule`, `GetIndividualJobSchedule`, `PutAssemblyJobPrice` |
| Books | `Book`, `ListBooks`, **`AR Sale`**, **`AR Payment`**, … |
| Documents | `DocumentLineItems`, `DocumentBOM`, `DocumentParty` |
| Reports | `LineItems`, `JournalReport`, `LedgerReport`, `Parts`, `Assemblies`, `AssemblyParts` |

---

## Wiki anchors

- `Business.wiki/Examples.md` → **# Parts**  
- `Business.wiki/Examples.md` → **# Inventory Movement**  
- Diagrams: `diagrams/assemblies.png`, `diagrams/inventory.png`  
- Accounting books for AR: static GL / Inventory Movement payment section  
