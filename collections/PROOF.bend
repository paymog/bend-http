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

def Trans(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> @z: K -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}

def Flip(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> {cmp(y, x) == Laws.flip(cmp(x, y)) : Cmp}

def Refl(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> {cmp(x, x) == EQ{} : Cmp}

def Eq(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}

def lt_of(c: Cmp, e: {Cmp.is_lt(c) == True{} : Bool}) -> {c == LT{} : Cmp}:
  match c:
    case LT{}:
      {==}
    case EQ{}:
      exfalso({EQ{} == LT{} : Cmp}, absurd_b(e))
    case GT{}:
      exfalso({GT{} == LT{} : Cmp}, absurd_b(e))

def lt_true(-c: Cmp, e: {c == LT{} : Cmp}) -> {Cmp.is_lt(c) == True{} : Bool}:
  Equal.cong(Cmp, Bool, x => Cmp.is_lt(x), c, LT{}, e)

def gt_flip(
  ~K: Data, ~cmp: K -> K -> Cmp, ~flip: Flip(~K, ~cmp), +x: K, +y: K,
  e: {cmp(x, y) == GT{} : Cmp}
) -> {cmp(y, x) == LT{} : Cmp}:
  Equal.trans(Cmp, cmp(y, x), Laws.flip(cmp(x, y)), LT{}, flip(x, y),
    Equal.cong(Cmp, Cmp, c => Laws.flip(c), cmp(x, y), GT{}, e))

def lt_trans(
  ~K: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp), +x: K, +y: K, +z: K,
  e1: {Cmp.is_lt(cmp(x, y)) == True{} : Bool},
  e2: {Cmp.is_lt(cmp(y, z)) == True{} : Bool}
) -> {Cmp.is_lt(cmp(x, z)) == True{} : Bool}:
  lt_true(cmp(x, z), trans(x, y, z, lt_of(cmp(x, y), e1), lt_of(cmp(y, z), e2)))

def above_trans(
  ~K: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp), lb: Maybe<&2, K>,
  +k: K, +hk: K, ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  e: {Cmp.is_lt(cmp(k, hk)) == True{} : Bool}
) -> {Laws.above(~K, ~cmp, lb, hk) == True{} : Bool}:
  match lb:
    case None{}:
      {==}
    case Some{+b}:
      lt_trans(~K, ~cmp, ~trans, b, k, hk, ea, e)

def below_trans(
  ~K: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp), ub: Maybe<&2, K>,
  +k: K, +hk: K, e: {Cmp.is_lt(cmp(k, hk)) == True{} : Bool},
  eb: {Laws.below(~K, ~cmp, ub, hk) == True{} : Bool}
) -> {Laws.below(~K, ~cmp, ub, k) == True{} : Bool}:
  match ub:
    case None{}:
      {==}
    case Some{+u}:
      lt_trans(~K, ~cmp, ~trans, k, hk, u, e, eb)

# Projections and introduction for bounded on one node.
def bn.a(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}
) -> {Laws.above(~K, ~cmp, lb, k) == True{} : Bool}:
  c4.a(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
    Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}),
    Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub), e)

def bn.b(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}
) -> {Laws.below(~K, ~cmp, ub, k) == True{} : Bool}:
  c4.b(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
    Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}),
    Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub), e)

def bn.l(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool}:
  c4.c(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
    Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}),
    Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub), e)

def bn.h(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}:
  c4.d(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
    Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}),
    Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub), e)

def bn.i(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}:
  c4.i(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
    Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}),
    Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub), ea, eb, el, eh)

def rot_lo.single.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V, +lo: O.OMap<K, V>,
  +hk: K, +hv: V, +hl: O.OMap<K, V>, +hh: O.OMap<K, V>,
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  +eh: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, hk, hv, hl, hh}, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.bin(K, V, hk, hv, O.OMap.bin(K, V, k, v, lo, hl), hh), lb, ub) == True{} : Bool}:
  +h_a = bn.a(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)
  bn.i(~K, ~V, ~cmp, lb, ub, hk, hv, O.OMap.bin(K, V, k, v, lo, hl), hh,
    above_trans(~K, ~cmp, ~trans, lb, k, hk, ea, h_a),
    bn.b(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh),
    bn.i(~K, ~V, ~cmp, lb, Some{hk}, k, v, lo, hl, ea, h_a, el,
      bn.l(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)),
    bn.h(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh))

