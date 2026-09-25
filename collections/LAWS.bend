import Base
import ./omap.bend as O
import ./vec.bend as V
import ./deque.bend as D
import ./heap.bend as H

def scmp.fin(r: (String & String) & Cmp) -> Cmp:
  (ab, c) = r
  c

def scmp(a: String, b: String) -> Cmp:
  scmp.fin(String.cmp(a, b))

def m3() -> O.OMap<U32, U32>:
  m = O.OMap.put(~U32, ~U32, ~U32.cmp, O.OMap.new(U32, U32), 5, 50)
  m = O.OMap.put(~U32, ~U32, ~U32.cmp, m, 1, 10)
  O.OMap.put(~U32, ~U32, ~U32.cmp, m, 3, 30)

def m7.go(n: Nat, +i: U32, m: O.OMap<U32, U32>) -> O.OMap<U32, U32>:
  match n:
    case 0n:
      m
    case 1n+p:
      m7.go(p, (i + 1 : U32), O.OMap.put(~U32, ~U32, ~U32.cmp, m, i, (i * 10 : U32)))

def m7() -> O.OMap<U32, U32>:
  m7.go(7n, 1, O.OMap.new(U32, U32))

law omap_keys_ascending_puts:
  {O.OMap.keys(U32, U32, m7()) == [1, 2, 3, 4, 5, 6, 7] : List<&2, U32>}

law omap_size_del:
  {O.OMap.size(U32, U32, O.OMap.del(~U32, ~U32, ~U32.cmp, m7(), 4)) == 6 : U32}

law omap_get_after_rotations:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.del(~U32, ~U32, ~U32.cmp, m7(), 4), 6)
   == Some{60} : Maybe<&2, U32>}

law omap_keys_del_root:
  {O.OMap.keys(U32, U32, O.OMap.del(~U32, ~U32, ~U32.cmp, m7(), 4))
   == [1, 2, 3, 5, 6, 7] : List<&2, U32>}

law omap_get_put:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.put(~U32, ~U32, ~U32.cmp, m3(), 4, 40), 4)
   == Some{40} : Maybe<&2, U32>}

law omap_get_put_replace:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.put(~U32, ~U32, ~U32.cmp, m3(), 3, 33), 3)
   == Some{33} : Maybe<&2, U32>}

law omap_get_put_other:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.put(~U32, ~U32, ~U32.cmp, m3(), 4, 40), 3)
   == O.OMap.get(~U32, ~U32, ~U32.cmp, m3(), 3) : Maybe<&2, U32>}

law omap_get_missing:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, m3(), 2) == None{} : Maybe<&2, U32>}

law omap_keys_sorted:
  {O.OMap.keys(U32, U32, O.OMap.put(~U32, ~U32, ~U32.cmp, m3(), 4, 40))
   == [1, 3, 4, 5] : List<&2, U32>}

law omap_size_replace:
  {O.OMap.size(U32, U32, O.OMap.put(~U32, ~U32, ~U32.cmp, m3(), 5, 55)) == 3 : U32}

law omap_get_del:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.del(~U32, ~U32, ~U32.cmp, m3(), 3), 3)
   == None{} : Maybe<&2, U32>}

law omap_get_del_other:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.del(~U32, ~U32, ~U32.cmp, m3(), 3), 5)
   == Some{50} : Maybe<&2, U32>}

law omap_keys_del:
  {O.OMap.keys(U32, U32, O.OMap.del(~U32, ~U32, ~U32.cmp, m3(), 5))
   == [1, 3] : List<&2, U32>}

law omap_string_keys:
  {O.OMap.keys(String, U32,
     O.OMap.put(~String, ~U32, ~scmp,
       O.OMap.put(~String, ~U32, ~scmp, O.OMap.new(String, U32), "b", 2),
       "a", 1))
   == ["a", "b"] : List<&2, String>}

law oset_to_list:
  {O.OSet.to_list(U32,
     O.OSet.add(~U32, ~U32.cmp, O.OSet.add(~U32, ~U32.cmp,
       O.OSet.add(~U32, ~U32.cmp, O.OSet.new(U32), 3), 1), 3))
   == [1, 3] : List<&2, U32>}

law oset_has_del:
  {O.OSet.has(~U32, ~U32.cmp,
     O.OSet.del(~U32, ~U32.cmp, O.OSet.add(~U32, ~U32.cmp, O.OSet.new(U32), 3), 3), 3)
   == False{} : Bool}

law vec_from_list:
  {V.Vec.to_list(~U32, V.Vec.from_list(~U32, [1, 2, 3, 4, 5]))
   == [1, 2, 3, 4, 5] : List<&2, U32>}

law vec_get:
  {Pair.snd(V.Vec<U32>, Maybe<&2, U32>, V.Vec.get(~U32, V.Vec.from_list(~U32, [1, 2, 3]), 2))
   == Some{3} : Maybe<&2, U32>}

law vec_get_past_len:
  {Pair.snd(V.Vec<U32>, Maybe<&2, U32>, V.Vec.get(~U32, V.Vec.from_list(~U32, [1, 2, 3]), 3))
   == None{} : Maybe<&2, U32>}

law vec_set:
  {V.Vec.to_list(~U32, V.Vec.set(~U32, V.Vec.from_list(~U32, [1, 2, 3]), 1, 9))
   == [1, 9, 3] : List<&2, U32>}

law vec_pop:
  {Pair.snd(V.Vec<U32>, Maybe<&2, U32>, V.Vec.pop(~U32, V.Vec.from_list(~U32, [1, 2, 3])))
   == Some{3} : Maybe<&2, U32>}

law vec_pop_empty:
  {Pair.snd(V.Vec<U32>, Maybe<&2, U32>, V.Vec.pop(~U32, V.Vec.new(~U32)))
   == None{} : Maybe<&2, U32>}

law vec_pop_to_list:
  {V.Vec.to_list(~U32, Pair.fst(V.Vec<U32>, Maybe<&2, U32>,
     V.Vec.pop(~U32, V.Vec.from_list(~U32, [1, 2, 3]))))
   == [1, 2] : List<&2, U32>}

law deque_ends:
  {D.Deque.to_list(&2, U32, D.Deque.push_front(&2, U32, 0,
     D.Deque.push_back(&2, U32, 2, D.Deque.push_back(&2, U32, 1, D.Deque.new(&2, U32)))))
   == [0, 1, 2] : List<&2, U32>}

law heap_sort:
  {H.Heap.sort(~U32, ~U32.is_le, [3, 1, 4, 1, 5]) == [1, 1, 3, 4, 5] : List<&2, U32>}
