# bend-net roadmap

This is a backlog, not a promise. Items are grouped by when they matter: **before other people use it**, **after they do**, and **only if someone asks**. Each checkbox is one outcome. Move items when evidence changes.

## Current baseline

- Packages on the Elbow registry: `http@0.9.2`, `url@0.3.1`, `json@0.2.1`, `dns@0.2.1`, `wire@0.3.1`, `encoding@0.2.1`, `router@0.1.1`. Fetch returns `Result` and headers are lists (`f73e022`). The README is `bf9e139`. The Bend hub reads the first comment in path order (`c9b30e0`).
- `Http.fetch(method, url, headers, body)` does http and https, DNS, redirects (20 hops), and a 30 s timeout per step. `fetch.with(..., ms)` sets the timeout. It returns `Result<Res, Err>`: bad URL, DNS, connect, TLS (errno and verify text), read, write, timeout, too many redirects, or a malformed response. `ETIMEDOUT` is 60 on macOS and 110 on Linux. Headers are a list per name. `header` is the first value. `Set-Cookie` is never joined. Encode writes one line per value.
- Bodies are byte strings: one `Char` per octet. `Http.text` decodes UTF-8. `Http.json` parses that text. `Url.form` writes a form body.
- `wire` holds the effects Base lacks: byte-exact TCP/UDP, a TCP connect with a deadline, and TLS through OpenSSL 3 loaded at run time (`BEND_LIBSSL` overrides the path). Each effect has a C and a JS version.
- Laws: http 108, url 57, json 40, dns 18, encoding 13, router 3. Run `bend PROOF.bend` in the root and in each package folder.
- Big bodies need a native build (`bend file.bend -o app`). The `bend file.bend` runner overflows on strings over about 30 KB.
- A bad chunk or bad framing is `FrameBad` while the connection is still open. A close-delimited TLS body that ends without `close_notify` is a read error. Content-Length and chunked bodies do not wait for that close. `100` and `103` are skipped; `101` is final.
- `Dns.resolve` checks `/etc/hosts`, then the first three nameservers. `resolve.at` asks one server. A silent server is 2 attempts × 5 s, then the next server. `Http.exchange` does one request on an open socket and says whether that socket can take another.

## Before other people use it

- [ ] **Test the README on a clean machine.** Including the x86_64 Mac.
- [ ] **Run proofs and smoke tests in CI.** Run every `PROOF.bend` and `check.bend` on each push. Add a live smoke job (example.com over http and https, badssl.com negatives) that may fail without blocking.
- [ ] **Fix the server side.** `serve` reads one 8 KiB recv and parses it, so bigger requests are cut off and get a 400. Read requests with the same `need`/`frame` loop the client uses. `response()` writes "OK" for every status; use the right reason phrase. The server accepts only `HTTP/1.1` request lines.

## After people use it

- [ ] **IPv6 and the rest of DNS.** Add AAAA records and IPv6 connect (the runtime's `io_sys_addr` is IPv4 only). Also add a TCP retry when TC is set, and a small TTL cache. `/etc/hosts` is read. The first three nameservers are tried.
- [ ] **Make the url package total.** `pct.decode.go` and `hexhi.go` are `@unsafe`. Rewrite them with fuel or structural recursion, like the other packages.
- [ ] **Prove universal laws.** Most laws are fixtures. Add laws over all inputs for the claims that matter most: `fetch.gate` never says no to a whole message, `chunk.decode` inverts a chunk encoder, `utf8.decode(utf8.encode(s)) == s`, and `Json.parse(Json.encode(v)) == Some{v}`.
- [ ] **JSON number to F32.** `Json.at` and `Json.u32` exist. `json.encode` is still `@unsafe` because it walks a work list.
- [ ] **Speed up parsing.** A 1 MB JSON parse takes about 3.4 s of CPU, and a byte string costs one list cell per octet. Measure first; then try an array-backed buffer or chunked strings.
- [ ] **Report the runner overflow upstream.** `String.repeat`/`String.length` on about 30 KB overflows in the `bend file.bend` runner but not in native builds. Report it to Bend with the three-line repro.

## Only if someone asks

- [ ] **A connection pool.** `exchange` does one request on an open socket and leaves it open when another request can follow. `fetch` still closes. A pool on top of `exchange` is not built.
- [ ] Streaming request and response bodies.
- [ ] gzip/br decoding (`Accept-Encoding`).
- [ ] A cookie jar, proxies (`HTTP_PROXY`), client certificates, ALPN, HTTP/2.
- [ ] Windows support (the effects use POSIX sockets and `dlopen`).

## Depends on Elbow

- Publishing needs `ELBOW_TOKEN`; `ELBOW_TOKEN=$(gh auth token)` works. Token scope is tracked in Elbow's roadmap.
- Packages ship `.c` and `.js` effects that run host code, and proofs do not cover them. Elbow's roadmap has an item to show this before install.

When an item is done, link its commit here and remove it.
