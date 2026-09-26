import Base
import ./regex.bend as R

def show(m: Maybe<&2, R.Regex>, s: String) -> IO(Unit):
  match m:
    case None{}:
      IO.print("error")
    case Some{re}:
      IO.print(Bool.show(R.is_match(re, s)))

# (a*)*b against n a's: exponential for a backtracker, linear here.
def main() -> IO(Unit):
  do IO<Unit>:
    show(R.compile("(a*)*b"), String.repeat("a", 20000n))
    show(R.compile("(a*)*b"), String.repeat("a", 20000n) ++ "b")
    show(R.compile("(x+x+)+y"), String.repeat("x", 20000n))
