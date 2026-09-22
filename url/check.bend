import Base
import ./url.bend as Url

def show(m: Maybe<&2, Url.Url>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{u}:
      IO.print(Url.encode(u))

def main() -> IO(Unit):
  do IO<Unit>:
    show(Url.parse("/"))
    show(Url.parse("/x?a=1&b=2"))
    show(Url.parse("/a%20b"))
    show(Url.parse("nope"))
