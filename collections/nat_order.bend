# Peano-order lemmas for weight-balance proofs (#88).
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

def not_le_suc_zero(p: Nat) -> {Nat.is_le(1n+p, 0n) == False{} : Bool}:
  match p:
    case 0n:
      {==}
    case 1n+pp:
      {==}

def le_suc(b: Nat) -> {Nat.is_le(b, Nat.add(1n, b)) == True{} : Bool}:
  match b:
    case 0n:
      {==}
    case 1n+p:
      le_suc(p)

def le_refl(a: Nat) -> {Nat.is_le(a, a) == True{} : Bool}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      le_refl(p)

def le_zero(c: Nat) -> {Nat.is_le(0n, c) == True{} : Bool}:
  match c:
    case 0n:
      {==}
    case 1n+p:
      {==}

def le_zero_suc(p: Nat) -> {Nat.is_le(0n, 1n+p) == True{} : Bool}:
  match p:
    case 0n:
      {==}
    case 1n+pp:
      {==}

def le_trans_zero(b: Nat, c: Nat, e2: {Nat.is_le(b, c) == True{} : Bool})
  -> {Nat.is_le(0n, c) == True{} : Bool}:
  match b c:
    case 0n 0n:
      e2
    case 0n 1n+cp:
      {==}
    case 1n+bp 0n:
      exfalso({Nat.is_le(0n, 0n) == True{} : Bool}, absurd_b(e2))
    case 1n+bp 1n+cp:
      {==}

def le_trans(a: Nat, b: Nat, c: Nat, e1: {Nat.is_le(a, b) == True{} : Bool},
  e2: {Nat.is_le(b, c) == True{} : Bool}) -> {Nat.is_le(a, c) == True{} : Bool}:
  match a:
    case 0n:
      le_trans_zero(b, c, e2)
    case 1n+ap:
      match b c:
        case 0n 0n:
          exfalso({Nat.is_le(1n+ap, 0n) == True{} : Bool}, absurd_b(e1))
        case 0n 1n+cp:
          exfalso({Nat.is_le(1n+ap, 1n+cp) == True{} : Bool}, absurd_b(e1))
        case 1n+bp 0n:
          exfalso({Nat.is_le(1n+ap, 0n) == True{} : Bool}, absurd_b(e2))
        case 1n+bp 1n+cp:
          le_trans(ap, bp, cp, e1, e2)

def le_one_add_aux(p: Nat) -> {Nat.is_le(1n, Nat.add(1n, 1n+p)) == True{} : Bool}:
  match p:
    case 0n:
      {==}
    case 1n+ +p:
      le_trans(1n, Nat.add(1n, 1n+p), Nat.add(1n, 1n+1n+p), le_one_add_aux(p),
        le_suc(Nat.add(1n, 1n+p)))

def le_one_add(b: Nat) -> {Nat.is_le(1n, Nat.add(1n, b)) == True{} : Bool}:
  match b:
    case 0n:
      {==}
    case 1n+p:
      le_one_add_aux(p)

def le_succ_mono(a: Nat, b: Nat, e: {Nat.is_le(a, b) == True{} : Bool})
  -> {Nat.is_le(1n+a, 1n+b) == True{} : Bool}:
  match a:
    case 0n:
      match b:
        case 0n:
          {==}
        case 1n+p:
          le_one_add(b)
    case 1n+ap:
      match b:
        case 0n:
          exfalso({False{} == True{} : Bool}, absurd_b(e))
        case 1n+bp:
          le_succ_mono(ap, bp, e)

def rw(-A: Type, -P: A -> Type, -a: A, -b: A, e: {a == b : A}, p: P(b)) -> P(a):
  %Equal.sym(A, a, b, e) : P(_)
  p

