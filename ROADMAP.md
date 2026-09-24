# bend-net roadmap

The goal is the best HTTP library for Bend. This is a ranked backlog, not a promise. The top of **Next** is what we work on now. Each checkbox is one outcome. Re-rank items when evidence changes.

## Current baseline

- Packages on the Elbow registry: `http@0.9.2`, `url@0.3.1`, `json@0.2.1`, `dns@0.2.1`, `wire@0.3.1`, `encoding@0.2.1`, `router@0.1.1`. Fetch returns `Result` and headers are lists (`f73e022`). The README is `bf9e139`. The Bend hub reads the first comment in path order (`c9b30e0`).
- `Http.fetch(method, url, headers, body)` does http and https, DNS, redirects (20 hops), and a 30 s timeout per step. `fetch.with(..., ms)` sets the timeout. It returns `Result<Res, Err>`: bad URL, DNS, connect, TLS (errno and verify text), read, write, timeout, too many redirects, or a malformed response. `ETIMEDOUT` is 60 on macOS and 110 on Linux. Headers are a list per name. `header` is the first value. `Set-Cookie` is never joined. Encode writes one line per value.
- Bodies are byte strings: one `Char` per octet. `Http.text` decodes UTF-8. `Http.json` parses that text. `Url.form` writes a form body.
- `wire` holds the effects Base lacks: byte-exact TCP/UDP, a TCP connect with a deadline, and TLS through OpenSSL 3 loaded at run time (`BEND_LIBSSL` overrides the path). Each effect has a C and a JS version.
- `bytes` (not yet published) is a byte buffer packed four bytes to a `U32` `Array` slot. It has bounds-checked `get`/`set`, `slice`, `append`, `find`, and `eq`, and it converts to and from byte strings. `bench/bytes` measures the layout. Nothing uses it yet.
- Laws: http 119, url 57, json 40, dns 18, bytes 33, encoding 13, router 3. Run `bend PROOF.bend` in the root and in each package folder.
- Big bodies need a native build (`bend file.bend -o app`). The `bend file.bend` runner overflows on strings over about 30 KB.
- A bad chunk or bad framing is `FrameBad` while the connection is still open. A close-delimited TLS body that ends without `close_notify` is a read error. Content-Length and chunked bodies do not wait for that close. `100` and `103` are skipped; `101` is final.
- `Dns.resolve` checks `/etc/hosts`, then the first three nameservers. `resolve.at` asks one server. A silent server is 2 attempts × 5 s, then the next server. `Http.exchange` does one request on an open socket and says whether that socket can take another.
- `Http.serve` reads until the request is whole (Content-Length or chunked), up to 1 MiB, then answers and closes. It sends the RFC 9110 reason phrase, `connection: close`, no body for HEAD, 1xx, 204 and 304, and accepts `HTTP/1.0` without `Host`. A bad request is 400; a request over 1 MiB is 413.
- The README install and fetch example pass on clean Debian 12 containers (arm64 and amd64), in the runner and as a native build. The x86_64 Mac is not tested.

## Next

- [ ] **Frame requests incrementally.** `serve` re-frames the whole buffer after each read, which is O(n²), so requests stop at 1 MiB. Reverse-buffer and gate like `fetch.loop`, then let the caller set the cap.
- [ ] **Serve more than one request per connection.** `serve` closes after each response. Add keep-alive and pipelining with the leftover bytes, as `exchange` does for the client.
- [ ] **A connection pool for fetch.** `exchange` leaves a socket open when another request can follow, but `fetch` still closes. Build a pool on top of `exchange`.
- [ ] **gzip and deflate decoding.** Send `Accept-Encoding` and decode the body. Add br if a decoder is feasible.
- [ ] **Stream request and response bodies.** Today every body is one string in memory.
- [ ] **Speed up parsing.** A 1 MB JSON parse takes about 3.4 s of CPU, and a byte string costs one list cell per octet. `bytes` is the array-backed buffer. Next, have `wire.recv` fill `Bytes` directly, then move `Http` framing onto it. That is a breaking change to `Res.body`.
- [ ] **Prove universal laws.** Most laws are fixtures. Add laws over all inputs for the claims that matter most: `fetch.gate` never says no to a whole message, `chunk.decode` inverts a chunk encoder, `parse.got` never says Bad to a prefix of a valid request, `utf8.decode(utf8.encode(s)) == s`, `Json.parse(Json.encode(v)) == Some{v}`, and `Bytes.to_string(Bytes.from_string(s)) == s` for every byte string.
- [ ] **IPv6 and the rest of DNS.** Add AAAA records and IPv6 connect (the runtime's `io_sys_addr` is IPv4 only). Also add a TCP retry when TC is set, and a small TTL cache.
- [ ] **Report the runner overflow upstream.** `String.repeat`/`String.length` on about 30 KB overflows in the `bend file.bend` runner but not in native builds. Report it to Bend with the three-line repro.

## Later

- [ ] **Make the url package total.** `pct.decode.go` and `hexhi.go` are `@unsafe`. Rewrite them with fuel or structural recursion, like the other packages.
- [ ] **JSON number to F32.** `Json.at` and `Json.u32` exist. `json.encode` is still `@unsafe` because it walks a work list.
- [ ] A cookie jar, proxies (`HTTP_PROXY`), client certificates, ALPN, HTTP/2.
- [ ] Windows support (the effects use POSIX sockets and `dlopen`).
- [ ] Test on an x86_64 Mac.

## Depends on Elbow

- Publishing needs `ELBOW_TOKEN`; `ELBOW_TOKEN=$(gh auth token)` works. Token scope is tracked in Elbow's roadmap.
- Packages ship `.c` and `.js` effects that run host code, and proofs do not cover them. Elbow's roadmap has an item to show this before install.

When an item is done, link its commit here and remove it.
