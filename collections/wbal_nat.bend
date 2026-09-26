# Isolated Nat order smoke test (#88). Run: bend collections/wbal_nat.bend
import Base
import ./nat_order.bend as Ord

def smoke_wok_i() -> {Ord.wok(1n, 1n) == True{} : Bool}:
  Ord.wok_i(1n, 1n, {==}, {==})

def smoke_one_le_suc() -> {Nat.is_le(1n, 1n+3n) == True{} : Bool}:
  Ord.one_le_suc(3n)
