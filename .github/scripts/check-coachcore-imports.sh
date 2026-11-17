#!/usr/bin/env bash
# Every App/ Swift file must `import CoachCore`. Swift 6 resolves imports per
# file, members included, so a file that only touches a CoachCore value's
# property (no type named) still fails, and only the macOS build sees it.
# Requiring the import everywhere catches every case on Linux in seconds;
# an unused import costs nothing.
set -euo pipefail
cd "$(dirname "$0")/../.."
status=0
while IFS= read -r -d '' file; do
  if ! grep -q '^import CoachCore$' "$file"; then
    echo "::error file=$file::missing 'import CoachCore' (every App/ file imports it)"
    status=1
  fi
done < <(find App -name '*.swift' -print0)
[ $status -eq 0 ] && echo "All App/ Swift files import CoachCore."
exit $status
