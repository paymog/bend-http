# Vec: a growable array. push is amortized O(1): a full buffer doubles.
#
# get, set and pop are one Array access. An index at or past the length
# answers None (get, pop) or leaves the vector as it was (set).
import Base

type Vec<-T: Data> is Type:
  VNil{}
  Vec{len: U32, buf: Array<T>}

def Vec.new(~T: Data) -> Vec<T>:
  VNil{}

def Vec.len(~T: Data, v: Vec<T>) -> Vec<T> & U32:
  match v:
    case VNil{}:
      (VNil{}, 0)
    case Vec{+n, buf}:
      (Vec{n, buf}, n)

def Vec.copy(
  ~T: Data, fuel: Nat, +i: U32, dst: Array<T>, r: Array<T> & T
) -> Array<T>:
  match fuel:
    case 0n:
      dst
    case 1n+p:
      (src, x) = r
      +j = U32.inc(i)
      Vec.copy(~T, p, j, Array.set(T, dst, i, x), Array.get(T, src, j))

def Vec.push.grow(
  ~T: Data, full: Bool, +n: U32, +x: T, buf: Array<T>, +cap: U32
) -> Vec<T>:
  match full:
    case False{}:
      Vec{U32.inc(n), Array.set(T, buf, n, x)}
    case True{}:
      # Every slot of big starts as x, so slot n needs no write.
      big = Array.new(T, 1n+U32.log2(cap), x)
      Vec{U32.inc(n), Vec.copy(~T, U32.to_nat(n), 0, big, Array.get(T, buf, 0))}

def Vec.push.at(~T: Data, +n: U32, +x: T, bc: Array<T> & U32) -> Vec<T>:
  (buf, +cap) = bc
  Vec.push.grow(~T, U32.is_eq(n, cap), n, x, buf, cap)

def Vec.push(~T: Data, v: Vec<T>, +x: T) -> Vec<T>:
  match v:
    case VNil{}:
      Vec{1, ALeaf{x}}
    case Vec{+n, buf}:
      Vec.push.at(~T, n, x, Array.size(T, buf))

def Vec.get.fin(~T: Data, n: U32, r: Array<T> & T) -> Vec<T> & Maybe<&2, T>:
  (buf, x) = r
  (Vec{n, buf}, Some{x})

def Vec.get.if(
  ~T: Data, ok: Bool, +n: U32, buf: Array<T>, +i: U32
) -> Vec<T> & Maybe<&2, T>:
  match ok:
    case True{}:
      Vec.get.fin(~T, n, Array.get(T, buf, i))
    case False{}:
      (Vec{n, buf}, None{})

def Vec.get(~T: Data, v: Vec<T>, +i: U32) -> Vec<T> & Maybe<&2, T>:
  match v:
    case VNil{}:
      (VNil{}, None{})
    case Vec{+n, buf}:
      Vec.get.if(~T, U32.is_lt(i, n), n, buf, i)

def Vec.set.if(
  ~T: Data, ok: Bool, n: U32, buf: Array<T>, i: U32, x: T
) -> Vec<T>:
  match ok:
    case True{}:
      Vec{n, Array.set(T, buf, i, x)}
    case False{}:
      Vec{n, buf}

def Vec.set(~T: Data, v: Vec<T>, +i: U32, x: T) -> Vec<T>:
  match v:
    case VNil{}:
      VNil{}
    case Vec{+n, buf}:
      Vec.set.if(~T, U32.is_lt(i, n), n, buf, i, x)

def Vec.pop.if(
  ~T: Data, empty: Bool, +n: U32, buf: Array<T>
) -> Vec<T> & Maybe<&2, T>:
  match empty:
    case True{}:
      (Vec{n, buf}, None{})
    case False{}:
      +m = (n - 1 : U32)
      Vec.get.fin(~T, m, Array.get(T, buf, m))

# The last element, and the vector without it. The buffer keeps its size.
def Vec.pop(~T: Data, v: Vec<T>) -> Vec<T> & Maybe<&2, T>:
  match v:
    case VNil{}:
      (VNil{}, None{})
    case Vec{+n, buf}:
      Vec.pop.if(~T, U32.is_zero(n), n, buf)

def Vec.to_list.go(
  ~T: Data, fuel: Nat, +i: U32, acc: List<&2, T>, r: Array<T> & T
) -> List<&2, T>:
  match fuel:
    case 0n:
      acc
    case 1n+p:
      (buf, x) = r
      +j = (i - 1 : U32)
      Vec.to_list.go(~T, p, j, x <> acc, Array.get(T, buf, j))

# The elements, first to last.
def Vec.to_list(~T: Data, v: Vec<T>) -> List<&2, T>:
  match v:
    case VNil{}:
      Nil{}
    case Vec{+n, buf}:
      +last = (n - 1 : U32)
      Vec.to_list.go(~T, U32.to_nat(n), last, Nil{}, Array.get(T, buf, last))

def Vec.from_list.go(~T: Data, xs: List<&2, T>, v: Vec<T>) -> Vec<T>:
  match xs:
    case Nil{}:
      v
    case h <> t:
      Vec.from_list.go(~T, t, Vec.push(~T, v, h))

def Vec.from_list(~T: Data, xs: List<&2, T>) -> Vec<T>:
  Vec.from_list.go(~T, xs, VNil{})
