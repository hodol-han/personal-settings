#!/usr/bin/env bash
# Phase 1 (no sudo): deploy scope drop-in, migrate live scopes, opt out
# openclaw child oom_score_adj=1000 shim (kernel then picks real culprit).
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$REPO/home/.config/systemd/user/app-orca-.scope.d/50-containment.conf"
DST="$HOME/.config/systemd/user/app-orca-.scope.d"
mkdir -p "$DST"
cp "$SRC" "$DST/50-containment.conf"
systemctl --user daemon-reload
# Migrate already-running scopes (drop-ins only affect newly created units)
while read -r unit _; do
  systemctl --user set-property "$unit" MemoryHigh=72% MemoryMax=78% TasksMax=4096
  echo "migrated: $unit"
done < <(systemctl --user list-units 'app-orca-*.scope' --state=running --no-legend --plain)
# openclaw: stop self-marking children with oom_score_adj=1000 (upstream opt-out)
ENVF="$HOME/.openclaw/gateway.systemd.env"
touch "$ENVF"
grep -q '^OPENCLAW_CHILD_OOM_SCORE_ADJ=' "$ENVF" ||
  echo 'OPENCLAW_CHILD_OOM_SCORE_ADJ=0' >> "$ENVF"
echo "NOTE: gateway env takes effect on next 'systemctl --user restart openclaw-gateway'"
"$REPO/scripts/oom-containment/verify.sh"
