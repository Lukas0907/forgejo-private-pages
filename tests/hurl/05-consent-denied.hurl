# A user who declines the consent screen gets no session, even with repo access.

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

POST {{git}}/login/oauth/grant
Origin: {{git}}
[Form]
client_id: {{client_id}}
state: {{state}}
scope: {{scope}}
nonce: {{nonce}}
redirect_uri: {{redirect_uri}}
granted: false
HTTP *
[Captures]
callback: header "Location"
[Asserts]
header "Location" startsWith "{{pages}}/_oauth2/callback?error=access_denied"

# oauth2-proxy's error page is replaced by nginx's plain one
GET {{callback}}
HTTP 403
[Asserts]
header "Content-Type" startsWith "text/plain"
body == "Login failed\n"
cookie "_pages" not exists

GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 302
[Asserts]
header "Location" startsWith "{{git}}/login/oauth/authorize"
