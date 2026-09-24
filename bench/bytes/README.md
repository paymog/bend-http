# Bytes benchmark

How fast could a Bend `Bytes` type be? This runs the same seven byte-buffer operations in two Bend layouts and five other languages.

- `packed.bend` is the candidate: `Array<U32>`, 4 bytes per slot, little-endian.
- `string.bend` is what bend-net uses today: a `String`, one `Char` list cell per byte.

## Run

```sh
python3 run.py      # 3 runs per variant, median; Python and Bend String run once
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `rustc`, `go`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about a minute. It exits non-zero if any build fails, or if the variants that run at 256 MiB disagree on a checksum.

## The ops

Every program times each op in-process and prints its checksum. The buffer is N = 2^28 bytes (256 MiB). `bench.*` takes log2(N) as its first argument. The Bend files have N built in: 2^28 in `packed.bend`, and 2^26 in `string.bend`, since 256 MiB as a list takes more than 4 GiB. `run.py` multiplies the `String` times by 4. Checksum math is u32 and wraps.

| op | work | checksum |
|---|---|---|
| `fill` | allocate N bytes, set `b[i] = (31i + 7) & 255`, then set the last 4 bytes to `13,10,13,10` | `b[12345] + b[N-1]` |
| `sum` | add up every byte | the sum |
| `find` | index of the first `\r\n\r\n` (it is at N-4) | the index |
| `slice` | copy `b[N/4+1 .. N/4+1+N/2)` into a new buffer (not word-aligned) | first + last byte |
| `concat` | append N/65536 new 64 KiB chunks (chunk k is filled with `k & 255`) to an empty buffer that is not preallocated | first + last byte |
| `random` | 2^24 reads: `x = x*1664525 + 1013904223`, `idx = x >> (32 - log2 N)` | the sum |
| `equal` | compare `b` with a copy of it (the copy is made before the timer starts) | 1 |

Each language uses its idiomatic stdlib calls: `memmem`/`memcmp` in C, `windows(4).position` in Rust, `bytes.Index`/`bytes.Equal` in Go, `Buffer.indexOf`/`Buffer.equals` in JS, and `bytes.find` in Python. There is no hand-written SIMD and no third-party code.

In Bend, `sum` goes through the per-byte `byte(a, i)` read, which is what a `Bytes.get` caller would pay. `packed.bend` also prints two more ops that the table leaves out. `sum` reads a word at a time, and is slower (see below). `find_swar` skips words that hold no `\r`, but it does not beat the byte loop.

## Results

M4 Pro, macOS, Bend 2.0.25, 2026-09-24. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Go | Bun | Node | Python | Bend Array | Bend String |
|---|---|---|---|---|---|---|---|---|
| fill | 18.6 (1.1x) | 17.6 (1.0x) | 90.8 (5.2x) | 118.8 (6.7x) | 169.1 (9.6x) | 11,391.5 (647.2x) | 44.0 (2.5x) | 2,912.0 (165.4x) |
| sum | 11.5 (1.0x) | 14.9 (1.3x) | 78.0 (6.8x) | 557.7 (48.3x) | 1,307.1 (113.3x) | 14,247.9 (1234.6x) | 32.0 (2.8x) | 1,168.0 (101.2x) |
| find | 149.2 (15.5x) | 69.9 (7.3x) | 11.7 (1.2x) | 11.9 (1.2x) | 9.6 (1.0x) | 138.7 (14.4x) | 188.0 (19.6x) | 1,136.0 (118.2x) |
| slice | 8.6 (1.0x) | 10.4 (1.2x) | 10.0 (1.2x) | 8.7 (1.0x) | 8.4 (1.0x) | 10.8 (1.3x) | 19.0 (2.3x) | 4,164.0 (494.1x) |
| concat | 24.4 (1.5x) | 16.7 (1.0x) | 178.0 (10.7x) | 38.3 (2.3x) | 44.3 (2.7x) | 21.5 (1.3x) | 72.0 (4.3x) | 5,904.0 (354.4x) |
| random | 59.0 (1.0x) | 57.9 (1.0x) | 78.4 (1.4x) | 1,064.9 (18.4x) | 117.7 (2.0x) | 5,229.6 (90.4x) | 58.0 (1.0x) | n/a |
| equal | 5.0 (1.0x) | 10.3 (2.1x) | 6.5 (1.3x) | 10.8 (2.2x) | 16.0 (3.3x) | 4.8 (1.0x) | 23.0 (4.7x) | 7,608.0 (1569.2x) |
| geomean vs fastest | 1.6x | 1.6x | 2.7x | 4.5x | 4.1x | 20.9x | 3.5x | 285.7x |

`String` has no `random` column, because every read walks the list and is O(n). Its geomean covers the other six ops.

## Reading it

- A packed `Array` is 100 to 1,500 times faster than `String`, and it uses 1/16 of the memory.
- Overall it lands between Go and Node. Random reads match C.
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
