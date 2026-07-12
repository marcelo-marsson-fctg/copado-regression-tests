#!/usr/bin/env python3
"""Automated Copado Robotic Testing (CRT) suite executor.

Triggers a CRT test **job build** over the region REST API using a Personal
Access Key, polls the build to completion, downloads the Robot Framework
``output.xml`` into ``results/`` (where ``dashboard/dashboard.py`` looks), and
prints a pass/fail summary so we can iterate on a test until it is green.

Stdlib only — no pip install required.

Confirmed API model (Copado Robotic Testing, AU tenant):
    Base : https://api.au-robotic.copado.com          (US: api.robotic / EU: api.eu-robotic)
    Auth : header  X-Authorization: <personal access key>
    List jobs   : GET  /pace/v4/projects/{project}/jobs
    List builds : GET  /pace/v4/projects/{project}/jobs/{job}/builds
    Trigger     : POST /pace/v4/projects/{project}/jobs/{job}/builds   body {}
                  -> {"message":"Run id <N> started.","data":{"id":<N>,...}}
    Build detail: GET  /pace/v4/projects/{project}/jobs/{job}/builds/{build}
                  -> {"data":{"status":"running|succeeded|failed",
                              "xmlFile":{"location":"<output.xml url>"}, ...}}

CRT pulls the tests from the job's git storage (branch `main` of
github.com/marcelo-marsson-fctg/copado-service-regression == the service/ repo),
so the iterate loop is: push service/ -> `run` -> read results -> fix -> repeat.

Usage:
    python3 automation/run_suite.py discover        # list jobs for the project
    python3 automation/run_suite.py trigger         # start a build, print run id
    python3 automation/run_suite.py status <build>  # print build state
    python3 automation/run_suite.py run             # trigger -> poll -> fetch output.xml -> summarize
    python3 automation/run_suite.py fetch <build>   # download+summarize an existing build's output.xml
    python3 automation/run_suite.py parse <path>    # summarize a local output.xml

Config is read from .copado.env (gitignored). See automation/.copado.env.example.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def _find_env_file() -> Path:
    candidates = [Path(__file__).resolve().parent / ".copado.env", REPO_ROOT / ".copado.env"]
    for c in candidates:
        if c.is_file():
            return c
    return candidates[0]


ENV_FILE = _find_env_file()

_KNOWN_KEYS = [
    "COPADO_PAT", "COPADO_BASE_URL", "COPADO_PROJECT_ID", "COPADO_JOB_ID",
    "COPADO_AUTH_HEADER", "POLL_INTERVAL", "POLL_TIMEOUT",
]


def load_env(path: Path = ENV_FILE) -> dict:
    """Parse a KEY=VALUE .env file. Real env vars override file values."""
    cfg: dict = {}
    if path.is_file():
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            cfg[key.strip()] = val.strip().strip('"').strip("'")
    for key in _KNOWN_KEYS + ["COPADO_PROJECT"]:  # accept legacy COPADO_PROJECT
        if os.environ.get(key):
            cfg[key] = os.environ[key]
    return cfg


CFG = load_env()

BASE_URL = (CFG.get("COPADO_BASE_URL") or "https://api.au-robotic.copado.com").rstrip("/")
PAT = CFG.get("COPADO_PAT", "")
PROJECT = CFG.get("COPADO_PROJECT_ID") or CFG.get("COPADO_PROJECT", "")
JOB = CFG.get("COPADO_JOB_ID", "")
AUTH_HEADER = CFG.get("COPADO_AUTH_HEADER", "X-Authorization")
POLL_INTERVAL = int(CFG.get("POLL_INTERVAL", "15"))
POLL_TIMEOUT = int(CFG.get("POLL_TIMEOUT", "1800"))

JOBS_EP = "/pace/v4/projects/{project}/jobs"
JOB_EP = "/pace/v4/projects/{project}/jobs/{job}"
BUILDS_EP = "/pace/v4/projects/{project}/jobs/{job}/builds"
BUILD_EP = "/pace/v4/projects/{project}/jobs/{job}/builds/{build}"

# Stable branch the job is restored to after a --branch run.
MAIN_BRANCH = CFG.get("COPADO_MAIN_BRANCH", "main")

DONE = {"succeeded", "success", "passed", "failed", "failure", "error", "aborted",
        "cancelled", "canceled", "stopped", "timeout", "completed", "done", "finished"}
FAIL = {"failed", "failure", "error", "aborted", "cancelled", "canceled", "stopped", "timeout"}


# --------------------------------------------------------------------------- #
# HTTP                                                                         #
# --------------------------------------------------------------------------- #
def _require(*keys) -> None:
    names = {"BASE_URL": BASE_URL, "PAT": PAT, "PROJECT": PROJECT, "JOB": JOB}
    missing = [k for k in keys if not names.get(k)]
    if missing:
        sys.exit(f"Missing config: {', '.join(missing)}. Set them in {ENV_FILE} "
                 f"(copy from automation/.copado.env.example).")


def request(method: str, path: str, *, body=None, raw=False, quiet=False):
    url = path if path.startswith("http") else f"{BASE_URL}{path}"
    headers = {AUTH_HEADER: PAT, "Accept": "application/json"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            payload, status = resp.read(), resp.status
    except urllib.error.HTTPError as e:
        payload, status = e.read(), e.code
    except urllib.error.URLError as e:
        if not quiet:
            print(f"  ! {method} {url} -> connection error: {e.reason}")
        return None, None
    if raw:
        return status, payload
    try:
        return status, json.loads(payload.decode() or "null")
    except (ValueError, UnicodeDecodeError):
        return status, payload.decode(errors="replace")


def _data(resp):
    """Unwrap the common {"message":..., "data": ...} envelope."""
    return resp.get("data", resp) if isinstance(resp, dict) else resp


# --------------------------------------------------------------------------- #
# Commands                                                                     #
# --------------------------------------------------------------------------- #
def cmd_discover(_a) -> int:
    _require("BASE_URL", "PAT", "PROJECT")
    st, resp = request("GET", JOBS_EP.format(project=PROJECT))
    print(f"[{st}] jobs for project {PROJECT}:")
    for j in _data(resp) or []:
        print(f"  id={j.get('id')}  name={j.get('name')!r}  robotId={j.get('robotId')}  "
              f"branch={(j.get('storage') or {}).get('branchOrTag',{}).get('branch')}  "
              f"desc={j.get('description')!r}")
    print("\nSet COPADO_JOB_ID in .copado.env to the id you want, then `run`.")
    return 0


def _get_job() -> dict:
    st, resp = request("GET", JOB_EP.format(project=PROJECT, job=JOB))
    if st != 200:
        sys.exit(f"Could not fetch job {JOB} (HTTP {st}): {resp}")
    return _data(resp)


def _set_job_branch(branch: str) -> None:
    """Point the job's git storage at `branch` (PUT keeps everything else intact)."""
    job = _get_job()
    current = (job.get("storage") or {}).get("branchOrTag", {}).get("branch")
    if current == branch:
        return
    job["storage"]["branchOrTag"] = {"branch": branch}
    payload = {k: job[k] for k in ("name", "description", "parallelExecution", "storage",
                                   "suiteType", "robotId", "timeout", "showVideoParams") if k in job}
    st, resp = request("PUT", JOB_EP.format(project=PROJECT, job=JOB), body=payload)
    if st != 200:
        sys.exit(f"Could not switch job {JOB} to branch {branch!r} (HTTP {st}): {resp}")
    print(f"Job {JOB} now runs branch {branch!r}")


