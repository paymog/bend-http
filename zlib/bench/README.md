# Zlib benchmark

This times `gunzip` on one fixed gzip member, in Bend and in JavaScript (Bun and Node) and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median, 4 MiB plain
python3 run.py 5    # 5 runs
python3 run.py 1 65536   # 1 run on 64 KiB plain; check RSS and checksum first after a change
```

You need `bend`, `bun`, `node`, and `python3`. `run.py` writes the gzip member to `out/payload.gz` and the Bend binary to `out/`, which git ignores. The run takes a few seconds. It exits non-zero if a build fails, or if two languages print different checksums.

C and Rust are omitted: neither standard library ships gzip or DEFLATE decode.

## Input

`run.py` builds **N = 4,194,304** bytes (4 MiB) of deterministic ASCII text:

- Seed **0xDEADBEEF** drives an LCG that builds **1024** unique sentences from a fixed **247-word** vocabulary (6–17 words each, period-terminated).
- Seed **0xC0FFEE01** walks the plain text: append a sentence (space-separated), a newline, or a raw byte from the LCG (~3% random bytes, ~1.5% newlines).
- Gzip level **6**, **mtime=0**. Wire size **1,050,286** bytes; compression ratio **3.99×** (plain ÷ gzip).

Each program reads the member before any timer starts. The timed op **`inflate`** is one `gunzip` / `gzip.decompress` / `gunzipSync` call. After the timer stops, the program prints a checksum of every inflated byte: `h = h*31 + b` in wrapping u32. Expected: **2339964736**.

Throughput in the table is inflated bytes per second (decimal MB/s).

Bend reads the file with `File.read_bytes` so the gzip bytes are not UTF-8 decoded. Bend peak RSS was about **0.7 MB** on **64 KiB** plain and about **84 MB** on the 4 MiB run.

## Results

M4 Pro, macOS 26.6.2, arm64, 2026-09-26. Median of five runs (`python3 run.py 5`). Times are in ms; **MB/s** and **vs fastest** come from `run.py`.

| variant | inflate ms | inflate MB/s | vs fastest |
|---:|---:|---:|---:|
| Bun | 6.4 | 660 | 2.2x ms, 0.45x MB/s |
| Node | 6.2 | 673 | 2.2x ms, 0.46x MB/s |
| Python | 2.9 | 1,458 | 1.0x ms, 1.00x MB/s |
| Bend | 204.0 | 21 | 70.9x ms, 0.01x MB/s |

Versions: Bend 2.0.28, Bun 1.3.14, Node 24.0.1, Python 3.14.6.
