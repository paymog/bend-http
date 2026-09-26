# JSON benchmark

This times `Json.parse` and `Json.encode` on one fixed document, in Bend and in JavaScript (Bun and Node) and Python.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 4000 records
python3 run.py 5        # 5 runs
python3 run.py 1 40     # 1 run on a 40-record document; check this first after a change
```

You need `bend`, `bun`, `node`, and `python3`. `run.py` writes the input to `out/doc.json` and the Bend binary to `out/`, which git ignores. The run takes about 5 seconds. It exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

`run.py` writes `{"count": N, "items": [...]}` with N = 4000 records, pretty-printed by `json.dumps(indent=2)`: 1,361,421 bytes. Each record has a bool, a null, integers, a half (`i + 0.5`), plain strings, a string with `\n`, `\t`, `\"`, and `\\` escapes, a nested object, and arrays.

The document is ASCII only, its keys are in sorted order, and its numbers are integers or exact halves. So every encoder prints the same compact text, and Bend's sorted keys match the insertion order that JavaScript and Python keep.

Each program reads the file before any timer starts. `parse` times the parse of the text. `encode` times the encode of the parsed value to compact JSON. After each timer stops, the program prints a checksum of the compact encoding: `h = h*31 + c` over the chars, in wrapping u32, plus the length. Both checksums are `4114665117`.

## Results

M4 Pro, macOS 26.6.2, 2026-09-25. Median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op. Bend's peak RSS was 48 MB.

| op | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|
| parse | 2.2 (1.0x) | 3.0 (1.4x) | 4.6 (2.1x) | 42.0 (19.3x) |
| encode | 0.8 (1.0x) | 1.1 (1.3x) | 4.1 (5.0x) | 76.0 (92.8x) |

Versions: Bend 2.0.28, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## The calls

| language | parse | encode |
|---|---|---|
| Bend | `Json.parse` | `Json.encode` |
| JavaScript | `JSON.parse` | `JSON.stringify` |
| Python | `json.loads` | `json.dumps(v, separators=(",", ":"), ensure_ascii=False)` |

C and Rust have no JSON codec in their standard libraries, so they are left out.

## Caveats

- Bend strings are lists, one cell per char, and objects are `Map`s. The other languages use flat strings and hash maps.
- Bend keeps each number's text. JavaScript and Python convert numbers to doubles or ints and print them back.
- Bend's `Json.encode` sorts keys. The others keep insertion order, so they do not sort.
- Bend's `IO.now` counts in whole ms. The other languages use sub-ms clocks.
- These are micro-benchmarks on one machine.
