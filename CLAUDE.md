# Salesforce Automated Testing — Claude Guide

## What this repo is

Copado Robotic Testing (CRT) automated test suites for Salesforce, written in **Robot Framework** using the **QForce** and **QWeb** libraries. Tests run inside Copado Robotic Testing, which executes Robot Framework scripts against Salesforce orgs.

---

## Repo structure

```
resources/
  common.resource       # Shared keywords: Setup Browser, Login, Fill MFA, Home
tests/
  sf_api.robot          # Example: JWT auth test
  <feature>.robot       # One .robot file per feature/module under test
```

**Conventions:**
- Shared, reusable keywords go in `resources/` as `.resource` files
- Each test suite is a `.robot` file under `tests/`
- Name test files after the Salesforce feature being tested (e.g. `opportunity_creation.robot`, `account_management.robot`)

---

## Robot Framework file anatomy

Every `.robot` test file follows this structure:

```robot
*** Settings ***
Library             QForce
Resource            ../resources/common.resource
Suite Setup         Setup Browser
Suite Teardown      End suite

*** Variables ***
${BROWSER}          chrome

*** Test Cases ***
Test Case Name
    [Documentation]    What this test verifies
    [Tags]    smoke    regression
    # test steps here

*** Keywords ***
# Local reusable keywords for this suite only
```

---

## Libraries

| Library | Purpose | Docs |
|---------|---------|------|
| **QForce** | Salesforce-specific keywords (JWT auth, MFA, Salesforce UI interactions) | https://help.pace.qentinel.com/qwords-reference/current/qwords/_attachments/QForce.html |
| **QWeb** | General browser automation (TypeText, ClickText, VerifyText, etc.) | https://qentinelqi.github.io/qweb/QWeb.html |
| **QVision** | Image/visual-based interactions | https://help.pace.qentinel.com/qwords-reference/current/qwords/_attachments/QVision.html |
| **BuiltIn** | Standard RF keywords (Run Keyword If, Should Be Equal, etc.) | https://robotframework.org/robotframework/latest/libraries/BuiltIn.html |

Import QForce at the top of every test file — it includes QWeb functionality.

> **ALWAYS consult [`resources/QForce_Reference.md`](resources/QForce_Reference.md) when writing or fixing test scripts.**
> It is the authoritative, offline list of QForce keywords (auth, navigation, UI interaction,
> **picklists**, checkboxes, tables, REST API, CPQ, Agentforce, MFA) with exact argument
> signatures and examples. Check it BEFORE reaching for a keyword — it prevents the most common
> mistake on this repo: using a generic QWeb keyword where a Salesforce-specific QForce one exists
> (e.g. `PickList` for Lightning picklists, not `DropDown`; `Combobox` for type-ahead fields).

---

## Common keywords (already in resources/common.resource)

| Keyword | What it does |
|---------|-------------|
| `Setup Browser` | Opens Chrome, sets line break config, 30s default timeout, disables CSS selectors |
| `End suite` | Closes all browsers |
| `Login` | Navigates to `${login_url}`, types username/password, clicks Log In, handles MFA if `${secret}` is set |
| `Fill MFA` | Gets OTP via `GetOTP` and completes the MFA dialog |
| `Home` | Navigates to the Salesforce home page, re-logs in if session expired |

---

## Variables and secrets

Variables are passed in by CRT at runtime — never hardcode credentials.

| Variable | Type | Description |
|----------|------|-------------|
| `${login_url}` | Runtime | Salesforce instance URL (e.g. `https://test.salesforce.com/`) |
| `${username}` | Runtime | Salesforce username |
| `${password}` | Secret | Salesforce password |
| `${secret}` | Secret | MFA TOTP secret (leave as `${None}` if MFA not needed) |
| `${client_id}` | Runtime | Connected App client ID (for JWT auth) |
| `${persona_username}` | Runtime | Username for JWT auth flows |
| `${server_key}` | Secret | Private key for JWT auth |

Use `TypeSecret` (not `TypeText`) for passwords, OTP codes, and any sensitive values.

---

## Authentication patterns

### Standard login (username + password + optional MFA)
The `Login` keyword in `common.resource` handles this. Just call `Login` in your test setup.

