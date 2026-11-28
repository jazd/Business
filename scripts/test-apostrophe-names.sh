#!/usr/bin/env bash
# A name with an apostrophe is stored and found exactly.
# Invoke helpers with BASH_BIN (default /bin/bash), not the script shebang.
#
#   ./scripts/test-apostrophe-names.sh [business.sqlite3]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/business.sqlite3}"
BASH_BIN="${BASH_BIN:-/bin/bash}"

if [[ ! -f "$SRC" ]]; then
  echo "Error: SQLite template not found: $SRC" >&2
  exit 1
fi
if [[ ! -x "$BASH_BIN" ]]; then
  echo "Error: bash not found: $BASH_BIN" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/business.sqlite3"
cp -a "$SRC" "$DB"
export SQLITE_DB="$DB"

fail() {
  echo "Error: $*" >&2
  exit 1
}

run() {
  "$BASH_BIN" "$@"
}

value_is() {
  local got="$1"
  local want="$2"
  local label="$3"
  [[ "$got" == "$want" ]] || fail "$label is '$got'"
}

escaped=$(run -c 'source "$1"; sql_escape "$2"' bash "$ROOT/Bash/sqlite/common" "O'Brien")
value_is "$escaped" "O''Brien" "sql_escape O'Brien"

given=$(run "$ROOT/Bash/sqlite/GetGiven" "O'Brien")
value_is "$(sqlite3 "$DB" "SELECT value FROM Given WHERE id = $given;")" "O'Brien" "GetGiven"
given_again=$(run "$ROOT/Bash/sqlite/GetGiven" "O'Brien")
value_is "$given_again" "$given" "second GetGiven"
value_is "$(sqlite3 "$DB" "SELECT COUNT(*) FROM Given WHERE value = 'O''Brien';")" "1" "Given rows for O'Brien"

family=$(run "$ROOT/Bash/sqlite/GetFamily" "O'Brien")
value_is "$(sqlite3 "$DB" "SELECT value FROM Family WHERE id = $family;")" "O'Brien" "GetFamily"
family_again=$(run "$ROOT/Bash/sqlite/GetFamily" "O'Brien")
value_is "$family_again" "$family" "second GetFamily"

person=$(run "$ROOT/Bash/sqlite/GetIndividualPerson" Steve '' "O'Brien" 1980-01-15)
stored_family=$(sqlite3 "$DB" "
 SELECT f.value
 FROM Individual ind
 JOIN Name n ON n.id = ind.name
 JOIN Family f ON f.id = n.family
 WHERE ind.id = $person;
")
value_is "$stored_family" "O'Brien" "GetIndividualPerson family"

sentence=$(run "$ROOT/Bash/sqlite/GetSentence" "Steve's test")
value_is "$(sqlite3 "$DB" "SELECT value FROM Sentence WHERE id = $sentence AND culture = 1033;")" "Steve's test" "GetSentence"
sentence_again=$(run "$ROOT/Bash/sqlite/GetSentence" "Steve's test")
value_is "$sentence_again" "$sentence" "second GetSentence"

account=$(run "$ROOT/Bash/sqlite/GetAccount" "Steve's Card" Liability)
value_is "$(sqlite3 "$DB" "
 SELECT s.value FROM AccountName an
 JOIN Sentence s ON s.id = an.name AND s.culture = 1033
 WHERE an.account = $account;
")" "Steve's Card" "GetAccount"
account_again=$(run "$ROOT/Bash/sqlite/GetAccount" "Steve's Card" Liability)
value_is "$account_again" "$account" "second GetAccount"

word=$(run "$ROOT/Bash/sqlite/GetWord" "O'Brien")
value_is "$(sqlite3 "$DB" "SELECT value FROM Word WHERE id = $word AND culture = 1033;")" "O'Brien" "GetWord"
word_again=$(run "$ROOT/Bash/sqlite/GetWord" "O'Brien")
value_is "$word_again" "$word" "second GetWord"

entity=$(run "$ROOT/Bash/sqlite/GetEntityName" "O'Brien & Associates")
value_is "$(sqlite3 "$DB" "SELECT name FROM Entity WHERE id = $entity;")" "O'Brien & Associates" "GetEntityName"
entity_again=$(run "$ROOT/Bash/sqlite/GetEntityName" "O'Brien & Associates")
value_is "$entity_again" "$entity" "second GetEntityName"

paragraph=$(run "$ROOT/Bash/sqlite/GetParagraph" "O'Brien's note")
value_is "$(sqlite3 "$DB" "SELECT value FROM Paragraph WHERE id = $paragraph AND culture = 1033;")" "O'Brien's note" "GetParagraph"
paragraph_again=$(run "$ROOT/Bash/sqlite/GetParagraph" "O'Brien's note")
value_is "$paragraph_again" "$paragraph" "second GetParagraph"

ident=$(run "$ROOT/Bash/sqlite/GetIdentifier" "O'Brien")
value_is "$(sqlite3 "$DB" "SELECT value FROM Word WHERE id = $ident AND culture IS NULL;")" "O'Brien" "GetIdentifier"
ident_again=$(run "$ROOT/Bash/sqlite/GetIdentifier" "O'Brien")
value_is "$ident_again" "$ident" "second GetIdentifier"

echo "apostrophe names ($BASH_BIN, $SRC)"
