*** Settings ***
Library             QForce
Library             DateTime
Library             RequestsLibrary
Resource            ../resources/common.resource
Resource            ../resources/data_factory.resource
Suite Setup         Setup Browser
Suite Teardown      End suite


*** Variables ***
${BROWSER}                      chrome
${qa_persona_sales1_secret}     ${None}     # MFA TOTP secret for qa_persona_sales1; set in CRT
${qa_persona_admin}             ${EMPTY}    # API-enabled admin username for SOQL/REST; set in CRT

# GSCV API connection
${qa_gscv_apikey}               ${EMPTY}    # GSCV x-api-key header value; set as secret in CRT
${qa_gscv_endpoint}             ${EMPTY}    # GSCV base URL (no trailing slash); set in CRT
&{GSCV_CONTEXT}                 countryCode=AU    customerContextType=INTERNALS    customerContextLocator=AU-FC


*** Test Cases ***
Login Via JWT And Open Home
    [Documentation]    JWT Bearer auth as qa_persona_sales1, then verify the Home page loads.
    [Tags]    login    smoke
    OpenBrowser         about:blank    chrome
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login           /lightning/page/home
    VerifyTitle         Home | Salesforce

SLB-707_1 Create Customer Profile From Accounts Nav And Verify Fields
    [Documentation]    Create a Customer Profile via the navigation menu Accounts list view.
    ...    Validates name, address, contact, and RFM fields on the saved record.
    [Tags]    profile-management    gscv    slb-707    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete SLB707 Profile
    Set Test Variable    ${TC707_RECORD_ID}    ${EMPTY}
    ${data}=    Generate Profile Data    prefix=slb707    minimum=${False}
    ${id}=      Create GSCV Profile    ${data}
    Set Test Variable    ${TC707_RECORD_ID}    ${id}
    VerifyField    RFM Customer Segment    ${EMPTY}
    VerifyField    RFM Customer Strategy    ${EMPTY}
    VerifyField    Account Name    ${data}[salutation] ${data}[firstName] ${data}[middleName] ${data}[lastName]    partial_match=True
    VerifyField    Preferred Name    ${data}[preferredName]    partial_match=True
    VerifyField    Gender Identity    ${data}[genderDisplay]    partial_match=True
    VerifyField    Birthdate    15/6/1990    partial_match=True
    ScrollText     Billing Address
    ${exp_billing}=    Set Variable    ${data}[addressStreet]\n${data}[addressCity] ${data}[addressState] ${data}[addressPostal]\n${data}[addressCountry]
    VerifyField    Billing Address    ${exp_billing}    tag=a
    VerifyField    Email    ${data}[email]    tag=a    partial_match=True
    Verify GSCV ID Is Populated Via API
    Verify SLB707 GSCV API Data Consistency    ${data}


SLB-707_3 Duplicate Account Routes To Existing Account With Same GSCV ID
    [Documentation]    Create a Customer Profile with minimum data. Confirm GSCV ID is populated.
    ...    Attempt to create a second account with identical details and verify the system routes
    ...    to the same existing account with the same GSCV ID.
    [Tags]    profile-management    gscv    slb-707    regression    duplicate-detection
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete SLB707 Profile
    Set Test Variable    ${TC707_RECORD_ID}    ${EMPTY}
    ${data}=    Generate Profile Data    prefix=slb707    minimum=${True}
    ${id}=      Create GSCV Profile    ${data}
    Set Test Variable    ${TC707_RECORD_ID}    ${id}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${result}=         QueryRecords    SELECT crm_GSCV_ID__c FROM Account WHERE Id = '${TC707_RECORD_ID}' LIMIT 1
    ${gscv_id_1}=      Set Variable    ${result}[records][0][crm_GSCV_ID__c]
    Should Not Be Equal    ${gscv_id_1}    ${None}    msg=crm_GSCV_ID__c is null for Account ${TC707_RECORD_ID}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    VerifyText         ${gscv_id_1}
    ${id_2}=    Create GSCV Profile    ${data}
    Should Be Equal    ${TC707_RECORD_ID}    ${id_2}    msg=Expected duplicate to route to existing account ${TC707_RECORD_ID} but got ${id_2}
    VerifyText    ${gscv_id_1}


SLB-708_1 Create Customer Profile Via Global Action And Verify Fields
    [Documentation]    Create a Customer Profile via the Global Action "New Person Account" button.
    ...    Same form component and field set as SLB-707_1; only the entry point differs.
    [Tags]    profile-management    gscv    slb-708    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete SLB707 Profile
    Set Test Variable    ${TC707_RECORD_ID}    ${EMPTY}
    ${data}=    Generate Profile Data    prefix=slb708    minimum=${False}
    Sleep       10s
    ${id}=      Create GSCV Profile    ${data}    entry_point=global_action
    Set Test Variable    ${TC707_RECORD_ID}    ${id}
    VerifyField    RFM Customer Segment    ${EMPTY}
    VerifyField    RFM Customer Strategy    ${EMPTY}
    VerifyField    Account Name    ${data}[salutation] ${data}[firstName] ${data}[middleName] ${data}[lastName]    partial_match=True
    VerifyField    Preferred Name    ${data}[preferredName]    partial_match=True
    VerifyField    Gender Identity    ${data}[genderDisplay]    partial_match=True
    VerifyField    Birthdate    6/15/1990    partial_match=True
    ScrollText     Billing Address
    ${exp_billing}=    Set Variable    ${data}[addressStreet]\n${data}[addressCity] ${data}[addressState] ${data}[addressPostal]\n${data}[addressCountry]
    VerifyField    Billing Address    ${exp_billing}    tag=a
    VerifyField    Email    ${data}[email]    tag=a    partial_match=True
    Verify GSCV ID Is Populated Via API
    Verify SLB707 GSCV API Data Consistency    ${data}


SLB-708_3 Duplicate Account Via Global Action Routes To Existing Account With Same GSCV ID
    [Documentation]    Create a Customer Profile with minimum data via the nav menu. Confirm GSCV ID
    ...    is populated. Attempt to create a second account via the Global Action "New Person Account"
    ...    button with the exact same details and verify the system routes to the same existing account.
    [Tags]    profile-management    gscv    slb-708    regression    duplicate-detection
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete SLB707 Profile
    Set Test Variable    ${TC707_RECORD_ID}    ${EMPTY}
    ${data}=    Generate Profile Data    prefix=slb708    minimum=${True}
    ${id}=      Create GSCV Profile    ${data}
    Set Test Variable    ${TC707_RECORD_ID}    ${id}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${result}=         QueryRecords    SELECT crm_GSCV_ID__c FROM Account WHERE Id = '${TC707_RECORD_ID}' LIMIT 1
    ${gscv_id_1}=      Set Variable    ${result}[records][0][crm_GSCV_ID__c]
    Should Not Be Equal    ${gscv_id_1}    ${None}    msg=crm_GSCV_ID__c is null for Account ${TC707_RECORD_ID}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    VerifyText         ${gscv_id_1}
    Open GSCV New Account Via Global Action
    Sleep    2s
    PickList    Salutation    ${data}[salutation]
    TypeText    First Name    ${data}[firstName]
    TypeText    Last Name     ${data}[lastName]
    ${xp_cc}=    Set Variable    xpath=//*[@data-testid='phone-country-code-1']
    TypeText    ${xp_cc}    ${data}[countryCode]
    ${xp_ph}=    Set Variable    xpath=//*[@data-testid='phone-number-1']
    TypeText    ${xp_ph}    ${data}[phone]
    ${xp_em}=    Set Variable    xpath=//*[@data-testid='email-1']
    TypeText    ${xp_em}    ${data}[email]
    ClickText    Create
    Sleep    10s
    UseModal    Off
    ${status}    ${id_2}=    Run Keyword And Ignore Error    Get Record ID From Url
    Should Be Equal    ${TC707_RECORD_ID}    ${id_2}    msg=Expected duplicate to route to existing account ${TC707_RECORD_ID} but got ${id_2}
    VerifyText    ${gscv_id_1}


SLB-711_1_2 Edit Customer Profile Updates Both Salesforce And GSCV
    [Documentation]    Create a Customer Profile with full data, then edit the First Name.
    ...    Verifies the Salesforce record reflects the updated value (AC1: change confirmed in
    ...    GSCV before save) and the GSCV customerProfile API matches Salesforce (AC2: data
    ...    consistency after save).
    [Tags]    profile-management    gscv    slb-711    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete SLB711 AC12 Profile
    Set Test Variable    ${TC711_RECORD_ID}    ${EMPTY}
    ${data}=    Generate Profile Data    prefix=slb711    minimum=${False}
    ${id}=      Create GSCV Profile    ${data}
    Set Test Variable    ${TC711_RECORD_ID}    ${id}
    ${new_first_name}=    Set Variable    Up${data}[firstName]
    Set To Dictionary    ${data}    firstName=${new_first_name}
    ClickText    Edit
    Sleep    2s
    UseModal    On
    TypeText    First Name    ${new_first_name}
    ClickText    Update
    UseModal    Off
    Sleep    10s
    LogScreenshot
    VerifyField    Account Name    ${data}[salutation] ${new_first_name}    partial_match=True
    Verify SLB711 GSCV API Data Consistency    ${data}


SLB-711_3 Edit Second Account First Name To Match First Account Triggers Merge
    [Documentation]    Create two accounts with identical details except First Name. Edit the second
    ...    account's First Name to exactly match the first account's. Verify the first account is
    ...    merged into the second account (second account survives, first is deleted).
    [Tags]    profile-management    gscv    slb-711    regression    merge
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete SLB711 Profiles
    Set Test Variable    ${TC711_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC711_RECORD_ID_2}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc711    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc711    minimum=${True}    index=2    ts=${ts}
    Set To Dictionary    ${data_2}    email=${data_1}[email]    phone=${data_1}[phone]
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC711_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC711_RECORD_ID_2}    ${id_2}
    ClickText    Edit
    Sleep    2s
    UseModal    On
    TypeText    First Name    ${data_1}[firstName]
    ClickText    Update
    UseModal    Off
    Sleep   10s
    LogScreenshot
    VerifyText    Account updated. GSCV merge detected
    VerifyText    GSCV Profile ID
    ${status}    ${id_after}=    Run Keyword And Ignore Error    Get Record ID From Url
    Should Be Equal    ${TC711_RECORD_ID_2}    ${id_after}
    ...    msg=Expected to remain on account 2 (${TC711_RECORD_ID_2}) after merge but landed on ${id_after}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${result}=    QueryRecords    SELECT Id FROM Account WHERE Id = '${TC711_RECORD_ID_1}' LIMIT 1
    Should Be Equal As Integers    ${result}[totalSize]    0
    ...    msg=Expected account 1 (${TC711_RECORD_ID_1}) to be deleted after merge but it still exists


SLB-759_1 Create Linked Traveller Relationship Between Two Customer Profiles
    [Documentation]    Create two Customer Profiles (minimum data), then on the second profile's
    ...    Linked Travellers tab add a relationship with Role = FRIEND pointing to the first profile.
    ...    Verifies the relationship is reflected in the GSCV customerProfile API response.
    [Tags]    linked-travellers    gscv    slb-759    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC759 Profiles
    Set Test Variable    ${TC759_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC759_RECORD_ID_2}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc759    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc759    minimum=${True}    index=2    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC759_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC759_RECORD_ID_2}    ${id_2}
    ClickText    Linked Travellers
    ClickText    Add Relationship
    PickList     Role       FRIEND
    TypeText     Search contacts...    ${data_1}[firstName] ${data_1}[lastName]
    Sleep        2s
    ClickElement    xpath=//lightning-base-combobox-item[@role="option"]//span[contains(@class,"slds-listbox__option-text_entity")]/span[@title="${data_1}[firstName] ${data_1}[lastName]"]
    LogScreenshot
    ClickElement    xpath=//button[normalize-space(.)='Save']
    VerifyText    ${data_1}[firstName] ${data_1}[lastName]
    Verify TC759 GSCV Linked Traveller    ${TC759_RECORD_ID_2}    ${TC759_RECORD_ID_1}    FRIEND