def rot_lo.double.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  hl: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +lo: O.OMap<K, V>, +hk: K, +hv: V, +hh: O.OMap<K, V>,
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  +eh: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, hk, hv, hl, hh}, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.rot_lo.double(K, V, k, v, lo, hk, hv, hl, hh), lb, ub) == True{} : Bool}:
  match hl:
    case O.OTip{}:
      rot_lo.single.bnd(~K, ~V, ~cmp, ~trans, lb, ub, k, v, lo, hk, hv, O.OTip{}, hh,
        ea, el, eh)
    case O.OBin{s, +mk, +mv, +ml, +mh}:
      +hl = {O.OBin{0, mk, mv, ml, mh} : O.OMap<K, V>}
      +h_b = bn.b(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)
      +h_l = bn.l(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)
      +m_a = bn.a(~K, ~V, ~cmp, Some{k}, Some{hk}, mk, mv, ml, mh, h_l)
      +m_b = bn.b(~K, ~V, ~cmp, Some{k}, Some{hk}, mk, mv, ml, mh, h_l)
      bn.i(~K, ~V, ~cmp, lb, ub, mk, mv, O.OMap.bin(K, V, k, v, lo, ml),
        O.OMap.bin(K, V, hk, hv, mh, hh),
        above_trans(~K, ~cmp, ~trans, lb, k, mk, ea, m_a),
        below_trans(~K, ~cmp, ~trans, ub, mk, hk, m_b, h_b),
        bn.i(~K, ~V, ~cmp, lb, Some{mk}, k, v, lo, ml, ea, m_a, el,
          bn.l(~K, ~V, ~cmp, Some{k}, Some{hk}, mk, mv, ml, mh, h_l)),
        bn.i(~K, ~V, ~cmp, Some{mk}, ub, hk, hv, mh, hh, m_b, h_b,
          bn.h(~K, ~V, ~cmp, Some{k}, Some{hk}, mk, mv, ml, mh, h_l),
          bn.h(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)))

def rot_lo.pick.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  single: Bool, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +lo: O.OMap<K, V>, +hk: K, +hv: V, +hl: O.OMap<K, V>, +hh: O.OMap<K, V>,
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  +eh: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, hk, hv, hl, hh}, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.rot_lo.pick(K, V, single, k, v, lo, hk, hv, hl, hh), lb, ub) == True{} : Bool}:
  match single:
    case True{}:
      rot_lo.single.bnd(~K, ~V, ~cmp, ~trans, lb, ub, k, v, lo, hk, hv, hl, hh, ea, el, eh)
    case False{}:
      rot_lo.double.bnd(~K, ~V, ~cmp, ~trans, hl, lb, ub, k, v, lo, hk, hv, hh, ea, el, eh)

def rot_lo.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  hi: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +lo: O.OMap<K, V>,
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  +eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.rot_lo(K, V, k, v, lo, hi), lb, ub) == True{} : Bool}:
  match hi:
    case O.OTip{}:
      bn.i(~K, ~V, ~cmp, lb, ub, k, v, lo, O.OTip{}, ea, eb, el, eh)
    case O.OBin{s, +hk, +hv, +hl, +hh}:
      rot_lo.pick.bnd(~K, ~V, ~cmp, ~trans,
        U32.is_lt((O.OMap.size(K, V, hl) + 1 : U32),
          (2 * (O.OMap.size(K, V, hh) + 1) : U32)),
        lb, ub, k, v, lo, hk, hv, hl, hh, ea, el, eh)

def rot_hi.single.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V, +lk: K, +lv: V,
  +ll: O.OMap<K, V>, +lh: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  +el: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, lk, lv, ll, lh}, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.bin(K, V, lk, lv, ll, O.OMap.bin(K, V, k, v, lh, hi)), lb, ub) == True{} : Bool}:
  +l_b = bn.b(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el)
  bn.i(~K, ~V, ~cmp, lb, ub, lk, lv, ll, O.OMap.bin(K, V, k, v, lh, hi),
    bn.a(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el),
    below_trans(~K, ~cmp, ~trans, ub, lk, k, l_b, eb),
    bn.l(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el),
    bn.i(~K, ~V, ~cmp, Some{lk}, ub, k, v, lh, hi, l_b, eb,
      bn.h(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el), eh))

