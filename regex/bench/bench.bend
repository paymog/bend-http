# Regex benchmark: match and search on fixed inputs (see README.md).
import Base
import ../regex.bend as R

def mix(+acc: U32, +x: U32) -> U32:
  (acc * 31 + x : U32)

def chk_sp(m: Maybe<&2, R.Span>, +acc: U32) -> U32:
  match m:
    case None{}:
      (acc * 31 : U32)
    case Some{R.Span{start, end}}:
      mix(mix(acc, start), end)

def chk_spans(xs: List<&2, Maybe<&2, R.Span>>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      chk_spans(t, chk_sp(h, acc))

def chk_find(m: Maybe<&2, List<&2, Maybe<&2, R.Span>>>) -> U32:
  match m:
    case None{}:
      0
    case Some{xs}:
      chk_spans(xs, 0)

def text(+size: Nat) -> String:
  +e = (size - 50n : Nat)
  +h = (size - 20n : Nat)
  String.repeat("x", e) ++ "user@host.com" ++ String.repeat("x", (h - e - 13n : Nat)) ++ "helloworld12" ++ String.repeat("x", (size - h - 12n : Nat))

def lap(+name: String, t0: Nat, +chk: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("chk\t" ++ name ++ "\t" ++ U32.show(chk))
    t1 : Nat <- IO.now()
    IO.print("ms\t" ++ name ++ "\t" ++ Nat.show((t1 - t0 : Nat)))

def with_re(m: Maybe<&2, R.Regex>, +s: String, +name: String) -> IO(Unit):
  match m:
    case None{}:
      IO.print("error")
    case Some{re}:
      do IO<Unit>:
        t0 : Nat <- IO.now()
        lap(name, t0, chk_find(R.find(re, s)))

def op.is_match(+s: String) -> IO(Unit):
  with_re(R.compile("hello\\w+"), s, "is_match")

def op.find_captures(+s: String) -> IO(Unit):
  with_re(R.compile("(\\w+)@(\\w+)\\.com"), s, "find_captures")

def op.redos() -> IO(Unit):
  do IO<Unit>:
    with_re(R.compile("(a*)*b"), String.repeat("a", 100000n), "redos")

def run_text(+s: String) -> IO(Unit):
  do IO<Unit>:
    op.is_match(s)
    op.find_captures(s)
    op.redos()

def run(+size: Nat) -> IO(Unit):
  run_text(text(size))

def main() -> IO(Unit):
  run(1048576n)
