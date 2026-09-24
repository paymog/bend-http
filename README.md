# bend-net

HTTP/1.1 client and server for Bend. `http` does `http://` and `https://`, DNS, redirects, and timeouts. Bodies are byte strings: one `Char` per octet.

`http@0.11.0` is a break from `http@0.10.0`: `Got` has a `GotHead` case, and the old serve internals (`serve.try`, `req.need`, `req.after`) are gone. `http@0.10.0` changed `exchange` to return the socket as `Maybe<Socket>`.

## Install

You need [Bend 2.0.26 or newer](https://bend-lang.com/install.sh), [Bun 1.4.2](https://bun.sh/docs/installation), and Elbow 0.1.0. macOS or Linux, including WSL. Windows is not supported.

```sh
version=0.1.0
curl -fsSLO "https://github.com/elbowpm/elbow/releases/download/v${version}/elbow-${version}.tar.gz"
curl -fsSLO "https://github.com/elbowpm/elbow/releases/download/v${version}/elbow-${version}.tar.gz.sha256"
shasum -a 256 -c "elbow-${version}.tar.gz.sha256" # Linux: sha256sum -c
mkdir -p "$HOME/.local/bin"
tar -xzf "elbow-${version}.tar.gz" --strip-components=2 -C "$HOME/.local/bin" "elbow-${version}/bin/elbow"
export PATH="$HOME/.local/bin:$PATH"
```

Create `main.bend`, then:

```sh
elbow add http@0.11.0
```

Elbow writes a hash import, `elbow.toml`, and `elbow.lock`. Commit those. `http` ships `.c` and `.js` effects. They run host code. Proofs do not cover them.

HTTPS needs OpenSSL 3 at run time. On macOS, `brew install openssl@3`. The client looks for Homebrew's `libssl.3.dylib`, then `libssl.so.3`. Set `BEND_LIBSSL` to the library path if it is somewhere else.

## Fetch

```bend
import Base

def show(got: Result<&2, &2, Http.Err, Http.Res>) -> IO(Unit):
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
    got : Result<&2, &2, Http.Err, Http.Res> <- Http.get("https://example.com/")
    show(got)
```

`Http.fetch(method, url, headers, body)` is the same call with a method, headers, and body. `Http.fetch.with(..., ms)` sets the per-step timeout. The default is 30 seconds. A redirect chain stops after 20 hops (`ErrRedirect`). `Http.fetch.how(..., ms, mode)` chooses the policy: `ModeFollow` follows, `ModeManual` returns the 3xx, `ModeError` fails on a redirect. `ETIMEDOUT` is 60 on macOS and 110 on Linux. Both become `ErrTimeout`.

`Http.get` is `fetch("GET", url, Http.empty(), "")`.

A response body over about 30 KB overflows `bend file.bend`. Compile it. That needs clang 14 or newer (`apt install clang` on Debian 12 or Ubuntu 22.04 and later; `xcode-select --install` on macOS):

```sh
bend file.bend -o app
```

## Headers

A header map is `Map<String, List<String>>`. Names are lowercase after parse.

`Http.empty()` is an empty map. `Http.set(m, k, v)` replaces `k` with one value. `Http.add(m, k, v)` appends. `Http.header(h, k)` is the first value, or `""`. `Http.fields(h, k)` is the list.

Repeated `Set-Cookie` lines stay separate. Encode writes one line per value. A second `Host` or `Content-Length` is rejected.

## Bodies

A body is bytes. `Http.text(res)` decodes it as UTF-8. A bad byte becomes U+FFFD. `Http.json(res)` parses that text. `Json.at(v, n)` is an array element. `Json.u32(v)` is a whole number that fits in `U32`. `Url.form(m)` is an `application/x-www-form-urlencoded` body. Space is `%20`.

A response with `Transfer-Encoding` other than `chunked` is read until the connection closes. The bytes are not decoded. `Content-Length` together with `Transfer-Encoding` is rejected. A response over 16 MiB of body and 64 KiB of head is `ErrBad`. `Http.after(raw, head)` is the bytes after a complete self-delimited message, or `None` if the message is not finished or runs until close. `Http.encode_req.on(..., False)` sends `keep-alive`. `Http.exchange(tls, ms, close, head, socket, bytes)` writes one request on that socket. It returns `Some{socket}` when the socket can take another request, the result, and any bytes already read past the response.

## Compressed bodies

`fetch` sends `accept-encoding: gzip, deflate` unless you set `Accept-Encoding` yourself. It decodes the body per `Content-Encoding`: `gzip` and `x-gzip`, `deflate` with or without the zlib wrapper, and `identity`. A list of codings is undone in reverse order. An unknown coding, such as `br`, leaves the body as sent. A corrupt body is `ErrBad`. The headers stay as the server sent them, so `content-length` is the compressed size. `Http.decoded(res)` does the same for a response you got another way. `exchange` never decodes.

The `zlib` package has `Zlib.inflate` (raw DEFLATE, RFC 1951), `Zlib.gunzip` (RFC 1952, one member, CRC-32 and size checked), `Zlib.unzlib` (RFC 1950, Adler-32 checked), `Zlib.crc32`, and `Zlib.adler32`. Each returns `None` for malformed or cut-short input. A 1 MB body decodes in about 0.1 s natively.

## Streams

`Http.open(method, url, headers, body)` follows redirects like `fetch` and returns a `Stream` as soon as the head is in. `Http.stream.res(st)` gives the status and headers (its body is `""`). `Http.stream.read(st)` returns the next piece of the body, or `None` at the end; a piece is never empty. `Http.stream.close(st)` closes the connection. Content-Length, chunked, and close-delimited bodies all stream, and interim 1xx responses are skipped. A stream sends no `Accept-Encoding` and returns the bytes as sent. Streaming a 50 MB body keeps the program under 10 MB.

`Http.upload(method, url, headers)` sends the head with `Transfer-Encoding: chunked`. `Http.upload.write(up, piece)` sends one chunk; an empty piece sends nothing. `Http.upload.finish(up)` ends the body and returns the response as a `Stream`. A streamed request body cannot be replayed, so uploads do not follow redirects. `open.with` and `upload.with` take a step timeout.

## Pool

```bend
def next(pr: Http.Pool & Result<&2, &2, Http.Err, Http.Res>) -> IO(Http.Pool & Result<&2, &2, Http.Err, Http.Res>):
  (p, first) = pr
  Http.pool.fetch(p, "GET", "https://example.com/b", Http.empty(), "")

def done(pr: Http.Pool & Result<&2, &2, Http.Err, Http.Res>) -> IO(Unit):
  (p, second) = pr
  Http.pool.close(p)

def main() -> IO(Unit):
  do IO<Unit>:
    r1 : Http.Pool & Result<&2, &2, Http.Err, Http.Res> <- Http.pool.fetch(Http.pool.new(), "GET", "https://example.com/a", Http.empty(), "")
    r2 : Http.Pool & Result<&2, &2, Http.Err, Http.Res> <- next(r1)
    done(r2)
```

`Http.pool.fetch(p, method, url, headers, body)` is `fetch` on the pool's idle sockets. It returns the pool with the result. Pass that pool to the next call. A pool holds one idle socket per scheme, host, and port. Redirects use the pool too. When a reused socket fails before any response byte, a GET, HEAD, OPTIONS, TRACE, PUT, or DELETE is retried once on a new connection; other methods fail. `Http.pool.fetch.with(..., ms)` sets the step timeout. `Http.pool.how(..., ms, mode)` sets the redirect mode. `Http.pool.close(p)` closes the idle sockets. `Http.fetch` is a pool of its own that closes when the call ends.

## Serve

```bend
def hello(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Res, Http.Res{200, Http.empty(), path})

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
