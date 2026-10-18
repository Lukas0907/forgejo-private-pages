# Path handling: traversal, encoding tricks and branch override must not reach other repos,
# other API endpoints or other branches. Logged in as carol, who CAN read the private repo,
# so a 404 below means the trick was blocked, not that carol lacks access.

# --- Log in to Forgejo -------------------------------------------------------
POST {{git}}/user/login
Origin: {{git}}
[Form]
user_name: carol
password: {{carol_password}}
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

# Sanity: the token can read the private site directly
GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 200
[Asserts]
body contains "{{secret_marker}}"

# --- Dot segments above the repo: rejected by nginx before proxying ----------
GET {{pages}}/{{owner}}/{{public_repo}}/../../../../user
[Options]
path-as-is: true
HTTP 400

GET {{pages}}/{{owner}}/{{public_repo}}/a/../../../../../user
[Options]
path-as-is: true
HTTP 400

GET {{pages}}/{{owner}}/{{public_repo}}/%2e%2e/%2e%2e/%2e%2e/%2e%2e/user
[Options]
path-as-is: true
HTTP 400

GET {{pages}}/{{owner}}/{{public_repo}}/..%2f..%2f..%2f..%2fuser
[Options]
path-as-is: true
HTTP 400

# --- Dot segments inside the repo path: stay inside the public repo ----------
GET {{pages}}/{{owner}}/{{public_repo}}/../{{private_repo}}/index.html
[Options]
path-as-is: true
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

GET {{pages}}/{{owner}}/{{public_repo}}/sub/../../{{private_repo}}/index.html
[Options]
path-as-is: true
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

# --- Other encodings: treated as literal file names ---------------------------
GET {{pages}}/{{owner}}/{{public_repo}}/%252e%252e/%252e%252e/user
[Options]
path-as-is: true
HTTP 404

GET {{pages}}/{{owner}}/{{public_repo}}/..%5c..%5c..%5c..%5cuser
[Options]
path-as-is: true
HTTP 404

GET {{pages}}/{{owner}}/{{public_repo}}/..;/..;/user
[Options]
path-as-is: true
HTTP 404

# --- Branch can't be switched from the URL ------------------------------------
GET {{pages}}/{{owner}}/{{private_repo}}/index.html%3Fref=main
HTTP 404

GET {{pages}}/{{owner}}/{{private_repo}}/index.html%23x
HTTP 404

# Real query strings are dropped, the branch stays `forgejo-pages`
GET {{pages}}/{{owner}}/{{private_repo}}/index.html?ref=main
HTTP 200
[Asserts]
body contains "{{secret_marker}}"

# --- "." / ".." as owner or repo: Forgejo finds no such repo (404) ----------
GET {{pages}}/./{{private_repo}}/
[Options]
path-as-is: true
HTTP 404

GET {{pages}}/{{owner}}/./
[Options]
path-as-is: true
HTTP 404

GET {{pages}}/{{owner}}/../
[Options]
path-as-is: true
HTTP 302

GET {{pages}}/{{owner}}/..
[Options]
path-as-is: true
HTTP 302

# Names that merely contain dots are still fine (Forgejo allows them)
GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 200
