#!/usr/bin/env bash
# Book and BookBalance under a date that rejects -d and a realpath that rejects -e.
# Those are the GNU flags stock macOS does not have. Stored dates stay the same.
#
#   ./scripts/test-book-date-shim.sh [business.sqlite3]
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

REAL_DATE=$(command -v date)
if [[ -z "$REAL_DATE" || ! -x "$REAL_DATE" ]]; then
  echo "Error: date was not found" >&2
  exit 1
fi

mkdir -p "$TMP/bin"
cat > "$TMP/bin/date" << EOF
#!/bin/sh
real=$REAL_DATE
for arg in "\$@"; do
  case "\$arg" in
    -d|--date|-d*)
      echo "date: invalid option" >&2
      exit 1
      ;;
  esac
done
exec "\$real" "\$@"
EOF
cat > "$TMP/bin/realpath" << 'EOF'
#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    -e|--canonicalize|--canonicalize-existing|--canonicalize-missing)
      echo "realpath: invalid option" >&2
      exit 1
      ;;
  esac
done
echo "realpath: refusing GNU-only call" >&2
exit 1
EOF
chmod +x "$TMP/bin/date" "$TMP/bin/realpath"

export PATH="$TMP/bin:$PATH"
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

rows=$(count_rows)
e_leap=$("$BOOK" Rent 1 2024-02-29)
[[ "$(dates_for "$e_leap")" == "2024-02-29" ]] || fail "leap day stored $(dates_for "$e_leap")"

if "$BOOK" Rent 1 2023-02-29 >/dev/null 2>"$TMP/err"; then
  fail "2023-02-29 was accepted"
fi
grep -q 'Error: date must be YYYY-MM-DD' "$TMP/err" || fail "leap error was: $(cat "$TMP/err")"
[[ "$(count_rows)" == "$((rows + 2))" ]] || fail "rejected leap day wrote a row"

ny=$(TZ=America/New_York "$REAL_DATE" +%Y-%m-%d)
e_ny=$("$BOOK" Rent 1 '' America/New_York)
[[ "$(dates_for "$e_ny")" == "$ny" ]] || fail "zone today stored $(dates_for "$e_ny"), want $ny"

if "$BOOK" Rent 1 '' Not/AZone >/dev/null 2>&1; then
  fail "invalid zone was accepted"
fi
if "$BOOK" Rent 1 '' ../Etc/passwd >/dev/null 2>&1; then
  fail "zone escape was accepted"
fi
if "$BOOK" Rent 1 '' /etc/localtime >/dev/null 2>&1; then
  fail "absolute zone was accepted"
fi

e_bal=$("$BALANCE" Rent 2 1999-12-31 | tail -n 1)
[[ "$(dates_for "$e_bal")" == "1999-12-31" ]] || fail "BookBalance stored $(dates_for "$e_bal")"

if grep -R -i -n 'localtime' "$ROOT/SQLite" "$ROOT/Bash/sqlite" >/dev/null; then
  fail "localtime appeared in SQLite or Bash/sqlite"
fi
utc_now=$("$REAL_DATE" -u +%Y-%m-%dT%H:%M)
for zone in Pacific/Kiritimati Etc/GMT+12; do
  got=$(TZ="$zone" sqlite3 :memory: "SELECT strftime('%Y-%m-%dT%H:%M', datetime('now'));")
  [[ "$got" == "$utc_now" ]] || fail "datetime('now') in $zone is $got, UTC minute is $utc_now"
done

echo "Book date shim ok ($SRC)"
