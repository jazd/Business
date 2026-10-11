#!/usr/bin/env bash
# EntitlementCurrent on SQLite uses CURRENT_TIMESTAMP, not ClientNow().
# A stopped row and a row that already ended stay out of the view.
#
#   ./scripts/test-sqlite-entitlement.sh [business.sqlite3]
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

sqlite3 "$DB" < "$ROOT/SQLite/0.2.13-0.2.14.sql"
sqlite3 "$DB" < "$ROOT/SQLite/0.2.14-0.2.15.sql"

sqlite3 "$DB" "
 INSERT INTO Entitlement (individual, listName, source, status, starts, ends, stopped)
 VALUES (1, 1, 1, 1, '2020-01-01', NULL, NULL);
 INSERT INTO Entitlement (individual, listName, source, status, starts, ends, stopped)
 VALUES (1, 1, 2, 1, '2020-01-01', '2000-01-01', NULL);
 INSERT INTO Entitlement (individual, listName, source, status, starts, ends, stopped)
 VALUES (1, 1, 3, 1, '2020-01-01', NULL, '2020-02-01');
"

count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM EntitlementCurrent;")
if [[ "$count" != "1" ]]; then
  echo "Error: EntitlementCurrent returned $count rows, expected 1" >&2
  sqlite3 "$DB" "SELECT id, ends, stopped FROM EntitlementCurrent;" >&2
  exit 1
fi

echo "EntitlementCurrent ok ($SRC)"
