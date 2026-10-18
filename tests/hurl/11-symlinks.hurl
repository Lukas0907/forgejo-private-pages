# Symlinks in the pages branch (pushed by testenv/setup.sh): Forgejo never follows them.
# The media API returns the link's target path as the content (X-Forgejo-Object-Type: symlink),
# so nothing outside the repo, and no other file of it, is reachable through a link.
# nginx serves anything that isn't a plain file as application/octet-stream (download, never rendered).

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

GET {{pages}}/{{owner}}/{{links_repo}}/
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

# --- Links inside the repo: the link text, not the target's content -------------
GET {{pages}}/{{owner}}/{{links_repo}}/rel.html
HTTP 200
[Asserts]
header "Content-Type" == "application/octet-stream"
header "X-Forgejo-Object-Type" not exists
header "X-Gitea-Object-Type" not exists
body == "index.html"

GET {{pages}}/{{owner}}/{{links_repo}}/dangling.html
HTTP 200
[Asserts]
header "Content-Type" == "application/octet-stream"
body == "missing.html"

# --- Links pointing outside the repo: still only the link text ---------------
GET {{pages}}/{{owner}}/{{links_repo}}/abs.txt
HTTP 200
[Asserts]
header "Content-Type" == "application/octet-stream"
body == "/etc/passwd"
body not contains "root:"

GET {{pages}}/{{owner}}/{{links_repo}}/up.txt
HTTP 200
[Asserts]
header "Content-Type" == "application/octet-stream"
body == "../../../../etc/passwd"
body not contains "root:"

# --- Directory links are not traversed ----------------------------------------
GET {{pages}}/{{owner}}/{{links_repo}}/dirlink/index.html
HTTP 404
[Asserts]
body not contains "{{secret_marker}}"

GET {{pages}}/{{owner}}/{{links_repo}}/dirlink/
HTTP 404

# --- The real files are there (control) --------------------------------------
GET {{pages}}/{{owner}}/{{links_repo}}/sub/
HTTP 200
[Asserts]
header "Content-Type" == "text/html"
body contains "{{secret_marker}} sub"

# Partial and conditional requests for a link: also octet-stream
GET {{pages}}/{{owner}}/{{links_repo}}/rel.html
Range: bytes=0-3
HTTP 206
[Captures]
etag: header "ETag"
[Asserts]
header "Content-Type" == "application/octet-stream"

GET {{pages}}/{{owner}}/{{links_repo}}/rel.html
If-None-Match: {{etag}}
HTTP 304
[Asserts]
header "Content-Type" == "application/octet-stream"