### JWT Bearer auth (headless/API tests)
```robot
OpenBrowser         about:blank    chrome
Jwt Authenticate    ${client_id}    ${persona_username}    ${server_key}    sandbox=True
Jwt Login           /lightning/page/home
```

### MFA setup — getting the TOTP secret for CRT

MFA requires a one-time setup per user to extract the TOTP secret and store it as a CRT secret variable. Do this once, then CRT handles MFA automatically at runtime via `GetOTP`.

**Steps (must be followed in order):**

1. Log in to Salesforce as the test user
2. Go to **Setup → Users → Users → [your user] → User Detail**
3. Find **App Registration: One-Time Password Authenticator** → click **Connect**
4. Salesforce sends a 6-digit code to the user's email — enter it and click **Verify**
5. A QR code page appears — **right-click the QR code image → Open Image in New Tab**
6. Back on the original tab: scan the QR code with an authenticator app, enter the generated code, click **Connect**
7. Switch to the **new tab** containing the QR code image — look at the URL, it contains the secret:
   ```
   ...?secret=YOURSECRETHERE&...
   ```
   Copy the value after `secret=` (up to the next `&`)
8. Save this value as the `${secret}` CRT secret variable for this user

**Using the secret in tests:**

The `Login` keyword in `common.resource` handles MFA automatically when `${secret}` is set:

```robot
*** Test Cases ***
Login With MFA
    GoTo                  ${login_url}
    TypeText              Username              ${username}
    TypeSecret            Password              ${password}
    ClickText             Log In
    ${mfa_code}=          GetOTP                ${username}    ${secret}    ${login_url}
    TypeSecret            Verification Code     ${mfa_code}
    ClickText             Verify
```

The `Login` keyword in `common.resource` already wraps this pattern — just ensure `${secret}` is set as a CRT variable and it runs automatically. If `${secret}` is `${None}` (default), MFA is skipped.

---

## How to convert a manual test script to a Robot Framework test

Given a manual test script like:

> 1. Log in to Salesforce
> 2. Click "Accounts" in the nav bar
> 3. Click "New"
> 4. Fill in Account Name = "Test Corp"
> 5. Click "Save"
> 6. Verify "Test Corp" appears on the account detail page

Translate each step to RF keywords:

```robot
*** Test Cases ***
Create New Account
    [Documentation]    Verify a new Account can be created with a name
    [Tags]    accounts    smoke
    Login
    ClickText           Accounts
    ClickText           New
    TypeText            Account Name    Test Corp
    ClickText           Save
    VerifyText          Test Corp
```

**Key translation rules:**
- "Click X" → `ClickText    X`
- "Type X into Y field" → `TypeText    Y    X`
- "Verify X appears" → `VerifyText    X`
- "Verify X is not present" → `VerifyNoText    X`
- "Open / go to the X app", "navigate to the X app", "launch X" → `LaunchApp    X` — opens the app via the Salesforce **App Launcher** (the waffle). This is the preferred, much simpler way to reach an app: **prefer it over** building a `GoTo    ${login_url}lightning/...` URL or clicking through the App Launcher manually. Use the exact app name (e.g. `LaunchApp    Leisure Service`, `LaunchApp    Sales`). For the home page use `LaunchApp    Home`. Optionally verify a tab after launch: `LaunchApp    Sales    Opportunities`. See `LaunchApp` in `resources/QForce_Reference.md` for `connected_app`/`index` args.
- "Navigate to a raw URL" → `GoTo    ${login_url}lightning/...` (only when there is no app to launch — e.g. a deep link or a record page; otherwise prefer `LaunchApp`)
- "Select X from a Salesforce Lightning picklist" → `PickList    field_label    X` — **NOT `DropDown`**. Lightning picklists are comboboxes, not native `<select>` elements, so `DropDown` fails with "Unable to find element for locator". `DropDown` is only for true HTML `<select>` elements (rare in Lightning). For type-ahead lookup fields use `Combobox`. See `resources/QForce_Reference.md`.
- "Verify field value" → `VerifyInputValue    field_label    expected_value` (for a saved record layout field, prefer `VerifyField    label    expected`)
- Login/setup → call `Login` keyword from common.resource

---

## Tags convention

Always tag test cases. Common tags:

