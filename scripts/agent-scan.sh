#!/usr/bin/env zsh
# Run Snyk Agent Scan against all skills in this repository.
#
# Prerequisites:
#   - uv installed (https://docs.astral.sh/uv/getting-started/installation/)
#   - SNYK_TOKEN set in environment (https://app.snyk.io/account -> API Token)
#
# Usage:
#   ./scripts/agent-scan.sh                 # scan all skills, rich output
#   ./scripts/agent-scan.sh --json          # JSON output (pipe-friendly)
#   ./scripts/agent-scan.sh --out results   # save JSON to results.json
#   FAIL_ON_ISSUES=0 ./scripts/agent-scan.sh  # never exit non-zero

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${0:A}")" && cd .. && pwd)"
JSON_FLAG=""
OUTPUT_FILE=""
FAIL_ON_ISSUES="${FAIL_ON_ISSUES:-1}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --json          Output results as JSON instead of rich text
  --out FILE      Write JSON output to FILE.json (implies --json)
  --no-fail       Do not exit with an error code when issues are found
  -h, --help      Show this help

Environment variables:
  SNYK_TOKEN      Required. Snyk API token from https://app.snyk.io/account
  FAIL_ON_ISSUES  Set to 0 to suppress non-zero exit on detected issues (default: 1)
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)       JSON_FLAG="--json"; shift ;;
    --out)        OUTPUT_FILE="$2"; JSON_FLAG="--json"; shift 2 ;;
    --no-fail)    FAIL_ON_ISSUES=0; shift ;;
    -h|--help)    usage ;;
    *)            echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "${SNYK_TOKEN:-}" ]]; then
  echo "ERROR: SNYK_TOKEN is not set." >&2
  echo "  Get yours at: https://app.snyk.io/account" >&2
  exit 1
fi

if ! command -v uvx &>/dev/null; then
  echo "ERROR: uvx (uv) is not installed." >&2
  echo "  Install: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi

RUN_CMD=(uvx snyk-agent-scan@latest --skills "$REPO_ROOT")
[[ -n "$JSON_FLAG" ]] && RUN_CMD+=("$JSON_FLAG")

if [[ -n "$OUTPUT_FILE" ]]; then
  echo "Scanning skills in $REPO_ROOT ..."
  set +e
  "${RUN_CMD[@]}" | tee "${OUTPUT_FILE}.json"
  scan_exit=${pipestatus[1]}
  set -e
  echo "Results saved to ${OUTPUT_FILE}.json"
else
  set +e
  "${RUN_CMD[@]}"
  scan_exit=$?
  set -e
fi

if [[ "$scan_exit" -ne 0 ]]; then
  echo "" >&2
  echo "Snyk Agent Scan detected issues (exit code: $scan_exit)." >&2
  if [[ "$FAIL_ON_ISSUES" -ne 0 ]]; then
    exit "$scan_exit"
  fi
fi
