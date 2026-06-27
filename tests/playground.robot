*** Settings ***
Library             QForce
Library             DateTime
Library             RequestsLibrary
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

${persona_admin}            ${EMPTY}    # API-enabled admin username for SOQL/REST calls; set in CRT

# GSCV API test variables
${qa_gscv_apikey}           ${EMPTY}    # GSCV x-api-key header value; set as secret in CRT
${qa_gscv_endpoint}         ${EMPTY}    # GSCV base URL (no trailing slash); set in CRT
${GSCV_API_SALUTATION}      Mr
${GSCV_API_FIRST_NAME}      ${EMPTY}    # set by Generate GSCV API Test Data
${GSCV_API_LAST_NAME}       ${EMPTY}    # set by Generate GSCV API Test Data
${GSCV_API_PHONE}           ${EMPTY}    # set by Generate GSCV API Test Data
${GSCV_API_EMAIL}           ${EMPTY}    # set by Generate GSCV API Test Data
${GSCV_API_TC_RECORD_ID}    ${EMPTY}    # captured after save; used by teardown to clean up


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


TC_002 Create Account And Verify GSCV API Returns Customer Profile
    [Documentation]    Create a minimal Customer Profile in Salesforce via the GSCV app, wait for
    ...    the GSCV ID to be assigned, then call GET /b2bv2/customerProfile on the GSCV API and
    ...    verify the response contains the correct customerProfileId, firstName, and lastName.
    [Tags]    gscv    api    playground
    [Setup]    Setup GSCV API Test Browser
    [Teardown]    Delete GSCV API Test Profile
    Generate GSCV API Test Data
    Navigate To Accounts Via GSCV Nav
    ClickText    New
    UseModal    On
    Sleep    2s
    PickList    Salutation    ${GSCV_API_SALUTATION}
    TypeText    First Name    ${GSCV_API_FIRST_NAME}
    TypeText    Last Name     ${GSCV_API_LAST_NAME}
    ${xp_phone_cc}=    Set Variable    xpath=//*[@data-testid='phone-country-code-1']
    TypeText    ${xp_phone_cc}    61
    ${xp_phone}=    Set Variable    xpath=//*[@data-testid='phone-number-1']
    TypeText    ${xp_phone}    ${GSCV_API_PHONE}
    ${xp_email}=    Set Variable    xpath=//*[@data-testid='email-1']
    TypeText    ${xp_email}    ${GSCV_API_EMAIL}
    ClickText    Create
    UseModal    Off
    VerifyText    GSCV Profile ID
    ${status}    ${id}=    Run Keyword And Ignore Error    Get Record ID From Url
    Run Keyword If    '${status}' == 'PASS'    Set Test Variable    ${GSCV_API_TC_RECORD_ID}    ${id}
    ${gscv_id}=    Get GSCV ID From Salesforce    ${GSCV_API_TC_RECORD_ID}
    Call GSCV Customer Profile API And Verify    ${gscv_id}


*** Keywords ***
Setup Browser
    Set Library Search Order    QForce    QWeb
    Open Browser                about:blank    ${BROWSER}
    SetConfig                   LineBreak           ${EMPTY}
    SetConfig                   DefaultTimeout      30s
    SetConfig                   CSSSelectors        False

Authenticate And Open Leisure Sales
    # Disable Chrome's native "Save address?" bubble via both feature flags and prefs.
    # Neither approach alone has worked — trying them together here in the playground.
    OpenBrowser                 about:blank    chrome
    ...    options=add_argument("--disable-features=AutofillAddressUserPerception,AutofillSaveAddressProfilePrompt"), add_experimental_option("prefs", {"autofill.profile_enabled": False, "autofill.address_enabled": False, "credentials_enable_service": False, "profile.password_manager_enabled": False})
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

