#!/usr/bin/env bash
# SetSchedule inserts a count band and does not update an existing band.
# SetPrice inserts the quote unit price. A different price for the same
# assembly and job exits non-zero and writes nothing.
# Schedule.price is not the line unit price.
# InvoiceLineDetail.description is the part name, plus the part description
# when one is stored. It is not the part version.
# GetAddress stores a street on an existing zip.
#
#   ./scripts/test-price-and-invoice.sh [business.sqlite3]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/business.sqlite3}"
if [[ ! -f "$SRC" && -f /tmp/business-0.2.12.sqlite3 ]]; then
  SRC=/tmp/business-0.2.12.sqlite3
fi

if [[ ! -f "$SRC" ]]; then
  echo "Error: SQLite template not found: $SRC" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/business.sqlite3"
cp -a "$SRC" "$DB"

fail() {
  echo "Error: $*" >&2
  exit 1
}

fingerprint() {
  sqlite3 "$DB" "SELECT COUNT(*) || '|' || printf('%.4f', COALESCE(SUM(amount), 0)) || '|' || COALESCE(SUM(account * CASE WHEN credit THEN 1 ELSE -1 END), 0) FROM JournalEntry;"
}

stamp() {
  sqlite3 "$DB" "SELECT COUNT(*) FROM SchemaVersion WHERE stop IS NULL;"
}

before=$(fingerprint)
stamp_before=$(stamp)
sqlite3 "$DB" < "$ROOT/SQLite/0.2.12-0.2.13.sql"
sqlite3 "$DB" < "$ROOT/SQLite/0.2.12-0.2.13.sql"
after=$(fingerprint)
[[ "$before" == "$after" ]] || fail "hop rewrote JournalEntry ($before -> $after)"
[[ "$(stamp)" == "$stamp_before" ]] || fail "hop changed the active SchemaVersion count"

export SQLITE_DB="$DB"
export PATH="$ROOT/Bash/sqlite:$PATH"

q() { sqlite3 "$DB" "$1"; }

sup=$(GetIndividualEntity 'Bunnies-R-Us')
con=$(GetIndividualEntity 'City Library')
GetPostal USA 10504 Armonk NY 'New York' >/dev/null
GetPostal USA 20500 Washington DC 'District of Columbia' >/dev/null
armonk=$(GetAddress '18 Cottonwood Lane' 10504 1716)
armonk2=$(GetAddress '18 Cottonwood Lane' 10504 1716)
[[ "$armonk" == "$armonk2" && -n "$armonk" ]] || fail "Cottonwood address was not reused ($armonk / $armonk2)"
[[ "$(q "SELECT line1 FROM Address WHERE id = $armonk;")" == "18 Cottonwood Lane" ]] || fail "Cottonwood line1"
dc=$(GetAddress '42 Storybook Court NW' 20500 0005)
[[ "$(q "SELECT line1 FROM Address WHERE id = $dc;")" == "42 Storybook Court NW" ]] || fail "Storybook line1"

GetPart Product >/dev/null
widget=$(GetPartWithParent Widget-A 1.0 Product SKU)
gadget=$(GetPartWithParent Gadget-B 2.0 Product SKU)
[[ -n "$widget" && -n "$gadget" ]] || fail "parts missing"

job=$(GetJob Default)
sch=$(GetSchedule Default)
ij=$(GetIndividualJobSchedule "$con" "$job" "$sch")
[[ -n "$sch" && -n "$ij" ]] || fail "schedule or job missing"