def cmd_trigger(a) -> int:
    _require("BASE_URL", "PAT", "PROJECT", "JOB")
    if getattr(a, "branch", None):
        _set_job_branch(a.branch)
    st, resp = request("POST", BUILDS_EP.format(project=PROJECT, job=JOB), body={})
    if st is None or not (200 <= st < 300):
        sys.exit(f"Trigger failed (HTTP {st}): {resp}")
    build_id = str(_data(resp).get("id", ""))
    if not build_id:
        sys.exit(f"Triggered but no run id in response: {resp}")
    print(f"Triggered build/run: {build_id}")
    return int(build_id)


def _build(build_id) -> dict:
    st, resp = request("GET", BUILD_EP.format(project=PROJECT, job=JOB, build=build_id), quiet=True)
    return _data(resp) if isinstance(resp, dict) else {}


def cmd_status(a) -> int:
    _require("BASE_URL", "PAT", "PROJECT", "JOB")
    b = _build(a.build_id)
    print(f"build {a.build_id}: status={b.get('status')} duration={b.get('duration')} "
          f"output={(b.get('xmlFile') or {}).get('location')}")
    return 0


def _download_output(build_id) -> Path | None:
    b = _build(build_id)
    loc = (b.get("xmlFile") or {}).get("location")
    if not loc:
        print(f"  ! build {build_id} has no xmlFile.location yet (status={b.get('status')})")
        return None
    st, payload = request("GET", loc, raw=True)
    if st is None or not (200 <= st < 300) or not payload:
        print(f"  ! could not download output.xml (HTTP {st}) from {loc}")
        return None
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    out_dir = REPO_ROOT / "results" / f"{stamp}-{build_id}"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "output.xml"
    out_path.write_bytes(payload)
    print(f"  saved {out_path.relative_to(REPO_ROOT)}  (report: {b.get('logReportUrl')})")
    return out_path


