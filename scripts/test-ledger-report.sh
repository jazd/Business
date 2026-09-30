#!/usr/bin/env bash
# LedgerReport is the chart-header statement (Asset, Liability, Income, Expenses).
# Uses a copy of a shop template. Does not write the source file.
#
#   ./scripts/test-ledger-report.sh [business.sqlite3]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SRC="${1:-$ROOT/business.sqlite3}"

if [[ ! -f "$SRC" ]]; then
  echo "Error: SQLite template not found: $SRC" >&2
  exit 1
fi

fail() {
  echo "Error: $*" >&2
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/business.sqlite3"
cp -a "$SRC" "$DB"

sqlite3 "$DB" < "$ROOT/SQLite/0.2.12-0.2.13.sql"
sqlite3 "$DB" "DELETE FROM JournalEntry;"

export SQLITE_DB="$DB"
export PATH="$ROOT/Bash/sqlite:/usr/bin:/bin"

book() {
  "$ROOT/Bash/sqlite/Book" "$@" >/dev/null
}

assert_line() {
  local file="$1" needle="$2"
  if ! grep -F -q -- "$needle" "$file"; then
    echo "Error: missing [$needle] in $file" >&2
    echo "-----" >&2
    cat "$file" >&2
    exit 1
  fi
}

reject_sci() {
  local file="$1"
  if grep -E -q '[0-9]e[+-][0-9]|[0-9]E[+-][0-9]' "$file"; then
    echo "Error: scientific notation in $file" >&2
    cat "$file" >&2
    exit 1
  fi
}

reject_posting_names() {
  local file="$1"
  if grep -E -q 'Cash|Equipment|Rent|Salary|Sales|Loan' "$file"; then
    echo "Error: posting account name in chart report $file" >&2
    cat "$file" >&2
    exit 1
  fi
}

reject_bare_zero() {
  local file="$1"
  if grep -E -q '(^|[^0-9])0\.00([^0-9]|$)' "$file"; then
    echo "Error: empty side printed as 0.00 in $file" >&2
    cat "$file" >&2
    exit 1
  fi
}

# Five Wikipedia books. Chart total is 21350.00 / 21350.00.
book Rent 100
book Sale 50
book Equipment 5200
book Loan 11000
book Salary 5000

cat > "$TMP/wiki-expect.txt" << 'EOF'
General|Asset|16250.00|10300.00
General|Liability||11000.00
General|Income||50.00
General|Expenses|5100.00|
General|Total|21350.00|21350.00
EOF
sqlite3 -separator '|' "$DB" \
  "SELECT ledgerName, accountName, debit, credit FROM LedgerReport;" \
  > "$TMP/wiki-view.txt"
if ! cmp -s "$TMP/wiki-expect.txt" "$TMP/wiki-view.txt"; then
  echo "Error: LedgerReport view is not the chart-header statement" >&2
  diff -u "$TMP/wiki-expect.txt" "$TMP/wiki-view.txt" >&2 || true
  exit 1
fi
reject_sci "$TMP/wiki-view.txt"

"$ROOT/Bash/sqlite/LedgerReport" > "$TMP/wiki.txt"
assert_line "$TMP/wiki.txt" "Asset"
assert_line "$TMP/wiki.txt" "Liability"
assert_line "$TMP/wiki.txt" "Income"
assert_line "$TMP/wiki.txt" "Expenses"
assert_line "$TMP/wiki.txt" "16250.00"
assert_line "$TMP/wiki.txt" "10300.00"
assert_line "$TMP/wiki.txt" "11000.00"
assert_line "$TMP/wiki.txt" "5100.00"
assert_line "$TMP/wiki.txt" "21350.00"
reject_sci "$TMP/wiki.txt"
reject_posting_names "$TMP/wiki.txt"
reject_bare_zero "$TMP/wiki.txt"
last="$(awk 'NF { line = $0 } END { print line }' "$TMP/wiki.txt")"
case "$last" in
  *Total*21350.00*21350.00*) ;;
  *)
    fail "Total row is not last or is not 21350.00 / 21350.00: $last"
    ;;
esac

"$ROOT/Bash/sqlite/LedgerReport" 1 es > "$TMP/es.txt"
assert_line "$TMP/es.txt" "la posesión capital"
assert_line "$TMP/es.txt" "la obligación"
assert_line "$TMP/es.txt" "Ingreso"
assert_line "$TMP/es.txt" "las expensas"
if grep -F -q 'Ingresos' "$TMP/es.txt"; then
  fail "Spanish LedgerReport used the type word Ingresos"
fi
reject_posting_names "$TMP/es.txt"
es_last="$(awk 'NF { line = $0 } END { print line }' "$TMP/es.txt")"
case "$es_last" in
  *Total*21350.00*21350.00*) ;;
  *)
    fail "Spanish Total row is not last: $es_last"
    ;;
esac

# Commission books from the LedgerReport FitNesse page.
book "Sale Jane Doe" 1000
book "Sale John Doe" 1000

cat > "$TMP/comm-expect.txt" << 'EOF'
General|Asset|18250.00|10300.00
General|Liability||11350.00
General|Income||1700.00
General|Expenses|5100.00|
General|Total|23350.00|23350.00
EOF
sqlite3 -separator '|' "$DB" \
  "SELECT ledgerName, accountName, debit, credit FROM LedgerReport;" \
  > "$TMP/comm-view.txt"
if ! cmp -s "$TMP/comm-expect.txt" "$TMP/comm-view.txt"; then
  echo "Error: LedgerReport view after commission books" >&2
  diff -u "$TMP/comm-expect.txt" "$TMP/comm-view.txt" >&2 || true
  exit 1
fi

"$ROOT/Bash/sqlite/LedgerReport" > "$TMP/comm.txt"
comm_last="$(awk 'NF { line = $0 } END { print line }' "$TMP/comm.txt")"
case "$comm_last" in
  *Total*23350.00*23350.00*) ;;
  *)
    fail "commission Total row is not last or is not 23350.00 / 23350.00: $comm_last"
    ;;
esac
reject_sci "$TMP/comm.txt"
reject_posting_names "$TMP/comm.txt"
reject_bare_zero "$TMP/comm.txt"

echo "LedgerReport ok ($SRC)"
