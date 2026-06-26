*** Settings ***
Library    DateTime
Library    Collections


*** Keywords ***
Generate Profile Data
    [Documentation]    Generates unique test data for one customer profile and returns it as a dict.
    ...    minimum=True: firstName, lastName, email, phone, salutation, countryCode only.
    ...    minimum=False: also adds middleName, preferredName, gender/genderDisplay,
    ...    dob/dobDisplay, notes, preferredContact, and hardcoded AU address fields.
    ...    Pass a pre-generated ts to share the same token/lastName across two profiles.
    [Arguments]    ${prefix}=profile    ${minimum}=${False}    ${index}=1    ${ts}=${EMPTY}
    ${ts}=         Run Keyword If    '${ts}' == '${EMPTY}'
    ...            Get Current Date    result_format=%Y%m%d%H%M%S%f
    ...            ELSE    Set Variable    ${ts}
    ${minimum}=    Evaluate    str(${minimum}).lower() == 'true'
    ${token}=      Evaluate    ''.join(chr(97 + int(d)) for d in $ts)
    ${label}=      Evaluate    chr(64 + int(${index}))
    ${phone}=      Evaluate    '40' + str(int(${index}) - 1) + $ts[-6:]
    ${data}=       Create Dictionary
    ...    minimum=${minimum}
    ...    firstName=Test${label}${token}
    ...    lastName=Profile${token}
    ...    email=test.${prefix}.${index}.${ts}@auto.com
    ...    phone=${phone}
    ...    salutation=Mr
    ...    countryCode=61
    IF    not ${minimum}
        Set To Dictionary    ${data}
        ...    middleName=Mid
        ...    preferredName=Pref
        ...    gender=M
        ...    genderDisplay=Male
        ...    dob=1990-06-15
        ...    dobDisplay=15/06/1990
        ...    notes=test notes
        ...    preferredContact=Any
        ...    addressStreet=22 George Street
        ...    addressCity=Leichhardt
        ...    addressState=New South Wales
        ...    addressPostal=2040
        ...    addressCountry=Australia
    END
    [Return]    ${data}


Create GSCV Profile
    [Documentation]    Creates a new GSCV customer profile via the SF UI using data from the factory dict.
    ...    entry_point=nav (default): navigates via Accounts nav menu.
    ...    entry_point=global_action: uses the Global Actions "New Person Account" button.
    ...    Always fills minimum fields. Fills full fields when data[minimum] is False.
    ...    Returns the captured SF Account record Id.
    [Arguments]    ${data}    ${entry_point}=nav
    IF    '${entry_point}' == 'nav'
        Navigate To Accounts Via Nav Menu
        ClickText    New
        UseModal     On
    ELSE
        Open GSCV New Account Via Global Action
    END
    Sleep       2s
    PickList    Salutation    ${data}[salutation]
    TypeText    First Name    ${data}[firstName]
    TypeText    Last Name     ${data}[lastName]
    ${xp_cc}=    Set Variable    xpath=//*[@data-testid='phone-country-code-1']
    TypeText    ${xp_cc}    ${data}[countryCode]
    ${xp_ph}=    Set Variable    xpath=//*[@data-testid='phone-number-1']
    TypeText    ${xp_ph}    ${data}[phone]
    ${xp_em}=    Set Variable    xpath=//*[@data-testid='email-1']
    TypeText    ${xp_em}    ${data}[email]
    IF    not ${data}[minimum]
        TypeText    Middle Name                      ${data}[middleName]
        TypeText    Preferred Name                   ${data}[preferredName]
        PickList    Gender Identity                  ${data}[genderDisplay]
        TypeText    Birthdate                        ${data}[dobDisplay]
        TypeText    Notes                            ${data}[notes]
        PickList    Preferred Method of Contact      ${data}[preferredContact]
        ${xp_at1}=    Set Variable    xpath=//*[@data-testid='address-type-1']
        ClickElement    ${xp_at1}
        ClickText       Billing
        PressKey        ${xp_at1}    TAB
        TypeText        Address Search    ${data}[addressStreet] ${data}[addressCity]    index=1
        ClickText       ${data}[addressStreet]    ${data}[addressCity]    timeout=10s
        Sleep           2s
    END
    ClickText    Create
    UseModal     Off
    VerifyText   GSCV Profile ID
    ${status}    ${id}=    Run Keyword And Ignore Error    Get Record ID From Url
    [Return]    ${id}


Build GSCV Profile Body
    [Documentation]    Assembles a nested dict from the factory data dict, ready for json= in
    ...    a RequestsLibrary POST or PUT call to /b2bv2/customerProfile.
    ...    Always includes title, firstName, lastName, contactDetail.
    ...    When data[minimum] is False, also includes middleName, preferredName, gender, dob.
    [Arguments]    ${data}
    ${email_entry}=    Create Dictionary    email=${data}[email]    emailAddressType=personal
    ${phone_entry}=    Create Dictionary
    ...    countryCode=${data}[countryCode]
    ...    number=${data}[phone]
    ...    phoneNumberType=mobile
    ${email_list}=     Create List    ${email_entry}
    ${phone_list}=     Create List    ${phone_entry}
    ${addr_list}=      Create List
    ${contact}=        Create Dictionary
    ...    email=${email_list}
    ...    phoneNumber=${phone_list}
    ...    address=${addr_list}
    ${body}=           Create Dictionary
    ...    title=${data}[salutation]
    ...    firstName=${data}[firstName]
    ...    lastName=${data}[lastName]
    ...    contactDetail=${contact}
    IF    not ${data}[minimum]
        Set To Dictionary    ${body}
        ...    middleName=${data}[middleName]
        ...    preferredName=${data}[preferredName]
        ...    gender=${data}[gender]
        ...    dob=${data}[dob]
    END
    [Return]    ${body}
