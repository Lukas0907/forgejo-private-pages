# Visitors without a valid pages session never see content.

# Anonymous visitor: nginx's auth check fails -> login start...
GET {{pages}}/{{owner}}/{{private_repo}}/
HTTP 302
[Asserts]
header "Location" == "{{pages}}/_oauth2/start?rd=/{{owner}}/{{private_repo}}/"

# ...which sends the browser to Forgejo with read-only scopes...
GET {{pages}}/_oauth2/start?rd=/{{owner}}/{{private_repo}}/
HTTP 302
[Asserts]
header "Location" startsWith "{{git}}/login/oauth/authorize"
header "Location" contains "scope=openid+email+profile+read%3Arepository"

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
header "Location" == "{{pages}}/_oauth2/start?rd=/{{owner}}/{{private_repo}}/"
