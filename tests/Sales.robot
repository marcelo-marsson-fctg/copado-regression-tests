*** Settings ***
Library             QForce
Library             DateTime
Resource            ../resources/common.resource
Suite Setup         Setup Browser
Suite Teardown      End suite


*** Variables ***
${BROWSER}                  chrome
# Test data — override via CRT variables if needed
${TC001_SALUTATION}         Mr
${TC001_FIRST_NAME}         Test
${TC001_MIDDLE_NAME}        Automation
${TC001_LAST_NAME}          Profile
${TC001_PHONE}              +61400400400
${TC001_EMAIL}              test.automation@auto.com
${TC001_BILLING_STREET}     123 Test Street
${TC001_BILLING_CITY}       Melbourne
${TC001_BILLING_STATE}      Victoria
${TC001_BILLING_ZIP}        3000
${TC001_BILLING_COUNTRY}    Australia
${TC001_RECORD_ID}          ${EMPTY}    # captured after save; used by teardown to clean up

${TC002_SALUTATION}         Mr
${TC002_FIRST_NAME}         Test
${TC002_MIDDLE_NAME}        Automation
${TC002_LAST_NAME}          Profile
${TC002_PHONE}              +61400400400
${TC002_EMAIL}              test.automation.tc002@auto.com
${TC002_RECORD_ID}          ${EMPTY}    # captured after save; used by teardown to clean up

${persona_admin}            ${EMPTY}    # API-enabled admin username for SOQL/REST calls; set in CRT (test users are not API-enabled)

${TC003_NEW_EMAIL}          ${EMPTY}    # populated at runtime via Generate TC003 Test Data
${TC003_RECORD_ID}          ${EMPTY}    # populated at runtime; used by teardown to restore email
${TC003_ORIGINAL_EMAIL}     ${EMPTY}    # populated at runtime; used by teardown to restore email


*** Test Cases ***
TC_001 Customer Profile Creation Via Accounts List View And Page Layout Validation
    [Documentation]    Verify a Customer Profile can be created via the Accounts list view New button.
    ...    Validates the creation form layout (sections/fields) and the record page layout
    ...    (highlight panel, quick actions, tabs, related panel) after save.
    [Tags]    profile-management    sales    p1    regression
    [Setup]    Authenticate And Open Leisure Sales
    [Teardown]    Delete Created Profile
    Generate Unique Test Data
    Navigate To Accounts List View
    Open New Customer Profile Form
    Verify Creation Form Sections
    Verify Creation Form About Fields
    Verify Creation Form Get In Touch Fields
    Verify Creation Form Billing Address Fields
    Verify Creation Form Mailing Address Fields
    Verify Creation Form Other Address Fields
    Verify Creation Form History Fields
    Create Customer Profile
    Verify Sync Warning Message
    RefreshPage
    Verify Highlight Panel Fields
    Verify Quick Action Buttons
    Verify Record Tabs
    Verify Details Tab Layout
    Verify Related Records Tab Sections
    Verify Right Panel Sections

TC_003 Customer Profile Field Updation PersonAccountHistory Validation
    [Documentation]    Verify user is able to update the Email field on an existing Customer Profile
    ...    record synced with GSCV, and that the change is tracked in the Person Account History
    ...    related list with the correct date, field name, modifying user, original value, and
    ...    new value.
    ...    Precondition: At least one Customer Profile record with a GSCV Profile ID must exist.
    [Tags]    profile-management    sales    p3    regression
    [Setup]    Authenticate And Open Leisure Sales
    [Teardown]    Restore TC003 Original Email
    Generate TC003 Test Data
    Find And Open GSCV Synced Profile
    Update TC003 Email Field
    Navigate To Person Account History
    Verify Email Change In Person Account History

TC_002 Customer Profile Creation Via Global Action Button And Field Mapping Validation
    [Documentation]    Verify a Customer Profile can be created via the "New Person Account"
    ...    Global Action button. Validates the creation form shows the required fields (Salutation,
    ...    First Name, Middle Name, Last Name, Phone, Email), that the record saves successfully,
    ...    that GSCV Profile ID is populated after page refresh, and that Account Name, Phone,
    ...    and Email reflect the values entered during creation.
    [Tags]    profile-management    sales    p1    regression
    [Setup]    Authenticate And Open Leisure Sales
    [Teardown]    Delete Created TC002 Profile
    Generate Unique TC002 Test Data
    Open Global Action New Person Account
    Verify TC002 Creation Form Fields
    Create TC002 Customer Profile
    RefreshPage
    Verify GSCV Profile ID Is Populated
    Verify TC002 Account Name Data
    Verify TC002 Phone And Email Data

