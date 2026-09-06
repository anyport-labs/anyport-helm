#!/usr/bin/env bash
# Installs the repo's git hooks from scripts/git-hooks into this clone.
#
# Usage:
#   ./scripts/install-git-hooks.sh
#
# Hooks live in the git common directory, so one install covers every worktree. Existing hooks
# are backed up rather than overwritten; re-running is safe.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/git-hooks" && pwd)"

# core.hooksPath wins over the default location when it is set, so honour it.
dest="$(git config --get core.hooksPath || true)"
if [ -z "$dest" ]; then
  dest="$(git rev-parse --git-common-dir)/hooks"
fi
mkdir -p "$dest"

for hook in "$src"/*; do
  name="$(basename "$hook")"
  target="$dest/$name"

  if [ -e "$target" ] && ! cmp -s "$hook" "$target"; then
    mv "$target" "$target.backup"
    echo "backed up existing $name to $name.backup"
  fi

  cp "$hook" "$target"
  chmod +x "$target"
  echo "installed $name -> $target"
done
