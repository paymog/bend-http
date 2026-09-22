import Base

# origin-form /path[?k=v] with RFC 3986 percent-encoding.

type Url is Data:
  Url{path: String, query: Map<&2, String>}

def unreserved(+c: U32) -> Bool:
  Bool.or(Bool.and(U32.is_le(65, c), U32.is_le(c, 90)), Bool.or(Bool.and(U32.is_le(97, c), U32.is_le(c, 122)), Bool.or(Bool.and(U32.is_le(48, c), U32.is_le(c, 57)), Bool.or(U32.is_eq(c, 45), Bool.or(U32.is_eq(c, 46), Bool.or(U32.is_eq(c, 95), U32.is_eq(c, 126)))))))

def path_ok(+c: U32) -> Bool:
  Bool.or(unreserved(c), U32.is_eq(c, 47))

def hexn(+n: U32) -> U32:
  Bool.pick(U32, U32.is_le(n, 9), (48 + n : U32), (55 + n : U32))

@unsafe
def hexhi.go(+n: U32, +acc: U32, small: Bool) -> U32:
  match small:
    case True{}:
      acc
    case False{}:
      hexhi.go((n - 16 : U32), (acc + 1 : U32), U32.is_le((n - 16 : U32), 15))

def hexhi(+n: U32) -> U32:
  hexhi.go(n, 0, U32.is_le(n, 15))

def hexlo(+n: U32) -> U32:
  (n - (hexhi(n) * 16 : U32) : U32)

def pct.enc.push(+c: U32, acc: String, keep: Bool) -> String:
  match keep:
    case True{}:
      SCon{Chr{c}, acc}
    case False{}:
      SCon{Chr{hexn(hexlo(c))}, SCon{Chr{hexn(hexhi(c))}, SCon{Chr{37}, acc}}}

def pct.enc.path(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+c}, t}:
      pct.enc.path(t, pct.enc.push(c, acc, path_ok(c)))

def pct.enc.query(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+c}, t}:
      pct.enc.query(t, pct.enc.push(c, acc, unreserved(c)))

def pct.encode_path(s: String) -> String:
  pct.enc.path(s, SNil{})

def pct.encode_q(s: String) -> String:
  pct.enc.query(s, SNil{})

def unhex.H(c: U32, hex: Bool) -> Maybe<&2, U32>:
  match hex:
    case True{}:
      Some{(c - 55 : U32)}
    case False{}:
      None{}

def unhex.h(+c: U32, lo: Bool) -> Maybe<&2, U32>:
  match lo:
    case True{}:
      Some{(c - 87 : U32)}
    case False{}:
      unhex.H(c, Bool.and(U32.is_le(65, c), U32.is_le(c, 70)))

def unhex.d(+c: U32, dec: Bool, lo: Bool) -> Maybe<&2, U32>:
  match dec:
    case True{}:
      Some{(c - 48 : U32)}
    case False{}:
      unhex.h(c, lo)

def unhex(+c: U32) -> Maybe<&2, U32>:
  unhex.d(c, Bool.and(U32.is_le(48, c), U32.is_le(c, 57)), Bool.and(U32.is_le(97, c), U32.is_le(c, 102)))

