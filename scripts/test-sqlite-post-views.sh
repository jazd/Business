#!/usr/bin/env bash
# Every view created in SQLite/post.sql also exists in schema.xml.
# Accounts, Ledgers, and LedgerBalance are created from schema.xml.
# post.sql then replaces JournalReport and LedgerReport (two-decimal text, Total last).
#
#   ./scripts/test-sqlite-post-views.sh [business.sqlite3]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/business.sqlite3}"
if [[ ! -f "$SRC" && -f /tmp/business-0.2.12.sqlite3 ]]; then
  SRC=/tmp/business-0.2.12.sqlite3
fi
if [[ ! -f "$SRC" ]]; then
  echo "Error: SQLite template not found: $SRC" >&2
  exit 1
fi

fail() {
  echo "Error: $*" >&2
  exit 1
}

mapfile -t post_views < <(sed -n 's/^CREATE VIEW \([A-Za-z0-9_]*\).*/\1/p' "$ROOT/SQLite/post.sql")
[[ ${#post_views[@]} -gt 0 ]] || fail "SQLite/post.sql creates no views"
for name in "${post_views[@]}"; do
  grep -q "<view name=\"$name\"" "$ROOT/schema.xml" || fail "$name is in SQLite/post.sql and not in schema.xml"
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/business.sqlite3"
cp -a "$SRC" "$DB"

python3 - "$ROOT/schema.xml" "$DB" <<'PY'
import re, sqlite3, sys
src = open(sys.argv[1]).read()
con = sqlite3.connect(sys.argv[2])
for name in ("Accounts", "Ledgers", "LedgerBalance", "Books"):
    m = re.search(r'<view name="%s"[^>]*>\s*<sql>(.*?)</sql>' % name, src, re.S)
    if not m:
        raise SystemExit("schema.xml is missing %s" % name)
    sql = m.group(1).replace("!apos;", "'").replace("!lt;", "<").replace("!gt;", ">").replace("!amp;", "&").strip()
    con.execute("DROP VIEW IF EXISTS %s" % name)
    con.executescript("CREATE VIEW %s AS\n%s;" % (name, sql.rstrip(";")))
    con.execute("SELECT COUNT(*) FROM %s" % name).fetchone()
PY

# View replacements only. The earlier post.sql statements are triggers and indexes.
awk 'f; /^-- Amounts are text/{f=1}' "$ROOT/SQLite/post.sql" | sqlite3 "$DB"

export SQLITE_DB="$DB"
export PATH="$ROOT/Bash/sqlite:$PATH"
"$ROOT/Bash/sqlite/Book" Rent 100 >/dev/null

report=$(sqlite3 "$DB" "SELECT accountName || '|' || COALESCE(debit, '') || '|' || COALESCE(credit, '') FROM LedgerReport;")
printf '%s\n' "$report" | grep -q $'Expenses|100.00|' || fail "LedgerReport expenses row missing: $report"
last=$(printf '%s\n' "$report" | tail -n 1)
[[ "$last" == Total* ]] || fail "LedgerReport Total is not last: $last"
printf '%s\n' "$report" | grep -q 'e+' && fail "LedgerReport uses scientific notation" || true
printf '%s\n' "$report" | grep -q '|0.00|' && fail "LedgerReport printed a null side as 0.00" || true

journal=$(sqlite3 "$DB" "SELECT account || '|' || COALESCE(debit, '') || '|' || COALESCE(credit, '') FROM JournalReport;")
jlast=$(printf '%s\n' "$journal" | tail -n 1)
[[ "$jlast" == 'Total|100.00|100.00' ]] || fail "JournalReport total is '$jlast'"
rent=$(sqlite3 "$DB" "SELECT name FROM Books WHERE book = 1;")
[[ "$rent" == "Rent" ]] || fail "Books view name is '$rent'"

# Upgrade path: the hop creates the same schema.xml views on a 0.2.12 shop, twice.
HOP="$TMP/hop.sqlite3"
cp -a "$SRC" "$HOP"
sqlite3 "$HOP" < "$ROOT/SQLite/0.2.12-0.2.13.sql"
sqlite3 "$HOP" < "$ROOT/SQLite/0.2.12-0.2.13.sql"
[[ "$(sqlite3 "$HOP" "SELECT name FROM Books WHERE book = 1;")" == "Rent" ]] || fail "hop Books view"
sqlite3 "$HOP" "SELECT COUNT(*) FROM EdgeIndividuals; SELECT COUNT(*) FROM IndividualURL; SELECT COUNT(*) FROM IndividualEmailAddress;" >/dev/null

echo "sqlite post.sql views passed"
