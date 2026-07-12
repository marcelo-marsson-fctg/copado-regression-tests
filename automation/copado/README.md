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

## Choose a scheduling model

### Option A — one scheduled job (recommended for cron / a long-running scheduler)
A single job at 01:00 runs `nightly_regression.sh`, which triggers the CRT run, waits for
it to finish, and publishes. Simplest, fully self-contained.

- **cron:** `0 1 * * *  /path/to/repo/automation/copado/nightly_regression.sh >> /var/log/crt-nightly.log 2>&1`
- **Copado scheduled Function:** only if the Function can run ~3–4h (check the container
  execution-time limit). Image with `python3`+`bash`; script `bash automation/copado/nightly_regression.sh`.

### Option B — two steps (use if your scheduler caps job duration, e.g. short Functions)
Decouple the trigger from the publish so neither runs for hours:

1. **01:00 — trigger the tests.** Use CRT's own **Schedule** on the "Service" job to run
   nightly at 01:00 (Copado Robotic Testing → the job → Schedule). No custom code.
2. **~04:30 — publish.** A short scheduled Function (or cron) runs `publish_to_zephyr.sh`,
   which finds the newest *finished* build and posts it to Zephyr. Exits cleanly if the run
   isn't done yet.

## Secrets / config (env — Copado credentials, never in git)

| Env var | Value |
|---------|-------|
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
