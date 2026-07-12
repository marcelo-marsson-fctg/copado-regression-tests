#!/usr/bin/env bash
# COPADO FUNCTION ENTRY SCRIPT (paste this into the Function's "Script" field).
#
# The Function container starts empty, so this bootstrap clones the harness repo and
# then runs the nightly regression + publish. Kept in the repo for version control; the
# Copado Function uses a copy of it inline.
#
# Required secret (Copado credential injected as env):
#   GIT_TOKEN     GitHub token with READ access to the harness repo
#   ZEPHYR_API_KEY, COPADO_PAT, COPADO_BASE_URL, COPADO_PROJECT_ID, COPADO_JOB_ID, ZEPHYR_PROJECT_KEY
# Optional:
#   REPO_SLUG     default marcelo-marsson-fctg/copado-regression-tests
#   REPO_BRANCH   default main   (must contain automation/copado/nightly_regression.sh — merge PR #1 first)
#   CYCLE_NAME, JIRA_VERSION_ID, POLL_TIMEOUT, POLL_INTERVAL  (passed through)
set -euo pipefail

: "${GIT_TOKEN:?GIT_TOKEN (repo read token) must be set}"
REPO_SLUG="${REPO_SLUG:-marcelo-marsson-fctg/copado-regression-tests}"
REPO_BRANCH="${REPO_BRANCH:-main}"
WORKDIR="${WORKDIR:-crt-regression}"

echo "Cloning ${REPO_SLUG}@${REPO_BRANCH}..."
rm -rf "$WORKDIR"
# x-access-token:<token> is the standard GitHub HTTPS auth form; git masks it in logs.
git clone --depth 1 --branch "$REPO_BRANCH" \
  "https://x-access-token:${GIT_TOKEN}@github.com/${REPO_SLUG}.git" "$WORKDIR"

cd "$WORKDIR"
exec bash automation/copado/nightly_regression.sh
