#!/usr/bin/env bash
# Book and BookBalance store a civil date (YYYY-MM-DD, no time) on new journal lines.
# An omitted date is today in the given time zone, or the local zone.
# An explicit date is stored as given. A row written outside Book is left unchanged.
#
#   ./scripts/test-book-date.sh [business.sqlite3]
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
BOOK="$ROOT/Bash/sqlite/Book"
BALANCE="$ROOT/Bash/sqlite/BookBalance"

fail() {
  echo "Error: $*" >&2
  exit 1
}

count_rows() {
  sqlite3 "$DB" "SELECT COUNT(*) FROM JournalEntry;"
}

dates_for() {
  sqlite3 "$DB" "SELECT DISTINCT created FROM JournalEntry WHERE entry = $1 ORDER BY created;"
}

today_in() {
  TZ="$1" date +%Y-%m-%d
}

# Rows already stored must keep their created value.
sqlite3 "$DB" "SELECT id || '|' || COALESCE(created, '') FROM JournalEntry ORDER BY id;" > "$TMP/before.txt"

old_id=$(sqlite3 "$DB" "
 INSERT INTO JournalEntry (journal, account, credit, amount, created)
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
  1.11119,
  '2019-08-08 13:45:00';
 SELECT last_insert_rowid();
")

kiri=$(today_in Pacific/Kiritimati)
gmt=$(today_in Etc/GMT+12)
local_today=$(date +%Y-%m-%d)
if [[ "$kiri" == "$gmt" ]]; then
  fail "Pacific/Kiritimati and Etc/GMT+12 share a civil date ($kiri)"
fi

e_kiri=$(TZ=Pacific/Kiritimati "$BOOK" Rent 100)
e_gmt=$(TZ=Etc/GMT+12 "$BOOK" Rent 100)
[[ "$(dates_for "$e_kiri")" == "$kiri" ]] || fail "two-arg Book in Pacific/Kiritimati stored $(dates_for "$e_kiri"), want $kiri"
[[ "$(dates_for "$e_gmt")" == "$gmt" ]] || fail "two-arg Book in Etc/GMT+12 stored $(dates_for "$e_gmt"), want $gmt"

e_zone_kiri=$("$BOOK" Rent 1 '' Pacific/Kiritimati)
e_zone_gmt=$("$BOOK" Rent 1 '' ' Etc/GMT+12 ')
[[ "$(dates_for "$e_zone_kiri")" == "$kiri" ]] || fail "zone-only Kiritimati stored $(dates_for "$e_zone_kiri")"
[[ "$(dates_for "$e_zone_gmt")" == "$gmt" ]] || fail "zone-only GMT+12 stored $(dates_for "$e_zone_gmt")"

e_explicit=$("$BOOK" Rent 1 1999-12-31 Pacific/Kiritimati)
[[ "$(dates_for "$e_explicit")" == "1999-12-31" ]] || fail "explicit date stored $(dates_for "$e_explicit")"

e_ignore=$("$BOOK" Rent 1 1999-12-31 Not/AZone)
[[ "$(dates_for "$e_ignore")" == "1999-12-31" ]] || fail "explicit date with a zone stored $(dates_for "$e_ignore")"

e_local=$("$BOOK" Sale 50)
[[ "$(dates_for "$e_local")" == "$local_today" ]] || fail "local two-arg stored $(dates_for "$e_local"), want $local_today"

e_bal=$("$BALANCE" Rent 2 1999-12-31 | tail -n 1)
[[ "$(dates_for "$e_bal")" == "1999-12-31" ]] || fail "BookBalance date stored $(dates_for "$e_bal")"

e_bal2=$("$BALANCE" Sale 4 | tail -n 1)
[[ "$(dates_for "$e_bal2")" == "$local_today" ]] || fail "two-arg BookBalance stored $(dates_for "$e_bal2")"

new_entries="$e_kiri,$e_gmt,$e_zone_kiri,$e_zone_gmt,$e_explicit,$e_ignore,$e_local,$e_bal,$e_bal2"
timed=$(sqlite3 "$DB" "SELECT COUNT(*) FROM JournalEntry WHERE entry IN ($new_entries) AND CAST(created AS TEXT) LIKE '%:%';")
[[ "$timed" == "0" ]] || fail "new lines contain a time ($timed)"
shared=$(sqlite3 "$DB" "
 SELECT COUNT(*) FROM (
  SELECT entry FROM JournalEntry
  WHERE entry IN ($new_entries)
  GROUP BY entry
  HAVING COUNT(DISTINCT created) <> 1
 );
")
[[ "$shared" == "0" ]] || fail "an entry stored more than one created value"
lines=$(sqlite3 "$DB" "SELECT COUNT(*) FROM JournalEntry WHERE entry IN ($new_entries);")
[[ "$lines" -ge 18 ]] || fail "expected a pair of lines on each entry, got $lines"

reject_date() {
  local when="$1" rows
  rows=$(count_rows)
  if "$BOOK" Rent 1 "$when" >/dev/null 2>"$TMP/err"; then
    fail "invalid date $when was accepted"
  fi
  grep -q 'Error: date must be YYYY-MM-DD' "$TMP/err" || fail "date $when error was: $(cat "$TMP/err")"
  [[ "$(count_rows)" == "$rows" ]] || fail "rejected date $when wrote a journal row"
}

e_leap=$("$BOOK" Rent 1 2024-02-29)
[[ "$(dates_for "$e_leap")" == "2024-02-29" ]] || fail "leap day stored $(dates_for "$e_leap")"
reject_date 2023-02-29
reject_date 2026-13-01
reject_date 2026-04-31
reject_date 2026-02-31
reject_date not-a-date
reject_date 2026-02-31abc
if "$BOOK" Rent 1 '' Not/AZone >/dev/null 2>"$TMP/err"; then
  fail "invalid zone was accepted"
fi
grep -q "Error: unknown time zone" "$TMP/err" || fail "zone error was: $(cat "$TMP/err")"
if "$BOOK" Rent 1 '' ../Etc/passwd >/dev/null 2>&1; then
  fail "zone path escape was accepted"
fi
if "$BOOK" Rent 1 '' /etc/localtime >/dev/null 2>&1; then
  fail "absolute zone path was accepted"
fi
if [[ -f /usr/share/zoneinfo/US/Eastern || -L /usr/share/zoneinfo/US/Eastern ]]; then
  e_east=$("$BOOK" Rent 1 '' US/Eastern)
  [[ "$(dates_for "$e_east")" == "$(TZ=US/Eastern date +%Y-%m-%d)" ]] || fail "US/Eastern stored $(dates_for "$e_east")"
fi
e_ny=$("$BOOK" Rent 1 '' America/New_York)
[[ "$(dates_for "$e_ny")" == "$(TZ=America/New_York date +%Y-%m-%d)" ]] || fail "America/New_York stored $(dates_for "$e_ny")"
e_blank=$("$BOOK" Rent 1 '' '   ')
[[ "$(dates_for "$e_blank")" == "$local_today" ]] || fail "blank zone stored $(dates_for "$e_blank")"
before=$(count_rows)
if "$BOOK" Rent 100 extra nope also >/dev/null 2>&1; then
  fail "extra arguments were accepted"
fi
after=$(count_rows)
[[ "$before" == "$after" ]] || fail "rejected Book calls wrote journal rows ($before -> $after)"

now_old=$(sqlite3 "$DB" "SELECT created FROM JournalEntry WHERE id = $old_id;")
[[ "$now_old" == "2019-08-08 13:45:00" ]] || fail "raw created changed to $now_old"
while IFS='|' read -r id created; do
  [[ -n "$id" ]] || continue
  now=$(sqlite3 "$DB" "SELECT COALESCE(created, '') FROM JournalEntry WHERE id = $id;")
  [[ "$now" == "$created" ]] || fail "rewrote JournalEntry $id ($created -> $now)"
done < "$TMP/before.txt"

echo "Book date ok ($SRC)"
