#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  # Kill all child processes of the current script
  pkill -P $$ || true
}
trap cleanup SIGINT SIGTERM EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$SCRIPT_DIR/sipp-scenarios"
CALLERS_ROOT="$SCENARIO_DIR/callers"
CALLEES_ROOT="$SCENARIO_DIR/callees"
UAC_DIR="$SCENARIO_DIR/uac"
SUBJECT_INF="$SCENARIO_DIR/subject.csv"
PN_PROVIDERS_INF="$SCENARIO_DIR/pn_providers.csv"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift || true
fi

SIP_SERVER="${1:-${SIP_SERVER:-sip_server}}"  # Usage: ./run_caller_commands.sh [--dry-run] <server_host>
if [[ -z "$SIP_SERVER" ]]; then
  echo "SIP server not specified." >&2
  exit 1
fi

if [[ ! -d "$CALLERS_ROOT" ]]; then
  echo "callers root directory not found: $CALLERS_ROOT" >&2
  exit 1
fi
if [[ ! -d "$CALLEES_ROOT" ]]; then
  echo "callees root directory not found: $CALLEES_ROOT" >&2
  exit 1
fi
if [[ ! -f "$SUBJECT_INF" ]]; then
  echo "subject.csv not found: $SUBJECT_INF" >&2
  exit 1
fi

if [[ ! -d "$UAC_DIR" ]]; then
  echo "uac directory not found: $UAC_DIR" >&2
  exit 1
fi

mapfile -t SCENARIO_FILES < <(find "$UAC_DIR" -maxdepth 1 -type f -printf '%p\n')
if [[ ${#SCENARIO_FILES[@]} -eq 0 ]]; then
  echo "No scenario files in $UAC_DIR" >&2
  exit 1
fi

OUT_DIR="$SCRIPT_DIR/uac_out"
mkdir -p "$OUT_DIR"

# Gather caller directories (caller\d)
mapfile -t CALLER_DIRS < <(find "$CALLERS_ROOT" -maxdepth 1 -type d -regex '.*/caller[0-9]+' | sort)
if [[ ${#CALLER_DIRS[@]} -eq 0 ]]; then
  echo "No callerN directories found in $CALLERS_ROOT" >&2
  exit 1
fi

# Gather callee directories (callee\d)
mapfile -t CALLEE_DIRS < <(find "$CALLEES_ROOT" -maxdepth 1 -type d -regex '.*/callee[0-9]+' | sort)
if [[ ${#CALLEE_DIRS[@]} -eq 0 ]]; then
  echo "No calleeN directories found in $CALLEES_ROOT" >&2
  exit 1
fi

for cdir in "${CALLER_DIRS[@]}"; do
  caller_csv="$cdir/caller.csv"
  if [[ ! -f "$caller_csv" ]]; then
    echo "Skipping $(basename "$cdir"): missing caller.csv" >&2
    continue
  fi

  # Each caller.csv expected single user line plus header
  while IFS=';' read -r name caller_uri port endpoint password; do
    [[ -z "${name// }" ]] && continue
    [[ "$name" == "RANDOM" ]] && continue
    [[ "$name" == \#* ]] && continue

    if [[ -z "${caller_uri// }" || -z "${port// }" || -z "${password// }" ]]; then
      echo "Skipping malformed line in $(basename "$caller_csv"): $name;$caller_uri;$port;$endpoint;$password" >&2
      continue
    fi

    # Pick random callee directory and its callee.csv
    callee_dir="${CALLEE_DIRS[RANDOM % ${#CALLEE_DIRS[@]}]}"
    callee_csv="$callee_dir/callee.csv"
    if [[ ! -f "$callee_csv" ]]; then
      echo "Chosen callee dir $(basename "$callee_dir") missing callee.csv, skipping pairing" >&2
      continue
    fi

    scenario_file="${SCENARIO_FILES[RANDOM % ${#SCENARIO_FILES[@]}]}"
    base_caller="$(basename "$cdir")"
    base_callee="$(basename "$callee_dir")"
    log_file="$OUT_DIR/${base_caller}_${base_callee}_${caller_uri}_${port}.log"

    cmd=(sipp "${SIP_SERVER}:5060" -aa -au "$caller_uri" -ap "$password" -sf "$scenario_file" -p "$port" -m 1 -inf "$caller_csv" -inf "$callee_csv" -inf "$SUBJECT_INF" -inf "$PN_PROVIDERS_INF")
    echo "Running: ${cmd[*]}  # caller=$(basename "$cdir") callee=$(basename "$callee_dir") scenario=$(basename "$scenario_file") -> $log_file"

    if [[ $DRY_RUN -eq 0 ]]; then
      "${cmd[@]}" >"$log_file" 2>&1 &
    fi
  done < "$caller_csv"
done

if [[ $DRY_RUN -eq 0 ]]; then
  wait
  echo "All caller sipp processes completed."
else
  echo "Dry run finished (no commands executed)."
fi