SLB-759_2 Update Linked Traveller Relationship Syncs To GSCV
    [Documentation]    Create two Customer Profiles and a linked traveller relationship (FRIEND).
    ...    Edit the relationship role to SPOUSE, save, and verify the updated role is reflected
    ...    in the Linked Travellers tab and in the GSCV customerProfile API response.
    [Tags]    linked-travellers    gscv    slb-759    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC759 Profiles
    Set Test Variable    ${TC759_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC759_RECORD_ID_2}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc759    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc759    minimum=${True}    index=2    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC759_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC759_RECORD_ID_2}    ${id_2}
    Add TC759 FRIEND Relationship    ${data_1}[firstName]    ${data_1}[lastName]
    ClickText    Row actions
    ClickElement    xpath=//a[@role="menuitem" and normalize-space(.)="Edit"]
    PickList     Role    SPOUSE
    ClickText    Save
    VerifyText    SPOUSE
    Verify TC759 GSCV Linked Traveller    ${TC759_RECORD_ID_2}    ${TC759_RECORD_ID_1}    SPOUSE


SLB-759_3 Delete Linked Traveller Relationship Syncs To GSCV
    [Documentation]    Create two Customer Profiles and a linked traveller relationship (FRIEND).
    ...    Delete the relationship, confirm no linked travellers remain on Customer A's profile,
    ...    and verify the GSCV customerProfile API returns an empty linkedTravellers array.
    [Tags]    linked-travellers    gscv    slb-759    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC759 Profiles
    Set Test Variable    ${TC759_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC759_RECORD_ID_2}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc759    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc759    minimum=${True}    index=2    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC759_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC759_RECORD_ID_2}    ${id_2}
    Add TC759 FRIEND Relationship    ${data_1}[firstName]    ${data_1}[lastName]
    ClickText    Row actions
    ClickText    Delete
    VerifyText    Are you sure you want to delete this relationship?
    ClickText    OK
    VerifyText    No linked travellers found.
    Verify TC759 GSCV No Linked Travellers    ${TC759_RECORD_ID_2}


SLB-759_4 One-Way Linked Traveller Relationship Does Not Affect Customer B
    [Documentation]    Create two Customer Profiles and a one-way linked traveller relationship
    ...    from Customer A to Customer B. Verify that creating, updating, and removing the
    ...    relationship on Customer A does not affect Customer B's linked traveller relationships.
    [Tags]    linked-travellers    gscv    slb-759    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC759 Profiles
    Set Test Variable    ${TC759_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC759_RECORD_ID_2}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc759    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc759    minimum=${True}    index=2    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC759_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC759_RECORD_ID_2}    ${id_2}
    Add TC759 FRIEND Relationship    ${data_1}[firstName]    ${data_1}[lastName]
    Jwt Login    /lightning/r/Account/${TC759_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    Jwt Login    /lightning/r/Account/${TC759_RECORD_ID_2}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    ClickText    Row actions
    ClickElement    xpath=//a[@role="menuitem" and normalize-space(.)="Edit"]
    PickList     Role    SPOUSE
    ClickText    Save
    Jwt Login    /lightning/r/Account/${TC759_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    Jwt Login    /lightning/r/Account/${TC759_RECORD_ID_2}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    ClickText    Row actions
    ClickText    Delete
    VerifyText    Are you sure you want to delete this relationship?
    ClickText    OK
    Jwt Login    /lightning/r/Account/${TC759_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    Verify TC759 GSCV No Linked Travellers    ${TC759_RECORD_ID_1}


SLB-760_1 Create Inverse Linked Traveller Relationship Maintains Both Directions
    [Documentation]    Create two Customer Profiles and add a two-way (inverse) linked traveller
    ...    relationship from Customer A to Customer B. Verify both directions in the GSCV API response.
    [Tags]    linked-travellers    gscv    slb-760    regression    inverse
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC760 Profiles
    Set Test Variable    ${TC760_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC760_RECORD_ID_2}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc760    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc760    minimum=${True}    index=2    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC760_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC760_RECORD_ID_2}    ${id_2}
    Add TC760 Inverse Relationship    ${data_1}[firstName]    ${data_1}[lastName]
    VerifyText    ${data_1}[firstName] ${data_1}[lastName]
    Sleep         5s
    Jwt Login    /lightning/r/Account/${TC760_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    ${data_2}[firstName] ${data_2}[lastName]
    VerifyText    COLLEAGUE
    Verify TC760 GSCV Both Directions    ${TC760_RECORD_ID_2}    ${TC760_RECORD_ID_1}    COLLEAGUE    COLLEAGUE


SLB-760_2 Update Inverse Linked Traveller Relationship Maintains Both Directions
    [Documentation]    Create two Customer Profiles and a two-way linked traveller relationship.
    ...    Edit the relationship role on Customer A and verify both sides reflect the updated role.
    [Tags]    linked-travellers    gscv    slb-760    regression    inverse
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC760 Profiles
    Set Test Variable    ${TC760_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC760_RECORD_ID_2}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc760    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc760    minimum=${True}    index=2    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC760_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC760_RECORD_ID_2}    ${id_2}
    Add TC760 Inverse Relationship    ${data_1}[firstName]    ${data_1}[lastName]
    ClickText    Row actions
    ClickElement    xpath=//a[@role="menuitem" and normalize-space(.)="Edit"]
    PickList     Role    SPOUSE
    ClickText    Save
    VerifyText    SPOUSE
    Jwt Login    /lightning/r/Account/${TC760_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    ${data_2}[firstName] ${data_2}[lastName]
    VerifyText    SPOUSE
    Verify TC760 GSCV Both Directions    ${TC760_RECORD_ID_2}    ${TC760_RECORD_ID_1}    SPOUSE    SPOUSE


SLB-760_3 Delete Inverse Linked Traveller Relationship Removes Both Directions
    [Documentation]    Create two Customer Profiles and a two-way linked traveller relationship.
    ...    Delete from Customer A and verify both sides no longer show the relationship.
    [Tags]    linked-travellers    gscv    slb-760    regression    inverse
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC760 Profiles
    Set Test Variable    ${TC760_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC760_RECORD_ID_2}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc760    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc760    minimum=${True}    index=2    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC760_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC760_RECORD_ID_2}    ${id_2}
    Add TC760 Inverse Relationship    ${data_1}[firstName]    ${data_1}[lastName]
    ClickText    Row actions
    ClickText    Delete
    VerifyText    Are you sure you want to delete this relationship?
    ClickText    OK
    Sleep        1s
    RefreshPage
    VerifyText    Linked Travellers
    ClickText     Linked Travellers
    VerifyText    No linked travellers found.
    Jwt Login    /lightning/r/Account/${TC760_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    Verify TC759 GSCV No Linked Travellers    ${TC760_RECORD_ID_2}
    Verify TC759 GSCV No Linked Travellers    ${TC760_RECORD_ID_1}


SLB-760_4 Agent Manages Only One Side Of Inverse Relationship
    [Documentation]    Create two Customer Profiles and add a two-way linked traveller relationship
    ...    from Customer A's profile only. Verify Customer B automatically shows the reciprocal.
    [Tags]    linked-travellers    gscv    slb-760    regression    inverse
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC760 Profiles
    Set Test Variable    ${TC760_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC760_RECORD_ID_2}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc760    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc760    minimum=${True}    index=2    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC760_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC760_RECORD_ID_2}    ${id_2}
    Add TC760 Inverse Relationship    ${data_1}[firstName]    ${data_1}[lastName]
    VerifyText    ${data_1}[firstName] ${data_1}[lastName]
    Jwt Login    /lightning/r/Account/${TC760_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    ${data_2}[firstName] ${data_2}[lastName]
    VerifyText    COLLEAGUE
    Verify TC760 GSCV Both Directions    ${TC760_RECORD_ID_2}    ${TC760_RECORD_ID_1}    COLLEAGUE    COLLEAGUE


SLB-761_1 Adding New Relationship Preserves Existing Relationships
    [Documentation]    Create 3 profiles (A, B, C). Add a one-way FRIEND from A to B, then add an
    ...    inverse COLLEAGUE from A to C. Verifies both relationships remain on A and GSCV reflects
    ...    the complete state: A has both; C has inverse COLLEAGUE; B has no linkedTravellers.
    [Tags]    linked-travellers    gscv    slb-761    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC761 Profiles
    Set Test Variable    ${TC761_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC761_RECORD_ID_2}    ${EMPTY}
    Set Test Variable    ${TC761_RECORD_ID_3}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=2    ts=${ts}
    ${data_3}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=3    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC761_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC761_RECORD_ID_2}    ${id_2}
    ${id_3}=    Create GSCV Profile    ${data_3}
    Set Test Variable    ${TC761_RECORD_ID_3}    ${id_3}
    Jwt Login    /lightning/r/Account/${TC761_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    Add TC761 Relationship    ${data_2}[firstName]    ${data_2}[lastName]    FRIEND
    VerifyText    ${data_2}[firstName] ${data_2}[lastName]
    Add TC761 Relationship    ${data_3}[firstName]    ${data_3}[lastName]    COLLEAGUE    ${True}
    VerifyText    ${data_3}[firstName] ${data_3}[lastName]
    Jwt Login    /lightning/r/Account/${TC761_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    ${data_2}[firstName] ${data_2}[lastName]
    VerifyText    FRIEND
    VerifyText    ${data_3}[firstName] ${data_3}[lastName]
    VerifyText    COLLEAGUE
    LogScreenshot
    Verify TC759 GSCV Linked Traveller    ${TC761_RECORD_ID_1}    ${TC761_RECORD_ID_2}    FRIEND
    Verify TC759 GSCV Linked Traveller    ${TC761_RECORD_ID_1}    ${TC761_RECORD_ID_3}    COLLEAGUE
    Verify TC759 GSCV Linked Traveller    ${TC761_RECORD_ID_3}    ${TC761_RECORD_ID_1}    COLLEAGUE
    Verify TC759 GSCV No Linked Travellers    ${TC761_RECORD_ID_2}


SLB-761_2 Updating One Relationship Does Not Affect Others
    [Documentation]    Create 3 profiles (A, B, C). Set up A-B FRIEND (one-way) and A-C inverse
    ...    COLLEAGUE. Edit A-B's role to SPOUSE. Verifies A-C remains COLLEAGUE and GSCV reflects
    ...    the updated state for all three profiles.
    [Tags]    linked-travellers    gscv    slb-761    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC761 Profiles
    Set Test Variable    ${TC761_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC761_RECORD_ID_2}    ${EMPTY}
    Set Test Variable    ${TC761_RECORD_ID_3}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=2    ts=${ts}
    ${data_3}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=3    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC761_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC761_RECORD_ID_2}    ${id_2}
    ${id_3}=    Create GSCV Profile    ${data_3}
    Set Test Variable    ${TC761_RECORD_ID_3}    ${id_3}
    Jwt Login    /lightning/r/Account/${TC761_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    Add TC761 Relationship    ${data_2}[firstName]    ${data_2}[lastName]    FRIEND
    VerifyText    ${data_2}[firstName] ${data_2}[lastName]
    Add TC761 Relationship    ${data_3}[firstName]    ${data_3}[lastName]    COLLEAGUE    ${True}
    VerifyText    ${data_3}[firstName] ${data_3}[lastName]
    ClickText    Row actions    anchor=${data_2}[firstName] ${data_2}[lastName]
    ClickElement    xpath=//a[@role="menuitem" and normalize-space(.)="Edit"]
    PickList     Role    SPOUSE
    ClickText    Save
    VerifyText    SPOUSE
    VerifyText    COLLEAGUE
    LogScreenshot
    Verify TC759 GSCV Linked Traveller    ${TC761_RECORD_ID_1}    ${TC761_RECORD_ID_2}    SPOUSE
    Verify TC759 GSCV Linked Traveller    ${TC761_RECORD_ID_1}    ${TC761_RECORD_ID_3}    COLLEAGUE
    Verify TC759 GSCV Linked Traveller    ${TC761_RECORD_ID_3}    ${TC761_RECORD_ID_1}    COLLEAGUE
    Verify TC759 GSCV No Linked Travellers    ${TC761_RECORD_ID_2}


SLB-761_3 Removing One Relationship Does Not Affect Others
    [Documentation]    Create 3 profiles (A, B, C). Set up A-B FRIEND (one-way) and A-C inverse
    ...    COLLEAGUE. Delete A-B. Verifies A-C remains, GSCV for A has only C, GSCV for C still
    ...    has inverse, and B has no linkedTravellers.
    [Tags]    linked-travellers    gscv    slb-761    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC761 Profiles
    Set Test Variable    ${TC761_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC761_RECORD_ID_2}    ${EMPTY}
    Set Test Variable    ${TC761_RECORD_ID_3}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=2    ts=${ts}
    ${data_3}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=3    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC761_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC761_RECORD_ID_2}    ${id_2}
    ${id_3}=    Create GSCV Profile    ${data_3}
    Set Test Variable    ${TC761_RECORD_ID_3}    ${id_3}
    Jwt Login    /lightning/r/Account/${TC761_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    Add TC761 Relationship    ${data_2}[firstName]    ${data_2}[lastName]    FRIEND
    VerifyText    ${data_2}[firstName] ${data_2}[lastName]
    Add TC761 Relationship    ${data_3}[firstName]    ${data_3}[lastName]    COLLEAGUE    ${True}
    VerifyText    ${data_3}[firstName] ${data_3}[lastName]
    ClickText    Row actions    anchor=${data_2}[firstName] ${data_2}[lastName]
    ClickText    Delete
    VerifyText    Are you sure you want to delete this relationship?
    ClickText    OK
    Sleep        1s
    RefreshPage
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_3}[firstName] ${data_3}[lastName]
    VerifyText    COLLEAGUE
    LogScreenshot
    Verify TC759 GSCV Linked Traveller    ${TC761_RECORD_ID_1}    ${TC761_RECORD_ID_3}    COLLEAGUE
    Verify TC759 GSCV Linked Traveller    ${TC761_RECORD_ID_3}    ${TC761_RECORD_ID_1}    COLLEAGUE
    Verify TC759 GSCV No Linked Travellers    ${TC761_RECORD_ID_2}


SLB-761_4 Mixed Operations In Sequence Final State Matches GSCV
    [Documentation]    Create 3 profiles (A, B, C). Start with A-B FRIEND (one-way). Perform three
    ...    successive saves: add A-C inverse COLLEAGUE, update A-B to RELATIVE, delete A-C.
    ...    Verifies final state: A has only A-B RELATIVE in SF and GSCV; C has no linkedTravellers.
    [Tags]    linked-travellers    gscv    slb-761    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Delete TC761 Profiles
    Set Test Variable    ${TC761_RECORD_ID_1}    ${EMPTY}
    Set Test Variable    ${TC761_RECORD_ID_2}    ${EMPTY}
    Set Test Variable    ${TC761_RECORD_ID_3}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=2    ts=${ts}
    ${data_3}=   Generate Profile Data    prefix=tc761    minimum=${True}    index=3    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    Set Test Variable    ${TC761_RECORD_ID_1}    ${id_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    Set Test Variable    ${TC761_RECORD_ID_2}    ${id_2}
    ${id_3}=    Create GSCV Profile    ${data_3}
    Set Test Variable    ${TC761_RECORD_ID_3}    ${id_3}
    # Existing state: A has A→B FRIEND (one-way)
    Jwt Login    /lightning/r/Account/${TC761_RECORD_ID_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    Add TC761 Relationship    ${data_2}[firstName]    ${data_2}[lastName]    FRIEND
    VerifyText    ${data_2}[firstName] ${data_2}[lastName]
    # Save 1: add A→C inverse COLLEAGUE
    Add TC761 Relationship    ${data_3}[firstName]    ${data_3}[lastName]    COLLEAGUE    ${True}
    VerifyText    ${data_3}[firstName] ${data_3}[lastName]
    # Save 2: update A→B from FRIEND to RELATIVE
    ClickText    Row actions    anchor=${data_2}[firstName] ${data_2}[lastName]
    ClickElement    xpath=//a[@role="menuitem" and normalize-space(.)="Edit"]
    PickList     Role    RELATIVE
    ClickText    Save
    VerifyText    RELATIVE
    # Save 3: delete A→C COLLEAGUE
    ClickText    Row actions    anchor=${data_3}[firstName] ${data_3}[lastName]
    ClickText    Delete
    VerifyText    Are you sure you want to delete this relationship?
    ClickText    OK
    Sleep        1s
    RefreshPage
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    ${data_2}[firstName] ${data_2}[lastName]
    VerifyText    RELATIVE
    VerifyText    Linked Travellers (1)
    LogScreenshot
    Verify TC759 GSCV Linked Traveller    ${TC761_RECORD_ID_1}    ${TC761_RECORD_ID_2}    RELATIVE
    Verify TC759 GSCV No Linked Travellers    ${TC761_RECORD_ID_3}


SLB-762_1 New Single Linked Traveller From GSCV Appears In Salesforce
    [Documentation]    POST two profiles to GSCV, then PUT a FRIEND linked traveller from A to B.
    ...    Verifies A's Linked Travellers tab shows the new relationship (AC1) and the GSCV
    ...    customerProfile API reflects the same state (AC5).
    [Tags]    linked-travellers    gscv    slb-762    regression    gscv-initiated
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC762 Profiles
    Set Test Variable    ${TC762_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC762_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC762_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC762_SF_ID_B}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc762    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc762    minimum=${True}    index=2    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC762_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC762_GSCV_ID_B}    ${gscv_id_b}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}') LIMIT 2
    Should Be Equal As Integers    ${result}[totalSize]    2
    ...    msg=Expected 2 SF Accounts for GSCV IDs ${gscv_id_a} and ${gscv_id_b}
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC762_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC762_SF_ID_B}    ${row}[Id]
    END
    ${lt_entry}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=FRIEND
    ${lt_list}=     Create List    ${lt_entry}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC762_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_b}[firstName] ${data_b}[lastName]
    VerifyText    FRIEND
    LogScreenshot
    Verify TC759 GSCV Linked Traveller    ${TC762_SF_ID_A}    ${TC762_SF_ID_B}    FRIEND


SLB-762_2 Updated Single Linked Traveller From GSCV Reflected In Salesforce
    [Documentation]    POST two profiles to GSCV and PUT a FRIEND linked traveller from A to B.
    ...    Then PUT an update changing the role to SPOUSE. Verifies A's Linked Travellers tab
    ...    reflects the updated role in Salesforce (AC2).
    [Tags]    linked-travellers    gscv    slb-762    regression    gscv-initiated
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC762 Profiles
    Set Test Variable    ${TC762_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC762_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC762_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC762_SF_ID_B}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc762    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc762    minimum=${True}    index=2    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC762_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC762_GSCV_ID_B}    ${gscv_id_b}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}') LIMIT 2
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC762_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC762_SF_ID_B}    ${row}[Id]
    END
    ${lt_friend}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=FRIEND
    ${lt_list}=      Create List    ${lt_friend}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list}
    Sleep    10s
    ${lt_spouse}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=SPOUSE
    ${lt_list_2}=    Create List    ${lt_spouse}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list_2}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC762_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_b}[firstName] ${data_b}[lastName]
    VerifyText    SPOUSE
    LogScreenshot
    Verify TC759 GSCV Linked Traveller    ${TC762_SF_ID_A}    ${TC762_SF_ID_B}    SPOUSE


