#!/usr/bin/env bash
# Print the packages, one per line. With a git ref, print only the packages
# changed since that ref; a change to CI or scripts selects every package.
set -euo pipefail
cd "$(dirname "$0")/.."

all() { for f in */*.bend; do d=${f%%/*}; [ "$f" = "$d/$d.bend" ] && echo "$d"; done; }

[ $# -eq 0 ] && { all; exit; }

changed=$(git diff --name-only "$1"...HEAD)
if grep -qE '^(\.github|scripts)/' <<<"$changed"; then all; exit; fi
all | while read -r d; do grep -q "^$d/" <<<"$changed" && echo "$d"; done || true
