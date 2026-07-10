#!/usr/bin/env bash
set -euo pipefail

# run_siptorch_random.sh
# Execute siptorch.py N times selecting random caller / callee rows from the CSV datasets.
# Usage: ./run_siptorch_random.sh -n <iterations> [-m <concurrency>] [--dry-run] [--sip-server host] [--caller-ip ip] [--callee-ip ip]
# Environment fallbacks: SIP_SERVER, CALLER_IP, CALLEE_IP

cleanup() {
  # Kill all child processes of the current script
  pkill -P $$ || true
}
trap cleanup SIGINT SIGTERM EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIPTORCH_DIR="$SCRIPT_DIR/SIPTorch"
SIPTORCH_PY="$SIPTORCH_DIR/siptorch.py"
CALLER_CSV="$SCRIPT_DIR/caller.csv"
CALLEE_CSV="$SCRIPT_DIR/callee.csv"
LOG_DIR="$SCRIPT_DIR/siptorch_out"

mkdir -p "$LOG_DIR"

N=64
M=10
DRY_RUN=0
SIP_SERVER="${SIP_SERVER:-172.18.0.2}"
CALLER_IP="${CALLER_IP:-172.18.0.4}"
CALLEE_IP="${CALLEE_IP:-172.18.0.2}"

usage() {
  cat <<EOF
Usage: $0 -n <iterations> [options]
Options:
  -n N                Number of executions (required)
  -m M                Max concurrent jobs (default: 1)
  --dry-run           Print commands only
  --sip-server HOST   Override SIP server hostname (default: $SIP_SERVER)
  --caller-ip IP      Caller Contact IP (default: $CALLER_IP)
  --callee-ip IP      Callee Contact IP (default: $CALLEE_IP)
  -h, --help          Show this help
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n)
      N="$2"; shift 2;;
    -m)
      M="$2"; shift 2;;
    --dry-run)
      DRY_RUN=1; shift;;
    --sip-server)
      SIP_SERVER="$2"; shift 2;;
    --caller-ip)
      CALLER_IP="$2"; shift 2;;
    --callee-ip)
      CALLEE_IP="$2"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

if [[ "$N" -le 0 ]]; then
  echo "Iterations (-n) must be > 0" >&2
  usage
  exit 1
fi

if [[ "$M" -le 0 ]]; then
  echo "Concurrency (-m) must be > 0" >&2
  usage
  exit 1
fi

# Validate files
for f in "$SIPTORCH_PY" "$CALLER_CSV" "$CALLEE_CSV"; do
  [[ -f "$f" ]] || { echo "Required file not found: $f" >&2; exit 1; }
done

# Load caller and callee records into arrays (skip headers, comments, empty)
mapfile -t CALLER_ROWS < <(grep -Ev '^(#|RANDOM$|$)' "$CALLER_CSV")
mapfile -t CALLEE_ROWS < <(grep -Ev '^(#|RANDOM$|$)' "$CALLEE_CSV")

if [[ ${#CALLER_ROWS[@]} -eq 0 || ${#CALLEE_ROWS[@]} -eq 0 ]]; then
  echo "No usable rows found in caller or callee CSVs" >&2
  exit 1
fi

# Field layouts:
# caller.csv: caller_name;caller_uri;port;endpoint;password
# callee.csv: callee_name;port;endpoint;password

pad() { printf "%03d" "$1"; }

echo "Running $N siptorch executions (max $M concurrent)..."
for ((i=1; i<=N; i++)); do
  # Limit concurrency
  # while [[ $(jobs -r | wc -l) -ge $M ]]; do
  #   sleep 0.1
  # done

  caller_line="${CALLER_ROWS[RANDOM % ${#CALLER_ROWS[@]}]}"
  callee_line="${CALLEE_ROWS[RANDOM % ${#CALLEE_ROWS[@]}]}"

  IFS=';' read -r caller_name caller_uri caller_port caller_endpoint caller_password <<<"$caller_line"
  IFS=';' read -r callee_name callee_port callee_endpoint callee_password <<<"$callee_line"

  # Build From (-F) and To (-T) headers
  FROM_HDR="\"${caller_name}\" <sip:${caller_uri}@${CALLER_IP}:${caller_port}>"
  TO_HDR="\"${callee_name}\" <sip:${callee_endpoint}@${CALLEE_IP}:5060>"

  cmd=(python3 "$SIPTORCH_PY" -t 3 -u "$SIP_SERVER" -p 5060 -P "$caller_port" -e "$callee_endpoint" -F "$FROM_HDR" -T "$TO_HDR")
  log_file="$LOG_DIR/iter_$(pad $i).log"
  echo "[$(pad $i)/$N] ${cmd[*]}" # Display command

  if [[ $DRY_RUN -eq 0 ]]; then
    # Run in background
    (
      if "${cmd[@]}" >"$log_file" 2>&1; then
        echo " -> [$(pad $i)] OK"
      else
        echo " -> [$(pad $i)] FAIL (see $(basename "$log_file"))" >&2
      fi
    ) &
  fi

done

wait
echo "Done."
