import Base

# Hex of each char as two nibbles. ASCII-oriented.

def nibble(+n: U32) -> U32:
  Bool.pick(U32, U32.is_le(n, 9), (48 + n : U32), (87 + n : U32))

@unsafe
def hi.go(+n: U32, +acc: U32, small: Bool) -> U32:
  match small:
    case True{}:
      acc
    case False{}:
      hi.go((n - 16 : U32), (acc + 1 : U32), U32.is_le((n - 16 : U32), 15))

def hi(+n: U32) -> U32:
  hi.go(n, 0, U32.is_le(n, 15))

def lo(+n: U32) -> U32:
  (n - (hi(n) * 16 : U32) : U32)

def encode.go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+c}, t}:
      encode.go(t, SCon{Chr{nibble(lo(c))}, SCon{Chr{nibble(hi(c))}, acc}})

def encode(s: String) -> String:
  encode.go(s, SNil{})

def unhex.h(c: U32, hex: Bool) -> Maybe<&2, U32>:
  match hex:
    case True{}:
      Some{(c - 87 : U32)}
    case False{}:
      None{}

def unhex.d(+c: U32, dec: Bool, hex: Bool) -> Maybe<&2, U32>:
  match dec:
    case True{}:
      Some{(c - 48 : U32)}
    case False{}:
      unhex.h(c, hex)

def unhex(+c: U32) -> Maybe<&2, U32>:
  unhex.d(c, Bool.and(U32.is_le(48, c), U32.is_le(c, 57)), Bool.and(U32.is_le(97, c), U32.is_le(c, 102)))

def decode.cons(byte: U32, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match rest:
    case None{}:
      None{}
    case Some{s}:
      Some{SCon{Chr{byte}, s}}

def decode.join2(x: U32, b: Maybe<&2, U32>, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match b:
    case None{}:
      None{}
    case Some{y}:
      decode.cons((x * 16 + y : U32), rest)

def decode.join(a: Maybe<&2, U32>, b: Maybe<&2, U32>, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match a:
    case None{}:
      None{}
    case Some{x}:
      decode.join2(x, b, rest)

@unsafe
def decode.go(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}:
      Some{SNil{}}
    case SCon{Chr{+c}, t}:
      match t:
        case SNil{}:
          None{}
        case SCon{Chr{+d}, r}:
          decode.join(unhex(c), unhex(d), decode.go(r))

def decode(s: String) -> Maybe<&2, String>:
  decode.go(s)
