# Automated CRT execution

`run_suite.py` triggers a Copado Robotic Testing (CRT) suite over the REST API,
polls it to completion, downloads the Robot Framework `output.xml` into
`results/`, and prints a pass/fail summary. Stdlib only — no `pip install`.

## Setup

1. Copy the template and fill in your values (the real file is gitignored):
   ```bash
   cp automation/.copado.env.example automation/.copado.env
   # edit automation/.copado.env — set COPADO_PAT and COPADO_BASE_URL at minimum
   ```
2. Set `COPADO_ORG_ID` (CRT profile icon → Organization), then discover the rest:
   ```bash
   python3 automation/run_suite.py discover
   ```
   `discover` lists your **robots** and their **jobs**. Set `COPADO_ROBOT_ID` and
   `COPADO_JOB_ID` from the ids it prints. If a path 404s with a different shape,
   correct the matching `*_PATH` in `.copado.env`.

Auth is the personal access key sent as `X-Authorization` to the region `api.*`
host (US `api.robotic.copado.com`, EU `api.eu-robotic.copado.com`,
AU `api.au-robotic.copado.com`). The trigger is
`POST /v1/organizations/{org}/robots/{robot}/jobs/{job}/builds`.

## Run a suite

```bash
python3 automation/run_suite.py run          # trigger -> poll -> fetch output.xml -> summarize
python3 automation/run_suite.py trigger      # just start a run, print its id
python3 automation/run_suite.py status <id>  # check a run's state
python3 automation/run_suite.py parse results/<dir>/output.xml   # re-summarize a saved run
```

Downloaded results land in `results/<timestamp>-<runid>/output.xml`, which the
conversion dashboard already scans:

```bash
python3 dashboard/dashboard.py --once   # or open the web view
```

## Iterate loop

1. Edit the test (`service/tests/Case.robot`, `service/resources/common.resource`).
2. Get the edit into CRT (CRT runs its own copy — via QEditor sync or a git push of
   the `service/` repo; confirm which during `discover`).
3. `python3 automation/run_suite.py run`.
4. Read the failing keyword/message in the summary, fix, repeat until green.

> Endpoints are best-guess defaults confirmed live via `discover` — the Copado docs
> are JS-rendered and could not be verified offline. All paths are overridable in
> `.copado.env`.
