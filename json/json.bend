import Base

# JSON leaves + empty []/{}. Nested arrays/objects need forward refs.

type Val is Data:
  Null{}
  Flag{on: Bool}
  Num{n: U32}
  Str{s: String}
  Arr{xs: List<&2, Val>}
  Obj{m: Map<&2, Val>}

type Next is Data:
  Next{v: Val, rest: String}

type Cut is Data:
  Cut{s: String, rest: String}

def is_ws(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 32), Bool.or(U32.is_eq(c, 9), Bool.or(U32.is_eq(c, 10), U32.is_eq(c, 13))))

def skip_ws(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, +t}:
      Bool.pick(String, is_ws(c), skip_ws(t), SCon{Chr{c}, t})

def digit(+c: U32) -> Bool:
  Bool.and(U32.is_le(48, c), U32.is_le(c, 57))

def parse.null.if(+s: String, ok: Bool) -> Maybe<&2, Next>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Next{Null{}, String.drop(s, 4n)}}

def parse.null(+s: String) -> Maybe<&2, Next>:
  parse.null.if(s, String.starts_with(s, "null"))

def parse.true.if(+s: String, ok: Bool) -> Maybe<&2, Next>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Next{Flag{True{}}, String.drop(s, 4n)}}

def parse.true(+s: String) -> Maybe<&2, Next>:
  parse.true.if(s, String.starts_with(s, "true"))

def parse.false.if(+s: String, ok: Bool) -> Maybe<&2, Next>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Next{Flag{False{}}, String.drop(s, 5n)}}

def parse.false(+s: String) -> Maybe<&2, Next>:
  parse.false.if(s, String.starts_with(s, "false"))

def parse.num.go(s: String, +acc: U32) -> Next:
  match s:
    case SNil{}:
      Next{Num{acc}, SNil{}}
    case SCon{Chr{+c}, +t}:
      Bool.pick(Next, digit(c), parse.num.go(t, (acc * 10 + (c - 48 : U32) : U32)), Next{Num{acc}, SCon{Chr{c}, t}})

def parse.num.start(c: U32, t: String, ok: Bool) -> Maybe<&2, Next>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{parse.num.go(t, (c - 48 : U32))}

def parse.num(s: String) -> Maybe<&2, Next>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, t}:
      parse.num.start(c, t, digit(c))

def parse.str.put(ch: Char, got: Maybe<&2, Cut>) -> Maybe<&2, Cut>:
  match got:
    case None{}:
      None{}
    case Some{Cut{tail, rest}}:
      Some{Cut{SCon{ch, tail}, rest}}

@unsafe
def parse.str.go(s: String) -> Maybe<&2, Cut>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, +t}:
      Bool.pick(Maybe<&2, Cut>, U32.is_eq(c, 34), Some{Cut{SNil{}, t}}, parse.str.put(Chr{c}, parse.str.go(t)))

def parse.str.val(got: Maybe<&2, Cut>) -> Maybe<&2, Next>:
  match got:
    case None{}:
      None{}
    case Some{Cut{s, rest}}:
      Some{Next{Str{s}, rest}}

def parse.str.q(t: String, quot: Bool) -> Maybe<&2, Next>:
  match quot:
    case False{}:
      None{}
    case True{}:
      parse.str.val(parse.str.go(t))

def parse.str(s: String) -> Maybe<&2, Next>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{c}, t}:
      parse.str.q(t, U32.is_eq(c, 34))

def parse.empty.arr(r: String, ok: Bool) -> Maybe<&2, Next>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Next{Arr{Nil{}}, r}}

def parse.empty.obj(r: String, ok: Bool) -> Maybe<&2, Next>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Next{Obj{Map.new(&2, Val)}, r}}

def parse.coll2(r: String, arr: Bool, close_a: Bool, close_o: Bool) -> Maybe<&2, Next>:
  match arr:
    case True{}:
      parse.empty.arr(r, close_a)
    case False{}:
      parse.empty.obj(r, close_o)

def parse.coll1(t: String, arr: Bool) -> Maybe<&2, Next>:
  match t:
    case SNil{}:
      None{}
    case SCon{Chr{+d}, r}:
      parse.coll2(r, arr, U32.is_eq(d, 93), U32.is_eq(d, 125))

