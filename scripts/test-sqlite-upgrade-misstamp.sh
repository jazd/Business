#!/usr/bin/env bash
# A 0.2.14 release file can still report SchemaVersions 0.2.11.
# upgrade-sqlite.sh 0.2.14 0.2.15 accepts that file when Entitlement and
# SchemaVersions are present, restamps 0.2.14, and applies the living hop.
#
#   ./scripts/test-sqlite-upgrade-misstamp.sh [business.sqlite3]
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

export SQLITE_DB="$DB"
export PATH="$ROOT/Bash/sqlite:${PATH:-}"
export UPGRADE_BACKUP=0
SetSchemaVersion Business 0 2 11 >/dev/null

"$ROOT/scripts/upgrade-sqlite.sh" 0.2.14 0.2.15

active=$(sqlite3 "$DB" "
 SELECT maj.value || '.' || min.value || '.' || pat.value
 FROM SchemaVersion sv
 JOIN Word sch ON sch.id = sv.schema AND UPPER(sch.value) = 'BUSINESS'
 JOIN Version v ON v.id = sv.version
 JOIN Word maj ON maj.id = v.major
 JOIN Word min ON min.id = v.minor
 JOIN Word pat ON pat.id = v.patch
 WHERE sv.stop IS NULL
 ORDER BY sv.build DESC
 LIMIT 1;
")
if [[ "$active" != "0.2.14" ]]; then
  echo "Error: active version is $active, expected 0.2.14" >&2
  exit 1
fi

sqlite3 "$DB" "SELECT COUNT(*) FROM EntitlementCurrent;" >/dev/null

echo "Mis-stamped 0.2.14 upgrade ok ($SRC)"
