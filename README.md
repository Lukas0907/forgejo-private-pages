# forgejo-private-pages

Serve static files directly by Forgejo via nginx and oauth2-proxy.
No additional service and no deploy step or actions workflow is needed.
Files are served from the `forgejo-pages` branch by default.

## Flow

1. nginx asks oauth2-proxy (`auth_request /_oauth2/auth`) whether there is a session.
   If there is no session, nginx starts the login at oauth2-proxy's `/_oauth2/start` (passing the requested URI in `X-Auth-Request-Redirect`), which redirects to Forgejo's oauth authorize endpoint.
2. After the login, oauth2-proxy gets a Forgejo access token (`read:repository read:user`) and stores it in its own encrypted cookie.
3. On later requests the auth check returns the Forgejo token in `X-Auth-Request-Access-Token`. nginx sends it to Forgejo as `Authorization: Bearer`.
   If oauth2-proxy refreshed the session, nginx passes its new `Set-Cookie` on to the browser.
4. nginx then calls Forgejo's `media` endpoint for requests to `/<owner>/<repo>/<path>`.
   Permissions are checked by Forgejo.

## Known issue if sites share one origin

A script on any repo's page can read every other repo's page the visitor has access to.
This can be fixed by having one origin for a repo (similar to GitHub), however, this complicates the setup.

Note: Of oauth2-proxy's endpoints only `/_oauth2/callback` is reachable from outside.
Among others, `/_oauth2/userinfo` is blocked to prevent scripts from accessing visitor information.

## Setup

See `conf/forgejo-private-pages.conf` and `conf/oauth2-proxy.cfg` for an example configuration.

## Publishing with Forgejo Actions (optional)

By default, everything from the `fogejo-pages` branch is served.
If an additional build step is necessary, one can use a Forgejo action that populates the branch.
See `tests/fixtures/actions/pages.yml` for an example action.

## Testing

### Automated Testing

A self-contained test suite based on Podman containers is available in `testenv`.
Run via `just test`.

### Manual Testing

To test the setup manually on your local machine:

1. **Add hostnames to `/etc/hosts`:**
   ```bash
   echo "127.0.0.1 git.test pages.test" | sudo tee -a /etc/hosts
   ```

2. **Start the test environment:**
   ```bash
   just testenv-up
   ```

3. **Access the services:**
   - **Forgejo**: http://git.test:3000
   - **Pages**: http://pages.test:3001

4. **Login credentials:**
   - Username: `alice`
   - Password: `Pass-alice-123`

5. **Try accessing a site:**
   - Navigate to http://pages.test:3001/alice/site/
   - You'll be redirected to Forgejo OAuth login
   - After logging in and granting permissions, you'll see the built page

6. **Stop and clean up:**
   ```bash
   just testenv-down
   ```
