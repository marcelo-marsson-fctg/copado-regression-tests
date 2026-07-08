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
BUILDS_EP = "/pace/v4/projects/{project}/jobs/{job}/builds"
BUILD_EP = "/pace/v4/projects/{project}/jobs/{job}/builds/{build}"

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


def cmd_trigger(_a) -> int:
    _require("BASE_URL", "PAT", "PROJECT", "JOB")
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
    state = _poll(build_id)
    out = _download_output(build_id)
    if out:
        summarize(out)
    return 1 if state in FAIL else 0


def cmd_fetch(a) -> int:
    _require("BASE_URL", "PAT", "PROJECT", "JOB")
    out = _download_output(a.build_id)
    return 0 if out and summarize(out) else 1


def cmd_parse(a) -> int:
    return 0 if summarize(Path(a.path)) else 1


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
    sub.add_parser("trigger", help="start a build, print run id")
    p_s = sub.add_parser("status", help="print build state"); p_s.add_argument("build_id")
    sub.add_parser("run", help="trigger -> poll -> fetch output.xml -> summarize")
    p_f = sub.add_parser("fetch", help="download+summarize an existing build"); p_f.add_argument("build_id")
    p_p = sub.add_parser("parse", help="summarize a local output.xml"); p_p.add_argument("path")
    args = ap.parse_args(argv)
    return {
        "discover": cmd_discover, "trigger": lambda a: (cmd_trigger(a), 0)[1],
        "status": cmd_status, "run": cmd_run, "fetch": cmd_fetch, "parse": cmd_parse,
    }[args.cmd](args)


if __name__ == "__main__":
    raise SystemExit(main())
