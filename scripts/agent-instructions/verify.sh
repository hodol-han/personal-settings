#!/usr/bin/env bash
# Verify that the installed global agent instruction files match home/.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"

for path in .claude/CLAUDE.md .codex/AGENTS.md; do
  cmp "$REPO/home/$path" "$HOME/$path"
  echo "verified: ~/$path"
done
