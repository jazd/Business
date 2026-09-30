#!/usr/bin/env bash
# Wiki Post to General Journal, checked against the Grokipedia cash ledger.
# Capital is the es-MX name of Equity. AccountLedger prints Equity.
# A Book entry on another journal stays out of the report.
#
#   ./scripts/test-cash-ledger.sh [business.sqlite3]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/business.sqlite3}"

if [[ ! -f "$SRC" ]]; then
  echo "Error: SQLite template not found: $SRC" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/business.sqlite3"
cp -a "$SRC" "$DB"

sqlite3 "$DB" < "$ROOT/SQLite/0.2.12-0.2.13.sql"

export SQLITE_DB="$DB"
POST="$ROOT/Bash/sqlite/Post"
BOOK="$ROOT/Bash/sqlite/Book"
LEDGER="$ROOT/Bash/sqlite/AccountLedger"

fail() {
  echo "Error: $*" >&2
  exit 1
}

general=$(sqlite3 "$DB" "
 SELECT jn.journal
 FROM JournalName jn
 JOIN Sentence s ON s.id = jn.name
 WHERE s.value = 'General' AND s.culture = 1033
 LIMIT 1;
")

sqlite3 "$DB" "SELECT id || '|' || COALESCE(created, '') FROM JournalEntry WHERE journal != $general ORDER BY id;" > "$TMP/before.txt"

sqlite3 "$DB" "DELETE FROM JournalEntry WHERE journal = $general;"

"$BOOK" Rent 100 >/dev/null
"$POST" Cash 10000 Capital 2024-01-01 >/dev/null
"$POST" Equipment 2000 Cash 2024-01-05 >/dev/null
"$POST" Cash 500 Sales 2024-01-10 >/dev/null

"$LEDGER" Cash > "$TMP/ledger.txt"

python3 - "$TMP/ledger.txt" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read().splitlines()
header = next(line for line in text if line.startswith("date"))
names = ["date", "details", "debit", "credit", "balance"]
starts = [header.index(name) for name in names]
starts.append(len(header) + 8)

def fields(line):
    padded = line.ljust(starts[-1])
    return [padded[starts[i]:starts[i + 1]].strip() for i in range(len(names))]

rows = []
for line in text:
    if not line.strip() or line.startswith("date") or set(line.strip()) <= set("- "):
        continue
    rows.append(fields(line))

expect = [
    ["Jan 1", "Equity", "10000.00", "", "10000.00"],
    ["Jan 5", "Equipment", "", "2000.00", "8000.00"],
    ["Jan 10", "Sales", "500.00", "", "8500.00"],
    ["", "Total", "10500.00", "2000.00", ""],
]
if rows != expect:
    print("Error: cash ledger mismatch", file=sys.stderr)
    for row in rows:
        print(row, file=sys.stderr)
    sys.exit(1)
PY

if grep -q 'Capital' "$TMP/ledger.txt"; then
  fail "cash ledger printed Capital; the en-US name is Equity"
fi

rent=$(sqlite3 "$DB" "SELECT COUNT(*) FROM JournalEntry je JOIN AccountName an ON an.account = je.account JOIN Sentence s ON s.id = an.name AND s.culture = 1033 WHERE s.value = 'Rent' AND je.journal = $general;")
if [[ "$rent" != "0" ]]; then
  fail "Rent book landed on the General journal"
fi

while IFS='|' read -r id created; do
  [[ -n "$id" ]] || continue
  now=$(sqlite3 "$DB" "SELECT COALESCE(created, '') FROM JournalEntry WHERE id = $id;")
  [[ "$now" == "$created" ]] || fail "rewrote JournalEntry $id ($created -> $now)"
done < "$TMP/before.txt"

echo "Cash ledger ok ($SRC)"
