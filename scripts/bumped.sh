#!/usr/bin/env bash
# Fail when a package's published files changed since a git ref but its VERSION did not.
set -euo pipefail
cd "$(dirname "$0")/.."

changed=$(git diff --name-only "$1"...HEAD)
fail=0
for d in $(scripts/packages.sh "$1"); do
  grep -qE "^$d/($d\.bend|effs/)" <<<"$changed" || continue
  grep -qx "$d/VERSION" <<<"$changed" && continue
  echo "$d: $d.bend or effs/ changed; raise $d/VERSION"
  fail=1
done
exit $fail
