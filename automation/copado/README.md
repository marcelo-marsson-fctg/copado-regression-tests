# Nightly CRT regression → Zephyr Scale

Runs the CRT regression suite (TC_102–189) **every night at 01:00** and publishes the
results to **Zephyr Scale** (Jira project **SLB**). This is a **scheduled** job — not a
deployment quality gate. The full suite takes ~3h, so a 01:00 start finishes ~04:00.

> Copado field/UI names vary by edition — confirm against your org.

## Files

| File | Role |
|------|------|
| `nightly_regression.sh` | Single-shot entrypoint: trigger the CRT job → wait (up to 6h) → publish. |
| `publish_to_zephyr.sh` | Publish-only: posts the newest **finished** build's results (for the decoupled model). |
| `../zephyr_publish.py` | The bridge (parse `output.xml` → create cycle → post executions). |
| `../run_suite.py` | Harness (`run --publish`, `publish`, `trigger`, …). |
| `../zephyr_slb_mapping.csv` | `TC → SLB-T<n>` reference. |

## Scheduling — Copado scheduled Function (chosen)

A single **Copado Function** runs on a **nightly 01:00 schedule**. Copado Functions have no
execution-time limit here, so one Function triggers the CRT run, waits ~3h, and publishes —
self-contained. The Function container starts empty, so its script **clones this repo first**,
then runs the nightly logic.

| Function field | Value |
|----------------|-------|
| **API Name** | `Nightly_CRT_Regression_To_Zephyr` |
| **Type / Image** | Custom · container with `python3` + `bash` + `git` (e.g. `python:3.12-slim` + git) |
| **Script** | the contents of **`automation/copado/copado_function_script.sh`** — it `git clone`s the repo (branch `main`, using `GIT_TOKEN`) and runs `automation/copado/nightly_regression.sh`. |
| **Schedule** | nightly `0 1 * * *` — via a Copado scheduled Automation / scheduled job that invokes this Function (confirm the exact scheduling UI in your edition) |

- **No `.copado.env` in the container** — all config is read from the injected env vars (secrets below).
- `REPO_BRANCH` defaults to `main`, which must contain the scripts → **merge PR #1 first** (or set `REPO_BRANCH=feat/zephyr-integration` to test before merge).
- Optional inputs: `CYCLE_NAME`, `JIRA_VERSION_ID`, `POLL_TIMEOUT` (default 6h), `REPO_SLUG`, `REPO_BRANCH`.

### Fallback (only if you ever need it)
Decoupled: use CRT's own **Schedule** on the "Service" job to fire the tests at 01:00, then a
separate short job at ~04:30 runs `publish_to_zephyr.sh` (publishes the newest *finished* build).

## Secrets / config (env — Copado credentials, never in git)

| Env var | Value |
|---------|-------|
| `GIT_TOKEN` | GitHub token with read access to the harness repo (for the clone) |
| `ZEPHYR_API_KEY` | Zephyr Scale service-account token |
| `COPADO_PAT` | CRT personal access key (`X-Authorization`) |
| `COPADO_BASE_URL` | `https://api.au-robotic.copado.com` |
| `COPADO_PROJECT_ID` | `12325` |
| `COPADO_JOB_ID` | `21321` |
| `ZEPHYR_PROJECT_KEY` | `SLB` |

Optional inputs: `CYCLE_NAME` (default `"Nightly Regression <date>"`), `JIRA_VERSION_ID`,
`POLL_TIMEOUT` (default 21600s / 6h), `POLL_INTERVAL` (default 120s).

## Behaviour notes

- **One cycle per night** — each run creates a new Zephyr cycle (`SLB-R##`). Cycle name
  defaults to `Nightly Regression <date>`.
- **Records all results** — publishes Pass/Fail/Not Executed regardless of overall outcome;
  a failing test is a `Fail` execution, not a job error.
- **Idempotent-ish** — re-running publishes again (new executions); it never deletes.

## Test locally (no scheduler)

```bash
# full nightly path (long-running): trigger + wait + publish
bash automation/copado/nightly_regression.sh

# publish-only, newest finished build, preview:
python3 automation/run_suite.py publish --build <id> --cycle "Nightly Regression test" --dry-run
```
