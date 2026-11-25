#!/usr/bin/env bash
# AddCargo --unit without a book must not write. The unit price has nowhere
# to live except the journal amount, and that amount is booked only when a
# book name is given.
#
#   ./scripts/test-addcargo-unit.sh [business.sqlite3]
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
export SQLITE_DB="$DB"
export PATH="$ROOT/Bash/sqlite:${PATH:-}"

fail() {
  echo "Error: $*" >&2
  exit 1
}

sup=$(GetIndividualEntity 'Bunnies-R-Us')
con=$(GetIndividualEntity 'City Library')
GetPart Product >/dev/null
part=$(GetPartWithParent Widget-A 1.0 Product SKU)
bill=$(CreateBill "$sup" "$con" Cart)
[[ -n "$bill" && -n "$part" ]] || fail "bill or part missing"

before=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Cargo;")
set +e
msg=$(AddCargo --unit "$bill" "$part" 2 12.50 2>&1)
code=$?
set -e
[[ "$code" -ne 0 ]] || fail "--unit without a book exited 0"
printf '%s\n' "$msg" | grep -q 'book' || fail "missing book was not reported: $msg"
after=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Cargo;")
[[ "$after" == "$before" ]] || fail "cargo rows changed ($before -> $after)"

entry=$(AddCargo --unit "$bill" "$part" 2 12.50 '' '' Sale)
[[ -n "$entry" ]] || fail "booked --unit returned nothing"
amount=$(sqlite3 "$DB" "SELECT printf('%.4f', amount) FROM JournalEntry WHERE entry = (SELECT entry FROM Cargo WHERE id = $entry ORDER BY created DESC LIMIT 1) AND credit = 1 LIMIT 1;")
[[ "$amount" == "25.0000" ]] || fail "booked amount is '$amount'"

echo "AddCargo unit price ok ($SRC)"
