import Base
import ./http.bend as Http

def show_res(res: Http.Res) -> IO(Unit):
  Http.Res{status, +headers, +body} = res
  IO.print(U32.show(status) ++ " bytes=" ++ Nat.show(String.length(body)) ++ " te=" ++ Http.header(headers, "transfer-encoding") ++ " head=" ++ String.take(body, 24n))

def show(url: String, m: Maybe<&2, Http.Res>) -> IO(Unit):
  match m:
    case None{}:
      IO.print(url ++ " -> none")
    case Some{res}:
      do IO<Unit>:
        IO.print(url)
        show_res(res)

def try(+url: String) -> IO(Unit):
  do IO<Unit>:
    m : Maybe<&2, Http.Res> <- Http.fetch("GET", url, Http.empty(), "")
    show(url, m)

def main() -> IO(Unit):
  do IO<Unit>:
    try("http://example.com/")
    try("http://httpbin.org/stream/3")
    try("http://httpbin.org/encoding/utf8")
    try("http://no-such-host.invalid/")
    try("not a url")
