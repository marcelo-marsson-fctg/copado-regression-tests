# Salesforce Automated Testing

Automated regression test suites for the Flight Centre Travel Group Leisure Salesforce platform, built with [Copado Robotic Testing (CRT)](https://docs.copado.com/articles/#!copado-robotic-testing-publication/copado-robotic-testing) and [Robot Framework](https://robotframework.org/).

---

## Structure

```
resources/
  common.resource       # Shared keywords: Setup Browser, Login, MFA, Home
tests/
  Sales.robot           # Sales module regression tests
  sf_api.robot          # JWT auth smoke test
```

New test suites go in `tests/` as `<Module>.robot`. Shared keywords used across suites belong in `resources/`.

---

## Libraries

| Library | Purpose |
|---------|---------|
| [QForce](https://help.pace.qentinel.com/qwords-reference/current/qwords/_attachments/QForce.html) | Salesforce-specific keywords (JWT auth, MFA, OTP) |
| [QWeb](https://qentinelqi.github.io/qweb/QWeb.html) | Browser automation (ClickText, TypeText, VerifyText, etc.) |

Import `QForce` at the top of every test file — it includes QWeb functionality.

---

## Running tests

Tests are executed via Copado Robotic Testing. Each suite is attached to a CRT job that supplies runtime variables (credentials, org URL, persona usernames).

### Required CRT variables

| Variable | Description |
|----------|-------------|
| `${login_url}` | Salesforce instance URL |
| `${username}` | Salesforce username |
| `${password}` | Salesforce password (secret) |
| `${secret}` | TOTP secret for MFA — omit or set to `${None}` if not required |
| `${client_id}` | Connected App client ID for JWT auth |
| `${server_key}` | Private key for JWT auth (secret) |
| `${persona_sales_team_member}` | Username for the Sales Team Member persona |

### Authentication

Tests use **JWT Bearer auth** — no username/password form login required. Each test case opens a fresh browser session via `OpenBrowser`, authenticates with `Jwt Authenticate`, and navigates to the target page with `Jwt Login`.

For orgs that require MFA on standard login, the `Login` keyword in `common.resource` handles TOTP via `GetOTP`.

---

## Test suites

### Sales.robot
Regression tests for the Sales module covering the full customer lifecycle in the Leisure Sales app.

| Test Case | Description | Priority |
|-----------|-------------|----------|
| TC_001 | Customer Profile creation via Accounts list view — form layout and field mapping validation | P1 |

Source: *Sales Leisure BAU Regression Test Suite_v5.0_Draft.xlsx* → sheet `1. Sales`

---

## Adding a new test

1. Create `tests/<Module>.robot`
2. Set `Suite Setup    Setup Browser` and `Suite Teardown    End suite`
3. Add a `[Setup]` on each test case to handle JWT auth and app navigation
4. Tag every test: module name, priority (`p1`/`p2`/`p3`), and suite type (`smoke`/`regression`)
5. Put any multi-test keywords into `resources/` rather than the suite file

See `CLAUDE.md` for the full keyword reference, translation guide from manual test scripts, and Salesforce-specific tips.

---

## Resources

- [CRT Documentation](https://docs.copado.com/articles/#!copado-robotic-testing-publication/copado-robotic-testing)
- [QForce Keyword Reference](https://help.pace.qentinel.com/qwords-reference/current/qwords/_attachments/QForce.html)
- [QWeb Keyword Reference](https://qentinelqi.github.io/qweb/QWeb.html)
- [Robot Framework User Guide](https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html)
- [XPath Cheat Sheet](https://devhints.io/xpath)
