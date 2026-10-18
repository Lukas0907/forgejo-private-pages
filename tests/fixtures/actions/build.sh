#!/bin/sh
# Example build: writes the site into the directory given as $1.
set -eu
cat > "index.html" <<HTML
<!doctype html><meta charset="utf-8"><title>site</title>
<h1>Built from ${FORGEJO_SHA:-a local run}</h1>
HTML