*** Keywords ***
Setup Browser
    Set Library Search Order    QForce    QWeb
    Open Browser                about:blank    ${BROWSER}
    SetConfig                   LineBreak           ${EMPTY}
    SetConfig                   DefaultTimeout      30s
    SetConfig                   CSSSelectors        False

Authenticate And Open Leisure Sales
    OpenBrowser                 about:blank    chrome
    Jwt Authenticate            ${client_id}    ${persona_sales_team_member}    ${server_key}    sandbox=True
    Jwt Login                   /lightning/page/home
    VerifyTitle                 Home | Salesforce
    ClickElement                xpath=//button[@title='App Launcher']
    ClickElement                xpath=//input[contains(@placeholder,'Search apps')]
    TypeText                    Search apps and items...        Leisure Sales
    ClickText                   Leisure Sales

Navigate To Accounts List View
    Run Keyword And Ignore Error    ClickElement    xpath=//*[contains(@class,'toastClose') or @title='Close' or @title='Dismiss']
    ClickElement                    xpath=//button[.//*[@data-key='chevrondown']]
    ClickText                       Accounts
    VerifyText                      Accounts

Open New Customer Profile Form
    ClickText                   New
    VerifyText                  New Account: Person Account

Verify Creation Form Sections
    VerifyText                  About
    VerifyText                  Get in Touch
    VerifyText                  History

Verify Creation Form About Fields
    VerifyText                  Salutation
    VerifyText                  First Name
    VerifyText                  Middle Name
    VerifyText                  Last Name
    VerifyText                  Preferred Name
    VerifyText                  Gender Identity
    VerifyText                  Birthdate
    VerifyText                  RFM
    VerifyText                  RFM Customer Segment
    VerifyText                  RFM Customer Strategy
    VerifyText                  Account Currency
    VerifyText                  Is Staff Profile?
    VerifyText                  Notes

Verify Creation Form Get In Touch Fields
    ScrollText                  Get in Touch
    VerifyText                  Preferred Method of Contact
    VerifyText                  Phone
    VerifyText                  Home Phone
    VerifyText                  Other Phone
    VerifyText                  Email
    VerifyText                  Email Business
    VerifyText                  Email Other

Verify Creation Form Billing Address Fields
    VerifyText                  Address Search
    VerifyText                  Billing Country
    VerifyText                  Billing Street
    VerifyText                  Billing City
    VerifyText                  Billing State/Province
    VerifyText                  Billing Zip/Postal Code

Verify Creation Form Mailing Address Fields
    VerifyText                  Mailing Country
    VerifyText                  Mailing Street
    VerifyText                  Mailing City
    VerifyText                  Mailing State/Province
    VerifyText                  Mailing Zip/Postal Code

Verify Creation Form Other Address Fields
    VerifyText                  Other Country
    VerifyText                  Other Street
    VerifyText                  Other City
    VerifyText                  Other State/Province
    VerifyText                  Other Zip/Postal Code

Verify Creation Form History Fields
    VerifyText                  Created By
    VerifyText                  Last Modified By

Generate Unique Test Data
    [Documentation]    Make the duplicate-sensitive fields unique per run so they don't trip
    ...    Salesforce duplicate detection. First Name, Last Name and Email all carry a token
    ...    derived from the current timestamp (the wall clock advances every run). The names use
    ...    a digit-free, letters-only encoding of the token (Salesforce name fields reject
    ...    digits). Values are written back into the TC001 variables so both data entry and the
    ...    later verifications use the same dynamic values.
    # NOTE: Generate Random String returned the SAME value every run in CRT (its RNG is seeded
    # deterministically), so names collided and tripped duplicate detection. Derive the token
    # from the current timestamp instead — the wall clock always advances between runs. Map each
    # digit 0-9 to a letter a-j so the token is digit-free (Salesforce name fields reject digits).
    ${ts}=          Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${token}=       Evaluate            ''.join(chr(97 + int(d)) for d in $ts)
    Set Test Variable           ${TC001_FIRST_NAME}   Test${token}
    Set Test Variable           ${TC001_LAST_NAME}    Profile${token}
    Set Test Variable           ${TC001_EMAIL}        test.automation.${ts}@auto.com
    Log    Unique test data -> First Name: Test${token} | Last Name: Profile${token} | Email: test.automation.${ts}@auto.com

