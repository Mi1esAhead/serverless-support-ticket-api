#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tf_dir="$(cd -- "$script_dir/../terraform" && pwd)"
action="${1:-}"
case "$action" in
  status)
    api="$(terraform -chdir="$tf_dir" output -raw api_url)"
    if health="$(curl --fail --silent --show-error --max-time 15 "$api/health")" &&
       printf '%s' "$health" | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("status") == "ok" else 1)'; then
      echo "ONLINE (application responding; storage not checked)"
    else
      echo "OFFLINE / UNREACHABLE"
      exit 1
    fi
    ;;
  on|off)
    enabled=false
    if [[ "$action" == on ]]; then enabled=true; fi
    printf '{"demo_enabled": %s}\n' "$enabled" > "$tf_dir/zz-demo.auto.tfvars.json"
    echo "Desired state saved: demo_enabled=$enabled. Review the full apply plan."
    terraform -chdir="$tf_dir" apply
    echo "Apply complete. Run this script with status to check reachability."
    ;;
  *) echo "Usage: $0 on|off|status" >&2; exit 2 ;;
esac