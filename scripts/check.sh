#!/usr/bin/env bash
# Type-check, prove, and run check.bend for the named packages (default: all).
set -euo pipefail
cd "$(dirname "$0")/.."

[ $# -eq 0 ] && set -- $(scripts/packages.sh)
for d in "$@"; do
  echo "== $d"
  (
    cd "$d"
    bend "$d.bend" --check-only
    [ ! -f PROOF.bend ] || bend PROOF.bend
    [ ! -f check.bend ] || bend check.bend
  )
done