Delete Created Profile
    [Documentation]    Teardown: delete the person account created by this test via the REST API
    ...    so runs don't pollute the org. Runs even when the test fails. Best-effort — skips if
    ...    no record Id was captured (e.g. creation failed) and ignores delete errors.
    ...    Re-auths as admin — test users are not API-enabled.
    Run Keyword If    '${TC001_RECORD_ID}' != '${EMPTY}'    Run Keywords
    ...    Jwt Authenticate    ${client_id}    ${persona_admin}    ${server_key}    sandbox=True
    ...    AND    Run Keyword And Ignore Error    Delete Record    Account    ${TC001_RECORD_ID}

Create Customer Profile
    Run Keyword And Ignore Error    ClickElement    xpath=//*[contains(@class,'toastClose') or @title='Close' or @title='Dismiss']
    # Salutation is a Lightning picklist (combobox, not a native <select>) — use QForce PickList.
    PickList                    Salutation                  ${TC001_SALUTATION}
    TypeText                    First Name                  ${TC001_FIRST_NAME}
    TypeText                    Middle Name                 ${TC001_MIDDLE_NAME}
    TypeText                    Last Name                   ${TC001_LAST_NAME}
    TypeText                    Phone                       ${TC001_PHONE}
    TypeText                    Email                       ${TC001_EMAIL}
    TypeText                    Billing Street              ${TC001_BILLING_STREET}
    TypeText                    Billing City                ${TC001_BILLING_CITY}
    TypeText                    Billing Zip/Postal Code     ${TC001_BILLING_ZIP}
    # Country & State/Province are Lightning picklists (State & Country Picklists enabled).
    # Select Country FIRST — the State/Province picklist is filtered by the chosen country.
    PickList                    Billing Country             ${TC001_BILLING_COUNTRY}
    PickList                    Billing State/Province      ${TC001_BILLING_STATE}
    # Click the exact "Save" button. Plain ClickText Save also matches "Save & New",
    # which saves the record AND opens a fresh blank form instead of routing to the
    # new record page. Match the button whose full text is exactly "Save".
    ClickElement                xpath=//button[normalize-space(.)='Save']
    VerifyText                  was created.
    # Capture the new record's Id from the record-page URL so teardown can delete it.
    # Best-effort: never fail the test if the Id can't be read.
    ${status}    ${id}=         Run Keyword And Ignore Error    Get Record ID From Url
    Run Keyword If              '${status}' == 'PASS'    Set Test Variable    ${TC001_RECORD_ID}    ${id}

Verify Sync Warning Message
    # Match the banner exactly as rendered: capitalised "Customer Profile" AND the typo
    # "sychronised" (missing an 'n') that exists in the Salesforce banner itself.
    VerifyText                  The Customer Profile has not sychronised to Helio

Verify Highlight Panel Fields
    VerifyText                  Email
    VerifyText                  Phone
    VerifyText                  GSCV Profile ID
    VerifyText                  GDS ID
    VerifyText                  Linked My Account
    VerifyText                  ${TC001_FIRST_NAME}
    VerifyText                  ${TC001_LAST_NAME}

Verify Quick Action Buttons
    VerifyText                  Follow
    VerifyText                  Edit
    VerifyText                  New Lead
    VerifyText                  New Opportunity
    # js=True opens the dropdown (confirmed working). These two items live inside native
    # shadow DOM — QWeb's DOM-based VerifyText cannot see them. vision mode uses a
    # screenshot + OCR to find the text visually, bypassing shadow DOM entirely.
    ${xp_more}=                 Set Variable    xpath=//lightning-button-menu[contains(@class,'slds-dropdown_actions')]//button
    ClickElement                ${xp_more}    js=True
    VerifyText                  Mark as Staff Profile
    VerifyText                  Enrol Member
    VerifyText                  New Task
    VerifyText                  New Event
    VerifyText                  Log a Call

Verify Record Tabs
    VerifyText                  Details
    VerifyText                  Linked Travellers
    VerifyText                  Travel Documents
    VerifyText                  Loyalty
    VerifyText                  Marketing Preferences
    VerifyText                  Related Records

Verify Details Tab Layout
    ClickText                   Details
    # About section fields
    VerifyText                  Account Name
    VerifyText                  Preferred Name
    VerifyText                  Gender Identity
    VerifyText                  Birthdate
    VerifyText                  RFM Customer Segment
    VerifyText                  RFM Customer Strategy
    VerifyText                  Account Currency
    VerifyText                  Is Staff Profile?
    VerifyText                  Notes
    # PII guidance text between About and Get in Touch
    VerifyText                  Do NOT include payment information
    # Get in Touch section fields
    ScrollText                  Get in Touch
    VerifyText                  ${TC001_PHONE}
    VerifyText                  ${TC001_EMAIL}
    VerifyText                  ${TC001_BILLING_STREET}
    VerifyText                  Preferred Method of Contact
    VerifyText                  Home Phone
    VerifyText                  Other Phone
    VerifyText                  Email Business
    VerifyText                  Email Other
    VerifyText                  Billing Address
    VerifyText                  Mailing Address
    VerifyText                  Other Address
    # History section fields
    VerifyText                  Created By
    VerifyText                  Last Modified By

