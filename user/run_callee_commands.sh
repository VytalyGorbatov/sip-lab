#!/usr/bin/env bash
set -euo pipefail

cleanup() {
  # Kill all child processes of the current script
  pkill -P $$ || true
}
trap cleanup SIGINT SIGTERM EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_DIR="$SCRIPT_DIR/sipp-scenarios"
CSV_FILE="$SCENARIO_DIR/callee.csv"
UAS_DIR="$SCENARIO_DIR/uas"

# Optional: dry-run mode (use ./run_callee_commands.sh --dry-run)
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

if [[ ! -f "$CSV_FILE" ]]; then
  echo "CSV file not found: $CSV_FILE" >&2
  exit 1
fi

# Collect scenario files (any regular file) once.
if [[ ! -d "$UAS_DIR" ]]; then
  echo "uas directory not found: $UAS_DIR" >&2
  exit 1
fi
mapfile -t SCENARIO_FILES < <(find "$UAS_DIR" -maxdepth 1 -type f -printf '%p\n')
if [[ ${#SCENARIO_FILES[@]} -eq 0 ]]; then
  echo "No scenario files found in $UAS_DIR" >&2
  exit 1
fi

while IFS=';' read -r name port endpoint password; do
  # Skip empty, header, or comment lines
  [[ -z "${name// }" ]] && continue
  [[ "$name" == "RANDOM" ]] && continue
  [[ "$name" == \#* ]] && continue

  # Basic field validation
  if [[ -z "${port// }" || -z "${endpoint// }" ]]; then
    echo "Skipping malformed line: $name;$port;$endpoint;$password" >&2
    continue
  fi

  # Pick random scenario file
  scenario_file="${SCENARIO_FILES[RANDOM % ${#SCENARIO_FILES[@]}]}"

  cmd=(sipp -aa -p "$port" -s "sip:$endpoint" -sf "$scenario_file")
  echo "Running: ${cmd[*]}"
  if [[ $DRY_RUN -eq 0 ]]; then
    "${cmd[@]}" > "uas_out/${endpoint}_out.log" 2>&1 &
  fi
done < "$CSV_FILE"

if [[ $DRY_RUN -eq 0 ]]; then
  wait
  echo "All sipp processes completed."
else
  echo "Dry run finished (no commands executed)."
fi
