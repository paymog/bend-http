import Base
import ./zlib.bend as Z

def show(m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{s}:
      IO.print(s)

def main() -> IO(Unit):
  do IO<Unit>:
    show(Z.inflate(SCon{Chr{203}, SCon{Chr{72}, SCon{Chr{205}, SCon{Chr{201}, SCon{Chr{201}, SCon{Chr{7}, SCon{Chr{0}, SNil{}}}}}}}}))
    show(Z.inflate("x"))
