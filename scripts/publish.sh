#!/usr/bin/env bash
# Publish the named packages (default: all) as bend-kit-<pkg>@<VERSION>.
# A version already on the hub is skipped; the hub rejects a republish.
set -euo pipefail
cd "$(dirname "$0")/.."

hub=${BEND_HUB:-https://hub.bend-lang.com}
[ $# -eq 0 ] && set -- $(scripts/packages.sh)
for d in "$@"; do
  named=bend-kit-$d@$(<"$d/VERSION")
  if curl -fs -o /dev/null "$hub/name/$named"; then
    echo "== $named is on the hub"
  else
    echo "== publish $named"
    (cd "$d" && bend "$d.bend" --publish "$named")
  fi
done
