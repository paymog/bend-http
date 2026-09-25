# Heap: a priority queue, as a skew heap ordered by a le you pass in.
#
# The smallest element (by le) sits at the top. push and pop are
# amortized O(log n) over a heap used once (sharing one with + and popping
# both copies can cost more), peek and size are O(1), and sort is
# heapsort. le is a template, as in List.sort: Heap.push(~U32, ~U32.is_le,
# 7, h).
#
# The laws at the bottom are checked every time this file is imported.
import Base

type Heap<-A: Data> is Data:
  HLeaf{}
  HNode{size: Nat, top: A, left: Heap<A>, right: Heap<A>}

def Heap.new(-A: Data) -> Heap<A>:
  HLeaf{}

def Heap.size(-A: Data, h: Heap<A>) -> Nat:
  match h:
    case HLeaf{}:
      0n
    case HNode{n, x, l, r}:
      n

def Heap.peek(-A: Data, h: Heap<A>) -> Maybe<&2, A>:
  match h:
    case HLeaf{}:
      None{}
    case HNode{n, x, l, r}:
      Some{x}

# The smaller root wins: its right child merges with the other heap and
# becomes the left, and its old left becomes the right (a skew heap's
# swap, which keeps merges short on average). The fuel is the size of both
# heaps: every step takes a root out, so it never runs short.
def Heap.merge.go(
  ~A: Data, ~le: A -> A -> Bool, fuel: Nat, a: Heap<A>, b: Heap<A>
) -> Heap<A>:
  match fuel:
    case 0n:
      a
    case 1n+f:
      match a b:
        case HLeaf{} HLeaf{}:
          HLeaf{}
        case HLeaf{} HNode{nb, y, bl, br}:
          HNode{nb, y, bl, br}
        case HNode{na, x, al, ar} HLeaf{}:
          HNode{na, x, al, ar}
        case HNode{+na, +x, +al, +ar} HNode{+nb, +y, +bl, +br}:
          +c = le(x, y)
          HNode{Nat.add(na, nb), Bool.pick(A, c, x, y),
            Heap.merge.go(~A, ~le, f,
              Bool.pick(Heap<A>, c, ar, br),
              Bool.pick(Heap<A>, c, HNode{nb, y, bl, br},
                HNode{na, x, al, ar})),
            Bool.pick(Heap<A>, c, al, bl)}

def Heap.merge(
  ~A: Data, ~le: A -> A -> Bool, +a: Heap<A>, +b: Heap<A>
) -> Heap<A>:
  Heap.merge.go(~A, ~le, Nat.add(Heap.size(A, a), Heap.size(A, b)), a, b)

def Heap.push(~A: Data, ~le: A -> A -> Bool, x: A, h: Heap<A>) -> Heap<A>:
  Heap.merge(~A, ~le, HNode{1n, x, HLeaf{}, HLeaf{}}, h)

# the top, and the heap without it; None on an empty heap
def Heap.pop(
  ~A: Data, ~le: A -> A -> Bool, h: Heap<A>
) -> Maybe<&1, A & Heap<A>>:
  match h:
    case HLeaf{}:
      None{}
    case HNode{n, x, l, r}:
      Some{(x, Heap.merge(~A, ~le, l, r))}

def Heap.from_list(~A: Data, ~le: A -> A -> Bool, xs: List<&2, A>) -> Heap<A>:
  match xs:
    case Nil{}:
      HLeaf{}
    case h <> t:
      Heap.push(~A, ~le, h, Heap.from_list(~A, ~le, t))

def Heap.to_list.go(
  ~A: Data, ~le: A -> A -> Bool, fuel: Nat, h: Heap<A>
) -> List<&2, A>:
  match fuel:
    case 0n:
      Nil{}
    case 1n+f:
      match h:
        case HLeaf{}:
          Nil{}
        case HNode{n, x, l, r}:
          x <> Heap.to_list.go(~A, ~le, f, Heap.merge(~A, ~le, l, r))

# the elements, smallest first
def Heap.to_list(~A: Data, ~le: A -> A -> Bool, +h: Heap<A>) -> List<&2, A>:
  Heap.to_list.go(~A, ~le, Heap.size(A, h), h)

# heapsort
def Heap.sort(~A: Data, ~le: A -> A -> Bool, xs: List<&2, A>) -> List<&2, A>:
  Heap.to_list(~A, ~le, Heap.from_list(~A, ~le, xs))

# Laws
# ----

# LAW: popping what was pushed onto an empty heap gives it back
law Heap.pop.push_new:
  for -x: U32
  {Heap.pop(~U32, ~U32.is_le, Heap.push(~U32, ~U32.is_le, x, Heap.new(U32)))
   == Some{(x, Heap.new(U32))} : Maybe<&1, U32 & Heap<U32>>}

def Heap.pop.push_new(x):
  {==}

# LAW: a push adds one to the size
law Heap.size.push:
  for -x: U32
  for  h: Heap<U32>
  {Heap.size(U32, Heap.push(~U32, ~U32.is_le, x, h))
   == 1n+Heap.size(U32, h) : Nat}

def Heap.size.push(x, h):
  match h:
    case HLeaf{}:
      {==}
    case HNode{n, y, l, r}:
      {==}
