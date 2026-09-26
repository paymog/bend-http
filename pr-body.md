## Summary

Speed up `Http.parse` / `parse.got` on the codec bench (#109). This pass adds a **native phase breakdown**, folds header-name lowercasing into `split_colon`, and keeps the earlier `split_at_blank` offset scan.

**Bench (M4 Pro, median of 5× `python3 http/bench/run.py 5`):**

| op | before (0.15.0.1) | this branch (0.15.0.3) |
|---|---:|---:|
| `parse_req` | ~865 ms | **820 ms** (~5%; run-to-run noise) |
| `parse_res` | ~661 ms | **617 ms** |

We did **not** hit the ≥20% goal on `parse_req`; the breakdown below shows why.

## Parse phase breakdown (20 000 × 451-byte request)

From `http/bench/parse_phases.bend` (one native run):

| phase | ms | notes |
|---|---:|---|
| **full** | 869 | `Http.parse` |
| split | 70 | `split_at_blank.scan.go` |
| whole | 174 | `ends_with` terminator check |
| lines | 187 | `String.lines` |
| start_line | 197 | first line → method/path/version |
| **field_ops** | 447 | per header: `drop_cr`, `split_colon` (+ lower), `trim` |
| **map_build** | 649 | `parse.headers` → `Map` |
| head_got | 864 | `parse.got` through head |
| body_len | 683 | body length / hold |

**Top costs:** `map_build` + `field_ops` (and the line list from `String.lines`), not blank split. That matches the char-list `String` + linked `Map` story in #126.

## Code changes

- `split_at_blank.scan.go`: offset scan + `String.take` (runtime); proof path unchanged.
- `split_colon.go`: lowercase header names while scanning for `:` (drops separate `String.to_lower` on names).
- `http/bench/parse_phases.bend`: scratch native timings per stage.
- `http/bench/README.md`: updated medians + how to run phases.

## One-pass head parser (attempted, not merged)

Tried a single-pass head walk (no `String.lines` / intermediate line strings). A workable design needs `scan → emit → tok → scan`, but Bend’s **define-before-use** ordering blocks every factoring we tried (helpers that tail-call `scan` must sit after `scan`, while `scan` must call them on `\n`). Inlining hits **no match on computed scrutinees** (e.g. destructuring `start_line(line)` inside `scan`). Keeping behavior identical and laws green without a large monolithic `scan` is follow-up—likely paired with #126 (string/Map representation).

## Proof / check

- `bend PROOF.bend` / `scripts/check.sh http` — green (no law edits).

## Follow-up (#126)

- One-pass head + cheaper field store / Map build once representation work lands.
- Re-run phases after any of: list-backed headers, `Map.from_list`, or bytes-style strings.
