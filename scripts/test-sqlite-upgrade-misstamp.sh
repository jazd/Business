#!/usr/bin/env bash
# One test of upgrade-sqlite.sh. Copies the shop file.
# A file already at or past the newest hop is not upgraded.
# EntitlementCurrent must still query on that file.
# An older file runs upgrade-sqlite.sh for the one hop that starts at its
# active version. A file that reports 0.2.11 and already has Entitlement and
# SchemaVersions uses upgrade-sqlite.sh 0.2.14 0.2.15.
# The active version afterward is the version that script printed.
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

ver_ge() {
  local IFS=.
  local -a left right
  local i av bv
  read -ra left <<<"$1"
  read -ra right <<<"$2"
  for i in 0 1 2; do
    av=${left[$i]:-0}
    bv=${right[$i]:-0}
    if (( 10#$av > 10#$bv )); then
      return 0
    fi
    if (( 10#$av < 10#$bv )); then
      return 1
    fi
  done
  return 0
}

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
if [[ -z "$active" ]]; then
  echo "Error: no active SchemaVersion for Business in $SRC" >&2
  exit 1
fi

newest_from=""
newest_to=""
shopt -s nullglob
for hop in "$ROOT"/SQLite/*.sql; do
  base=$(basename "$hop" .sql)
  [[ "$base" == *-* ]] || continue
  from=${base%%-*}
  to=${base#*-}
  [[ "$from" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
  [[ "$to" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
  if [[ -z "$newest_to" ]] || ! ver_ge "$newest_to" "$to"; then
    newest_from=$from
    newest_to=$to
  fi
done
shopt -u nullglob
if [[ -z "$newest_from" ]]; then
  echo "Error: no SQLite hop files under $ROOT/SQLite" >&2
  exit 1
fi

if ver_ge "$active" "$newest_from"; then
  sqlite3 "$DB" "SELECT COUNT(*) FROM EntitlementCurrent;" >/dev/null
  echo "Shop file is $active; EntitlementCurrent ok ($SRC)"
  exit 0
fi

release_objects=$(sqlite3 "$DB" "
 SELECT COUNT(*) FROM sqlite_master
 WHERE name IN ('Entitlement', 'SchemaVersions');
")
if [[ "$active" == "0.2.11" && "$release_objects" == "2" ]]; then
  from=0.2.14
  to=0.2.15
else
  shopt -s nullglob
  matches=( "$ROOT"/SQLite/"${active}"-*.sql )
  shopt -u nullglob
  if [[ ${#matches[@]} -ne 1 ]]; then
    echo "Error: expected one hop starting at $active, found ${#matches[@]}" >&2
    exit 1
  fi
  base=$(basename "${matches[0]}" .sql)
  from=${base%%-*}
  to=${base#*-}
fi

export PATH="$ROOT/Bash/sqlite:${PATH:-}"
log=$(SQLITE_DB="$DB" UPGRADE_BACKUP=0 "$ROOT/scripts/upgrade-sqlite.sh" "$from" "$to")
expect=$(printf '%s\n' "$log" | sed -n \
  -e 's/^Upgraded .* to Business \([0-9][0-9.]*\) .*/\1/p' \
  -e 's/^Hop SQL applied\. SchemaVersion still \([0-9][0-9.]*\) .*/\1/p' | tail -n 1)
if [[ -z "$expect" ]]; then
  echo "Error: upgrader did not report a version" >&2
  printf '%s\n' "$log" >&2
  exit 1
fi

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
if [[ "$active" != "$expect" ]]; then
  echo "Error: active version is $active, upgrader reported $expect" >&2
  printf '%s\n' "$log" >&2
  exit 1
fi

has_view=$(sqlite3 "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type = 'view' AND name = 'EntitlementCurrent';")
if [[ "$has_view" == "1" ]]; then
  sqlite3 "$DB" "SELECT COUNT(*) FROM EntitlementCurrent;" >/dev/null
fi

echo "Upgrade $from -> $to left Business $active ($SRC)"
