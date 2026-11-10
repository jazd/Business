#!/usr/bin/env bash
# EntryDescription and EntryReference on a shop copy.
# A file that does not have the tables yet receives the living SQLite hop.
#
#   ./scripts/test-entry-text.sh [business.sqlite3]
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

have=$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = 'EntryDescription';")
if [[ "$have" == "0" ]]; then
  sqlite3 "$DB" < "$ROOT/SQLite/0.2.15-0.2.16.sql"
fi

fail() {
  echo "Error: $*" >&2
  exit 1
}

entry=$(Book Rent 1.25)
[[ -n "$entry" ]] || fail "Book did not return an entry"

desc=$(SetEntryDescription "$entry" "October rent")
[[ -n "$desc" ]] || fail "SetEntryDescription returned nothing"
ref=$(SetEntryReference "$entry" check 1042)
[[ -n "$ref" ]] || fail "SetEntryReference returned nothing"

row=$(sqlite3 "$DB" "SELECT description || '|' || value FROM EntryDescriptions JOIN EntryReferences USING (entry) WHERE entry = $entry;")
[[ "$row" == "October rent|1042" ]] || fail "open text is '$row'"

desc2=$(SetEntryDescription "$entry" "November rent")
[[ "$desc2" != "$desc" ]] || fail "replacement description reused id $desc"
open=$(sqlite3 "$DB" "SELECT COUNT(*) FROM EntryDescription WHERE entry = $entry AND stop IS NULL;")
[[ "$open" == "1" ]] || fail "open descriptions: $open"
text=$(sqlite3 "$DB" "SELECT description FROM EntryDescriptions WHERE entry = $entry;")
[[ "$text" == "November rent" ]] || fail "description is '$text'"

ref2=$(SetEntryReference "$entry" check 1043)
[[ "$ref2" != "$ref" ]] || fail "replacement reference reused id $ref"
open=$(sqlite3 "$DB" "SELECT COUNT(*) FROM EntryReference WHERE entry = $entry AND stop IS NULL;")
[[ "$open" == "1" ]] || fail "open references: $open"
number=$(sqlite3 "$DB" "SELECT value FROM EntryReferences WHERE entry = $entry;")
[[ "$number" == "1043" ]] || fail "reference is '$number'"

echo "entry text passed ($SRC entry $entry)"
