#!/usr/bin/env bash
# Copado Function entrypoint: publish a finished CRT build's results to Zephyr Scale.
#
# Runs as a pipeline step AFTER the Robotic Testing step. Reads its inputs from
# environment variables (Copado Function parameters + injected secrets):
#
#   Secrets / config (Copado credentials injected as env):
#     ZEPHYR_API_KEY      Zephyr Scale API token                         [required]
#     COPADO_PAT          CRT personal access key (X-Authorization)      [required]
#     COPADO_BASE_URL     default https://api.au-robotic.copado.com
#     COPADO_PROJECT_ID   default 12325
#     COPADO_JOB_ID       default 21321
#     ZEPHYR_PROJECT_KEY  default SLB
#
#   Parameters (Copado Function inputs):
#     BUILD_ID            CRT build id to publish. If empty, the latest build for
#                         the job is used (prefer passing it from the RT step).
#     RELEASE             release label used in the default cycle name
#     CYCLE_NAME          full cycle name (overrides the default)
#     JIRA_VERSION_ID     optional Jira release/version id to link the cycle to
#
# Exit code is the publisher's: non-zero if any execution failed to post.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

: "${ZEPHYR_API_KEY:?ZEPHYR_API_KEY must be set (Copado secret)}"
: "${COPADO_PAT:?COPADO_PAT must be set (CRT personal access key)}"

# Build id: prefer the one passed from the Robotic Testing step; else newest build.
BUILD_ID="${BUILD_ID:-}"
if [ -z "$BUILD_ID" ]; then
  echo "BUILD_ID not provided — resolving the latest CRT build for the job..."
  BUILD_ID="$(python3 - <<'PY'
import automation.run_suite as rs
_st, resp = rs.request("GET", rs.BUILDS_EP.format(project=rs.PROJECT, job=rs.JOB))
lst = rs._data(resp) or []
print(lst[0].get("id") if lst else "")
PY
)"
fi
[ -n "$BUILD_ID" ] || { echo "ERROR: no CRT build id available"; exit 1; }

RELEASE="${RELEASE:-Regression}"
CYCLE_NAME="${CYCLE_NAME:-${RELEASE} Automated Regression $(date +%Y-%m-%d)}"

ARGS=(publish --build "$BUILD_ID" --cycle "$CYCLE_NAME")
[ -n "${JIRA_VERSION_ID:-}" ] && ARGS+=(--jira-version-id "$JIRA_VERSION_ID")

echo "Publishing CRT build ${BUILD_ID} -> Zephyr cycle: ${CYCLE_NAME}"
exec python3 automation/run_suite.py "${ARGS[@]}"
