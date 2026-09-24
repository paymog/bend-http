# bend-net roadmap

The goal is the best HTTP library for Bend. This is a ranked backlog, not a promise. The top of **Next** is what we work on now. Each checkbox is one outcome. Re-rank items when evidence changes.

## Current baseline

- Packages on the Elbow registry: `http@0.9.2`, `url@0.3.1`, `json@0.2.1`, `dns@0.2.1`, `wire@0.3.1`, `encoding@0.2.1`, `router@0.1.1`, `bytes@0.1.0`. Fetch returns `Result` and headers are lists (`f73e022`). The README is `bf9e139`. The Bend hub reads the first comment in path order (`c9b30e0`).
- `Http.fetch(method, url, headers, body)` does http and https, DNS, redirects (20 hops), and a 30 s timeout per step. It runs on a pool of its own that it closes; `Http.pool.*` keeps one idle socket per origin across calls and retries an idempotent request once when a reused socket fails before any response byte (`b566beb`). `fetch.with(..., ms)` sets the timeout. It returns `Result<Res, Err>`: bad URL, DNS, connect, TLS (errno and verify text), read, write, timeout, too many redirects, or a malformed response. `ETIMEDOUT` is 60 on macOS and 110 on Linux. Headers are a list per name. `header` is the first value. `Set-Cookie` is never joined. Encode writes one line per value.
- Bodies are byte strings: one `Char` per octet. `Http.text` decodes UTF-8. `Http.json` parses that text. `Url.form` writes a form body. `fetch` sends `accept-encoding: gzip, deflate` and decodes gzip and deflate through the `zlib` package (`4787d29`); an unknown coding is left as sent. `Http.open`/`stream.read` and `Http.upload` stream bodies in pieces (`ec55a76`).
- `wire` holds the effects Base lacks: byte-exact TCP/UDP, a TCP connect with a deadline, and TLS through OpenSSL 3 loaded at run time (`BEND_LIBSSL` overrides the path). Each effect has a C and a JS version.
- `bytes@0.1.0` (`67341da`) is a byte buffer packed four bytes to a `U32` `Array` slot. It has bounds-checked `get`/`set`, `slice`, `append`, `find`, and `eq`, and it converts to and from byte strings. `bench/bytes` measures the layout. `Http` will adopt it once the `Http` work in progress lands.
- Laws: http 152, url 57, json 40, bytes 46, zlib 14, dns 18, encoding 13, router 3. Run `bend PROOF.bend` in the root and in each package folder.
- Big bodies need a native build (`bend file.bend -o app`). The `bend file.bend` runner overflows on strings over about 30 KB.
- A bad chunk or bad framing is `FrameBad` while the connection is still open. A close-delimited TLS body that ends without `close_notify` is a read error. Content-Length and chunked bodies do not wait for that close. `100` and `103` are skipped; `101` is final.
- `Dns.resolve` checks `/etc/hosts`, then the first three nameservers. `resolve.at` asks one server. A silent server is 2 attempts × 5 s, then the next server. `Http.exchange` does one request on an open socket and says whether that socket can take another.
- `Http.serve` frames requests in linear time (chunked bodies decode as they arrive), keeps HTTP/1.1 connections open, and answers pipelined requests in order (`a7d28f7`). `serve.with` sets the request cap; the default is 16 MiB. A bad request is 400, an oversized one 413, a head over 64 KiB 431. It sends the RFC 9110 reason phrase, no body for HEAD, 1xx, 204 and 304, and accepts `HTTP/1.0` without `Host`.
- Header lines, request targets, and URLs parse in linear time. They were O(n²), so a 70 KB header or a 32 KB `Location` held a worker for 20 to 30 s (`05cbd5b`, `7487a84`). The `url` package has no `@unsafe` defs.
- The README install and fetch example pass on clean Debian 12 containers (arm64 and amd64), in the runner and as a native build. The x86_64 Mac is not tested.

## Next

- [ ] **Publish `http@0.10.0` and `zlib@0.1.0`.** `main` has the pool, gzip, streams, and the serve rewrite, but the registry has `http@0.9.2`. `exchange` now returns `Maybe<Socket>`, so this is a breaking release.
- [ ] **Speed up parsing.** A 1 MB JSON parse takes about 3.4 s of CPU, and a byte string costs one list cell per octet: a 16 MB upload to `serve` takes about 3 s. `bytes` is the array-backed buffer. Next, have `wire.recv` fill `Bytes` directly, then move `Http` framing onto it. That is a breaking change to `Res.body`.
- [ ] **Stream in the server.** `serve` hands the handler a whole `Req` and sends a whole `Res`. Add a handler form that reads the request body and writes the response in pieces, on the same `Sf`/`dc` framing the client streams use.
- [ ] **Lingering close in `serve`.** After a 400, 413, or 431, `serve` closes with unread client bytes, so the client may get an RST instead of the response. Stop writing, drain for a moment, then close.
- [ ] **Prove universal laws.** Most laws are fixtures. Add laws over all inputs for the claims that matter most: `fetch.gate` never says no to a whole message, `dc.feed` of `a ++ b` equals feeding `a` then `b`, `parse.got` never says Bad to a prefix of a valid request, `utf8.decode(utf8.encode(s)) == s`, `Json.parse(Json.encode(v)) == Some{v}`, and `Bytes.to_string(Bytes.from_string(s)) == s` for every byte string.
- [ ] **IPv6 and the rest of DNS.** Add AAAA records and IPv6 connect (the runtime's `io_sys_addr` is IPv4 only). Also add a TCP retry when TC is set, and a small TTL cache.
- [ ] **Report the runner overflow upstream.** `String.repeat`/`String.length` on about 30 KB overflows in the `bend file.bend` runner but not in native builds. Report it to Bend with the three-line repro.

## Later

- [ ] **JSON number to F32.** `Json.at` and `Json.u32` exist. `json.encode` is still `@unsafe` because it walks a work list.
- [ ] brotli decoding, and gzip bodies with more than one member (only the first is decoded).
- [ ] More than one idle socket per origin in the pool, and decoding inside streams.
- [ ] A cookie jar, proxies (`HTTP_PROXY`), client certificates, ALPN, HTTP/2.
- [ ] Windows support (the effects use POSIX sockets and `dlopen`).
- [ ] Test on an x86_64 Mac.

## Depends on Elbow

- Publishing needs `ELBOW_TOKEN`; `ELBOW_TOKEN=$(gh auth token)` works. Token scope is tracked in Elbow's roadmap.
- Packages ship `.c` and `.js` effects that run host code, and proofs do not cover them. Elbow's roadmap has an item to show this before install.

When an item is done, link its commit here and remove it.
