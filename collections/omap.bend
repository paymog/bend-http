# OMap: an ordered map keyed by any Data type, as a weight-balanced tree.
#
# The order is a template cmp, as in List.sort: OMap.put(~U32, ~U32,
# ~U32.cmp, m, 7, 70). put, get and del are O(log n) comparisons. Balance
# follows Hirai and Yamamoto (delta 3, gamma 2), which is correct for both
# insertion and deletion with one rebalance per level.
import Base

type OMap<-K: Data, -V: Data> is Data:
  OTip{}
  OBin{size: U32, key: K, val: V, lo: OMap<K, V>, hi: OMap<K, V>}

def OMap.new(-K: Data, -V: Data) -> OMap<K, V>:
  OTip{}

def OMap.size(-K: Data, -V: Data, m: OMap<K, V>) -> U32:
  match m:
    case OTip{}:
      0
    case OBin{s, k, v, lo, hi}:
      s

# The recursion on cmp's result: a match cannot scrutinize cmp(k, key), and
# a template cannot call a law filled below it, so each branch is a closure.
def Cmp.case(
  -A: Type, c: Cmp, lt: Unit -> A, eq: Unit -> A, gt: Unit -> A
) -> A:
  match c:
    case LT{}:
      lt(Unit{})
    case EQ{}:
      eq(Unit{})
    case GT{}:
      gt(Unit{})

def OMap.bin(
  -K: Data, -V: Data, k: K, v: V, +lo: OMap<K, V>, +hi: OMap<K, V>
) -> OMap<K, V>:
  OBin{(1 + OMap.size(K, V, lo) + OMap.size(K, V, hi) : U32), k, v, lo, hi}

def OMap.rot_lo.double(
  -K: Data, -V: Data, k: K, v: V, lo: OMap<K, V>, hk: K, hv: V,
  hl: OMap<K, V>, hh: OMap<K, V>
) -> OMap<K, V>:
  match hl:
    case OTip{}:
      OMap.bin(K, V, hk, hv, OMap.bin(K, V, k, v, lo, OTip{}), hh)
    case OBin{s, mk, mv, ml, mh}:
      OMap.bin(K, V, mk, mv, OMap.bin(K, V, k, v, lo, ml),
        OMap.bin(K, V, hk, hv, mh, hh))

def OMap.rot_lo.pick(
  -K: Data, -V: Data, single: Bool, k: K, v: V, lo: OMap<K, V>, hk: K, hv: V,
  hl: OMap<K, V>, hh: OMap<K, V>
) -> OMap<K, V>:
  match single:
    case True{}:
      OMap.bin(K, V, hk, hv, OMap.bin(K, V, k, v, lo, hl), hh)
    case False{}:
      OMap.rot_lo.double(K, V, k, v, lo, hk, hv, hl, hh)

# The hi side is too heavy: move weight toward lo.
def OMap.rot_lo(
  -K: Data, -V: Data, k: K, v: V, lo: OMap<K, V>, hi: OMap<K, V>
) -> OMap<K, V>:
  match hi:
    case OTip{}:
      OMap.bin(K, V, k, v, lo, OTip{})
    case OBin{s, hk, hv, +hl, +hh}:
      OMap.rot_lo.pick(K, V,
        U32.is_lt((OMap.size(K, V, hl) + 1 : U32),
          (2 * (OMap.size(K, V, hh) + 1) : U32)),
        k, v, lo, hk, hv, hl, hh)

def OMap.rot_hi.double(
  -K: Data, -V: Data, k: K, v: V, lk: K, lv: V, ll: OMap<K, V>,
  lh: OMap<K, V>, hi: OMap<K, V>
) -> OMap<K, V>:
  match lh:
    case OTip{}:
      OMap.bin(K, V, lk, lv, ll, OMap.bin(K, V, k, v, OTip{}, hi))
    case OBin{s, mk, mv, ml, mh}:
      OMap.bin(K, V, mk, mv, OMap.bin(K, V, lk, lv, ll, ml),
        OMap.bin(K, V, k, v, mh, hi))

