import Base

# origin-form: /path[?k=v&k=v]. No percent-encoding.

type Url is Data:
  Url{path: String, query: Map<&2, String>}

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

def qput.kv(m: Map<&2, String>, kv: String & String) -> Map<&2, String>:
  (k, v) = kv
  Map.set(&2, String, m, k, v)

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

def parse.split(pr: String & String) -> Maybe<&2, Url>:
  (path, +rest) = pr
  parse.q(path, rest, Bool.not(String.is_empty(rest)))

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
      enc.pairs.go(t, acc ++ ("&" ++ k ++ "=" ++ v))

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
  encode.go(path, enc.pairs(query))
