## Summary

Speed up `Http.parse` on the codec bench (**Refs #109**). This PR ships measurable but **sub‑20%** wins plus a native phase breakdown; the one-pass head walk is blocked on Bend’s define-before-use / no-mutual-recursion rules (see below).

**Bench (M4 Pro, median of 5× `python3 http/bench/run.py 5`):**

| op | baseline (0.15.0.1 README) | this branch (0.15.0.3) |
|---|---:|---:|
| `parse_req` | ~865 ms | **~820 ms** (~5%; run-to-run ~676–816 ms) |
| `parse_res` | ~661 ms | **~617 ms** |

Target for closing #109 was **≥20%** (~692 ms on `parse_req`); not met reliably.

## Parse phase breakdown (20 000 × 451-byte request)

`http/bench/parse_phases.bend` (one native run):

| phase | ms | notes |
|---|---:|---|
| **full** | ~870 | `Http.parse` |
| split | ~70 | `split_at_blank.scan` |
| **whole** | ~174 | `ends_with(head, "\r\n\r\n")` — still required: using split’s “found blank” flag as `whole` **broke** `LAWS.req_te_other_bad` (reverted) |
| lines | ~187 | `String.lines` |
| start_line | ~197 | first line |
| **field_ops** | ~447 | `drop_cr`, `split_colon` (+ inline lower), `trim` |
| **map_build** | ~649 | `parse.headers` → `Map` |

Top costs remain **map_build + field_ops + line list**, not blank split (#126).

## Code changes

- `split_at_blank.scan.go` offset scan (earlier commit).
- `split_colon.go`: lowercase header names while scanning; `fields_put.kv` skips separate `String.to_lower` on keys.
- `http/bench/parse_phases.bend` + README section.

## One-pass head (attempted, not merged)

Per AGENTS.md: merge scan + line dispatch into **one** def with a mode selector, shrinking `String` first. Every factoring we tried hit either:

- **mutual recursion** (`go` ↔ `scan.m` / `on_nl`) — Bend disallows it; callee must be defined above caller, so `scan → emit → tok → scan` cannot be split; inlining into a single `parse.head.go` still needs a post-`\n` step that tail-calls `go` with the same shrunk tail **and** a different mode (checker: no decreasing arg unless we add fuel), or
- **computed scrutinees** (`start_line(line)` inside the scanner).

A **fuel‑bounded monolithic `parse.head.go`** is the next thing to try; not landed here.

## Proof / check

- `bend PROOF.bend` / `scripts/check.sh http` — green (no law edits).

## Follow-up

- Wire `whole` from split without changing observable `Got` (needs law-safe spec for partial vs complete heads), or drop `ends_with` only when #126 changes representation.
- One-pass head + cheaper map build with `Map.from_list` after pair collection (#126).
