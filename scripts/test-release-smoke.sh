#!/usr/bin/env bash
# Wikipedia books and the Grokipedia cash ledger on a copy of a shop file.
# JournalReport and the chart LedgerReport total 21350.00 / 21350.00.
# Posting accounts net to 11050.00 / 11050.00.
# AccountLedger Cash is the three General-journal posts.
# Does not write the source file. The copy starts with no journal lines.
#
#   ./scripts/test-release-smoke.sh [business.sqlite3]
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

existing=$(sqlite3 "$DB" "SELECT COUNT(*) FROM JournalEntry;")
if [[ "$existing" != "0" ]]; then
  fail "shop already has $existing journal lines; this smoke uses an empty journal"
fi

export SQLITE_DB="$DB"
export PATH="$ROOT/Bash/sqlite:/usr/bin:/bin"

book() {
  "$ROOT/Bash/sqlite/Book" "$@" >/dev/null
}

# Five Wikipedia books.
book Rent 100
book Sale 50
book Equipment 5200
book Loan 11000
book Salary 5000

"$ROOT/Bash/sqlite/JournalReport" > "$TMP/journal.txt"
if grep -E -q '[0-9][eE][+-][0-9]' "$TMP/journal.txt"; then
  fail "scientific notation in JournalReport"
fi
journal_last="$(awk 'NF { line = $0 } END { print line }' "$TMP/journal.txt")"
case "$journal_last" in
  *Total*21350.00*21350.00*) ;;
  *) fail "JournalReport Total is not last or is not 21350.00 / 21350.00: $journal_last" ;;
esac

view_last="$(sqlite3 -separator '|' "$DB" "SELECT account, debit, credit FROM JournalReport;" | tail -n 1)"
case "$view_last" in
  Total\|21350.00\|21350.00) ;;
  *) fail "JournalReport view Total is not last: $view_last" ;;
esac

ledger_last="$(sqlite3 -separator '|' "$DB" \
  "SELECT ledgerName, accountName, debit, credit FROM LedgerReport;" | tail -n 1)"
case "$ledger_last" in
  General\|Total\|21350.00\|21350.00) ;;
  *) fail "LedgerReport Total is not last: $ledger_last" ;;
esac

# Net of each posting account. Cash is 750.00 debit.
cat > "$TMP/posting-expect.txt" << 'EOF'
100|Cash|750.00|
101|Rent|100.00|
102|Sales||50.00
103|Equipment|5200.00|
104|Loan||11000.00
105|Salary|5000.00|
EOF
sqlite3 -separator '|' "$DB" "
WITH nets AS (
 SELECT account,
  accountName AS name,
  SUM(COALESCE(debit, 0)) - SUM(COALESCE(credit, 0)) AS net
 FROM JournalEntries
 WHERE posted IS NULL
 GROUP BY account, accountName
)
SELECT account, name,
 CASE WHEN net > 0 THEN printf('%.2f', net) ELSE '' END,
 CASE WHEN net < 0 THEN printf('%.2f', -net) ELSE '' END
FROM nets
ORDER BY account;
" > "$TMP/posting.txt"
if ! cmp -s "$TMP/posting-expect.txt" "$TMP/posting.txt"; then
  echo "Error: posting accounts are not the Wikipedia nets" >&2
  diff -u "$TMP/posting-expect.txt" "$TMP/posting.txt" >&2 || true
  exit 1
fi

totals="$(sqlite3 -separator '|' "$DB" "
WITH nets AS (
 SELECT SUM(COALESCE(debit, 0)) - SUM(COALESCE(credit, 0)) AS net
 FROM JournalEntries
 WHERE posted IS NULL
 GROUP BY account
)
SELECT printf('%.2f', SUM(CASE WHEN net > 0 THEN net ELSE 0 END)),
 printf('%.2f', SUM(CASE WHEN net < 0 THEN -net ELSE 0 END))
FROM nets;
")"
[[ "$totals" == "11050.00|11050.00" ]] || fail "posting total is $totals"

# Grokipedia cash ledger, plus the journal and chart reports on their own copies.
"$ROOT/scripts/test-cash-ledger.sh" "$SRC"
"$ROOT/scripts/test-journal-report-format.sh" "$SRC"
"$ROOT/scripts/test-ledger-report.sh" "$SRC"

echo "Release smoke ok ($SRC)"
