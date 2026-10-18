# Test fixtures. Idempotent: "already exists" answers are accepted (HTTP *), then verified.
# Needs an existing admin account ({{owner}}); creates bob + carol, two repos, `forgejo-pages` branches.

POST {{admin_api}}/admin/users
[BasicAuth]
{{owner}}: {{owner_password}}
{"username": "bob", "email": "bob@example.test", "password": "{{bob_password}}", "must_change_password": false}
HTTP *

POST {{admin_api}}/admin/users
[BasicAuth]
{{owner}}: {{owner_password}}
{"username": "carol", "email": "carol@example.test", "password": "{{carol_password}}", "must_change_password": false}
HTTP *

POST {{admin_api}}/user/repos
[BasicAuth]
{{owner}}: {{owner_password}}
{"name": "{{private_repo}}", "private": true}
HTTP *

POST {{admin_api}}/user/repos
[BasicAuth]
{{owner}}: {{owner_password}}
{"name": "{{public_repo}}", "private": false}
HTTP *

PUT {{admin_api}}/repos/{{owner}}/{{private_repo}}/collaborators/carol
[BasicAuth]
{{owner}}: {{owner_password}}
{"permission": "read"}
HTTP 204

POST {{admin_api}}/repos/{{owner}}/{{private_repo}}/contents
[BasicAuth]
{{owner}}: {{owner_password}}
{
  "new_branch": "forgejo-pages",
  "message": "pages fixtures",
  "files": [
    {
      "operation": "create",
      "path": "index.html",
      "content": "PCFkb2N0eXBlIGh0bWw+PHRpdGxlPmRvY3M8L3RpdGxlPjxoMT5TRUNSRVQgZG9jczwvaDE+PGxpbmsgcmVsPXN0eWxlc2hlZXQgaHJlZj1jc3Mvc2l0ZS5jc3M+PHNjcmlwdCBzcmM9YXBwLmpzPjwvc2NyaXB0Pg=="
    },
    {
      "operation": "create",
      "path": "css/site.css",
      "content": "Ym9keXtmb250LWZhbWlseTpzYW5zLXNlcmlmfQ=="
    },
    {
      "operation": "create",
      "path": "app.js",
      "content": "Y29uc29sZS5sb2coInBhZ2VzIik="
    },
    {
      "operation": "create",
      "path": "logo.svg",
      "content": "PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxIiBoZWlnaHQ9IjEiLz4="
    },
    {
      "operation": "create",
      "path": "sub/index.html",
      "content": "PGgxPlNFQ1JFVCBzdWIgaW5kZXg8L2gxPg=="
    },
    {
      "operation": "create",
      "path": "with space.html",
      "content": "PGgxPlNFQ1JFVCBlbmNvZGVkIHBhdGg8L2gxPg=="
    },
    {
      "operation": "create",
      "path": ".env",
      "content": "U0VDUkVUIGRvdGZpbGUK"
    },
    {
      "operation": "create",
      "path": "sub/.hidden/file.txt",
      "content": "U0VDUkVUIGRvdGZpbGUK"
    }
  ]
}
HTTP *

POST {{admin_api}}/repos/{{owner}}/{{public_repo}}/contents
[BasicAuth]
{{owner}}: {{owner_password}}
{
  "new_branch": "forgejo-pages",
  "message": "pages fixtures",
  "files": [
    {
      "operation": "create",
      "path": "index.html",
      "content": "PGgxPlBVQkxJQyBzaXRlPC9oMT4="
    }
  ]
}
HTTP *

# Content-type fixtures (separate commit on the existing branch)
POST {{admin_api}}/repos/{{owner}}/{{private_repo}}/contents
[BasicAuth]
{{owner}}: {{owner_password}}
{
  "branch": "forgejo-pages",
  "message": "content-type fixtures",
  "files": [
    {
      "operation": "create",
      "path": "UPPER.HTML",
      "content": "PGgxPlNFQ1JFVCB1cHBlcjwvaDE+"
    },
    {
      "operation": "create",
      "path": "mod.mjs",
      "content": "ZXhwb3J0IGRlZmF1bHQgMQ=="
    },
    {
      "operation": "create",
      "path": "site.webmanifest",
      "content": "eyJuYW1lIjoiZG9jcyJ9"
    },
    {
      "operation": "create",
      "path": "LICENSE",
      "content": "TUlU"
    },
    {
      "operation": "create",
      "path": "data.xyz",
      "content": "Pz8/"
    },
    {
      "operation": "create",
      "path": "v1.2/page",
      "content": "bm8gZXh0ZW5zaW9uLCBkb3R0ZWQgZGly"
    }
  ]
}
HTTP *

# Multi-line mime.types entry (docx)
POST {{admin_api}}/repos/{{owner}}/{{private_repo}}/contents
[BasicAuth]
{{owner}}: {{owner_password}}
{"branch": "forgejo-pages", "message": "docx fixture", "files": [{"operation": "create", "path": "doc.docx", "content": "UEsgZmFrZSBkb2N4"}]}
HTTP *

# --- Verify -------------------------------------------------------------------
GET {{admin_api}}/repos/{{owner}}/{{private_repo}}
[BasicAuth]
{{owner}}: {{owner_password}}
HTTP 200
[Asserts]
jsonpath "$.private" == true

GET {{admin_api}}/repos/{{owner}}/{{public_repo}}
HTTP 200
[Asserts]
jsonpath "$.private" == false

GET {{admin_api}}/repos/{{owner}}/{{private_repo}}/collaborators/carol
[BasicAuth]
{{owner}}: {{owner_password}}
HTTP 204

GET {{admin_api}}/repos/{{owner}}/{{private_repo}}/raw/with%20space.html?ref=forgejo-pages
[BasicAuth]
{{owner}}: {{owner_password}}
HTTP 200
[Asserts]
body contains "{{secret_marker}}"

GET {{admin_api}}/repos/{{owner}}/{{private_repo}}/raw/.env?ref=forgejo-pages
[BasicAuth]
{{owner}}: {{owner_password}}
HTTP 200

GET {{admin_api}}/repos/{{owner}}/{{private_repo}}/raw/v1.2/page?ref=forgejo-pages
[BasicAuth]
{{owner}}: {{owner_password}}
HTTP 200

GET {{admin_api}}/repos/{{owner}}/{{public_repo}}/raw/index.html?ref=forgejo-pages
HTTP 200
[Asserts]
body contains "{{public_marker}}"