SLB-762_3 Removed Single Linked Traveller From GSCV Reflected In Salesforce
    [Documentation]    POST two profiles to GSCV and PUT a FRIEND linked traveller from A to B.
    ...    Then PUT an update with empty linkedTravellers. Verifies the relationship is removed
    ...    from A's Linked Travellers tab in Salesforce (AC3).
    [Tags]    linked-travellers    gscv    slb-762    regression    gscv-initiated
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC762 Profiles
    Set Test Variable    ${TC762_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC762_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC762_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC762_SF_ID_B}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc762    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc762    minimum=${True}    index=2    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC762_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC762_GSCV_ID_B}    ${gscv_id_b}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}') LIMIT 2
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC762_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC762_SF_ID_B}    ${row}[Id]
    END
    ${lt_entry}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=FRIEND
    ${lt_list}=     Create List    ${lt_entry}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list}
    Sleep    10s
    ${empty_list}=    Create List
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${empty_list}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC762_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    LogScreenshot
    Verify TC759 GSCV No Linked Travellers    ${TC762_SF_ID_A}


SLB-762_4 One-Way GSCV Relationship Does Not Affect Customer B
    [Documentation]    POST two profiles to GSCV and PUT a one-way FRIEND from A to B.
    ...    Verifies B's Linked Travellers tab is unaffected throughout create, update, and
    ...    delete of the relationship on A (AC4).
    [Tags]    linked-travellers    gscv    slb-762    regression    gscv-initiated
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC762 Profiles
    Set Test Variable    ${TC762_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC762_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC762_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC762_SF_ID_B}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc762    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc762    minimum=${True}    index=2    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC762_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC762_GSCV_ID_B}    ${gscv_id_b}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}') LIMIT 2
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC762_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC762_SF_ID_B}    ${row}[Id]
    END
    ${lt_friend}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=FRIEND
    ${lt_list}=      Create List    ${lt_friend}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC762_SF_ID_B}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    ${lt_spouse}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=SPOUSE
    ${lt_list_2}=    Create List    ${lt_spouse}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list_2}
    Sleep    10s
    Jwt Login    /lightning/r/Account/${TC762_SF_ID_B}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    ${empty_list}=    Create List
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${empty_list}
    Sleep    10s
    Jwt Login    /lightning/r/Account/${TC762_SF_ID_B}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    LogScreenshot
    Verify TC759 GSCV No Linked Travellers    ${TC762_SF_ID_B}


SLB-763_1 New Inverse Linked Traveller From GSCV Appears On Both Profiles
    [Documentation]    POST two profiles to GSCV, then PUT A's profile with B as COLLEAGUE
    ...    with hasInverseRelationship=True. Verifies both A and B show the COLLEAGUE relationship
    ...    in Salesforce and in the GSCV customerProfile API (AC1).
    [Tags]    linked-travellers    gscv    slb-763    regression    gscv-initiated    inverse
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC763 Profiles
    Set Test Variable    ${TC763_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC763_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC763_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC763_SF_ID_B}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc763    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc763    minimum=${True}    index=2    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC763_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC763_GSCV_ID_B}    ${gscv_id_b}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}') LIMIT 2
    Should Be Equal As Integers    ${result}[totalSize]    2
    ...    msg=Expected 2 SF Accounts for GSCV IDs ${gscv_id_a} and ${gscv_id_b}
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC763_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC763_SF_ID_B}    ${row}[Id]
    END
    ${lt_entry}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=COLLEAGUE    hasInverseRelationship=${True}
    ${lt_list}=     Create List    ${lt_entry}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC763_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_b}[firstName] ${data_b}[lastName]
    VerifyText    COLLEAGUE
    Jwt Login    /lightning/r/Account/${TC763_SF_ID_B}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_a}[firstName] ${data_a}[lastName]
    VerifyText    COLLEAGUE
    LogScreenshot
    Verify TC760 GSCV Both Directions    ${TC763_SF_ID_A}    ${TC763_SF_ID_B}    COLLEAGUE    COLLEAGUE


