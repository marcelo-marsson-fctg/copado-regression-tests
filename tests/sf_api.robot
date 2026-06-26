*** Settings ***
Library             QForce
Resource            ../resources/common.resource
Suite Setup         Setup Browser
Suite Teardown      End suite


*** Variables ***
${BROWSER}          chrome


*** Test Cases ***
Login Via JWT And Open Home
    [Documentation]    JWT Bearer auth as a precondition, then verify the Home page loads.
    [Tags]    login    smoke
    OpenBrowser         about:blank    chrome
    Jwt Authenticate    ${client_id}    ${persona_service_agent}    ${server_key}    sandbox=True
    Jwt Login           /lightning/page/home
    VerifyTitle         Home | Salesforce


*** Keywords ***
Setup Browser
    Set Library Search Order    QForce    QWeb
    Open Browser        about:blank    ${BROWSER}
    SetConfig           LineBreak           ${EMPTY}        #\ue000
    SetConfig           DefaultTimeout      30s
    SetConfig           CSSSelectors        False

End suite
    Close All Browsers