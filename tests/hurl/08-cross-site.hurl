# What stops other websites from using a logged-in visitor's session: SameSite=Lax cookies
# (browsers don't send the session on cross-site embeds or fetches), CORP same-origin on content,
# no CORS headers, frame-ancestors. Hurl itself always sends the cookie, so these tests check the
# headers that make browsers refuse; enforcement is the browser's job.

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

# --- Callback: session cookie must be SameSite=Lax ----------------------------
GET {{callback}}
HTTP 302
[Asserts]
cookie "_pages" exists
cookie "_pages[HttpOnly]" exists
cookie "_pages[SameSite]" == "Lax"

# --- Content: no embedding or reading by other origins -------------------------
GET {{pages}}/{{owner}}/{{private_repo}}/app.js
Origin: https://other.example
HTTP 200
[Asserts]
header "Cross-Origin-Resource-Policy" == "same-origin"
header "Access-Control-Allow-Origin" not exists
header "Access-Control-Allow-Credentials" not exists
header "Access-Control-Expose-Headers" not exists

# OAuth2 userinfo endpoint is blocked for security
GET {{pages}}/_oauth2/userinfo
Origin: https://other.example
HTTP 404
