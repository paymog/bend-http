import Base
import ./router.bend as R

def show(m: Maybe<&2, Map<&2, String>>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{m}:
      IO.print("hit")

def main() -> IO(Unit):
  do IO<Unit>:
    show(R.route("GET", "GET", "/users/:id", "/users/1"))
    show(R.route("GET", "POST", "/users/:id", "/users/1"))
    show(R.route("GET", "GET", "/x", "/y"))
