# Visitors without a valid pages session never see content.

# Anonymous visitor: nginx's auth check fails -> login starts, sending the browser to Forgejo
# with read-only scopes...
GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 302
[Asserts]
header "Location" startsWith "{{git}}/login/oauth/authorize"
header "Location" contains "scope=openid+email+profile+read%3Arepository"

# The return URI is kept exactly (in oauth2-proxy's state "<nonce>:<redirect>"): encoded
# characters stay encoded, and the page's query string can't add or override login parameters.
# (oauth2-proxy rejects any return URI containing "//", even in the query, and falls back to "/".)
GET {{pages}}/{{owner}}/{{private_repo}}/a%26b+c?x=1&rd=/elsewhere
[Options]
path-as-is: true
HTTP 302
[Asserts]
header "Location" startsWith "{{git}}/login/oauth/authorize"
header "Location" regex "[?&]state=([^&]+)" urlDecode endsWith ":/{{owner}}/{{private_repo}}/a%26b+c?x=1&rd=/elsewhere"

# Starting the login directly isn't possible: nginx starts it itself
GET {{pages}}/_oauth2/start?rd=/{{owner}}/{{private_repo}}/
HTTP 404

# Forged callbacks fail with nginx's plain error, not oauth2-proxy's error page
GET {{pages}}/_oauth2/callback?code=forged&state=forged
HTTP 403
[Asserts]
header "Content-Type" startsWith "text/plain"
body == "Login failed\n"

GET {{pages}}/_oauth2/callback
HTTP 403
[Asserts]
body == "Login failed\n"

# ...which (not logged in to Forgejo) ends on the Forgejo login form
GET {{pages}}/{{owner}}/{{private_repo}}/
[Options]
location: true
HTTP 200
[Asserts]
url startsWith "{{git}}/user/login"
xpath "count(//input[@name='user_name'])" == 1

# Root redirects to Forgejo
GET {{pages}}/
HTTP 302

GET {{pages}}/favicon.ico
HTTP 404

# Write methods: 405 before any login (the site is read-only)
POST {{pages}}/{{owner}}/{{private_repo}}/
HTTP 405

# The session check itself isn't reachable from outside
GET {{pages}}/_oauth2/auth
HTTP 404

# Assets and public repos also require a login
GET {{pages}}/{{owner}}/{{private_repo}}/css/site.css
HTTP 302

GET {{pages}}/{{owner}}/{{public_repo}}/
HTTP 302

# Forged session cookie -> treated as no session
GET {{pages}}/{{owner}}/{{private_repo}}/
[Cookies]
_pages: forged-garbage
HTTP 302
[Asserts]
body not contains "{{secret_marker}}"

# Injected token headers without a session don't bypass oauth2-proxy
GET {{pages}}/{{owner}}/{{private_repo}}/
X-Forwarded-Access-Token: bogus
Authorization: Bearer bogus
HTTP 302
[Asserts]
header "Location" startsWith "{{git}}/login/oauth/authorize"
