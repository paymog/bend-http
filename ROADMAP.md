# bend-net roadmap

The goal is the best HTTP library for Bend. This is a ranked backlog, not a promise. The top of **Next** is what we work on now. Each checkbox is one outcome. Re-rank items when evidence changes.

## Current baseline

- Packages on the Bend hub: `bend-net-http@0.14.0.0`, `bend-net-bytes@0.2.0.0`, `bend-net-wire@0.4.0.0`, `bend-net-url@0.4.0.0`, `bend-net-json@0.3.0.0`, `bend-net-encoding@0.2.1.0`, `bend-net-dns@0.3.1.0`, `bend-net-zlib@0.1.0.0`, and `bend-net-router@0.1.1.0`. `http` and `dns` import their siblings by name, so callers share their types. Elbow is no longer used. Fetch returns `Result` and headers are lists (`f73e022`). The README is `bf9e139`.
- `Http.fetch(method, url, headers, body)` does http and https, DNS, redirects (20 hops), and a 30 s timeout per step. It runs on a pool of its own that it closes; `Http.pool.*` keeps one idle socket per origin across calls and retries an idempotent request once when a reused socket fails before any response byte (`b566beb`). `fetch.with(..., ms)` sets the timeout. It returns `Result<Res, Err>`: bad URL, DNS, connect, TLS (errno and verify text), read, write, timeout, too many redirects, or a malformed response. `ETIMEDOUT` is 60 on macOS and 110 on Linux. Headers are a list per name. `header` is the first value. `Set-Cookie` is never joined. Encode writes one line per value.
- Bodies are `Http.Body` (`Bytes.Bytes` from `bend-net-bytes`, with `Http.from_string`, `to_string`, and `length`): `Req.body`, `Res.body`, request bodies, stream pieces, and the wire bytes of `encode`, `encode_req`, and `exchange`. The `String` parsers (`parse`, `frame`) stay as the spec. `Http.text` decodes UTF-8. `Http.json` parses that text. `Url.form` writes a form body. `fetch` sends `accept-encoding: gzip, deflate` and decodes gzip and deflate through the `zlib` package (`4787d29`); an unknown coding is left as sent. `Http.open`/`stream.read` and `Http.upload` stream bodies in pieces (`ec55a76`).
- `wire` holds the effects Base lacks: byte-exact TCP/UDP, a TCP connect with a deadline, and TLS through OpenSSL 3 loaded at run time (`BEND_LIBSSL` overrides the path). Each effect has a C and a JS version. The `.words` forms move bytes in the `bytes` layout, with no list cell per byte (`52ca321`).
- `bytes@0.1.0` (`67341da`) is a byte buffer packed four bytes to a `U32` `Array` slot. It has bounds-checked `get`/`set`, `slice`, `append`, `concat`, `find`, and `eq`, and it converts to and from byte strings. `bench/bytes` measures the layout.
- Laws: http 176, url 57, json 40, bytes 48, zlib 14, dns 18, encoding 13, router 3. Run `bend PROOF.bend` in the root and in each package folder.
- Big bodies need a native build (`bend file.bend -o app`). The `bend file.bend` runner overflows on strings over about 30 KB.
- A bad chunk or bad framing is `FrameBad` while the connection is still open. A close-delimited TLS body that ends without `close_notify` is a read error. Content-Length and chunked bodies do not wait for that close. `100` and `103` are skipped; `101` is final.
- `fetch`, `exchange`, and streams read into `Bytes` and frame each read once: the head is parsed when it is whole, and chunk data runs are sliced whole. At 12 MiB a download takes about 25 ms in-process and peaks at 32 MB of RSS: the body sits in a 16 MiB array (arrays are a power of two in size), and the 12 MiB of pieces are alive while they are joined. Streaming the same body with `Http.open` peaks at 2.4 MB. It took 1.1 s and 1.1 GB with Content-Length, and 27.5 s chunked, which re-framed the whole buffer after every read (`bench/fetch16.bend`). A `String` body alone held 434 MB. The cap is 16 MiB of body and 64 KiB of head; before, a body of exactly 16 MiB failed.
- `Dns.resolve` checks `/etc/hosts`, then the first three nameservers. `resolve.at` asks one server. A silent server is 2 attempts × 5 s, then the next server. `Http.exchange` does one request on an open socket and says whether that socket can take another.
- `Http.serve` reads into `Bytes`, parses the head once, and joins the body once; chunk data runs are sliced whole. A 16 MiB upload takes about 0.03 s, down from 2.7 s on a `String` buffer and 0.26 s with a `String` body (`f3ceb23`, `bench/serve16.bend`). A 12 MiB response goes out in about 25 ms. It sends 100 Continue when a request expects it. It keeps HTTP/1.1 connections open and answers pipelined requests in order (`a7d28f7`). `serve.with` sets the request cap; the default is 16 MiB. A bad request is 400, an oversized one 413, a head over 64 KiB 431. It sends the RFC 9110 reason phrase, no body for HEAD, 1xx, 204 and 304, and accepts `HTTP/1.0` without `Host`.
- Header lines, request targets, and URLs parse in linear time. They were O(n²), so a 70 KB header or a 32 KB `Location` held a worker for 20 to 30 s (`05cbd5b`, `7487a84`). The `url` package has no `@unsafe` defs.
- The README install and fetch example pass on clean Debian 12 containers (arm64 and amd64), in the runner and as a native build. The x86_64 Mac is not tested.

