#!/usr/bin/env bash
# What every container app in a cluster actually consumes, against the limits it declares but
# does not yet have. Run once per cluster before enabling ANYPORT_APPLY_RESOURCE_LIMITS: an app
# whose peak already exceeds its declared memory limit gets OOMKilled the moment the limit
# becomes real. See the agent's env.applyResourceLimits.
#
# Reads peak usage from the project-auxiliary VictoriaMetrics the observability bundle already
# collects — a peak over history, not the instantaneous sample `kubectl top` gives you, because
# a memory limit is enforced against peaks.
#
# Requires: kubectl, jq, curl.
#
# Usage:
#   ./scripts/check-app-resources.sh [kube-context] [window]
# Context defaults to the current one, window to 7d.
set -euo pipefail

CTX=${1:-$(kubectl config current-context)}
WINDOW=${2:-7d}
K="kubectl --context=$CTX"
PORT=${VM_PORT:-18428}

VM=$($K -n project-auxiliary get svc -o name 2>/dev/null | grep victoria-metrics-single-server | head -1 || true)
if [ -z "$VM" ]; then
  echo "no VictoriaMetrics in project-auxiliary on $CTX — is the observability bundle installed?" >&2
  exit 1
fi

$K -n project-auxiliary port-forward "$VM" "$PORT:8428" >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null || true' EXIT
for _ in $(seq 20); do
  curl -sf --max-time 2 "http://127.0.0.1:$PORT/api/v1/query?query=up" >/dev/null 2>&1 && break
  sleep 0.5
done

q() { curl -s --max-time 30 --data-urlencode "query=$1" "http://127.0.0.1:$PORT/api/v1/query"; }

# Peak working set (MiB) and peak 5m-rate CPU (millicores) per pod, over WINDOW.
PEAK_MEM=$(q "max by (namespace,pod) (max_over_time(container_memory_working_set_bytes{namespace=~\"project-.*\",container!=\"\",container!=\"POD\"}[$WINDOW])) / 1024 / 1024" \
  | jq -r '.data.result[]? | "\(.metric.namespace)\t\(.metric.pod)\t\(.value[1]|tonumber|floor)"')
PEAK_CPU=$(q "max by (namespace,pod) (max_over_time(rate(container_cpu_usage_seconds_total{namespace=~\"project-.*\",container!=\"\",container!=\"POD\"}[5m])[$WINDOW:1m])) * 1000" \
  | jq -r '.data.result[]? | "\(.metric.namespace)\t\(.metric.pod)\t\(.value[1]|tonumber|floor)"')

to_milli() { case "$1" in *m) echo "${1%m}";; ""|null) echo "";; *) awk "BEGIN{printf \"%d\", $1*1000}";; esac; }
to_mib() {
  case "$1" in
    *Gi) awk "BEGIN{printf \"%d\", ${1%Gi}*1024}";; *Mi) echo "${1%Mi}";;
    *Ki) awk "BEGIN{printf \"%d\", ${1%Ki}/1024}";;
    *G) awk "BEGIN{printf \"%d\", ${1%G}*953.674}";; *M) awk "BEGIN{printf \"%d\", ${1%M}*0.953674}";;
    ""|null) echo "";; *) awk "BEGIN{printf \"%d\", $1/1048576}";;
  esac
}
peak() { awk -F'\t' -v ns="$2" -v app="$3" 'BEGIN{m=0} $1==ns && index($2, app"-")==1 && $3>m {m=$3} END{print m+0}' <<< "$1"; }

printf '%-20s %-26s %10s %8s %10s %8s  %s\n' NAMESPACE APP "CPU peak" LIMIT "MEM peak" LIMIT VERDICT

$K get containerapps.runtime.anyport.dev -A -o json | jq -r '
  .items[] | [ .metadata.namespace, .metadata.name,
               (.spec.resources.limits.cpu // ""), (.spec.resources.limits.memory // "") ] | @tsv' |
while IFS=$'\t' read -r ns app cpulim memlim; do
  mem=$(peak "$PEAK_MEM" "$ns" "$app"); cpu=$(peak "$PEAK_CPU" "$ns" "$app")
  mem_lim=$(to_mib "$memlim"); cpu_lim=$(to_milli "$cpulim")

  verdict="ok"
  if [ -z "$memlim" ] && [ -z "$cpulim" ]; then
    verdict="declares nothing - unchanged by the fix"
  elif [ "$mem" = 0 ] && [ "$cpu" = 0 ]; then
    verdict="no usage in $WINDOW - not running, or newer than the data"
  else
    if [ -n "$mem_lim" ] && [ "$mem_lim" -gt 0 ]; then
      pct=$(( mem * 100 / mem_lim ))
      if   [ "$pct" -ge 100 ]; then verdict="WILL OOM: peak is ${pct}% of the memory limit"
      elif [ "$pct" -ge 80 ];  then verdict="AT RISK: peak is ${pct}% of the memory limit"
      elif [ "$pct" -ge 60 ];  then verdict="tight: peak is ${pct}% of the memory limit"
      fi
    fi
    if [ -n "$cpu_lim" ] && [ "$cpu_lim" -gt 0 ] && [ "$cpu" -ge "$cpu_lim" ]; then
      verdict="$verdict; will be CPU throttled"
    fi
  fi
  printf '%-20s %-26s %9sm %8s %9sMi %8s  %s\n' \
    "$ns" "$app" "$cpu" "${cpulim:--}" "$mem" "${memlim:--}" "$verdict"
done
