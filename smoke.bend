import Base
import ./http.bend as Http
import ./bytes/bytes.bend as Bytes

def line(kind: String, url: String) -> IO(Unit):
  IO.print(kind ++ " " ++ url)

def ok_page.go(url: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      line("ok", url)
    case False{}:
      line("fail", url)

def ok_page(url: String, m: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match m:
    case Fail{e}:
      line("fail", url)
    case Done{res}:
      Http.Res{+status, headers, body} = res
      ok_page.go(url, U32.is_eq(status, 200))

def ok_tls(url: String, m: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match m:
    case Fail{e}:
      match e:
        case Http.ErrTls{code, why}:
          line("ok", url)
        case Http.ErrUrl{}:
          line("fail", url)
        case Http.ErrDns{}:
          line("fail", url)
        case Http.ErrConnect{code, why}:
          line("fail", url)
        case Http.ErrRead{code, why}:
          line("fail", url)
        case Http.ErrWrite{code, why}:
          line("fail", url)
        case Http.ErrTimeout{}:
          line("fail", url)
        case Http.ErrRedirect{}:
          line("fail", url)
        case Http.ErrBad{}:
          line("fail", url)
    case Done{res}:
      line("fail", url)

def page(+url: String) -> IO(Unit):
  do IO<Unit>:
    m : Result<&1, &1, Http.Err, Http.Res> <- Http.fetch.with("GET", url, Http.empty(), Bytes.new(0), 15000)
    ok_page(url, m)

def tls(+url: String) -> IO(Unit):
  do IO<Unit>:
    m : Result<&1, &1, Http.Err, Http.Res> <- Http.fetch.with("GET", url, Http.empty(), Bytes.new(0), 15000)
    ok_tls(url, m)

def main() -> IO(Unit):
  do IO<Unit>:
    page("http://example.com/")
    page("https://example.com/")
    tls("https://expired.badssl.com/")
    tls("https://wrong.host.badssl.com/")
    tls("https://self-signed.badssl.com/")
