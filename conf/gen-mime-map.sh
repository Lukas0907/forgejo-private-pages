#!/bin/sh
# Convert nginx's mime.types into map entries (extension -> type).
# nginx `types` don't apply to proxied responses, so the pages server needs this as a map.
#
# Usage:
#   ./gen-mime-map.sh [/etc/nginx/mime.types] > forgejo-pages-mime.conf
#
set -eu
src=${1:-/etc/nginx/mime.types}
[ -r "$src" ] || { echo "cannot read $src" >&2; exit 1; }

printf '# Converted by gen-mime-map.sh from %s. Do not edit.\n' "$src"
# Strip comments, join lines (entries may span lines), split on ';' -> one "type ext..." per line.
sed -e 's/#.*//' "$src" | tr '\n' ' ' | sed -e 's/^[^{]*{//' -e 's/}[^}]*$//' | tr ';' '\n' |
    awk 'NF >= 2 { for (i = 2; i <= NF; i++) printf "%-14s %s;\n", $i, $1 }'
