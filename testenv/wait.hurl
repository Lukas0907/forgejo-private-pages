# Wait until oauth2-proxy and nginx are up (Forgejo is already, setup waited for it).
GET http://oauth2-proxy.test:4180/ping
[Options]
retry: 60
retry-interval: 1000
HTTP 200

GET http://pages.test:3001/
[Options]
retry: 60
retry-interval: 1000
HTTP 302