def _poll(build_id) -> str:
    print(f"Polling build {build_id} every {POLL_INTERVAL}s (timeout {POLL_TIMEOUT}s)...")
    deadline = time.time() + POLL_TIMEOUT
    state = ""
    while time.time() < deadline:
        time.sleep(POLL_INTERVAL)
        b = _build(build_id)
        state = (b.get("status") or "").lower()
        print(f"  [{datetime.now():%H:%M:%S}] status={state or '?'}")
        if state in DONE:
            return state
    print("! Timed out waiting for the build to finish.")
    return state


def cmd_run(a) -> int:
    build_id = cmd_trigger(a)
    state = ""
    try:
        state = _poll(build_id)
        out = _download_output(build_id)
        if out:
            summarize(out)
    finally:
        # A --branch run is a one-off: restore the job to the stable branch so the next
        # plain `run` (or a teammate's UI trigger) executes the real suite. BUT a build
        # only clones its branch when it STARTS executing — if this build is still queued
        # (e.g. the poll timed out behind another build), restoring now would make it run
        # the wrong suite. In that case leave the branch alone and say so.
        if getattr(a, "branch", None) and a.branch != MAIN_BRANCH:
            current = (_build(build_id).get("status") or "").lower()
            if current in DONE or current == "executing":
                _set_job_branch(MAIN_BRANCH)
            else:
                print(f"! build {build_id} is still {current or 'pending'} — leaving the job on "
                      f"branch {a.branch!r}. Restore later with: run_suite.py set-branch {MAIN_BRANCH}")
    return 1 if state in FAIL else 0


def cmd_fetch(a) -> int:
    _require("BASE_URL", "PAT", "PROJECT", "JOB")
    out = _download_output(a.build_id)
    return 0 if out and summarize(out) else 1


def cmd_parse(a) -> int:
    return 0 if summarize(Path(a.path)) else 1


def cmd_publish(a) -> int:
    """Publish a run's results to Zephyr Scale. Either --build <id> (download the finished
    build's output.xml + report URL from CRT) or --results <output.xml> (local file)."""
    import zephyr_publish  # sibling module, stdlib-only
    report_url, build_id = a.report_url or "", a.build or ""
    if a.build:
        _require("BASE_URL", "PAT", "PROJECT", "JOB")
        out = _download_output(a.build)
        if not out:
            print("! could not download output.xml for build", a.build)
            return 1
        if not report_url:
            report_url = (_build(a.build) or {}).get("logReportUrl", "") or ""
    elif a.results:
        out = Path(a.results)
    else:
        print("! provide --build <id> or --results <output.xml>")
        return 1
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    cycle = a.cycle or f"CRT Automated Regression {stamp}"
    return zephyr_publish.publish(out, cycle, report_url, build_id, a.dry_run,
                                  jira_version_id=getattr(a, "jira_version_id", None) or None)