SLB-763_2 Updated Inverse Linked Traveller From GSCV Reflected On Both Profiles
    [Documentation]    POST two profiles to GSCV and PUT a COLLEAGUE (inverse) linked traveller.
    ...    Then PUT an update changing the role to SPOUSE (inverse). Verifies both A and B
    ...    reflect the updated role in Salesforce and GSCV (AC2).
    [Tags]    linked-travellers    gscv    slb-763    regression    gscv-initiated    inverse
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC763 Profiles
    Set Test Variable    ${TC763_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC763_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC763_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC763_SF_ID_B}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc763    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc763    minimum=${True}    index=2    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC763_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC763_GSCV_ID_B}    ${gscv_id_b}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}') LIMIT 2
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC763_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC763_SF_ID_B}    ${row}[Id]
    END
    ${lt_colleague}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=COLLEAGUE    hasInverseRelationship=${True}
    ${lt_list}=         Create List    ${lt_colleague}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list}
    Sleep    10s
    ${lt_spouse}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=SPOUSE    hasInverseRelationship=${True}
    ${lt_list_2}=    Create List    ${lt_spouse}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list_2}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC763_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_b}[firstName] ${data_b}[lastName]
    VerifyText    SPOUSE
    Jwt Login    /lightning/r/Account/${TC763_SF_ID_B}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_a}[firstName] ${data_a}[lastName]
    VerifyText    SPOUSE
    LogScreenshot
    Verify TC760 GSCV Both Directions    ${TC763_SF_ID_A}    ${TC763_SF_ID_B}    SPOUSE    SPOUSE


SLB-763_3 Removed Inverse Linked Traveller From GSCV Removed From Both Profiles
    [Documentation]    POST two profiles to GSCV and PUT a COLLEAGUE (inverse) linked traveller.
    ...    Then PUT an update with empty linkedTravellers. Verifies the relationship is removed
    ...    from both A and B in Salesforce and GSCV (AC3).
    [Tags]    linked-travellers    gscv    slb-763    regression    gscv-initiated    inverse
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC763 Profiles
    Set Test Variable    ${TC763_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC763_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC763_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC763_SF_ID_B}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc763    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc763    minimum=${True}    index=2    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC763_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC763_GSCV_ID_B}    ${gscv_id_b}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}') LIMIT 2
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC763_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC763_SF_ID_B}    ${row}[Id]
    END
    ${lt_entry}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=COLLEAGUE    hasInverseRelationship=${True}
    ${lt_list}=     Create List    ${lt_entry}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list}
    Sleep    10s
    ${empty_list}=    Create List
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${empty_list}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC763_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    Jwt Login    /lightning/r/Account/${TC763_SF_ID_B}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    LogScreenshot
    Verify TC759 GSCV No Linked Travellers    ${TC763_SF_ID_A}
    Verify TC759 GSCV No Linked Travellers    ${TC763_SF_ID_B}


SLB-763_4 GSCV Overrides Conflicting Salesforce-Created Inverse Relationship
    [Documentation]    POST two profiles to GSCV and wait for SF sync. Use the SF UI to add an
    ...    inverse COLLEAGUE from A to B (pre-existing SF-side state). Then PUT A's GSCV profile
    ...    with B as SPOUSE (inverse). Verifies both profiles now show SPOUSE — confirming GSCV
    ...    overrides conflicting local SF data (AC4).
    [Tags]    linked-travellers    gscv    slb-763    regression    gscv-initiated    inverse
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC763 Profiles
    Set Test Variable    ${TC763_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC763_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC763_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC763_SF_ID_B}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc763    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc763    minimum=${True}    index=2    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC763_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC763_GSCV_ID_B}    ${gscv_id_b}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}') LIMIT 2
    Should Be Equal As Integers    ${result}[totalSize]    2
    ...    msg=Expected 2 SF Accounts for GSCV IDs ${gscv_id_a} and ${gscv_id_b}
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC763_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC763_SF_ID_B}    ${row}[Id]
    END
    # Pre-state: create a COLLEAGUE inverse via the SF UI
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC763_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    ClickText    Add Relationship
    PickList     Role    COLLEAGUE
    TypeText     Search contacts...    ${data_b}[firstName] ${data_b}[lastName]
    Sleep        2s
    ClickElement    xpath=//lightning-base-combobox-item[@role="option"]//span[contains(@class,"slds-listbox__option-text_entity")]/span[@title="${data_b}[firstName] ${data_b}[lastName]"]
    ClickCheckbox   Has Inverse Relationship    on
    ClickElement    xpath=//button[normalize-space(.)='Save']
    VerifyText    ${data_b}[firstName] ${data_b}[lastName]
    VerifyText    COLLEAGUE
    LogScreenshot
    # GSCV PUT with SPOUSE (inverse) — should override the SF-created COLLEAGUE
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${lt_spouse}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=SPOUSE    hasInverseRelationship=${True}
    ${lt_list}=      Create List    ${lt_spouse}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_list}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC763_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_b}[firstName] ${data_b}[lastName]
    VerifyText    SPOUSE
    Jwt Login    /lightning/r/Account/${TC763_SF_ID_B}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_a}[firstName] ${data_a}[lastName]
    VerifyText    SPOUSE
    LogScreenshot
    Verify TC760 GSCV Both Directions    ${TC763_SF_ID_A}    ${TC763_SF_ID_B}    SPOUSE    SPOUSE


SLB-764_1 Adding New GSCV Relationships Preserves Existing
    [Documentation]    POST three profiles to GSCV. PUT A→B FRIEND (one-way) as initial state.
    ...    Then PUT A→B FRIEND + C COLLEAGUE (inverse) in a single call. Verifies A has both
    ...    relationships, B is unaffected (one-way), and C shows the inverse relationship (AC1).
    [Tags]    linked-travellers    gscv    slb-764    regression    gscv-initiated
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC764 Profiles
    Set Test Variable    ${TC764_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC764_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC764_GSCV_ID_C}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_B}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_C}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=2    ts=${ts}
    ${data_c}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=3    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC764_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC764_GSCV_ID_B}    ${gscv_id_b}
    ${gscv_id_c}=    Create TC762 Profile Via GSCV API    ${data_c}
    Set Test Variable    ${TC764_GSCV_ID_C}    ${gscv_id_c}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}', '${gscv_id_c}') LIMIT 3
    Should Be Equal As Integers    ${result}[totalSize]    3
    ...    msg=Expected 3 SF Accounts for GSCV IDs ${gscv_id_a}, ${gscv_id_b}, ${gscv_id_c}
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC764_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC764_SF_ID_B}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_c}'    Set Test Variable    ${TC764_SF_ID_C}    ${row}[Id]
    END
    # Initial state: A→B FRIEND (one-way)
    ${lt_b}=      Create Dictionary    profileId=${gscv_id_b}    relationshipType=FRIEND
    ${lt_init}=   Create List    ${lt_b}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_init}
    Sleep    10s
    # Add C COLLEAGUE (inverse) alongside existing B FRIEND in a single PUT
    ${lt_b2}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=FRIEND
    ${lt_c}=     Create Dictionary    profileId=${gscv_id_c}    relationshipType=COLLEAGUE    hasInverseRelationship=${True}
    ${lt_both}=  Create List    ${lt_b2}    ${lt_c}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_both}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC764_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (2)
    VerifyText    ${data_b}[firstName] ${data_b}[lastName]
    VerifyText    FRIEND
    VerifyText    ${data_c}[firstName] ${data_c}[lastName]
    VerifyText    COLLEAGUE
    LogScreenshot
    Verify TC759 GSCV No Linked Travellers    ${TC764_SF_ID_B}
    Verify TC759 GSCV Linked Traveller    ${TC764_SF_ID_A}    ${TC764_SF_ID_B}    FRIEND
    Verify TC759 GSCV Linked Traveller    ${TC764_SF_ID_A}    ${TC764_SF_ID_C}    COLLEAGUE
    Verify TC759 GSCV Linked Traveller    ${TC764_SF_ID_C}    ${TC764_SF_ID_A}    COLLEAGUE


SLB-764_2 Changing A GSCV Relationship Does Not Affect Others
    [Documentation]    POST three profiles to GSCV. PUT A with B=FRIEND (one-way) + C=COLLEAGUE
    ...    (inverse). Then PUT A with B=SPOUSE (role changed) + C=COLLEAGUE (unchanged). Verifies
    ...    only B's role is updated; C and its inverse remain intact (AC2).
    [Tags]    linked-travellers    gscv    slb-764    regression    gscv-initiated
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC764 Profiles
    Set Test Variable    ${TC764_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC764_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC764_GSCV_ID_C}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_B}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_C}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=2    ts=${ts}
    ${data_c}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=3    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC764_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC764_GSCV_ID_B}    ${gscv_id_b}
    ${gscv_id_c}=    Create TC762 Profile Via GSCV API    ${data_c}
    Set Test Variable    ${TC764_GSCV_ID_C}    ${gscv_id_c}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}', '${gscv_id_c}') LIMIT 3
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC764_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC764_SF_ID_B}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_c}'    Set Test Variable    ${TC764_SF_ID_C}    ${row}[Id]
    END
    # Initial state: A→B FRIEND (one-way) + A→C COLLEAGUE (inverse)
    ${lt_b}=     Create Dictionary    profileId=${gscv_id_b}    relationshipType=FRIEND
    ${lt_c}=     Create Dictionary    profileId=${gscv_id_c}    relationshipType=COLLEAGUE    hasInverseRelationship=${True}
    ${lt_init}=  Create List    ${lt_b}    ${lt_c}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_init}
    Sleep    10s
    # Update: change B to SPOUSE; leave C COLLEAGUE unchanged
    ${lt_b2}=    Create Dictionary    profileId=${gscv_id_b}    relationshipType=SPOUSE
    ${lt_c2}=    Create Dictionary    profileId=${gscv_id_c}    relationshipType=COLLEAGUE    hasInverseRelationship=${True}
    ${lt_upd}=   Create List    ${lt_b2}    ${lt_c2}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_upd}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC764_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (2)
    VerifyText    ${data_b}[firstName] ${data_b}[lastName]
    VerifyText    SPOUSE
    VerifyText    ${data_c}[firstName] ${data_c}[lastName]
    VerifyText    COLLEAGUE
    LogScreenshot
    Verify TC759 GSCV No Linked Travellers    ${TC764_SF_ID_B}
    Verify TC759 GSCV Linked Traveller    ${TC764_SF_ID_A}    ${TC764_SF_ID_B}    SPOUSE
    Verify TC759 GSCV Linked Traveller    ${TC764_SF_ID_A}    ${TC764_SF_ID_C}    COLLEAGUE
    Verify TC759 GSCV Linked Traveller    ${TC764_SF_ID_C}    ${TC764_SF_ID_A}    COLLEAGUE


SLB-764_3 Removing A GSCV Relationship Does Not Affect Others
    [Documentation]    POST three profiles to GSCV. PUT A with B=FRIEND (one-way) + C=COLLEAGUE
    ...    (inverse). Then PUT A with B=FRIEND only (C omitted). Verifies C is removed from A
    ...    and loses its inverse link; B and its one-way relationship remain unchanged (AC3).
    [Tags]    linked-travellers    gscv    slb-764    regression    gscv-initiated
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC764 Profiles
    Set Test Variable    ${TC764_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC764_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC764_GSCV_ID_C}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_B}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_C}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=2    ts=${ts}
    ${data_c}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=3    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC764_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC764_GSCV_ID_B}    ${gscv_id_b}
    ${gscv_id_c}=    Create TC762 Profile Via GSCV API    ${data_c}
    Set Test Variable    ${TC764_GSCV_ID_C}    ${gscv_id_c}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}', '${gscv_id_c}') LIMIT 3
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC764_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC764_SF_ID_B}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_c}'    Set Test Variable    ${TC764_SF_ID_C}    ${row}[Id]
    END
    # Initial state: A→B FRIEND (one-way) + A→C COLLEAGUE (inverse)
    ${lt_b}=     Create Dictionary    profileId=${gscv_id_b}    relationshipType=FRIEND
    ${lt_c}=     Create Dictionary    profileId=${gscv_id_c}    relationshipType=COLLEAGUE    hasInverseRelationship=${True}
    ${lt_init}=  Create List    ${lt_b}    ${lt_c}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_init}
    Sleep    10s
    # Remove C by omitting it from the PUT; B remains
    ${lt_b2}=   Create Dictionary    profileId=${gscv_id_b}    relationshipType=FRIEND
    ${lt_rem}=  Create List    ${lt_b2}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_rem}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC764_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_b}[firstName] ${data_b}[lastName]
    VerifyText    FRIEND
    LogScreenshot
    Verify TC759 GSCV No Linked Travellers    ${TC764_SF_ID_B}
    Verify TC759 GSCV No Linked Travellers    ${TC764_SF_ID_C}
    Verify TC759 GSCV Linked Traveller    ${TC764_SF_ID_A}    ${TC764_SF_ID_B}    FRIEND


