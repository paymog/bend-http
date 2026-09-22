import Base
import ./http.bend as Http

def show_res(res: Http.Res) -> IO(Unit):
  Http.Res{status, headers, body} = res
  IO.print(U32.show(status) ++ " " ++ body)

def show(m: Maybe<&2, Http.Res>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{res}:
      show_res(res)

def main() -> IO(Unit):
  do IO<Unit>:
    m : Maybe<&2, Http.Res> <- Http.fetch("GET", "127.0.0.1", 18080, "localhost", "/hello", "")
    show(m)