def rot_hi.double.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  lh: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +lk: K, +lv: V, +ll: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  +el: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, lk, lv, ll, lh}, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.rot_hi.double(K, V, k, v, lk, lv, ll, lh, hi), lb, ub) == True{} : Bool}:
  match lh:
    case O.OTip{}:
      rot_hi.single.bnd(~K, ~V, ~cmp, ~trans, lb, ub, k, v, lk, lv, ll, O.OTip{}, hi,
        eb, el, eh)
    case O.OBin{s, +mk, +mv, +ml, +mh}:
      +lh = {O.OBin{0, mk, mv, ml, mh} : O.OMap<K, V>}
      +l_a = bn.a(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el)
      +l_h = bn.h(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el)
      +m_a = bn.a(~K, ~V, ~cmp, Some{lk}, Some{k}, mk, mv, ml, mh, l_h)
      +m_b = bn.b(~K, ~V, ~cmp, Some{lk}, Some{k}, mk, mv, ml, mh, l_h)
      bn.i(~K, ~V, ~cmp, lb, ub, mk, mv, O.OMap.bin(K, V, lk, lv, ll, ml),
        O.OMap.bin(K, V, k, v, mh, hi),
        above_trans(~K, ~cmp, ~trans, lb, lk, mk, l_a, m_a),
        below_trans(~K, ~cmp, ~trans, ub, mk, k, m_b, eb),
        bn.i(~K, ~V, ~cmp, lb, Some{mk}, lk, lv, ll, ml, l_a, m_a,
          bn.l(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el),
          bn.l(~K, ~V, ~cmp, Some{lk}, Some{k}, mk, mv, ml, mh, l_h)),
        bn.i(~K, ~V, ~cmp, Some{mk}, ub, k, v, mh, hi, m_b, eb,
          bn.h(~K, ~V, ~cmp, Some{lk}, Some{k}, mk, mv, ml, mh, l_h), eh))

def rot_hi.pick.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  single: Bool, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +lk: K, +lv: V, +ll: O.OMap<K, V>, +lh: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  +el: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, lk, lv, ll, lh}, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.rot_hi.pick(K, V, single, k, v, lk, lv, ll, lh, hi), lb, ub) == True{} : Bool}:
  match single:
    case True{}:
      rot_hi.single.bnd(~K, ~V, ~cmp, ~trans, lb, ub, k, v, lk, lv, ll, lh, hi, eb, el, eh)
    case False{}:
      rot_hi.double.bnd(~K, ~V, ~cmp, ~trans, lh, lb, ub, k, v, lk, lv, ll, hi, eb, el, eh)

def rot_hi.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  lo: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +hi: O.OMap<K, V>,
  ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  +el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.rot_hi(K, V, k, v, lo, hi), lb, ub) == True{} : Bool}:
  match lo:
    case O.OTip{}:
      bn.i(~K, ~V, ~cmp, lb, ub, k, v, O.OTip{}, hi, ea, eb, el, eh)
    case O.OBin{s, +lk, +lv, +ll, +lh}:
      rot_hi.pick.bnd(~K, ~V, ~cmp, ~trans,
        U32.is_lt((O.OMap.size(K, V, lh) + 1 : U32),
          (2 * (O.OMap.size(K, V, ll) + 1) : U32)),
        lb, ub, k, v, lk, lv, ll, lh, hi, eb, el, eh)

def balance.if.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  heavy_hi: Bool, heavy_lo: Bool, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K,
  +v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  +el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  +eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.balance.if(K, V, heavy_hi, heavy_lo, k, v, lo, hi), lb, ub) == True{} : Bool}:
  match heavy_hi heavy_lo:
    case True{} _:
      rot_lo.bnd(~K, ~V, ~cmp, ~trans, hi, lb, ub, k, v, lo, ea, eb, el, eh)
    case False{} True{}:
      rot_hi.bnd(~K, ~V, ~cmp, ~trans, lo, lb, ub, k, v, hi, ea, eb, el, eh)
    case False{} False{}:
      bn.i(~K, ~V, ~cmp, lb, ub, k, v, lo, hi, ea, eb, el, eh)

