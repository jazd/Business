#!/usr/bin/env bash
# Account 6 is Fixed Assets. Sentence 78 stays on account 103 and the Equipment book.
# Post rejects a name that matches more than one account and accepts an account id.
# Capital, Card Sale, and Hosting each book one balanced entry.
# JournalEntry rows already stored are not rewritten.
#
#   ./scripts/test-shop-books.sh [business.sqlite3]
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

fail() {
  echo "Error: $*" >&2
  exit 1
}

fingerprint() {
  sqlite3 "$DB" "SELECT COUNT(*) || '|' || printf('%.4f', COALESCE(SUM(amount), 0)) || '|' || COALESCE(SUM(account * CASE WHEN credit THEN 1 ELSE -1 END), 0) FROM JournalEntry;"
}

before=$(fingerprint)
sqlite3 "$DB" < "$ROOT/SQLite/0.2.12-0.2.13.sql"
sqlite3 "$DB" < "$ROOT/SQLite/0.2.12-0.2.13.sql"
after=$(fingerprint)
[[ "$before" == "$after" ]] || fail "hop rewrote JournalEntry ($before -> $after)"

export SQLITE_DB="$DB"
POST="$ROOT/Bash/sqlite/Post"
BOOK="$ROOT/Bash/sqlite/Book"
LEDGER="$ROOT/Bash/sqlite/AccountLedger"
LIST="$ROOT/Bash/sqlite/ListBooks"

name_of() {
  sqlite3 "$DB" "SELECT s.value FROM AccountName an JOIN Sentence s ON s.id = an.name AND s.culture = 1033 WHERE an.account = $1;"
}

[[ "$(name_of 6)" == "Fixed Assets" ]] || fail "account 6 is '$(name_of 6)'"
[[ "$(name_of 103)" == "Equipment" ]] || fail "account 103 is '$(name_of 103)'"
[[ "$(name_of 109)" == "Hosting" ]] || fail "account 109 is '$(name_of 109)'"

equip=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT an.account) FROM AccountName an JOIN Sentence s ON s.id = an.name WHERE s.value = 'Equipment';")
[[ "$equip" == "1" ]] || fail "Equipment matches $equip accounts"

book4=$(sqlite3 "$DB" "SELECT s.value FROM BookName bn JOIN Sentence s ON s.id = bn.name AND s.culture = 1033 WHERE bn.book = 4;")
[[ "$book4" == "Equipment" ]] || fail "Equipment book is '$book4'"

capital_accounts=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT an.account) FROM AccountName an JOIN Sentence s ON s.id = an.name WHERE s.value = 'Capital';")
[[ "$capital_accounts" == "1" ]] || fail "Capital matches $capital_accounts accounts"

"$LIST" > "$TMP/books.txt"
for name in Capital "Card Sale" Hosting; do
  grep -q "$name" "$TMP/books.txt" || fail "ListBooks missing $name"
done

lines_of() {
  sqlite3 "$DB" "SELECT account || '|' || credit || '|' || printf('%.4f', amount) FROM JournalEntry WHERE entry = $1 ORDER BY credit, account;"
}

journal_of() {
  sqlite3 "$DB" "SELECT DISTINCT journal FROM JournalEntry WHERE entry = $1;"
}

expect_entry() {
  local entry="$1" journal="$2" expected="$3"
  [[ "$(journal_of "$entry")" == "$journal" ]] || fail "entry $entry journal $(journal_of "$entry") != $journal"
  [[ "$(lines_of "$entry")" == "$expected" ]] || fail "entry $entry lines [$(lines_of "$entry")] != [$expected]"
}

entry=$("$POST" Equipment 10 Cash)
expect_entry "$entry" 1 $'103|0|10.0000\n100|1|10.0000'
on6=$(sqlite3 "$DB" "SELECT COUNT(*) FROM JournalEntry WHERE entry = $entry AND account = 6;")
[[ "$on6" == "0" ]] || fail "Post Equipment wrote account 6"

entry=$("$POST" Cash 25 Capital)
expect_entry "$entry" 1 $'100|0|25.0000\n5|1|25.0000'

entry=$("$POST" 103 7 100)
expect_entry "$entry" 1 $'103|0|7.0000\n100|1|7.0000'

entry=$("$BOOK" Rent 5)
expect_entry "$entry" 6 $'101|0|5.0000\n100|1|5.0000'

entry=$("$BOOK" Capital 100)
expect_entry "$entry" 4 $'100|0|100.0000\n5|1|100.0000'

entry=$("$BOOK" "Card Sale" 40)
expect_entry "$entry" 2 $'110|0|40.0000\n102|1|40.0000'

entry=$("$BOOK" Hosting 15)
expect_entry "$entry" 6 $'109|0|15.0000\n100|1|15.0000'

# A second Equipment account makes the name ambiguous. The numeric id still posts.
sqlite3 "$DB" "INSERT INTO AccountName (account, name, type, credit) VALUES (901, 78, 70000, 0);"
count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM JournalEntry;")
if "$POST" Equipment 3 Cash >"$TMP/post.out" 2>"$TMP/post.err"; then
  fail "ambiguous Post Equipment succeeded"
fi
grep -q "more than one account" "$TMP/post.err" || fail "ambiguous Post error was: $(cat "$TMP/post.err")"
now=$(sqlite3 "$DB" "SELECT COUNT(*) FROM JournalEntry;")
[[ "$now" == "$count" ]] || fail "ambiguous Post wrote journal rows ($count -> $now)"

if "$LEDGER" Equipment >"$TMP/ledger.out" 2>"$TMP/ledger.err"; then
  fail "ambiguous AccountLedger Equipment succeeded"
fi
grep -q "more than one account" "$TMP/ledger.err" || fail "ambiguous AccountLedger error was: $(cat "$TMP/ledger.err")"

entry=$("$POST" 103 4 Cash)
expect_entry "$entry" 1 $'103|0|4.0000\n100|1|4.0000'

if "$POST" NotARealAccount 1 Cash >"$TMP/miss.out" 2>"$TMP/miss.err"; then
  fail "unknown account name posted"
fi
if "$POST" 99999 1 Cash >"$TMP/missid.out" 2>"$TMP/missid.err"; then
  fail "unknown account id posted"
fi

"$LEDGER" 100 >/dev/null
"$LEDGER" Capital >/dev/null

echo "Shop books ok ($SRC)"