Delete Created Profile
    [Documentation]    Teardown: delete the person account created by this test via the REST API
    ...    so runs don't pollute the org. Runs even when the test fails. Best-effort — skips if
    ...    no record Id was captured (e.g. creation failed) and ignores delete errors.
    ...    Re-auths as admin — test users are not API-enabled.
    Run Keyword If    '${TC001_RECORD_ID}' != '${EMPTY}'    Run Keywords
    ...    Jwt Authenticate    ${client_id}    ${persona_admin}    ${server_key}    sandbox=True
    ...    AND    Run Keyword And Ignore Error    Delete Record    Account    ${TC001_RECORD_ID}

Setup GSCV API Test Browser
    OpenBrowser         about:blank    chrome
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login           /lightning/page/home
    VerifyTitle         Home | Salesforce

Navigate To Accounts Via GSCV Nav
    ClickText    Show Navigation Menu
    ClickText    Accounts
    ClickText    Close    anchor=Skip to Navigation

Generate GSCV API Test Data
    [Documentation]    Derive unique First Name, Last Name, Email, and Phone from the current
    ...    timestamp so each run is fully isolated. Names use letter-only encoding (Salesforce
    ...    name fields reject digits). Phone is prefixed with 4 (valid AU mobile format).
    ${ts}=          Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${token}=       Evaluate            ''.join(chr(97 + int(d)) for d in $ts)
    ${phone}=       Evaluate            '4' + $ts[-8:]
    Set Test Variable    ${GSCV_API_FIRST_NAME}    Test${token}
    Set Test Variable    ${GSCV_API_LAST_NAME}     Profile${token}
    Set Test Variable    ${GSCV_API_EMAIL}         test.automation.gscvapi.${ts}@auto.com
    Set Test Variable    ${GSCV_API_PHONE}         ${phone}

Get GSCV ID From Salesforce
    [Documentation]    Re-auths as admin, queries crm_GSCV_ID__c for the given Account Id,
    ...    asserts it is not null, then re-auths as the sales user and returns the GSCV ID.
    [Arguments]    ${record_id}
    Run Keyword If    '${record_id}' == '${EMPTY}'    Fail    No record ID captured — cannot query GSCV ID
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${result}=          QueryRecords    SELECT crm_GSCV_ID__c FROM Account WHERE Id = '${record_id}' LIMIT 1
    ${gscv_id}=         Set Variable    ${result}[records][0][crm_GSCV_ID__c]
    Should Not Be Equal    ${gscv_id}    ${None}    msg=crm_GSCV_ID__c is null for Account ${record_id}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    [Return]    ${gscv_id}

Call GSCV Customer Profile API And Verify
    [Documentation]    Calls GET /b2bv2/customerProfile with hardcoded AU/INTERNALS/AU-FC context
    ...    and the supplied GSCV ID. Verifies 200 response and that customerProfileId, firstName,
    ...    and lastName match the Salesforce record.
    ...    Expects ${qa_gscv_endpoint} to be the base URL without a trailing slash.
    [Arguments]    ${gscv_id}
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json    Content-Type=application/json
    ${params}=     Create Dictionary
    ...    countryCode=AU
    ...    customerContextType=INTERNALS
    ...    customerContextLocator=AU-FC
    ...    customerProfileId=${gscv_id}
    ${response}=    GET    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}
    ...    params=${params}
    ...    expected_status=200
    Should Be Equal As Strings    ${response.json()}[customerProfileId]    ${gscv_id}
    Should Be Equal As Strings    ${response.json()}[firstName]            ${GSCV_API_FIRST_NAME}
    Should Be Equal As Strings    ${response.json()}[lastName]             ${GSCV_API_LAST_NAME}

Delete GSCV API Test Profile
    [Documentation]    Teardown: delete the account created by TC_002. Best-effort — skips if no
    ...    record Id was captured. Re-auths as admin — test users are not API-enabled.
    Run Keyword If    '${GSCV_API_TC_RECORD_ID}' != '${EMPTY}'    Run Keywords
    ...    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ...    AND    Run Keyword And Ignore Error    Delete Record    Account    ${GSCV_API_TC_RECORD_ID}
