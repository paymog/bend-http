import Base
import ./http.bend as Http

def show_res(res: Http.Res) -> IO(Unit):
  Http.Res{status, +headers, +body} = res
  IO.print(U32.show(status) ++ " bytes=" ++ Nat.show(String.length(body)) ++ " te=" ++ Http.header(headers, "transfer-encoding") ++ " head=" ++ String.take(body, 24n))

def show_err(e: Http.Err) -> IO(Unit):
  match e:
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

def show(url: String, m: Result<&2, &2, Http.Err, Http.Res>) -> IO(Unit):
  match m:
    case Fail{e}:
      do IO<Unit>:
        IO.print(url)
        show_err(e)
    case Done{res}:
      do IO<Unit>:
        IO.print(url)
        show_res(res)

def try(+url: String) -> IO(Unit):
  do IO<Unit>:
    m : Result<&2, &2, Http.Err, Http.Res> <- Http.fetch("GET", url, Http.empty(), "")
    show(url, m)

def main() -> IO(Unit):
  do IO<Unit>:
    try("http://example.com/")
    try("http://httpbin.org/stream/3")
    try("http://httpbin.org/encoding/utf8")
    try("http://no-such-host.invalid/")
    try("not a url")
