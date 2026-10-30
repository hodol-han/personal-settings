#!/usr/bin/env bash
# Show effective limits on live orca scopes + gateway child adj distribution.
set -euo pipefail
CG=/sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice
for d in "$CG"/app-orca-*.scope; do
  [ -d "$d" ] || continue
  echo "$(basename "$d"): high=$(cat "$d/memory.high") max=$(cat "$d/memory.max") pids.max=$(cat "$d/pids.max")"
done
echo "gateway children oom_score_adj (expect no 1000 after gateway restart):"
while read -r p; do
  cat "/proc/$p/oom_score_adj" 2> /dev/null
done < <(cat "$CG/openclaw-gateway.service/cgroup.procs" 2> /dev/null) | sort | uniq -c
