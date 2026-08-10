#!/usr/bin/env bash
# Print the checkpoint locations for the current project as TSV, one
# <key><TAB><value> pair per line: base (top-level checkpoint directory),
# project (directory-safe slug), tag (org-tag-safe slug), root (absolute
# project root), dir (this project's document directory), today (current date
# as an inactive org timestamp), now (the same with time), commit (short
# HEAD — omitted outside a git repository or before the first commit).
# Scoped by the CWD's enclosing git repository.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

printf 'base\t%s\n' "$(base_dir)"
printf 'project\t%s\n' "$(project_slug)"
printf 'tag\t%s\n' "$(project_tag)"
printf 'root\t%s\n' "$(project_root)"
printf 'dir\t%s\n' "$(project_dir)"
printf 'today\t%s\n' "$(LC_TIME=C date +'[%Y-%m-%d %a]')"
printf 'now\t%s\n' "$(LC_TIME=C date +'[%Y-%m-%d %a %H:%M]')"
if commit=$(git rev-parse --short HEAD 2>/dev/null); then
  printf 'commit\t%s\n' "$commit"
fi
