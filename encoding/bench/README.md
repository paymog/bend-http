# Encoding benchmark

This times the four `encoding` hot paths on one fixed input, in Bend and in C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about 20 seconds. It exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

The seed is `Hello é Ω € 中 😀\n`: 16 code points, 25 UTF-8 bytes, with 1-, 2-, 3-, and 4-byte sequences. Each program repeats it 2^18 times:

| op | input | output |
|---|---|---|
| `utf8_encode` | text, 4,194,304 code points | 6,553,600 bytes |
| `utf8_decode` | those 6,553,600 bytes | 4,194,304 code points |
| `hex_encode` | those 6,553,600 bytes | 13,107,200 hex digits |
| `hex_decode` | those 13,107,200 hex digits | 6,553,600 bytes |

Each program builds its inputs before any timer starts, and times only the op. After the timer stops, it prints a checksum of the output: `h = h*31 + x` over the bytes or code points, in wrapping u32, plus the length. The checksums are `2586050560`, `2599682048`, `4003201024`, and `2586050560`, in table order.

## Results

M4 Pro, macOS 26.6.2, 2026-09-25. Median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| utf8_encode | 5.7 (2.4x) | 3.5 (1.4x) | 2.4 (1.0x) | 8.1 (3.3x) | 4.3 (1.8x) | 68.0 (28.0x) |
| utf8_decode | 7.6 (1.8x) | 4.9 (1.2x) | 4.2 (1.0x) | 10.8 (2.6x) | 5.6 (1.3x) | 47.0 (11.2x) |
| hex_encode | n/a | n/a | 1.2 (1.0x) | 2.9 (2.5x) | 4.2 (3.7x) | 135.0 (117.0x) |
| hex_decode | n/a | n/a | 3.9 (1.0x) | 4.4 (1.1x) | 4.0 (1.0x) | 83.0 (21.4x) |

Versions: Bend 2.0.28, Apple clang 17.0.0, rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## The calls

| language | UTF-8 encode | UTF-8 decode | hex |
|---|---|---|---|
| Bend | `Enc.utf8.encode` | `Enc.utf8.decode` | `Enc.encode`, `Enc.decode` |
| C | `wcsrtombs` from `wchar_t[]` | `mbsrtowcs` to `wchar_t[]` | left out |
| Rust | `Vec<char>` collected into a `String` | `String::from_utf8_lossy`, then collected into `Vec<char>` | left out |
| JavaScript | `TextEncoder.encode` | `TextDecoder.decode` | `Buffer` `toString("hex")` and `Buffer.from(s, "hex")` |
| Python | `str.encode` | `bytes.decode("utf-8", "replace")` | `bytes.hex`, `bytes.fromhex` |

C and Rust have no hex codec in their standard libraries, so they have no hex rows. `bench.ts` uses `Buffer`, which is in the Node standard library and in Bun, but not in ECMAScript itself.

## Caveats

- Bend strings are lists, one cell per byte or code point. The other languages use flat buffers.
- The outputs are not all the same shape. C and Rust decode to UTF-32 arrays, JavaScript to a UTF-16 string, and Python to its compact `str`. Bend decodes to a list of code points.
- C's `mbsrtowcs` fails on malformed input. The others substitute U+FFFD. The input is valid UTF-8, so this does not change the work here.
- Bend's `IO.now` counts in whole ms. The other languages use sub-ms clocks.
- These are micro-benchmarks on one machine.