def balance.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V, +lo: O.OMap<K, V>,
  +hi: O.OMap<K, V>,
  ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.balance(K, V, k, v, lo, hi), lb, ub) == True{} : Bool}:
  +wl = (O.OMap.size(K, V, lo) + 1 : U32)
  +wh = (O.OMap.size(K, V, hi) + 1 : U32)
  balance.if.bnd(~K, ~V, ~cmp, ~trans, U32.is_gt(wh, (3 * wl : U32)),
    U32.is_gt(wl, (3 * wh : U32)), lb, ub, k, v, lo, hi, ea, eb, el, eh)

# Proves a goal about O.Cmp.case by one case per comparison result.
def cmp.split(
  -A: Type, -B: Type, -F: A -> B, -G: B, c: Cmp, -f1: Unit -> A,
  -f2: Unit -> A, -f3: Unit -> A,
  hl: {c == LT{} : Cmp} -> {F(f1(Unit{})) == G : B},
  he: {c == EQ{} : Cmp} -> {F(f2(Unit{})) == G : B},
  hg: {c == GT{} : Cmp} -> {F(f3(Unit{})) == G : B}
) -> {F(O.Cmp.case(A, c, f1, f2, f3)) == G : B}:
  match c:
    case LT{}:
      hl({==})
    case EQ{}:
      he({==})
    case GT{}:
      hg({==})

def put.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~flip: Flip(~K, ~cmp),
  ~trans: Trans(~K, ~cmp), t: O.OMap<K, V>, +lb: Maybe<&2, K>,
  +ub: Maybe<&2, K>, +k: K, +v: V,
  +bt: {Laws.bounded(~K, ~V, ~cmp, t, lb, ub) == True{} : Bool},
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.put(~K, ~V, ~cmp, t, k, v), lb, ub) == True{} : Bool}:
  match t:
    case O.OTip{}:
      bn.i(~K, ~V, ~cmp, lb, ub, k, v, O.OTip{}, O.OTip{}, ea, eb, {==}, {==})
    case O.OBin{+s, +key, +val, +lo, +hi}:
      +b_a = bn.a(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_b = bn.b(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_l = bn.l(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_h = bn.h(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      cmp.split(O.OMap<K, V>, Bool, x => Laws.bounded(~K, ~V, ~cmp, x, lb, ub), True{},
        cmp(k, key),
        u => O.OMap.balance(K, V, key, val, O.OMap.put(~K, ~V, ~cmp, lo, k, v), hi),
        u => O.OBin{s, key, v, lo, hi},
        u => O.OMap.balance(K, V, key, val, lo, O.OMap.put(~K, ~V, ~cmp, hi, k, v)),
        e => balance.bnd(~K, ~V, ~cmp, ~trans, lb, ub, key, val,
          O.OMap.put(~K, ~V, ~cmp, lo, k, v), hi, b_a, b_b,
          put.bnd(~K, ~V, ~cmp, ~flip, ~trans, lo, lb, Some{key}, k, v, b_l, ea,
            lt_true(cmp(k, key), e)),
          b_h),
        e => bt,
        e => balance.bnd(~K, ~V, ~cmp, ~trans, lb, ub, key, val, lo,
          O.OMap.put(~K, ~V, ~cmp, hi, k, v), b_a, b_b, b_l,
          put.bnd(~K, ~V, ~cmp, ~flip, ~trans, hi, Some{key}, ub, k, v, b_h,
            lt_true(cmp(key, k), gt_flip(~K, ~cmp, ~flip, k, key, e)), eb)))

def Laws.omap_put_searchtree(K, V, cmp, refl, eq, flip, trans, m, tree, k, v):
  put.bnd(~K, ~V, ~cmp, ~flip, ~trans, m, None{}, None{}, k, v, tree, {==}, {==})