## Next

- [ ] **Name the last four packages.** The hub's limit of five new names a day stopped these; each is published. Run `bend link bend-net-router@0.1.1.0 0xee542cbbb769c012fbef4eac7dcba335`, `bend link bend-net-zlib@0.1.0.0 0xfa97cc8246066bff0b9237beb9af14d2`, `bend link bend-net-dns@0.3.1.0 0x70dd8459e2a121e9bbe04ea7e5f8ebb7`, and `bend link bend-net-http@0.14.0.0 0xea8f96f102b76dde4994886007251d17`, then show the name imports in the README.
- [ ] **Give `zlib` a `Bytes` input.** `decoded` turns a compressed body into a `String` for `zlib` and the result back into `Bytes`, so a large gzip body still costs a `String` of each size. A plain body is never converted.
- [ ] **Read a Content-Length body into one buffer.** Allocate the body once from its length and write each read into it, so a 12 MiB download peaks near 18 MB, not 32 MB. Chunked and close-delimited bodies keep joining pieces.
- [ ] **Speed up JSON.** A 1 MB `Json.parse` takes about 3.4 s of CPU.
- [ ] **Stream in the server.** `serve` hands the handler a whole `Req` and sends a whole `Res`. Add a handler form that reads the request body and writes the response in pieces, on the same `Rb`/`ck` framing the client streams use.
- [ ] **Lingering close in `serve`.** After a 400, 413, or 431, `serve` closes with unread client bytes, so the client may get an RST instead of the response. Stop writing, drain for a moment, then close.
- [ ] **Prove universal laws.** Most laws are fixtures. Add laws over all inputs for the claims that matter most: `res.frame` agrees with `frame` for every split of the bytes, `dc.feed` of `a ++ b` equals feeding `a` then `b`, `parse.got` never says Bad to a prefix of a valid request, `utf8.decode(utf8.encode(s)) == s`, `Json.parse(Json.encode(v)) == Some{v}`, and `Bytes.to_string(Bytes.from_string(s)) == s` for every byte string.
- [ ] **IPv6 and the rest of DNS.** Add AAAA records and IPv6 connect (the runtime's `io_sys_addr` is IPv4 only). Also add a TCP retry when TC is set, and a small TTL cache.
- [ ] **Report the runner overflow upstream.** `String.repeat`/`String.length` on about 30 KB overflows in the `bend file.bend` runner but not in native builds. Report it to Bend with the three-line repro.

## Later

- [ ] **JSON number to F32.** `Json.at` and `Json.u32` exist. `json.encode` is still `@unsafe` because it walks a work list.
- [ ] brotli decoding, and gzip bodies with more than one member (only the first is decoded).
- [ ] More than one idle socket per origin in the pool, and decoding inside streams.
- [ ] A cookie jar, proxies (`HTTP_PROXY`), client certificates, ALPN, HTTP/2.
- [ ] Windows support (the effects use POSIX sockets and `dlopen`).
- [ ] Test on an x86_64 Mac.

## Depends on the Bend hub

- The hub registers at most five new names per account per day.
- Packages ship `.c` and `.js` effects that run host code, and proofs do not cover them. The hub does not show this before import.

When an item is done, link its commit here and remove it.
