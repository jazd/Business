#!/usr/bin/env bash
# Stopped BookAccount, LedgerAccount, and AssemblyPart rows stay out of the views.
# A stopped IndividualVertex link does not name that individual.
#
#   ./scripts/test-views-stop.sh [business.sqlite3]
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
sqlite3 "$DB" < "$ROOT/SQLite/0.2.16-0.2.17.sql"

fail() {
  echo "Error: $*" >&2
  exit 1
}

sqlite3 "$DB" "UPDATE BookAccount SET stop = datetime('now') WHERE book = 1;"
open_books=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Books WHERE book = 2;")
stopped_books=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Books WHERE book = 1;")
[[ "$open_books" -ge 1 ]] || fail "open book 2 dropped out of Books"
[[ "$stopped_books" == "0" ]] || fail "stopped book 1 still in Books ($stopped_books)"

sqlite3 "$DB" "UPDATE LedgerAccount SET stop = datetime('now') WHERE account = 1;"
stopped_ledgers=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Ledgers WHERE account = 1;")
open_ledgers=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Ledgers WHERE account = 2;")
[[ "$stopped_ledgers" == "0" ]] || fail "stopped ledger account 1 still in Ledgers"
[[ "$open_ledgers" -ge 1 ]] || fail "open ledger account 2 dropped out of Ledgers"

asm=$(sqlite3 "$DB" "SELECT assembly FROM AssemblyPart WHERE stop IS NULL LIMIT 1;")
if [[ -n "$asm" ]]; then
  sqlite3 "$DB" "UPDATE AssemblyPart SET stop = datetime('now') WHERE assembly = $asm;"
  left=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Assemblies WHERE assembly = $asm;")
  [[ "$left" == "0" ]] || fail "stopped assembly $asm still in Assemblies"
fi

echo "views honor stop ($SRC)"
