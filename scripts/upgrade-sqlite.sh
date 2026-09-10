#!/usr/bin/env bash
# Upgrade a shop SQLite database one hop: SQLite/<from>-<to>.sql
#
# Usage:
#   export SQLITE_DB=$HOME/business-shop/business.sqlite3
#   ./scripts/upgrade-sqlite.sh 0.2.11 0.2.12
#
# Preconditions: active SchemaVersion Business = <from>.
# After SQL file succeeds: SetSchemaVersion Business to <to>.
# Optional backup: UPGRADE_BACKUP=1 (default) writes SQLITE_DB.bak.<timestamp>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FROM="${1:-}"
TO="${2:-}"
: "${SQLITE_DB:=$HOME/business-shop/business.sqlite3}"
: "${UPGRADE_BACKUP:=1}"

if [[ -z "$FROM" || -z "$TO" ]]; then
  echo "Usage: SQLITE_DB=... $0 <from_version> <to_version>" >&2
  echo "Example: $0 0.2.11 0.2.12" >&2
  exit 1
fi

if [[ ! -f "$SQLITE_DB" ]]; then
  echo "Error: SQLITE_DB not found: $SQLITE_DB" >&2
  exit 1
fi

HOP="$ROOT/SQLite/${FROM}-${TO}.sql"
if [[ ! -f "$HOP" ]]; then
  echo "Error: missing hop file $HOP" >&2
  exit 1
fi

export PATH="$ROOT/Bash/sqlite:${PATH:-}"
export SQLITE_DB

IFS=. read -r FROM_MAJ FROM_MIN FROM_PAT <<<"$FROM"
IFS=. read -r TO_MAJ TO_MIN TO_PAT <<<"$TO"
if [[ -z "${FROM_MAJ:-}" || -z "${FROM_MIN:-}" || -z "${FROM_PAT:-}" \
   || -z "${TO_MAJ:-}" || -z "${TO_MIN:-}" || -z "${TO_PAT:-}" ]]; then
  echo "Error: versions must be major.minor.patch (got from=$FROM to=$TO)" >&2
  exit 1
fi

# Active Business version as major.minor.patch
active=$(sqlite3 "$SQLITE_DB" "
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

if [[ -z "$active" ]]; then
  echo "Error: no active SchemaVersion for Business in $SQLITE_DB" >&2
  echo "Stamp a 0.2.11 shop with: SetSchemaVersion Business 0 2 11" >&2
  exit 1
fi

if [[ "$active" != "$FROM" ]]; then
  echo "Error: active Business version is $active, expected $FROM" >&2
  exit 1
fi

if [[ "$UPGRADE_BACKUP" == "1" ]]; then
  stamp=$(date +%Y%m%d-%H%M%S)
  bak="${SQLITE_DB}.bak.${stamp}"
  sqlite3 "$SQLITE_DB" ".backup '$bak'"
  echo "Backup: $bak"
fi

echo "Applying $HOP ..."
sqlite3 "$SQLITE_DB" < "$HOP"

# While the hop is still living/empty, leave STAMP_VERSION=0 so a shop is not
# marked as the next release without DDL. Set STAMP_VERSION=1 when the hop is
# complete enough to record Business <to> (same idea as uncommenting
# SetSchemaVersion in the PostgreSQL hop).
: "${STAMP_VERSION:=0}"
if [[ "$STAMP_VERSION" == "1" ]]; then
  echo "SetSchemaVersion Business $TO_MAJ $TO_MIN $TO_PAT ..."
  build=$(SetSchemaVersion Business "$TO_MAJ" "$TO_MIN" "$TO_PAT")
  echo "Upgraded $SQLITE_DB to Business $TO (SchemaVersion build=$build)"
else
  echo "Hop SQL applied. SchemaVersion still $FROM (STAMP_VERSION=0)."
  echo "When the hop is release-ready: STAMP_VERSION=1 $0 $FROM $TO"
fi