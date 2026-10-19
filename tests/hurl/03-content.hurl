# Serving from the `forgejo-pages` branch: content types, headers, URL handling (logged in as the owner).

# --- Log in to Forgejo -------------------------------------------------------
POST {{git}}/user/login
Origin: {{git}}
[Form]
user_name: {{owner}}
password: {{owner_password}}
HTTP 303

# --- Revoke any earlier grant so the consent screen always appears -----------
GET {{git}}/user/settings/applications
HTTP 200
[Captures]
revoke_url: xpath "string(//div[@class='flex-item'][.//div[@class='flex-item-title'][normalize-space()='{{oauth_app}}']]//button/@data-url)"

POST {{git}}{{revoke_url}}
Origin: {{git}}
HTTP *

# --- Visit a page: redirected to Forgejo's consent screen --------------------
GET {{pages}}/{{owner}}/{{private_repo}}/
[Options]
location: true
HTTP 200
[Captures]
client_id: xpath "string(//form[@action='/login/oauth/grant']//input[@name='client_id']/@value)"
state: xpath "string(//form[@action='/login/oauth/grant']//input[@name='state']/@value)"
scope: xpath "string(//form[@action='/login/oauth/grant']//input[@name='scope']/@value)"
nonce: xpath "string(//form[@action='/login/oauth/grant']//input[@name='nonce']/@value)"
redirect_uri: xpath "string(//form[@action='/login/oauth/grant']//input[@name='redirect_uri']/@value)"
[Asserts]
url startsWith "{{git}}/login/oauth/authorize"
xpath "string(//button[@id='authorize-app']/@value)" == "true"
xpath "string(//form[@action='/login/oauth/grant']//input[@name='scope']/@value)" contains "read:repository"
xpath "string(//form[@action='/login/oauth/grant']//input[@name='scope']/@value)" not contains "write:"

# --- Approve -> Forgejo redirects to the pages callback with a code ----------
POST {{git}}/login/oauth/grant
Origin: {{git}}
[Form]
client_id: {{client_id}}
state: {{state}}
scope: {{scope}}
nonce: {{nonce}}
redirect_uri: {{redirect_uri}}
granted: true
HTTP *
[Captures]
callback: header "Location"
[Asserts]
status >= 300
status < 400
header "Location" startsWith "{{pages}}/_oauth2/callback?code="

# --- Callback sets the pages session cookie ---------------------------------
GET {{callback}}
HTTP 302

# --- Directory index, headers -------------------------------------------------
GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 200
[Captures]
etag: header "ETag"
[Asserts]
header "Content-Type" == "text/html"
header "Cache-Control" == "private, no-cache"
header "X-Content-Type-Options" == "nosniff"
header "Content-Disposition" not exists
header "Referrer-Policy" == "same-origin"
header "Allow" not exists
header "Cross-Origin-Opener-Policy" == "same-origin"
header "ETag" exists
body contains "{{secret_marker}}"

# --- Content types: exactly what mime.types says, case-insensitive ------------
GET {{pages}}/{{owner}}/{{private_repo}}/css/site.css
HTTP 200
[Asserts]
header "Content-Type" == "text/css"

GET {{pages}}/{{owner}}/{{private_repo}}/app.js
HTTP 200
[Asserts]
header "Content-Type" == "application/javascript"

GET {{pages}}/{{owner}}/{{private_repo}}/logo.svg
HTTP 200
[Asserts]
header "Content-Type" == "image/svg+xml"

GET {{pages}}/{{owner}}/{{private_repo}}/UPPER.HTML
HTTP 200
[Asserts]
header "Content-Type" == "text/html"

# Entry that spans two lines in mime.types
GET {{pages}}/{{owner}}/{{private_repo}}/doc.docx
HTTP 200
[Asserts]
header "Content-Type" == "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

# Local addition in forgejo-private-pages.conf (not in mime.types)
GET {{pages}}/{{owner}}/{{private_repo}}/mod.mjs
HTTP 200
[Asserts]
header "Content-Type" == "application/javascript"

# Not in mime.types, no extension, unknown -> octet-stream
GET {{pages}}/{{owner}}/{{private_repo}}/site.webmanifest
HTTP 200
[Asserts]
header "Content-Type" == "application/octet-stream"

GET {{pages}}/{{owner}}/{{private_repo}}/LICENSE
HTTP 200
[Asserts]
header "Content-Type" == "application/octet-stream"
header "X-Content-Type-Options" == "nosniff"

GET {{pages}}/{{owner}}/{{private_repo}}/data.xyz
HTTP 200
[Asserts]
header "Content-Type" == "application/octet-stream"

