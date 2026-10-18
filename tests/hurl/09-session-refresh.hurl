# Session refresh: oauth2-proxy refreshes the Forgejo token during nginx's auth check and returns a
# new cookie, which nginx must pass on to the browser. Needs cookie_refresh < 6s, which the test
# environment sets (testenv/setup.sh); against a setup with the production value this file fails.

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

GET {{callback}}
HTTP 302
[Asserts]
cookie "_pages" exists

GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 200
[Asserts]
cookie "_pages" not exists          # fresh session: nothing to refresh yet

# After cookie_refresh: the auth check refreshes, and the new cookie reaches the browser
GET {{pages}}/{{owner}}/{{private_repo}}/
[Options]
delay: 6000
HTTP 200
[Captures]
refreshed: cookie "_pages"
[Asserts]
cookie "_pages" exists
cookie "_pages[HttpOnly]" exists
body contains "{{secret_marker}}"

# The refreshed session works
GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 200
[Asserts]
body contains "{{secret_marker}}"