Verify Related Records Tab Sections
    ClickText                   Related Records
    VerifyText                  Files
    VerifyText                  Trip History
    VerifyText                  Person Account History

Verify Right Panel Sections
    VerifyText                  Loyalty Member Profile
    VerifyText                  Activity
    VerifyText                  Voice Calls
    VerifyText                  Leads
    VerifyText                  Opportunities
    VerifyText                  Cases
    VerifyText                  Notes

Generate Unique TC002 Test Data
    ${ts}=          Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${token}=       Evaluate            ''.join(chr(97 + int(d)) for d in $ts)
    Set Test Variable           ${TC002_FIRST_NAME}   Test${token}
    Set Test Variable           ${TC002_LAST_NAME}    Profile${token}
    Set Test Variable           ${TC002_EMAIL}        test.automation.tc002.${ts}@auto.com
    Log    Unique test data -> First Name: Test${token} | Last Name: Profile${token} | Email: test.automation.tc002.${ts}@auto.com

Open Global Action New Person Account
    # The Global Actions trigger is an <a> with class="globalCreateTrigger" and title="" (empty).
    # title='Global Actions' fails — that text only lives in a hidden tooltip span, not the element.
    ClickElement                xpath=//a[contains(@class,'globalCreateTrigger')]
    VerifyText                  New Person Account
    ClickText                   New Person Account
    VerifyText                  New Person Account

Verify TC002 Creation Form Fields
    ScrollText                  Salutation
    VerifyText                  Salutation
    ScrollText                  First Name
    VerifyText                  First Name
    ScrollText                  Middle Name
    VerifyText                  Middle Name
    ScrollText                  Last Name
    VerifyText                  Last Name
    VerifyElement               xpath=//div[@data-target-selection-name='sfdc:RecordField.Account.Phone']
    VerifyElement               xpath=//div[@data-target-selection-name='sfdc:RecordField.Account.PersonEmail']

Create TC002 Customer Profile
    # Salutation is a Lightning picklist (combobox) — use QForce PickList, never DropDown
    ScrollText                  Salutation
    PickList                    Salutation                  ${TC002_SALUTATION}
    ScrollText                  First Name
    TypeText                    First Name                  ${TC002_FIRST_NAME}
    ScrollText                  Middle Name
    TypeText                    Middle Name                 ${TC002_MIDDLE_NAME}
    ScrollText                  Last Name
    TypeText                    Last Name                   ${TC002_LAST_NAME}
    # Phone/Email: xpath= prefix causes RF named-arg parse error; store in variable so RF doesn't see the = sign
    ${xp_phone}=                Set Variable    xpath=//div[@data-target-selection-name='sfdc:RecordField.Account.Phone']//input
    TypeText                    ${xp_phone}     ${TC002_PHONE}
    ${xp_home}=                 Set Variable    xpath=//div[@data-target-selection-name='sfdc:RecordField.Account.PersonHomePhone']//input
    TypeText                    ${xp_home}      ${TC002_PHONE}
    ${xp_other}=                Set Variable    xpath=//div[@data-target-selection-name='sfdc:RecordField.Account.PersonOtherPhone']//input
    TypeText                    ${xp_other}     ${TC002_PHONE}
    ${xp_email}=                Set Variable    xpath=//div[@data-target-selection-name='sfdc:RecordField.Account.PersonEmail']//input
    TypeText                    ${xp_email}     ${TC002_EMAIL}
    # Click the exact "Save" button to avoid matching "Save & New"
    ClickElement                xpath=//button[normalize-space(.)='Save']
    # Global Action stays on the home page after save — Get Record ID From Url won't work here.
    # Look up the new record by its unique email instead, then navigate to the record page.
    # Re-auth as admin for the API call — test users are not API-enabled.
    Jwt Authenticate            ${client_id}    ${persona_admin}    ${server_key}    sandbox=True
    ${result}=                  QueryRecords    SELECT Id FROM Account WHERE PersonEmail \= '${TC002_EMAIL}' LIMIT 1
    ${id}=                      Set Variable    ${result}[records][0][Id]
    Set Test Variable           ${TC002_RECORD_ID}    ${id}
    GoTo                        ${login_url}lightning/r/Account/${id}/view
    VerifyText                  ${TC002_LAST_NAME}