def parse.leaf9(s: String, d: Bool) -> Maybe<&2, Next>:
  match d:
    case True{}:
      parse.num(s)
    case False{}:
      None{}

def parse.leaf8(s: String, q: Bool, d: Bool) -> Maybe<&2, Next>:
  match q:
    case True{}:
      parse.str(s)
    case False{}:
      parse.leaf9(s, d)

def parse.leaf7(s: String, f: Bool, q: Bool, d: Bool) -> Maybe<&2, Next>:
  match f:
    case True{}:
      parse.false(s)
    case False{}:
      parse.leaf8(s, q, d)

def parse.leaf6(s: String, tr: Bool, f: Bool, q: Bool, d: Bool) -> Maybe<&2, Next>:
  match tr:
    case True{}:
      parse.true(s)
    case False{}:
      parse.leaf7(s, f, q, d)

def parse.leaf5(s: String, n: Bool, tr: Bool, f: Bool, q: Bool, d: Bool) -> Maybe<&2, Next>:
  match n:
    case True{}:
      parse.null(s)
    case False{}:
      parse.leaf6(s, tr, f, q, d)

def parse.leaf4o(+s: String, +c: U32, t: String, obj: Bool) -> Maybe<&2, Next>:
  match obj:
    case True{}:
      parse.coll1(skip_ws(t), False{})
    case False{}:
      parse.leaf5(s, U32.is_eq(c, 110), U32.is_eq(c, 116), U32.is_eq(c, 102), U32.is_eq(c, 34), digit(c))

def parse.leaf4(+s: String, +c: U32, t: String, arr: Bool, obj: Bool) -> Maybe<&2, Next>:
  match arr:
    case True{}:
      parse.coll1(skip_ws(t), True{})
    case False{}:
      parse.leaf4o(s, c, t, obj)

def parse.leaf(+s: String) -> Maybe<&2, Next>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, t}:
      parse.leaf4(s, c, t, U32.is_eq(c, 91), U32.is_eq(c, 123))

def parse.trail(v: Val, rest: String) -> Maybe<&2, Val>:
  match rest:
    case SNil{}:
      Some{v}
    case SCon{h, t}:
      None{}

def parse.done(got: Maybe<&2, Next>) -> Maybe<&2, Val>:
  match got:
    case None{}:
      None{}
    case Some{Next{v, rest}}:
      parse.trail(v, skip_ws(rest))

def parse(s: String) -> Maybe<&2, Val>:
  parse.done(parse.leaf(skip_ws(s)))

def get.hit(r: Map<&2, Val> & Bool) -> Bool:
  (m, b) = r
  b

def get.some(r: Map<&2, Val> & Val) -> Maybe<&2, Val>:
  (m, x) = r
  Some{x}

def get.has(+m: Map<&2, Val>, +k: String, hit: Bool) -> Maybe<&2, Val>:
  match hit:
    case False{}:
      None{}
    case True{}:
      get.some(Map.get(Val, Null{}, m, k))

def get.of(+m: Map<&2, Val>, +k: String) -> Maybe<&2, Val>:
  get.has(m, k, get.hit(Map.has(&2, Val, m, k)))

def get(v: Val, k: String) -> Maybe<&2, Val>:
  match v:
    case Obj{m}:
      get.of(m, k)
    case Null{}:
      None{}
    case Flag{on}:
      None{}
    case Num{n}:
      None{}
    case Str{s}:
      None{}
    case Arr{xs}:
      None{}

def esc.go(s: String, +acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+c}, +t}:
      Bool.pick(String, U32.is_eq(c, 34), esc.go(t, SCon{Chr{34}, SCon{Chr{92}, acc}}), Bool.pick(String, U32.is_eq(c, 92), esc.go(t, SCon{Chr{92}, SCon{Chr{92}, acc}}), esc.go(t, SCon{Chr{c}, acc})))

def esc(s: String) -> String:
  esc.go(s, SNil{})

def encode(v: Val) -> String:
  match v:
    case Null{}:
      "null"
    case Flag{True{}}:
      "true"
    case Flag{False{}}:
      "false"
    case Num{n}:
      U32.show(n)
    case Str{s}:
      "\"" ++ esc(s) ++ "\""
    case Arr{xs}:
      "[]"
    case Obj{m}:
      "{}"
