#!/usr/bin/env bash
# Helpers source common and call siblings from their own directory.
# PATH to Bash/sqlite is enough. A ~/bin/sqlite link is optional.
# Uses a copy of a shop template. Does not write the source file.
#
#   ./scripts/test-sqlite-helper-path.sh [business.sqlite3]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SRC="${1:-$ROOT/business.sqlite3}"

if [[ ! -f "$SRC" ]]; then
  echo "Error: SQLite template not found: $SRC" >&2
  exit 1
fi

fail() {
  echo "Error: $*" >&2
  exit 1
}

if grep -R -n --exclude '*~' -E '~/bin/sqlite/|dirname "\$0"' "$ROOT/Bash/sqlite"; then
  fail "a helper still uses ~/bin/sqlite or dirname of \$0"
fi
if grep -R -n --exclude '*~' 'sandbox/Business' "$ROOT/Bash/sqlite"; then
  fail "InvoicePDF sandbox fallback is still present"
fi

here_assign='HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"'
while IFS= read -r -d '' f; do
  bash -n "$f"
  if grep -q '"$HERE/' "$f" && ! grep -F -q -- "$here_assign" "$f"; then
    fail "missing HERE assignment in $f"
  fi
done < <(find "$ROOT/Bash/sqlite" -maxdepth 1 -type f ! -name '*~' -print0)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/business.sqlite3"
cp -a "$SRC" "$DB"
EMPTY_HOME="$TMP/empty-home"
mkdir -p "$EMPTY_HOME"

run_isolated() {
  env -u BUSINESS_ROOT \
    HOME="$EMPTY_HOME" \
    PATH="$ROOT/Bash/sqlite:/usr/bin:/bin" \
    SQLITE_DB="$DB" \
    "$@"
}

set +e
usage=$(cd "$EMPTY_HOME" && run_isolated Book 2>&1)
status=$?
set -e
[[ $status -eq 1 ]] || fail "Book with no args exited $status: $usage"
grep -F -q "Usage: Book" <<<"$usage" || fail "Book usage missing: $usage"

out=$(cd "$EMPTY_HOME" && run_isolated BookBalance Rent 1)
entry=$(tail -n 1 <<<"$out" | tr -d '[:space:]')
[[ "$entry" =~ ^[0-9]+$ ]] || fail "BookBalance did not print an entry id: $out"

set +e
pdf=$(cd "$EMPTY_HOME" && run_isolated InvoicePDF 1 "$TMP/invoice.pdf" 2>&1)
set -e
if grep -F -q "cannot find scripts/invoice_pdf.py" <<<"$pdf"; then
  fail "InvoicePDF did not locate scripts/invoice_pdf.py: $pdf"
fi

REAL_HOME="$HOME"
LINK="$REAL_HOME/bin/sqlite"
if [[ -L "$LINK" ]]; then
  link_out=$(cd "$EMPTY_HOME" && env -u BUSINESS_ROOT \
    HOME="$EMPTY_HOME" \
    PATH="$LINK:/usr/bin:/bin" \
    SQLITE_DB="$DB" \
    Book Rent 1)
  link_entry=$(tr -d '[:space:]' <<<"$link_out")
  [[ "$link_entry" =~ ^[0-9]+$ ]] || fail "symlink Book did not print an entry id: $link_out"
  set +e
  link_pdf=$(cd "$EMPTY_HOME" && env -u BUSINESS_ROOT \
    HOME="$EMPTY_HOME" \
    PATH="$LINK:/usr/bin:/bin" \
    SQLITE_DB="$DB" \
    InvoicePDF 1 "$TMP/invoice-link.pdf" 2>&1)
  set -e
  if grep -F -q "cannot find scripts/invoice_pdf.py" <<<"$link_pdf"; then
    fail "symlink InvoicePDF did not locate scripts/invoice_pdf.py: $link_pdf"
  fi
  echo "symlink ok"
else
  echo "symlink check skipped (no $LINK)"
fi

echo "sqlite helper path ok"