def add_zero_right(a: Nat) -> {Nat.add(a, 0n) == a : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+ +p:
      rw(Nat, x => {1n+x == 1n+p : Nat}, Nat.add(p, 0n), p, add_zero_right(p), {==})

def add_succ_right(a: Nat, p: Nat) -> {Nat.add(a, 1n+p) == Nat.add(1n, Nat.add(a, p)) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+ap:
      rw(Nat, x => {1n+x == Nat.add(1n, Nat.add(1n+ap, p)) : Nat}, Nat.add(ap, 1n+p),
        Nat.add(1n, Nat.add(ap, p)), add_succ_right(ap, p), {==})

def le_add0_zero_hi(bp: Nat, e: {Nat.is_le(0n, 1n+bp) == True{} : Bool})
  -> {Nat.is_le(0n, Nat.add(1n+bp, 0n)) == True{} : Bool}:
  match bp:
    case 0n:
      e
    case 1n+pp:
      {==}

def le_add0(a: Nat, b: Nat, e: {Nat.is_le(a, b) == True{} : Bool})
  -> {Nat.is_le(Nat.add(a, 0n), Nat.add(b, 0n)) == True{} : Bool}:
  match a b:
    case 0n 0n:
      e
    case 0n 1n+bp:
      le_add0_zero_hi(bp, e)
    case 1n+ap 0n:
      exfalso({Nat.is_le(1n+ap, 0n) == True{} : Bool}, absurd_b(e))
    case 1n+ap 1n+bp:
      le_add0(ap, bp, e)

def le_add_right_succ(+a: Nat, +b: Nat, +cp: Nat, +ih: {Nat.is_le(Nat.add(a, cp), Nat.add(b, cp)) == True{} : Bool})
  -> {Nat.is_le(Nat.add(a, 1n+cp), Nat.add(b, 1n+cp)) == True{} : Bool}:
  rw(Nat, x => {Nat.is_le(x, Nat.add(b, 1n+cp)) == True{} : Bool}, Nat.add(a, 1n+cp),
    Nat.add(1n, Nat.add(a, cp)), add_succ_right(a, cp),
    rw(Nat, x => {Nat.is_le(Nat.add(1n, Nat.add(a, cp)), x) == True{} : Bool}, Nat.add(b, 1n+cp),
      Nat.add(1n, Nat.add(b, cp)), add_succ_right(b, cp),
      le_succ_mono(Nat.add(a, cp), Nat.add(b, cp), ih)))

def le_add_right(+a: Nat, +b: Nat, c: Nat, e: {Nat.is_le(a, b) == True{} : Bool})
  -> {Nat.is_le(Nat.add(a, c), Nat.add(b, c)) == True{} : Bool}:
  match c:
    case 0n:
      le_add0(a, b, e)
    case 1n+ +cp:
      le_add_right_succ(a, b, cp, le_add_right(a, b, cp, e))

def le_b_add_c(+b: Nat, c: Nat) -> {Nat.is_le(b, Nat.add(b, c)) == True{} : Bool}:
  match c:
    case 0n:
      rw(Nat, x => {Nat.is_le(b, x) == True{} : Bool}, Nat.add(b, 0n), b, add_zero_right(b), le_refl(b))
    case 1n+ +cp:
      le_trans(b, Nat.add(b, cp), Nat.add(b, 1n+cp), le_b_add_c(b, cp),
        rw(Nat, x => {Nat.is_le(Nat.add(b, cp), x) == True{} : Bool}, Nat.add(b, 1n+cp),
          Nat.add(1n, Nat.add(b, cp)), add_succ_right(b, cp), le_suc(Nat.add(b, cp))))

def le_add_tail(+a: Nat, +b: Nat, +c: Nat, e: {Nat.is_le(a, b) == True{} : Bool})
  -> {Nat.is_le(a, Nat.add(b, c)) == True{} : Bool}:
  le_trans(a, b, Nat.add(b, c), e, le_b_add_c(b, c))

# --- weight_ok on Nat ---------------------------------------------------------

def mul2(+a: Nat) -> Nat:
  Nat.mul(2n, a)

def mul3(+a: Nat) -> Nat:
  Nat.mul(3n, a)

def wok(+wl: Nat, +wh: Nat) -> Bool:
  Bool.and(Nat.is_le(wh, mul3(wl)), Nat.is_le(wl, mul3(wh)))

def wok_l(+wl: Nat, +wh: Nat, e: {wok(wl, wh) == True{} : Bool})
  -> {Nat.is_le(wh, mul3(wl)) == True{} : Bool}:
  and_l(Nat.is_le(wh, mul3(wl)), Nat.is_le(wl, mul3(wh)), e)

def wok_r(+wl: Nat, +wh: Nat, e: {wok(wl, wh) == True{} : Bool})
  -> {Nat.is_le(wl, mul3(wh)) == True{} : Bool}:
  and_r(Nat.is_le(wh, mul3(wl)), Nat.is_le(wl, mul3(wh)), e)

def wok_i(+wl: Nat, +wh: Nat, el: {Nat.is_le(wh, mul3(wl)) == True{} : Bool},
  er: {Nat.is_le(wl, mul3(wh)) == True{} : Bool}) -> {wok(wl, wh) == True{} : Bool}:
  and_i(Nat.is_le(wh, mul3(wl)), Nat.is_le(wl, mul3(wh)), el, er)


def add_0_l(+b: Nat) -> {Nat.add(0n, b) == b : Nat}:
  match b:
    case 0n:
      {==}
    case 1n+p:
      {==}

def add_cancel_l0(+b: Nat, +c: Nat, e: {Nat.add(0n, b) == Nat.add(0n, c) : Nat}) -> {b == c : Nat}:
  rw(Nat, x => {x == c : Nat}, b, Nat.add(0n, b), add_0_l(b),
    rw(Nat, x => {Nat.add(0n, b) == x : Nat}, c, Nat.add(0n, c), add_0_l(c), e))

def one_le_suc(+p: Nat) -> {Nat.is_le(1n, 1n+p) == True{} : Bool}:
  match p:
    case 0n:
      {==}
    case 1n+pp:
      le_trans(1n, 1n+pp, 1n+1n+pp, one_le_suc(pp),
        rw(Nat, x => {Nat.is_le(1n+pp, x) == True{} : Bool}, 1n+1n+pp, Nat.add(1n, 1n+pp),
          add_succ_right(1n, pp), le_suc(1n+pp)))


# Rotation / eq_add1 chain pending (#116): eq_add1_succ, le_one_of_add3,
# le_hl_mul3_wl (hh>1), le_wl_mul3_hl, rot_lo_single_inner/outer.
