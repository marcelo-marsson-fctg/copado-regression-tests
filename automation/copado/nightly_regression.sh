#!/usr/bin/env bash
# Nightly regression: trigger the CRT "Service" job, wait for it to finish, and
# publish the results to Zephyr Scale. Single self-contained entrypoint for a
# scheduled run (cron, a Copado scheduled Function, or any scheduler) — NOT a
# quality gate. Intended to fire at 01:00; the suite takes ~3h, so it finishes ~04:00.
#
# Secrets / config (env — Copado credentials or the local .copado.env):
#   ZEPHYR_API_KEY, COPADO_PAT              [required]
#   COPADO_BASE_URL / COPADO_PROJECT_ID / COPADO_JOB_ID / ZEPHYR_PROJECT_KEY
# Optional inputs:
#   CYCLE_NAME        cycle name (default: "Nightly Regression <date>")
#   JIRA_VERSION_ID   Jira version id to link the cycle to
#   POLL_TIMEOUT      seconds to wait for the build (default 21600 = 6h)
#   POLL_INTERVAL     poll cadence seconds (default 120)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

: "${ZEPHYR_API_KEY:?ZEPHYR_API_KEY must be set}"
: "${COPADO_PAT:?COPADO_PAT must be set}"

# The full suite runs ~3h; wait generously so the run completes in one shot.
export POLL_TIMEOUT="${POLL_TIMEOUT:-21600}"   # 6h
export POLL_INTERVAL="${POLL_INTERVAL:-120}"

CYCLE_NAME="${CYCLE_NAME:-Nightly Regression $(date +%Y-%m-%d)}"

ARGS=(run --publish --cycle "$CYCLE_NAME")
[ -n "${JIRA_VERSION_ID:-}" ] && ARGS+=(--jira-version-id "$JIRA_VERSION_ID")

echo "$(date '+%Y-%m-%d %H:%M:%S') nightly regression -> cycle: ${CYCLE_NAME}"
exec python3 automation/run_suite.py "${ARGS[@]}"
