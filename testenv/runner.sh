#!/bin/sh
# Forgejo runner, registered with the shared secret that setup.sh also gave Forgejo.
set -eu
cd /data
forgejo-runner create-runner-file --instance http://forgejo:3000 --name testenv-runner \
    --secret "$(cat /secret/runner-secret)"
exec forgejo-runner daemon --config /testenv/runner.yaml