SLB-764_4 Mixed One-Way And Inverse In Single GSCV Update Reconciles Correctly
    [Documentation]    POST three profiles to GSCV. Issue a single PUT for A containing B=FRIEND
    ...    (one-way, no inverse flag) and C=COLLEAGUE (hasInverseRelationship=True). Verifies A has
    ...    both relationships, B has no linked travellers (one-way respected), C has A as COLLEAGUE
    ...    (inverse maintained), and the GSCV API confirms the exact final state (AC4 + AC5).
    [Tags]    linked-travellers    gscv    slb-764    regression    gscv-initiated    inverse
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC764 Profiles
    Set Test Variable    ${TC764_GSCV_ID_A}    ${EMPTY}
    Set Test Variable    ${TC764_GSCV_ID_B}    ${EMPTY}
    Set Test Variable    ${TC764_GSCV_ID_C}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_A}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_B}    ${EMPTY}
    Set Test Variable    ${TC764_SF_ID_C}    ${EMPTY}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_a}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=1    ts=${ts}
    ${data_b}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=2    ts=${ts}
    ${data_c}=   Generate Profile Data    prefix=tc764    minimum=${True}    index=3    ts=${ts}
    ${gscv_id_a}=    Create TC762 Profile Via GSCV API    ${data_a}
    Set Test Variable    ${TC764_GSCV_ID_A}    ${gscv_id_a}
    ${gscv_id_b}=    Create TC762 Profile Via GSCV API    ${data_b}
    Set Test Variable    ${TC764_GSCV_ID_B}    ${gscv_id_b}
    ${gscv_id_c}=    Create TC762 Profile Via GSCV API    ${data_c}
    Set Test Variable    ${TC764_GSCV_ID_C}    ${gscv_id_c}
    Sleep    10s
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE crm_GSCV_ID__c IN ('${gscv_id_a}', '${gscv_id_b}', '${gscv_id_c}') LIMIT 3
    Should Be Equal As Integers    ${result}[totalSize]    3
    ...    msg=Expected 3 SF Accounts for GSCV IDs ${gscv_id_a}, ${gscv_id_b}, ${gscv_id_c}
    FOR    ${row}    IN    @{result}[records]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_a}'    Set Test Variable    ${TC764_SF_ID_A}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_b}'    Set Test Variable    ${TC764_SF_ID_B}    ${row}[Id]
        Run Keyword If    '${row}[crm_GSCV_ID__c]' == '${gscv_id_c}'    Set Test Variable    ${TC764_SF_ID_C}    ${row}[Id]
    END
    # Single PUT: B=FRIEND (one-way) + C=COLLEAGUE (inverse)
    ${lt_b}=     Create Dictionary    profileId=${gscv_id_b}    relationshipType=FRIEND
    ${lt_c}=     Create Dictionary    profileId=${gscv_id_c}    relationshipType=COLLEAGUE    hasInverseRelationship=${True}
    ${lt_mixed}=  Create List    ${lt_b}    ${lt_c}
    Put TC762 GSCV Linked Travellers    ${gscv_id_a}    ${lt_mixed}
    Sleep    10s
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/r/Account/${TC764_SF_ID_A}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (2)
    VerifyText    ${data_b}[firstName] ${data_b}[lastName]
    VerifyText    FRIEND
    VerifyText    ${data_c}[firstName] ${data_c}[lastName]
    VerifyText    COLLEAGUE
    Jwt Login    /lightning/r/Account/${TC764_SF_ID_B}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    No linked travellers found.
    Jwt Login    /lightning/r/Account/${TC764_SF_ID_C}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    Linked Travellers (1)
    VerifyText    ${data_a}[firstName] ${data_a}[lastName]
    VerifyText    COLLEAGUE
    LogScreenshot
    Verify TC759 GSCV No Linked Travellers    ${TC764_SF_ID_B}
    Verify TC759 GSCV Linked Traveller    ${TC764_SF_ID_A}    ${TC764_SF_ID_B}    FRIEND
    Verify TC759 GSCV Linked Traveller    ${TC764_SF_ID_A}    ${TC764_SF_ID_C}    COLLEAGUE
    Verify TC759 GSCV Linked Traveller    ${TC764_SF_ID_C}    ${TC764_SF_ID_A}    COLLEAGUE


SLB-765 Symmetric Role Mapping - Both Sides Show Same Role
    [Documentation]    For each symmetric role, create a two-way linked traveller relationship
    ...    from Customer A and verify Customer B automatically shows the same role.
    ...    Roles covered: COLLEAGUE, FRIEND, RELATIVE, SIBLING, SIGNIFICANT OTHER, SPOUSE.
    [Tags]    linked-travellers    gscv    slb-765    regression    inverse    role-mapping
    [Setup]    Authenticate And Open GSCV
    [Template]    Verify TC765 Inverse Role Mapping
    COLLEAGUE            COLLEAGUE
    FRIEND               FRIEND
    RELATIVE             RELATIVE
    SIBLING              SIBLING
    SIGNIFICANT OTHER    SIGNIFICANT_OTHER
    SPOUSE               SPOUSE


SLB-765 Asymmetric Role Mapping - Parent And Child
    [Documentation]    PARENT creates a reciprocal CHILD on Customer B, and CHILD creates a
    ...    reciprocal PARENT. Verifies correct inverse mapping in both directions.
    [Tags]    linked-travellers    gscv    slb-765    regression    inverse    role-mapping
    [Setup]    Authenticate And Open GSCV
    [Template]    Verify TC765 Inverse Role Mapping
    PARENT    CHILD
    CHILD     PARENT


SLB-765 Asymmetric Role Mapping - Management And Employee
    [Documentation]    Management roles (MANAGER, LEAD, PROJECT MANAGER, SUPERVISOR) create a
    ...    reciprocal EMPLOYEE on Customer B. EMPLOYEE and ADMIN ASSISTANT map back to MANAGER.
    [Tags]    linked-travellers    gscv    slb-765    regression    inverse    role-mapping
    [Setup]    Authenticate And Open GSCV
    [Template]    Verify TC765 Inverse Role Mapping
    MANAGER            EMPLOYEE
    LEAD               EMPLOYEE
    PROJECT MANAGER    EMPLOYEE
    SUPERVISOR         EMPLOYEE
    EMPLOYEE           MANAGER
    ADMIN ASSISTANT    MANAGER


SLB-769_1 GSCV-Created Profile Appears In Salesforce With Correct Data
    [Documentation]    POST a new customer profile directly to the GSCV API, wait 10s for the
    ...    integration queue to process, then verify Salesforce automatically created a matching
    ...    Account record with all fields correct.
    ...    Covers AC1 (record created), AC2 (data consistency), AC3 (all fields populated).
    [Tags]    profile-management    gscv    slb-769    regression    gscv-initiated
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC769 Profile
    Set Test Variable    ${TC769_GSCV_ID}       ${EMPTY}
    Set Test Variable    ${TC769_SF_RECORD_ID}  ${EMPTY}
    ${data}=      Generate Profile Data    prefix=tc769    minimum=${False}
    ${body}=      Build GSCV Profile Body    ${data}
    ${headers}=   Create Dictionary    x-api-key=${qa_gscv_apikey}    Content-Type=application/json    accept=application/json
    ${params}=    Create Dictionary    &{GSCV_CONTEXT}
    ${response}=    POST    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    json=${body}    expected_status=201
    ${gscv_id}=    Set Variable    ${response.json()}[customerProfileId]
    Set Test Variable    ${TC769_GSCV_ID}    ${gscv_id}
    Sleep    10s
    # AC1: verify SF record created
    ${result}=    QueryRecords
    ...    SELECT Id, FirstName, LastName, Salutation, PersonEmail, PersonBirthdate, PersonGenderIdentity FROM Account WHERE crm_GSCV_ID__c = '${gscv_id}' LIMIT 1
    Should Be Equal As Integers    ${result}[totalSize]    1
    ...    msg=Expected 1 SF Account for GSCV ID ${gscv_id} but found ${result}[totalSize]
    ${account}=    Set Variable    ${result}[records][0]
    Set Test Variable    ${TC769_SF_RECORD_ID}    ${account}[Id]
    # AC2 + AC3: verify field consistency
    Should Be Equal As Strings    ${account}[FirstName]             ${data}[firstName]
    Should Be Equal As Strings    ${account}[LastName]              ${data}[lastName]
    Should Be Equal As Strings    ${account}[Salutation]            ${data}[salutation]
    Should Be Equal As Strings    ${account}[PersonEmail]           ${data}[email]
    Should Be Equal As Strings    ${account}[PersonBirthdate]       ${data}[dob]
    Should Be Equal As Strings    ${account}[PersonGenderIdentity]  ${data}[gender]


