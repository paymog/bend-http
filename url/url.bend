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
def take_to.go(s: String, +stop: U32, +acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), SNil{})
    case SCon{Chr{+c}, +t}:
      Bool.pick(String & String, U32.is_eq(c, stop), (String.reverse(acc), t), take_to.go(t, stop, SCon{Chr{c}, acc}))

# (text before the first stop char, text after it)
def take_to(s: String, stop: U32) -> String & String:
  take_to.go(s, stop, SNil{})

def pair(kv: String) -> String & String:
  take_to(kv, 61)

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
      parse.split(take_to(s, 63))

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

# Absolute http(s) URLs (RFC 3986 §3) for clients.
# ---------------------------------------------

# target is the RFC 9112 §3.2.1 origin-form: path (never empty) and query, no fragment.
type Abs is Data:
  Abs{scheme: String, host: String, port: U32, target: String}

def has(s: String, +c: U32) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{d}, t}:
      Bool.or(U32.is_eq(d, c), has(t, c))

def auth_end(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 47), Bool.or(U32.is_eq(c, 63), U32.is_eq(c, 35)))

# §3.2: the authority runs to the first "/", "?" or "#".
def take_auth.go(s: String, +acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), SNil{})
    case SCon{Chr{+c}, +t}:
      Bool.pick(String & String, auth_end(c), (String.reverse(acc), SCon{Chr{c}, t}), take_auth.go(t, SCon{Chr{c}, acc}))

def default_port(+scheme: String) -> Maybe<&2, U32>:
  Bool.pick(Maybe<&2, U32>, String.eq(scheme, "http"), Some{80}, Bool.pick(Maybe<&2, U32>, String.eq(scheme, "https"), Some{443}, None{}))

def abs.target(+pq: String) -> String:
  Bool.pick(String, String.starts_with(pq, "/"), pq, "/" ++ pq)

def abs.fst(ab: String & String) -> String:
  (a, b) = ab
  a

# §3.5: the fragment is for the client; it never goes on the wire.
def abs.build(scheme: String, host: String, port: Maybe<&2, U32>, rest: String) -> Maybe<&2, Abs>:
  match port:
    case None{}:
      None{}
    case Some{p}:
      Some{Abs{scheme, host, p, abs.target(abs.fst(take_to(rest, 35)))}}

def abs.port.num(n: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match n:
    case None{}:
      None{}
    case Some{+p}:
      Bool.pick(Maybe<&2, U32>, U32.is_le(p, 65535), Some{p}, None{})

# §3.2.3: an empty port means the scheme's default.
def abs.port(+ps: String, dflt: Maybe<&2, U32>) -> Maybe<&2, U32>:
  Bool.pick(Maybe<&2, U32>, String.is_empty(ps), dflt, abs.port.num(U32.read(ps)))

def abs.hostok(scheme: String, host: String, port: Maybe<&2, U32>, rest: String, ok: Bool) -> Maybe<&2, Abs>:
  match ok:
    case False{}:
      None{}
    case True{}:
      abs.build(scheme, host, port, rest)

# §3.2.2: hosts are case-insensitive. IPv6 literals are refused (IPv4-only runtime).
def abs.hostport(scheme: String, dflt: Maybe<&2, U32>, hp: String & String, rest: String) -> Maybe<&2, Abs>:
  (+host, ps) = hp
  abs.hostok(scheme, String.to_lower(host), abs.port(ps, dflt), rest, Bool.not(Bool.or(String.is_empty(host), String.starts_with(host, "["))))

# WHATWG fetch refuses URLs that carry credentials (user:pass@).
def abs.auth.if(+scheme: String, auth: String, rest: String, creds: Bool) -> Maybe<&2, Abs>:
  match creds:
    case True{}:
      None{}
    case False{}:
      abs.hostport(scheme, default_port(scheme), take_to(auth, 58), rest)

def abs.auth(scheme: String, ar: String & String) -> Maybe<&2, Abs>:
  (+auth, rest) = ar
  abs.auth.if(scheme, auth, rest, has(auth, 64))

def abs.slashes(scheme: String, +rest: String, ok: Bool) -> Maybe<&2, Abs>:
  match ok:
    case False{}:
      None{}
    case True{}:
      abs.auth(String.to_lower(scheme), take_auth.go(String.drop(rest, 2n), SNil{}))

def abs.scheme(sr: String & String) -> Maybe<&2, Abs>:
  (scheme, +rest) = sr
  abs.slashes(scheme, rest, String.starts_with(rest, "//"))

# scheme://host[:port][/path][?query][#fragment]
def absolute(s: String) -> Maybe<&2, Abs>:
  abs.scheme(take_to(s, 58))

def abs.port.dflt(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      0
    case Some{p}:
      p

# RFC 9110 §7.2: the Host field; the default port may be left out.
def host_field(a: Abs) -> String:
  Abs{+scheme, +host, +port, target} = a
  Bool.pick(String, U32.is_eq(port, abs.port.dflt(default_port(scheme))), host, host ++ ":" ++ U32.show(port))
