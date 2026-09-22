import Base
import ./encoding.bend as Hex

def show(m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{s}:
      IO.print(s)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Hex.encode("A"))
    show(Hex.decode(Hex.encode("A")))
    show(Hex.decode("zz"))
    show(Hex.decode("a"))
