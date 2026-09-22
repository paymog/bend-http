import Base
import ./http.bend as Http
import ./LAWS.bend as Laws

def Laws.body_after_blank(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def suffix_step(
  a: U32, -t: String, -e: Bool, -w: U32, -acc: String,
  ih: (&p: String -> {p ++ Http.body.of(Http.split_at_blank.go(t, e, w, acc)) == t : String})
) -> (&p: String -> {p ++ Http.body.of(Http.split_at_blank.go(t, e, w, acc)) == SCon{Chr{a}, t} : String}):
  (p, pf) = ih
  (SCon{Chr{a}, p}, Equal.cong(String, String, x => SCon{Chr{a}, x}, p ++ Http.body.of(Http.split_at_blank.go(t, e, w, acc)), t, pf))

def suffix_go(s: String, e: Bool, w: U32, acc: String) ->
  (&p: String -> {p ++ Http.body.of(Http.split_at_blank.go(s, e, w, acc)) == s : String}):
  match s:
    case SNil{}:
      ("", {==})
    case SCon{Chr{+a}, +t}:
      match e:
        case True{}:
          ("", {==})
        case False{}:
          +w2 = (w * 256 + a : U32)
          suffix_step(a, t, U32.is_eq(w2, 218762506), w2, SCon{Chr{a}, acc}, suffix_go(t, U32.is_eq(w2, 218762506), w2, SCon{Chr{a}, acc}))

def Laws.body_suffix(s):
  suffix_go(s, False{}, 0, SNil{})

def Laws.page_after_blank(status, page):
  ("HTTP/1.1 " ++ U32.show(status) ++ " OK\r\nContent-Type: text/plain\r\nConnection: close", {==})

def drop(n: Nat, s: String) -> String:
  match n:
    case 0n:
      s
    case 1n+p:
      match s:
        case SNil{}:
          SNil{}
        case SCon{h, t}:
          drop(p, t)

def Laws.response_inj(a, b, e):
  Equal.cong(String, String, s => drop(64n, s), Http.response(200, a), Http.response(200, b), e)