| Tag | Meaning |
|-----|---------|
| `smoke` | Quick sanity checks, run on every deploy |
| `regression` | Full regression suite |
| `login` | Auth-related tests |
| `<feature>` | Feature name (e.g. `accounts`, `opportunities`, `contacts`) |

---

## Useful QWeb/QForce keywords reference

```robot
# Navigation
LaunchApp           App Name                # open an app via the App Launcher (preferred)
LaunchApp           App Name    Tab Name    # also verify a tab after launch
GoTo                url                      # raw URL nav — use only when there's no app to launch
VerifyTitle         Expected Page Title

# Text interaction
ClickText           Visible text on page
TypeText            Field label    value to type
TypeSecret          Field label    ${secret_var}
VerifyText          Expected text
VerifyNoText        Text that should not be present

# Dropdowns & selects
DropDown            Field label    Option to select

# Input fields
VerifyInputValue    Field label    expected value
ClearText           Field label

# Wait/condition
VerifyText          Some text    timeout=10s

# Checkboxes
ClickCheckbox       Label    on/off

# XPath fallback (when text-based selectors don't work)
ClickElement        xpath=//button[@data-id='submit']
```

---

## Salesforce-specific tips

- Salesforce pages are slow — the default 30s timeout in `Setup Browser` usually covers it, but add `timeout=60s` to specific keywords on heavy pages
- Lightning UI uses shadow DOM — prefer `ClickText`/`TypeText` (text-based) over CSS selectors; `SetConfig    CSSSelectors    False` is already set in `Setup Browser`
- To reach an app, use `LaunchApp    <App Name>` (App Launcher) rather than a hardcoded `GoTo` URL — it's simpler, org-portable, and survives URL changes. This is how `Login`/`Home` in `service/resources/common.resource` navigate (`LaunchApp    Home`), and how suites open their app (`LaunchApp    Leisure Service`).
- After navigating, wait for a known element before interacting: `VerifyText    Account Name`
- For list views, use `ClickText` on the row text then verify the detail page title

---

## Creating a new test file checklist

1. Open [`resources/QForce_Reference.md`](resources/QForce_Reference.md) and pick the correct QForce keyword for each step (especially picklists, comboboxes, fields, tables)
2. Create `tests/<feature_name>.robot`
3. Add `*** Settings ***` with Library QForce, Resource common.resource, Suite Setup/Teardown
4. Define test cases — one test per scenario from the manual script
5. Put any multi-step sequences used in multiple tests into `*** Keywords ***` (or into `resources/` if shared across files)
6. Tag every test case
7. Use `${login_url}`, `${username}`, `${password}` — never hardcode values

---

## GSCV API — GET /b2bv2/customerProfile

Source: `fclimited/global-scv-api` (private, `fclimited` org). Types defined in `fclimited/gscv-shared-libs` → `packages/gscv-lib-core/src/lib/types/customerProfile/`.

### Request parameters
All four are required query params:
| Param | Example |
|-------|---------|
| `countryCode` | `AU` |
| `customerContextType` | `INTERNALS` |
| `customerContextLocator` | `AU-FC` |
| `customerProfileId` | the GSCV ID from `crm_GSCV_ID__c` |

Auth: `x-api-key` header (`${qa_gscv_apikey}` CRT secret). Base URL: `${qa_gscv_endpoint}` CRT variable.

### Response shape (top-level fields)
```
customerProfileId   string
title               string  (e.g. "Mr")
firstName           string
middleName          string
lastName            string
preferredName       string
gender              string  (single letter code: "M", "F" — NOT "Male"/"Female")
dob                 string  (ISO date: "YYYY-MM-DD" — NOT MM/DD/YYYY)
alias               array
contactDetail       object  → see below
dnc                 object
passports / passport / nationalIDTravelDocuments / travelVisa
loyaltyMembership   array
linkedTravellers    array   → see below
marketingPreferences array
verifications       array
isMyAccountLinked   boolean
createdAt / updatedAt
```

### contactDetail shape
```
contactDetail.email[n].email             string
contactDetail.phoneNumber[n].countryCode string  (e.g. "61" or "+61")
contactDetail.phoneNumber[n].number      string
contactDetail.address[n].addressLine1    string
contactDetail.address[n].city            string
contactDetail.address[n].state           string  (SF BillingStateCode, e.g. "NSW")
contactDetail.address[n].postcode        string
contactDetail.address[n].country         string  (SF BillingCountryCode, e.g. "AU")
```

