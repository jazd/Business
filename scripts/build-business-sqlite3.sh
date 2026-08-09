#!/usr/bin/env bash
# Build business.sqlite3 from schema + Static seeds + GeoNames postal sample.
# Mirrors make pgsqldb seed order without PL/pgSQL:
#   pre → schema → Static[01] → postal TSV → Static[2-9] (adapted) → addresses → post
#
# Usage:
#   ./scripts/build-business-sqlite3.sh [output.sqlite3]
#   FORCE=1 ./scripts/build-business-sqlite3.sh   # overwrite existing
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/business.sqlite3}"
SCHEMA="${ROOT}/schema.sqlite"

if [[ -f "$OUT" && "${FORCE:-0}" != "1" ]]; then
  echo "Refusing to overwrite existing $OUT (set FORCE=1 or remove it)." >&2
  exit 1
fi

if [[ ! -f "$SCHEMA" ]]; then
  echo "Missing $SCHEMA — run: make schema.sqlite" >&2
  exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Building SQLite database: $OUT"

rm -f "$OUT"
sqlite3 "$OUT" < "${ROOT}/SQLite/pre.sql"
sqlite3 "$OUT" < "$SCHEMA"

# --- Static 0–1: drop PG GetInterval; store interval as text ---
{
  for f in "${ROOT}"/Static/[01]_*; do
    [[ -f "$f" ]] || continue
    [[ "$f" == *~ ]] && continue
    sed -e "s/GetInterval('\\([^']*\\)')/'\\1'/g" "$f"
  done
} | sqlite3 "$OUT"

# --- Postal sample (same TSV as pgsqldb) ---
echo "Loading GeoNames postal sample…"
awk -f "${ROOT}/scripts/USZip.awk" "${ROOT}/Static/GeoNamesUSZipSample.tsv" \
  | awk -f "${ROOT}/scripts/PostalImportSQLite.awk" \
  | sqlite3 "$OUT"

# --- Static 2–9: GetSentence → Sentence lookup; skip GetAddress (handled below) ---
{
  for f in "${ROOT}"/Static/[23456789]_*; do
    [[ -f "$f" ]] || continue
    [[ "$f" == *~ ]] && continue
    # Skip Address seeds that call GetAddress
    case "$(basename "$f")" in
      3_Address.sql) continue ;;
    esac
    sed \
      -e "s/GetSentence('\\([^']*\\)')/(SELECT id FROM Sentence WHERE value = '\\1' AND culture = 1033 LIMIT 1)/g" \
      -e "s/, false/, 0/g" \
      -e "s/, true/, 1/g" \
      -e "s/ FROM DUAL//g" \
      "$f"
  done
} | sqlite3 "$OUT"

# Wiki addresses (Static/3_Address.sql parity)
sqlite3 "$OUT" < "${ROOT}/SQLite/seed-addresses.sql"

sqlite3 "$OUT" < "${ROOT}/SQLite/post.sql"

# Quick counts for operators
sqlite3 "$OUT" "
SELECT 'Country' AS t, COUNT(*) AS n FROM Country
UNION ALL SELECT 'Postal', COUNT(*) FROM Postal
UNION ALL SELECT 'Address', COUNT(*) FROM Address
UNION ALL SELECT 'Phone', COUNT(*) FROM Phone
UNION ALL SELECT 'BookName', COUNT(*) FROM BookName
UNION ALL SELECT 'Word', COUNT(*) FROM Word
UNION ALL SELECT 'Sentence', COUNT(*) FROM Sentence
UNION ALL SELECT 'Individual', COUNT(*) FROM Individual
UNION ALL SELECT 'Timezone', COUNT(*) FROM Timezone
UNION ALL SELECT 'PeriodName', COUNT(*) FROM PeriodName;
"

echo "Done: $OUT"
