#!/usr/bin/env bash
# SetContentElement stores a dynamic name and type with GetIdentifier.
# SetFormatAttribute stores name, value, and target the same way.
# GetIdentifier('link') twice is one Word row with culture null.
#
#   ./scripts/test-content-writers.sh [business.sqlite3]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/business.sqlite3}"

if [[ ! -f "$SRC" ]]; then
  echo "Error: SQLite template not found: $SRC" >&2
  exit 1
fi

fail() {
  echo "Error: $*" >&2
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/business.sqlite3"
cp -a "$SRC" "$DB"
sqlite3 "$DB" < "$ROOT/SQLite/0.2.13-0.2.14.sql"
sqlite3 "$DB" < "$ROOT/SQLite/0.2.14-0.2.15.sql"

export SQLITE_DB="$DB"
export PATH="$ROOT/Bash/sqlite:${PATH:-}"

first=$("$ROOT/Bash/sqlite/GetIdentifier" link)
second=$("$ROOT/Bash/sqlite/GetIdentifier" link)
[[ "$first" == "$second" && -n "$first" ]] || fail "GetIdentifier link returned $first then $second"
culture=$(sqlite3 "$DB" "SELECT COALESCE(culture, 'null') FROM Word WHERE id = $first;")
[[ "$culture" == "null" ]] || fail "identifier culture is $culture"

content=$("$ROOT/Bash/sqlite/SetContent" "Writer template")
type_id=$("$ROOT/Bash/sqlite/GetIdentifier" url)
"$ROOT/Bash/sqlite/SetContentElement" "$content" 1 "" "" "" "" "" link url >/dev/null
row=$(sqlite3 -separator '|' "$DB" "
 SELECT COALESCE(word, ''), COALESCE(sentence, ''), COALESCE(paragraph, ''),
  name, type,
  COALESCE((SELECT CAST(culture AS TEXT) FROM Word WHERE id = ContentElement.name), 'null'),
  (SELECT value FROM Word WHERE id = ContentElement.name),
  (SELECT value FROM Word WHERE id = ContentElement.type)
 FROM ContentElement
 WHERE edition = (SELECT id FROM ContentEdition WHERE content = $content AND stop IS NULL);
")
[[ "$row" == "|||$first|$type_id|null|link|url" ]] || fail "dynamic row is $row"

word=$("$ROOT/Bash/sqlite/GetWord" subscription)
"$ROOT/Bash/sqlite/SetContentElement" "$content" 2 "" "$word" "" "" subscriptions >/dev/null
arg=$(sqlite3 "$DB" "
 SELECT Word.culture || '|' || Word.value
 FROM ContentElement
 JOIN Word ON Word.id = ContentElement.argument AND Word.culture = 1033
 WHERE sequence = 2
  AND edition = (SELECT id FROM ContentEdition WHERE content = $content AND stop IS NULL);
")
[[ "$arg" == "1033|subscriptions" ]] || fail "word argument is $arg"
idents=$(sqlite3 "$DB" "
 SELECT COALESCE(name, '') || '|' || COALESCE(type, '')
 FROM ContentElement
 WHERE sequence = 2
  AND edition = (SELECT id FROM ContentEdition WHERE content = $content AND stop IS NULL);
")
[[ "$idents" == "|" ]] || fail "word element stored identifiers $idents"
plain=$(sqlite3 "$DB" "
 SELECT COALESCE(squash, '')
 FROM ContentElement
 WHERE sequence = 2
  AND edition = (SELECT id FROM ContentEdition WHERE content = $content AND stop IS NULL);
")
[[ "$plain" == "" ]] || fail "unsquashed word stored squash $plain"

sent=$("$ROOT/Bash/sqlite/GetSentence" "Squash line")
"$ROOT/Bash/sqlite/SetContentElement" "$content" 3 "" "" "$sent" "" "" "" "" space >/dev/null
squash=$(sqlite3 "$DB" "
 SELECT COALESCE(culture, 'null') || '|' || value
 FROM Word
 WHERE id = (
  SELECT squash FROM ContentElement
  WHERE sequence = 3
   AND edition = (SELECT id FROM ContentEdition WHERE content = $content AND stop IS NULL)
 );
")
[[ "$squash" == "null|space" ]] || fail "squash word is $squash"
shown=$(sqlite3 "$DB" "
 SELECT COALESCE(squash, '')
 FROM ContentElements
 WHERE content = $content AND sequence = 3;
")
[[ "$shown" == "space" ]] || fail "ContentElements squash is $shown"
bare=$(sqlite3 "$DB" "
 SELECT COALESCE(squash, '')
 FROM ContentElements
 WHERE content = $content AND sequence = 2;
")
[[ "$bare" == "" ]] || fail "unsquashed ContentElements squash is $bare"

format=$("$ROOT/Bash/sqlite/SetFormat" "Body copy")
"$ROOT/Bash/sqlite/SetFormatAttribute" "$format" class lede html >/dev/null
attr=$(sqlite3 -separator '|' "$DB" "
 SELECT n.culture, n.value, v.value, t.value
 FROM FormatAttribute a
 JOIN Word n ON n.id = a.name
 JOIN Word v ON v.id = a.value
 JOIN Word t ON t.id = a.target
 WHERE a.format = $format AND a.stop IS NULL;
")
# culture null prints as empty before the first pipe
[[ "$attr" == "|class|lede|html" ]] || fail "format attribute is [$attr]"

shown=$(sqlite3 -separator '|' "$DB" "
 SELECT name, value, COALESCE(target, '')
 FROM FormatAttributes
 WHERE format = $format;
")
[[ "$shown" == "class|lede|html" ]] || fail "FormatAttributes is [$shown]"

read_content=$("$ROOT/Bash/sqlite/SetContent" "Read template")
hello=$("$ROOT/Bash/sqlite/GetSentence" "Read hello")
thanks=$("$ROOT/Bash/sqlite/GetSentence" "Read thanks")
para=$("$ROOT/Bash/sqlite/GetParagraph" "Read paragraph")
"$ROOT/Bash/sqlite/SetContentElement" "$read_content" 1 "" "" "$hello" "" "" >/dev/null
"$ROOT/Bash/sqlite/SetContentElement" "$read_content" 2 "" "" "" "" "" link url >/dev/null
"$ROOT/Bash/sqlite/SetContentElement" "$read_content" 3 "" "" "$thanks" "" "" >/dev/null
"$ROOT/Bash/sqlite/SetContentElement" "$read_content" 4 "" "" "" "$para" "" >/dev/null
lines=$(sqlite3 "$DB" "
 SELECT sequence || '|' || COALESCE(kind, '') || '|' || COALESCE(value, '')
  || '|' || COALESCE(identifier, '') || '|' || COALESCE(identifierType, '')
  || '|' || COALESCE(argument, '')
 FROM ContentElements
 WHERE content = $read_content
 ORDER BY sequence;
")
expected=$'1|sentence|Read hello|||\n2|dynamic||link|url|\n3|sentence|Read thanks|||\n4|paragraph|Read paragraph|||'
[[ "$lines" == "$expected" ]] || fail "read edition is [$lines]"
hist=$(sqlite3 "$DB" "
 SELECT kind FROM ContentHistory
 WHERE content = $read_content AND sequence = 2;
")
[[ "$hist" == "dynamic" ]] || fail "history kind is [$hist]"

word_line=$(sqlite3 "$DB" "
 SELECT kind || '|' || COALESCE(value, '') || '|' || COALESCE(identifier, '')
  || '|' || COALESCE(identifierType, '') || '|' || COALESCE(argument, '')
 FROM ContentElements
 WHERE content = $content AND sequence = 2;
")
[[ "$word_line" == "word|subscription|||subscriptions" ]] || fail "word kind is [$word_line]"

thankyou=$(sqlite3 "$DB" "
 SELECT sequence || '|' || kind || '|' || COALESCE(identifier, '')
  || '|' || COALESCE(identifierType, '')
 FROM ContentElements
 WHERE content = 10
 ORDER BY sequence;
")
[[ "$thankyou" == $'1|sentence||\n2|word||' ]] || fail "content 10 is [$thankyou]"

echo "Content writers ok ($SRC)"
