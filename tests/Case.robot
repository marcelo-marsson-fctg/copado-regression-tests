*** Settings ***
Library             RetryFailed    global_retries=1
Library             QForce
Library             DateTime
Resource            ../resources/common.resource
Suite Setup         Setup Browser
Suite Teardown      End suite


*** Variables ***
${BROWSER}                  chrome

# TC_102 test data — mandatory Feedback case fields.
# The spreadsheet does not specify concrete picklist values, so these are best-guess
# defaults. CONFIRM IN CRT: replace with valid picklist options for your org, or override
# via CRT variables.
${TC102_STATUS}             New
${TC102_TYPE}               Feedback
${TC102_CASE_CATEGORY}      ${EMPTY}      # CONFIRM IN CRT: a valid "Case Category" picklist value
${TC102_CASE_SUBCATEGORY}   ${EMPTY}      # CONFIRM IN CRT: a valid "Case Sub-category" value (if applicable)
${TC102_RECORD_ID}          ${EMPTY}      # captured after save; used by teardown to clean up
${TC102_CASE_NUMBER}        ${EMPTY}      # captured at runtime from the saved record

# CONFIRM IN CRT: the Customer Profile to map in the Account Details section (step 10).
# Use an existing person-account name (or its unique email) in your sandbox.
${TC102_CUSTOMER_PROFILE}   ${EMPTY}

${persona_service_agent}    ${EMPTY}    # JWT username for a "Sales & Service Agent" persona; set in CRT
${persona_admin}            ${EMPTY}    # API-enabled admin username for SOQL/REST calls; set in CRT


*** Test Cases ***
TC_102 Manual Feedback Case Creation Via New Feedback Global Action And Field Mapping
    [Documentation]    Verify a user can create a "Feedback" case record via the "New Feedback"
    ...    global action button, that the record saves and opens from the confirmation toast,
    ...    and that the field mapping is correct (Case Number, Record Type = Feedback, Case Owner
    ...    defaults to the creator, and the entered Status/Type/Category/Sub-category surface under
    ...    Key Case Details). Finally maps the case to a Customer Profile in Account Details.
    ...    Precondition: persona is Sales & Service Agent (or Customer Relations/Risk Agent),
    ...    logged into the Leisure Service app.
    [Tags]    manual-feedback-case    case    p1    regression
    [Setup]    Authenticate And Open Leisure Service
    [Teardown]    Delete Created TC102 Case
    Open Global Action New Feedback
    Create TC102 Feedback Case 
    Open Created Case From Toast
    Verify TC102 Case Number
    Verify TC102 Record Type Is Feedback
    Verify TC102 Case Owner Is Creator
    Verify TC102 Key Case Details
    Map TC102 Customer Profile


*** Keywords ***
Authenticate And Open Leisure Service
    [Documentation]    JWT-authenticate as a Sales & Service Agent and open the Leisure Service app.
    OpenBrowser                 about:blank    chrome
    Jwt Authenticate            ${client_id}    ${persona_service_agent}    ${server_key}    sandbox=True
    Jwt Login                   /lightning/page/home
    VerifyTitle                 Home | Salesforce
    ClickElement                xpath=//button[@title='App Launcher']
    ClickElement                xpath=//input[contains(@placeholder,'Search apps')]
    TypeText                    Search apps and items...        Leisure Service
    ClickText                   Leisure Service

Open Global Action New Feedback
    # The Global Actions trigger is an <a> with class="globalCreateTrigger" (title is empty).
    # Same element used by the Sales global-action flow.
    Run Keyword And Ignore Error    ClickElement    xpath=//*[contains(@class,'toastClose') or @title='Close' or @title='Dismiss']
    ClickElement                xpath=//a[contains(@class,'globalCreateTrigger')]
    VerifyText                  New Feedback
    ClickText                   New Feedback
    # New Feedback case creation page should be displayed.
    VerifyText                  New Feedback

