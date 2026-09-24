import Base
import ./bytes.bend as Bytes

# The laws run in the checker, where Array is a tree of defs. This runs the same
# operations on the runtime's native Array, at sizes the checker would not reach.
# Strings stay at 10 KB: `bend check.bend` overflowed on this file at 20 KB, though a native build passes.

def bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, bytes(t)}

def of(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def str(b: Bytes.Bytes) -> String:
  Bytes.to_string(b)

def val(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, U32>:
  (b, x) = r
  x

def num(r: Bytes.Bytes & U32) -> U32:
  (b, n) = r
  n

def left(r: Bytes.Bytes & Bytes.Bytes) -> String:
  (a, b) = r
  str(a)

def right(r: Bytes.Bytes & Bytes.Bytes) -> String:
  (a, b) = r
  str(b)

def rightb(r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes:
  (a, b) = r
  b

def same(r: Bytes.Bytes & Bytes.Bytes & Bool) -> Bool:
  (a, b, ok) = r
  ok

def expect(+name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def has(m: Maybe<&2, U32>, +v: U32) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{x}:
      U32.is_eq(x, v)

def none(m: Maybe<&2, U32>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{x}:
      False{}

def rep(n: Nat, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      rep(p, SCon{'a', acc})

def big() -> String:
  rep(10000n, "\r\n\r\n")

def main() -> IO(Unit):
  do IO<Unit>:
    expect("roundtrip", String.eq(str(of("hello, world")), "hello, world"))
    expect("roundtrip octets", String.eq(str(of(bytes([0, 128, 255, 13, 10]))), bytes([0, 128, 255, 13, 10])))
    expect("roundtrip 10 KB", String.eq(str(of(big())), big()))
    expect("get past len", none(val(Bytes.get(of("hi"), 2))))
    expect("set", String.eq(str(Bytes.set(of("hello"), 4, 33)), "hell!"))
    expect("set 1 MB", has(val(Bytes.get(Bytes.set(Bytes.new(1000003), 1000002, 7), 1000002)), 7))
    expect("get 1 MB past len", none(val(Bytes.get(Bytes.new(1000003), 1000003))))
    expect("length 1 MB", U32.is_eq(num(Bytes.length(Bytes.new(1000003))), 1000003))
    expect("find header end", has(val(Bytes.find(of("GET / HTTP/1.1\r\n\r\nbody"), "\r\n\r\n")), 14))
    expect("find 10 KB", has(val(Bytes.find(of(big()), "\r\n\r\n")), 10000))
    expect("find missing", none(val(Bytes.find(of(big()), "b"))))
    expect("slice 10 KB", String.eq(right(Bytes.slice(of(big()), 9998, 10)), "aa\r\n\r\n"))
    expect("append", String.eq(str(Bytes.append(of("ab"), of("cde"))), "abcde"))
    expect("append 10 KB", has(val(Bytes.find(Bytes.append(of(big()), of("xyz")), "xyz")), 10004))
    expect("eq 10 KB", same(Bytes.eq(of(big()), of(big()))))
    expect("eq 10 KB differs", Bool.not(same(Bytes.eq(Bytes.set(of(big()), 5, 98), of(big())))))
    expect("eq after set", same(Bytes.eq(Bytes.set(of("abc"), 1, 98), of("abc"))))
    expect("slice 10 KB offset 1", String.eq(right(Bytes.slice(of(big()), 1, 10003)), String.drop(big(), 1n)))
    expect("slice 10 KB offset 3 eq", same(Bytes.eq(rightb(Bytes.slice(of(big()), 3, 10001)), of(String.drop(big(), 3n)))))
    expect("append 10 KB aligned", String.eq(str(Bytes.append(of(big()), of("wxyz"))), big() ++ "wxyz"))
