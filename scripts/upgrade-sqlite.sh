#!/usr/bin/env bash
# Upgrade a shop SQLite database one hop: SQLite/<from>-<to>.sql
#
# Usage:
#   export SQLITE_DB=$HOME/business-shop/business.sqlite3
#   ./scripts/upgrade-sqlite.sh 0.2.13 0.2.14
#   ./scripts/upgrade-sqlite.sh 0.2.14 0.2.15
#
# Preconditions: active SchemaVersion Business = <from>.
# A downloaded 0.2.14 business.sqlite3 can still report 0.2.11. When
# Entitlement and SchemaVersions exist, this script treats that file as 0.2.14.
# A downloaded 0.2.13 file that reports 0.2.11 needs ALLOW_MISSTAMP=1.
# Released hops stamp <to>. The living 0.2.14 -> 0.2.15 hop does not,
# unless STAMP_VERSION=1.
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
  echo "Read SchemaVersions, then stamp the real release with SetSchemaVersion." >&2
  exit 1
fi

release_objects=$(sqlite3 "$SQLITE_DB" "
 SELECT COUNT(*) FROM sqlite_master
 WHERE name IN ('Entitlement', 'SchemaVersions');
")
restamp=0

if [[ "$active" == "0.2.11" && "$FROM" == "0.2.14" && "$release_objects" == "2" ]]; then
  echo "Active stamp is 0.2.11 and this file already has Entitlement and SchemaVersions."
  echo "Treating it as Business 0.2.14."
  active=0.2.14
  restamp=1
elif [[ "$active" == "0.2.11" && "$FROM" == "0.2.13" && "${ALLOW_MISSTAMP:-0}" == "1" ]]; then
  echo "ALLOW_MISSTAMP=1: treating active 0.2.11 as Business 0.2.13."
  active=0.2.13
  restamp=1
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

if [[ "$restamp" == "1" ]]; then
  echo "SetSchemaVersion Business $FROM_MAJ $FROM_MIN $FROM_PAT ..."
  SetSchemaVersion Business "$FROM_MAJ" "$FROM_MIN" "$FROM_PAT"
fi

echo "Applying $HOP ..."
sqlite3 "$SQLITE_DB" < "$HOP"

# Released hops record Business <to>. The living 0.2.14 -> 0.2.15 hop does not
# until STAMP_VERSION=1.
if [[ -z "${STAMP_VERSION+x}" ]]; then
  if [[ "$FROM" == "0.2.14" && "$TO" == "0.2.15" ]]; then
    STAMP_VERSION=0
  else
    STAMP_VERSION=1
  fi
fi
if [[ "$STAMP_VERSION" == "1" ]]; then
  echo "SetSchemaVersion Business $TO_MAJ $TO_MIN $TO_PAT ..."
  build=$(SetSchemaVersion Business "$TO_MAJ" "$TO_MIN" "$TO_PAT")
  echo "Upgraded $SQLITE_DB to Business $TO (SchemaVersion build=$build)"
else
  echo "Hop SQL applied. SchemaVersion still $FROM (STAMP_VERSION=0)."
  echo "When the hop is release-ready: STAMP_VERSION=1 $0 $FROM $TO"
fi