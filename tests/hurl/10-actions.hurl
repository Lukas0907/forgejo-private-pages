# Actions flow (testenv runner): tests/fixtures/actions/pages.yml builds alice/site into its `forgejo-pages` branch.
# Each build pushes a single parentless commit with only the build output; the site shows the new build.

# --- Log in (Forgejo + consent), as in 04 -------------------------------------
POST {{git}}/user/login
Origin: {{git}}
[Form]
user_name: {{owner}}
password: {{owner_password}}
HTTP 303

GET {{git}}/user/settings/applications
HTTP 200
[Captures]
revoke_url: xpath "string(//div[@class='flex-item'][.//div[@class='flex-item-title'][normalize-space()='{{oauth_app}}']]//button/@data-url)"

POST {{git}}{{revoke_url}}
Origin: {{git}}
HTTP *

GET {{pages}}/{{owner}}/{{site_repo}}/
[Options]
location: true
HTTP 200
[Captures]
client_id: xpath "string(//form[@action='/login/oauth/grant']//input[@name='client_id']/@value)"
state: xpath "string(//form[@action='/login/oauth/grant']//input[@name='state']/@value)"
scope: xpath "string(//form[@action='/login/oauth/grant']//input[@name='scope']/@value)"
nonce: xpath "string(//form[@action='/login/oauth/grant']//input[@name='nonce']/@value)"
redirect_uri: xpath "string(//form[@action='/login/oauth/grant']//input[@name='redirect_uri']/@value)"

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

GET {{callback}}
HTTP 302

# --- First build (started by setup's commit) ---------------------------------
GET {{pages}}/{{owner}}/{{site_repo}}/
[Options]
retry: 120
retry-interval: 1000
HTTP 200
[Asserts]
header "Content-Type" == "text/html"
body contains "Built from "

GET {{admin_api}}/repos/{{owner}}/{{site_repo}}/commits?sha=forgejo-pages&stat=false
[BasicAuth]
{{owner}}: {{owner_password}}
HTTP 200
[Asserts]
jsonpath "$" count == 1

# --- Push to main -> rebuild; the forgejo-pages branch still has one commit ----------
POST {{admin_api}}/repos/{{owner}}/{{site_repo}}/contents/trigger-{{newUuid}}.txt
[BasicAuth]
{{owner}}: {{owner_password}}
{
  "branch": "main",
  "message": "trigger build",
  "content": "dHJpZ2dlcgo="
}
HTTP 201
[Captures]
second_sha: jsonpath "$.commit.sha"

GET {{pages}}/{{owner}}/{{site_repo}}/
[Options]
retry: 120
retry-interval: 1000
HTTP 200
[Asserts]
body contains "Built from {{second_sha}}"

GET {{admin_api}}/repos/{{owner}}/{{site_repo}}/commits?sha=forgejo-pages&stat=false
[BasicAuth]
{{owner}}: {{owner_password}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].commit.message" contains "{{second_sha}}"
jsonpath "$[0].parents" isEmpty

# Only the build output is on the branch: no workflow, no build.sh, no trigger files
GET {{admin_api}}/repos/{{owner}}/{{site_repo}}/contents?ref=forgejo-pages
[BasicAuth]
{{owner}}: {{owner_password}}
HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].name" == "index.html"