def OMap.rot_hi.pick(
  -K: Data, -V: Data, single: Bool, k: K, v: V, lk: K, lv: V, ll: OMap<K, V>,
  lh: OMap<K, V>, hi: OMap<K, V>
) -> OMap<K, V>:
  match single:
    case True{}:
      OMap.bin(K, V, lk, lv, ll, OMap.bin(K, V, k, v, lh, hi))
    case False{}:
      OMap.rot_hi.double(K, V, k, v, lk, lv, ll, lh, hi)

# The lo side is too heavy: move weight toward hi.
def OMap.rot_hi(
  -K: Data, -V: Data, k: K, v: V, lo: OMap<K, V>, hi: OMap<K, V>
) -> OMap<K, V>:
  match lo:
    case OTip{}:
      OMap.bin(K, V, k, v, OTip{}, hi)
    case OBin{s, lk, lv, +ll, +lh}:
      OMap.rot_hi.pick(K, V,
        U32.is_lt((OMap.size(K, V, lh) + 1 : U32),
          (2 * (OMap.size(K, V, ll) + 1) : U32)),
        k, v, lk, lv, ll, lh, hi)

def OMap.balance.if(
  -K: Data, -V: Data, heavy_hi: Bool, heavy_lo: Bool, k: K, v: V,
  lo: OMap<K, V>, hi: OMap<K, V>
) -> OMap<K, V>:
  match heavy_hi heavy_lo:
    case True{} _:
      OMap.rot_lo(K, V, k, v, lo, hi)
    case False{} True{}:
      OMap.rot_hi(K, V, k, v, lo, hi)
    case False{} False{}:
      OMap.bin(K, V, k, v, lo, hi)

# A node whose sides were balanced before one insertion or deletion.
def OMap.balance(
  -K: Data, -V: Data, k: K, v: V, +lo: OMap<K, V>, +hi: OMap<K, V>
) -> OMap<K, V>:
  +wl = (OMap.size(K, V, lo) + 1 : U32)
  +wh = (OMap.size(K, V, hi) + 1 : U32)
  OMap.balance.if(K, V, U32.is_gt(wh, (3 * wl : U32)),
    U32.is_gt(wl, (3 * wh : U32)), k, v, lo, hi)

def OMap.put(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, m: OMap<K, V>, +k: K, +v: V
) -> OMap<K, V>:
  match m:
    case OTip{}:
      OBin{1, k, v, OTip{}, OTip{}}
    case OBin{+s, +key, +val, +lo, +hi}:
      Cmp.case(OMap<K, V>, cmp(k, key),
        u => OMap.balance(K, V, key, val, OMap.put(~K, ~V, ~cmp, lo, k, v), hi),
        u => OBin{s, key, v, lo, hi},
        u => OMap.balance(K, V, key, val, lo, OMap.put(~K, ~V, ~cmp, hi, k, v)))

def OMap.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, m: OMap<K, V>, +k: K
) -> Maybe<&2, V>:
  match m:
    case OTip{}:
      None{}
    case OBin{s, +key, +val, +lo, +hi}:
      Cmp.case(Maybe<&2, V>, cmp(k, key),
        u => OMap.get(~K, ~V, ~cmp, lo, k),
        u => Some{val},
        u => OMap.get(~K, ~V, ~cmp, hi, k))

def OMap.has(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, m: OMap<K, V>, +k: K
) -> Bool:
  Maybe.is_some(&2, V, OMap.get(~K, ~V, ~cmp, m, k))

def OMap.pop_min.fin(
  -K: Data, -V: Data, k: K, v: V, hi: OMap<K, V>,
  r: K & V & OMap<K, V>
) -> K & V & OMap<K, V>:
  (mk, mv, lo) = r
  (mk, mv, OMap.balance(K, V, k, v, lo, hi))

