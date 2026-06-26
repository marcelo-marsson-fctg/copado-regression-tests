# Conversion Dashboard

Project-specific live dashboard for the BAU regression-suite conversion. It computes
status from ground truth on every reload — nothing is stored or hand-maintained.

Signals:

- **Generated** — which workbook test cases now exist in `tests/*.robot` (scoped per file;
  duplicate ids are credited only to their first occurrence).
- **Review burden** — count of unresolved `# CONFIRM IN CRT:` flags per converted test.
- **CRT pass/fail** — parsed from the newest Robot `output.xml` if present.
- **Coverage gaps** — what's still Not started, grouped by tab and priority.

## Run

From the repo root:

```bash
python3 dashboard/dashboard.py          # then open http://localhost:8765
python3 dashboard/dashboard.py --once   # one-shot text report, no browser
```

Options: `--port N` (default 8765), `--host H`, `--repo PATH`, `--workbook PATH`.
`/api` on the running server returns the full status model as JSON.

## Dependency

Reuses the generic spreadsheet parser `extract_testcase.py` from the
`copado-regression-skills` plugin. It's discovered automatically when that repo sits beside
this one or the plugin is installed; otherwise set `NEWTEST_PARSER_DIR` to the folder
containing `extract_testcase.py`.