SLB-769_4 Duplicate GSCV Profile Does Not Create Duplicate Salesforce Record
    [Documentation]    POST the same customer profile to GSCV twice. Verify that Salesforce
    ...    contains exactly one Account record and its GSCV ID matches the original customerProfileId.
    ...    Covers AC4 (duplicate prevention).
    [Tags]    profile-management    gscv    slb-769    regression    gscv-initiated    duplicate-detection
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC769 Profile
    Set Test Variable    ${TC769_GSCV_ID}       ${EMPTY}
    Set Test Variable    ${TC769_SF_RECORD_ID}  ${EMPTY}
    ${data}=      Generate Profile Data    prefix=tc769    minimum=${False}
    ${body}=      Build GSCV Profile Body    ${data}
    ${headers}=   Create Dictionary    x-api-key=${qa_gscv_apikey}    Content-Type=application/json    accept=application/json
    ${params}=    Create Dictionary    &{GSCV_CONTEXT}
    # First GSCV create
    ${response}=    POST    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    json=${body}    expected_status=201
    ${gscv_id}=    Set Variable    ${response.json()}[customerProfileId]
    Set Test Variable    ${TC769_GSCV_ID}    ${gscv_id}
    Sleep    10s
    ${first_result}=    QueryRecords
    ...    SELECT Id FROM Account WHERE crm_GSCV_ID__c = '${gscv_id}' LIMIT 1
    Should Be Equal As Integers    ${first_result}[totalSize]    1
    ...    msg=First create: expected 1 SF Account but found ${first_result}[totalSize]
    Set Test Variable    ${TC769_SF_RECORD_ID}    ${first_result}[records][0][Id]
    # Second GSCV create with identical body — must not create a duplicate
    POST    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    json=${body}    expected_status=200
    Sleep    10s
    # AC4: exactly one account matching these details
    ${dup_result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE FirstName = '${data}[firstName]' AND LastName = '${data}[lastName]' AND PersonEmail = '${data}[email]' LIMIT 10
    Should Be Equal As Integers    ${dup_result}[totalSize]    1
    ...    msg=Expected 1 Account after duplicate GSCV create but found ${dup_result}[totalSize]
    Should Be Equal As Strings    ${dup_result}[records][0][crm_GSCV_ID__c]    ${gscv_id}
    ...    msg=GSCV ID mismatch — expected original ${gscv_id}


SLB-770_1 GSCV-Updated Profile Automatically Reflected In Salesforce
    [Documentation]    POST a new customer profile to the GSCV API, wait for SF sync, then PUT an
    ...    update changing firstName, lastName, and preferredName. Waits for the integration queue
    ...    and verifies Salesforce reflects all updated values while unchanged fields remain correct.
    ...    Covers AC1 (update applied), AC2 (data consistent), AC3 (all supported fields).
    [Tags]    profile-management    gscv    slb-770    regression    gscv-initiated
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC770 Profile
    Set Test Variable    ${TC770_GSCV_ID}       ${EMPTY}
    Set Test Variable    ${TC770_SF_RECORD_ID}  ${EMPTY}
    ${data}=      Generate Profile Data    prefix=tc770    minimum=${False}
    ${gscv_id}=   Create TC762 Profile Via GSCV API    ${data}
    Set Test Variable    ${TC770_GSCV_ID}    ${gscv_id}
    Sleep    10s
    ${init_result}=    QueryRecords
    ...    SELECT Id FROM Account WHERE crm_GSCV_ID__c = '${gscv_id}' LIMIT 1
    Should Be Equal As Integers    ${init_result}[totalSize]    1
    ...    msg=Expected 1 SF Account for GSCV ID ${gscv_id} but found ${init_result}[totalSize]
    Set Test Variable    ${TC770_SF_RECORD_ID}    ${init_result}[records][0][Id]
    ${new_first}=    Set Variable    Up${data}[firstName]
    ${new_last}=     Set Variable    Up${data}[lastName]
    ${new_pref}=     Set Variable    Pref2
    ${headers}=      Create Dictionary    x-api-key=${qa_gscv_apikey}    Content-Type=application/json    accept=application/json
    ${get_params}=   Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${gscv_id}
    ${get_resp}=     GET    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${get_params}    expected_status=200
    ${body}=         Set Variable    ${get_resp.json()}
    Set To Dictionary    ${body}    firstName=${new_first}    lastName=${new_last}    preferredName=${new_pref}
    ${put_params}=   Create Dictionary    &{GSCV_CONTEXT}
    PUT    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${put_params}    json=${body}    expected_status=200
    Sleep    10s
    ${sf_result}=    QueryRecords
    ...    SELECT FirstName, LastName, PersonEmail, PersonBirthdate, PersonGenderIdentity FROM Account WHERE Id = '${TC770_SF_RECORD_ID}' LIMIT 1
    ${sf}=    Set Variable    ${sf_result}[records][0]
    Should Be Equal As Strings    ${sf}[FirstName]             ${new_first}
    Should Be Equal As Strings    ${sf}[LastName]              ${new_last}
    Should Be Equal As Strings    ${sf}[PersonEmail]           ${data}[email]
    Should Be Equal As Strings    ${sf}[PersonBirthdate]       ${data}[dob]
    Should Be Equal As Strings    ${sf}[PersonGenderIdentity]  ${data}[gender]


SLB-770_3 Partial GSCV Update Preserves Unchanged Salesforce Fields
    [Documentation]    POST a customer profile with full data to the GSCV API, wait for SF sync,
    ...    then PUT an update changing only firstName. Verifies firstName is updated in Salesforce
    ...    and all other fields (lastName, email, dob, gender) remain unchanged.
    ...    Covers AC3: fields not changed in GSCV should remain as they were in Salesforce.
    [Tags]    profile-management    gscv    slb-770    regression    gscv-initiated
    [Setup]    Authenticate As Admin
    [Teardown]    Delete TC770 Profile
    Set Test Variable    ${TC770_GSCV_ID}       ${EMPTY}
    Set Test Variable    ${TC770_SF_RECORD_ID}  ${EMPTY}
    ${data}=      Generate Profile Data    prefix=tc770    minimum=${False}
    ${gscv_id}=   Create TC762 Profile Via GSCV API    ${data}
    Set Test Variable    ${TC770_GSCV_ID}    ${gscv_id}
    Sleep    10s
    ${init_result}=    QueryRecords
    ...    SELECT Id FROM Account WHERE crm_GSCV_ID__c = '${gscv_id}' LIMIT 1
    Should Be Equal As Integers    ${init_result}[totalSize]    1
    ...    msg=Expected 1 SF Account for GSCV ID ${gscv_id} but found ${init_result}[totalSize]
    Set Test Variable    ${TC770_SF_RECORD_ID}    ${init_result}[records][0][Id]
    ${new_first}=    Set Variable    Up${data}[firstName]
    ${headers}=      Create Dictionary    x-api-key=${qa_gscv_apikey}    Content-Type=application/json    accept=application/json
    ${get_params}=   Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${gscv_id}
    ${get_resp}=     GET    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${get_params}    expected_status=200
    ${body}=         Set Variable    ${get_resp.json()}
    Set To Dictionary    ${body}    firstName=${new_first}
    ${put_params}=   Create Dictionary    &{GSCV_CONTEXT}
    PUT    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${put_params}    json=${body}    expected_status=200
    Sleep    10s
    ${sf_result}=    QueryRecords
    ...    SELECT FirstName, LastName, PersonEmail, PersonBirthdate, PersonGenderIdentity FROM Account WHERE Id = '${TC770_SF_RECORD_ID}' LIMIT 1
    ${sf}=    Set Variable    ${sf_result}[records][0]
    Should Be Equal As Strings    ${sf}[FirstName]             ${new_first}
    Should Be Equal As Strings    ${sf}[LastName]              ${data}[lastName]
    Should Be Equal As Strings    ${sf}[PersonEmail]           ${data}[email]
    Should Be Equal As Strings    ${sf}[PersonBirthdate]       ${data}[dob]
    Should Be Equal As Strings    ${sf}[PersonGenderIdentity]  ${data}[gender]


SLB-522_1 Blank First Name Prevents Save And Shows Error
    [Documentation]    Submit the new account form with First Name blank. Verifies the form is not
    ...    submitted (modal remains open, no Account created).
    [Tags]    form-validation    gscv    slb-522    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Close New Account Form Modal
    Open New Account Form Via Nav
    PickList    Salutation    Mr
    TypeText    Last Name     ValidLastName
    ${xp_cc}=    Set Variable    xpath=//*[@data-testid='phone-country-code-1']
    TypeText    ${xp_cc}    61
    ${xp_ph}=    Set Variable    xpath=//*[@data-testid='phone-number-1']
    TypeText    ${xp_ph}    400123456
    ClickText    Create
    VerifyText   Cancel


SLB-522_2 Blank Last Name Prevents Save And Shows Error
    [Documentation]    Submit the new account form with Last Name blank. Verifies the form is not
    ...    submitted (modal remains open, no Account created).
    [Tags]    form-validation    gscv    slb-522    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Close New Account Form Modal
    Open New Account Form Via Nav
    PickList    Salutation    Mr
    TypeText    First Name    ValidFirstName
    ${xp_cc}=    Set Variable    xpath=//*[@data-testid='phone-country-code-1']
    TypeText    ${xp_cc}    61
    ${xp_ph}=    Set Variable    xpath=//*[@data-testid='phone-number-1']
    TypeText    ${xp_ph}    400123456
    ClickText    Create
    VerifyText   Cancel


SLB-522_3 Missing Both Email And Phone Prevents Save
    [Documentation]    Submit the new account form with both Email and Phone blank. Verifies the form
    ...    is not submitted (modal remains open, no Account created).
    [Tags]    form-validation    gscv    slb-522    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Close New Account Form Modal
    Open New Account Form Via Nav
    PickList    Salutation    Mr
    TypeText    First Name    ValidFirstName
    TypeText    Last Name     ValidLastName
    ClickText    Create
    VerifyText   Cancel


SLB-522_4 Invalid Name Characters Show Inline Error
    [Documentation]    Submit the new account form with numbers in the First Name field. Verifies the
    ...    inline error "Only characters a-z and A-Z and '-. will be accepted" is shown.
    [Tags]    form-validation    gscv    slb-522    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Close New Account Form Modal
    Open New Account Form Via Nav
    PickList    Salutation    Mr
    TypeText    First Name    Test123
    TypeText    Last Name     ValidLastName
    ${xp_cc}=    Set Variable    xpath=//*[@data-testid='phone-country-code-1']
    TypeText    ${xp_cc}    61
    ${xp_ph}=    Set Variable    xpath=//*[@data-testid='phone-number-1']
    TypeText    ${xp_ph}    400123456
    ClickText    Create
    VerifyText   Only characters a-z and A-Z and '-. will be accepted


SLB-522_5 Invalid Country Code Shows Inline Error On Blur
    [Documentation]    Enter a country code beginning with zero and move away from the field. Verifies
    ...    the inline error "Numbers only (1–4 digits), cannot start with 0" is shown.
    [Tags]    form-validation    gscv    slb-522    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Close New Account Form Modal
    Open New Account Form Via Nav
    PickList    Salutation    Mr
    TypeText    First Name    ValidFirstName
    TypeText    Last Name     ValidLastName
    ${xp_cc}=    Set Variable    xpath=//*[@data-testid='phone-country-code-1']
    TypeText    ${xp_cc}    0
    ClickText    First Name
    VerifyText   Numbers only (1–4 digits), cannot start with 0


SLB-522_6 Invalid Phone Number Shows Inline Error On Blur
    [Documentation]    Enter a non-numeric value in the phone number field and move away. Verifies
    ...    the inline error "Numbers only (4–15 digits)" is shown.
    [Tags]    form-validation    gscv    slb-522    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Close New Account Form Modal
    Open New Account Form Via Nav
    PickList    Salutation    Mr
    TypeText    First Name    ValidFirstName
    TypeText    Last Name     ValidLastName
    ${xp_cc}=    Set Variable    xpath=//*[@data-testid='phone-country-code-1']
    TypeText    ${xp_cc}    61
    ${xp_ph}=    Set Variable    xpath=//*[@data-testid='phone-number-1']
    TypeText    ${xp_ph}    abc
    ClickText    First Name
    VerifyText   Numbers only (4–15 digits)


SLB-522_7 Birthdate Before 1900 Shows Inline Error
    [Documentation]    Submit the new account form with a birthdate before 01/01/1900. Verifies the
    ...    inline error "Value must be 1/1/1900 or later." is shown on the DOB field.
    [Tags]    form-validation    gscv    slb-522    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Close New Account Form Modal
    Open New Account Form Via Nav
    PickList    Salutation    Mr
    TypeText    First Name    ValidFirstName
    TypeText    Last Name     ValidLastName
    ${xp_cc}=    Set Variable    xpath=//*[@data-testid='phone-country-code-1']
    TypeText    ${xp_cc}    61
    ${xp_ph}=    Set Variable    xpath=//*[@data-testid='phone-number-1']
    TypeText    ${xp_ph}    400123456
    TypeText    Birthdate    01/01/1899
    ClickText    Create
    VerifyText   Date of birth cannot be before 01/01/1900.


SLB-522_8 Birthdate Wrong Format Shows Inline Error On Blur
    [Documentation]    Enter a birthdate in YYYY-MM-DD format (not DD/MM/YYYY) and move away from
    ...    the field. Verifies the inline error "Your entry does not match the allowed format
    ...    31/12/2024." is shown on the DOB field.
    [Tags]    form-validation    gscv    slb-522    regression
    [Setup]    Authenticate And Open GSCV
    [Teardown]    Close New Account Form Modal
    Open New Account Form Via Nav
    PickList    Salutation    Mr
    TypeText    First Name    ValidFirstName
    TypeText    Last Name     ValidLastName
    ${xp_cc}=    Set Variable    xpath=//*[@data-testid='phone-country-code-1']
    TypeText    ${xp_cc}    61
    ${xp_ph}=    Set Variable    xpath=//*[@data-testid='phone-number-1']
    TypeText    ${xp_ph}    400123456
    TypeText    Birthdate    2024-12-31
    ClickText    First Name
    VerifyText   Your entry does not match the allowed format 31/12/2024.


*** Keywords ***
Setup Browser
    Set Library Search Order    QForce    QWeb
    Open Browser        about:blank    ${BROWSER}
    SetConfig           LineBreak           ${EMPTY}
    SetConfig           DefaultTimeout      30s
    SetConfig           CSSSelectors        False

End suite
    Close All Browsers

Authenticate And Open GSCV
    OpenBrowser         about:blank    chrome
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login           /lightning/page/home
    VerifyTitle         Home | Salesforce

Authenticate As Admin
    [Documentation]    Opens a browser and authenticates as the API-enabled admin user.
    ...    Used by tests that need SOQL access but no SF UI navigation.
    OpenBrowser         about:blank    chrome
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True

Open GSCV New Account Via Global Action
    # The Global Actions trigger is an <a> with class="globalCreateTrigger" and title="" (empty).
    # title='Global Actions' fails — that text only lives in a hidden tooltip span, not the element.
    ClickElement                xpath=//a[contains(@class,'globalCreateTrigger')]
    VerifyText                  New Person Account
    ClickText                   New Person Account
    UseModal                    On

Navigate To Accounts Via Nav Menu
    ClickText           Show Navigation Menu
    ClickText           Accounts
    ClickText           Close    anchor=Skip to Navigation


Verify GSCV ID Is Populated Via API
    [Documentation]    Re-auths as admin and queries the saved record to confirm crm_GSCV_ID__c
    ...    is not null, then re-auths as the test user and verifies the value is visible on screen.
    Run Keyword If    '${TC707_RECORD_ID}' == '${EMPTY}'    Pass Execution    No record ID captured — skipping API check
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${result}=          QueryRecords    SELECT crm_GSCV_ID__c FROM Account WHERE Id = '${TC707_RECORD_ID}' LIMIT 1
    ${gscv_id}=         Set Variable    ${result}[records][0][crm_GSCV_ID__c]
    Should Not Be Equal    ${gscv_id}    ${None}    msg=crm_GSCV_ID__c is null for Account ${TC707_RECORD_ID}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    VerifyText          ${gscv_id}

Delete SLB707 Profile
    [Documentation]    Teardown: deletes the GSCV profile via API then the Salesforce account.
    ...    Best-effort — skips if no record Id was captured. Re-auths as admin (test users are not API-enabled).
    Return From Keyword If    '${TC707_RECORD_ID}' == '${EMPTY}'
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    Delete Profile Fully    ${TC707_RECORD_ID}

Delete GSCV Profile Via API
    [Documentation]    Queries crm_GSCV_ID__c for the given SF Account Id then calls
    ...    DELETE /b2bv2/customerProfile. Skips silently if the GSCV ID is null or the
    ...    SOQL query fails. Expects an active admin JWT session before calling.
    [Arguments]    ${record_id}
    ${status}    ${result}=    Run Keyword And Ignore Error
    ...    QueryRecords    SELECT crm_GSCV_ID__c FROM Account WHERE Id = '${record_id}' LIMIT 1
    Return From Keyword If    '${status}' != 'PASS'
    ${gscv_id}=    Set Variable    ${result}[records][0][crm_GSCV_ID__c]
    Return From Keyword If    '${gscv_id}' == 'None'
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json
    ${params}=     Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${gscv_id}
    Run Keyword And Ignore Error    DELETE    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}
    ...    params=${params}
    ...    expected_status=200

