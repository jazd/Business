#!/usr/bin/env bash
# GetVersionName and SetSchemaVersion keep a version that points at a culture word.
# A new version stores culture-null words.
#
#   ./scripts/test-version-identifier.sh [business.sqlite3]
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

old_word=$(sqlite3 "$DB" "INSERT INTO Word (value, culture) VALUES ('zzoldname', 1033); SELECT id FROM Word WHERE value = 'zzoldname' AND culture = 1033;")
old_version=$(sqlite3 "$DB" "INSERT INTO Version (name, major, minor, patch) VALUES ($old_word, NULL, NULL, NULL); SELECT id FROM Version WHERE name = $old_word;")

found=$(GetVersionName zzoldname)
[[ "$found" == "$old_version" ]] || fail "culture word version returned $found, expected $old_version"
count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Version WHERE name IN (SELECT id FROM Word WHERE UPPER(value) = 'ZZOLDNAME');")
[[ "$count" == "1" ]] || fail "culture word version count is $count"

new_version=$(GetVersionName zzfresh 1 0 0)
[[ -n "$new_version" && "$new_version" != "$old_version" ]] || fail "new version id is '$new_version'"
cultures=$(sqlite3 "$DB" "SELECT COUNT(*) FROM Word WHERE id IN (SELECT name FROM Version WHERE id = $new_version UNION SELECT major FROM Version WHERE id = $new_version UNION SELECT minor FROM Version WHERE id = $new_version UNION SELECT patch FROM Version WHERE id = $new_version) AND culture IS NOT NULL;")
[[ "$cultures" == "0" ]] || fail "new version uses a culture word"
dotted=$(sqlite3 "$DB" "
 SELECT maj.value || '.' || minr.value || '.' || pat.value
 FROM Version
 JOIN Word maj ON maj.id = Version.major
 JOIN Word minr ON minr.id = Version.minor
 JOIN Word pat ON pat.id = Version.patch
 WHERE Version.id = $new_version;
")
[[ "$dotted" == "1.0.0" ]] || fail "dotted value is '$dotted'"

echo "version identifier passed ($SRC old $old_version new $new_version)"
