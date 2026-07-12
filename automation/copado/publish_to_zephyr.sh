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
#   Parameters:
#     BUILD_ID            CRT build id to publish. If empty, the newest FINISHED
#                         build for the job is used.
#     CYCLE_NAME          cycle name (default: "Nightly Regression <date>")
#     JIRA_VERSION_ID     optional Jira release/version id to link the cycle to
#
# Exit code is the publisher's: non-zero if any execution failed to post.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

: "${ZEPHYR_API_KEY:?ZEPHYR_API_KEY must be set (Copado secret)}"
: "${COPADO_PAT:?COPADO_PAT must be set (CRT personal access key)}"

# Build id: prefer the one passed in; else the newest *finished* build for the job.
# (Use this decoupled publish when the run is triggered separately — e.g. a CRT native
#  schedule fires the suite at 01:00 and this publishes a few hours later once it's done.)
BUILD_ID="${BUILD_ID:-}"
if [ -z "$BUILD_ID" ]; then
  echo "BUILD_ID not provided — resolving the newest finished CRT build for the job..."
  BUILD_ID="$(python3 - <<'PY'
import automation.run_suite as rs
_st, resp = rs.request("GET", rs.BUILDS_EP.format(project=rs.PROJECT, job=rs.JOB))
lst = rs._data(resp) or []
b = lst[0] if lst else {}
status = (b.get("status") or "").lower()
# only publish a finished build; if the newest is still executing, print nothing
print(b.get("id") if status and status not in ("executing", "queued", "pending", "") else "")
PY
)"
fi
[ -n "$BUILD_ID" ] || { echo "ERROR: no finished CRT build to publish (newest may still be running)"; exit 1; }

CYCLE_NAME="${CYCLE_NAME:-Nightly Regression $(date +%Y-%m-%d)}"

ARGS=(publish --build "$BUILD_ID" --cycle "$CYCLE_NAME")
[ -n "${JIRA_VERSION_ID:-}" ] && ARGS+=(--jira-version-id "$JIRA_VERSION_ID")

echo "Publishing CRT build ${BUILD_ID} -> Zephyr cycle: ${CYCLE_NAME}"
exec python3 automation/run_suite.py "${ARGS[@]}"
