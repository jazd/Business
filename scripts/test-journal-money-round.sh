#!/usr/bin/env bash
# Book and Post round new journal amounts to 4 decimal places.
# JournalReport still prints two decimals. A row written outside Book/Post
# is left unchanged. Uses a copy of a shop template.
#
#   ./scripts/test-journal-money-round.sh [business.sqlite3]
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

sqlite3 "$DB" < "$ROOT/SQLite/0.2.12-0.2.13.sql"
sqlite3 "$DB" "DELETE FROM JournalEntry;"

export SQLITE_DB="$DB"
export PATH="$ROOT/Bash/sqlite:${PATH:-}"

# A stored amount Book/Post must not rewrite.
old_id=$(sqlite3 "$DB" "
 INSERT INTO JournalEntry (journal, account, credit, amount)
 SELECT
  (SELECT jn.journal
   FROM JournalName jn
   JOIN Sentence js ON js.id = jn.name
   WHERE js.value = 'General' AND js.culture = 1033
   LIMIT 1),
  (SELECT an.account
   FROM AccountName an
   JOIN Sentence s ON s.id = an.name
   WHERE s.value = 'Rent' AND s.culture = 1033
   LIMIT 1),
  0,
  1.11119;
 SELECT last_insert_rowid();
")
old_before=$(sqlite3 "$DB" "SELECT printf('%.10f', amount) FROM JournalEntry WHERE id = $old_id;")

"$ROOT/Bash/sqlite/Book" Rent 100 >/dev/null
"$ROOT/Bash/sqlite/Book" Rent 385.50 >/dev/null
"$ROOT/Bash/sqlite/Book" Rent 100000.25 >/dev/null
"$ROOT/Bash/sqlite/Post" Rent 1.23456 Cash >/dev/null
"$ROOT/Bash/sqlite/BookBalance" Rent 1.23456 >/dev/null

old_after=$(sqlite3 "$DB" "SELECT printf('%.10f', amount) FROM JournalEntry WHERE id = $old_id;")
if [[ "$old_before" != "$old_after" ]]; then
  echo "Error: stored amount changed ($old_before -> $old_after)" >&2
  exit 1
fi

stored=$(sqlite3 "$DB" "
 SELECT printf('%.4f', amount)
 FROM JournalEntry
 WHERE id != $old_id
 ORDER BY id;
")
for need in 100.0000 385.5000 100000.2500 1.2346; do
  if ! grep -F -q -x -- "$need" <<<"$stored"; then
    echo "Error: stored amounts missing $need" >&2
    echo "$stored" >&2
    exit 1
  fi
done

"$ROOT/Bash/sqlite/JournalReport" > "$TMP/report.txt"
for need in 100.00 385.50 100000.25 1.23; do
  if ! grep -F -q -- "$need" "$TMP/report.txt"; then
    echo "Error: JournalReport missing $need" >&2
    cat "$TMP/report.txt" >&2
    exit 1
  fi
done
if grep -E -q '[0-9][eE][+-][0-9]' "$TMP/report.txt"; then
  echo "Error: scientific notation in JournalReport" >&2
  cat "$TMP/report.txt" >&2
  exit 1
fi

echo "Journal money round ok ($SRC)"
