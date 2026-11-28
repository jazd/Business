#!/usr/bin/env bash
# Account and book helpers, and culture-first account names.
#
#   ./scripts/test-account-book-helpers.sh [business.sqlite3]
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
export PATH="$ROOT/Bash/sqlite:${PATH:-}"

fail() {
 echo "Error: $*" >&2
 exit 1
}

POST="$ROOT/Bash/sqlite/Post"
BOOK="$ROOT/Bash/sqlite/Book"
GETA="$ROOT/Bash/sqlite/GetAccount"
GETB="$ROOT/Bash/sqlite/GetBook"
SETC="$ROOT/Bash/sqlite/SetSentenceCulture"
LEDGER="$ROOT/Bash/sqlite/AccountLedger"
REPORT="$ROOT/Bash/sqlite/LedgerReport"

snapshot() {
 local table="$1"
 local where="$2"
 sqlite3 "$DB" "SELECT * FROM $table $where;"
}

seed_accounts=$(snapshot AccountName "WHERE account < 1000 ORDER BY account")
seed_books=$(snapshot BookName "WHERE book < 1000 ORDER BY book")
seed_book_accounts=$(snapshot BookAccount "WHERE book < 1000 ORDER BY book, increase, decrease")
seed_journals=$(snapshot JournalName "ORDER BY journal")
seed_ledger_journals=$(snapshot LedgerJournal "ORDER BY ledger, journal")
seed_ledger_accounts=$(snapshot LedgerAccount "ORDER BY ledger, account")
sqlite3 "$DB" "SELECT id, culture, value, length FROM Sentence ORDER BY id, culture, value;" | sort > "$TMP/sentence.before"

lines_of() {
 local entry="$1"
 sqlite3 "$DB" "
  SELECT account || '|' || credit || '|' || printf('%.4f', amount)
  FROM JournalEntry
  WHERE entry = $entry
  ORDER BY credit, account;
 "
}

count_rows() {
 sqlite3 "$DB" "SELECT COUNT(*) FROM $1;"
}

# Fresh file: Capital is Equity through es-MX. Cash is the seeded asset.
entry=$("$POST" Cash 1 Capital)
[[ "$(lines_of "$entry")" == $'100|0|1.0000\n5|1|1.0000' ]] || fail "fresh Capital did not post to Equity: $(lines_of "$entry")"

accounts_before=$(count_rows AccountName)
cash_id=$("$GETA" Cash Asset)
[[ "$cash_id" == "100" ]] || fail "GetAccount Cash Asset returned $cash_id"
[[ "$(count_rows AccountName)" == "$accounts_before" ]] || fail "GetAccount Cash inserted a row"

capital=$("$GETA" Capital Equity)
[[ "$capital" == "1000" ]] || fail "first new account is $capital"
[[ "$(sqlite3 "$DB" "SELECT name FROM AccountName WHERE account = $capital;")" == "225" ]] || fail "Capital account did not reuse sentence 225"
[[ "$(sqlite3 "$DB" "SELECT type || '|' || credit FROM AccountName WHERE account = $capital;")" == "70002|1" ]] || fail "Capital type or credit is wrong"
[[ "$capital" != "5" ]] || fail "Capital account is Equity"

