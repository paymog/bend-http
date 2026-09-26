# Minimal repro: cannot project weight_balanced on OBin (#88).
import Base
import ./LAWS.bend as Laws
import ./omap.bend as O

def and_l(a: Bool, b: Bool, e: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}:
      e
    case False{}:
      {==}

def proj_ok(
  ~K: Data, ~V: Data, +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  bt: {Laws.weight_balanced(K, V, O.OBin{0, k, v, lo, hi}) == True{} : Bool}
) -> {Laws.weight_ok(Laws.omap_weight(K, V, lo), Laws.omap_weight(K, V, hi)) == True{} : Bool}:
  and_l(Laws.weight_ok(Laws.omap_weight(K, V, lo), Laws.omap_weight(K, V, hi)),
    Bool.and(Laws.weight_balanced(K, V, lo), Laws.weight_balanced(K, V, hi)), bt)
