import Base
import ./LAWS.bend as Laws
import ./omap.bend as O

def Laws.omap_keys_ascending_puts():
  {==}

def Laws.omap_size_del():
  {==}

def Laws.omap_get_after_rotations():
  {==}

def Laws.omap_keys_del_root():
  {==}

def Laws.omap_get_put():
  {==}

def Laws.omap_get_put_replace():
  {==}

def Laws.omap_get_put_other():
  {==}

def Laws.omap_get_missing():
  {==}

def Laws.omap_keys_sorted():
  {==}

def Laws.omap_size_replace():
  {==}

def Laws.omap_get_del():
  {==}

def Laws.omap_get_del_other():
  {==}

def Laws.omap_keys_del():
  {==}

def Laws.omap_string_keys():
  {==}

def Laws.oset_to_list():
  {==}

def Laws.oset_has_del():
  {==}

def Laws.vec_from_list():
  {==}

def Laws.vec_get():
  {==}

def Laws.vec_get_past_len():
  {==}

def Laws.vec_set():
  {==}

def Laws.vec_pop():
  {==}

def Laws.vec_pop_empty():
  {==}

def Laws.vec_pop_to_list():
  {==}

def Laws.deque_ends():
  {==}

def Laws.heap_sort():
  {==}

def isT(b: Bool) -> Type:
  match b:
    case True{}:
      Unit
    case False{}:
      Empty

def absurd_b(e: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, e) : isT(_)
  Unit{}

def exfalso(-A: Type, e: Empty) -> A:
  match e:

def and_l(a: Bool, b: Bool, e: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      exfalso({False{} == True{} : Bool}, absurd_b(e))

def and_r(a: Bool, b: Bool, e: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}:
      e
    case False{}:
      exfalso({b == True{} : Bool}, absurd_b(e))

def and_i(
  a: Bool, b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}
) -> {Bool.and(a, b) == True{} : Bool}:
  match a:
    case True{}:
      eb
    case False{}:
      exfalso({Bool.and(False{}, b) == True{} : Bool}, absurd_b(ea))

def c4.a(
  +a: Bool, +b: Bool, +c: Bool, +d: Bool,
  e: {Bool.and(Bool.and(Bool.and(a, b), c), d) == True{} : Bool}
) -> {a == True{} : Bool}:
  and_l(a, b, and_l(Bool.and(a, b), c, and_l(Bool.and(Bool.and(a, b), c), d, e)))

def c4.b(
  +a: Bool, +b: Bool, +c: Bool, +d: Bool,
  e: {Bool.and(Bool.and(Bool.and(a, b), c), d) == True{} : Bool}
) -> {b == True{} : Bool}:
  and_r(a, b, and_l(Bool.and(a, b), c, and_l(Bool.and(Bool.and(a, b), c), d, e)))

def c4.c(
  +a: Bool, +b: Bool, +c: Bool, +d: Bool,
  e: {Bool.and(Bool.and(Bool.and(a, b), c), d) == True{} : Bool}
) -> {c == True{} : Bool}:
  and_r(Bool.and(a, b), c, and_l(Bool.and(Bool.and(a, b), c), d, e))

def c4.d(
  +a: Bool, +b: Bool, +c: Bool, +d: Bool,
  e: {Bool.and(Bool.and(Bool.and(a, b), c), d) == True{} : Bool}
) -> {d == True{} : Bool}:
  and_r(Bool.and(Bool.and(a, b), c), d, e)

def c4.i(
  +a: Bool, +b: Bool, +c: Bool, +d: Bool, ea: {a == True{} : Bool},
  eb: {b == True{} : Bool}, ec: {c == True{} : Bool}, ed: {d == True{} : Bool}
) -> {Bool.and(Bool.and(Bool.and(a, b), c), d) == True{} : Bool}:
  and_i(Bool.and(Bool.and(a, b), c), d,
    and_i(Bool.and(a, b), c, and_i(a, b, ea, eb), ec), ed)

def Laws.omap_new_searchtree(K, V, cmp):
  {==}

def head(-K: Data, xs: List<&2, K>) -> Maybe<&2, K>:
  match xs:
    case Nil{}:
      None{}
    case Con{h, t}:
      Some{h}

# The list is sorted and its first element lies above lb.
def sfrom(~K: Data, ~cmp: K -> K -> Cmp, lb: Maybe<&2, K>, xs: List<&2, K>) -> Bool:
  match lb:
    case None{}:
      Laws.sorted(~K, ~cmp, xs)
    case Some{b}:
      Laws.sorted.go(~K, ~cmp, xs, b)

# lb lies below ub, when both exist.
def lt_m(~K: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, ub: Maybe<&2, K>) -> Bool:
  match ub:
    case None{}:
      True{}
    case Some{u}:
      Laws.above(~K, ~cmp, lb, u)

def lt_m.some(
  ~K: Data, ~cmp: K -> K -> Cmp, ub: Maybe<&2, K>, +k: K,
  e: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool}
) -> {lt_m(~K, ~cmp, Some{k}, ub) == True{} : Bool}:
  match ub:
    case None{}:
      {==}
    case Some{u}:
      e

def sfrom.base(
  ~K: Data, ~cmp: K -> K -> Cmp, lb: Maybe<&2, K>, acc: List<&2, K>,
  lt: {lt_m(~K, ~cmp, lb, head(K, acc)) == True{} : Bool},
  sa: {Laws.sorted(~K, ~cmp, acc) == True{} : Bool}
) -> {sfrom(~K, ~cmp, lb, acc) == True{} : Bool}:
  match lb acc:
    case None{} _:
      sa
    case Some{b} Nil{}:
      {==}
    case Some{+b} Con{+h, t}:
      and_i(Cmp.is_lt(cmp(b, h)), Laws.sorted.go(~K, ~cmp, t, h), lt, sa)

def keys_sorted.go(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, t: O.OMap<K, V>, +lb: Maybe<&2, K>,
  +acc: List<&2, K>,
  +bt: {Laws.bounded(~K, ~V, ~cmp, t, lb, head(K, acc)) == True{} : Bool},
  lt: {lt_m(~K, ~cmp, lb, head(K, acc)) == True{} : Bool},
  sa: {Laws.sorted(~K, ~cmp, acc) == True{} : Bool}
) -> {sfrom(~K, ~cmp, lb, O.OMap.keys.go(K, V, t, acc)) == True{} : Bool}:
  match t:
    case O.OTip{}:
      sfrom.base(~K, ~cmp, lb, acc, lt, sa)
    case O.OBin{s, +k, v, +lo, +hi}:
      +A = Laws.above(~K, ~cmp, lb, k)
      +B = Laws.below(~K, ~cmp, head(K, acc), k)
      +L = Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k})
      +H = Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, head(K, acc))
      ih = keys_sorted.go(~K, ~V, ~cmp, hi, Some{k}, acc, c4.d(A, B, L, H, bt),
        lt_m.some(~K, ~cmp, head(K, acc), k, c4.b(A, B, L, H, bt)), sa)
      keys_sorted.go(~K, ~V, ~cmp, lo, lb, k <> O.OMap.keys.go(K, V, hi, acc),
        c4.c(A, B, L, H, bt), c4.a(A, B, L, H, bt), ih)

def Laws.omap_searchtree_keys_sorted(K, V, cmp, m, tree):
  keys_sorted.go(~K, ~V, ~cmp, m, None{}, Nil{}, tree, {==}, {==})
