# Copado Function — Publish CRT Results to Zephyr Scale

Runs the publish bridge (`run_suite.py publish`) as a **Copado Function** step in the
pipeline, right after the **Robotic Testing** step, so each CRT run posts a Zephyr Scale
test cycle to project **SLB**.

> Copado Function field names/UI vary slightly by Copado edition — confirm against your
> org. The values below are the intent; adjust to match your Functions setup.

## Files

| File | Role |
|------|------|
| `automation/copado/publish_to_zephyr.sh` | Function entrypoint — resolves the build id + cycle name from env and calls the publisher. |
| `automation/zephyr_publish.py` | The bridge (parse `output.xml` → create cycle → post executions). Stdlib only. |
| `automation/run_suite.py` | Harness; `publish` subcommand. |
| `automation/zephyr_slb_mapping.csv` | `TC → SLB-T<n>` reference mapping. |

## Function definition

| Field | Value |
|-------|-------|
| **API Name** | `Publish_CRT_Results_To_Zephyr` |
| **Type** | Custom |
| **Image** | A container with `python3` (3.8+) and `bash` — e.g. `python:3.12-slim`. No `pip install` needed (stdlib only). |
| **Script** | `bash automation/copado/publish_to_zephyr.sh` |
| **Working dir** | The checked-out `copado-regression-tests` repo (so `run_suite.py` / `zephyr_publish.py` are on disk). If your Function doesn't auto-checkout, add a `git clone` of the harness repo at the top of the script. |

## Parameters (Function inputs → env vars)

| Parameter | Example / source | Notes |
|-----------|------------------|-------|
| `BUILD_ID` | output of the Robotic Testing step (the CRT build/run id) | If omitted, the script uses the newest build for the job — pass it explicitly when you can. |
| `RELEASE` | pipeline release name | Used in the default cycle name. |
| `CYCLE_NAME` | *(optional)* | Overrides the default `"<RELEASE> Automated Regression <date>"`. |
| `JIRA_VERSION_ID` | *(optional)* Jira version id | Links the cycle to a Jira release. |

## Secrets / credentials (injected as env)

Store these as Copado credentials/secret env vars on the Function (never in git):

| Env var | Value |
|---------|-------|
| `ZEPHYR_API_KEY` | Zephyr Scale service-account token |
| `COPADO_PAT` | CRT personal access key (`X-Authorization`) |
| `COPADO_BASE_URL` | `https://api.au-robotic.copado.com` |
| `COPADO_PROJECT_ID` | `12325` |
| `COPADO_JOB_ID` | `21321` |
| `ZEPHYR_PROJECT_KEY` | `SLB` |

## Pipeline wiring

1. Existing **Robotic Testing** step runs the CRT "Service" job (TC_102–189).
2. Add a **Function** step immediately after it that invokes `Publish_CRT_Results_To_Zephyr`.
3. Wire the Robotic Testing step's build/run id into the Function's `BUILD_ID` parameter.
4. On completion, a new Zephyr cycle (e.g. `SLB-R##`) appears in project SLB with one
   execution per tagged test (Pass / Fail / Not Executed).

## Behaviour notes

- **One cycle per run** — each invocation creates a *new* test cycle. For one-cycle-per-release,
  pass a fixed `CYCLE_NAME`; re-running then adds executions to a same-named (new) cycle — decide
  the convention with QA.
- **Idempotency** — the Function does not delete/overwrite; re-running publishes again.
- **Exit code** — non-zero if any execution failed to POST (surfaces as a failed Function step);
  test *failures* themselves are recorded as `Fail` executions, not a step error.

## Test locally (no Copado)

```bash
# uses ./.copado.env for ZEPHYR_API_KEY + COPADO_* config
BUILD_ID=<crt build id> RELEASE="RW6" bash automation/copado/publish_to_zephyr.sh
# or directly:
python3 automation/run_suite.py publish --build <id> --cycle "RW6 Automated Regression" --dry-run
```
