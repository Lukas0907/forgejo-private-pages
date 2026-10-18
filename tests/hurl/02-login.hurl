# Full browser login as the owner: oauth2-proxy session behaviour.

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

# --- Callback sets the pages session cookie and sends us back ---------------
GET {{callback}}
HTTP 302
[Asserts]
cookie "_pages" exists
cookie "_pages[HttpOnly]" exists
cookie "_pages[SameSite]" == "Lax"
header "Location" == "/{{owner}}/{{private_repo}}/"

GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 200
[Asserts]
body contains "{{secret_marker}}"

# Token headers sent by the client are ignored: nginx uses the token from its own auth check
GET {{pages}}/{{owner}}/{{private_repo}}/
X-Forwarded-Access-Token: bogus
Authorization: Bearer bogus
HTTP 200
[Asserts]
body contains "{{secret_marker}}"

# nginx passes the raw path; Forgejo resolves %2e%2e inside the public repo only (even with access)
GET {{pages}}/{{owner}}/{{public_repo}}/%2e%2e/{{private_repo}}/
[Options]
path-as-is: true                 # else curl turns %2e%2e into a dot segment and removes it
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

GET {{pages}}/{{owner}}/{{public_repo}}/
HTTP 200
[Asserts]
body contains "{{public_marker}}"

# --- Sign out endpoint is blocked ----------------------------
GET {{pages}}/_oauth2/sign_out
HTTP 404
