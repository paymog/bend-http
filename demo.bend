import Base
import ./http.bend as Http

def hello(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Res, Http.Res{200, Http.empty(), path})

def main() -> IO(Unit):
  Http.serve(~hello, 18080)
