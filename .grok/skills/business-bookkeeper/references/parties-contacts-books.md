# Parties, contacts & named books

Clerk deep dive for `/business-bookkeeper`. Full rules: `../SKILL.md`.

---

## 1. Parties (customers, vendors, “you”)

| Role | API (bash / SQL) | Notes |
|------|------------------|--------|
| Company / org | `GetIndividualEntity 'Name'` | Find-or-insert Entity + Individual |
| Person (with birth) | `GetIndividualPerson first middle last YYYY-MM-DD [goesBy]` | Birth required for dedupe (wiki) |
| Person via email | `GetIndividualEmail 'a@b.c'` | Creates individual if needed |
| Link email | `SetIndividualEmail <individual> <email\|id> [type]` | Soft-stops other emails of same type |

**Bash examples**

```bash
SUP=$(GetIndividualEntity 'Bunnies-R-Us')
CON=$(GetIndividualEntity 'Toys for Tots')
PAT=$(GetIndividualPerson Pat '' Lee 1990-05-01)
GetIndividualEmail 'pat@example.com'
SetIndividualEmail "$PAT" 'pat@example.com' work
```

Read via views **`People`**, **`Entities`**, **`EmailAddress`** when present.

Do **not** DELETE parties; soft-stop contact links instead.

---

## 2. Contacts (invoice-ready address & phone)

| Intent | Bash |
|--------|------|
| Phone | `GetPhone <country> <area> <number>` - digits; strip formatting |
| Postal (lookup) | `GetPostal <zip>` or `GetPostal <country> <zip>` |
| Postal (insert) | `GetPostal <country> <zip> <city> <state_abbr> <state> [county]` |
| Street address | `GetAddress <street> <zip> [plus4]` - needs Postal row first |
| Link phone | `SetIndividualPhone <individual> <phone_id> [type]` |
| Link address | `SetIndividualAddress <individual> <address_id> [type]` |
| Party dump | `DocumentParty <individual_id>` |

```bash
GetPostal USA 10504 Armonk NY 'New York'
ADDR=$(GetAddress '1 New Orchard Road' 10504 1716)
SetIndividualAddress "$CON" "$ADDR" shipping
PH=$(GetPhone USA 914 4991900)
SetIndividualPhone "$CON" "$PH" main
DocumentParty "$CON"
```

Views: **`Addresses`**, **`Phones`**.  
`SetIndividualPhone` / `SetIndividualAddress` follow the same soft-stop pattern as email (schema helpers; not separate PG procedures).

---

## 3. Named books catalog (seeded GL)

List anytime:

```bash
ListBooks
```

| Book (en-US) | Typical user language |
|--------------|------------------------|
| **Rent** | Paid rent in cash |
| **Sale** | Cash sale |
| **Sales Credit** | Sales credit / reverse cash sale |
| **Equipment** | Bought equipment cash |
| **Equipment Return** | Returned equipment |
| **Loan** | Borrowed cash |
| **Loan Payment** | Paid down loan |
| **Salary** | Paid salaries |
| **Supply** | Bought supplies (seed label is *Supply*, not “Supplies”) |
| **Supply Return** | Returned supplies |
| **Petty Cash** / **Petty Cash Return** | Petty cash out / return |
| **AR Sale** | Credit sale (Receivable / Sales) - cargo path on Order |
| **AR Sale Credit** | Credit memo / reverse AR sale |
| **AR Payment** | Customer paid AR (Cash / Receivable) - Receipt path |
| **Sale Jane Doe** / **Sale John Doe** | Commission split sales (wiki complex books) |
| **AP Donation** / **Donation Payment** | Donation AP path if used |

```bash
Book Rent 100
Book 'AR Sale' 14.99   # usually via MoveCargoToChild … AR Sale
Post Cash 500 Sales 2024-01-10   # manual General journal
BookBalance Sale 50              # Book + show lines for that entry
JournalReport
```

**Returns / credits (honest):**

- Prefer named books **Sales Credit**, **AR Sale Credit**, **Equipment Return**, **Supply Return**.
- Cargo returns/split shipments: wiki “more complicated example” is still a **stub** - use compensating cargo/`LineItems` only when you understand the bill tree; do not invent Return bill types beyond schema comments.
- Soft-stop prices / new `AssemblyIndividualJobPrice` rather than overwriting quoted lines.

---

## 4. Quick customer card recipe

```bash
C=$(GetIndividualEntity 'City Library')
# or person:
# C=$(GetIndividualPerson Alex '' Ng 1985-01-15)
SetIndividualEmail "$C" 'orders@citylib.example' work
GetPostal USA 20500 Washington DC 'District of Columbia'
A=$(GetAddress '1600 Pennsylvania Avenue NW' 20500 0005)
SetIndividualAddress "$C" "$A" billing
DocumentParty "$C"
```

Then create bills with supplier = your shop entity, consignee = `$C`.
