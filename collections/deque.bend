# Deque: a double-ended queue, as a front list and a reversed back list.
#
# Pushing and popping on either end is amortized O(1), in any mix of ends
# (the refill below says why). Like List, the queries consume the deque: a
# Data deque is shared with +.
#
# The laws at the bottom are checked every time this file is imported.
import Base

type Deque<a, -A: Kind(a)> is Kind(a):
  Deq{front: List<a, A>, back: List<a, A>}

def Deque.new(a, -A: Kind(a)) -> Deque<a, A>:
  Deq{Nil{}, Nil{}}

# the list's first element is the deque's front
def Deque.from_list(a, -A: Kind(a), xs: List<a, A>) -> Deque<a, A>:
  Deq{xs, Nil{}}

def Deque.push_front(a, -A: Kind(a), x: A, d: Deque<a, A>) -> Deque<a, A>:
  match d:
    case Deq{f, b}:
      Deq{x <> f, b}

def Deque.push_back(a, -A: Kind(a), x: A, d: Deque<a, A>) -> Deque<a, A>:
  match d:
    case Deq{f, b}:
      Deq{f, x <> b}

def Deque.count.put(
  a, -A: Kind(a), h: A, rn: List<a, A> & Nat
) -> List<a, A> & Nat:
  (rest, n) = rn
  (h <> rest, 1n+n)

# a list and its length, in one pass that hands the list back
def Deque.count(a, -A: Kind(a), xs: List<a, A>) -> List<a, A> & Nat:
  match xs:
    case Nil{}:
      (Nil{}, 0n)
    case h <> t:
      Deque.count.put(a, A, h, Deque.count(a, A, t))

