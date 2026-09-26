# Bytes benchmark

How fast could a Bend `Bytes` type be? This runs byte-buffer operations in two Bend layouts and five other languages.

- `packed.bend` is the candidate: `Array<U32>`, 4 bytes per slot, little-endian.
- `string.bend` is what bend-kit uses today: a `String`, one `Char` list cell per byte.

## Run

```sh
python3 run.py      # 3 runs per variant, median; Python and Bend String run once
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `rustc`, `go`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about a minute. It exits non-zero if any build fails, or if the variants that run at 256 MiB disagree on a checksum.

## The ops

Every program times each op in-process and prints its checksum. Except for `build`, the buffer is N = 2^28 bytes (256 MiB). `bench.*` takes log2(N) as its first argument. The Bend files have N built in: 2^28 in `packed.bend`, and 2^26 in `string.bend`, since 256 MiB as a list takes more than 4 GiB. `run.py` multiplies the `String` times by 4. Checksum math is u32 and wraps.

| op | work | checksum |
|---|---|---|
| `fill` | allocate N bytes, set `b[i] = (31i + 7) & 255`, then set the last 4 bytes to `13,10,13,10` | `b[12345] + b[N-1]` |
| `sum` | add up every byte | the sum |
| `find` | index of the first `\r\n\r\n` (it is at N-4) | the index |
| `slice` | copy `b[N/4+1 .. N/4+1+N/2)` into a new buffer (not word-aligned) | first + last byte |
| `concat` | append N/65536 new 64 KiB chunks (chunk k is filled with `k & 255`) to an empty buffer that is not preallocated | first + last byte |
| `random` | 2^24 reads: `x = x*1664525 + 1013904223`, `idx = x >> (32 - log2 N)` | the sum |
| `equal` | compare `b` with a copy of it (the copy is made before the timer starts) | 1 |
| `build_1000000`, `build_4000000` | start empty; append bytes `i & 255` one at a time, without reserving capacity | size + last byte |

The two `build` sizes use 1,000,000 and 4,000,000 bytes, not the 256 MiB used by the other ops. Bend Array calls `Bytes.append` with a one-byte buffer each time. Bend String has no build row: `string.bend` measures construction in `fill`, not incremental append.

Each language uses its idiomatic stdlib calls: `memmem`/`memcmp` in C, `windows(4).position` in Rust, `bytes.Index`/`bytes.Equal` in Go, `Buffer.indexOf`/`Buffer.equals` in JS, and `bytes.find` in Python. There is no hand-written SIMD and no third-party code.

In Bend, `sum` goes through the per-byte `byte(a, i)` read, which is what a `Bytes.get` caller would pay. `packed.bend` also prints two more ops that the table leaves out. `sum` reads a word at a time, and is slower (see below). `find_swar` skips words that hold no `\r`, but it does not beat the byte loop.

## Results

M4 Pro, macOS, 2026-09-25, from `python3 run.py`. Median of three runs, except Python and Bend String (one run). Every variant that runs at 256 MiB printed the same checksums. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

Versions: Bend 2.0.28, Apple clang 17.0.0, rustc 1.91.0, Go 1.27.1, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

| op | C | Rust | Go | Bun | Node | Python | Bend Array | Bend String |
|---|---|---|---|---|---|---|---|---|
| fill | 16.6 (1.1x) | 15.3 (1.0x) | 94.7 (6.2x) | 116.5 (7.6x) | 155.7 (10.2x) | 10,985.1 (716.9x) | 46.0 (3.0x) | 2,936.0 (191.6x) |
| sum | 10.0 (1.1x) | 9.0 (1.0x) | 74.2 (8.3x) | 485.9 (54.2x) | 1,166.2 (130.0x) | 14,186.2 (1581.8x) | 39.0 (4.3x) | 1,552.0 (173.0x) |
| find | 136.1 (14.8x) | 66.8 (7.3x) | 11.4 (1.2x) | 11.0 (1.2x) | 9.2 (1.0x) | 191.8 (20.8x) | 190.0 (20.6x) | 1,692.0 (183.7x) |
| slice | 8.4 (1.1x) | 7.7 (1.0x) | 9.1 (1.2x) | 7.9 (1.0x) | 7.9 (1.0x) | 10.8 (1.4x) | 19.0 (2.5x) | 3,784.0 (490.6x) |
| concat | 14.5 (1.0x) | 15.8 (1.1x) | 159.9 (11.0x) | 34.3 (2.4x) | 41.2 (2.8x) | 21.9 (1.5x) | 63.0 (4.3x) | 5,768.0 (397.2x) |
| random | 56.8 (1.0x) | 58.9 (1.0x) | 70.2 (1.2x) | 999.6 (17.6x) | 110.8 (2.0x) | 4,938.5 (86.9x) | 62.0 (1.1x) | n/a |
| equal | 5.2 (1.0x) | 12.5 (2.4x) | 9.8 (1.9x) | 11.1 (2.1x) | 11.0 (2.1x) | 5.2 (1.0x) | 24.0 (4.6x) | 6,492.0 (1251.1x) |
| build_1000000 | 0.3 (1.0x) | 0.4 (1.2x) | 0.4 (1.2x) | 5.6 (17.8x) | 3.1 (9.9x) | 36.6 (117.4x) | 8.0 (25.6x) | n/a |
| build_4000000 | 1.3 (1.0x) | 1.8 (1.4x) | 1.4 (1.1x) | 18.2 (14.3x) | 8.8 (7.0x) | 146.3 (115.2x) | 36.0 (28.3x) | n/a |
| build (4M / 1M) | 4.1x | 4.9x | 3.7x | 3.3x | 2.9x | 4.0x | 4.5x | n/a |
| geomean vs fastest | 1.4x | 1.5x | 2.4x | 6.1x | 4.7x | 33.9x | 6.0x | 337.8x |

`String` has no `random` row, because every read walks the list and is O(n). It has no `build` rows either (see above). Its geomean covers the other six ops.

Four times as many one-byte appends took Bend Array 4.5 times as long. This is consistent with linear growth; the two sizes do not prove an asymptotic bound.

## Reading it

- A packed `Array` is 9 to 270 times faster than `String`, and it uses 1/16 of the memory.
- Over the seven buffer ops, without the `build` rows, the geomean is 3.9x for Bend Array, 4.0x for Node, and 2.9x for Go. Random reads match C. The one-byte `build` appends are 25 to 28 times slower than C, which pulls the full geomean to 6.0x.
- `find` is the weak spot. Go and JS hand it to SIMD `memchr`/`memmem`, and a Bend loop cannot call host code outside `IO`. Closing that gap probably needs native `Array` primitives in Bend itself. The C and Python columns are slow here for a different reason: macOS `memmem` and CPython's search do not use SIMD for this pattern.
- `concat` keeps the chunks in a list and copies them once at the end. `Array.join` might make that O(1) per chunk; it has not been tried.

## Later: parallel ops

For now we accept the gap: `find` is about 20x slower, and `concat` about 4x. Every Bend op here is one sequential loop.

The idea to try later: other standard libraries close gaps like these with SIMD, and Bend can close them with fork-join instead. `Array` is a binary tree (`ALeaf{value}` / `ANode{xs, ys}`), so an op can match `ANode{xs, ys}` and run `a b = op(xs) op(ys)` on all cores. Compare against each language's standard library as it is. If Bend's parallelism beats their SIMD, that counts.

Plan:

1. Run every op at several sizes, say 256 B, 4 KiB, 64 KiB, 1 MiB, and 256 MiB. HTTP headers are small, and on small buffers forking costs more than it saves.
2. Go parallel automatically once a buffer passes a size cutoff. Take the cutoff from those size curves, and stay sequential below it.
3. Parallelize `fill`, `sum`, `find`, and `equal`. `find` has to catch a match that spans the split: each half reports its first and last 3 bytes, or the halves overlap by 3 bytes. Try `Array.join` for `concat`.

Keep in mind that parallelism borrows idle cores, while SIMD speeds up one core. On a loaded server every core is already busy, so the cutoff should be conservative.

## Caveats

- Bend's `IO.now` counts in whole ms, so a Bend op under 20 ms is ±5% or worse. The other languages use sub-ms clocks.
- Bend `concat` and `find_swar` vary up to 2x between runs. Rerun before you trust a small change.
- The byte-at-a-time `sum` beats the word-at-a-time one, even on `--threads 1`. The likely cause is clang optimizing the C that Bend emits for the byte loop better. That is not confirmed.
- These are micro-benchmarks on one machine. They measure primitives, not an HTTP parser.
