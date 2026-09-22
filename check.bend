import Base
import ./http.bend as Http

def show(req: Http.Req) -> IO(Unit):
  Http.Req{method, path, body} = req
  do IO<Unit>:
    IO.print(method ++ " " ++ path ++ " " ++ body)
    IO.print(Http.encode(Http.Res{200, "ok"}))

def main() -> IO(Unit):
  show(Http.parse("GET /x HTTP/1.1\r\n\r\nhello"))
