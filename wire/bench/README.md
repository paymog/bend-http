# Wire benchmark

This times one localhost TCP echo of a fixed 1 MiB buffer: Bend uses `Wire.send.words` and `Wire.recv.words`; C, Rust, Python, and JavaScript use raw `socket` / `std::net` / `node:net`.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes a few seconds. It exits non-zero if a build fails or checksums disagree.

## Input

- Payload: 1,048,576 bytes (`N = 2^20`). Byte `i` is `(i * 31 + 7) & 255`.
- Port: `38475` on `127.0.0.1`.
- Checksum: `b[12345] + b[N - 1]` (plain integer sum, not u32 wrap). Value: **470**.
- Ops: `send` times one full write; `recv` times one full read of the echo. Connect and server setup are not timed.

Bend runs in **one process**: `IO.fork` starts a TCP echo server (`TCP.listen` / `TCP.accept`, then `Wire.recv.words` / `Wire.send.words`); the main task sleeps 200 ms, connects with `Wire.connect`, then times client `send.words` and `recv.words`. Other languages use a helper thread or async server that signals when listen is ready.

## Results

M4 Pro, macOS 26.6.2, 2026-09-26. Median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| send | 0.3 (1.3x) | 0.2 (1.0x) | 0.9 (4.5x) | 0.8 (3.8x) | 0.4 (2.0x) | 1.0 (4.9x) |
| recv | 0.5 (487.0x) | 0.4 (368.2x) | 0.8 (827.0x) | 0.9 (869.0x) | 0.6 (640.0x) | 0.0 (0.0x) |

Bend `recv` at 0.0 ms is below the `IO.now()` timer resolution on this run; send still shows wire cost.

Versions: Bend 2.0.28, Apple clang 17.0.0, Rust 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6.
