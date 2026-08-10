#!/usr/bin/env bash
# Shared helpers for the /checkpoint and /resume skills.
# Sourced by every script in this directory; do not execute directly.

set -euo pipefail

die() { printf 'checkpoint: %s\n' "$*" >&2; exit 1; }

# Base directory holding all checkpoint documents, overridable via
# CLAUDE_CHECKPOINT_DIR.
base_dir() {
  printf '%s\n' "${CLAUDE_CHECKPOINT_DIR:-$HOME/org/checkpoints}"
}

# Absolute project root: the enclosing git repository's top level, or the CWD
# when outside any repository.
project_root() {
  git rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$PWD"
}

# Short human-readable project slug (used for :CATEGORY:): basename of the
# project root, with leading dots stripped (.emacs.d -> emacs.d).
project_slug() {
  local root slug
  root=$(project_root)
  slug=$(basename "$root" | sed 's/^\.\{1,\}//')
  [[ -n "$slug" ]] || die "cannot derive a project slug from '$root'"
  printf '%s\n' "$slug"
}

# Flattened absolute project root, used as the per-project directory name:
# every character outside [A-Za-z0-9-] becomes '-', mirroring the encoding of
# ~/.claude/projects, so equally-named projects in different locations never
# collide (/home/user/projects/my-app -> -home-user-projects-my-app).
project_dir_slug() {
  project_root | tr -c 'A-Za-z0-9\n-' '-'
}

# Org-tag-safe variant of the project slug: org tags only allow
# [A-Za-z0-9_@], so every other character becomes an underscore
# (emacs.d -> emacs_d).
project_tag() {
  project_slug | tr -c 'A-Za-z0-9_@\n' '_'
}

# Directory holding the current project's checkpoint documents.
project_dir() {
  printf '%s/%s\n' "$(base_dir)" "$(project_dir_slug)"
}
