# Zlib benchmark

This times `gunzip` on one fixed gzip member, in Bend and in JavaScript (Bun and Node) and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median, 8 MiB plain
python3 run.py 5    # 5 runs
python3 run.py 1 8192   # 1 run on 8 KiB plain; check this first after a change
```

You need `bend`, `bun`, `node`, and `python3`. `run.py` writes the gzip member to `out/payload.gz` and the Bend binary to `out/`, which git ignores. The run takes a few seconds. It exits non-zero if a build fails, or if two languages print different checksums.

C and Rust are omitted: neither standard library ships gzip or DEFLATE decode.

## Input

`run.py` builds plain bytes of length **N = 8,388,608** (8 MiB). Byte `i` is `(i * 31 + 7) & 255`. It gzip-compresses that payload once (`mtime=0`, level 6). On this pattern the member is **32,876** bytes on the wire.

Each program reads the member before any timer starts. The timed op **`inflate`** is one `gunzip` / `gzip.decompress` / `gunzipSync` call. After the timer stops, the program prints a checksum of every inflated byte: `h = h*31 + b` in wrapping u32. Expected: **2009071616**.

Throughput in the table is inflated bytes per second (decimal MB/s).

Bend reads the file with `File.read_bytes` so the gzip bytes are not UTF-8 decoded.

## Results

M4 Pro, macOS 26.6.2, arm64, 2026-09-26. Median of five runs (`python3 run.py 5`). Times are in ms; **MB/s** and **vs fastest** come from `run.py`.

| variant | inflate ms | inflate MB/s | vs fastest |
|---:|---:|---:|---:|
| Bun | 2.7 | 3,135 | 1.8x ms, 0.55x MB/s |
| Node | 2.9 | 2,935 | 2.0x ms, 0.51x MB/s |
| Python | 1.5 | 5,726 | 1.0x ms, 1.00x MB/s |
| Bend | 134.0 | 63 | 91.5x ms, 0.01x MB/s |

Versions: Bend 2.0.28, Bun 1.3.14, Node 24.0.1, Python 3.14.6.
