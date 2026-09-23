import Base
import ./json.bend as Json

def show(m: Maybe<&2, Json.Val>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{v}:
      IO.print(Json.encode(v))

def main() -> IO(Unit):
  do IO<Unit>:
    show(Json.parse("null"))
    show(Json.parse(" true "))
    show(Json.parse("[]"))
    show(Json.parse("{}"))
    show(Json.parse("-12.5e+3"))
    show(Json.parse("\"hi\\n\\u00e9\""))
    show(Json.parse("null x"))
    show(Json.parse("{\"b\":[1,{\"c\":null}],\"a\":true}"))
    show(Json.parse("[1,]"))
