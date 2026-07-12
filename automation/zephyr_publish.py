#!/usr/bin/env python3
"""Publish Robot Framework (CRT) results to Zephyr Scale Cloud.

Reads a Robot `output.xml`, extracts each test's status and its `zephyr:<KEY>` tag,
creates a Zephyr Scale test cycle, and posts one execution per tagged test against
the matching test case (e.g. SLB-T99). Stdlib only.

Config (from ./.copado.env or automation/.copado.env, overridable by real env vars):
    ZEPHYR_API_KEY        Zephyr Scale API access token (Bearer)          [required]
    ZEPHYR_BASE_URL       default https://api.zephyrscale.smartbear.com/v2
    ZEPHYR_PROJECT_KEY    default SLB

Usage (standalone):
    python3 automation/zephyr_publish.py --results results/<dir>/output.xml \
        --cycle "Automated Regression <date>" [--report-url URL] [--dry-run]

Typically invoked via `run_suite.py publish` (which can also fetch the build first).
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent

# Status maps (verified against SLB: Pass / Fail / Not Executed exist).
_STATUS = {"PASS": "Pass", "FAIL": "Fail", "SKIP": "Not Executed",
           "NOT RUN": "Not Executed"}


def _load_cfg() -> dict:
    cfg: dict = {}
    for path in (Path(__file__).resolve().parent / ".copado.env", _REPO_ROOT / ".copado.env"):
        if path.is_file():
            for raw in path.read_text(encoding="utf-8").splitlines():
                line = raw.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    cfg[k.strip()] = v.strip().strip('"').strip("'")
            break
    for k in ("ZEPHYR_API_KEY", "ZEPHYR_BASE_URL", "ZEPHYR_PROJECT_KEY"):
        if os.environ.get(k):
            cfg[k] = os.environ[k]
    return cfg


CFG = _load_cfg()
ZBASE = (CFG.get("ZEPHYR_BASE_URL") or "https://api.zephyrscale.smartbear.com/v2").rstrip("/")
ZTOKEN = CFG.get("ZEPHYR_API_KEY", "")
ZPROJECT = CFG.get("ZEPHYR_PROJECT_KEY", "SLB")


def z_api(method: str, path: str, body=None):
    url = path if path.startswith("http") else f"{ZBASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Authorization": f"Bearer {ZTOKEN}", "Accept": "application/json"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")


def _elapsed_ms(status_el) -> int:
    """Robot output.xml: RF7 uses elapsed="secs"; older uses starttime/endtime."""
    if status_el is None:
        return 0
    el = status_el.get("elapsed")
    if el is not None:
        try:
            return int(float(el) * 1000)
        except ValueError:
            return 0
    s, e = status_el.get("starttime"), status_el.get("endtime")
    for fmt in ("%Y%m%d %H:%M:%S.%f",):
        try:
            return int((datetime.strptime(e, fmt) - datetime.strptime(s, fmt)).total_seconds() * 1000)
        except (ValueError, TypeError):
            pass
    return 0


def _end_iso(status_el) -> str:
    if status_el is not None:
        e = status_el.get("endtime")
        if e:
            try:
                return datetime.strptime(e, "%Y%m%d %H:%M:%S.%f").replace(
                    tzinfo=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            except ValueError:
                pass
        st = status_el.get("elapsed") and status_el.get("start")
        if st:
            return str(status_el.get("start"))[:19].replace(" ", "T") + "Z"
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_output(output_xml: Path) -> list:
    """Return [{name, status, key, message, ms, end}] for every test carrying a zephyr:<KEY> tag."""
    tree = ET.parse(output_xml)
    out = []
    for test in tree.iter("test"):
        tags_el = test.find("tags")
        tags = [t.text or "" for t in (tags_el.findall("tag") if tags_el is not None else [])]
        key = next((t.split(":", 1)[1].strip() for t in tags
                    if t.lower().startswith("zephyr:")), None)
        if not key:
            continue
        st = test.find("status")
        status = (st.get("status") if st is not None else "") or "?"
        msg = ""
        if status.upper() != "PASS":
            fails = [m.text for m in test.iter("msg")
                     if (m.get("level") or "").upper() in ("FAIL", "ERROR") and m.text]
            msg = (fails[-1] if fails else (st.text if st is not None and st.text else "")).strip()
        out.append({"name": test.get("name", ""), "status": status.upper(), "key": key,
                    "message": msg[:500], "ms": _elapsed_ms(st), "end": _end_iso(st)})
    return out


def publish(output_xml: Path, cycle_name: str, report_url: str = "",
            build_id: str = "", dry_run: bool = False, folder_id=None,
            jira_version_id=None) -> int:
    if not ZTOKEN:
        print("! ZEPHYR_API_KEY not set (add it to .copado.env or the environment)")
        return 1
    results = parse_output(output_xml)
    if not results:
        print(f"! no zephyr-tagged tests found in {output_xml}")
        return 1
    counts = {}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    print(f"parsed {len(results)} tagged tests from {output_xml.name}: "
          + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))

    if dry_run:
        for r in results:
            print(f"  {r['key']:10} {_STATUS.get(r['status'], 'Not Executed'):12} {r['name'][:70]}")
        print("(dry-run — nothing posted)")
        return 0

    # 1. create the test cycle
    desc = "CRT automated regression run."
    if build_id:
        desc += f" CRT build {build_id}."
    if report_url:
        desc += f' <a href="{report_url}">CRT report</a>.'
    cycle_body = {"projectKey": ZPROJECT, "name": cycle_name, "description": desc,
                  "statusName": "Done"}
    if folder_id:
        cycle_body["folderId"] = int(folder_id)
    if jira_version_id:  # link the cycle to a Jira release/version (id, not name)
        cycle_body["jiraProjectVersion"] = int(jira_version_id)
    st, cyc = z_api("POST", "/testcycles", cycle_body)
    if not (isinstance(cyc, dict) and cyc.get("key")):
        print(f"! failed to create test cycle (HTTP {st}): {str(cyc)[:300]}")
        return 1
    cycle_key = cyc["key"]
    print(f"created test cycle {cycle_key}  ({cycle_name})")

    # 2. one execution per tagged test
    ok = err = 0
    errors = []
    for r in results:
        comment = f'CRT: {r["name"]}.'
        if report_url:
            comment += f' <a href="{report_url}">CRT report</a>.'
        if r["message"]:
            comment += f'<br/>Failure: {r["message"]}'
        payload = {"projectKey": ZPROJECT, "testCaseKey": r["key"], "testCycleKey": cycle_key,
                   "statusName": _STATUS.get(r["status"], "Not Executed"),
                   "actualEndDate": r["end"], "executionTime": r["ms"], "comment": comment}
        st, resp = z_api("POST", "/testexecutions", payload)
        # /testexecutions returns {id, self} (no "key") on success — check the HTTP status.
        if 200 <= (st or 0) < 300 and isinstance(resp, dict) and resp.get("id"):
            ok += 1
        else:
            err += 1
            errors.append((r["key"], st, str(resp)[:160]))
        time.sleep(0.1)

    print(f"\ncycle {cycle_key}: {ok} executions posted, {err} errors")
    for k, s, m in errors[:15]:
        print(f"  ERR {k} HTTP {s}: {m}")
    return 0 if err == 0 else 1


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--results", required=True, help="path to a Robot output.xml")
    ap.add_argument("--cycle", required=True, help="Zephyr test cycle name to create")
    ap.add_argument("--report-url", default="", help="CRT report URL to attach")
    ap.add_argument("--build", default="", help="CRT build id (recorded on the cycle)")
    ap.add_argument("--jira-version-id", default="", help="Jira release/version id to link the cycle to")
    ap.add_argument("--dry-run", action="store_true", help="parse + print, post nothing")
    a = ap.parse_args(argv)
    return publish(Path(a.results), a.cycle, a.report_url, a.build, a.dry_run,
                   jira_version_id=a.jira_version_id or None)


if __name__ == "__main__":
    raise SystemExit(main())
