# QForce Keyword Reference

**Library version:** 2025.47 | **Scope:** GLOBAL

QForce is a Robot Framework library for Salesforce. It includes all QWeb keywords — import QForce only, not QWeb separately.

---

## Table of Contents

- [Authentication](#authentication)
- [Navigation](#navigation)
- [UI Interaction](#ui-interaction)
- [Records (UI)](#records-ui)
- [Pick Lists](#pick-lists)
- [Checkboxes](#checkboxes)
- [Tables (CPQ / SF Standard)](#tables-cpq--sf-standard)
- [REST API — Records & SOQL](#rest-api--records--soql)
- [REST API — CPQ](#rest-api--cpq)
- [REST API — Agentforce](#rest-api--agentforce)
- [Utilities & MFA](#utilities--mfa)

---

## Authentication

### JWT Authenticate
`Tags: Authentication, JWT, REST_API`

Authenticates via JWT Bearer Token flow. Preferred method for automation.

```robot
JWTAuthenticate    ${client_id}    myusername@test.com    ${private_key}
JWTAuthenticate    ${client_id}    myusername@test.com    ${private_key}    sandbox=True
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `client_id` | str | — | Consumer key of External Client App |
| `username` | str | — | Salesforce username |
| `private_key` | str | — | RSA private key in PEM format |
| `sandbox` | bool | False | Use test.salesforce.com if True |
| `custom_url` | str | None | Custom instance URL (overrides sandbox flag) |
| `timeout` | str\|int | None | API call timeout in seconds (default 10) |

**Returns:** access token (also set automatically for subsequent QForce calls)

---

### JWT Login
`Tags: JWT, Login`

Opens a browser UI session using a JWT token (bypasses login screen). Browser must be open and `JWT Authenticate` must have been called first.

```robot
OpenBrowser       about:blank    chrome
JWTAuthenticate   ${client_id}   ${private_key}   myusername@test.com
JWTLogin          /lightning/setup/SetupOneHome/home
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `ret_url` | str | None | URL to redirect to after login |

---

### Client Authenticate
`Tags: Authentication, REST_API`

Authenticates via OAuth 2.0 Client Credentials flow. Preferred for API-only automation.

```robot
Client Authenticate    ${my_domain}    ${client_id}    ${client_secret}
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `domain` | str | — | e.g. `https://mycompany.my.salesforce.com` |
| `client_id` | str | — | Consumer key |
| `client_secret` | str | — | Consumer secret |
| `timeout` | str\|int | None | Default 10s |

**Returns:** access token

---

### Authenticate *(DEPRECATED)*
`Tags: Authentication, REST_API`

Username-password OAuth flow. Use `Client Authenticate` or `JWT Authenticate` instead.

```robot
Authenticate    ${client_id}    ${client_secret}    myuser@test.com    ${password}
Authenticate    ${client_id}    ${client_secret}    myuser@test.com    ${password}    sandbox=True
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `client_id` | str | — | Consumer key |
| `client_secret` | str | — | Consumer secret |
| `username` | str | — | Salesforce username |
| `password` | str | — | Salesforce password |
| `sandbox` | bool | False | Use test.salesforce.com if True |
| `custom_url` | str | None | Custom instance URL |
| `timeout` | str\|int | None | Default 10s |

---

### Revoke *(DEPRECATED)*
`Tags: REST_API`

Revokes authentication token. Not needed when using `Client Authenticate`.

```robot
Revoke
```

---

## Navigation

### Launch App
`Tags: Navigation`

Launches an app via the Salesforce App Launcher.

```robot
LaunchApp    Sales
LaunchApp    Sales    Opportunities          # verify tab after launch
LaunchApp    Gmail    connected_app=True     # connected app (skips close/tab checks)
LaunchApp    E-Bikes  index=2               # second instance of duplicate name
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `app_name` | str | — | Exact app name |
| `tab` | str | None | Tab text to verify after launch |
| `connected_app` | bool | False | Skip launcher-close and tab checks |
| `index` | int | 1 | Which duplicate to select |

---

### Global Search
`Tags: Navigation`

Performs Lightning global search and opens results page.

```robot
GlobalSearch    ${login_url}    John Doe
GlobalSearch    ${login_url}    John Doe    Contact
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `instance_url` | str | — | Salesforce base URL |
| `search_term` | str | — | Text to search for |
| `record_type` | str | `""` | Filter by object type (e.g. `Contact`) |
| `timeout` | str | 0 | Wait for results page |

---

### Go To Record
`Tags: Navigation, Records`

Navigates to a Lightning record by ID.

```robot
Go To Record    001UD000002XlBuYAK
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `record_id` | str | — | 18-char Salesforce record ID |
| `url` | str | None | Base URL (falls back to `${login_url}`) |

---

### Verify Page Header
`Tags: Navigation`

Verifies the current page header/tab name.

```robot
VerifyPageHeader    Opportunities
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `tab_name` | str | — | Expected header text |
| `timeout` | str | 0 | Wait time |

---

### Scroll List
`Tags: Navigation`

Scrolls a Salesforce list view using keyboard keys.

```robot
ScrollList                             # page down (default)
ScrollList    direction=page_up
ScrollList    uiScroller    right
ScrollList    direction=top
Repeat Keyword    3 times    ScrollList    direction=down
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `scrollable` | str | None | Attribute value or xpath of scrollable element |
| `direction` | str | `page_down` | `down/up/left/right/top/bottom/page_down/page_up` |
| `tag` | str | `div` | Tag of scrollable element |
| `timeout` | str | 0 | Wait time |

---

### Use Modal
`Tags: Modal, Navigation`

Limits text searches to within an open modal dialog.

```robot
ClickText    New
UseModal     On
# ... interact with modal ...
UseModal     Off

UseModal     On    //div[@class='slds-modal__container']    # custom modal xpath
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `status` | str | `on` | `on` or `off` |
| `modal_xpath` | str | `//div[contains(@class, 'modal-container')]` | Root xpath of modal |

---

## UI Interaction

### Click Text
`Tags: Text, Verification`

Clicks visible text on the page.

```robot
ClickText    Canis
ClickText    Canis    3             # third instance
ClickText    Canis    Dog           # instance near "Dog"
ClickText    Canis    1    20s      # first instance, 20s timeout
ClickText    Canis    recognition_mode=vision   # computer vision
ClickText    Canis    parent=span
ClickText    Canis    child=a
ClickText    Canis    js=true
ClickText    Canis    doubleclick=True
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `text` | str | — | Text to click |
| `anchor` | str | 1 | Nearby text or index |
| `timeout` | str\|int | 0 | Wait time |
| `parent` | str | None | Tag name of clickable parent |
| `child` | str | None | Tag name of clickable child |
| `js` | bool | None | Use JavaScript click |
| `recognition_mode` | str | `web` | `web` or `vision` |

---

### Verify Text
`Tags: Text, Verification`

Verifies text appears on screen.

```robot
VerifyText    Canis
VerifyText    Canis    20               # 20s timeout
VerifyText    Canis    recognition_mode=vision
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `text` | str | — | Text to verify |
| `timeout` | str\|int | 0 | Wait time |
| `anchor` | str\|int | 1 | Nearby text or index |
| `recognition_mode` | str | `web` | `web` or `vision` |

---

### Combo Box
`Tags: Combobox, Interaction`

Searches and selects a value from a Salesforce combobox (type-ahead).

```robot
Combobox    Search Accounts...    Test Account
Combobox    *Account Name         Test Account    index=3
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `locator` | str | — | Combobox placeholder or field label |
| `value` | str | — | Full value to select (exact match only) |
| `timeout` | str\|int | 0 | Wait time |
| `index` | int | 1 | Which duplicate result to select |
| `selection_delay` | int | 1 | Seconds to wait after typing before selecting |
| `all_results` | bool | False | Click "Show all results for..." dialog |

---

### Click Tree
`Tags: Interaction, Tree`

Expands or collapses a parent node in a Lightning Tree component.

```robot
ClickTree    Western Sales Director          # expand
ClickTree    Western Sales Director    False # collapse
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `label` | str | — | Label of parent tree node |
| `expanded` | bool | True | True = expand, False = collapse |
| `index` | int | 1 | Which duplicate node |
| `timeout` | str | 0 | Wait time |

---

## Records (UI)

### Get Field Value
`Tags: Getters, Records`

Returns a field value from a Lightning/Aura record layout.

```robot
${value}=    GetFieldValue    Phone
${value}=    GetFieldValue    Quote Number    tag=a
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `label` | str | — | Field label |
| `index` | int | 1 | Which duplicate label |
| `tag` | str | `span` | HTML tag (`a` for link fields) |
| `timeout` | str\|int | 0 | Wait time |

---

### Verify Field
`Tags: Records, Verification`

Verifies a field value in a Lightning/Aura record layout.

```robot
VerifyField    Phone          12345
VerifyField    Phone          123       partial_match=True
VerifyField    Account Name   Customer X
VerifyField    Type           ${EMPTY}
VerifyField    Lead Owner     John Doe  tag=a
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `label` | str | — | Field label |
| `expected` | str | — | Expected value |
| `index` | int | 1 | Which duplicate label |
| `partial_match` | bool | False | Allow partial match |
| `tag` | str | `span` | HTML tag (`a` for link fields) |
| `timeout` | str\|int | 0 | Wait time |

---

### Click Field Value
`Tags: Interaction, Records`

Clicks a value (e.g. a link) in a Lightning/Aura record layout field.

```robot
ClickFieldValue    Phone
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `label` | str | — | Field label |
| `index` | int | 1 | Which duplicate label |
| `tag` | str | `a` | HTML tag to click |
| `timeout` | str\|int | 0 | Wait time |

---

### Get Record ID From URL
`Tags: Getters, Records`

Gets the Lightning record ID from the current URL. Must be on a record page.

```robot
${id}=    Get Record ID From Url
```

**Returns:** record ID string (e.g. `5005E00000BMpypQAD`)

---

## Pick Lists

### Pick List
`Tags: Interaction, Pick List`

Selects a value from a Salesforce Lightning or Aura picklist by label.

```robot
PickList    Salutation    Mr.
PickList    \*Status      Open    partial_match=False
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `label` | str | — | Picklist label |
| `value` | str | — | Value to select |
| `index` | int | 1 | Which duplicate picklist |
| `timeout` | str\|int | 0 | Wait time |
| `partial_match` | bool | — | Config default; set False for exact |

> **Note:** Escape `*` in mandatory field labels with `\*`. Use `PickList` (not `DropDown`) for Lightning picklists — they are comboboxes, not `<select>` elements.

---

### Multi Pick List
`Tags: Interaction, Pick List`

Selects or unselects a value in a Lightning multi-select picklist.

```robot
MultiPicklist    Hide Tabs    Auto Resolved Conflicts
MultiPicklist    Hide Tabs    Auto Resolved Conflicts    action=Move to Available
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `label` | str | — | Picklist label |
| `value` | str | — | Value to move |
| `action` | str | None | Button text/tooltip. Default: "Move to Chosen". Use "Move to Available" to unselect |
| `timeout` | str\|int | 0 | Wait time |

---

### Get Pick List
`Tags: Getters, Pick List`

Returns all options or the selected option from a picklist.

```robot
${options}=   GetPicklist    Salutation
# Returns: ['--None--', 'Mr.', 'Ms.', 'Mrs.', 'Dr.', 'Prof.']

${selected}=  GetPicklist    Salutation    selected=True
# Returns: 'Mr.'
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `label` | str | — | Picklist label |
| `index` | int | 1 | Which duplicate picklist |
| `selected` | bool | False | True = return selected value only |
| `timeout` | str\|int | 0 | Wait time |

---

### Get Pick List Count
`Tags: Getters, Pick List`

Returns the number of options in a picklist.

```robot
${count}=    GetPickListCount    Salutation
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `label` | str | — | Picklist label |
| `index` | int | 1 | Which duplicate picklist |
| `timeout` | str\|int | 0 | Wait time |

---

### Verify Pick List
`Tags: Pick List, Verification`

Verifies that one or more option values exist in a picklist.

```robot
VerifyPicklist    Salutation    Dr.
VerifyPicklist    Salutation    Mr.    Ms.    Dr.
VerifyPicklist    Salutation    Dr.    selected=True
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `label` | str | — | Picklist label |
| `*args` | str | — | One or more option values to verify |
| `index` | int | 1 | Which duplicate picklist |
| `selected` | bool | False | Also verify the value is currently selected |
| `timeout` | str\|int | 0 | Wait time |

---

## Checkboxes

### Click Checkbox
`Tags: Checkbox, Interaction`

Checks or unchecks a Salesforce checkbox.

```robot
ClickCheckbox    I am not a robot    on
ClickCheckbox    I am not a robot    off
ClickCheckbox    r1c1                on          # table cell (use Use Table first)
ClickCheckbox    r?Robot/c-1         on    Test  # row with "Robot" and "Test", last cell
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `locator` | str | — | Label text or `xpath=...` |
| `value` | str | — | `on` or `off` |
| `anchor` | str | 1 | Nearby text or index |
| `timeout` | int\|float\|str | 0 | Wait time |
| `index` | int | 1 | Which checkbox if multiple |

---

## Tables (CPQ / SF Standard)

These keywords work with custom CPQ/Revenue Cloud tables (e.g. Quotes → Edit Lines).

### Click Table Cell
`Tags: CPQ/Revenue Cloud, Interaction, SF Standard Table`

Clicks a cell in a CPQ/Revenue Cloud table.

```robot
ClickTableCell    Quantity           3
ClickTableCell    List Unit Price    5    double=True
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `column` | str | — | Column header |
| `row` | str | — | Row number |
| `double` | str | False | True for double-click |
| `timeout` | str\|int | 0 | Wait time |

---

### Get Table Cell
`Tags: CPQ/Revenue Cloud, Getters, SF Standard Table`

Gets a value from a CPQ/Revenue Cloud table cell.

```robot
${value}=    GetTableCell    Quantity           3
${value}=    GetTableCell    List Unit Price    5
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `column` | str | — | Column header |
| `row` | str | — | Row number |
| `timeout` | str\|int | 0 | Wait time |

---

### Type Table
`Tags: CPQ/Revenue Cloud, Input, Interaction, SF Standard Table`

Types a value into a CPQ/Revenue Cloud table cell.

```robot
TypeTable    Quantity           3    2.00
TypeTable    List Unit Price    5    9322
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `column` | str | — | Column header |
| `row` | str | — | Row number |
| `text` | str | — | Value to type |
| `timeout` | str\|int | 0 | Wait time |

---

### Verify Table Cell
`Tags: CPQ/Revenue Cloud, SF Standard Table, Verification`

Verifies a value in a CPQ/Revenue Cloud table cell.

```robot
VerifyTableCell    Quantity           3    2.00
VerifyTableCell    List Unit Price    5    7 632    partial_match=True
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `column` | str | — | Column header |
| `row` | str | — | Row number |
| `expected` | str | — | Expected value |
| `partial_match` | bool | False | Allow partial match |
| `timeout` | str\|int | 0 | Wait time |

---

## REST API — Records & SOQL

> All REST API keywords require authentication first (`JWT Authenticate` or `Client Authenticate`).

### Create Record
`Tags: Interaction, REST_API`

Creates a new Salesforce record.

```robot
${contact}=    Create Record    Contact    FirstName=Jane    LastName=Doe
${account}=    Create Record    Account    Name=KindCorp    BillingPostalCode=12345

# With duplicate rule override
${account2}=   Create Record    Account    Name=KindCorp    additional_headers={"Sforce-Duplicate-Rule-Header": "allowSave=true"}
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `sobject` | str | — | Salesforce object type (e.g. `Account`) |
| `additional_headers` | str\|dict | None | Extra request headers |
| `timeout` | str\|int | None | Default 10s |
| `**data` | str | — | Field=Value pairs |

**Returns:** record ID string

---

### Get Record
`Tags: Getters, REST_API`

Retrieves a single record by ID.

```robot
${account}=    Get Record    Account    0015E00001TyR6mQAF
Should Be Equal As Strings    ${account}[Name]    Corporation
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `sobject` | str | — | Salesforce object type |
| `oid` | str | — | Record ID |
| `timeout` | str\|int | None | Default 10s |

**Returns:** dict of field/value pairs

---

### Update Record
`Tags: Interaction, REST_API`

Updates fields on an existing record.

```robot
Update Record    Contact    ${contact}    FirstName=Jamie    Email=jamie.doe@fake.com
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `sobject` | str | — | Salesforce object type |
| `oid` | str | — | Record ID |
| `timeout` | str\|int | None | Default 10s |
| `**data` | str | — | Field=Value pairs to update |

---

### Delete Record
`Tags: Interaction, REST_API`

Deletes a record.

```robot
Delete Record    Contact    ${contact}
Delete Record    Account    0015E000024YyV0QAK
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `sobject` | str | — | Salesforce object type |
| `oid` | str | — | Record ID |
| `timeout` | str\|int | None | Default 10s |

---

### Verify Record
`Tags: Interaction, REST_API`

Verifies field values on a record via API.

```robot
Verify Record    Contact    ${contact}    FirstName=Jamie    LastName=Doe    Email=jamie.doe@fake.com
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `sobject` | str | — | Salesforce object type |
| `oid` | str | — | Record ID |
| `partial_match` | bool | False | Allow partial string match |
| `timeout` | str\|int | None | Default 10s |
| `**data` | str | — | Field=ExpectedValue pairs |

---

### Query Records
`Tags: Getters, REST_API`

Executes a SOQL query.

```robot
${results}=    QueryRecords    SELECT id,name FROM Contact WHERE name LIKE 'John%'
${ID}=         Set Variable    ${results}[records][0][Id]
```

> Escape `=` in SOQL with `\=` when needed.

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `query` | str | — | SOQL query string |
| `timeout` | str\|int | None | Default 10s |

**Returns:** dict (Salesforce REST query response with `records` list)

---

### Import Records
`Tags: Interaction, REST_API`

Creates multiple records from a `.json` file.

```robot
${json}=           Import Records    Account    ${CURDIR}/resources/new_records.json
${id1}=            Set Variable      ${json}[results][0][id]
@{created_ids}=    Evaluate          [x['id'] for x in $json['results']]
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `sobject` | str | — | Salesforce object type |
| `file` | str | — | Full path to `.json` file |
| `additional_headers` | str\|dict | None | Extra request headers |
| `timeout` | str\|int | None | Default 10s |

---

### Export Records
`Tags: Getters, REST_API`

Runs a SOQL query and saves results to a `.json` file.

```robot
${path}=    Export Records    SELECT id,name FROM Contact    ${OUTPUTDIR}/contacts.json
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `query` | str | — | SOQL query |
| `output_file` | str | — | Full path for output file |
| `timeout` | str\|int | None | Default 10s |

**Returns:** path to created file

---

### Execute Apex
`Tags: Interaction, REST_API`

Executes anonymous Apex. Verifies the API call and compilation succeed.

```robot
${results}=    Execute Apex    Account a = new Account();\na.Name = 'Test';\ninsert a;
${results}=    Execute Apex    my_script.apex    is_file=True
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `script` | str | — | Apex code string or file path |
| `is_file` | bool | False | True if `script` is a file path |
| `timeout` | str\|int | None | Default 10s |

**Returns:** dict (API response JSON)

---

### List Objects
`Tags: Getters, REST_API`

Lists all available sObjects in the org.

```robot
ListObjects
```

---

### Get Access Token
`Tags: Getters, REST_API, Utilities`

Returns the current access token (for use with third-party libraries).

```robot
${token}=    Get Access Token
```

---

### Get Instance URL
`Tags: Getters, REST_API, Utilities`

Returns the instance URL after authentication.

```robot
${instance_url}=    Get Instance URL
```

---

### Get API Version URL
`Tags: Getters, REST_API, Utilities`

Returns the API version URL for the instance.

```robot
${api_version_url}=    Get API Version URL
```

---

## REST API — CPQ

### Read CPQ Quote
`Tags: CPQ, Getters, REST_API`

Retrieves a CPQ QuoteModel by quote ID.

```robot
${cpq_quote}=    Read CPQ Quote    a2w7Q000000LBGRQA4
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `quote_id` | str | — | CPQ Quote ID |
| `timeout` | str\|int | None | Default 10s |

**Returns:** dict (QuoteModel)

---

### Read CPQ Product
`Tags: CPQ, Getters, REST_API`

Retrieves a CPQ ProductModel.

```robot
${cpq_product}=    Read CPQ Product    ${product_id}[records][0][Id]    ${pricebook_id}[records][0][Id]    USD
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `product_id` | str | — | Product ID |
| `pricebook_id` | str | — | Pricebook ID |
| `currency_code` | str | `USD` | ISO currency code (multi-currency orgs) |
| `timeout` | str\|int | None | Default 10s |

**Returns:** dict (ProductModel)

---

### Add CPQ Products
`Tags: CPQ, Interaction, REST_API`

Adds products to a CPQ QuoteModel.

```robot
${cpq_quote_model}=      Read CPQ Quote       ${quote_id}
${cpq_product}=          Read CPQ Product     ${product_id}[records][0][Id]    ${pricebook_id}[records][0][Id]    USD
${quote_with_product}=   Add CPQ Products     ${cpq_quote_model}    ${cpq_product}
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `quote_model` | str\|dict | — | QuoteModel to add products to |
| `product_models` | str\|dict | — | Product model(s) to add |
| `group_key` | int | 0 | Index of quote line group (grouped quotes only) |
| `timeout` | str\|int | None | Default 10s |

**Returns:** dict (updated QuoteModel)

---

### Calculate CPQ Quote
`Tags: CPQ, Interaction, REST_API`

Calculates a CPQ quote.

```robot
${cpq_quote}=           Read CPQ Quote         a2w7Q000000LBGRQA4
${calculated_quote}=    Calculate CPQ Quote    ${cpq_quote}
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `quote_model` | str | — | QuoteModel to calculate |
| `timeout` | str\|int | None | Default 10s |

**Returns:** dict (calculated QuoteModel)

---

### Validate CPQ Quote
`Tags: CPQ, Interaction, REST_API`

Runs CPQ validation rules against a QuoteModel.

```robot
${validation_errors}=    Validate CPQ Quote    ${cpq_quote}
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `quote_model` | str | — | QuoteModel to validate |
| `timeout` | str\|int | None | Default 10s |

**Returns:** empty list if valid; list of validation error strings if not

---

### Save CPQ Quote
`Tags: CPQ, Interaction, REST_API`

Saves a CPQ QuoteModel to Salesforce (must be done before changes take effect).

```robot
${cpq_quote}=           Read CPQ Quote         a2w7Q000000LBGRQA4
${calculated_quote}=    Calculate CPQ Quote    ${cpq_quote}
${saved_quote}=         Save CPQ Quote         ${calculated_quote}
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `quote_model` | str | — | QuoteModel to save |
| `timeout` | str\|int | None | Default 10s |

**Returns:** dict (saved QuoteModel)

---

## REST API — Agentforce

### Create Agentforce Session
`Tags: Agentforce, Interaction, REST_API`

Creates a new Agentforce API session. Requires `Client Authenticate` first.

```robot
${session}=    Create Agentforce Session    https://mydomain.my.salesforce.com    0A5E0000000YyV0QAK
${session_id}= Create Agentforce Session   https://mydomain.my.salesforce.com    0XxKZ000000ZjK31AL    bypass_user=False
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `my_domain` | str | — | Full domain URL (include `https://`) |
| `agent_id` | str | — | 18-char agent ID from Setup URL |
| `bypass_user` | bool | True | True = use agent's assigned user |
| `timeout` | str\|int | None | Default 10s |

**Returns:** session ID string

---

### Send Agentforce Message
`Tags: Agentforce, Interaction, REST_API`

Sends a message to an Agentforce agent and returns the response.

```robot
${response}=          Send Agentforce Message    ${session_id}    What can you do?
# ${response}[0] = plain text reply
# ${response}[1] = full JSON response

${message}    ${data}=    Send Agentforce Message    ${session_id}    What can you do?    sequence_id=1
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `session_id` | str | — | Session ID from `Create Agentforce Session` |
| `prompt` | str | — | User input message |
| `sequence_id` | int | 1 | Increment for each message in the session |
| `timeout` | int\|float\|str | 60 | Request timeout in seconds |

**Returns:** tuple `(message: str, data: dict)`

---

## Utilities & MFA

### Get OTP
`Tags: MFA, Utilities`

Generates a TOTP code (same as an authenticator app). Used in MFA login flows.

```robot
${mfa_code}=    GetOTP    my_user@testsf.com    ${MY_SECRET}
TypeText        Code      ${mfa_code}
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `username` | str | — | Salesforce username |
| `secret` | str | — | TOTP secret from Salesforce setup |
| `url` | str | `https://login.salesforce.com` | Salesforce instance URL |

**MFA setup:** Log in → Setup → Users → App Registration: One-Time Password → Connect → right-click QR image → Open in new tab → copy `secret=VALUE` from URL → store as CRT secret variable `${secret}`.

---

### Timestr To Secs

Parses time strings and returns seconds.

```robot
${secs}=    Timestr To Secs    1h 10s
${secs}=    Timestr To Secs    01:00:10
```

| Argument | Type | Default | Description |
|----------|------|---------|-------------|
| `timestr` | str\|int\|float | — | Time string, e.g. `1h 10s`, `01:00:10`, `42` |
| `round_to` | int | 3 | Decimal places (None to disable rounding) |

---

## Lightning UI Patterns & Gotchas

### Quick Action Overflow Button ("Show more actions")

The overflow button on a Salesforce record's action bar (the `▾` chevron after the visible quick action buttons) has assistive text "Show more actions" — but `ClickText    Show more actions    js=True` is unreliable because the same assistive text can appear on other page controls (e.g. list view dropdowns), causing the wrong element to be clicked.

**Use `slds-dropdown_actions` on the `lightning-button-menu` to pin to the record action bar specifically:**

```robot
${xp_more}=    Set Variable    xpath=//lightning-button-menu[contains(@class,'slds-dropdown_actions')]//button
ClickElement    ${xp_more}    js=True
```

`slds-dropdown_actions` is the SLDS semantic class for record quick-action menus and is not shared with list view or other page controls. `js=True` is required because the button is often not in the visible viewport.

After clicking, verify items with plain `VerifyText` — no `recognition_mode=vision` needed:

```robot
VerifyText    Mark as Staff Profile
VerifyText    Enrol Member
```