# A dot in a directory name is not an extension
# Dot files and dot directories are never served (they exist, see 00-fixtures), also encoded
GET {{pages}}/{{owner}}/{{private_repo}}/.env
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

GET {{pages}}/{{owner}}/{{private_repo}}/%2eenv
HTTP 404

GET {{pages}}/{{owner}}/{{private_repo}}/%2Eenv
HTTP 404

GET {{pages}}/{{owner}}/{{private_repo}}/sub/.hidden/file.txt
HTTP 404

GET {{pages}}/{{owner}}/{{private_repo}}/sub/%2Ehidden/
HTTP 404

GET {{pages}}/{{owner}}/{{private_repo}}/sub%2F.hidden/file.txt
HTTP 404

# Backslashes: nginx's filter only looks for a dot after "/" or "%2f", so these reach Forgejo.
# They must not, if Forgejo turns "\" into "/" in the tree path.
GET {{pages}}/{{owner}}/{{private_repo}}/%5c.env
[Options]
path-as-is: true
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

GET {{pages}}/{{owner}}/{{private_repo}}/x%5C..%5C.env
[Options]
path-as-is: true
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

GET {{pages}}/{{owner}}/{{private_repo}}/sub%5c.hidden/file.txt
[Options]
path-as-is: true
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

GET {{pages}}/{{owner}}/{{private_repo}}/sub%5C.hidden%5Cfile.txt
[Options]
path-as-is: true
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

GET {{pages}}/{{owner}}/{{private_repo}}/sub%5c%2ehidden/file.txt
[Options]
path-as-is: true
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

GET {{pages}}/{{owner}}/{{private_repo}}/sub\\.hidden/file.txt
[Options]
path-as-is: true
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

GET {{pages}}/{{owner}}/{{private_repo}}/v1.2/page
HTTP 200
[Asserts]
header "Content-Type" == "application/octet-stream"

# Exactly one Content-Type header
GET {{pages}}/{{owner}}/{{private_repo}}/css/site.css
HTTP 200
[Asserts]
header "Content-Type" isString        # a duplicate header would be a list

# --- URL handling ---------------------------------------------------------------
GET {{pages}}/{{owner}}/{{private_repo}}/sub/
HTTP 200
[Asserts]
body contains "sub index"

GET {{pages}}/{{owner}}/{{private_repo}}/with%20space.html
HTTP 200
[Asserts]
body contains "encoded path"

GET {{pages}}/{{owner}}/{{private_repo}}/index.html?utm=x&v=2
HTTP 200
[Asserts]
header "Content-Type" == "text/html"

# Partial content (Range is forwarded to Forgejo)
GET {{pages}}/{{owner}}/{{private_repo}}/css/site.css
Range: bytes=0-3
HTTP 206
[Asserts]
header "Content-Range" startsWith "bytes 0-3/"
body == "body"

# Unchanged content -> 304 via ETag
GET {{pages}}/{{owner}}/{{private_repo}}/
If-None-Match: {{etag}}
HTTP 304

# /owner/repo -> /owner/repo/
GET {{pages}}/{{owner}}/{{private_repo}}
HTTP 301
[Asserts]
header "Location" == "{{pages}}/{{owner}}/{{private_repo}}/"

# ...keeping the query string
GET {{pages}}/{{owner}}/{{private_repo}}?x=1
HTTP 301
[Asserts]
header "Location" == "{{pages}}/{{owner}}/{{private_repo}}/?x=1"

# Missing file -> 404 with nginx's own plain text, not the file type
GET {{pages}}/{{owner}}/{{private_repo}}/missing.html
HTTP 404
[Asserts]
header "Content-Type" startsWith "text/plain"

# Read-only: HEAD works (headers only), anything else is refused
HEAD {{pages}}/{{owner}}/{{private_repo}}/
HTTP 200
[Asserts]
header "Content-Type" == "text/html"
bytes count == 0

POST {{pages}}/{{owner}}/{{private_repo}}/
HTTP 405
[Asserts]
header "Allow" == "GET, HEAD"
body not contains "{{secret_marker}}"

DELETE {{pages}}/{{owner}}/{{private_repo}}/index.html
HTTP 405

# Redirect to Forgejo
GET {{pages}}/
HTTP 302

GET {{pages}}/favicon.ico
HTTP 404

GET {{pages}}/{{owner}}/
HTTP 404

# Encoded owner/repo names never reach the API
GET {{pages}}/{{owner}}/%64ocs/
HTTP 404
