# Upload benchmark: answers the body length. Build with -o, then time a 16 MiB upload:
#   curl -s --data-binary @16m.bin http://127.0.0.1:18093/
import Base
import ../http.bend as Http
import 0xbf22530d1ea11c951d1ecaa353ed1580/bytes.bend as Bytes

def len(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = req
  Bytes.Bytes{+n, buf} = body
  IO.pure(Http.Res, Http.Res{200, Http.empty(), Bytes.from_string(U32.show(n))})

def main() -> IO(Unit):
  Http.serve.with(~len, 18093, 33554432n)
