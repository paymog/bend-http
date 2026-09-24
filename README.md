# bend-net

HTTP/1.1 client and server for Bend. `http` does `http://` and `https://`, DNS, redirects, and timeouts. Bodies are byte strings: one `Char` per octet.

`http@0.9.2` is a break from `http@0.8.0`. `fetch` returns `Result`, not `Maybe`. Each header name holds a list of values.

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
elbow add http@0.9.2
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

A response with `Transfer-Encoding` other than `chunked` is read until the connection closes. The bytes are not decoded. `Content-Length` together with `Transfer-Encoding` is rejected. `Http.after(raw, head)` is the bytes after a complete self-delimited message, or `None` if the message is not finished or runs until close. `Http.encode_req.on(..., False)` sends `keep-alive`. `Http.exchange(tls, ms, close, head, socket, bytes)` writes one request on that socket. It returns `True` when the socket is still open and can take another request, plus any bytes already read past this response. `fetch` still closes.

## Serve

```bend
def hello(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Res, Http.Res{200, Http.empty(), path})

def main() -> IO(Unit):
  Http.serve(~hello, 18080)
```

`Http.serve(~h, port)` reads each request until it is whole, calls `h`, sends the response, and closes. A request line must be `HTTP/1.1` (with `Host`) or `HTTP/1.0`. A malformed request gets 400. A request over 1 MiB gets 413. A silent client is dropped after 30 seconds. Responses use the RFC 9110 reason phrase. HEAD, 1xx, 204, and 304 responses have no body.

## Proofs

From a clone of this repo:

```sh
bend PROOF.bend
```

Run that in the root and in each package folder.
