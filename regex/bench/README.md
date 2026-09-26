# Regex benchmark

Times `Regex.is_match` and `Regex.find` on fixed inputs against POSIX `regex.h`, Python `re`, and JavaScript `RegExp`.

## Run

```sh
python3 run.py      # 3 runs per case, median; Bend smoke (4096 code points) first
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `python3`, `bun`, and `node`. Binaries go to `out/`, which git ignores. `run.py` exits non-zero if a build fails or the checksums disagree. The `redos` case uses a 10 s per-run timeout; backtracking engines that hang are recorded as `timeout`.

## Input

Text is built deterministically at **N = 2^20** code points (about 1 MiB of ASCII):

1. Fill with `x`.
2. At **N − 50**, write `user@host.com` (13 code points).
3. At **N − 20**, write `helloworld12` (12 code points).

The ReDoS input is **100 000** `a` with no trailing `b`.

## Cases

| case | Bend / Python / JS pattern | POSIX ERE (C) | work | checksum |
|---|---|---|---|---|
| `is_match` | `hello\w+` | `hello[[:alnum:]_]+` | leftmost match of the hello prefix | u32 hash of group-0 start/end (0 if no match) |
| `find_captures` | `(\w+)@(\w+)\.com` | `([[:alnum:]_]+)@([[:alnum:]_]+)\.com` | leftmost match with two captures | hash of groups 0–2 spans |
| `redos` | `(a*)*b` | `(a*)*b` | no match on 100k `a` | 0 |

Hash: for each group, if missing then `h = h * 31`; else `h = h * 31 + start` then `h = h * 31 + end` (u32 wrap). Positions are code-point indexes in Bend and byte indexes in the other languages; the input is ASCII so they agree.

Compile the pattern **outside** the timed region. Bend uses a native build (`bend bench.bend -o out/bend`); the checker runner is not used for the 1 MiB input.

## Rust

Rust's standard library has no regular expression engine, so Rust is left out.

## Results

Apple M4 Pro, macOS, 2026-09-26. Median of three runs (`python3 run.py 3`). Times are ms for one match on the 1 MiB text (or 100k `a` for `redos`).

Versions: Bend 2.0.28, Apple clang 17.0.0, Python 3.14.6, Bun 1.3.14, Node v24.0.1.

| op | C | Python | Bun | Node | Bend |
|---|---:|---:|---:|---:|---:|
| is_match | 0.0 | 0.3 | 0.3 | 0.2 | 145.0 |
| find_captures | 15.9 | 3.0 | 0.8 | 0.7 | 777.0 |
| redos | 3.3 | timeout | 915.6 | timeout | 141.0 |

Checksums (1 MiB text): `is_match` 33553812, `find_captures` 3021334545, `redos` 0. All non-timeout variants agree.

## Caveats

- Bend strings are `Char` lists; the gap on large inputs is mostly allocation layout, not just the Pike VM.
- POSIX ERE has no `\w`; `[[:alnum:]_]` is the documented equivalent for ASCII word characters.
- `IO.now` in Bend is whole milliseconds; C and the scripting languages use sub-ms clocks.