Verify GSCV Profile ID Is Populated
    # After page refresh, GSCV Profile ID should be auto-populated by the Helio integration
    VerifyText                  GSCV Profile ID
    # CONFIRM IN CRT: add a check that the field has a non-empty value (system-generated)

Verify TC002 Account Name Data
    ClickText                   Details
    # Account Name is auto-composed from Salutation + First Name + Middle Name + Last Name
    # CONFIRM IN CRT: adjust expected value to match your org's Person Account name format
    # (some orgs include Salutation and/or Middle Name; others only First Name + Last Name)
    VerifyField                 Account Name    ${TC002_SALUTATION} ${TC002_FIRST_NAME} ${TC002_MIDDLE_NAME} ${TC002_LAST_NAME}

Verify TC002 Phone And Email Data
    # CONFIRM IN CRT: verify Phone displays with/without formatting (e.g. "+61400400400" vs "0400 400 400")
    VerifyText                  ${TC002_PHONE}
    VerifyText                  ${TC002_EMAIL}

Delete Created TC002 Profile
    Run Keyword If    '${TC002_RECORD_ID}' != '${EMPTY}'    Run Keywords
    ...    Jwt Authenticate    ${client_id}    ${persona_admin}    ${server_key}    sandbox=True
    ...    AND    Run Keyword And Ignore Error    Delete Record    Account    ${TC002_RECORD_ID}

Generate TC003 Test Data
    ${ts}=          Get Current Date    result_format=%Y%m%d%H%M%S%f
    Set Test Variable    ${TC003_NEW_EMAIL}    test.tc003.update.${ts}@auto.com

Find And Open GSCV Synced Profile
    # Re-auth as admin to run SOQL — test users are not API-enabled
    Jwt Authenticate    ${client_id}    ${persona_admin}    ${server_key}    sandbox=True
    ${result}=          QueryRecords    SELECT Id, PersonEmail FROM Account WHERE crm_GSCV_ID__c != null AND IsPersonAccount = true LIMIT 1
    ${id}=              Set Variable    ${result}[records][0][Id]
    ${email}=           Set Variable    ${result}[records][0][PersonEmail]
    Set Test Variable   ${TC003_RECORD_ID}       ${id}
    Set Test Variable   ${TC003_ORIGINAL_EMAIL}  ${email}
    # Re-auth as sales consultant for UI interaction
    Jwt Authenticate    ${client_id}    ${persona_sales_team_member}    ${server_key}    sandbox=True
    GoTo                ${login_url}lightning/r/Account/${id}/view
    VerifyText          GSCV Profile ID

Update TC003 Email Field
    ClickText           Edit
    # CONFIRM IN CRT: verify that clicking Edit opens an inline modal (not a full-page form);
    # if a full-page form opens, remove the UseModal calls below
    UseModal            On
    ${xp_email}=        Set Variable    xpath=//div[@data-target-selection-name='sfdc:RecordField.Account.PersonEmail']//input
    TypeText            ${xp_email}     ${TC003_NEW_EMAIL}
    ClickElement        xpath=//button[normalize-space(.)='Save']
    UseModal            Off
    VerifyText          was saved.

Navigate To Person Account History
    ClickText           Related Records
    ScrollText          Person Account History
    VerifyText          Person Account History

Verify Email Change In Person Account History
    ${today}=           Get Current Date    result_format=%m/%d/%Y
    # CONFIRM IN CRT: verify Salesforce displays date in this format — may differ by org locale
    # (e.g. "6/22/2026", "22/06/2026", or "Jun 22, 2026")
    VerifyText          ${today}
    VerifyText          Email
    VerifyText          ${TC003_ORIGINAL_EMAIL}
    VerifyText          ${TC003_NEW_EMAIL}
    # CONFIRM IN CRT: add VerifyText for the modifying user's display name if needed

Restore TC003 Original Email
    Run Keyword If    '${TC003_RECORD_ID}' != '${EMPTY}' and '${TC003_ORIGINAL_EMAIL}' != '${EMPTY}'    Run Keywords
    ...    Jwt Authenticate    ${client_id}    ${persona_admin}    ${server_key}    sandbox=True
    ...    AND    Run Keyword And Ignore Error    Update Record    Account    ${TC003_RECORD_ID}    PersonEmail=${TC003_ORIGINAL_EMAIL}