def pct.cons(byte: U32, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match rest:
    case None{}:
      None{}
    case Some{s}:
      Some{SCon{Chr{byte}, s}}

def pct.join2(x: U32, b: Maybe<&2, U32>, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match b:
    case None{}:
      None{}
    case Some{y}:
      pct.cons((x * 16 + y : U32), rest)

def pct.join(a: Maybe<&2, U32>, b: Maybe<&2, U32>, rest: Maybe<&2, String>) -> Maybe<&2, String>:
  match a:
    case None{}:
      None{}
    case Some{x}:
      pct.join2(x, b, rest)

def pct.decode.last(+c: U32, pct: Bool) -> Maybe<&2, String>:
  match pct:
    case True{}:
      None{}
    case False{}:
      Some{SCon{Chr{c}, SNil{}}}

@unsafe
def pct.decode.go(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}:
      Some{SNil{}}
    case SCon{Chr{+c}, t}:
      match t:
        case SNil{}:
          pct.decode.last(c, U32.is_eq(c, 37))
        case SCon{Chr{+a}, u}:
          match u:
            case SNil{}:
              Bool.pick(Maybe<&2, String>, U32.is_eq(c, 37), None{}, pct.cons(c, pct.decode.go(SCon{Chr{a}, SNil{}})))
            case SCon{Chr{+b}, +r}:
              Bool.pick(Maybe<&2, String>, U32.is_eq(c, 37), pct.join(unhex(a), unhex(b), pct.decode.go(r)), pct.cons(c, pct.decode.go(SCon{Chr{a}, SCon{Chr{b}, r}})))

def pct.decode(s: String) -> Maybe<&2, String>:
  pct.decode.go(s)
def take_q.go(s: String, +acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), SNil{})
    case SCon{Chr{+c}, +t}:
      Bool.pick(String & String, U32.is_eq(c, 63), (String.reverse(acc), t), take_q.go(t, SCon{Chr{c}, acc}))

def take_eq.go(s: String, +acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), SNil{})
    case SCon{Chr{+c}, +t}:
      Bool.pick(String & String, U32.is_eq(c, 61), (String.reverse(acc), t), take_eq.go(t, SCon{Chr{c}, acc}))

def pair(kv: String) -> String & String:
  take_eq.go(kv, SNil{})

def qput.decv(m: Map<&2, String>, key: String, v: Maybe<&2, String>) -> Map<&2, String>:
  match v:
    case None{}:
      m
    case Some{val}:
      Map.set(&2, String, m, key, val)

def qput.dec(m: Map<&2, String>, k: Maybe<&2, String>, v: Maybe<&2, String>) -> Map<&2, String>:
  match k:
    case None{}:
      m
    case Some{key}:
      qput.decv(m, key, v)

def qput.kv(m: Map<&2, String>, kv: String & String) -> Map<&2, String>:
  (k, v) = kv
  qput.dec(m, pct.decode(k), pct.decode(v))

def qput(m: Map<&2, String>, kv: String) -> Map<&2, String>:
  qput.kv(m, pair(kv))

def qfold(xs: List<&2, String>, m: Map<&2, String>) -> Map<&2, String>:
  match xs:
    case Nil{}:
      m
    case Con{h, t}:
      qfold(t, qput(m, h))

def parse.q(path: String, rest: String, hasq: Bool) -> Maybe<&2, Url>:
  match hasq:
    case False{}:
      Some{Url{path, Map.new(&2, String)}}
    case True{}:
      Some{Url{path, qfold(String.split(rest, '&'), Map.new(&2, String))}}

def parse.path(path: Maybe<&2, String>, +rest: String) -> Maybe<&2, Url>:
  match path:
    case None{}:
      None{}
    case Some{p}:
      parse.q(p, rest, Bool.not(String.is_empty(rest)))

def parse.split(pr: String & String) -> Maybe<&2, Url>:
  (path, +rest) = pr
  parse.path(pct.decode(path), rest)

def parse.ok(+s: String, ok: Bool) -> Maybe<&2, Url>:
  match ok:
    case False{}:
      None{}
    case True{}:
      parse.split(take_q.go(s, SNil{}))

def parse(+s: String) -> Maybe<&2, Url>:
  parse.ok(s, String.starts_with(s, "/"))

def enc.pairs.go(xs: List<&2, Sigma<&2, &2, String, _ => String>>, acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case (k, v) <> t:
      enc.pairs.go(t, acc ++ ("&" ++ pct.encode_q(k) ++ "=" ++ pct.encode_q(v)))

def enc.pairs(m: Map<&2, String>) -> String:
  enc.pairs.go(Map.to_list(&2, String, m), "")

def encode.q(path: String, q: String, empty: Bool) -> String:
  match empty:
    case True{}:
      path
    case False{}:
      path ++ "?" ++ String.drop(q, 1n)

def encode.go(path: String, +q: String) -> String:
  encode.q(path, q, String.is_empty(q))

def encode(u: Url) -> String:
  Url{path, query} = u
  encode.go(pct.encode_path(path), enc.pairs(query))
