# bend-net roadmap

This is a backlog, not a promise. Items are grouped by when they matter: **before other people use it**, **after they do**, and **only if someone asks**. Each checkbox is one outcome. Move items when evidence changes.

## Current baseline

- Packages on the Elbow registry: `http@0.9.2`, `url@0.3.1`, `json@0.2.1`, `dns@0.2.1`, `wire@0.3.1`, `encoding@0.2.1`, `router@0.1.1`. Fetch returns `Result` and headers are lists (`f73e022`). The README is `bf9e139`. The Bend hub reads the first comment in path order (`c9b30e0`).
- `Http.fetch(method, url, headers, body)` does http and https, DNS, redirects (20 hops), and a 30 s timeout per step. `fetch.with(..., ms)` sets the timeout. It returns `Result<Res, Err>`: bad URL, DNS, connect, TLS (errno and verify text), read, write, timeout, too many redirects, or a malformed response. `ETIMEDOUT` is 60 on macOS and 110 on Linux. Headers are a list per name. `header` is the first value. `Set-Cookie` is never joined. Encode writes one line per value.
- Bodies are byte strings: one `Char` per octet. `Enc.utf8.decode` turns a body into text.
- `wire` holds the effects Base lacks: byte-exact TCP/UDP, a TCP connect with a deadline, and TLS through OpenSSL 3 loaded at run time (`BEND_LIBSSL` overrides the path). Each effect has a C and a JS version.
- Laws: http 76, url 56, json 35, dns 15, encoding 13, router 3. Run `bend PROOF.bend` in the root and in each package folder.
- Big bodies need a native build (`bend file.bend -o app`). The `bend file.bend` runner overflows on strings over about 30 KB.

## Before other people use it

- [ ] **Test the README on a clean machine.** Including the x86_64 Mac.
- [ ] **Run proofs and smoke tests in CI.** Run every `PROOF.bend` and `check.bend` on each push. Add a live smoke job (example.com over http and https, badssl.com negatives) that may fail without blocking.
- [ ] **Fix the server side.** `serve` reads one 8 KiB recv and parses it, so bigger requests are cut off and get a 400. Read requests with the same `need`/`frame` loop the client uses. `response()` writes "OK" for every status; use the right reason phrase. The server accepts only `HTTP/1.1` request lines.
- [ ] **Fail fast on malformed responses.** A bad chunk or bad framing on an open connection returns `More` and waits until close or timeout. Make `frame` return `Bad` as soon as the bytes cannot become a valid message. Add laws for that.
- [ ] **Detect TLS truncation.** `SSL_OP_IGNORE_UNEXPECTED_EOF` treats a bare EOF as close. A close-delimited body over TLS can therefore be cut short without an error. Content-Length and chunked bodies are safe. Fail when a close-delimited TLS body ends without `close_notify`.
- [ ] **Test the DNS timeout.** The resolver always reads `/etc/resolv.conf`, so the retry path has never run against a silent server. Let tests pass a nameserver, then check 2 attempts × 5 s.

## After people use it

- [ ] **Skip 1xx responses.** `frame` treats a 103 or 100 as the final response. Skip interim responses and frame what follows (RFC 9110 §15.2).
- [ ] **Read other transfer codings until close.** A response with `Transfer-Encoding: gzip` (without chunked) is rejected. RFC 9112 §6.3 says read until close.
- [ ] **IPv6 and more of DNS.** Add AAAA records and IPv6 connect (the runtime's `io_sys_addr` is IPv4 only). Also add `/etc/hosts`, a TCP retry when TC is set, more than one nameserver, and a small TTL cache.
- [ ] **Make the url package total.** `pct.decode.go` and `hexhi.go` are `@unsafe`. Rewrite them with fuel or structural recursion, like the other packages.
- [ ] **Prove universal laws.** Most laws are fixtures. Add laws over all inputs for the claims that matter most: `fetch.gate` never says no to a whole message, `chunk.decode` inverts a chunk encoder, `utf8.decode(utf8.encode(s)) == s`, and `Json.parse(Json.encode(v)) == Some{v}`.
- [ ] **JSON helpers.** Add array index access, number conversion (`Num` text to U32/F32), and an `Http.text` helper that UTF-8 decodes a body. `json.encode` is still `@unsafe` because it walks a work list.
- [ ] **Speed up parsing.** A 1 MB JSON parse takes about 3.4 s of CPU, and a byte string costs one list cell per octet. Measure first; then try an array-backed buffer or chunked strings.
- [ ] **Report the runner overflow upstream.** `String.repeat`/`String.length` on about 30 KB overflows in the `bend file.bend` runner but not in native builds. Report it to Bend with the three-line repro.

## Only if someone asks

- [ ] Keep-alive and connection pools (`fetch` sends `connection: close` today).
- [ ] Streaming request and response bodies.
- [ ] gzip/br decoding (`Accept-Encoding`).
- [ ] A cookie jar, proxies (`HTTP_PROXY`), client certificates, ALPN, HTTP/2.
- [ ] Windows support (the effects use POSIX sockets and `dlopen`).

## Depends on Elbow

- Publishing needs `ELBOW_TOKEN`; `ELBOW_TOKEN=$(gh auth token)` works. Token scope is tracked in Elbow's roadmap.
- Packages ship `.c` and `.js` effects that run host code, and proofs do not cover them. Elbow's roadmap has an item to show this before install.

When an item is done, link its commit here and remove it.