### linkedTravellers shape
Each entry in `linkedTravellers[]`:
```
profileId             string   (GSCV ID of the linked profile)
linkedTravellerId     string?
linkedTravellerInternalId string?
firstName             string?
lastName              string?
title                 string?
relationshipType      string   (enum — see below)
hasInverseRelationship boolean?
alias                 array?
```

`relationshipType` enum values (used verbatim in GSCV responses):
`ADMIN_ASSISTANT`, `CHILD`, `COLLEAGUE`, `EMPLOYEE`, `FRIEND`, `LEAD`, `MANAGER`, `OTHER`, `PROJECT_MANAGER`, `PARENT`, `RELATIVE`, `SIBLING`, `SIGNIFICANT_OTHER`, `SPOUSE`, `SUPERVISOR`

Note: the Salesforce UI shows "SIGNIFICANT OTHER" (with space) but GSCV stores/returns `SIGNIFICANT_OTHER` (underscore).

### POST /b2bv2/customerProfile (create)
Auth: `x-api-key` header. Query params: `countryCode`, `customerContextType`, `customerContextLocator`. Body: `CustomerProfile` object **without** `customerProfileId` (assigned by GSCV on create). Response: full `CustomerProfile` with `customerProfileId`. Expected status: `200` (verify on first run — adjust to `201` if needed).

```robot
${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    Content-Type=application/json    accept=application/json
${params}=     Create Dictionary
...    countryCode=AU
...    customerContextType=INTERNALS
...    customerContextLocator=AU-FC
${response}=    POST    ${qa_gscv_endpoint}/b2bv2/customerProfile
...    headers=${headers}    params=${params}    json=${body}    expected_status=200
${gscv_id}=    Set Variable    ${response.json()}[customerProfileId]
```

### PUT /b2bv2/customerProfile (update)
Auth: `x-api-key` header. Query params: `countryCode=AU` only. Body: full `CustomerProfile` **including** `customerProfileId`. Response: updated `CustomerProfile`. Expected status: `200`.

### Pattern for verifying linkedTravellers in tests
```robot
Verify TC759 GSCV Linked Travellers
    [Arguments]    ${record_id}    ${expected_linked_gscv_id}    ${expected_role}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${result}=    QueryRecords    SELECT crm_GSCV_ID__c FROM Account WHERE Id = '${record_id}' LIMIT 1
    ${gscv_id}=    Set Variable    ${result}[records][0][crm_GSCV_ID__c]
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json
    ${params}=     Create Dictionary
    ...    countryCode=AU
    ...    customerContextType=INTERNALS
    ...    customerContextLocator=AU-FC
    ...    customerProfileId=${gscv_id}
    ${response}=    GET    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    expected_status=200
    ${body}=    Set Variable    ${response.json()}
    ${travellers}=    Set Variable    ${body}[linkedTravellers]
    Should Not Be Empty    ${travellers}    msg=linkedTravellers array is empty in GSCV for profile ${gscv_id}
    ${found}=    Set Variable    False
    FOR    ${t}    IN    @{travellers}
        ${match}=    Run Keyword And Return Status    Should Be Equal As Strings    ${t}[profileId]    ${expected_linked_gscv_id}
        Run Keyword If    ${match}    Should Be Equal As Strings    ${t}[relationshipType]    ${expected_role}
        Run Keyword If    ${match}    Set Test Variable    ${found}    True
    END
    Should Be True    ${found}    msg=No linkedTraveller with profileId=${expected_linked_gscv_id} and role=${expected_role} found in GSCV
```

---

## Key documentation links

- **[QForce Keyword Reference (local)](resources/QForce_Reference.md) — consult this first for every test script**
- [CRT General Docs](https://docs.copado.com/articles/#!copado-robotic-testing-publication/copado-robotic-testing)
- [QForce Library](https://help.pace.qentinel.com/qwords-reference/current/qwords/_attachments/QForce.html)
- [QWeb Library](https://qentinelqi.github.io/qweb/QWeb.html)
- [Robot Framework User Guide](https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html)
- [Robot Framework BuiltIn](https://robotframework.org/robotframework/latest/libraries/BuiltIn.html)
- [XPath Cheat Sheet](https://devhints.io/xpath)
