# Download benchmark: fetches the URL in argv 1 and prints the body length and the time.
#   python3 dl.py 18094 &; ./fetch16 http://127.0.0.1:18094/cl
import Base
import ../http.bend as Http
import ../bytes/bytes.bend as Bytes

def report(+t0: Nat, +t1: Nat, r: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("fail")
    case Done{res}:
      Http.Res{status, headers, body} = res
      Bytes.Bytes{+len, buf} = body
      IO.print({U32.show(status) ++ " " ++ U32.show(len) ++ " " ++ Nat.show(Nat.sub(t1, t0)) ++ " ms" : String})

def url(xs: List<&1, String>) -> String:
  match xs:
    case Nil{}:
      "http://127.0.0.1:18094/cl"
    case Con{x, t}:
      x

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    t0 : Nat <- IO.now()
    r : Result<&1, &1, Http.Err, Http.Res> <- Http.fetch("GET", url(args), Http.set(Http.empty(), "accept-encoding", "identity"), Bytes.new(0))
    t1 : Nat <- IO.now()
    report(t0, t1, r)