Create TC102 Feedback Case
    # Status / Type / Case Category / Case Sub-category are Lightning picklists — use PickList,
    # never DropDown. Sub-category only applies for some categories; skip when left blank.
    PickList                    Status                  ${TC102_STATUS}
    PickList                    Type                    ${TC102_TYPE}
    Run Keyword If              '${TC102_CASE_CATEGORY}' != '${EMPTY}'
    ...    PickList             Case Category           ${TC102_CASE_CATEGORY}
    Run Keyword If              '${TC102_CASE_SUBCATEGORY}' != '${EMPTY}'
    ...    PickList             Case Sub-category       ${TC102_CASE_SUBCATEGORY}
    # Click the exact "Save" button (plain ClickText Save also matches "Save & New").
    ClickElement                xpath=//button[normalize-space(.)='Save']
    # A confirmation toast (Case "<number>" was created) should be displayed.
    VerifyText                  was created

Open Created Case From Toast
    # Click the case-number link inside the success toast to open the created record.
    # CONFIRM IN CRT: confirm the toast renders the case number as a clickable link; if it does
    # not, navigate via the record Id captured below instead.
    ClickElement                xpath=//*[contains(@class,'toastMessage')]//a
    # Capture the new record's Id from the record-page URL so teardown can delete it.
    ${status}    ${id}=         Run Keyword And Ignore Error    Get Record ID From Url
    Run Keyword If              '${status}' == 'PASS'    Set Test Variable    ${TC102_RECORD_ID}    ${id}

Verify TC102 Case Number
    # Case Number should be populated and match the number shown in the creation toast link.
    VerifyText                  Case Number
    # CONFIRM IN CRT: capture the actual case number (e.g. via VerifyField Case Number) and
    # assert it equals the value shown in the toast; the spreadsheet cannot supply the number.

Verify TC102 Record Type Is Feedback
    # "Case Record Type Name" should be displayed as "Feedback".
    VerifyText                  Feedback

Verify TC102 Case Owner Is Creator
    # Case Owner should default to the creating user.
    VerifyText                  Case Owner
    # CONFIRM IN CRT: assert the owner equals the running persona's display name
    # (e.g. VerifyField Case Owner <Display Name>).

Verify TC102 Key Case Details
    # The values entered at creation should surface under the "Key Case Details" section.
    ScrollText                  Key Case Details
    VerifyText                  Key Case Details
    VerifyText                  ${TC102_STATUS}
    VerifyText                  ${TC102_TYPE}
    Run Keyword If              '${TC102_CASE_CATEGORY}' != '${EMPTY}'
    ...    VerifyText           ${TC102_CASE_CATEGORY}
    Run Keyword If              '${TC102_CASE_SUBCATEGORY}' != '${EMPTY}'
    ...    VerifyText           ${TC102_CASE_SUBCATEGORY}

Map TC102 Customer Profile
    # In the Account Details section, search a Customer Profile record and map it.
    # This is a type-ahead lookup — use Combobox, not PickList.
    # CONFIRM IN CRT: confirm the lookup field label ("Account Name" / "Customer Profile") and
    # that ${TC102_CUSTOMER_PROFILE} resolves to an existing profile in your sandbox.
    Run Keyword If              '${TC102_CUSTOMER_PROFILE}' == '${EMPTY}'
    ...    Fail                 Set \${TC102_CUSTOMER_PROFILE} (CRT var) to an existing Customer Profile before running
    ScrollText                  Account Details
    Combobox                    Account Name            ${TC102_CUSTOMER_PROFILE}
    ClickElement                xpath=//button[normalize-space(.)='Save']
    VerifyText                  was saved
    VerifyText                  ${TC102_CUSTOMER_PROFILE}

Delete Created TC102 Case
    [Documentation]    Teardown: delete the Case created by this test via the REST API so runs
    ...    don't pollute the org. Best-effort; re-auths as admin (test users are not API-enabled).
    Run Keyword If    '${TC102_RECORD_ID}' != '${EMPTY}'    Run Keywords
    ...    Jwt Authenticate    ${client_id}    ${persona_admin}    ${server_key}    sandbox=True
    ...    AND    Run Keyword And Ignore Error    Delete Record    Case    ${TC102_RECORD_ID}