# The least entry of the node lo < (k, v) < hi, and the node without it.
def OMap.pop_min(
  -K: Data, -V: Data, lo: OMap<K, V>, k: K, v: V, hi: OMap<K, V>
) -> K & V & OMap<K, V>:
  match lo:
    case OTip{}:
      (k, v, hi)
    case OBin{s, lk, lv, ll, lh}:
      OMap.pop_min.fin(K, V, k, v, hi, OMap.pop_min(K, V, ll, lk, lv, lh))

def OMap.glue.fin(
  -K: Data, -V: Data, lo: OMap<K, V>, r: K & V & OMap<K, V>
) -> OMap<K, V>:
  (k, v, hi) = r
  OMap.balance(K, V, k, v, lo, hi)

# Joins two sides of a deleted node.
def OMap.glue(-K: Data, -V: Data, lo: OMap<K, V>, hi: OMap<K, V>) -> OMap<K, V>:
  match hi:
    case OTip{}:
      lo
    case OBin{s, k, v, hl, hh}:
      OMap.glue.fin(K, V, lo, OMap.pop_min(K, V, hl, k, v, hh))

def OMap.del(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, m: OMap<K, V>, +k: K
) -> OMap<K, V>:
  match m:
    case OTip{}:
      OTip{}
    case OBin{s, +key, +val, +lo, +hi}:
      Cmp.case(OMap<K, V>, cmp(k, key),
        u => OMap.balance(K, V, key, val, OMap.del(~K, ~V, ~cmp, lo, k), hi),
        u => OMap.glue(K, V, lo, hi),
        u => OMap.balance(K, V, key, val, lo, OMap.del(~K, ~V, ~cmp, hi, k)))

def OMap.keys.go(
  -K: Data, -V: Data, m: OMap<K, V>, acc: List<&2, K>
) -> List<&2, K>:
  match m:
    case OTip{}:
      acc
    case OBin{s, k, v, lo, hi}:
      OMap.keys.go(K, V, lo, k <> OMap.keys.go(K, V, hi, acc))

# The keys in ascending order.
def OMap.keys(-K: Data, -V: Data, m: OMap<K, V>) -> List<&2, K>:
  OMap.keys.go(K, V, m, Nil{})

def OMap.to_list.go(
  -K: Data, -V: Data, m: OMap<K, V>, acc: List<&1, K & V>
) -> List<&1, K & V>:
  match m:
    case OTip{}:
      acc
    case OBin{s, k, v, lo, hi}:
      OMap.to_list.go(K, V, lo, (k, v) <> OMap.to_list.go(K, V, hi, acc))

# The entries in ascending key order.
def OMap.to_list(-K: Data, -V: Data, m: OMap<K, V>) -> List<&1, K & V>:
  OMap.to_list.go(K, V, m, Nil{})

def OSet(-K: Data) -> Data:
  OMap<K, Unit>

def OSet.new(-K: Data) -> OSet(K):
  OTip{}

def OSet.size(-K: Data, s: OSet(K)) -> U32:
  OMap.size(K, Unit, s)

def OSet.add(~K: Data, ~cmp: K -> K -> Cmp, s: OSet(K), +k: K) -> OSet(K):
  OMap.put(~K, ~Unit, ~cmp, s, k, Unit{})

def OSet.has(~K: Data, ~cmp: K -> K -> Cmp, s: OSet(K), +k: K) -> Bool:
  OMap.has(~K, ~Unit, ~cmp, s, k)

def OSet.del(~K: Data, ~cmp: K -> K -> Cmp, s: OSet(K), +k: K) -> OSet(K):
  OMap.del(~K, ~Unit, ~cmp, s, k)

# The elements in ascending order.
def OSet.to_list(-K: Data, s: OSet(K)) -> List<&2, K>:
  OMap.keys(K, Unit, s)