SetSchedule "$sch" 0 999 100 >/dev/null
SetSchedule "$sch" 0 999 100 >/dev/null
band_a=$(q "
 SELECT COUNT(*) FROM Schedule
 WHERE schedule = $sch AND fromCount = 0 AND toCount = 999
  AND rate = 100 AND price IS NULL;
")
[[ "$band_a" == "1" ]] || fail "rate 100 band count is $band_a"

SetSchedule "$sch" 100 '' 80 >/dev/null
open_band=$(q "
 SELECT COUNT(*) FROM Schedule
 WHERE schedule = $sch AND fromCount = 100 AND toCount IS NULL
  AND rate = 80 AND price IS NULL;
")
[[ "$open_band" == "1" ]] || fail "open band count is $open_band"
[[ "$band_a" == "$(q "
 SELECT COUNT(*) FROM Schedule
 WHERE schedule = $sch AND fromCount = 0 AND toCount = 999
  AND rate = 100 AND price IS NULL;
")" ]] || fail "open band changed the 100 rate"

SetSchedule "$sch" 0 999 90 >/dev/null
[[ "$(q "
 SELECT COUNT(*) FROM Schedule
 WHERE schedule = $sch AND fromCount = 0 AND toCount = 999 AND rate = 100 AND price IS NULL;
")" == "1" ]] || fail "a second rate updated the first band"
[[ "$(q "
 SELECT COUNT(*) FROM Schedule
 WHERE schedule = $sch AND fromCount = 0 AND toCount = 999 AND rate = 90 AND price IS NULL;
")" == "1" ]] || fail "second rate was not inserted"

SetSchedule "$sch" 0 10 100 99.99 >/dev/null
[[ "$(q "
 SELECT printf('%.4f', price) FROM Schedule
 WHERE schedule = $sch AND fromCount = 0 AND toCount = 10 AND rate = 100;
")" == "99.9900" ]] || fail "schedule price was not stored"
[[ "$(q "
 SELECT COUNT(*) FROM Schedule
 WHERE schedule = $sch AND fromCount = 0 AND toCount = 999 AND rate = 100 AND price IS NULL;
")" == "1" ]] || fail "schedule price updated the percent band"

sched_before=$(q "SELECT COUNT(*) FROM Schedule;")
if SetSchedule "$sch" 0 1 '' '' >"$TMP/sch.out" 2>"$TMP/sch.err"; then
  fail "SetSchedule with no rate or price succeeded"
fi
grep -q "rate or price is required" "$TMP/sch.err" || fail "SetSchedule error was: $(cat "$TMP/sch.err")"
[[ "$(q "SELECT COUNT(*) FROM Schedule;")" == "$sched_before" ]] || fail "empty SetSchedule wrote a band"

cart=$(CreateBill "$sup" "$con" Cart)
AddCargo "$cart" "$widget" 3 >/dev/null
AddCargo "$cart" "$gadget" 1 >/dev/null

price_of() {
  q "
   SELECT CASE WHEN currentUnitPrice IS NULL THEN 'null' ELSE printf('%.2f', currentUnitPrice) END
    || '|' ||
    CASE WHEN unitPrice IS NULL THEN 'null' ELSE printf('%.2f', unitPrice) END
   FROM LineItems WHERE bill = $1 AND item = '$2';
  "
}

[[ "$(price_of "$cart" Widget-A)" == "null|null" ]] || fail "cart Widget-A price before SetPrice is $(price_of "$cart" Widget-A)"
[[ "$(price_of "$cart" Gadget-B)" == "null|null" ]] || fail "cart Gadget-B price before SetPrice is $(price_of "$cart" Gadget-B)"

SetPrice "$widget" "$ij" 12.50 >/dev/null
SetPrice "$widget" "$ij" 12.50 >/dev/null
SetPrice "$widget" "$ij" 12.50001 >/dev/null
[[ "$(q "
 SELECT COUNT(*) || '|' || printf('%.4f', price)
 FROM AssemblyIndividualJobPrice
 WHERE assembly = $widget AND individualJob = $ij;
")" == "1|12.5000" ]] || fail "same SetPrice wrote another row"

price_rows=$(q "SELECT COUNT(*) FROM AssemblyIndividualJobPrice WHERE assembly = $widget AND individualJob = $ij;")
if SetPrice "$widget" "$ij" 13 >"$TMP/price.out" 2>"$TMP/price.err"; then
  fail "different SetPrice succeeded"
fi
grep -q "different price" "$TMP/price.err" || fail "SetPrice error was: $(cat "$TMP/price.err")"
[[ "$(q "SELECT COUNT(*) FROM AssemblyIndividualJobPrice WHERE assembly = $widget AND individualJob = $ij;")" == "$price_rows" ]] || fail "different SetPrice wrote a row"
[[ "$(q "SELECT printf('%.4f', price) FROM AssemblyIndividualJobPrice WHERE assembly = $widget AND individualJob = $ij;")" == "12.5000" ]] || fail "different SetPrice changed the stored price"

SetPrice "$gadget" "$ij" 49 >/dev/null

[[ "$(price_of "$cart" Widget-A)" == "12.50|null" ]] || fail "cart Widget-A after SetPrice is $(price_of "$cart" Widget-A)"
[[ "$(price_of "$cart" Gadget-B)" == "49.00|null" ]] || fail "cart Gadget-B after SetPrice is $(price_of "$cart" Gadget-B)"

quote=$(CreateBill "$sup" "$con" Quote "$cart")
MoveCargoToChild "$cart" '' '' "$ij" >/dev/null

quote_money() {
  q "
   SELECT printf('%.2f', unitPrice) || '|' || printf('%.2f', totalPrice) || '|' || printf('%.2f', currentUnitPrice)
   FROM LineItems WHERE bill = $quote AND item = '$1';
  "
}
[[ "$(quote_money Widget-A)" == "12.50|37.50|12.50" ]] || fail "quote Widget-A is $(quote_money Widget-A)"
[[ "$(quote_money Gadget-B)" == "49.00|49.00|49.00" ]] || fail "quote Gadget-B is $(quote_money Gadget-B)"

desc_of() {
  q "SELECT description FROM InvoiceLineDetail WHERE bill = $quote AND product = '$1';"
}
[[ "$(desc_of Widget-A)" == "Widget-A" ]] || fail "Widget-A description is '$(desc_of Widget-A)'"
[[ "$(desc_of Gadget-B)" == "Gadget-B" ]] || fail "Gadget-B description is '$(desc_of Gadget-B)'"
widget_version=$(q "SELECT version FROM LineItems WHERE bill = $quote AND item = 'Widget-A';")
[[ -n "$widget_version" ]] || fail "Widget-A version is empty"
[[ "$(desc_of Widget-A)" != "$widget_version" ]] || fail "description is the version ($widget_version)"

next_para() {
  q "SELECT COALESCE(MAX(id), 0) + 1 FROM Paragraph;"
}
empty_id=$(next_para)
q "INSERT INTO Paragraph (id, culture, value) VALUES ($empty_id, 1033, '');"
q "INSERT INTO PartDescription (part, description) VALUES ($gadget, $empty_id);"
[[ "$(desc_of Gadget-B)" == "Gadget-B" ]] || fail "empty paragraph changed Gadget-B to '$(desc_of Gadget-B)'"

text_id=$(next_para)
q "INSERT INTO Paragraph (id, culture, value) VALUES ($text_id, 1033, 'A small widget');"
q "INSERT INTO PartDescription (part, description) VALUES ($widget, $text_id);"
[[ "$(desc_of Widget-A)" == "Widget-A - A small widget" ]] || fail "Widget-A description is '$(desc_of Widget-A)'"
[[ "$(q "SELECT product FROM InvoiceLineDetail WHERE bill = $quote AND line = (SELECT line FROM InvoiceLineDetail WHERE bill = $quote AND product = 'Widget-A');")" == "Widget-A" ]] || fail "product column changed"

python3 - "$DB" "$quote" "$ROOT/scripts" <<'PY'
import sqlite3, sys
sys.path.insert(0, sys.argv[3])
import invoice_pdf
conn = sqlite3.connect(sys.argv[1])
bill = invoice_pdf.load_invoice(conn, int(sys.argv[2]))
by_item = {ln["item"]: ln["description"] for ln in bill["lines"]}
expect = {
    "Widget-A": "Widget-A - A small widget",
    "Gadget-B": "Gadget-B",
}
if by_item != expect:
    raise SystemExit(f"invoice_pdf descriptions {by_item} != {expect}")
PY

[[ "$(fingerprint)" == "$after" ]] || fail "price helpers wrote JournalEntry ($(fingerprint) vs $after)"

echo "price and invoice checks passed"