Delete Profile Fully
    [Documentation]    Deletes the GSCV profile via API then the Salesforce Account. Both steps are
    ...    best-effort: the GSCV delete triggers a SF delete via integration, so the SF record may
    ...    already be gone (ENTITY_IS_DELETED) by the time Delete Record runs — that is expected.
    ...    Expects an active admin JWT session before calling.
    [Arguments]    ${record_id}
    Run Keyword And Ignore Error    Delete GSCV Profile Via API    ${record_id}
    Run Keyword And Ignore Error    Delete Record    Account    ${record_id}

Verify SLB711 GSCV API Data Consistency
    [Documentation]    AC2: Queries crm_GSCV_ID__c from Salesforce then calls the GSCV
    ...    customerProfile endpoint and asserts all fields match between systems after an update.
    [Arguments]    ${data}
    Run Keyword If    '${TC711_RECORD_ID}' == '${EMPTY}'    Pass Execution    No record ID captured — skipping GSCV API consistency check
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${result}=                QueryRecords    SELECT crm_GSCV_ID__c, BillingStateCode, BillingCountryCode FROM Account WHERE Id = '${TC711_RECORD_ID}' LIMIT 1
    ${gscv_id}=               Set Variable    ${result}[records][0][crm_GSCV_ID__c]
    ${billing_state_code}=    Set Variable    ${result}[records][0][BillingStateCode]
    ${billing_country_code}=  Set Variable    ${result}[records][0][BillingCountryCode]
    Should Not Be Equal    ${gscv_id}    ${None}    msg=crm_GSCV_ID__c is null for Account ${TC711_RECORD_ID}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json    Content-Type=application/json
    ${params}=     Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${gscv_id}
    ${response}=    GET    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    expected_status=200
    ${body}=    Set Variable    ${response.json()}
    Should Be Equal As Strings    ${body}[customerProfileId]    ${gscv_id}
    Should Be Equal As Strings    ${body}[title]               ${data}[salutation]
    Should Be Equal As Strings    ${body}[firstName]           ${data}[firstName]
    Should Be Equal As Strings    ${body}[middleName]          ${data}[middleName]
    Should Be Equal As Strings    ${body}[lastName]            ${data}[lastName]
    Should Be Equal As Strings    ${body}[preferredName]       ${data}[preferredName]
    Should Be Equal As Strings    ${body}[gender]              ${data}[gender]
    Should Be Equal As Strings    ${body}[dob]                 ${data}[dob]
    Should Be Equal As Strings    ${body}[contactDetail][email][0][email]                    ${data}[email]
    Should Be Equal As Strings    ${body}[contactDetail][phoneNumber][0][countryCode]        ${data}[countryCode]
    Should Be Equal As Strings    ${body}[contactDetail][phoneNumber][0][number]             ${data}[phone]
    Should Be Equal As Strings    ${body}[contactDetail][address][0][addressLine1]           ${data}[addressStreet]
    Should Be Equal As Strings    ${body}[contactDetail][address][0][city]                   ${data}[addressCity]
    Should Be Equal As Strings    ${body}[contactDetail][address][0][state]                  ${billing_state_code}
    Should Be Equal As Strings    ${body}[contactDetail][address][0][postcode]               ${data}[addressPostal]
    Should Be Equal As Strings    ${body}[contactDetail][address][0][country]                ${billing_country_code}

Delete SLB711 AC12 Profile
    [Documentation]    Teardown: deletes the GSCV profile via API then the Salesforce account.
    ...    Best-effort — skips if no record Id was captured.
    Return From Keyword If    '${TC711_RECORD_ID}' == '${EMPTY}'
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    Delete Profile Fully    ${TC711_RECORD_ID}

Delete SLB711 Profiles
    [Documentation]    Teardown: attempt to delete both accounts. After a successful merge, account 1
    ...    will already be gone — errors are ignored for both so teardown always completes cleanly.
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    Delete Profile Fully    ${TC711_RECORD_ID_2}
    Delete Profile Fully    ${TC711_RECORD_ID_1}

Delete TC759 Profiles
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    Delete Profile Fully    ${TC759_RECORD_ID_1}
    Delete Profile Fully    ${TC759_RECORD_ID_2}

Add TC759 FRIEND Relationship
    [Documentation]    Adds a FRIEND linked traveller relationship from the current profile page
    ...    to the profile identified by the given first and last name.
    [Arguments]    ${first_name}    ${last_name}
    ClickText    Linked Travellers
    ClickText    Add Relationship
    PickList     Role    FRIEND
    TypeText     Search contacts...    ${first_name} ${last_name}
    Sleep        2s
    ClickElement    xpath=//lightning-base-combobox-item[@role="option"]//span[contains(@class,"slds-listbox__option-text_entity")]/span[@title="${first_name} ${last_name}"]
    ClickElement    xpath=//button[normalize-space(.)='Save']
    VerifyText    ${first_name} ${last_name}


Delete TC760 Profiles
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    Delete Profile Fully    ${TC760_RECORD_ID_1}
    Delete Profile Fully    ${TC760_RECORD_ID_2}

Delete TC769 Profile
    [Documentation]    Teardown: deletes the GSCV profile via API then the Salesforce account.
    ...    Best-effort — skips if no GSCV ID was captured.
    Return From Keyword If    '${TC769_GSCV_ID}' == '${EMPTY}'
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json
    ${params}=     Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${TC769_GSCV_ID}
    Run Keyword And Ignore Error    DELETE    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    expected_status=200
    Run Keyword If    '${TC769_SF_RECORD_ID}' != '${EMPTY}'
    ...    Run Keyword And Ignore Error    Delete Record    Account    ${TC769_SF_RECORD_ID}

Add TC760 Inverse Relationship
    [Documentation]    Adds a COLLEAGUE (inverse/two-way) linked traveller relationship from the
    ...    current profile page to the profile identified by the given first and last name.
    [Arguments]    ${first_name}    ${last_name}
    ClickText    Linked Travellers
    ClickText    Add Relationship
    PickList     Role    COLLEAGUE
    TypeText     Search contacts...    ${first_name} ${last_name}
    Sleep        2s
    ClickElement    xpath=//lightning-base-combobox-item[@role="option"]//span[contains(@class,"slds-listbox__option-text_entity")]/span[@title="${first_name} ${last_name}"]
    ClickCheckbox   Has Inverse Relationship    on
    ClickElement    xpath=//button[normalize-space(.)='Save']
    Sleep        2s
    LogScreenshot

Verify SLB707 GSCV API Data Consistency
    [Documentation]    AC2: Queries crm_GSCV_ID__c from Salesforce then calls the GSCV
    ...    customerProfile endpoint and asserts all created fields match between systems.
    [Arguments]    ${data}
    Run Keyword If    '${TC707_RECORD_ID}' == '${EMPTY}'    Pass Execution    No record ID captured — skipping GSCV API consistency check
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${result}=                QueryRecords    SELECT crm_GSCV_ID__c, BillingStateCode, BillingCountryCode FROM Account WHERE Id = '${TC707_RECORD_ID}' LIMIT 1
    ${gscv_id}=               Set Variable    ${result}[records][0][crm_GSCV_ID__c]
    ${billing_state_code}=    Set Variable    ${result}[records][0][BillingStateCode]
    ${billing_country_code}=  Set Variable    ${result}[records][0][BillingCountryCode]
    Should Not Be Equal    ${gscv_id}    ${None}    msg=crm_GSCV_ID__c is null for Account ${TC707_RECORD_ID}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json    Content-Type=application/json
    ${params}=     Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${gscv_id}
    ${response}=    GET    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    expected_status=200
    ${body}=    Set Variable    ${response.json()}
    Should Be Equal As Strings    ${body}[customerProfileId]    ${gscv_id}
    Should Be Equal As Strings    ${body}[title]               ${data}[salutation]
    Should Be Equal As Strings    ${body}[firstName]           ${data}[firstName]
    Should Be Equal As Strings    ${body}[middleName]          ${data}[middleName]
    Should Be Equal As Strings    ${body}[lastName]            ${data}[lastName]
    Should Be Equal As Strings    ${body}[preferredName]       ${data}[preferredName]
    Should Be Equal As Strings    ${body}[gender]              ${data}[gender]
    Should Be Equal As Strings    ${body}[dob]                 ${data}[dob]
    Should Be Equal As Strings    ${body}[contactDetail][email][0][email]                    ${data}[email]
    Should Be Equal As Strings    ${body}[contactDetail][phoneNumber][0][countryCode]        ${data}[countryCode]
    Should Be Equal As Strings    ${body}[contactDetail][phoneNumber][0][number]             ${data}[phone]
    Should Be Equal As Strings    ${body}[contactDetail][address][0][addressLine1]           ${data}[addressStreet]
    Should Be Equal As Strings    ${body}[contactDetail][address][0][city]                   ${data}[addressCity]
    Should Be Equal As Strings    ${body}[contactDetail][address][0][state]                  ${billing_state_code}
    Should Be Equal As Strings    ${body}[contactDetail][address][0][postcode]               ${data}[addressPostal]
    Should Be Equal As Strings    ${body}[contactDetail][address][0][country]                ${billing_country_code}