def Deque.half(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      match p:
        case 0n:
          0n
        case 1n+q:
          1n+Deque.half(q)

def Deque.split.put(
  a, -A: Kind(a), h: A, lr: List<a, A> & List<a, A>
) -> List<a, A> & List<a, A>:
  (l, r) = lr
  (h <> l, r)

# the first n elements, and the rest
def Deque.split(a, -A: Kind(a), n: Nat, xs: List<a, A>) ->
  List<a, A> & List<a, A>:
  match n:
    case 0n:
      (Nil{}, xs)
    case 1n+p:
      match xs:
        case Nil{}:
          (Nil{}, Nil{})
        case h <> t:
          Deque.split.put(a, A, h, Deque.split(a, A, p, t))

# When one end runs out, the other list is split in half and only the half
# nearest the empty end is reversed over. Moving everything would let pops
# that alternate ends reverse the whole deque each time; halving keeps the
# lists balanced, so every operation stays amortized O(1).

def Deque.pop_front.go(
  a, -A: Kind(a), xs: List<a, A>, b: List<a, A>
) -> Maybe<&1, A & Deque<a, A>>:
  match xs:
    case Nil{}:
      None{}
    case h <> t:
      Some{(h, Deq{t, b})}

def Deque.pop_front.halves(
  a, -A: Kind(a), sm: List<a, A> & List<a, A>
) -> Maybe<&1, A & Deque<a, A>>:
  (stay, move) = sm
  Deque.pop_front.go(a, A, List.reverse(a, A, move), stay)

def Deque.pop_front.refill(
  a, -A: Kind(a), bn: List<a, A> & Nat
) -> Maybe<&1, A & Deque<a, A>>:
  (b, n) = bn
  Deque.pop_front.halves(a, A, Deque.split(a, A, Deque.half(n), b))

def Deque.pop_front(
  a, -A: Kind(a), d: Deque<a, A>
) -> Maybe<&1, A & Deque<a, A>>:
  match d:
    case Deq{f, b}:
      match f:
        case h <> t:
          Some{(h, Deq{t, b})}
        case Nil{}:
          Deque.pop_front.refill(a, A, Deque.count(a, A, b))

def Deque.pop_back.go(
  a, -A: Kind(a), xs: List<a, A>, f: List<a, A>
) -> Maybe<&1, A & Deque<a, A>>:
  match xs:
    case Nil{}:
      None{}
    case h <> t:
      Some{(h, Deq{f, t})}

def Deque.pop_back.halves(
  a, -A: Kind(a), sm: List<a, A> & List<a, A>
) -> Maybe<&1, A & Deque<a, A>>:
  (stay, move) = sm
  Deque.pop_back.go(a, A, List.reverse(a, A, move), stay)

def Deque.pop_back.refill(
  a, -A: Kind(a), fn: List<a, A> & Nat
) -> Maybe<&1, A & Deque<a, A>>:
  (f, n) = fn
  Deque.pop_back.halves(a, A, Deque.split(a, A, Deque.half(n), f))

def Deque.pop_back(
  a, -A: Kind(a), d: Deque<a, A>
) -> Maybe<&1, A & Deque<a, A>>:
  match d:
    case Deq{f, b}:
      match b:
        case h <> t:
          Some{(h, Deq{f, t})}
        case Nil{}:
          Deque.pop_back.refill(a, A, Deque.count(a, A, f))

# the elements, front to back
def Deque.to_list(a, -A: Kind(a), d: Deque<a, A>) -> List<a, A>:
  match d:
    case Deq{f, b}:
      List.append(a, A, f, List.reverse(a, A, b))

def Deque.length(a, -A: Kind(a), d: Deque<a, A>) -> Nat:
  match d:
    case Deq{f, b}:
      Nat.add(List.length(a, A, f), List.length(a, A, b))

def Deque.is_empty(a, -A: Kind(a), d: Deque<a, A>) -> Bool:
  match d:
    case Deq{f, b}:
      Bool.and(List.is_empty(a, A, f), List.is_empty(a, A, b))

# Laws
# ----
# Each law reads a deque through to_list, the only view a user has of it.

# LAW: a new deque reads as the empty list
law Deque.to_list.new:
  for -A: Data
  {Deque.to_list(&2, A, Deque.new(&2, A)) == Nil{} : List<&2, A>}

def Deque.to_list.new(A):
  {==}

# LAW: push_front puts the element at the head of the list
law Deque.to_list.push_front:
  for -A: Data
  for -x: A
  for  d: Deque<&2, A>
  {Deque.to_list(&2, A, Deque.push_front(&2, A, x, d))
   == x <> Deque.to_list(&2, A, d) : List<&2, A>}

def Deque.to_list.push_front(A, x, d):
  match d:
    case Deq{f, b}:
      {==}

# LAW: pop_front undoes push_front
law Deque.pop_front.push_front:
  for -A: Data
  for -x: A
  for  d: Deque<&2, A>
  {Deque.pop_front(&2, A, Deque.push_front(&2, A, x, d))
   == Some{(x, d)} : Maybe<&1, A & Deque<&2, A>>}

def Deque.pop_front.push_front(A, x, d):
  match d:
    case Deq{f, b}:
      {==}

# LAW: pop_back undoes push_back
law Deque.pop_back.push_back:
  for -A: Data
  for -x: A
  for  d: Deque<&2, A>
  {Deque.pop_back(&2, A, Deque.push_back(&2, A, x, d))
   == Some{(x, d)} : Maybe<&1, A & Deque<&2, A>>}

def Deque.pop_back.push_back(A, x, d):
  match d:
    case Deq{f, b}:
      {==}

# Lemmas over Base's List, by induction on the first list

law Deque.lemma.append_nil:
  for -A: Data
  for  xs: List<&2, A>
  {List.append(&2, A, xs, Nil{}) == xs : List<&2, A>}

def Deque.lemma.append_nil(A, xs):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      %Deque.lemma.append_nil(A, t) : {h <> List.append(&2, A, t, Nil{})
        == h <> _ : List<&2, A>}
      {==}

law Deque.lemma.append_assoc:
  for -A: Data
  for  xs: List<&2, A>
  for -ys: List<&2, A>
  for -zs: List<&2, A>
  {List.append(&2, A, List.append(&2, A, xs, ys), zs)
   == List.append(&2, A, xs, List.append(&2, A, ys, zs)) : List<&2, A>}

def Deque.lemma.append_assoc(A, xs, ys, zs):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      %Deque.lemma.append_assoc(A, t, ys, zs) : {h <> List.append(&2, A,
        List.append(&2, A, t, ys), zs) == h <> _ : List<&2, A>}
      {==}

# LAW: a list read into a deque reads back as itself
law Deque.to_list.from_list:
  for -A: Data
  for  xs: List<&2, A>
  {Deque.to_list(&2, A, Deque.from_list(&2, A, xs)) == xs : List<&2, A>}

def Deque.to_list.from_list(A, xs):
  Deque.lemma.append_nil(A, xs)

# reversing onto an accumulator is reversing, then appending it
law Deque.lemma.reverse_go:
  for -A: Data
  for  xs: List<&2, A>
  for -acc: List<&2, A>
  {List.append(&2, A, List.reverse.go(&2, A, xs, Nil{}), acc)
   == List.reverse.go(&2, A, xs, acc) : List<&2, A>}

def Deque.lemma.reverse_go(A, xs, acc):
  match xs:
    case Nil{}:
      {==}
    case +h <> +t:
      %Deque.lemma.reverse_go(A, t, [h]) : {List.append(&2, A, _, acc)
        == List.reverse.go(&2, A, t, h <> acc) : List<&2, A>}
      %Deque.lemma.reverse_go(A, t, h <> acc) : {List.append(&2, A,
        List.append(&2, A, List.reverse.go(&2, A, t, Nil{}), [h]), acc)
        == _ : List<&2, A>}
      Deque.lemma.append_assoc(A, List.reverse.go(&2, A, t, Nil{}), [h], acc)

# LAW: push_back puts the element at the end of the list
law Deque.to_list.push_back:
  for -A: Data
  for -x: A
  for  d: Deque<&2, A>
  {Deque.to_list(&2, A, Deque.push_back(&2, A, x, d))
   == List.append(&2, A, Deque.to_list(&2, A, d), [x]) : List<&2, A>}

def Deque.to_list.push_back(A, x, d):
  match d:
    case Deq{+f, +b}:
      %Deque.lemma.reverse_go(A, b, [x]) : {List.append(&2, A, f, _)
        == List.append(&2, A, List.append(&2, A, f, List.reverse(&2, A, b)),
          [x]) : List<&2, A>}
      %Deque.lemma.append_assoc(A, f, List.reverse(&2, A, b), [x]) : {_
        == List.append(&2, A, List.append(&2, A, f, List.reverse(&2, A, b)),
          [x]) : List<&2, A>}
      {==}