def cmd_lint(a) -> int:
    """Parse .robot/.resource files locally and report syntax errors — catches typos
    before they cost a full CRT cloud round-trip. Needs `pip install robotframework`
    (parse only; QForce/QWeb keywords are not resolved)."""
    try:
        from robot.api import get_model, get_resource_model
        from robot.parsing.model.visitor import ModelVisitor
    except ImportError:
        sys.exit("robotframework is not installed locally: pip3 install --user robotframework")

    root = Path(a.path) if a.path else REPO_ROOT / "service"
    files = [root] if root.is_file() else sorted(
        list(root.rglob("*.robot")) + list(root.rglob("*.resource")))
    problems = []

    class Collector(ModelVisitor):
        def __init__(self, path):
            self.path = path

        def visit_Error(self, node):
            for err in node.errors:
                problems.append(f"{self.path}:{node.lineno}: {err}")

    for f in files:
        model = get_resource_model(str(f)) if f.suffix == ".resource" else get_model(str(f))
        Collector(f).visit(model)
    if problems:
        print("\n".join(problems))
        print(f"\n{len(problems)} problem(s) in {len(files)} file(s)")
        return 1
    print(f"OK — {len(files)} file(s) parse cleanly")
    return 0


def summarize(output_xml: Path) -> bool:
    """Print per-test pass/fail and failing keyword messages. True if all passed."""
    if not output_xml.is_file():
        print(f"! no such file: {output_xml}")
        return False
    tree = ET.parse(output_xml)
    tests = list(tree.iter("test"))
    passed = failed = 0
    print(f"\n=== Results: {output_xml} ===")
    for test in tests:
        st = test.find("status")
        status = (st.get("status") if st is not None else "") or "?"
        name = test.get("name", "")
        if status.upper() == "PASS":
            passed += 1
            print(f"  PASS  {name}")
        else:
            failed += 1
            print(f"  {status.upper():5} {name}")
            for msg in test.iter("msg"):
                if (msg.get("level") or "").upper() in ("FAIL", "ERROR"):
                    print(f"        -> {(msg.text or '').strip()[:300]}")
    print(f"\n  {passed} passed, {failed} failed/other, {len(tests)} total")
    return failed == 0 and passed > 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("discover", help="list jobs for the project")
    p_t = sub.add_parser("trigger", help="start a build, print run id")
    p_t.add_argument("--branch", help="switch the job to this git branch before triggering (NOT restored)")
    p_s = sub.add_parser("status", help="print build state"); p_s.add_argument("build_id")
    p_r = sub.add_parser("run", help="trigger -> poll -> fetch output.xml -> summarize")
    p_r.add_argument("--branch", help="run this git branch (e.g. dev for isolated in-development "
                     "suites); the job is restored to the stable branch afterwards")
    p_b = sub.add_parser("set-branch", help="point the job at a git branch and exit")
    p_b.add_argument("branch")
    p_f = sub.add_parser("fetch", help="download+summarize an existing build"); p_f.add_argument("build_id")
    p_p = sub.add_parser("parse", help="summarize a local output.xml"); p_p.add_argument("path")
    p_l = sub.add_parser("lint", help="parse .robot/.resource files locally, report syntax errors")
    p_l.add_argument("path", nargs="?", help="file or directory (default: service/)")
    p_z = sub.add_parser("publish", help="publish results to Zephyr Scale (build or local output.xml)")
    p_z.add_argument("--build", help="CRT build id to download + publish")
    p_z.add_argument("--results", help="path to a local Robot output.xml")
    p_z.add_argument("--cycle", help="Zephyr test cycle name (default: timestamped)")
    p_z.add_argument("--report-url", help="CRT report URL to attach (auto-filled from --build)")
    p_z.add_argument("--jira-version-id", help="Jira release/version id to link the cycle to")
    p_z.add_argument("--dry-run", action="store_true", help="parse + print, post nothing")
    args = ap.parse_args(argv)
    return {
        "discover": cmd_discover, "trigger": lambda a: (cmd_trigger(a), 0)[1],
        "status": cmd_status, "run": cmd_run, "fetch": cmd_fetch, "parse": cmd_parse, "lint": cmd_lint,
        "publish": cmd_publish,
        "set-branch": lambda a: (_require("BASE_URL", "PAT", "PROJECT", "JOB"),
                                 _set_job_branch(a.branch), 0)[2],
    }[args.cmd](args)


if __name__ == "__main__":
    raise SystemExit(main())
