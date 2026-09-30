#!/usr/bin/env bash
# JournalReport prints fixed two-decimal amounts and keeps Total last.
# Uses a copy of a shop template (released business.sqlite3, or the path
# passed as $1). Does not write the source file.
#
#   ./scripts/test-journal-report-format.sh [business.sqlite3]
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
sqlite3 "$DB" "DELETE FROM JournalEntry;"

export SQLITE_DB="$DB"
export PATH="$ROOT/Bash/sqlite:${PATH:-}"

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

# Five Wikipedia books. Journal total is 21350.00 / 21350.00.
book Rent 100
book Sale 50
book Equipment 5200
book Loan 11000
book Salary 5000

"$ROOT/Bash/sqlite/JournalReport" > "$TMP/wiki.txt"
assert_line "$TMP/wiki.txt" "21350.00"
reject_sci "$TMP/wiki.txt"
last="$(awk 'NF { line = $0 } END { print line }' "$TMP/wiki.txt")"
case "$last" in
  *Total*21350.00*21350.00*) ;;
  *)
    echo "Error: Total row is not last or is not 21350.00 / 21350.00" >&2
    echo "last: $last" >&2
    cat "$TMP/wiki.txt" >&2
    exit 1
    ;;
esac

sqlite3 "$DB" "SELECT account, debit, credit FROM JournalReport;" > "$TMP/wiki-view.txt"
view_last="$(tail -n 1 "$TMP/wiki-view.txt")"
case "$view_last" in
  Total\|21350.00\|21350.00) ;;
  *)
    echo "Error: view Total row is not last: $view_last" >&2
    cat "$TMP/wiki-view.txt" >&2
    exit 1
    ;;
esac

# Amounts that %g collapses, rounds, or prints in scientific notation.
sqlite3 "$DB" "DELETE FROM JournalEntry;"
book Rent 385.50
book Rent 100000.25
book Rent 1234567.50

"$ROOT/Bash/sqlite/JournalReport" > "$TMP/odd.txt"
assert_line "$TMP/odd.txt" "385.50"
assert_line "$TMP/odd.txt" "100000.25"
assert_line "$TMP/odd.txt" "1234567.50"
assert_line "$TMP/odd.txt" "1334953.25"
reject_sci "$TMP/odd.txt"
if grep -E -q '(^|[^0-9.])385\.5([^0-9]|$)' "$TMP/odd.txt"; then
  echo "Error: 385.50 printed with a short fraction" >&2
  cat "$TMP/odd.txt" >&2
  exit 1
fi
odd_last="$(awk 'NF { line = $0 } END { print line }' "$TMP/odd.txt")"
case "$odd_last" in
  *Total*) ;;
  *)
    echo "Error: Total row is not last on the odd-amount report" >&2
    cat "$TMP/odd.txt" >&2
    exit 1
    ;;
esac

sqlite3 "$DB" "SELECT account, debit, credit FROM JournalReport;" > "$TMP/odd-view.txt"
assert_line "$TMP/odd-view.txt" "385.50"
assert_line "$TMP/odd-view.txt" "100000.25"
assert_line "$TMP/odd-view.txt" "1234567.50"
reject_sci "$TMP/odd-view.txt"
odd_view_last="$(tail -n 1 "$TMP/odd-view.txt")"
case "$odd_view_last" in
  Total\|*) ;;
  *)
    echo "Error: view Total row is not last: $odd_view_last" >&2
    cat "$TMP/odd-view.txt" >&2
    exit 1
    ;;
esac

echo "JournalReport format ok ($SRC)"
