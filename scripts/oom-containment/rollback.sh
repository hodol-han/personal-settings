#!/usr/bin/env bash
# Roll back phase 1. Snapshot of pre-change state:
# snapshots/2026-08-24-oom-containment/
set -euo pipefail
DROPIN="$HOME/.config/systemd/user/app-orca-.scope.d/50-containment.conf"
[ -f "$DROPIN" ] && mv "$DROPIN" "$DROPIN.disabled"
systemctl --user daemon-reload
while read -r unit _; do
  systemctl --user set-property "$unit" MemoryHigh=infinity MemoryMax=infinity TasksMax=infinity
  echo "reset: $unit"
done < <(systemctl --user list-units 'app-orca-*.scope' --state=running --no-legend --plain)
sed -i '/^OPENCLAW_CHILD_OOM_SCORE_ADJ=/d' "$HOME/.openclaw/gateway.systemd.env" 2>/dev/null || true
echo "rolled back (gateway env change effective on next gateway restart)"
