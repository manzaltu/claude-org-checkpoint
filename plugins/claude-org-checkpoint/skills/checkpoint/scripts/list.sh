#!/usr/bin/env bash
# List checkpoint documents as TSV, one record per line:
# <abs-path><TAB><state><TAB><modified><TAB><title>
# <state> is the TODO keyword of the document's root heading (NONE when the
# heading carries no keyword), <modified> is the :MODIFIED: property (- when
# absent), <title> falls back to the file name when #+title: is absent.
# When no documents exist, prints nothing on stdout and notes it on stderr —
# a normal outcome, not an error.
#
# Usage: list.sh [--all]
#   --all  list documents for every project, not just the current one

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

dir=$(project_dir)
[[ "${1:-}" == "--all" ]] && dir=$(base_dir)

files=()
if [[ -d "$dir" ]]; then
  mapfile -d '' -t files < <(find "$dir" -type f -name '*.org' -print0 | sort -z)
fi

if (( ${#files[@]} == 0 )); then
  printf 'checkpoint: no documents in %s\n' "$dir" >&2
  exit 0
fi

for f in "${files[@]}"; do
  awk -v path="$f" -v fallback="$(basename "$f" .org)" '
    title == "" && tolower($0) ~ /^#\+title:/ {
      title = $0; sub(/^[^:]*:[ \t]*/, "", title)
    }
    state == "" && /^\* / {
      state = ($2 ~ /^[A-Z][A-Z]+$/) ? $2 : "NONE"
    }
    modified == "" && /^[ \t]*:MODIFIED:/ {
      modified = $0; sub(/^[ \t]*:MODIFIED:[ \t]*/, "", modified)
    }
    END {
      if (title == "") title = fallback
      if (state == "") state = "NONE"
      if (modified == "") modified = "-"
      printf "%s\t%s\t%s\t%s\n", path, state, modified, title
    }
  ' "$f"
done
