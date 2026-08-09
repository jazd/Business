#!/usr/bin/env bash
# Test PostgreSQL/0.2.8-0.2.9.sql against a clean 0.2.8 baseline on host "postgres".
#
# Preferred over git checkout 0.2.8 + make pgsqldb:
#  - stays on current branch (develop)
#  - avoids leftover types (journalentryresult) from a prior develop install
#  - uses DROP SCHEMA (as postgres superuser) for a clean slate
#
# Usage (from repo root, on develop with working 0.2.8-0.2.9.sql):
#   ./scripts/test-pg-upgrade-0.2.8-0.2.9.sh
#   ./scripts/test-pg-upgrade-0.2.8-0.2.9.sh --fitnesse   # also run DbFit suite (optional)
#
# Env:
#   PGHOST=postgres  PGUSER=test  PGDATABASE=MyCo  PG_SUPERUSER=postgres
#
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

PGHOST=${PGHOST:-postgres}
PGUSER=${PGUSER:-test}
PGDATABASE=${PGDATABASE:-MyCo}
PG_SUPERUSER=${PG_SUPERUSER:-postgres}
BASE=${BASE:-/tmp/business-0.2.8-baseline}
TAG=${TAG:-0.2.8}
RUN_FITNESSE=0
for a in "$@"; do
  case "$a" in
    --fitnesse) RUN_FITNESSE=1 ;;
  esac
done

psql_test() { psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" "$@"; }
psql_super() { psql -h "$PGHOST" -U "$PG_SUPERUSER" -d "$PGDATABASE" "$@"; }

echo "== Extract $TAG sources to $BASE =="
rm -rf "$BASE"
mkdir -p "$BASE/PostgreSQL" "$BASE/Static" "$BASE/scripts"
git show "$TAG:schema.xml" > "$BASE/schema.xml"
git show "$TAG:PostgreSQL/pre.sql" > "$BASE/PostgreSQL/pre.sql"
git show "$TAG:PostgreSQL/procedures.sql" > "$BASE/PostgreSQL/procedures.sql"
git show "$TAG:PostgreSQL/post.sql" > "$BASE/PostgreSQL/post.sql"
git show "$TAG:LICENSE.txt" > "$BASE/LICENSE.txt"
git archive "$TAG" Static | tar -x -C "$BASE"
git show "$TAG:scripts/USZip.awk" > "$BASE/scripts/USZip.awk"
git show "$TAG:scripts/PostalImportPostgreSQL.awk" > "$BASE/scripts/PostalImportPostgreSQL.awk"

echo "== Generate $TAG schema.pgsql =="
SQLT=${SQLT:-/usr/local/bin/sqlt}
sed 's/^/-- /' "$BASE/LICENSE.txt" > "$BASE/schema.pgsql"
"$SQLT" -f XML-SQLFairy -t PostgreSQL --add-drop-table "$BASE/schema.xml" \
  | sed -e 's|["'\'']||g' \
  | sed -e "s/\!apos;/'/g" -e "s/\!lt;/</g" -e "s/\!gt;/>/g" -e "s/!amp;/\&/g" \
  | sed -e "s/DROP TABLE /DROP TABLE IF EXISTS /g" -e "s/DROP VIEW /DROP VIEW IF EXISTS /g" \
  >> "$BASE/schema.pgsql"

echo "== DROP/CREATE schema business (superuser) =="
# User "test" cannot DROP SCHEMA if owner is postgres (common after older installs).
psql_super -v ON_ERROR_STOP=1 <<SQL
DROP SCHEMA IF EXISTS business CASCADE;
CREATE SCHEMA business AUTHORIZATION $PGUSER;
GRANT ALL ON SCHEMA business TO $PGUSER;
SQL

echo "== Load $TAG core + statics =="
cat "$BASE/PostgreSQL/pre.sql" "$BASE/schema.pgsql" \
    "$BASE/PostgreSQL/procedures.sql" "$BASE/PostgreSQL/post.sql" \
  | psql_test -v ON_ERROR_STOP=1 -q
cat "$BASE/Static"/[01]_* | psql_test -v ON_ERROR_STOP=1 -q
awk -f "$BASE/scripts/USZip.awk" "$BASE/Static/GeoNamesUSZipSample.tsv" \
  | awk -f "$BASE/scripts/PostalImportPostgreSQL.awk" \
  | psql_test -v ON_ERROR_STOP=1 -q
cat "$BASE/Static"/[23456789]_* | psql_test -v ON_ERROR_STOP=1 -q

echo "== Mark SchemaVersion $TAG =="
# Fresh tag load does not call SetSchemaVersion; upgrade script requires active 0.2.8.
psql_test -v ON_ERROR_STOP=1 -c "SET search_path TO business, public; SELECT SetSchemaVersion('Business', '0', '2', '8');"

echo "== Run PostgreSQL/0.2.8-0.2.9.sql from working tree =="
psql_test -v ON_ERROR_STOP=1 -f "$ROOT/PostgreSQL/0.2.8-0.2.9.sql"

echo "== Post-upgrade version =="
psql_test -c "
SET search_path TO business, public;
SELECT major.value AS major, minor.value AS minor, patch.value AS patch, sv.stop IS NULL AS active
FROM schemaversion sv
JOIN word AS schema ON schema.id = sv.schema
JOIN version v ON v.id = sv.version
JOIN word major ON major.id = v.major
JOIN word minor ON minor.id = v.minor
JOIN word patch ON patch.id = v.patch
WHERE schema.value = 'Business'
ORDER BY sv.build;
"

if [[ "$RUN_FITNESSE" -eq 1 ]]; then
  echo "== FitNesse suite (optional; SchemaVersion history pages may differ from fresh install) =="
  curl -sS --http1.0 -m 900 -o /tmp/fitnesse_upgrade_suite.xml \
    'http://localhost:8085/BusinessSchema.PostgreSqlSuite?suite&format=xml'
  python3 - <<'PY'
from pathlib import Path
import re
xml = Path('/tmp/fitnesse_upgrade_suite.xml').read_text(errors='replace')
pages = list(re.finditer(
    r'<result>\s*<counts>\s*<right>(\d+)</right>\s*<wrong>(\d+)</wrong>\s*<ignores>(\d+)</ignores>\s*<exceptions>(\d+)</exceptions>\s*</counts>.*?<relativePageName>([^<]+)</relativePageName>',
    xml, re.S))
sw = se_x = 0
for m in pages:
    w, e, n = int(m.group(2)), int(m.group(4)), m.group(5)
    if w:
        print(f'WRONG {n}: wrong={w}')
        sw += w
    if e and 'Xcept' not in n:
        print(f'UNEXPECTED EXC {n}: exceptions={e}')
        se_x += e
    if e and 'Xcept' in n:
        print(f'EXPECTED EXC {n}: exceptions={e}')
print('total wrong assertions', sw)
print('PASS' if sw == 0 and se_x == 0 else 'CHECK FAILURES')
PY
fi

echo "OK: upgrade script completed."
