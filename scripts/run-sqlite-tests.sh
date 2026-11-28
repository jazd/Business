#!/usr/bin/env bash
# Run the SQLite and bash checks on this machine.
# Stock macOS bash is 3.2. This script does not use bash 4 features.
# It does not contact PostgreSQL, and it does not read a shop database.
#
#   ./scripts/run-sqlite-tests.sh [business.sqlite3]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
SRC="${1:-$ROOT/business.sqlite3}"

if [[ ! -f "$SRC" ]]; then
  echo "Error: SQLite template not found: $SRC" >&2
  exit 1
fi
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "Error: sqlite3 is not on PATH" >&2
  exit 1
fi

echo "bash: $(bash -c 'echo "$BASH_VERSION"')"
echo "sqlite3: $(sqlite3 -version)"
echo "template: $SRC"

passed=0
failed=0
skipped=0

for script in "$ROOT"/scripts/test-*.sh; do
  base=$(basename "$script")
  case "$base" in
    test-pg-upgrade-0.2.8-0.2.9.sh)
      echo "SKIP $base (drops a PostgreSQL schema)"
      skipped=$((skipped + 1))
      continue
      ;;
    test-content-reads.sh)
      echo "SKIP $base (needs a local PostgreSQL MyCo)"
      skipped=$((skipped + 1))
      continue
      ;;
  esac
  echo "RUN  $base"
  if "$script" "$SRC"; then
    echo "OK   $base"
    passed=$((passed + 1))
  else
    echo "FAIL $base"
    failed=$((failed + 1))
  fi
done

echo "$passed passed, $failed failed, $skipped skipped"
[[ "$failed" -eq 0 ]]
