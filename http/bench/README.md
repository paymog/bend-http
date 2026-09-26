# HTTP benchmarks

## Codec

`bench.*` and `rs/` time the HTTP/1.1 codec with no socket: parse one fixed request and one fixed response, and encode one of each. Bend runs against C, Rust, JavaScript (Bun and Node), and Python.

### Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `llhttp` (`brew install llhttp`), `cargo`, `bun`, `node`, and `uv`. Cargo fetches `httparse` and `uv` fetches `h11` on the first run. Binaries go to `out/`, which git ignores. The run takes about 30 seconds. It exits non-zero if a build fails, or if two languages print different checksums for one op.

### Input

Each op runs 20,000 times on one message:

| op | message |
|---|---|
| `parse_req` | a 451-byte `POST` with 9 browser-like headers and a 26-byte JSON body |
| `parse_res` | a 252-byte `200` with 6 headers and a 34-byte JSON body |
| `encode_req` | a `POST` with 3 caller headers and the 26-byte body, 222 bytes out |
| `encode_res` | a `200` with 4 caller headers and the 34-byte body, 200 bytes out |

The parse checksum sums, over every message, the method and target lengths (for a request) or the status code (for a response), plus name length + value length + 1 per header, plus the body length. Bend's encoders add `host`, `connection`, and `content-length`, and write headers in sorted order, so the other encoders get the same headers. h11 moves `host` first, so the encode checksum sums a hash per line (`h = h*31 + c`, u32) and does not depend on line order. It adds the total output length. The checksums are `8200000`, `8300000`, `954665139`, and `4171655946`, in table order.

### Results

M4 Pro, macOS 26.6.2, 2026-09-25. Median of five runs. Times are in ms for 20,000 messages; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| parse_req | 4.0 (2.2x) | 1.8 (1.0x) | 16.8 (9.3x) | 19.9 (11.1x) | 443.9 (246.6x) | 876.0 (486.7x) |
| parse_res | 2.5 (1.7x) | 1.5 (1.0x) | 12.4 (8.3x) | 15.1 (10.1x) | 315.3 (210.2x) | 2,234.0 (1489.3x) |
| encode_req | n/a | n/a | n/a | n/a | 317.4 (1.7x) | 183.0 (1.0x) |
| encode_res | n/a | n/a | n/a | n/a | 273.2 (2.1x) | 128.0 (1.0x) |

Versions: Bend 2.0.28, Apple clang 17.0.0 with llhttp 9.4.2, rustc 1.91.0 with httparse 1.10.1, Bun 1.3.14, Node 24.0.1, Python 3.14.6 with h11 0.16.0.

### The calls

| language | parse | encode |
|---|---|---|
| Bend | `Http.parse`, `Http.parse_res` | `Http.encode_req`, `Http.encode` |
| C | `llhttp_execute` with span callbacks | left out |
| Rust | `httparse::Request::parse`, `httparse::Response::parse`, then the `Content-Length` body slice | left out |
| JavaScript | `HTTPParser.execute` from Node's `_http_common` | left out |
| Python | `h11.Connection.receive_data` and `next_event` | `h11.Connection.send` |

C, Rust, and JavaScript have no HTTP/1.1 message encoder short of a client or server bound to a socket, so they have no encode rows. The JavaScript parser is Node's own llhttp binding. Its module is legacy and not documented, but Node and Bun both ship it.

### Caveats

- httparse reads only the head, so the Rust variant finds `Content-Length` and slices the body itself.
- h11 reads a response only on a connection that has sent a request, and writes one only on a connection that has read one. `bench.py` makes those 20,000 connections before the timer starts.
- C, Rust, and JavaScript reuse one parser. Python makes a connection per message. Bend has no parser state.
- Bend strings are lists, one cell per byte. The others read flat buffers.
- Bend's `IO.now` counts in whole ms. The others use sub-ms clocks.
- These are micro-benchmarks on one machine.

## Network

`fetch16.bend` and `serve16.bend` time a live download and upload in Bend only. They measure the socket and the runtime along with the codec. See the comment at the top of each file.
