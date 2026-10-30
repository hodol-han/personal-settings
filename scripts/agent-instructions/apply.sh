#!/usr/bin/env bash
# Install the global agent instruction files (Claude Code and Codex) from home/,
# with backup and rollback on failure.
set -Eeuo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/personal-settings/agent-instructions"
BACKUP_DIR="$STATE_DIR/backups/$(date -u +%Y%m%dT%H%M%SZ)-$$"
PATHS=(
  .claude/CLAUDE.md
  .codex/AGENTS.md
)
declare -A EXISTED=()

# Back up only the files that exist, and keep their permissions.
for path in "${PATHS[@]}"; do
  if [[ -f "$HOME/$path" ]]; then
    EXISTED["$path"]=1
    mkdir -p "$(dirname "$BACKUP_DIR/home/$path")"
    cp -p -- "$HOME/$path" "$BACKUP_DIR/home/$path"
  else
    EXISTED["$path"]=0
  fi
done

rollback() {
  local status="${1:-$?}"
  trap - ERR INT TERM
  set +e
  for path in "${PATHS[@]}"; do
    if [[ "${EXISTED[$path]}" == 1 ]]; then
      cp -p -- "$BACKUP_DIR/home/$path" "$HOME/$path"
    else
      rm -f -- "$HOME/$path"
    fi
  done
  echo "install failed; previous files restored from $BACKUP_DIR" >&2
  exit "$status"
}
trap rollback ERR
trap 'rollback 130' INT
trap 'rollback 143' TERM

for path in "${PATHS[@]}"; do
  install -D -m 0644 "$REPO/home/$path" "$HOME/$path"
done
"$REPO/scripts/agent-instructions/verify.sh"

trap - ERR INT TERM
if [[ -d "$BACKUP_DIR" ]]; then
  echo "backup: $BACKUP_DIR"
fi
