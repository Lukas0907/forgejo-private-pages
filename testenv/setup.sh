#!/bin/sh
# Runs once in the Forgejo image (compose service `setup`): wait for the API, create the admin
# account and the OAuth2 application, write oauth2-proxy.cfg with the real credentials to /out.
set -eu
api=http://forgejo:3000/api/v1        # Forgejo container; no test cookies on this name

# Admin credentials come from the test variables, so they're defined in one place only
var() { sed -n "s/^$1=//p" /testenv/vars.env; }
ADMIN_USER=$(var owner)
ADMIN_PASSWORD=$(var owner_password)
[ -n "$ADMIN_USER" ] && [ -n "$ADMIN_PASSWORD" ] || { echo "setup: owner/owner_password missing in vars.env" >&2; exit 1; }

i=0
until curl -fsS -o /dev/null "$api/version" 2>/dev/null; do
    i=$((i + 1)); [ "$i" -le 120 ] || { echo "setup: Forgejo did not come up" >&2; exit 1; }
    sleep 1
done

su git -c "forgejo admin user create --admin --username $ADMIN_USER --password $ADMIN_PASSWORD \
    --email $ADMIN_USER@example.test --must-change-password=false" >/dev/null 2>&1 \
    || echo "setup: admin $ADMIN_USER already exists"

app=$(curl -fsS -u "$ADMIN_USER:$ADMIN_PASSWORD" -H 'Content-Type: application/json' \
    -X POST "$api/user/applications/oauth2" \
    -d '{"name":"pages","redirect_uris":["http://pages.test:3001/_oauth2/callback"],"confidential_client":true}')
client_id=$(printf '%s' "$app" | sed -n 's/.*"client_id":"\([^"]*\)".*/\1/p')
client_secret=$(printf '%s' "$app" | sed -n 's/.*"client_secret":"\([^"]*\)".*/\1/p')
[ -n "$client_id" ] && [ -n "$client_secret" ] || { echo "setup: could not create OAuth2 app: $app" >&2; exit 1; }
cookie_secret=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')

sed -e "s|^client_id .*|client_id             = \"$client_id\"|" \
    -e "s|^client_secret .*|client_secret         = \"$client_secret\"|" \
    -e "s|^cookie_secret .*|cookie_secret         = \"$cookie_secret\"|" \
    -e "s|^http_address .*|http_address          = \"0.0.0.0:4180\"   # test only: reachable from the nginx container|" \
    -e "s|^cookie_refresh .*|cookie_refresh        = \"5s\"   # test only: exercise session refresh quickly|" \
    -e "s|^oidc_issuer_url .*|oidc_issuer_url       = \"http://git.test:3000\"|" \
    -e "s|^redirect_url .*|redirect_url          = \"http://pages.test:3001/_oauth2/callback\"|" \
    /testenv/oauth2-proxy.cfg.template > /out/oauth2-proxy.cfg
chmod 0644 /out/oauth2-proxy.cfg     # oauth2-proxy image runs as non-root
echo "setup: OAuth2 app created (client_id $client_id)"

# --- Actions: runner + example site (tests/fixtures/actions/pages.yml builds alice/site into its forgejo-pages branch)
runner_secret=$(od -An -tx1 -N20 /dev/urandom | tr -d ' \n')
su git -c "forgejo forgejo-cli actions register --name testenv-runner --labels host --secret $runner_secret" >/dev/null
printf '%s' "$runner_secret" > /runner/runner-secret

auth="-u $ADMIN_USER:$ADMIN_PASSWORD"
curl -fsS -o /dev/null $auth -H 'Content-Type: application/json' -X POST "$api/user/repos" \
    -d '{"name":"'"$(var site_repo)"'","private":true,"auto_init":true,"default_branch":"main"}'
# One commit with both files; its push event starts the first build
wf=$(base64 -w0 /testenv/fixtures/actions/pages.yml)
curl -fsS -o /dev/null $auth -H 'Content-Type: application/json' -X POST "$api/repos/$ADMIN_USER/$(var site_repo)/contents" \
    -d "{\"branch\":\"main\",\"message\":\"add pages workflow\",\"files\":[
         {\"operation\":\"create\",\"path\":\".forgejo/workflows/pages.yml\",\"content\":\"$wf\"}]}"
echo "setup: runner registered, $ADMIN_USER/$(var site_repo) created"

# --- Symlinks (11-symlinks): the contents API can't create them, so push with git
links=$(var links_repo)
curl -fsS -o /dev/null $auth -H 'Content-Type: application/json' -X POST "$api/user/repos" \
    -d "{\"name\":\"$links\",\"private\":true}"
d=$(mktemp -d) && cd "$d"
git init -q -b forgejo-pages .
mkdir sub
echo '<h1>SECRET index</h1>' > index.html
echo '<h1>SECRET sub</h1>' > sub/index.html
ln -s index.html rel.html                    # inside the repo
ln -s /etc/passwd abs.txt                    # absolute, outside
ln -s ../../../../etc/passwd up.txt          # relative, outside
ln -s sub dirlink                            # directory
ln -s missing.html dangling.html             # target doesn't exist
git add -A
git -c user.name=setup -c user.email=setup@example.test commit -qm symlinks
git push -q "http://$ADMIN_USER:$ADMIN_PASSWORD@forgejo:3000/$ADMIN_USER/$links.git" HEAD:forgejo-pages
cd / && rm -rf "$d"
echo "setup: $ADMIN_USER/$links pushed"