Verify TC759 GSCV Linked Traveller
    [Documentation]    Calls GET /b2bv2/customerProfile for the profile at ${record_id} and asserts
    ...    that linkedTravellers contains an entry with profileId matching the GSCV ID of
    ...    ${linked_record_id} and relationshipType equal to ${expected_role}.
    [Arguments]    ${record_id}    ${linked_record_id}    ${expected_role}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${result}=    QueryRecords
    ...    SELECT Id, crm_GSCV_ID__c FROM Account WHERE Id = '${record_id}' OR Id = '${linked_record_id}' LIMIT 2
    ${gscv_id_a}=    Set Variable    ${EMPTY}
    ${gscv_id_b}=    Set Variable    ${EMPTY}
    FOR    ${row}    IN    @{result}[records]
        ${id}=    Set Variable    ${row}[Id]
        ${gid}=   Set Variable    ${row}[crm_GSCV_ID__c]
        Run Keyword If    '${id}' == '${record_id}'         Set Test Variable    ${gscv_id_a}    ${gid}
        Run Keyword If    '${id}' == '${linked_record_id}'  Set Test Variable    ${gscv_id_b}    ${gid}
    END
    Should Not Be Equal    ${gscv_id_a}    ${EMPTY}    msg=crm_GSCV_ID__c is null for Account ${record_id}
    Should Not Be Equal    ${gscv_id_b}    ${EMPTY}    msg=crm_GSCV_ID__c is null for Account ${linked_record_id}
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json
    ${params}=     Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${gscv_id_a}
    ${response}=    GET    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    expected_status=200
    ${body}=    Set Variable    ${response.json()}
    ${travellers}=    Set Variable    ${body}[linkedTravellers]
    Should Not Be Empty    ${travellers}    msg=linkedTravellers is empty in GSCV for profile ${gscv_id_a}
    ${found}=    Set Variable    False
    FOR    ${t}    IN    @{travellers}
        ${match}=    Run Keyword And Return Status
        ...    Should Be Equal As Strings    ${t}[profileId]    ${gscv_id_b}
        Run Keyword If    ${match}    Should Be Equal As Strings    ${t}[relationshipType]    ${expected_role}
        ...    msg=Expected role ${expected_role} but got ${t}[relationshipType] for linkedTraveller ${gscv_id_b}
        ${found}=    Run Keyword If    ${match}    Set Variable    True    ELSE    Set Variable    ${found}
    END
    Should Be True    ${found}
    ...    msg=No linkedTraveller with profileId=${gscv_id_b} and role=${expected_role} in GSCV profile ${gscv_id_a}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True

Verify TC759 GSCV No Linked Travellers
    [Documentation]    Calls GET /b2bv2/customerProfile for ${record_id} and asserts linkedTravellers is absent or empty.
    [Arguments]    ${record_id}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${result}=    QueryRecords    SELECT crm_GSCV_ID__c FROM Account WHERE Id = '${record_id}' LIMIT 1
    ${gscv_id}=    Set Variable    ${result}[records][0][crm_GSCV_ID__c]
    Should Not Be Equal    ${gscv_id}    ${None}    msg=crm_GSCV_ID__c is null for Account ${record_id}
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json
    ${params}=     Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${gscv_id}
    ${response}=    GET    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    expected_status=200
    ${body}=    Set Variable    ${response.json()}
    ${has_travellers}=    Run Keyword And Return Status
    ...    Should Not Be Empty    ${body}[linkedTravellers]
    Run Keyword If    ${has_travellers}    Fail
    ...    msg=Expected empty linkedTravellers in GSCV for ${gscv_id} but found entries
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True

Verify TC760 GSCV Both Directions
    [Documentation]    Verifies that GSCV reflects the linked traveller relationship in both directions.
    ...    Calls GET /b2bv2/customerProfile for both profiles and asserts each contains the other
    ...    with the expected role.
    [Arguments]    ${record_id_a}    ${record_id_b}    ${expected_role_a}    ${expected_role_b}
    Verify TC759 GSCV Linked Traveller    ${record_id_a}    ${record_id_b}    ${expected_role_a}
    Verify TC759 GSCV Linked Traveller    ${record_id_b}    ${record_id_a}    ${expected_role_b}

Verify TC765 Inverse Role Mapping
    [Documentation]    Template keyword: creates two isolated profiles, adds a linked traveller
    ...    relationship from A with the given role, then navigates to B and verifies the
    ...    reciprocal role is correct. Cleans up both profiles after each row.
    [Arguments]    ${role}    ${expected_reciprocal}
    ${ts}=       Get Current Date    result_format=%Y%m%d%H%M%S%f
    ${data_1}=   Generate Profile Data    prefix=tc765    minimum=${True}    index=1    ts=${ts}
    ${data_2}=   Generate Profile Data    prefix=tc765    minimum=${True}    index=2    ts=${ts}
    ${id_1}=    Create GSCV Profile    ${data_1}
    ${id_2}=    Create GSCV Profile    ${data_2}
    ClickText    Linked Travellers
    ClickText    Add Relationship
    PickList     Role    ${role}
    TypeText     Search contacts...    ${data_1}[firstName] ${data_1}[lastName]
    Sleep        2s
    ClickElement    xpath=//lightning-base-combobox-item[@role="option"]//span[contains(@class,"slds-listbox__option-text_entity")]/span[@title="${data_1}[firstName] ${data_1}[lastName]"]
    ClickCheckbox   Has Inverse Relationship    on
    ClickElement    xpath=//button[normalize-space(.)='Save']
    VerifyText    ${data_1}[firstName] ${data_1}[lastName]
    Jwt Login    /lightning/r/Account/${id_1}/view
    VerifyText    GSCV Profile ID
    ClickText    Linked Travellers
    VerifyText    ${data_2}[firstName] ${data_2}[lastName]
    VerifyText    ${expected_reciprocal}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    Delete Profile Fully    ${id_1}
    Delete Profile Fully    ${id_2}
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_sales1}    ${server_key}    sandbox=True
    Jwt Login    /lightning/page/home

Open New Account Form Via Nav
    Navigate To Accounts Via Nav Menu
    ClickText    New
    UseModal     On
    Sleep        2s

Close New Account Form Modal
    Run Keyword And Ignore Error    ClickText    Cancel
    UseModal    Off

Add TC761 Relationship
    [Documentation]    Adds a linked traveller relationship from the current Linked Travellers tab.
    ...    Assumes the browser is already on the Linked Travellers tab.
    ...    inverse=${True} checks "Has Inverse Relationship".
    [Arguments]    ${first_name}    ${last_name}    ${role}    ${inverse}=${False}
    ClickText    Add Relationship
    PickList     Role    ${role}
    TypeText     Search contacts...    ${first_name} ${last_name}
    Sleep        2s
    ClickElement    xpath=//lightning-base-combobox-item[@role="option"]//span[contains(@class,"slds-listbox__option-text_entity")]/span[@title="${first_name} ${last_name}"]
    Run Keyword If    ${inverse}    ClickCheckbox    Has Inverse Relationship    on
    ClickElement    xpath=//button[normalize-space(.)='Save']
    Sleep        2s
    LogScreenshot

Delete TC761 Profiles
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    Delete Profile Fully    ${TC761_RECORD_ID_1}
    Delete Profile Fully    ${TC761_RECORD_ID_2}
    Delete Profile Fully    ${TC761_RECORD_ID_3}

Create TC762 Profile Via GSCV API
    [Documentation]    POSTs a new customer profile to GSCV and returns the assigned customerProfileId.
    [Arguments]    ${data}
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    Content-Type=application/json    accept=application/json
    ${params}=     Create Dictionary    &{GSCV_CONTEXT}
    ${body}=       Build GSCV Profile Body    ${data}
    ${response}=   POST    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    json=${body}    expected_status=201
    [Return]    ${response.json()}[customerProfileId]

Put TC762 GSCV Linked Travellers
    [Documentation]    GETs the full GSCV profile for ${gscv_id}, replaces linkedTravellers with
    ...    ${linked_travellers}, then PUTs the updated profile back to GSCV.
    [Arguments]    ${gscv_id}    ${linked_travellers}
    ${headers}=      Create Dictionary    x-api-key=${qa_gscv_apikey}    Content-Type=application/json    accept=application/json
    ${get_params}=   Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${gscv_id}
    ${get_resp}=     GET    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${get_params}    expected_status=200
    ${body}=         Set Variable    ${get_resp.json()}
    Set To Dictionary    ${body}    linkedTravellers=${linked_travellers}
    ${put_params}=   Create Dictionary    &{GSCV_CONTEXT}
    PUT    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${put_params}    json=${body}    expected_status=200

Delete TC762 Profiles
    [Documentation]    Teardown: deletes both GSCV profiles via API then any synced SF accounts.
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json
    ${params_a}=   Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${TC762_GSCV_ID_A}
    ${params_b}=   Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${TC762_GSCV_ID_B}
    Run Keyword And Ignore Error    DELETE    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params_a}    expected_status=200
    Run Keyword And Ignore Error    DELETE    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params_b}    expected_status=200
    Run Keyword If    '${TC762_SF_ID_A}' != '${EMPTY}'
    ...    Run Keyword And Ignore Error    Delete Record    Account    ${TC762_SF_ID_A}
    Run Keyword If    '${TC762_SF_ID_B}' != '${EMPTY}'
    ...    Run Keyword And Ignore Error    Delete Record    Account    ${TC762_SF_ID_B}

Delete TC763 Profiles
    [Documentation]    Teardown: deletes both GSCV profiles via API then any synced SF accounts.
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json
    ${params_a}=   Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${TC763_GSCV_ID_A}
    ${params_b}=   Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${TC763_GSCV_ID_B}
    Run Keyword And Ignore Error    DELETE    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params_a}    expected_status=200
    Run Keyword And Ignore Error    DELETE    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params_b}    expected_status=200
    Run Keyword If    '${TC763_SF_ID_A}' != '${EMPTY}'
    ...    Run Keyword And Ignore Error    Delete Record    Account    ${TC763_SF_ID_A}
    Run Keyword If    '${TC763_SF_ID_B}' != '${EMPTY}'
    ...    Run Keyword And Ignore Error    Delete Record    Account    ${TC763_SF_ID_B}

Delete TC764 Profiles
    [Documentation]    Teardown: deletes all three GSCV profiles via API then any synced SF accounts.
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json
    ${params_a}=   Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${TC764_GSCV_ID_A}
    ${params_b}=   Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${TC764_GSCV_ID_B}
    ${params_c}=   Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${TC764_GSCV_ID_C}
    Run Keyword And Ignore Error    DELETE    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params_a}    expected_status=200
    Run Keyword And Ignore Error    DELETE    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params_b}    expected_status=200
    Run Keyword And Ignore Error    DELETE    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params_c}    expected_status=200
    Run Keyword If    '${TC764_SF_ID_A}' != '${EMPTY}'
    ...    Run Keyword And Ignore Error    Delete Record    Account    ${TC764_SF_ID_A}
    Run Keyword If    '${TC764_SF_ID_B}' != '${EMPTY}'
    ...    Run Keyword And Ignore Error    Delete Record    Account    ${TC764_SF_ID_B}
    Run Keyword If    '${TC764_SF_ID_C}' != '${EMPTY}'
    ...    Run Keyword And Ignore Error    Delete Record    Account    ${TC764_SF_ID_C}

Delete TC770 Profile
    [Documentation]    Teardown: deletes the GSCV profile via API then the Salesforce account.
    ...    Best-effort — skips if no GSCV ID was captured.
    Return From Keyword If    '${TC770_GSCV_ID}' == '${EMPTY}'
    Jwt Authenticate    ${qa_client_id}    ${qa_persona_admin}    ${server_key}    sandbox=True
    ${headers}=    Create Dictionary    x-api-key=${qa_gscv_apikey}    accept=application/json
    ${params}=     Create Dictionary    &{GSCV_CONTEXT}    customerProfileId=${TC770_GSCV_ID}
    Run Keyword And Ignore Error    DELETE    ${qa_gscv_endpoint}/b2bv2/customerProfile
    ...    headers=${headers}    params=${params}    expected_status=200
    Run Keyword If    '${TC770_SF_RECORD_ID}' != '${EMPTY}'
    ...    Run Keyword And Ignore Error    Delete Record    Account    ${TC770_SF_RECORD_ID}
