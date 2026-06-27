# Robot Framework RequestsLibrary Reference

A Robot Framework library for HTTP API testing, wrapping the Python [Requests](https://requests.readthedocs.io/) library.

---

## Quick Start

```robot
*** Settings ***
Library    RequestsLibrary

*** Test Cases ***
Quick Get Request Test
    ${response}=    GET  https://www.google.com

Quick Get Request With Parameters Test
    ${response}=    GET  https://www.google.com/search  params=query=ciao  expected_status=200

Quick Get A JSON Body Test
    ${response}=    GET  https://jsonplaceholder.typicode.com/posts/1
    Should Be Equal As Strings    1  ${response.json()}[id]
```

## Session-Based Usage (Recommended for Multiple Requests)

Share HTTP connections (same URL, headers, cookies) across multiple requests using `Create Session` + `* On Session` keywords:

```robot
*** Settings ***
Library    Collections
Library    RequestsLibrary

Suite Setup    Create Session  jsonplaceholder  https://jsonplaceholder.typicode.com

*** Test Cases ***

Get Request Test
    Create Session    google  http://www.google.com

    ${resp_google}=   GET On Session  google  /  expected_status=200
    ${resp_json}=     GET On Session  jsonplaceholder  /posts/1

    Should Be Equal As Strings          ${resp_google.reason}  OK
    Dictionary Should Contain Value     ${resp_json.json()}  sunt aut facere repellat provident

Post Request Test
    &{data}=    Create dictionary  title=Robotframework requests  body=This is a test!  userId=1
    ${resp}=    POST On Session    jsonplaceholder  /posts  json=${data}  expected_status=anything

    Status Should Be                 201  ${resp}
    Dictionary Should Contain Key    ${resp.json()}  id
```

---

## Response Object

All HTTP request keywords return a `Response` object. Access attributes with dot notation: `${response.json()}`, `${response.status_code}`.

| Attribute | Description |
|-----------|-------------|
| `content` | Response body as bytes |
| `cookies` | CookieJar of cookies the server sent |
| `elapsed` | Time between sending request and parsing headers (timedelta) |
| `encoding` | Encoding used to decode `response.text` |
| `headers` | Case-insensitive dictionary of response headers |
| `history` | List of Response objects from redirects (oldest first) |
| `json()` | JSON-decoded response body (raises ValueError if not valid JSON) |
| `ok` | `True` if status_code < 400 |
| `reason` | Textual reason for HTTP status (e.g. `OK`, `Not Found`) |
| `status_code` | Integer HTTP status code (e.g. `200`, `404`) |
| `text` | Response body as unicode string |
| `url` | Final URL of the response |

---

## POST a Multipart-Encoded File

Use `Get File For Streaming Upload` — do **not** set `Content-Length` or `Content-Type` headers manually.

```robot
Test Post Multiple Files
    ${file_1}=  Get File For Streaming Upload  files/randombytes.bin
    ${file_2}=  Get File For Streaming Upload  files/randombytes.bin
    ${files}=   Create Dictionary  randombytes1  ${file_1}  randombytes2  ${file_2}

    ${resp}=    POST  https://someurl  files=${files}
```

---

## Logging & Authentication

- All request data (including headers) are logged by default.
- The `Authorization` header is **masked** in standard logs.
- Full `Authorization` value is only visible at `TRACE` or `DEBUG` log level.

---

## Keywords

### Session Management

#### `Create Session`
```
Create Session    alias    url
    ...    headers={}    cookies={}    auth=None    timeout=None
    ...    proxies=None    verify=False    debug=0
    ...    max_retries=3    backoff_factor=0.1    disable_warnings=0
    ...    retry_status_list=[]    retry_method_list=['HEAD','TRACE','DELETE','GET','PUT','OPTIONS']
```
Creates a reusable HTTP session. Use alias with `* On Session` keywords.

- `alias` — identifier for the session
- `url` — base URL
- `auth` — `['username', 'password']` for HTTP Basic Auth
- `verify` — SSL cert verification (boolean or CA bundle path)
- `max_retries` — max connection retry attempts (0 = disabled)
- `backoff_factor` — delay multiplier between retries
- `retry_status_list` — HTTP status codes that trigger a retry (e.g. `[502, 503]`)

#### `Create Client Cert Session`
Same as `Create Session` but adds `client_certs` parameter: `['client_cert.pem', 'client_key.pem']`

#### `Create Digest Session`
Same as `Create Session` but `auth` is `['DOMAIN', 'username', 'password']` for Digest Auth.

#### `Create Ntlm Session`
Same as `Create Session` but `auth` is `['DOMAIN', 'username', 'password']` for NTLM Auth.

#### `Create Custom Session`
Same as `Create Session` but `auth` accepts a custom Python Authentication object.

#### `Delete All Sessions`
Removes all session objects from cache.

#### `Session Exists`
```
${exists}=    Session Exists    alias
```
Returns `True` if the session has already been created.

#### `Update Session`
```
Update Session    alias    headers=None    cookies=None
```
Merges new headers/cookies into an existing session.

---

### HTTP Request Keywords

All request keywords accept `expected_status` and `msg` parameters:
- `expected_status=200` — assert specific status code (name or number)
- `expected_status=anything` / `expected_status=any` — disable implicit status assertion

Common `**kwargs` (from `GET` docs, apply to all methods):
- `headers` — dict of HTTP headers
- `auth` — `['user', 'pass']` or auth object
- `timeout` — seconds to wait (float or `(connect_timeout, read_timeout)` tuple)
- `allow_redirects` — `${True}` / `${False}` (HEAD defaults to `${False}`)
- `proxies` — dict mapping protocol to proxy URL
- `verify` — SSL verification boolean or CA bundle path
- `cookies` — dict or CookieJar
- `files` — dict for multipart upload
- `data` — dict, list of tuples, bytes, or file-like object for request body
- `json` — Python dict to send as JSON body
- `stream` — if `${False}`, response is downloaded immediately
- `cert` — path to `.pem` client cert or `('cert', 'key')` tuple

#### `GET` / `GET On Session`
```
${resp}=    GET    url    params=None    expected_status=None    msg=None    **kwargs
${resp}=    GET On Session    alias    url    params=None    expected_status=None    **kwargs
```

#### `POST` / `POST On Session`
```
${resp}=    POST    url    data=None    json=None    expected_status=None    **kwargs
${resp}=    POST On Session    alias    url    data=None    json=None    expected_status=None    **kwargs
```

#### `PUT` / `PUT On Session`
```
${resp}=    PUT    url    data=None    json=None    expected_status=None    **kwargs
${resp}=    PUT On Session    alias    url    data=None    json=None    expected_status=None    **kwargs
```

#### `PATCH` / `PATCH On Session`
```
${resp}=    PATCH    url    data=None    json=None    expected_status=None    **kwargs
${resp}=    PATCH On Session    alias    url    data=None    json=None    expected_status=None    **kwargs
```

#### `DELETE` / `DELETE On Session`
```
${resp}=    DELETE    url    expected_status=None    **kwargs
${resp}=    DELETE On Session    alias    url    expected_status=None    **kwargs
```

#### `HEAD` / `HEAD On Session`
```
${resp}=    HEAD    url    expected_status=None    **kwargs
${resp}=    HEAD On Session    alias    url    expected_status=None    **kwargs
```
Note: `allow_redirects` defaults to `${False}` for HEAD.

#### `OPTIONS` / `OPTIONS On Session`
```
${resp}=    OPTIONS    url    expected_status=None    **kwargs
${resp}=    OPTIONS On Session    alias    url    expected_status=None    **kwargs
```

#### `TRACE` / `TRACE On Session`
```
${resp}=    TRACE    url    expected_status=None    **kwargs
${resp}=    TRACE On Session    alias    url    expected_status=None    **kwargs
```

#### `CONNECT` / `CONNECT On Session`
```
${resp}=    CONNECT    url    expected_status=None    **kwargs
${resp}=    CONNECT On Session    alias    url    expected_status=None    **kwargs
```

---

### Assertion Keywords

#### `Status Should Be`
```
Status Should Be    expected_status    response=None    msg=None
```
Fails if response status code differs from `expected_status`. Accepts numeric codes or named statuses (`ok`, `created`, `accepted`, `bad request`, `not found`, etc.). If `response` is omitted, uses the last response.

```robot
${resp}=    GET    https://example.com    expected_status=anything
Status Should Be    200    ${resp}
```

#### `Request Should Be Successful`
```
Request Should Be Successful    response=None
```
Fails if status code is 4xx or 5xx. Raises `HTTPError` on failure.

#### `Last Response`
```
${resp}=    Last response
```
Returns the response from the most recent request.

---

### File Upload

#### `Get File For Streaming Upload`
```
${file}=    Get File For Streaming Upload    path
```
Opens a file in binary read mode for use as `data` in upload requests. The requests keyword closes the file automatically.

---

## Named Status Codes

`Status Should Be` and `expected_status` accept names like:

| Name | Code |
|------|------|
| `ok` | 200 |
| `created` | 201 |
| `accepted` | 202 |
| `no content` | 204 |
| `bad request` | 400 |
| `unauthorized` | 401 |
| `forbidden` | 403 |
| `not found` | 404 |
| `conflict` | 409 |
| `internal server error` | 500 |
| `any` / `anything` | (disable assertion) |
