import Base
import ./http.bend as Http

def show_req(req: Http.Req) -> IO(Unit):
  Http.Req{method, path, headers, body} = req
  do IO<Unit>:
    IO.print(method ++ " " ++ path ++ " [" ++ body ++ "]")
    IO.print(Http.encode(Http.Res{200, Http.empty(), "ok"}))

def show(m: Maybe<&2, Http.Req>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{req}:
      show_req(req)

def main() -> IO(Unit):
  do IO<Unit>:
    show(Http.parse("GET /x HTTP/1.1\r\n\r\nhello"))
    show(Http.parse("GET /x HTTP/1.1\r\nHost: x\r\n\r\nhello"))
    show(Http.parse("GET /x HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhello"))
    show(Http.parse("GET / HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n"))
    IO.print(Http.res_body(Http.parse_res("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")))
    IO.print(Http.sanitize("a\rb\nc"))