entry=$("$POST" Cash 1 Capital)
[[ "$(lines_of "$entry")" == "100|0|1.0000
${capital}|1|1.0000" ]] || fail "Post Capital did not use the new account: $(lines_of "$entry")"

entry=$("$POST" Cash 1 Equity)
[[ "$(lines_of "$entry")" == $'100|0|1.0000\n5|1|1.0000' ]] || fail "Post Equity moved off account 5"

entry=$("$POST" Cash 1 5)
[[ "$(lines_of "$entry")" == $'100|0|1.0000\n5|1|1.0000' ]] || fail "Post 5 moved off account 5"

"$LEDGER" Capital >/dev/null

entry=$("$BOOK" Capital 100)
book_used=$(sqlite3 "$DB" "SELECT DISTINCT book FROM JournalEntry WHERE entry = $entry;")
[[ "$book_used" == "24" ]] || fail "Book Capital used book $book_used"
[[ "$(lines_of "$entry")" == $'100|0|100.0000\n5|1|100.0000' ]] || fail "Book Capital lines changed: $(lines_of "$entry")"

again=$("$GETA" Capital Equity)
[[ "$again" == "$capital" ]] || fail "second Capital account is $again"
[[ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM AccountName WHERE name = 225;")" == "1" ]] || fail "Capital sentence names more than one account"

out=$("$SETC" 225 es-MX Capital 2>"$TMP/es.err")
[[ "$out" == "225" ]] || fail "es-MX translation returned $out"
[[ ! -s "$TMP/es.err" ]] || fail "es-MX translation wrote: $(cat "$TMP/es.err")"
out=$("$SETC" 225 fr-FR Capital 2>"$TMP/fr.err")
[[ "$out" == "225" ]] || fail "fr-FR translation returned $out"
[[ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM Sentence WHERE id = 225 AND culture = 2058 AND value = 'Capital';")" == "1" ]] || fail "es-MX Capital row missing"
[[ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM Sentence WHERE id = 225 AND culture = 1036 AND value = 'Capital';")" == "1" ]] || fail "fr-FR Capital row missing"
rows_before=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Sentence WHERE id = 225;")
if "$SETC" 225 es-MX Capital >"$TMP/dup.out" 2>"$TMP/dup.err"; then
 fail "second es-MX translation succeeded"
fi
grep -q "already has" "$TMP/dup.err" || fail "second translation error was: $(cat "$TMP/dup.err")"
[[ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM Sentence WHERE id = 225;")" == "$rows_before" ]] || fail "second translation wrote a row"
if "$SETC" 225 zz-ZZ Capital >"$TMP/badc.out" 2>"$TMP/badc.err"; then
 fail "unknown culture succeeded"
fi
if "$SETC" 999999999 es-MX Capital >"$TMP/badi.out" 2>"$TMP/badi.err"; then
 fail "unknown sentence succeeded"
fi

entry=$("$POST" Cash 1 Capital)
[[ "$(lines_of "$entry")" == "100|0|1.0000
${capital}|1|1.0000" ]] || fail "Post Capital changed after translation"

card=$("$GETA" "Credit Card" Liability)
[[ "$card" -ge 1000 ]] || fail "Credit Card id $card is below 1000"
[[ "$(sqlite3 "$DB" "SELECT name || '|' || type || '|' || credit FROM AccountName WHERE account = $card;")" == "115|70001|1" ]] || fail "Credit Card did not reuse sentence 115"
[[ "$(sqlite3 "$DB" "SELECT name || '|' || typeName || '|' || credit FROM Accounts WHERE account = $card;")" == "Credit Card|Liability|1" ]] || fail "Accounts view for Credit Card is wrong"
card_again=$("$GETA" "Credit Card" Liability)
[[ "$card_again" == "$card" ]] || fail "second Credit Card is $card_again"
[[ "$(count_rows AccountName)" == "$(sqlite3 "$DB" "SELECT COUNT(DISTINCT account) FROM AccountName;")" ]] || fail "account ids are not distinct"

clearing=$("$GETA" "Stripe Clearing" Asset)
fees=$("$GETA" "Stripe Fees" Expense)
[[ "$clearing" -ge 1000 && "$fees" -ge 1000 && "$clearing" != "$fees" ]] || fail "Stripe accounts are $clearing and $fees"
[[ "$(sqlite3 "$DB" "SELECT credit FROM AccountName WHERE account = $clearing;")" == "0" ]] || fail "Stripe Clearing credit"
[[ "$(sqlite3 "$DB" "SELECT credit FROM AccountName WHERE account = $fees;")" == "0" ]] || fail "Stripe Fees credit"

accounts_now=$(count_rows AccountName)
if "$GETA" "Credit Card" Asset >"$TMP/clash.out" 2>"$TMP/clash.err"; then
 fail "Credit Card as Asset succeeded"
fi
grep -q "different type" "$TMP/clash.err" || fail "type clash error was: $(cat "$TMP/clash.err")"
if "$GETA" Nope Widget >"$TMP/type.out" 2>"$TMP/type.err"; then
 fail "unknown type succeeded"
fi
if "$GETA" "" Asset >"$TMP/empty.out" 2>"$TMP/empty.err"; then
 fail "empty name succeeded"
fi
[[ "$(count_rows AccountName)" == "$accounts_now" ]] || fail "rejected GetAccount wrote a row"

contra=$("$GETA" "Contra Equity" Equity contra)
[[ "$(sqlite3 "$DB" "SELECT type || '|' || credit FROM AccountName WHERE account = $contra;")" == "70002|0" ]] || fail "contra equity credit was not flipped"
draw=$("$GETA" Draw Dividend)
share=$("$GETA" Shares Share)
retained=$("$GETA" "Retained Earnings" Retained)
[[ "$(sqlite3 "$DB" "SELECT credit FROM AccountName WHERE account = $draw;")" == "0" ]] || fail "Dividend credit"
[[ "$(sqlite3 "$DB" "SELECT credit FROM AccountName WHERE account = $share;")" == "1" ]] || fail "Share credit"
[[ "$(sqlite3 "$DB" "SELECT credit FROM AccountName WHERE account = $retained;")" == "1" ]] || fail "Retained credit"

pay=$(sqlite3 "$DB" "SELECT s.value FROM JournalName j JOIN Sentence s ON s.id = j.name AND s.culture = 1033 WHERE j.journal = 6;")
[[ "$pay" == "Payments" ]] || fail "journal 6 is '$pay'"

books_before=$(count_rows BookName)
parts_before=$(count_rows BookAccount)
card_book=$("$GETB" "Card Charge" "$pay" Supply "Credit Card")
[[ "$card_book" == "1000" ]] || fail "first new book is $card_book"
card_book_again=$("$GETB" "Card Charge" "$pay" Supply "Credit Card")
[[ "$card_book_again" == "$card_book" ]] || fail "second Card Charge book is $card_book_again"
[[ "$(count_rows BookAccount)" == $((parts_before + 1)) ]] || fail "second Card Charge wrote a BookAccount row"

entry=$("$BOOK" "Card Charge" 40 2026-11-20)
[[ "$(lines_of "$entry")" == "106|0|40.0000
${card}|1|40.0000" ]] || fail "Card Charge lines: $(lines_of "$entry")"
report=$("$REPORT")
printf '%s\n' "$report" | grep -q "Liability" || fail "LedgerReport has no Liability"
printf '%s\n' "$report" | grep -q "Expense" || fail "LedgerReport has no Expense"
printf '%s\n' "$report" | grep "Liability" | grep -q "40.00" || fail "Liability line is not 40.00: $report"
printf '%s\n' "$report" | grep "Expense" | grep -q "40.00" || fail "Expense line is not 40.00: $report"
total_line=$(printf '%s\n' "$report" | sed 's/  */ /g' | grep ' Total ' | head -1)
debit=$(printf '%s\n' "$total_line" | awk '{print $(NF-1)}')
credit=$(printf '%s\n' "$total_line" | awk '{print $NF}')
[[ -n "$debit" && "$debit" == "$credit" ]] || fail "LedgerReport totals differ: $total_line"

split_book=$("$GETB" --split "Fee Split" "$pay" increase Cash decrease "Stripe Fees" 0.70 decrease Supply 0.30)
entry=$("$BOOK" "Fee Split" 100 2026-11-21)
[[ "$(lines_of "$entry")" == "100|0|100.0000
106|1|30.0000
${fees}|1|70.0000" ]] || fail "Fee Split lines: $(lines_of "$entry")"
split_again=$("$GETB" --split "Fee Split" "$pay" increase Cash decrease "Stripe Fees" 0.70 decrease Supply 0.30)
[[ "$split_again" == "$split_book" ]] || fail "second Fee Split book is $split_again"

books_now=$(count_rows BookName)
parts_now=$(count_rows BookAccount)
sentences_now=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Sentence WHERE value = 'Bad Split';")
if "$GETB" --split "Bad Split" "$pay" increase Cash decrease "Stripe Fees" 0.70 decrease Supply 0.20 >"$TMP/share.out" 2>"$TMP/share.err"; then
 fail "unbalanced shares succeeded"
fi
grep -q "add up to 1" "$TMP/share.err" || fail "share error was: $(cat "$TMP/share.err")"
[[ "$(count_rows BookName)" == "$books_now" ]] || fail "bad shares wrote a book"
[[ "$(count_rows BookAccount)" == "$parts_now" ]] || fail "bad shares wrote a book account"
[[ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM Sentence WHERE value = 'Bad Split';")" == "$sentences_now" ]] || fail "bad shares wrote a sentence"

if "$GETB" Rent "$pay" Cash Supply >"$TMP/rent.out" 2>"$TMP/rent.err"; then
 fail "second Rent book succeeded"
fi
grep -q "already exists" "$TMP/rent.err" || fail "Rent error was: $(cat "$TMP/rent.err")"
if "$GETB" "Missing Book" NoSuchJournal Cash Supply >"$TMP/jour.out" 2>"$TMP/jour.err"; then
 fail "unknown journal succeeded"
fi
if "$GETB" "Missing Book" "$pay" NoSuchAccount Supply >"$TMP/acct.out" 2>"$TMP/acct.err"; then
 fail "unknown account succeeded"
fi
[[ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM Sentence WHERE value = 'Missing Book';")" == "0" ]] || fail "failed book wrote a sentence"
[[ "$(count_rows BookName)" == "$books_now" ]] || fail "failed book wrote BookName"
[[ "$(count_rows BookAccount)" == "$parts_now" ]] || fail "failed book wrote BookAccount"

sqlite3 "$DB" "INSERT INTO AccountName (account, name, type, credit) VALUES (1500, 70, 70000, 0);"
floor=$("$GETA" "Past Floor" Asset)
[[ "$floor" == "1501" ]] || fail "account after 1500 is $floor"

for f in GetAccount GetBook SetSentenceCulture; do
 if grep -E 'DELETE|UPDATE' "$ROOT/Bash/sqlite/$f" >/dev/null; then
  fail "$f contains DELETE or UPDATE"
 fi
 if grep -E 'localtime|utc' "$ROOT/Bash/sqlite/$f" >/dev/null; then
  fail "$f mentions localtime or utc"
 fi
done

minute_ok() {
 local stored="$1"
 local before="$2"
 local after="$3"
 [[ "$stored" == "$before" || "$stored" == "$after" ]]
}

kiri_before=$(date -u +%Y-%m-%dT%H:%M)
kiri_acct=$(TZ=Pacific/Kiritimati "$GETA" "Kiritimati Cash" Asset)
kiri_book=$(TZ=Pacific/Kiritimati "$GETB" "Kiritimati Book" "$pay" Cash "$kiri_acct")
kiri_after=$(date -u +%Y-%m-%dT%H:%M)
kiri_stored=$(sqlite3 "$DB" "SELECT substr(replace(created, ' ', 'T'), 1, 16) FROM BookAccount WHERE book = $kiri_book;")
minute_ok "$kiri_stored" "$kiri_before" "$kiri_after" || fail "Kiritimati created $kiri_stored is outside $kiri_before .. $kiri_after"

gmt_before=$(date -u +%Y-%m-%dT%H:%M)
gmt_acct=$(TZ=Etc/GMT+12 "$GETA" "Gmt Cash" Asset)
gmt_book=$(TZ=Etc/GMT+12 "$GETB" "Gmt Book" "$pay" Cash "$gmt_acct")
gmt_after=$(date -u +%Y-%m-%dT%H:%M)
gmt_stored=$(sqlite3 "$DB" "SELECT substr(replace(created, ' ', 'T'), 1, 16) FROM BookAccount WHERE book = $gmt_book;")
minute_ok "$gmt_stored" "$gmt_before" "$gmt_after" || fail "GMT+12 created $gmt_stored is outside $gmt_before .. $gmt_after"

# Two accounts with the same en-US name still fail Post.
sqlite3 "$DB" "INSERT INTO AccountName (account, name, type, credit) VALUES (1600, 225, 70002, 1);"
journals=$(count_rows JournalEntry)
if "$POST" Cash 1 Capital >"$TMP/two.out" 2>"$TMP/two.err"; then
 fail "two en-US Capital accounts posted"
fi
grep -q "more than one account" "$TMP/two.err" || fail "clash error was: $(cat "$TMP/two.err")"
[[ "$(count_rows JournalEntry)" == "$journals" ]] || fail "clashing Post wrote a journal row"
entry=$("$POST" Cash 1 Equity)
[[ "$(lines_of "$entry")" == $'100|0|1.0000\n5|1|1.0000' ]] || fail "Equity no longer posts to account 5"

[[ "$(snapshot AccountName "WHERE account < 1000 ORDER BY account")" == "$seed_accounts" ]] || fail "seed accounts changed"
[[ "$(snapshot BookName "WHERE book < 1000 ORDER BY book")" == "$seed_books" ]] || fail "seed books changed"
[[ "$(snapshot BookAccount "WHERE book < 1000 ORDER BY book, increase, decrease")" == "$seed_book_accounts" ]] || fail "seed book accounts changed"
[[ "$(snapshot JournalName "ORDER BY journal")" == "$seed_journals" ]] || fail "journals changed"
[[ "$(snapshot LedgerJournal "ORDER BY ledger, journal")" == "$seed_ledger_journals" ]] || fail "ledger journals changed"
[[ "$(snapshot LedgerAccount "ORDER BY ledger, account")" == "$seed_ledger_accounts" ]] || fail "ledger accounts changed"
sqlite3 "$DB" "SELECT id, culture, value, length FROM Sentence ORDER BY id, culture, value;" | sort > "$TMP/sentence.after"
if comm -23 "$TMP/sentence.before" "$TMP/sentence.after" | grep -q .; then
 fail "a seed sentence row changed"
fi

echo "account and book helpers ($SRC)"
