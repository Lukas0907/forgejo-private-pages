# Access changes in Forgejo apply on the very next request (no cache).

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

# Read-only collaborator sees the private site
GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 200
[Asserts]
body contains "{{secret_marker}}"

# Owner removes carol as collaborator (admin_api host gets no test cookies)
DELETE {{admin_api}}/repos/{{owner}}/{{private_repo}}/collaborators/carol
[BasicAuth]
{{owner}}: {{owner_password}}
HTTP 204

GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 404

# Restore carol
PUT {{admin_api}}/repos/{{owner}}/{{private_repo}}/collaborators/carol
[BasicAuth]
{{owner}}: {{owner_password}}
{"permission": "read"}
HTTP 204

GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 200

# Carol revokes the app grant in Forgejo -> her token dies -> sent back through login
GET {{git}}/user/settings/applications
HTTP 200
[Captures]
revoke_url: xpath "string(//div[@class='flex-item'][.//div[@class='flex-item-title'][normalize-space()='{{oauth_app}}']]//button/@data-url)"
[Asserts]
xpath "string(//div[@class='flex-item'][.//div[@class='flex-item-title'][normalize-space()='{{oauth_app}}']]//button/@data-url)" contains "/revoke/"

POST {{git}}{{revoke_url}}
Origin: {{git}}
HTTP 200

GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 302
[Asserts]
header "Location" startsWith "{{git}}/login/oauth/authorize"
body not contains "{{secret_marker}}"
