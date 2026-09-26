# Peano-order lemmas for weight-balance proofs (#88 follow-up).
import Base

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

def not_le_suc_zero(p: Nat) -> {Nat.is_le(1n+p, 0n) == False{} : Bool}:
  match p:
    case 0n:
      {==}
    case 1n+pp:
      {==}

def le_suc_zero() -> {Nat.is_le(0n, 1n) == True{} : Bool}:
  {==}
