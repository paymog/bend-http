# bend-net

HTTP/1.1 client and server for Bend. `http` does `http://` and `https://`, DNS, redirects, and timeouts. Bodies are packed bytes (`Http.Body`).

`bend-net-http@0.14.0.0` is `http@0.13.1` moved to the Bend hub. Each package's hub description links to its folder here. It imports its sibling packages by name, so their types are shared with your code. `http@0.13.0` is a break from `http@0.12.0`: request and response bodies, stream pieces, and the wire bytes of `encode`, `encode_req`, and `exchange` are `Http.Body`. `http@0.13.1` adds `Http.Body`, `Http.from_string`, `Http.to_string`, and `Http.length`. `Req` and `Res` are `Type`, so a value is used once: its result type is `Result<&1, &1, Http.Err, Http.Res>`. `http@0.12.0` removed the client read internals (`need`, `fetch.gate`, `Sf`). `http@0.11.0` added `GotHead` to `Got`. `http@0.10.0` changed `exchange` to return the socket as `Maybe<Socket>`.

## Install

You need [Bend 2.0.27 or newer](https://bend-lang.com/install.sh) and [Bun 1.4.2](https://bun.sh/docs/installation). macOS or Linux, including WSL. Windows is not supported.

The packages are on the Bend hub. Import one at the top of your file, and `bend` fetches it and checks it against its hash:

```bend
import 0x6ee8b4f8d8a8f10e385dccb59e74e665/http.bend as Http
```

| Package | Import | What it does |
|---|---|---|
| `bend-net-http@0.14.0.0` | `0x6ee8b4f8d8a8f10e385dccb59e74e665/http.bend` | HTTP/1.1 client and server for http and https, with DNS and TLS. |
| `bend-net-bytes@0.2.0.1` | `0xdcce81c809e7aeb2e2c2fb775d28e0dc/bytes.bend` | Byte buffers packed four bytes to a `U32`, with bounds-checked access. |
| `bend-net-wire@0.4.0.1` | `0xd0e5dfa14254dc2d25247f592b3afbe2/wire.bend` | Byte-exact TCP, UDP, and TLS sockets. |
| `bend-net-url@0.4.0.1` | `0x3f15daecd30cac66472f8e312600ba3b/url.bend` | URL parsing, resolution, and percent-encoding (RFC 3986). |
| `bend-net-json@0.3.0.1` | `0x2213bb53d5eea36896815fc5b459bb6e/json.bend` | JSON values, parsed and encoded as RFC 8259. |
| `bend-net-encoding@0.2.1.1` | `0x58d0718042afbd57ac3a0124bfc0570f/encoding.bend` | UTF-8 and hex encoding for byte strings. |
| `bend-net-dns@0.3.1.0` | `0x4ae4f319f4174df6a2ae71eb32ba9642/dns.bend` | DNS A-record lookup over UDP. |
| `bend-net-zlib@0.1.0.0` | `0x05a6d0cd384bf4ebc144f0bc1b2d2350/zlib.bend` | DEFLATE, gzip, and zlib decoding (RFC 1951, 1952, 1950). |
| `bend-net-router@0.1.1.0` | `0xe160436f9c54f3dba1bd01de3117931e/router.bend` | Match an HTTP method and path to a handler. |

A name and its hash import the same package. `http` imports the others from the hub, so a `Json.Val`, `Url.Abs`, or body from your own import of `bend-net-json`, `bend-net-url`, or `bend-net-bytes` is the same type that `http` uses. `http` and `wire` ship `.c` and `.js` effects. They run host code. Proofs do not cover them.

HTTPS needs OpenSSL 3 at run time. On macOS, `brew install openssl@3`. The client looks for Homebrew's `libssl.3.dylib`, then `libssl.so.3`. Set `BEND_LIBSSL` to the library path if it is somewhere else.

## Fetch

```bend
import Base

def show(got: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match got:
    case Done{res}:
      Http.Res{status, headers, body} = res
      IO.print(U32.show(status) ++ " " ++ Http.header(headers, "content-type"))
    case Fail{err}:
      match err:
        case Http.ErrUrl{}:
          IO.print("bad url")
        case Http.ErrDns{}:
          IO.print("dns")
        case Http.ErrConnect{code, why}:
          IO.print("connect " ++ U32.show(code) ++ " " ++ why)
        case Http.ErrTls{code, why}:
          IO.print("tls " ++ U32.show(code) ++ " " ++ why)
        case Http.ErrRead{code, why}:
          IO.print("read " ++ U32.show(code) ++ " " ++ why)
        case Http.ErrWrite{code, why}:
          IO.print("write " ++ U32.show(code) ++ " " ++ why)
        case Http.ErrTimeout{}:
          IO.print("timeout")
        case Http.ErrRedirect{}:
          IO.print("redirect")
        case Http.ErrBad{}:
          IO.print("bad response")

def main() -> IO(Unit):
  do IO<Unit>:
    got : Result<&1, &1, Http.Err, Http.Res> <- Http.get("https://example.com/")
    show(got)
```

`Http.fetch(method, url, headers, body)` is the same call with a method, headers, and body. `Http.fetch.with(..., ms)` sets the per-step timeout. The default is 30 seconds. A redirect chain stops after 20 hops (`ErrRedirect`). `Http.fetch.how(..., ms, mode)` chooses the policy: `ModeFollow` follows, `ModeManual` returns the 3xx, `ModeError` fails on a redirect. `ETIMEDOUT` is 60 on macOS and 110 on Linux. Both become `ErrTimeout`.

`Http.get` is `fetch("GET", url, Http.empty(), Http.from_string(""))`.

A response body over about 30 KB overflows `bend file.bend`. Compile it. That needs clang 14 or newer (`apt install clang` on Debian 12 or Ubuntu 22.04 and later; `xcode-select --install` on macOS):

```sh
bend file.bend -o app
```

## Headers

A header map is `Map<String, List<String>>`. Names are lowercase after parse.

`Http.empty()` is an empty map. `Http.set(m, k, v)` replaces `k` with one value. `Http.add(m, k, v)` appends. `Http.header(h, k)` is the first value, or `""`. `Http.fields(h, k)` is the list.

Repeated `Set-Cookie` lines stay separate. Encode writes one line per value. A second `Host` or `Content-Length` is rejected.

## Bodies

A body is an `Http.Body`: bytes packed four to a `U32`. `Http.from_string(s)` makes one from a byte string (one `Char` per octet), and `Http.to_string(b)` turns it back. `Http.length(b)` returns the body and its length in bytes. `Http.Body` is `Bytes.Bytes` from `bend-net-bytes@0.2.0.1`, so you can also import that package and use it directly. `Http.text(res)` decodes the body as UTF-8. A bad byte becomes U+FFFD. `Http.json(res)` parses that text. `Json.at(v, n)` is an array element. `Json.u32(v)` is a whole number that fits in `U32`. `Url.form(m)` is an `application/x-www-form-urlencoded` body. Space is `%20`.

A response with `Transfer-Encoding` other than `chunked` is read until the connection closes. The bytes are not decoded. `Content-Length` together with `Transfer-Encoding` is rejected. A response over 16 MiB of body and 64 KiB of head is `ErrBad`. `Http.after(raw, head)` is the bytes after a complete self-delimited message, or `None` if the message is not finished or runs until close. `Http.encode_req(method, target, host, headers, body)` is the request as an `Http.Body`; `Http.encode_req.on(..., False)` sends `keep-alive`. `Http.exchange(tls, ms, close, head, socket, bytes)` writes one request on that socket. It returns `Some{socket}` when the socket can take another request, the result, and any bytes already read past the response.

## Compressed bodies

`fetch` sends `accept-encoding: gzip, deflate` unless you set `Accept-Encoding` yourself. It decodes the body per `Content-Encoding`: `gzip` and `x-gzip`, `deflate` with or without the zlib wrapper, and `identity`. A list of codings is undone in reverse order. An unknown coding, such as `br`, leaves the body as sent. A corrupt body is `ErrBad`. The headers stay as the server sent them, so `content-length` is the compressed size. `Http.decoded(res)` does the same for a response you got another way. `exchange` never decodes.

The `bend-net-zlib` package has `Zlib.inflate` (raw DEFLATE, RFC 1951), `Zlib.gunzip` (RFC 1952, one member, CRC-32 and size checked), `Zlib.unzlib` (RFC 1950, Adler-32 checked), `Zlib.crc32`, and `Zlib.adler32`. Each returns `None` for malformed or cut-short input. A 1 MB body decodes in about 0.1 s natively.

## Streams

`Http.open(method, url, headers, body)` follows redirects like `fetch` and returns a `Stream` as soon as the head is in. `Http.stream.res(st)` gives the status and headers (its body is empty). `Http.stream.read(st)` returns the next piece of the body as an `Http.Body`, or `None` at the end; a piece is never empty. `Http.stream.close(st)` closes the connection. Content-Length, chunked, and close-delimited bodies all stream, and interim 1xx responses are skipped. A stream sends no `Accept-Encoding` and returns the bytes as sent. Streaming a 50 MB body keeps the program under 10 MB.

`Http.upload(method, url, headers)` sends the head with `Transfer-Encoding: chunked`. `Http.upload.write(up, piece)` sends one `Http.Body` chunk; an empty piece sends nothing. `Http.upload.finish(up)` ends the body and returns the response as a `Stream`. A streamed request body cannot be replayed, so uploads do not follow redirects. `open.with` and `upload.with` take a step timeout.

## Pool

```bend
def next(pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) -> IO(Http.Pool & Result<&1, &1, Http.Err, Http.Res>):
  (p, first) = pr
  Http.pool.fetch(p, "GET", "https://example.com/b", Http.empty(), Http.from_string(""))

def done(pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  (p, second) = pr
  Http.pool.close(p)

def main() -> IO(Unit):
  do IO<Unit>:
    r1 : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <- Http.pool.fetch(Http.pool.new(), "GET", "https://example.com/a", Http.empty(), Http.from_string(""))
    r2 : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <- next(r1)
    done(r2)
```

`Http.pool.fetch(p, method, url, headers, body)` is `fetch` on the pool's idle sockets. It returns the pool with the result. Pass that pool to the next call. A pool holds one idle socket per scheme, host, and port. Redirects use the pool too. When a reused socket fails before any response byte, a GET, HEAD, OPTIONS, TRACE, PUT, or DELETE is retried once on a new connection; other methods fail. `Http.pool.fetch.with(..., ms)` sets the step timeout. `Http.pool.how(..., ms, mode)` sets the redirect mode. `Http.pool.close(p)` closes the idle sockets. `Http.fetch` is a pool of its own that closes when the call ends.

## Serve

```bend
def hello(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Res, Http.Res{200, Http.empty(), Http.from_string(path)})

def main() -> IO(Unit):
  Http.serve(~hello, 18080)
```

`Http.serve(~h, port)` reads each request until it is whole, calls `h`, and sends the response. HTTP/1.1 connections stay open unless the request or response says `Connection: close`; HTTP/1.0 connections close after each response. Pipelined requests are handled in order. `Http.serve.with(~h, port, max)` sets the maximum request size in bytes; `serve` defaults to 16 MiB. A malformed request gets 400, a request over the cap gets 413, and a header block over 64 KiB gets 431. Chunked bodies are decoded as they arrive, so a large upload costs time in proportion to its size. An idle client is dropped after 30 seconds. Responses use the RFC 9110 reason phrase. HEAD, 1xx, 204, and 304 responses have no body.

## Proofs

From a clone of this repo:

```sh
bend PROOF.bend
```

Run that in the root and in each package folder.
