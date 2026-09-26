# Nat order and linear-form lemmas for the OMap weight-balance proofs.
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

# --- sums ----------------------------------------------------------------------

def LE(a: Nat, b: Nat) -> Data:
  {Nat.is_le(a, b) == True{} : Bool}

def tr(-a: Nat, -b: Nat, -c: Nat, e1: {a == b : Nat}, e2: {b == c : Nat}) -> {a == c : Nat}:
  Equal.trans(Nat, a, b, c, e1, e2)

def sy(-a: Nat, -b: Nat, e: {a == b : Nat}) -> {b == a : Nat}:
  Equal.sym(Nat, a, b, e)

def cong_add(-a: Nat, -a2: Nat, -b: Nat, -b2: Nat, e1: {a == a2 : Nat}, e2: {b == b2 : Nat})
  -> {Nat.add(a, b) == Nat.add(a2, b2) : Nat}:
  %e1 : {Nat.add(a, b) == Nat.add(_, b2) : Nat}
  %e2 : {Nat.add(a, b) == Nat.add(a, _) : Nat}
  {==}

def add_assoc(a: Nat, +b: Nat, +c: Nat) -> {Nat.add(Nat.add(a, b), c) == Nat.add(a, Nat.add(b, c)) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_assoc(p, b, c) : {1n+Nat.add(Nat.add(p, b), c) == 1n+_ : Nat}
      {==}

def add_comm(a: Nat, +b: Nat) -> {Nat.add(a, b) == Nat.add(b, a) : Nat}:
  match a:
    case 0n:
      sy(Nat.add(b, 0n), b, add_zero_right(b))
    case 1n+ +p:
      %sy(Nat.add(b, 1n+p), Nat.add(1n, Nat.add(b, p)), add_succ_right(b, p)) : {1n+Nat.add(p, b) == _ : Nat}
      %add_comm(p, b) : {1n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

def swap3(+b: Nat, +c: Nat, +d: Nat) -> {Nat.add(b, Nat.add(c, d)) == Nat.add(c, Nat.add(b, d)) : Nat}:
  tr(Nat.add(b, Nat.add(c, d)), Nat.add(Nat.add(b, c), d), Nat.add(c, Nat.add(b, d)),
    sy(Nat.add(Nat.add(b, c), d), Nat.add(b, Nat.add(c, d)), add_assoc(b, c, d)),
    tr(Nat.add(Nat.add(b, c), d), Nat.add(Nat.add(c, b), d), Nat.add(c, Nat.add(b, d)),
      cong_add(Nat.add(b, c), Nat.add(c, b), d, d, add_comm(b, c), {==}),
      add_assoc(c, b, d)))

def swap4(+a: Nat, +b: Nat, +c: Nat, +d: Nat)
  -> {Nat.add(Nat.add(a, b), Nat.add(c, d)) == Nat.add(Nat.add(a, c), Nat.add(b, d)) : Nat}:
  tr(Nat.add(Nat.add(a, b), Nat.add(c, d)), Nat.add(a, Nat.add(b, Nat.add(c, d))),
    Nat.add(Nat.add(a, c), Nat.add(b, d)),
    add_assoc(a, b, Nat.add(c, d)),
    tr(Nat.add(a, Nat.add(b, Nat.add(c, d))), Nat.add(a, Nat.add(c, Nat.add(b, d))),
      Nat.add(Nat.add(a, c), Nat.add(b, d)),
      cong_add(a, a, Nat.add(b, Nat.add(c, d)), Nat.add(c, Nat.add(b, d)), {==}, swap3(b, c, d)),
      sy(Nat.add(Nat.add(a, c), Nat.add(b, d)), Nat.add(a, Nat.add(c, Nat.add(b, d))),
        add_assoc(a, c, Nat.add(b, d)))))

def mul_rdistr(c: Nat, +d: Nat, +v: Nat)
  -> {Nat.mul(Nat.add(c, d), v) == Nat.add(Nat.mul(c, v), Nat.mul(d, v)) : Nat}:
  match c:
    case 0n:
      {==}
    case 1n+ +p:
      tr(Nat.add(v, Nat.mul(Nat.add(p, d), v)), Nat.add(v, Nat.add(Nat.mul(p, v), Nat.mul(d, v))),
        Nat.add(Nat.add(v, Nat.mul(p, v)), Nat.mul(d, v)),
        cong_add(v, v, Nat.mul(Nat.add(p, d), v), Nat.add(Nat.mul(p, v), Nat.mul(d, v)), {==},
          mul_rdistr(p, d, v)),
        sy(Nat.add(Nat.add(v, Nat.mul(p, v)), Nat.mul(d, v)),
          Nat.add(v, Nat.add(Nat.mul(p, v), Nat.mul(d, v))), add_assoc(v, Nat.mul(p, v), Nat.mul(d, v))))

def step(+a: Nat, +b: Nat, +c: Nat, +d: Nat, -x: Nat, -y: Nat, e1: {Nat.add(a, c) == x : Nat},
  e2: {Nat.add(b, d) == y : Nat}) -> {Nat.add(Nat.add(a, b), Nat.add(c, d)) == Nat.add(x, y) : Nat}:
  tr(Nat.add(Nat.add(a, b), Nat.add(c, d)), Nat.add(Nat.add(a, c), Nat.add(b, d)), Nat.add(x, y),
    swap4(a, b, c, d), cong_add(Nat.add(a, c), x, Nat.add(b, d), y, e1, e2))

def dist(+a: Nat, +b: Nat, +v: Nat) -> {Nat.add(Nat.mul(a, v), Nat.mul(b, v)) == Nat.mul(Nat.add(a, b), v) : Nat}:
  sy(Nat.mul(Nat.add(a, b), v), Nat.add(Nat.mul(a, v), Nat.mul(b, v)), mul_rdistr(a, b, v))

# --- linear forms c0 + c1*v1 + c2*v2 + c3*v3 + c4*v4 ----------------------------

type Lin is Data:
  L{c0: Nat, c1: Nat, c2: Nat, c3: Nat, c4: Nat}

type Vs is Data:
  VS{v1: Nat, v2: Nat, v3: Nat, v4: Nat}

def F(p: Lin, v: Vs) -> Nat:
  match p v:
    case L{c0, c1, c2, c3, c4} VS{+v1, +v2, +v3, +v4}:
      Nat.add(c0, Nat.add(Nat.mul(c1, v1), Nat.add(Nat.mul(c2, v2),
        Nat.add(Nat.mul(c3, v3), Nat.mul(c4, v4)))))

def ladd(p: Lin, q: Lin) -> Lin:
  match p q:
    case L{a0, a1, a2, a3, a4} L{b0, b1, b2, b3, b4}:
      L{Nat.add(a0, b0), Nat.add(a1, b1), Nat.add(a2, b2), Nat.add(a3, b3), Nat.add(a4, b4)}

def lsc(k: Nat, +p: Lin) -> Lin:
  match k:
    case 0n:
      L{0n, 0n, 0n, 0n, 0n}
    case 1n+j:
      ladd(p, lsc(j, p))

def lsuc(p: Lin) -> Lin:
  match p:
    case L{a0, a1, a2, a3, a4}:
      L{1n+a0, a1, a2, a3, a4}

def lle(p: Lin, q: Lin) -> Bool:
  match p q:
    case L{a0, a1, a2, a3, a4} L{b0, b1, b2, b3, b4}:
      Bool.and(Nat.is_le(a0, b0), Bool.and(Nat.is_le(a1, b1), Bool.and(Nat.is_le(a2, b2),
        Bool.and(Nat.is_le(a3, b3), Nat.is_le(a4, b4)))))

def F_add(p: Lin, q: Lin, v: Vs) -> {Nat.add(F(p, v), F(q, v)) == F(ladd(p, q), v) : Nat}:
  match p q v:
    case L{+a0, +a1, +a2, +a3, +a4} L{+b0, +b1, +b2, +b3, +b4} VS{+v1, +v2, +v3, +v4}:
      +x1 = Nat.mul(a1, v1)
      +x2 = Nat.mul(a2, v2)
      +x3 = Nat.mul(a3, v3)
      +x4 = Nat.mul(a4, v4)
      +y1 = Nat.mul(b1, v1)
      +y2 = Nat.mul(b2, v2)
      +y3 = Nat.mul(b3, v3)
      +y4 = Nat.mul(b4, v4)
      +z1 = Nat.mul(Nat.add(a1, b1), v1)
      +z2 = Nat.mul(Nat.add(a2, b2), v2)
      +z3 = Nat.mul(Nat.add(a3, b3), v3)
      +z4 = Nat.mul(Nat.add(a4, b4), v4)
      step(a0, Nat.add(x1, Nat.add(x2, Nat.add(x3, x4))), b0, Nat.add(y1, Nat.add(y2, Nat.add(y3, y4))),
        Nat.add(a0, b0), Nat.add(z1, Nat.add(z2, Nat.add(z3, z4))), {==},
        step(x1, Nat.add(x2, Nat.add(x3, x4)), y1, Nat.add(y2, Nat.add(y3, y4)), z1,
          Nat.add(z2, Nat.add(z3, z4)), dist(a1, b1, v1),
          step(x2, Nat.add(x3, x4), y2, Nat.add(y3, y4), z2, Nat.add(z3, z4), dist(a2, b2, v2),
            step(x3, x4, y3, y4, z3, z4, dist(a3, b3, v3), dist(a4, b4, v4)))))

def le_add_left(a: Nat, -c: Nat, -d: Nat, e: LE(c, d)) -> LE(Nat.add(a, c), Nat.add(a, d)):
  match a:
    case 0n:
      e
    case 1n+p:
      le_add_left(p, c, d, e)

def le_add_mono(+a: Nat, +b: Nat, +c: Nat, +d: Nat, e1: LE(a, b), e2: LE(c, d))
  -> LE(Nat.add(a, c), Nat.add(b, d)):
  le_trans(Nat.add(a, c), Nat.add(b, c), Nat.add(b, d), le_add_right(a, b, c, e1),
    le_add_left(b, c, d, e2))

def comb(+p: Lin, +q: Lin, +r: Lin, +s: Lin, +v: Vs, e1: LE(F(p, v), F(q, v)), e2: LE(F(r, v), F(s, v)))
  -> LE(F(ladd(p, r), v), F(ladd(q, s), v)):
  %F_add(p, r, v) : LE(_, F(ladd(q, s), v))
  %F_add(q, s, v) : LE(Nat.add(F(p, v), F(r, v)), _)
  le_add_mono(F(p, v), F(q, v), F(r, v), F(s, v), e1, e2)

def scale(k: Nat, +p: Lin, +q: Lin, +v: Vs, +e: LE(F(p, v), F(q, v)))
  -> LE(F(lsc(k, p), v), F(lsc(k, q), v)):
  match k:
    case 0n:
      le_refl(F(L{0n, 0n, 0n, 0n, 0n}, v))
    case 1n+ +j:
      comb(p, q, lsc(j, p), lsc(j, q), v, e, scale(j, p, q, v, e))

def le_mul_mono(c: Nat, d: Nat, +v: Nat, e: LE(c, d)) -> LE(Nat.mul(c, v), Nat.mul(d, v)):
  match c d:
    case 0n d:
      le_zero(Nat.mul(d, v))
    case 1n+cp 0n:
      exfalso(LE(Nat.mul(1n+cp, v), 0n), absurd_b(e))
    case 1n+cp 1n+dp:
      le_add_left(v, Nat.mul(cp, v), Nat.mul(dp, v), le_mul_mono(cp, dp, v, e))

def and5_1(+a: Bool, +b: Bool, +c: Bool, +d: Bool, +f: Bool,
  e: {Bool.and(a, Bool.and(b, Bool.and(c, Bool.and(d, f)))) == True{} : Bool}) -> {a == True{} : Bool}:
  and_l(a, Bool.and(b, Bool.and(c, Bool.and(d, f))), e)

def and5_r(+a: Bool, +b: Bool, +c: Bool, +d: Bool, +f: Bool,
  e: {Bool.and(a, Bool.and(b, Bool.and(c, Bool.and(d, f)))) == True{} : Bool})
  -> {Bool.and(b, Bool.and(c, Bool.and(d, f))) == True{} : Bool}:
  and_r(a, Bool.and(b, Bool.and(c, Bool.and(d, f))), e)

def F_mono(p: Lin, q: Lin, v: Vs, +h: {lle(p, q) == True{} : Bool}) -> LE(F(p, v), F(q, v)):
  match p q v:
    case L{+a0, +a1, +a2, +a3, +a4} L{+b0, +b1, +b2, +b3, +b4} VS{+v1, +v2, +v3, +v4}:
      +l0 = Nat.is_le(a0, b0)
      +l1 = Nat.is_le(a1, b1)
      +l2 = Nat.is_le(a2, b2)
      +l3 = Nat.is_le(a3, b3)
      +l4 = Nat.is_le(a4, b4)
      +r1 = and5_r(l0, l1, l2, l3, l4, h)
      +r2 = and_r(l1, Bool.and(l2, Bool.and(l3, l4)), r1)
      +r3 = and_r(l2, Bool.and(l3, l4), r2)
      +x1 = Nat.mul(a1, v1)
      +x2 = Nat.mul(a2, v2)
      +x3 = Nat.mul(a3, v3)
      +x4 = Nat.mul(a4, v4)
      +y1 = Nat.mul(b1, v1)
      +y2 = Nat.mul(b2, v2)
      +y3 = Nat.mul(b3, v3)
      +y4 = Nat.mul(b4, v4)
      le_add_mono(a0, b0, Nat.add(x1, Nat.add(x2, Nat.add(x3, x4))), Nat.add(y1, Nat.add(y2, Nat.add(y3, y4))),
        and5_1(l0, l1, l2, l3, l4, h),
        le_add_mono(x1, y1, Nat.add(x2, Nat.add(x3, x4)), Nat.add(y2, Nat.add(y3, y4)),
          le_mul_mono(a1, b1, v1, and_l(l1, Bool.and(l2, Bool.and(l3, l4)), r1)),
          le_add_mono(x2, y2, Nat.add(x3, x4), Nat.add(y3, y4),
            le_mul_mono(a2, b2, v2, and_l(l2, Bool.and(l3, l4), r2)),
            le_add_mono(x3, y3, x4, y4, le_mul_mono(a3, b3, v3, and_l(l3, l4, r3)),
              le_mul_mono(a4, b4, v4, and_r(l3, l4, r3))))))

def le_succ_false(x: Nat, e: LE(1n+x, x)) -> Empty:
  match x:
    case 0n:
      absurd_b(e)
    case 1n+p:
      le_succ_false(p, e)

# A combined hypothesis F(p) <= F(q) with q < p term by term is false.
def contra(+p: Lin, q: Lin, v: Vs, e: LE(F(p, v), F(q, v)), h: {lle(lsuc(q), p) == True{} : Bool}) -> Empty:
  match q v:
    case L{+b0, +b1, +b2, +b3, +b4} VS{+v1, +v2, +v3, +v4}:
      +vs = {VS{v1, v2, v3, v4} : Vs}
      +fq = F(L{b0, b1, b2, b3, b4}, vs)
      le_succ_false(fq, le_trans(1n+fq, F(p, vs), fq, F_mono(L{1n+b0, b1, b2, b3, b4}, p, vs, h), e))

# --- from terms to linear forms ------------------------------------------------

def F0(v: Vs) -> {F(L{0n, 0n, 0n, 0n, 0n}, v) == 0n : Nat}:
  match v:
    case VS{v1, v2, v3, v4}:
      {==}

def cv_c(+n: Nat, v: Vs) -> {n == F(L{n, 0n, 0n, 0n, 0n}, v) : Nat}:
  match v:
    case VS{v1, v2, v3, v4}:
      sy(Nat.add(n, 0n), n, add_zero_right(n))

def az2(+a: Nat) -> {a == Nat.add(Nat.add(a, 0n), 0n) : Nat}:
  sy(Nat.add(Nat.add(a, 0n), 0n), a,
    tr(Nat.add(Nat.add(a, 0n), 0n), Nat.add(a, 0n), a, add_zero_right(Nat.add(a, 0n)), add_zero_right(a)))

def cv_1(+a: Nat, +b: Nat, +c: Nat, +d: Nat) -> {a == F(L{0n, 1n, 0n, 0n, 0n}, VS{a, b, c, d}) : Nat}:
  az2(a)

def cv_2(+a: Nat, +b: Nat, +c: Nat, +d: Nat) -> {b == F(L{0n, 0n, 1n, 0n, 0n}, VS{a, b, c, d}) : Nat}:
  az2(b)

def cv_3(+a: Nat, +b: Nat, +c: Nat, +d: Nat) -> {c == F(L{0n, 0n, 0n, 1n, 0n}, VS{a, b, c, d}) : Nat}:
  az2(c)

def cv_4(+a: Nat, +b: Nat, +c: Nat, +d: Nat) -> {d == F(L{0n, 0n, 0n, 0n, 1n}, VS{a, b, c, d}) : Nat}:
  sy(Nat.add(d, 0n), d, add_zero_right(d))

def cv_add(-A: Nat, -B: Nat, +p: Lin, +q: Lin, +v: Vs, eA: {A == F(p, v) : Nat}, eB: {B == F(q, v) : Nat})
  -> {Nat.add(A, B) == F(ladd(p, q), v) : Nat}:
  tr(Nat.add(A, B), Nat.add(F(p, v), F(q, v)), F(ladd(p, q), v),
    cong_add(A, F(p, v), B, F(q, v), eA, eB), F_add(p, q, v))

def cv_mul(k: Nat, +A: Nat, +p: Lin, +v: Vs, +eA: {A == F(p, v) : Nat})
  -> {Nat.mul(k, A) == F(lsc(k, p), v) : Nat}:
  match k:
    case 0n:
      sy(F(L{0n, 0n, 0n, 0n, 0n}, v), 0n, F0(v))
    case 1n+ +j:
      cv_add(A, Nat.mul(j, A), p, lsc(j, p), v, eA, cv_mul(j, A, p, v, eA))

def cvle(-A: Nat, -B: Nat, -p: Lin, -q: Lin, -v: Vs, eA: {A == F(p, v) : Nat}, eB: {B == F(q, v) : Nat},
  h: LE(A, B)) -> LE(F(p, v), F(q, v)):
  %eA : LE(_, F(q, v))
  %eB : LE(A, _)
  h

# --- from comparisons to <= ----------------------------------------------------

def absurd_tf(e: {True{} == False{} : Bool}) -> Empty:
  absurd_b(Equal.sym(Bool, True{}, False{}, e))

def gt_le(a: Nat, b: Nat, e: {Nat.is_gt(a, b) == True{} : Bool}) -> LE(1n+b, a):
  match a b:
    case 0n 0n:
      exfalso(LE(1n, 0n), absurd_b(e))
    case 0n 1n+bp:
      exfalso(LE(1n+1n+bp, 0n), absurd_b(e))
    case 1n+ap 0n:
      le_zero(ap)
    case 1n+ap 1n+bp:
      gt_le(ap, bp, e)

def ngt_le(a: Nat, b: Nat, e: {Nat.is_gt(a, b) == False{} : Bool}) -> LE(a, b):
  match a b:
    case 0n b:
      le_zero(b)
    case 1n+ap 0n:
      exfalso(LE(1n+ap, 0n), absurd_tf(e))
    case 1n+ap 1n+bp:
      ngt_le(ap, bp, e)

def lt_le(a: Nat, b: Nat, e: {Nat.is_lt(a, b) == True{} : Bool}) -> LE(1n+a, b):
  match a b:
    case 0n 0n:
      exfalso(LE(1n, 0n), absurd_b(e))
    case 0n 1n+bp:
      le_zero(bp)
    case 1n+ap 0n:
      exfalso(LE(1n+1n+ap, 0n), absurd_b(e))
    case 1n+ap 1n+bp:
      lt_le(ap, bp, e)

def nlt_le(a: Nat, b: Nat, e: {Nat.is_lt(a, b) == False{} : Bool}) -> LE(b, a):
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+bp:
      exfalso(LE(1n+bp, 0n), absurd_tf(e))
    case 1n+ap 0n:
      le_zero(1n+ap)
    case 1n+ap 1n+bp:
      nlt_le(ap, bp, e)

# Proves x <= y from a refutation of y < x.
def by_contra(x: Nat, y: Nat, k: LE(1n+y, x) -> Empty) -> LE(x, y):
  match x y:
    case 0n y:
      le_zero(y)
    case 1n+xp 0n:
      exfalso(LE(1n+xp, 0n), k(le_zero(xp)))
    case 1n+xp 1n+yp:
      by_contra(xp, yp, k)

# --- weight-balance arithmetic -------------------------------------------------
# Machine-written certificates. Each lemma refutes its negated goal: it adds the
# hypotheses as linear forms, each times a small factor, and contra shows the
# sum is false. rls/rld: single/double rotation toward lo; rhs/rhd: toward hi.

def alm(+wl: Nat, +wh: Nat) -> Bool:
  Bool.and(Nat.is_le(wh, Nat.add(3n, mul3(wl))), Nat.is_le(wl, Nat.add(3n, mul3(wh))))

def near(+a: Nat, +b: Nat) -> Bool:
  Bool.and(Nat.is_le(a, 1n+b), Nat.is_le(b, 1n+a))

def rls.c0a.k(+l: Nat, +a: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, l), a), h4: LE(Nat.add(a, b), Nat.add(3n, Nat.mul(3n, l))), hs: LE(1n+a, Nat.mul(2n, b)), pl: LE(1n, l)) -> Empty:
  +v = {VS{l, a, b, 0n} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, l), a, L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, a, b, 0n))),
    cv_2(l, a, b, 0n), ng)
  +f_h4 = cvle(Nat.add(a, b), Nat.add(3n, Nat.mul(3n, l)), L{0n, 0n, 1n, 1n, 0n}, L{3n, 3n, 0n, 0n, 0n}, v,
    cv_add(a, b, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, a, b, 0n), cv_3(l, a, b, 0n)),
    cv_add(3n, Nat.mul(3n, l), L{3n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(3n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, a, b, 0n))), h4)
  +f_hs = cvle(1n+a, Nat.mul(2n, b), L{1n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 2n, 0n}, v,
    cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_c(1n, v), cv_2(l, a, b, 0n)),
    cv_mul(2n, b, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, a, b, 0n)), hs)
  +f_pl = cvle(1n, l, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_c(1n, v),
    cv_1(l, a, b, 0n), pl)
  contra(L{7n, 9n, 3n, 2n, 0n}, L{6n, 9n, 3n, 2n, 0n}, v,
    comb(L{3n, 9n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, L{4n, 0n, 3n, 2n, 0n}, L{6n, 9n, 0n, 2n, 0n}, v, scale(3n, L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, f_ng),
    comb(L{0n, 0n, 2n, 2n, 0n}, L{6n, 6n, 0n, 0n, 0n}, L{4n, 0n, 1n, 0n, 0n}, L{0n, 3n, 0n, 2n, 0n}, v, scale(2n, L{0n, 0n, 1n, 1n, 0n}, L{3n, 3n, 0n, 0n, 0n}, v, f_h4),
    comb(L{1n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 2n, 0n}, L{3n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, f_hs,
    scale(3n, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, f_pl)))), {==})
def rls.c0a(+l: Nat, +a: Nat, +b: Nat, h4: LE(Nat.add(a, b), Nat.add(3n, Nat.mul(3n, l))), hs: LE(1n+a, Nat.mul(2n, b)), pl: LE(1n, l)) -> LE(a, Nat.mul(3n, l)):
  by_contra(a, Nat.mul(3n, l), ng => rls.c0a.k(l, a, b, ng, h4, hs, pl))

def rls.c0b.k(+l: Nat, +a: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, a), l), h2: LE(b, Nat.mul(3n, a)), h3: LE(1n+Nat.mul(3n, l), Nat.add(a, b))) -> Empty:
  +v = {VS{l, a, b, 0n} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, a), l, L{1n, 0n, 3n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, a), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, a, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(l, a, b, 0n))),
    cv_1(l, a, b, 0n), ng)
  +f_h2 = cvle(b, Nat.mul(3n, a), L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v,
    cv_3(l, a, b, 0n),
    cv_mul(3n, a, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(l, a, b, 0n)), h2)
  +f_h3 = cvle(1n+Nat.mul(3n, l), Nat.add(a, b), L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 0n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, a, b, 0n))),
    cv_add(a, b, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, a, b, 0n), cv_3(l, a, b, 0n)), h3)
  contra(L{3n, 3n, 6n, 1n, 0n}, L{0n, 2n, 4n, 1n, 0n}, v,
    comb(L{2n, 0n, 6n, 0n, 0n}, L{0n, 2n, 0n, 0n, 0n}, L{1n, 3n, 0n, 1n, 0n}, L{0n, 0n, 4n, 1n, 0n}, v, scale(2n, L{1n, 0n, 3n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, f_ng),
    comb(L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 0n}, v, f_h2,
    f_h3)), {==})
def rls.c0b(+l: Nat, +a: Nat, +b: Nat, h2: LE(b, Nat.mul(3n, a)), h3: LE(1n+Nat.mul(3n, l), Nat.add(a, b))) -> LE(l, Nat.mul(3n, a)):
  by_contra(l, Nat.mul(3n, a), ng => rls.c0b.k(l, a, b, ng, h2, h3))

def rls.w0(+l: Nat, +a: Nat, +b: Nat, +h1: LE(a, Nat.mul(3n, b)), +h2: LE(b, Nat.mul(3n, a)), +h3: LE(1n+Nat.mul(3n, l), Nat.add(a, b)), +h4: LE(Nat.add(a, b), Nat.add(3n, Nat.mul(3n, l))), +hs: LE(1n+a, Nat.mul(2n, b)), +pl: LE(1n, l), +pa: LE(1n, a), +pb: LE(1n, b)) -> {wok(l, a) == True{} : Bool}:
  and_i(Nat.is_le(a, Nat.mul(3n, l)), Nat.is_le(l, Nat.mul(3n, a)),
    rls.c0a(l, a, b, h4, hs, pl),
    rls.c0b(l, a, b, h2, h3))

def rls.c1a.k(+l: Nat, +a: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, Nat.add(l, a)), b), h2: LE(b, Nat.mul(3n, a))) -> Empty:
  +v = {VS{l, a, b, 0n} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, Nat.add(l, a)), b, L{1n, 3n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v,
    cv_add(1n, Nat.mul(3n, Nat.add(l, a)), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 3n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, Nat.add(l, a), L{0n, 1n, 1n, 0n, 0n}, v, cv_add(l, a, L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_1(l, a, b, 0n), cv_2(l, a, b, 0n)))),
    cv_3(l, a, b, 0n), ng)
  +f_h2 = cvle(b, Nat.mul(3n, a), L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v,
    cv_3(l, a, b, 0n),
    cv_mul(3n, a, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(l, a, b, 0n)), h2)
  contra(L{1n, 3n, 3n, 1n, 0n}, L{0n, 0n, 3n, 1n, 0n}, v,
    comb(L{1n, 3n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, f_ng,
    f_h2), {==})
def rls.c1a(+l: Nat, +a: Nat, +b: Nat, h2: LE(b, Nat.mul(3n, a))) -> LE(b, Nat.mul(3n, Nat.add(l, a))):
  by_contra(b, Nat.mul(3n, Nat.add(l, a)), ng => rls.c1a.k(l, a, b, ng, h2))

def rls.c1b.k(+l: Nat, +a: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, b), Nat.add(l, a)), h3: LE(1n+Nat.mul(3n, l), Nat.add(a, b)), hs: LE(1n+a, Nat.mul(2n, b))) -> Empty:
  +v = {VS{l, a, b, 0n} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, b), Nat.add(l, a), L{1n, 0n, 0n, 3n, 0n}, L{0n, 1n, 1n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, b), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v, cv_c(1n, v), cv_mul(3n, b, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, a, b, 0n))),
    cv_add(l, a, L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_1(l, a, b, 0n), cv_2(l, a, b, 0n)), ng)
  +f_h3 = cvle(1n+Nat.mul(3n, l), Nat.add(a, b), L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 0n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, a, b, 0n))),
    cv_add(a, b, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, a, b, 0n), cv_3(l, a, b, 0n)), h3)
  +f_hs = cvle(1n+a, Nat.mul(2n, b), L{1n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 2n, 0n}, v,
    cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_c(1n, v), cv_2(l, a, b, 0n)),
    cv_mul(2n, b, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, a, b, 0n)), hs)
  contra(L{8n, 3n, 4n, 9n, 0n}, L{0n, 3n, 4n, 9n, 0n}, v,
    comb(L{3n, 0n, 0n, 9n, 0n}, L{0n, 3n, 3n, 0n, 0n}, L{5n, 3n, 4n, 0n, 0n}, L{0n, 0n, 1n, 9n, 0n}, v, scale(3n, L{1n, 0n, 0n, 3n, 0n}, L{0n, 1n, 1n, 0n, 0n}, v, f_ng),
    comb(L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 0n}, L{4n, 0n, 4n, 0n, 0n}, L{0n, 0n, 0n, 8n, 0n}, v, f_h3,
    scale(4n, L{1n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 2n, 0n}, v, f_hs))), {==})
def rls.c1b(+l: Nat, +a: Nat, +b: Nat, h3: LE(1n+Nat.mul(3n, l), Nat.add(a, b)), hs: LE(1n+a, Nat.mul(2n, b))) -> LE(Nat.add(l, a), Nat.mul(3n, b)):
  by_contra(Nat.add(l, a), Nat.mul(3n, b), ng => rls.c1b.k(l, a, b, ng, h3, hs))

def rls.w1(+l: Nat, +a: Nat, +b: Nat, +h1: LE(a, Nat.mul(3n, b)), +h2: LE(b, Nat.mul(3n, a)), +h3: LE(1n+Nat.mul(3n, l), Nat.add(a, b)), +h4: LE(Nat.add(a, b), Nat.add(3n, Nat.mul(3n, l))), +hs: LE(1n+a, Nat.mul(2n, b)), +pl: LE(1n, l), +pa: LE(1n, a), +pb: LE(1n, b)) -> {wok(Nat.add(l, a), b) == True{} : Bool}:
  and_i(Nat.is_le(b, Nat.mul(3n, Nat.add(l, a))), Nat.is_le(Nat.add(l, a), Nat.mul(3n, b)),
    rls.c1a(l, a, b, h2),
    rls.c1b(l, a, b, h3, hs))

def rhs.c0a.k(+l: Nat, +a: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, b), Nat.add(a, l)), h3: LE(1n+Nat.mul(3n, l), Nat.add(b, a)), hs: LE(1n+a, Nat.mul(2n, b))) -> Empty:
  +v = {VS{l, a, b, 0n} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, b), Nat.add(a, l), L{1n, 0n, 0n, 3n, 0n}, L{0n, 1n, 1n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, b), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v, cv_c(1n, v), cv_mul(3n, b, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, a, b, 0n))),
    cv_add(a, l, L{0n, 0n, 1n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_2(l, a, b, 0n), cv_1(l, a, b, 0n)), ng)
  +f_h3 = cvle(1n+Nat.mul(3n, l), Nat.add(b, a), L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 0n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, a, b, 0n))),
    cv_add(b, a, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, a, b, 0n), cv_2(l, a, b, 0n)), h3)
  +f_hs = cvle(1n+a, Nat.mul(2n, b), L{1n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 2n, 0n}, v,
    cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_c(1n, v), cv_2(l, a, b, 0n)),
    cv_mul(2n, b, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, a, b, 0n)), hs)
  contra(L{8n, 3n, 4n, 9n, 0n}, L{0n, 3n, 4n, 9n, 0n}, v,
    comb(L{3n, 0n, 0n, 9n, 0n}, L{0n, 3n, 3n, 0n, 0n}, L{5n, 3n, 4n, 0n, 0n}, L{0n, 0n, 1n, 9n, 0n}, v, scale(3n, L{1n, 0n, 0n, 3n, 0n}, L{0n, 1n, 1n, 0n, 0n}, v, f_ng),
    comb(L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 0n}, L{4n, 0n, 4n, 0n, 0n}, L{0n, 0n, 0n, 8n, 0n}, v, f_h3,
    scale(4n, L{1n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 2n, 0n}, v, f_hs))), {==})
def rhs.c0a(+l: Nat, +a: Nat, +b: Nat, h3: LE(1n+Nat.mul(3n, l), Nat.add(b, a)), hs: LE(1n+a, Nat.mul(2n, b))) -> LE(Nat.add(a, l), Nat.mul(3n, b)):
  by_contra(Nat.add(a, l), Nat.mul(3n, b), ng => rhs.c0a.k(l, a, b, ng, h3, hs))

def rhs.c0b.k(+l: Nat, +a: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, Nat.add(a, l)), b), h2: LE(b, Nat.mul(3n, a))) -> Empty:
  +v = {VS{l, a, b, 0n} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, Nat.add(a, l)), b, L{1n, 3n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v,
    cv_add(1n, Nat.mul(3n, Nat.add(a, l)), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 3n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, Nat.add(a, l), L{0n, 1n, 1n, 0n, 0n}, v, cv_add(a, l, L{0n, 0n, 1n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_2(l, a, b, 0n), cv_1(l, a, b, 0n)))),
    cv_3(l, a, b, 0n), ng)
  +f_h2 = cvle(b, Nat.mul(3n, a), L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v,
    cv_3(l, a, b, 0n),
    cv_mul(3n, a, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(l, a, b, 0n)), h2)
  contra(L{1n, 3n, 3n, 1n, 0n}, L{0n, 0n, 3n, 1n, 0n}, v,
    comb(L{1n, 3n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, f_ng,
    f_h2), {==})
def rhs.c0b(+l: Nat, +a: Nat, +b: Nat, h2: LE(b, Nat.mul(3n, a))) -> LE(b, Nat.mul(3n, Nat.add(a, l))):
  by_contra(b, Nat.mul(3n, Nat.add(a, l)), ng => rhs.c0b.k(l, a, b, ng, h2))

def rhs.w0(+l: Nat, +a: Nat, +b: Nat, +h1: LE(a, Nat.mul(3n, b)), +h2: LE(b, Nat.mul(3n, a)), +h3: LE(1n+Nat.mul(3n, l), Nat.add(b, a)), +h4: LE(Nat.add(b, a), Nat.add(3n, Nat.mul(3n, l))), +hs: LE(1n+a, Nat.mul(2n, b)), +pl: LE(1n, l), +pa: LE(1n, a), +pb: LE(1n, b)) -> {wok(b, Nat.add(a, l)) == True{} : Bool}:
  and_i(Nat.is_le(Nat.add(a, l), Nat.mul(3n, b)), Nat.is_le(b, Nat.mul(3n, Nat.add(a, l))),
    rhs.c0a(l, a, b, h3, hs),
    rhs.c0b(l, a, b, h2))

def rhs.c1a.k(+l: Nat, +a: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, a), l), h2: LE(b, Nat.mul(3n, a)), h3: LE(1n+Nat.mul(3n, l), Nat.add(b, a))) -> Empty:
  +v = {VS{l, a, b, 0n} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, a), l, L{1n, 0n, 3n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, a), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, a, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(l, a, b, 0n))),
    cv_1(l, a, b, 0n), ng)
  +f_h2 = cvle(b, Nat.mul(3n, a), L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v,
    cv_3(l, a, b, 0n),
    cv_mul(3n, a, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(l, a, b, 0n)), h2)
  +f_h3 = cvle(1n+Nat.mul(3n, l), Nat.add(b, a), L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 0n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, a, b, 0n))),
    cv_add(b, a, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, a, b, 0n), cv_2(l, a, b, 0n)), h3)
  contra(L{3n, 3n, 6n, 1n, 0n}, L{0n, 2n, 4n, 1n, 0n}, v,
    comb(L{2n, 0n, 6n, 0n, 0n}, L{0n, 2n, 0n, 0n, 0n}, L{1n, 3n, 0n, 1n, 0n}, L{0n, 0n, 4n, 1n, 0n}, v, scale(2n, L{1n, 0n, 3n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, f_ng),
    comb(L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 0n}, v, f_h2,
    f_h3)), {==})
def rhs.c1a(+l: Nat, +a: Nat, +b: Nat, h2: LE(b, Nat.mul(3n, a)), h3: LE(1n+Nat.mul(3n, l), Nat.add(b, a))) -> LE(l, Nat.mul(3n, a)):
  by_contra(l, Nat.mul(3n, a), ng => rhs.c1a.k(l, a, b, ng, h2, h3))

def rhs.c1b.k(+l: Nat, +a: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, l), a), h4: LE(Nat.add(b, a), Nat.add(3n, Nat.mul(3n, l))), hs: LE(1n+a, Nat.mul(2n, b)), pl: LE(1n, l)) -> Empty:
  +v = {VS{l, a, b, 0n} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, l), a, L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, a, b, 0n))),
    cv_2(l, a, b, 0n), ng)
  +f_h4 = cvle(Nat.add(b, a), Nat.add(3n, Nat.mul(3n, l)), L{0n, 0n, 1n, 1n, 0n}, L{3n, 3n, 0n, 0n, 0n}, v,
    cv_add(b, a, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, a, b, 0n), cv_2(l, a, b, 0n)),
    cv_add(3n, Nat.mul(3n, l), L{3n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(3n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, a, b, 0n))), h4)
  +f_hs = cvle(1n+a, Nat.mul(2n, b), L{1n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 2n, 0n}, v,
    cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_c(1n, v), cv_2(l, a, b, 0n)),
    cv_mul(2n, b, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, a, b, 0n)), hs)
  +f_pl = cvle(1n, l, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_c(1n, v),
    cv_1(l, a, b, 0n), pl)
  contra(L{7n, 9n, 3n, 2n, 0n}, L{6n, 9n, 3n, 2n, 0n}, v,
    comb(L{3n, 9n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, L{4n, 0n, 3n, 2n, 0n}, L{6n, 9n, 0n, 2n, 0n}, v, scale(3n, L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, f_ng),
    comb(L{0n, 0n, 2n, 2n, 0n}, L{6n, 6n, 0n, 0n, 0n}, L{4n, 0n, 1n, 0n, 0n}, L{0n, 3n, 0n, 2n, 0n}, v, scale(2n, L{0n, 0n, 1n, 1n, 0n}, L{3n, 3n, 0n, 0n, 0n}, v, f_h4),
    comb(L{1n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 2n, 0n}, L{3n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, f_hs,
    scale(3n, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, f_pl)))), {==})
def rhs.c1b(+l: Nat, +a: Nat, +b: Nat, h4: LE(Nat.add(b, a), Nat.add(3n, Nat.mul(3n, l))), hs: LE(1n+a, Nat.mul(2n, b)), pl: LE(1n, l)) -> LE(a, Nat.mul(3n, l)):
  by_contra(a, Nat.mul(3n, l), ng => rhs.c1b.k(l, a, b, ng, h4, hs, pl))

def rhs.w1(+l: Nat, +a: Nat, +b: Nat, +h1: LE(a, Nat.mul(3n, b)), +h2: LE(b, Nat.mul(3n, a)), +h3: LE(1n+Nat.mul(3n, l), Nat.add(b, a)), +h4: LE(Nat.add(b, a), Nat.add(3n, Nat.mul(3n, l))), +hs: LE(1n+a, Nat.mul(2n, b)), +pl: LE(1n, l), +pa: LE(1n, a), +pb: LE(1n, b)) -> {wok(a, l) == True{} : Bool}:
  and_i(Nat.is_le(l, Nat.mul(3n, a)), Nat.is_le(a, Nat.mul(3n, l)),
    rhs.c1a(l, a, b, h2, h3),
    rhs.c1b(l, a, b, h4, hs, pl))

def rld.c0a.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, Nat.add(l, x)), Nat.add(y, b)), h4: LE(Nat.add(Nat.add(x, y), b), Nat.add(3n, Nat.mul(3n, l))), px: LE(1n, x)) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, Nat.add(l, x)), Nat.add(y, b), L{1n, 3n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 1n}, v,
    cv_add(1n, Nat.mul(3n, Nat.add(l, x)), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 3n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, Nat.add(l, x), L{0n, 1n, 1n, 0n, 0n}, v, cv_add(l, x, L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_1(l, x, y, b), cv_2(l, x, y, b)))),
    cv_add(y, b, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 0n, 0n, 1n}, v, cv_3(l, x, y, b), cv_4(l, x, y, b)), ng)
  +f_h4 = cvle(Nat.add(Nat.add(x, y), b), Nat.add(3n, Nat.mul(3n, l)), L{0n, 0n, 1n, 1n, 1n}, L{3n, 3n, 0n, 0n, 0n}, v,
    cv_add(Nat.add(x, y), b, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 1n}, v, cv_add(x, y, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, x, y, b), cv_3(l, x, y, b)), cv_4(l, x, y, b)),
    cv_add(3n, Nat.mul(3n, l), L{3n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(3n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, x, y, b))), h4)
  +f_px = cvle(1n, x, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v,
    cv_c(1n, v),
    cv_2(l, x, y, b), px)
  contra(L{4n, 3n, 4n, 1n, 1n}, L{3n, 3n, 3n, 1n, 1n}, v,
    comb(L{1n, 3n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 1n}, L{3n, 0n, 1n, 1n, 1n}, L{3n, 3n, 3n, 0n, 0n}, v, f_ng,
    comb(L{0n, 0n, 1n, 1n, 1n}, L{3n, 3n, 0n, 0n, 0n}, L{3n, 0n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, f_h4,
    scale(3n, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, f_px))), {==})
def rld.c0a(+l: Nat, +x: Nat, +y: Nat, +b: Nat, h4: LE(Nat.add(Nat.add(x, y), b), Nat.add(3n, Nat.mul(3n, l))), px: LE(1n, x)) -> LE(Nat.add(y, b), Nat.mul(3n, Nat.add(l, x))):
  by_contra(Nat.add(y, b), Nat.mul(3n, Nat.add(l, x)), ng => rld.c0a.k(l, x, y, b, ng, h4, px))

def rld.c0b.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, Nat.add(y, b)), Nat.add(l, x)), h1: LE(Nat.add(x, y), Nat.mul(3n, b)), h3: LE(1n+Nat.mul(3n, l), Nat.add(Nat.add(x, y), b)), h5: LE(x, Nat.mul(3n, y))) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, Nat.add(y, b)), Nat.add(l, x), L{1n, 0n, 0n, 3n, 3n}, L{0n, 1n, 1n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, Nat.add(y, b)), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 3n, 3n}, v, cv_c(1n, v), cv_mul(3n, Nat.add(y, b), L{0n, 0n, 0n, 1n, 1n}, v, cv_add(y, b, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 0n, 0n, 1n}, v, cv_3(l, x, y, b), cv_4(l, x, y, b)))),
    cv_add(l, x, L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_1(l, x, y, b), cv_2(l, x, y, b)), ng)
  +f_h1 = cvle(Nat.add(x, y), Nat.mul(3n, b), L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, v,
    cv_add(x, y, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, x, y, b), cv_3(l, x, y, b)),
    cv_mul(3n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b)), h1)
  +f_h3 = cvle(1n+Nat.mul(3n, l), Nat.add(Nat.add(x, y), b), L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 1n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, x, y, b))),
    cv_add(Nat.add(x, y), b, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 1n}, v, cv_add(x, y, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, x, y, b), cv_3(l, x, y, b)), cv_4(l, x, y, b)), h3)
  +f_h5 = cvle(x, Nat.mul(3n, y), L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v,
    cv_2(l, x, y, b),
    cv_mul(3n, y, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, x, y, b)), h5)
  contra(L{3n, 3n, 3n, 7n, 6n}, L{0n, 2n, 3n, 7n, 4n}, v,
    comb(L{2n, 0n, 0n, 6n, 6n}, L{0n, 2n, 2n, 0n, 0n}, L{1n, 3n, 3n, 1n, 0n}, L{0n, 0n, 1n, 7n, 4n}, v, scale(2n, L{1n, 0n, 0n, 3n, 3n}, L{0n, 1n, 1n, 0n, 0n}, v, f_ng),
    comb(L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, L{1n, 3n, 2n, 0n, 0n}, L{0n, 0n, 1n, 7n, 1n}, v, f_h1,
    comb(L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 1n}, L{0n, 0n, 2n, 0n, 0n}, L{0n, 0n, 0n, 6n, 0n}, v, f_h3,
    scale(2n, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v, f_h5)))), {==})
def rld.c0b(+l: Nat, +x: Nat, +y: Nat, +b: Nat, h1: LE(Nat.add(x, y), Nat.mul(3n, b)), h3: LE(1n+Nat.mul(3n, l), Nat.add(Nat.add(x, y), b)), h5: LE(x, Nat.mul(3n, y))) -> LE(Nat.add(l, x), Nat.mul(3n, Nat.add(y, b))):
  by_contra(Nat.add(l, x), Nat.mul(3n, Nat.add(y, b)), ng => rld.c0b.k(l, x, y, b, ng, h1, h3, h5))

def rld.w0(+l: Nat, +x: Nat, +y: Nat, +b: Nat, +h1: LE(Nat.add(x, y), Nat.mul(3n, b)), +h2: LE(b, Nat.mul(3n, Nat.add(x, y))), +h3: LE(1n+Nat.mul(3n, l), Nat.add(Nat.add(x, y), b)), +h4: LE(Nat.add(Nat.add(x, y), b), Nat.add(3n, Nat.mul(3n, l))), +hd: LE(Nat.mul(2n, b), Nat.add(x, y)), +h5: LE(x, Nat.mul(3n, y)), +h6: LE(y, Nat.mul(3n, x)), +pl: LE(1n, l), +px: LE(1n, x), +py: LE(1n, y), +pb: LE(1n, b)) -> {wok(Nat.add(l, x), Nat.add(y, b)) == True{} : Bool}:
  and_i(Nat.is_le(Nat.add(y, b), Nat.mul(3n, Nat.add(l, x))), Nat.is_le(Nat.add(l, x), Nat.mul(3n, Nat.add(y, b))),
    rld.c0a(l, x, y, b, h4, px),
    rld.c0b(l, x, y, b, h1, h3, h5))

def rld.c1a.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, l), x), h1: LE(Nat.add(x, y), Nat.mul(3n, b)), h4: LE(Nat.add(Nat.add(x, y), b), Nat.add(3n, Nat.mul(3n, l))), pl: LE(1n, l), py: LE(1n, y)) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, l), x, L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, x, y, b))),
    cv_2(l, x, y, b), ng)
  +f_h1 = cvle(Nat.add(x, y), Nat.mul(3n, b), L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, v,
    cv_add(x, y, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, x, y, b), cv_3(l, x, y, b)),
    cv_mul(3n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b)), h1)
  +f_h4 = cvle(Nat.add(Nat.add(x, y), b), Nat.add(3n, Nat.mul(3n, l)), L{0n, 0n, 1n, 1n, 1n}, L{3n, 3n, 0n, 0n, 0n}, v,
    cv_add(Nat.add(x, y), b, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 1n}, v, cv_add(x, y, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, x, y, b), cv_3(l, x, y, b)), cv_4(l, x, y, b)),
    cv_add(3n, Nat.mul(3n, l), L{3n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(3n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, x, y, b))), h4)
  +f_pl = cvle(1n, l, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_c(1n, v),
    cv_1(l, x, y, b), pl)
  +f_py = cvle(1n, y, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v,
    cv_c(1n, v),
    cv_3(l, x, y, b), py)
  contra(L{10n, 12n, 4n, 4n, 3n}, L{9n, 11n, 4n, 4n, 3n}, v,
    comb(L{4n, 12n, 0n, 0n, 0n}, L{0n, 0n, 4n, 0n, 0n}, L{6n, 0n, 4n, 4n, 3n}, L{9n, 11n, 0n, 4n, 3n}, v, scale(4n, L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, f_ng),
    comb(L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, L{6n, 0n, 3n, 3n, 3n}, L{9n, 11n, 0n, 4n, 0n}, v, f_h1,
    comb(L{0n, 0n, 3n, 3n, 3n}, L{9n, 9n, 0n, 0n, 0n}, L{6n, 0n, 0n, 0n, 0n}, L{0n, 2n, 0n, 4n, 0n}, v, scale(3n, L{0n, 0n, 1n, 1n, 1n}, L{3n, 3n, 0n, 0n, 0n}, v, f_h4),
    comb(L{2n, 0n, 0n, 0n, 0n}, L{0n, 2n, 0n, 0n, 0n}, L{4n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 4n, 0n}, v, scale(2n, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, f_pl),
    scale(4n, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, f_py))))), {==})
def rld.c1a(+l: Nat, +x: Nat, +y: Nat, +b: Nat, h1: LE(Nat.add(x, y), Nat.mul(3n, b)), h4: LE(Nat.add(Nat.add(x, y), b), Nat.add(3n, Nat.mul(3n, l))), pl: LE(1n, l), py: LE(1n, y)) -> LE(x, Nat.mul(3n, l)):
  by_contra(x, Nat.mul(3n, l), ng => rld.c1a.k(l, x, y, b, ng, h1, h4, pl, py))

def rld.c1b.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, x), l), h3: LE(1n+Nat.mul(3n, l), Nat.add(Nat.add(x, y), b)), hd: LE(Nat.mul(2n, b), Nat.add(x, y)), h6: LE(y, Nat.mul(3n, x))) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, x), l, L{1n, 0n, 3n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, x), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, x, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(l, x, y, b))),
    cv_1(l, x, y, b), ng)
  +f_h3 = cvle(1n+Nat.mul(3n, l), Nat.add(Nat.add(x, y), b), L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 1n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, x, y, b))),
    cv_add(Nat.add(x, y), b, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 1n}, v, cv_add(x, y, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, x, y, b), cv_3(l, x, y, b)), cv_4(l, x, y, b)), h3)
  +f_hd = cvle(Nat.mul(2n, b), Nat.add(x, y), L{0n, 0n, 0n, 0n, 2n}, L{0n, 0n, 1n, 1n, 0n}, v,
    cv_mul(2n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b)),
    cv_add(x, y, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, x, y, b), cv_3(l, x, y, b)), hd)
  +f_h6 = cvle(y, Nat.mul(3n, x), L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v,
    cv_3(l, x, y, b),
    cv_mul(3n, x, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(l, x, y, b)), h6)
  contra(L{4n, 3n, 9n, 2n, 2n}, L{0n, 3n, 8n, 2n, 1n}, v,
    comb(L{3n, 0n, 9n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, L{1n, 3n, 0n, 2n, 2n}, L{0n, 0n, 8n, 2n, 1n}, v, scale(3n, L{1n, 0n, 3n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, f_ng),
    comb(L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 1n}, L{0n, 0n, 0n, 2n, 2n}, L{0n, 0n, 7n, 1n, 0n}, v, f_h3,
    comb(L{0n, 0n, 0n, 0n, 2n}, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 2n, 0n}, L{0n, 0n, 6n, 0n, 0n}, v, f_hd,
    scale(2n, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, f_h6)))), {==})
def rld.c1b(+l: Nat, +x: Nat, +y: Nat, +b: Nat, h3: LE(1n+Nat.mul(3n, l), Nat.add(Nat.add(x, y), b)), hd: LE(Nat.mul(2n, b), Nat.add(x, y)), h6: LE(y, Nat.mul(3n, x))) -> LE(l, Nat.mul(3n, x)):
  by_contra(l, Nat.mul(3n, x), ng => rld.c1b.k(l, x, y, b, ng, h3, hd, h6))

def rld.w1(+l: Nat, +x: Nat, +y: Nat, +b: Nat, +h1: LE(Nat.add(x, y), Nat.mul(3n, b)), +h2: LE(b, Nat.mul(3n, Nat.add(x, y))), +h3: LE(1n+Nat.mul(3n, l), Nat.add(Nat.add(x, y), b)), +h4: LE(Nat.add(Nat.add(x, y), b), Nat.add(3n, Nat.mul(3n, l))), +hd: LE(Nat.mul(2n, b), Nat.add(x, y)), +h5: LE(x, Nat.mul(3n, y)), +h6: LE(y, Nat.mul(3n, x)), +pl: LE(1n, l), +px: LE(1n, x), +py: LE(1n, y), +pb: LE(1n, b)) -> {wok(l, x) == True{} : Bool}:
  and_i(Nat.is_le(x, Nat.mul(3n, l)), Nat.is_le(l, Nat.mul(3n, x)),
    rld.c1a(l, x, y, b, h1, h4, pl, py),
    rld.c1b(l, x, y, b, h3, hd, h6))

def rld.c2a.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, y), b), hd: LE(Nat.mul(2n, b), Nat.add(x, y)), h5: LE(x, Nat.mul(3n, y))) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, y), b, L{1n, 0n, 0n, 3n, 0n}, L{0n, 0n, 0n, 0n, 1n}, v,
    cv_add(1n, Nat.mul(3n, y), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v, cv_c(1n, v), cv_mul(3n, y, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, x, y, b))),
    cv_4(l, x, y, b), ng)
  +f_hd = cvle(Nat.mul(2n, b), Nat.add(x, y), L{0n, 0n, 0n, 0n, 2n}, L{0n, 0n, 1n, 1n, 0n}, v,
    cv_mul(2n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b)),
    cv_add(x, y, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, x, y, b), cv_3(l, x, y, b)), hd)
  +f_h5 = cvle(x, Nat.mul(3n, y), L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v,
    cv_2(l, x, y, b),
    cv_mul(3n, y, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, x, y, b)), h5)
  contra(L{2n, 0n, 1n, 6n, 2n}, L{0n, 0n, 1n, 4n, 2n}, v,
    comb(L{2n, 0n, 0n, 6n, 0n}, L{0n, 0n, 0n, 0n, 2n}, L{0n, 0n, 1n, 0n, 2n}, L{0n, 0n, 1n, 4n, 0n}, v, scale(2n, L{1n, 0n, 0n, 3n, 0n}, L{0n, 0n, 0n, 0n, 1n}, v, f_ng),
    comb(L{0n, 0n, 0n, 0n, 2n}, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v, f_hd,
    f_h5)), {==})
def rld.c2a(+l: Nat, +x: Nat, +y: Nat, +b: Nat, hd: LE(Nat.mul(2n, b), Nat.add(x, y)), h5: LE(x, Nat.mul(3n, y))) -> LE(b, Nat.mul(3n, y)):
  by_contra(b, Nat.mul(3n, y), ng => rld.c2a.k(l, x, y, b, ng, hd, h5))

def rld.c2b.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, b), y), h1: LE(Nat.add(x, y), Nat.mul(3n, b))) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, b), y, L{1n, 0n, 0n, 0n, 3n}, L{0n, 0n, 0n, 1n, 0n}, v,
    cv_add(1n, Nat.mul(3n, b), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 0n, 3n}, v, cv_c(1n, v), cv_mul(3n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b))),
    cv_3(l, x, y, b), ng)
  +f_h1 = cvle(Nat.add(x, y), Nat.mul(3n, b), L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, v,
    cv_add(x, y, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(l, x, y, b), cv_3(l, x, y, b)),
    cv_mul(3n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b)), h1)
  contra(L{1n, 0n, 1n, 1n, 3n}, L{0n, 0n, 0n, 1n, 3n}, v,
    comb(L{1n, 0n, 0n, 0n, 3n}, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, v, f_ng,
    f_h1), {==})
def rld.c2b(+l: Nat, +x: Nat, +y: Nat, +b: Nat, h1: LE(Nat.add(x, y), Nat.mul(3n, b))) -> LE(y, Nat.mul(3n, b)):
  by_contra(y, Nat.mul(3n, b), ng => rld.c2b.k(l, x, y, b, ng, h1))

def rld.w2(+l: Nat, +x: Nat, +y: Nat, +b: Nat, +h1: LE(Nat.add(x, y), Nat.mul(3n, b)), +h2: LE(b, Nat.mul(3n, Nat.add(x, y))), +h3: LE(1n+Nat.mul(3n, l), Nat.add(Nat.add(x, y), b)), +h4: LE(Nat.add(Nat.add(x, y), b), Nat.add(3n, Nat.mul(3n, l))), +hd: LE(Nat.mul(2n, b), Nat.add(x, y)), +h5: LE(x, Nat.mul(3n, y)), +h6: LE(y, Nat.mul(3n, x)), +pl: LE(1n, l), +px: LE(1n, x), +py: LE(1n, y), +pb: LE(1n, b)) -> {wok(y, b) == True{} : Bool}:
  and_i(Nat.is_le(b, Nat.mul(3n, y)), Nat.is_le(y, Nat.mul(3n, b)),
    rld.c2a(l, x, y, b, hd, h5),
    rld.c2b(l, x, y, b, h1))

def rhd.c0a.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, Nat.add(b, y)), Nat.add(x, l)), h1: LE(Nat.add(y, x), Nat.mul(3n, b)), h3: LE(1n+Nat.mul(3n, l), Nat.add(b, Nat.add(y, x))), h5: LE(x, Nat.mul(3n, y))) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, Nat.add(b, y)), Nat.add(x, l), L{1n, 0n, 0n, 3n, 3n}, L{0n, 1n, 1n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, Nat.add(b, y)), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 3n, 3n}, v, cv_c(1n, v), cv_mul(3n, Nat.add(b, y), L{0n, 0n, 0n, 1n, 1n}, v, cv_add(b, y, L{0n, 0n, 0n, 0n, 1n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_4(l, x, y, b), cv_3(l, x, y, b)))),
    cv_add(x, l, L{0n, 0n, 1n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_2(l, x, y, b), cv_1(l, x, y, b)), ng)
  +f_h1 = cvle(Nat.add(y, x), Nat.mul(3n, b), L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, v,
    cv_add(y, x, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, x, y, b), cv_2(l, x, y, b)),
    cv_mul(3n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b)), h1)
  +f_h3 = cvle(1n+Nat.mul(3n, l), Nat.add(b, Nat.add(y, x)), L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 1n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, x, y, b))),
    cv_add(b, Nat.add(y, x), L{0n, 0n, 0n, 0n, 1n}, L{0n, 0n, 1n, 1n, 0n}, v, cv_4(l, x, y, b), cv_add(y, x, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, x, y, b), cv_2(l, x, y, b))), h3)
  +f_h5 = cvle(x, Nat.mul(3n, y), L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v,
    cv_2(l, x, y, b),
    cv_mul(3n, y, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, x, y, b)), h5)
  contra(L{3n, 3n, 3n, 7n, 6n}, L{0n, 2n, 3n, 7n, 4n}, v,
    comb(L{2n, 0n, 0n, 6n, 6n}, L{0n, 2n, 2n, 0n, 0n}, L{1n, 3n, 3n, 1n, 0n}, L{0n, 0n, 1n, 7n, 4n}, v, scale(2n, L{1n, 0n, 0n, 3n, 3n}, L{0n, 1n, 1n, 0n, 0n}, v, f_ng),
    comb(L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, L{1n, 3n, 2n, 0n, 0n}, L{0n, 0n, 1n, 7n, 1n}, v, f_h1,
    comb(L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 1n}, L{0n, 0n, 2n, 0n, 0n}, L{0n, 0n, 0n, 6n, 0n}, v, f_h3,
    scale(2n, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v, f_h5)))), {==})
def rhd.c0a(+l: Nat, +x: Nat, +y: Nat, +b: Nat, h1: LE(Nat.add(y, x), Nat.mul(3n, b)), h3: LE(1n+Nat.mul(3n, l), Nat.add(b, Nat.add(y, x))), h5: LE(x, Nat.mul(3n, y))) -> LE(Nat.add(x, l), Nat.mul(3n, Nat.add(b, y))):
  by_contra(Nat.add(x, l), Nat.mul(3n, Nat.add(b, y)), ng => rhd.c0a.k(l, x, y, b, ng, h1, h3, h5))

def rhd.c0b.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, Nat.add(x, l)), Nat.add(b, y)), h4: LE(Nat.add(b, Nat.add(y, x)), Nat.add(3n, Nat.mul(3n, l))), px: LE(1n, x)) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, Nat.add(x, l)), Nat.add(b, y), L{1n, 3n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 1n}, v,
    cv_add(1n, Nat.mul(3n, Nat.add(x, l)), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 3n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, Nat.add(x, l), L{0n, 1n, 1n, 0n, 0n}, v, cv_add(x, l, L{0n, 0n, 1n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_2(l, x, y, b), cv_1(l, x, y, b)))),
    cv_add(b, y, L{0n, 0n, 0n, 0n, 1n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_4(l, x, y, b), cv_3(l, x, y, b)), ng)
  +f_h4 = cvle(Nat.add(b, Nat.add(y, x)), Nat.add(3n, Nat.mul(3n, l)), L{0n, 0n, 1n, 1n, 1n}, L{3n, 3n, 0n, 0n, 0n}, v,
    cv_add(b, Nat.add(y, x), L{0n, 0n, 0n, 0n, 1n}, L{0n, 0n, 1n, 1n, 0n}, v, cv_4(l, x, y, b), cv_add(y, x, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, x, y, b), cv_2(l, x, y, b))),
    cv_add(3n, Nat.mul(3n, l), L{3n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(3n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, x, y, b))), h4)
  +f_px = cvle(1n, x, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v,
    cv_c(1n, v),
    cv_2(l, x, y, b), px)
  contra(L{4n, 3n, 4n, 1n, 1n}, L{3n, 3n, 3n, 1n, 1n}, v,
    comb(L{1n, 3n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 1n}, L{3n, 0n, 1n, 1n, 1n}, L{3n, 3n, 3n, 0n, 0n}, v, f_ng,
    comb(L{0n, 0n, 1n, 1n, 1n}, L{3n, 3n, 0n, 0n, 0n}, L{3n, 0n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, f_h4,
    scale(3n, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, f_px))), {==})
def rhd.c0b(+l: Nat, +x: Nat, +y: Nat, +b: Nat, h4: LE(Nat.add(b, Nat.add(y, x)), Nat.add(3n, Nat.mul(3n, l))), px: LE(1n, x)) -> LE(Nat.add(b, y), Nat.mul(3n, Nat.add(x, l))):
  by_contra(Nat.add(b, y), Nat.mul(3n, Nat.add(x, l)), ng => rhd.c0b.k(l, x, y, b, ng, h4, px))

def rhd.w0(+l: Nat, +x: Nat, +y: Nat, +b: Nat, +h1: LE(Nat.add(y, x), Nat.mul(3n, b)), +h2: LE(b, Nat.mul(3n, Nat.add(y, x))), +h3: LE(1n+Nat.mul(3n, l), Nat.add(b, Nat.add(y, x))), +h4: LE(Nat.add(b, Nat.add(y, x)), Nat.add(3n, Nat.mul(3n, l))), +hd: LE(Nat.mul(2n, b), Nat.add(y, x)), +h5: LE(x, Nat.mul(3n, y)), +h6: LE(y, Nat.mul(3n, x)), +pl: LE(1n, l), +px: LE(1n, x), +py: LE(1n, y), +pb: LE(1n, b)) -> {wok(Nat.add(b, y), Nat.add(x, l)) == True{} : Bool}:
  and_i(Nat.is_le(Nat.add(x, l), Nat.mul(3n, Nat.add(b, y))), Nat.is_le(Nat.add(b, y), Nat.mul(3n, Nat.add(x, l))),
    rhd.c0a(l, x, y, b, h1, h3, h5),
    rhd.c0b(l, x, y, b, h4, px))

def rhd.c1a.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, b), y), h1: LE(Nat.add(y, x), Nat.mul(3n, b))) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, b), y, L{1n, 0n, 0n, 0n, 3n}, L{0n, 0n, 0n, 1n, 0n}, v,
    cv_add(1n, Nat.mul(3n, b), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 0n, 3n}, v, cv_c(1n, v), cv_mul(3n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b))),
    cv_3(l, x, y, b), ng)
  +f_h1 = cvle(Nat.add(y, x), Nat.mul(3n, b), L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, v,
    cv_add(y, x, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, x, y, b), cv_2(l, x, y, b)),
    cv_mul(3n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b)), h1)
  contra(L{1n, 0n, 1n, 1n, 3n}, L{0n, 0n, 0n, 1n, 3n}, v,
    comb(L{1n, 0n, 0n, 0n, 3n}, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, v, f_ng,
    f_h1), {==})
def rhd.c1a(+l: Nat, +x: Nat, +y: Nat, +b: Nat, h1: LE(Nat.add(y, x), Nat.mul(3n, b))) -> LE(y, Nat.mul(3n, b)):
  by_contra(y, Nat.mul(3n, b), ng => rhd.c1a.k(l, x, y, b, ng, h1))

def rhd.c1b.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, y), b), hd: LE(Nat.mul(2n, b), Nat.add(y, x)), h5: LE(x, Nat.mul(3n, y))) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, y), b, L{1n, 0n, 0n, 3n, 0n}, L{0n, 0n, 0n, 0n, 1n}, v,
    cv_add(1n, Nat.mul(3n, y), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v, cv_c(1n, v), cv_mul(3n, y, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, x, y, b))),
    cv_4(l, x, y, b), ng)
  +f_hd = cvle(Nat.mul(2n, b), Nat.add(y, x), L{0n, 0n, 0n, 0n, 2n}, L{0n, 0n, 1n, 1n, 0n}, v,
    cv_mul(2n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b)),
    cv_add(y, x, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, x, y, b), cv_2(l, x, y, b)), hd)
  +f_h5 = cvle(x, Nat.mul(3n, y), L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v,
    cv_2(l, x, y, b),
    cv_mul(3n, y, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(l, x, y, b)), h5)
  contra(L{2n, 0n, 1n, 6n, 2n}, L{0n, 0n, 1n, 4n, 2n}, v,
    comb(L{2n, 0n, 0n, 6n, 0n}, L{0n, 0n, 0n, 0n, 2n}, L{0n, 0n, 1n, 0n, 2n}, L{0n, 0n, 1n, 4n, 0n}, v, scale(2n, L{1n, 0n, 0n, 3n, 0n}, L{0n, 0n, 0n, 0n, 1n}, v, f_ng),
    comb(L{0n, 0n, 0n, 0n, 2n}, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v, f_hd,
    f_h5)), {==})
def rhd.c1b(+l: Nat, +x: Nat, +y: Nat, +b: Nat, hd: LE(Nat.mul(2n, b), Nat.add(y, x)), h5: LE(x, Nat.mul(3n, y))) -> LE(b, Nat.mul(3n, y)):
  by_contra(b, Nat.mul(3n, y), ng => rhd.c1b.k(l, x, y, b, ng, hd, h5))

def rhd.w1(+l: Nat, +x: Nat, +y: Nat, +b: Nat, +h1: LE(Nat.add(y, x), Nat.mul(3n, b)), +h2: LE(b, Nat.mul(3n, Nat.add(y, x))), +h3: LE(1n+Nat.mul(3n, l), Nat.add(b, Nat.add(y, x))), +h4: LE(Nat.add(b, Nat.add(y, x)), Nat.add(3n, Nat.mul(3n, l))), +hd: LE(Nat.mul(2n, b), Nat.add(y, x)), +h5: LE(x, Nat.mul(3n, y)), +h6: LE(y, Nat.mul(3n, x)), +pl: LE(1n, l), +px: LE(1n, x), +py: LE(1n, y), +pb: LE(1n, b)) -> {wok(b, y) == True{} : Bool}:
  and_i(Nat.is_le(y, Nat.mul(3n, b)), Nat.is_le(b, Nat.mul(3n, y)),
    rhd.c1a(l, x, y, b, h1),
    rhd.c1b(l, x, y, b, hd, h5))

def rhd.c2a.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, x), l), h3: LE(1n+Nat.mul(3n, l), Nat.add(b, Nat.add(y, x))), hd: LE(Nat.mul(2n, b), Nat.add(y, x)), h6: LE(y, Nat.mul(3n, x))) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, x), l, L{1n, 0n, 3n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, x), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, x, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(l, x, y, b))),
    cv_1(l, x, y, b), ng)
  +f_h3 = cvle(1n+Nat.mul(3n, l), Nat.add(b, Nat.add(y, x)), L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 1n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, x, y, b))),
    cv_add(b, Nat.add(y, x), L{0n, 0n, 0n, 0n, 1n}, L{0n, 0n, 1n, 1n, 0n}, v, cv_4(l, x, y, b), cv_add(y, x, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, x, y, b), cv_2(l, x, y, b))), h3)
  +f_hd = cvle(Nat.mul(2n, b), Nat.add(y, x), L{0n, 0n, 0n, 0n, 2n}, L{0n, 0n, 1n, 1n, 0n}, v,
    cv_mul(2n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b)),
    cv_add(y, x, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, x, y, b), cv_2(l, x, y, b)), hd)
  +f_h6 = cvle(y, Nat.mul(3n, x), L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v,
    cv_3(l, x, y, b),
    cv_mul(3n, x, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(l, x, y, b)), h6)
  contra(L{4n, 3n, 9n, 2n, 2n}, L{0n, 3n, 8n, 2n, 1n}, v,
    comb(L{3n, 0n, 9n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, L{1n, 3n, 0n, 2n, 2n}, L{0n, 0n, 8n, 2n, 1n}, v, scale(3n, L{1n, 0n, 3n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, f_ng),
    comb(L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 1n}, L{0n, 0n, 0n, 2n, 2n}, L{0n, 0n, 7n, 1n, 0n}, v, f_h3,
    comb(L{0n, 0n, 0n, 0n, 2n}, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 2n, 0n}, L{0n, 0n, 6n, 0n, 0n}, v, f_hd,
    scale(2n, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, f_h6)))), {==})
def rhd.c2a(+l: Nat, +x: Nat, +y: Nat, +b: Nat, h3: LE(1n+Nat.mul(3n, l), Nat.add(b, Nat.add(y, x))), hd: LE(Nat.mul(2n, b), Nat.add(y, x)), h6: LE(y, Nat.mul(3n, x))) -> LE(l, Nat.mul(3n, x)):
  by_contra(l, Nat.mul(3n, x), ng => rhd.c2a.k(l, x, y, b, ng, h3, hd, h6))

def rhd.c2b.k(+l: Nat, +x: Nat, +y: Nat, +b: Nat, ng: LE(1n+Nat.mul(3n, l), x), h1: LE(Nat.add(y, x), Nat.mul(3n, b)), h4: LE(Nat.add(b, Nat.add(y, x)), Nat.add(3n, Nat.mul(3n, l))), pl: LE(1n, l), py: LE(1n, y)) -> Empty:
  +v = {VS{l, x, y, b} : Vs}
  +f_ng = cvle(1n+Nat.mul(3n, l), x, L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, x, y, b))),
    cv_2(l, x, y, b), ng)
  +f_h1 = cvle(Nat.add(y, x), Nat.mul(3n, b), L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, v,
    cv_add(y, x, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, x, y, b), cv_2(l, x, y, b)),
    cv_mul(3n, b, L{0n, 0n, 0n, 0n, 1n}, v, cv_4(l, x, y, b)), h1)
  +f_h4 = cvle(Nat.add(b, Nat.add(y, x)), Nat.add(3n, Nat.mul(3n, l)), L{0n, 0n, 1n, 1n, 1n}, L{3n, 3n, 0n, 0n, 0n}, v,
    cv_add(b, Nat.add(y, x), L{0n, 0n, 0n, 0n, 1n}, L{0n, 0n, 1n, 1n, 0n}, v, cv_4(l, x, y, b), cv_add(y, x, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_3(l, x, y, b), cv_2(l, x, y, b))),
    cv_add(3n, Nat.mul(3n, l), L{3n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(3n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, x, y, b))), h4)
  +f_pl = cvle(1n, l, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_c(1n, v),
    cv_1(l, x, y, b), pl)
  +f_py = cvle(1n, y, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v,
    cv_c(1n, v),
    cv_3(l, x, y, b), py)
  contra(L{10n, 12n, 4n, 4n, 3n}, L{9n, 11n, 4n, 4n, 3n}, v,
    comb(L{4n, 12n, 0n, 0n, 0n}, L{0n, 0n, 4n, 0n, 0n}, L{6n, 0n, 4n, 4n, 3n}, L{9n, 11n, 0n, 4n, 3n}, v, scale(4n, L{1n, 3n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, f_ng),
    comb(L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 0n, 0n, 3n}, L{6n, 0n, 3n, 3n, 3n}, L{9n, 11n, 0n, 4n, 0n}, v, f_h1,
    comb(L{0n, 0n, 3n, 3n, 3n}, L{9n, 9n, 0n, 0n, 0n}, L{6n, 0n, 0n, 0n, 0n}, L{0n, 2n, 0n, 4n, 0n}, v, scale(3n, L{0n, 0n, 1n, 1n, 1n}, L{3n, 3n, 0n, 0n, 0n}, v, f_h4),
    comb(L{2n, 0n, 0n, 0n, 0n}, L{0n, 2n, 0n, 0n, 0n}, L{4n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 4n, 0n}, v, scale(2n, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, f_pl),
    scale(4n, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, f_py))))), {==})
def rhd.c2b(+l: Nat, +x: Nat, +y: Nat, +b: Nat, h1: LE(Nat.add(y, x), Nat.mul(3n, b)), h4: LE(Nat.add(b, Nat.add(y, x)), Nat.add(3n, Nat.mul(3n, l))), pl: LE(1n, l), py: LE(1n, y)) -> LE(x, Nat.mul(3n, l)):
  by_contra(x, Nat.mul(3n, l), ng => rhd.c2b.k(l, x, y, b, ng, h1, h4, pl, py))

def rhd.w2(+l: Nat, +x: Nat, +y: Nat, +b: Nat, +h1: LE(Nat.add(y, x), Nat.mul(3n, b)), +h2: LE(b, Nat.mul(3n, Nat.add(y, x))), +h3: LE(1n+Nat.mul(3n, l), Nat.add(b, Nat.add(y, x))), +h4: LE(Nat.add(b, Nat.add(y, x)), Nat.add(3n, Nat.mul(3n, l))), +hd: LE(Nat.mul(2n, b), Nat.add(y, x)), +h5: LE(x, Nat.mul(3n, y)), +h6: LE(y, Nat.mul(3n, x)), +pl: LE(1n, l), +px: LE(1n, x), +py: LE(1n, y), +pb: LE(1n, b)) -> {wok(x, l) == True{} : Bool}:
  and_i(Nat.is_le(l, Nat.mul(3n, x)), Nat.is_le(x, Nat.mul(3n, l)),
    rhd.c2a(l, x, y, b, h3, hd, h6),
    rhd.c2b(l, x, y, b, h1, h4, pl, py))

def tiph(+l: Nat, h: LE(1n+Nat.mul(3n, l), 1n), pl: LE(1n, l)) -> Empty:
  +v = {VS{l, 0n, 0n, 0n} : Vs}
  +f_h = cvle(1n+Nat.mul(3n, l), 1n, L{1n, 3n, 0n, 0n, 0n}, L{1n, 0n, 0n, 0n, 0n}, v,
    cv_add(1n, Nat.mul(3n, l), L{1n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_mul(3n, l, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(l, 0n, 0n, 0n))),
    cv_c(1n, v), h)
  +f_pl = cvle(1n, l, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_c(1n, v),
    cv_1(l, 0n, 0n, 0n), pl)
  contra(L{2n, 3n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v,
    comb(L{1n, 3n, 0n, 0n, 0n}, L{1n, 0n, 0n, 0n, 0n}, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, f_h,
    f_pl), {==})

def dtip(+b: Nat, h: LE(Nat.mul(2n, b), 1n), pb: LE(1n, b)) -> Empty:
  +v = {VS{b, 0n, 0n, 0n} : Vs}
  +f_h = cvle(Nat.mul(2n, b), 1n, L{0n, 2n, 0n, 0n, 0n}, L{1n, 0n, 0n, 0n, 0n}, v,
    cv_mul(2n, b, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(b, 0n, 0n, 0n)),
    cv_c(1n, v), h)
  +f_pb = cvle(1n, b, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_c(1n, v),
    cv_1(b, 0n, 0n, 0n), pb)
  contra(L{2n, 2n, 0n, 0n, 0n}, L{1n, 2n, 0n, 0n, 0n}, v,
    comb(L{0n, 2n, 0n, 0n, 0n}, L{1n, 0n, 0n, 0n, 0n}, L{2n, 0n, 0n, 0n, 0n}, L{0n, 2n, 0n, 0n, 0n}, v, f_h,
    scale(2n, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, f_pb)), {==})

def almlo.c0a.k(+wl: Nat, +wh: Nat, +w2: Nat, ng: LE(1n+Nat.add(3n, Nat.mul(3n, w2)), wh), o1: LE(wh, Nat.mul(3n, wl)), n1: LE(wl, 1n+w2)) -> Empty:
  +v = {VS{wl, wh, w2, 0n} : Vs}
  +f_ng = cvle(1n+Nat.add(3n, Nat.mul(3n, w2)), wh, L{4n, 0n, 0n, 3n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v,
    cv_add(1n, Nat.add(3n, Nat.mul(3n, w2)), L{1n, 0n, 0n, 0n, 0n}, L{3n, 0n, 0n, 3n, 0n}, v, cv_c(1n, v), cv_add(3n, Nat.mul(3n, w2), L{3n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v, cv_c(3n, v), cv_mul(3n, w2, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(wl, wh, w2, 0n)))),
    cv_2(wl, wh, w2, 0n), ng)
  +f_o1 = cvle(wh, Nat.mul(3n, wl), L{0n, 0n, 1n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v,
    cv_2(wl, wh, w2, 0n),
    cv_mul(3n, wl, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(wl, wh, w2, 0n)), o1)
  +f_n1 = cvle(wl, 1n+w2, L{0n, 1n, 0n, 0n, 0n}, L{1n, 0n, 0n, 1n, 0n}, v,
    cv_1(wl, wh, w2, 0n),
    cv_add(1n, w2, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_c(1n, v), cv_3(wl, wh, w2, 0n)), n1)
  contra(L{4n, 3n, 1n, 3n, 0n}, L{3n, 3n, 1n, 3n, 0n}, v,
    comb(L{4n, 0n, 0n, 3n, 0n}, L{0n, 0n, 1n, 0n, 0n}, L{0n, 3n, 1n, 0n, 0n}, L{3n, 3n, 0n, 3n, 0n}, v, f_ng,
    comb(L{0n, 0n, 1n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, L{3n, 0n, 0n, 3n, 0n}, v, f_o1,
    scale(3n, L{0n, 1n, 0n, 0n, 0n}, L{1n, 0n, 0n, 1n, 0n}, v, f_n1))), {==})
def almlo.c0a(+wl: Nat, +wh: Nat, +w2: Nat, o1: LE(wh, Nat.mul(3n, wl)), n1: LE(wl, 1n+w2)) -> LE(wh, Nat.add(3n, Nat.mul(3n, w2))):
  by_contra(wh, Nat.add(3n, Nat.mul(3n, w2)), ng => almlo.c0a.k(wl, wh, w2, ng, o1, n1))

def almlo.c0b.k(+wl: Nat, +wh: Nat, +w2: Nat, ng: LE(1n+Nat.add(3n, Nat.mul(3n, wh)), w2), o2: LE(wl, Nat.mul(3n, wh)), n2: LE(w2, 1n+wl)) -> Empty:
  +v = {VS{wl, wh, w2, 0n} : Vs}
  +f_ng = cvle(1n+Nat.add(3n, Nat.mul(3n, wh)), w2, L{4n, 0n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v,
    cv_add(1n, Nat.add(3n, Nat.mul(3n, wh)), L{1n, 0n, 0n, 0n, 0n}, L{3n, 0n, 3n, 0n, 0n}, v, cv_c(1n, v), cv_add(3n, Nat.mul(3n, wh), L{3n, 0n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v, cv_c(3n, v), cv_mul(3n, wh, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(wl, wh, w2, 0n)))),
    cv_3(wl, wh, w2, 0n), ng)
  +f_o2 = cvle(wl, Nat.mul(3n, wh), L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v,
    cv_1(wl, wh, w2, 0n),
    cv_mul(3n, wh, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(wl, wh, w2, 0n)), o2)
  +f_n2 = cvle(w2, 1n+wl, L{0n, 0n, 0n, 1n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v,
    cv_3(wl, wh, w2, 0n),
    cv_add(1n, wl, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_1(wl, wh, w2, 0n)), n2)
  contra(L{4n, 1n, 3n, 1n, 0n}, L{1n, 1n, 3n, 1n, 0n}, v,
    comb(L{4n, 0n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, L{0n, 1n, 0n, 1n, 0n}, L{1n, 1n, 3n, 0n, 0n}, v, f_ng,
    comb(L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v, f_o2,
    f_n2)), {==})
def almlo.c0b(+wl: Nat, +wh: Nat, +w2: Nat, o2: LE(wl, Nat.mul(3n, wh)), n2: LE(w2, 1n+wl)) -> LE(w2, Nat.add(3n, Nat.mul(3n, wh))):
  by_contra(w2, Nat.add(3n, Nat.mul(3n, wh)), ng => almlo.c0b.k(wl, wh, w2, ng, o2, n2))

def almlo.w0(+wl: Nat, +wh: Nat, +w2: Nat, +o1: LE(wh, Nat.mul(3n, wl)), +o2: LE(wl, Nat.mul(3n, wh)), +n1: LE(wl, 1n+w2), +n2: LE(w2, 1n+wl)) -> {alm(w2, wh) == True{} : Bool}:
  and_i(Nat.is_le(wh, Nat.add(3n, Nat.mul(3n, w2))), Nat.is_le(w2, Nat.add(3n, Nat.mul(3n, wh))),
    almlo.c0a(wl, wh, w2, o1, n1),
    almlo.c0b(wl, wh, w2, o2, n2))

def almhi.c0a.k(+wl: Nat, +wh: Nat, +w2: Nat, ng: LE(1n+Nat.add(3n, Nat.mul(3n, wl)), w2), o1: LE(wh, Nat.mul(3n, wl)), n2: LE(w2, 1n+wh)) -> Empty:
  +v = {VS{wl, wh, w2, 0n} : Vs}
  +f_ng = cvle(1n+Nat.add(3n, Nat.mul(3n, wl)), w2, L{4n, 3n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v,
    cv_add(1n, Nat.add(3n, Nat.mul(3n, wl)), L{1n, 0n, 0n, 0n, 0n}, L{3n, 3n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_add(3n, Nat.mul(3n, wl), L{3n, 0n, 0n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v, cv_c(3n, v), cv_mul(3n, wl, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(wl, wh, w2, 0n)))),
    cv_3(wl, wh, w2, 0n), ng)
  +f_o1 = cvle(wh, Nat.mul(3n, wl), L{0n, 0n, 1n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, v,
    cv_2(wl, wh, w2, 0n),
    cv_mul(3n, wl, L{0n, 1n, 0n, 0n, 0n}, v, cv_1(wl, wh, w2, 0n)), o1)
  +f_n2 = cvle(w2, 1n+wh, L{0n, 0n, 0n, 1n, 0n}, L{1n, 0n, 1n, 0n, 0n}, v,
    cv_3(wl, wh, w2, 0n),
    cv_add(1n, wh, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_c(1n, v), cv_2(wl, wh, w2, 0n)), n2)
  contra(L{4n, 3n, 1n, 1n, 0n}, L{1n, 3n, 1n, 1n, 0n}, v,
    comb(L{4n, 3n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, L{0n, 0n, 1n, 1n, 0n}, L{1n, 3n, 1n, 0n, 0n}, v, f_ng,
    comb(L{0n, 0n, 1n, 0n, 0n}, L{0n, 3n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, L{1n, 0n, 1n, 0n, 0n}, v, f_o1,
    f_n2)), {==})
def almhi.c0a(+wl: Nat, +wh: Nat, +w2: Nat, o1: LE(wh, Nat.mul(3n, wl)), n2: LE(w2, 1n+wh)) -> LE(w2, Nat.add(3n, Nat.mul(3n, wl))):
  by_contra(w2, Nat.add(3n, Nat.mul(3n, wl)), ng => almhi.c0a.k(wl, wh, w2, ng, o1, n2))

def almhi.c0b.k(+wl: Nat, +wh: Nat, +w2: Nat, ng: LE(1n+Nat.add(3n, Nat.mul(3n, w2)), wl), o2: LE(wl, Nat.mul(3n, wh)), n1: LE(wh, 1n+w2)) -> Empty:
  +v = {VS{wl, wh, w2, 0n} : Vs}
  +f_ng = cvle(1n+Nat.add(3n, Nat.mul(3n, w2)), wl, L{4n, 0n, 0n, 3n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, Nat.add(3n, Nat.mul(3n, w2)), L{1n, 0n, 0n, 0n, 0n}, L{3n, 0n, 0n, 3n, 0n}, v, cv_c(1n, v), cv_add(3n, Nat.mul(3n, w2), L{3n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 3n, 0n}, v, cv_c(3n, v), cv_mul(3n, w2, L{0n, 0n, 0n, 1n, 0n}, v, cv_3(wl, wh, w2, 0n)))),
    cv_1(wl, wh, w2, 0n), ng)
  +f_o2 = cvle(wl, Nat.mul(3n, wh), L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, v,
    cv_1(wl, wh, w2, 0n),
    cv_mul(3n, wh, L{0n, 0n, 1n, 0n, 0n}, v, cv_2(wl, wh, w2, 0n)), o2)
  +f_n1 = cvle(wh, 1n+w2, L{0n, 0n, 1n, 0n, 0n}, L{1n, 0n, 0n, 1n, 0n}, v,
    cv_2(wl, wh, w2, 0n),
    cv_add(1n, w2, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_c(1n, v), cv_3(wl, wh, w2, 0n)), n1)
  contra(L{4n, 1n, 3n, 3n, 0n}, L{3n, 1n, 3n, 3n, 0n}, v,
    comb(L{4n, 0n, 0n, 3n, 0n}, L{0n, 1n, 0n, 0n, 0n}, L{0n, 1n, 3n, 0n, 0n}, L{3n, 0n, 3n, 3n, 0n}, v, f_ng,
    comb(L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, L{0n, 0n, 3n, 0n, 0n}, L{3n, 0n, 0n, 3n, 0n}, v, f_o2,
    scale(3n, L{0n, 0n, 1n, 0n, 0n}, L{1n, 0n, 0n, 1n, 0n}, v, f_n1))), {==})
def almhi.c0b(+wl: Nat, +wh: Nat, +w2: Nat, o2: LE(wl, Nat.mul(3n, wh)), n1: LE(wh, 1n+w2)) -> LE(wl, Nat.add(3n, Nat.mul(3n, w2))):
  by_contra(wl, Nat.add(3n, Nat.mul(3n, w2)), ng => almhi.c0b.k(wl, wh, w2, ng, o2, n1))

def almhi.w0(+wl: Nat, +wh: Nat, +w2: Nat, +o1: LE(wh, Nat.mul(3n, wl)), +o2: LE(wl, Nat.mul(3n, wh)), +n1: LE(wh, 1n+w2), +n2: LE(w2, 1n+wh)) -> {alm(wl, w2) == True{} : Bool}:
  and_i(Nat.is_le(w2, Nat.add(3n, Nat.mul(3n, wl))), Nat.is_le(wl, Nat.add(3n, Nat.mul(3n, w2))),
    almhi.c0a(wl, wh, w2, o1, n2),
    almhi.c0b(wl, wh, w2, o2, n1))

def nearlo.c0a.k(+a: Nat, +a2: Nat, +c: Nat, ng: LE(1n+1n+Nat.add(a2, c), Nat.add(a, c)), n1: LE(a, 1n+a2)) -> Empty:
  +v = {VS{a, a2, c, 0n} : Vs}
  +f_ng = cvle(1n+1n+Nat.add(a2, c), Nat.add(a, c), L{2n, 0n, 1n, 1n, 0n}, L{0n, 1n, 0n, 1n, 0n}, v,
    cv_add(1n, 1n+Nat.add(a2, c), L{1n, 0n, 0n, 0n, 0n}, L{1n, 0n, 1n, 1n, 0n}, v, cv_c(1n, v), cv_add(1n, Nat.add(a2, c), L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 1n, 0n}, v, cv_c(1n, v), cv_add(a2, c, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(a, a2, c, 0n), cv_3(a, a2, c, 0n)))),
    cv_add(a, c, L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_1(a, a2, c, 0n), cv_3(a, a2, c, 0n)), ng)
  +f_n1 = cvle(a, 1n+a2, L{0n, 1n, 0n, 0n, 0n}, L{1n, 0n, 1n, 0n, 0n}, v,
    cv_1(a, a2, c, 0n),
    cv_add(1n, a2, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_c(1n, v), cv_2(a, a2, c, 0n)), n1)
  contra(L{2n, 1n, 1n, 1n, 0n}, L{1n, 1n, 1n, 1n, 0n}, v,
    comb(L{2n, 0n, 1n, 1n, 0n}, L{0n, 1n, 0n, 1n, 0n}, L{0n, 1n, 0n, 0n, 0n}, L{1n, 0n, 1n, 0n, 0n}, v, f_ng,
    f_n1), {==})
def nearlo.c0a(+a: Nat, +a2: Nat, +c: Nat, n1: LE(a, 1n+a2)) -> LE(Nat.add(a, c), 1n+Nat.add(a2, c)):
  by_contra(Nat.add(a, c), 1n+Nat.add(a2, c), ng => nearlo.c0a.k(a, a2, c, ng, n1))

def nearlo.c0b.k(+a: Nat, +a2: Nat, +c: Nat, ng: LE(1n+1n+Nat.add(a, c), Nat.add(a2, c)), n2: LE(a2, 1n+a)) -> Empty:
  +v = {VS{a, a2, c, 0n} : Vs}
  +f_ng = cvle(1n+1n+Nat.add(a, c), Nat.add(a2, c), L{2n, 1n, 0n, 1n, 0n}, L{0n, 0n, 1n, 1n, 0n}, v,
    cv_add(1n, 1n+Nat.add(a, c), L{1n, 0n, 0n, 0n, 0n}, L{1n, 1n, 0n, 1n, 0n}, v, cv_c(1n, v), cv_add(1n, Nat.add(a, c), L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 1n, 0n}, v, cv_c(1n, v), cv_add(a, c, L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_1(a, a2, c, 0n), cv_3(a, a2, c, 0n)))),
    cv_add(a2, c, L{0n, 0n, 1n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_2(a, a2, c, 0n), cv_3(a, a2, c, 0n)), ng)
  +f_n2 = cvle(a2, 1n+a, L{0n, 0n, 1n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v,
    cv_2(a, a2, c, 0n),
    cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_1(a, a2, c, 0n)), n2)
  contra(L{2n, 1n, 1n, 1n, 0n}, L{1n, 1n, 1n, 1n, 0n}, v,
    comb(L{2n, 1n, 0n, 1n, 0n}, L{0n, 0n, 1n, 1n, 0n}, L{0n, 0n, 1n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v, f_ng,
    f_n2), {==})
def nearlo.c0b(+a: Nat, +a2: Nat, +c: Nat, n2: LE(a2, 1n+a)) -> LE(Nat.add(a2, c), 1n+Nat.add(a, c)):
  by_contra(Nat.add(a2, c), 1n+Nat.add(a, c), ng => nearlo.c0b.k(a, a2, c, ng, n2))

def nearlo.w0(+a: Nat, +a2: Nat, +c: Nat, +n1: LE(a, 1n+a2), +n2: LE(a2, 1n+a)) -> {near(Nat.add(a, c), Nat.add(a2, c)) == True{} : Bool}:
  and_i(Nat.is_le(Nat.add(a, c), 1n+Nat.add(a2, c)), Nat.is_le(Nat.add(a2, c), 1n+Nat.add(a, c)),
    nearlo.c0a(a, a2, c, n1),
    nearlo.c0b(a, a2, c, n2))

def nearhi.c0a.k(+a: Nat, +c: Nat, +c2: Nat, ng: LE(1n+1n+Nat.add(a, c2), Nat.add(a, c)), n1: LE(c, 1n+c2)) -> Empty:
  +v = {VS{a, c, c2, 0n} : Vs}
  +f_ng = cvle(1n+1n+Nat.add(a, c2), Nat.add(a, c), L{2n, 1n, 0n, 1n, 0n}, L{0n, 1n, 1n, 0n, 0n}, v,
    cv_add(1n, 1n+Nat.add(a, c2), L{1n, 0n, 0n, 0n, 0n}, L{1n, 1n, 0n, 1n, 0n}, v, cv_c(1n, v), cv_add(1n, Nat.add(a, c2), L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 1n, 0n}, v, cv_c(1n, v), cv_add(a, c2, L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_1(a, c, c2, 0n), cv_3(a, c, c2, 0n)))),
    cv_add(a, c, L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_1(a, c, c2, 0n), cv_2(a, c, c2, 0n)), ng)
  +f_n1 = cvle(c, 1n+c2, L{0n, 0n, 1n, 0n, 0n}, L{1n, 0n, 0n, 1n, 0n}, v,
    cv_2(a, c, c2, 0n),
    cv_add(1n, c2, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_c(1n, v), cv_3(a, c, c2, 0n)), n1)
  contra(L{2n, 1n, 1n, 1n, 0n}, L{1n, 1n, 1n, 1n, 0n}, v,
    comb(L{2n, 1n, 0n, 1n, 0n}, L{0n, 1n, 1n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, L{1n, 0n, 0n, 1n, 0n}, v, f_ng,
    f_n1), {==})
def nearhi.c0a(+a: Nat, +c: Nat, +c2: Nat, n1: LE(c, 1n+c2)) -> LE(Nat.add(a, c), 1n+Nat.add(a, c2)):
  by_contra(Nat.add(a, c), 1n+Nat.add(a, c2), ng => nearhi.c0a.k(a, c, c2, ng, n1))

def nearhi.c0b.k(+a: Nat, +c: Nat, +c2: Nat, ng: LE(1n+1n+Nat.add(a, c), Nat.add(a, c2)), n2: LE(c2, 1n+c)) -> Empty:
  +v = {VS{a, c, c2, 0n} : Vs}
  +f_ng = cvle(1n+1n+Nat.add(a, c), Nat.add(a, c2), L{2n, 1n, 1n, 0n, 0n}, L{0n, 1n, 0n, 1n, 0n}, v,
    cv_add(1n, 1n+Nat.add(a, c), L{1n, 0n, 0n, 0n, 0n}, L{1n, 1n, 1n, 0n, 0n}, v, cv_c(1n, v), cv_add(1n, Nat.add(a, c), L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 1n, 0n, 0n}, v, cv_c(1n, v), cv_add(a, c, L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_1(a, c, c2, 0n), cv_2(a, c, c2, 0n)))),
    cv_add(a, c2, L{0n, 1n, 0n, 0n, 0n}, L{0n, 0n, 0n, 1n, 0n}, v, cv_1(a, c, c2, 0n), cv_3(a, c, c2, 0n)), ng)
  +f_n2 = cvle(c2, 1n+c, L{0n, 0n, 0n, 1n, 0n}, L{1n, 0n, 1n, 0n, 0n}, v,
    cv_3(a, c, c2, 0n),
    cv_add(1n, c, L{1n, 0n, 0n, 0n, 0n}, L{0n, 0n, 1n, 0n, 0n}, v, cv_c(1n, v), cv_2(a, c, c2, 0n)), n2)
  contra(L{2n, 1n, 1n, 1n, 0n}, L{1n, 1n, 1n, 1n, 0n}, v,
    comb(L{2n, 1n, 1n, 0n, 0n}, L{0n, 1n, 0n, 1n, 0n}, L{0n, 0n, 0n, 1n, 0n}, L{1n, 0n, 1n, 0n, 0n}, v, f_ng,
    f_n2), {==})
def nearhi.c0b(+a: Nat, +c: Nat, +c2: Nat, n2: LE(c2, 1n+c)) -> LE(Nat.add(a, c2), 1n+Nat.add(a, c)):
  by_contra(Nat.add(a, c2), 1n+Nat.add(a, c), ng => nearhi.c0b.k(a, c, c2, ng, n2))

def nearhi.w0(+a: Nat, +c: Nat, +c2: Nat, +n1: LE(c, 1n+c2), +n2: LE(c2, 1n+c)) -> {near(Nat.add(a, c), Nat.add(a, c2)) == True{} : Bool}:
  and_i(Nat.is_le(Nat.add(a, c), 1n+Nat.add(a, c2)), Nat.is_le(Nat.add(a, c2), 1n+Nat.add(a, c)),
    nearhi.c0a(a, c, c2, n1),
    nearhi.c0b(a, c, c2, n2))

def nearrf.c0a.k(+a: Nat, ng: LE(1n+1n+a, a)) -> Empty:
  +v = {VS{a, 0n, 0n, 0n} : Vs}
  +f_ng = cvle(1n+1n+a, a, L{2n, 1n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, 1n+a, L{1n, 0n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_1(a, 0n, 0n, 0n))),
    cv_1(a, 0n, 0n, 0n), ng)
  contra(L{2n, 1n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    f_ng, {==})
def nearrf.c0a(+a: Nat) -> LE(a, 1n+a):
  by_contra(a, 1n+a, ng => nearrf.c0a.k(a, ng))

def nearrf.c0b.k(+a: Nat, ng: LE(1n+1n+a, a)) -> Empty:
  +v = {VS{a, 0n, 0n, 0n} : Vs}
  +f_ng = cvle(1n+1n+a, a, L{2n, 1n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, 1n+a, L{1n, 0n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_1(a, 0n, 0n, 0n))),
    cv_1(a, 0n, 0n, 0n), ng)
  contra(L{2n, 1n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    f_ng, {==})
def nearrf.c0b(+a: Nat) -> LE(a, 1n+a):
  by_contra(a, 1n+a, ng => nearrf.c0b.k(a, ng))

def nearrf.w0(+a: Nat) -> {near(a, a) == True{} : Bool}:
  and_i(Nat.is_le(a, 1n+a), Nat.is_le(a, 1n+a),
    nearrf.c0a(a),
    nearrf.c0b(a))

def nearpm.c0a.k(+a: Nat, ng: LE(1n+1n+a, 1n+a)) -> Empty:
  +v = {VS{a, 0n, 0n, 0n} : Vs}
  +f_ng = cvle(1n+1n+a, 1n+a, L{2n, 1n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, 1n+a, L{1n, 0n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_1(a, 0n, 0n, 0n))),
    cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_1(a, 0n, 0n, 0n)), ng)
  contra(L{2n, 1n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v,
    f_ng, {==})
def nearpm.c0a(+a: Nat) -> LE(1n+a, 1n+a):
  by_contra(1n+a, 1n+a, ng => nearpm.c0a.k(a, ng))

def nearpm.c0b.k(+a: Nat, ng: LE(1n+1n+1n+a, a)) -> Empty:
  +v = {VS{a, 0n, 0n, 0n} : Vs}
  +f_ng = cvle(1n+1n+1n+a, a, L{3n, 1n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, 1n+1n+a, L{1n, 0n, 0n, 0n, 0n}, L{2n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_add(1n, 1n+a, L{1n, 0n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_1(a, 0n, 0n, 0n)))),
    cv_1(a, 0n, 0n, 0n), ng)
  contra(L{3n, 1n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    f_ng, {==})
def nearpm.c0b(+a: Nat) -> LE(a, 1n+1n+a):
  by_contra(a, 1n+1n+a, ng => nearpm.c0b.k(a, ng))

def nearpm.w0(+a: Nat) -> {near(1n+a, a) == True{} : Bool}:
  and_i(Nat.is_le(1n+a, 1n+a), Nat.is_le(a, 1n+1n+a),
    nearpm.c0a(a),
    nearpm.c0b(a))

def neargt.c0a.k(+a: Nat, ng: LE(1n+1n+a, Nat.add(a, 1n))) -> Empty:
  +v = {VS{a, 0n, 0n, 0n} : Vs}
  +f_ng = cvle(1n+1n+a, Nat.add(a, 1n), L{2n, 1n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, 1n+a, L{1n, 0n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_add(1n, a, L{1n, 0n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_1(a, 0n, 0n, 0n))),
    cv_add(a, 1n, L{0n, 1n, 0n, 0n, 0n}, L{1n, 0n, 0n, 0n, 0n}, v, cv_1(a, 0n, 0n, 0n), cv_c(1n, v)), ng)
  contra(L{2n, 1n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v,
    f_ng, {==})
def neargt.c0a(+a: Nat) -> LE(Nat.add(a, 1n), 1n+a):
  by_contra(Nat.add(a, 1n), 1n+a, ng => neargt.c0a.k(a, ng))

def neargt.c0b.k(+a: Nat, ng: LE(1n+1n+Nat.add(a, 1n), a)) -> Empty:
  +v = {VS{a, 0n, 0n, 0n} : Vs}
  +f_ng = cvle(1n+1n+Nat.add(a, 1n), a, L{3n, 1n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    cv_add(1n, 1n+Nat.add(a, 1n), L{1n, 0n, 0n, 0n, 0n}, L{2n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_add(1n, Nat.add(a, 1n), L{1n, 0n, 0n, 0n, 0n}, L{1n, 1n, 0n, 0n, 0n}, v, cv_c(1n, v), cv_add(a, 1n, L{0n, 1n, 0n, 0n, 0n}, L{1n, 0n, 0n, 0n, 0n}, v, cv_1(a, 0n, 0n, 0n), cv_c(1n, v)))),
    cv_1(a, 0n, 0n, 0n), ng)
  contra(L{3n, 1n, 0n, 0n, 0n}, L{0n, 1n, 0n, 0n, 0n}, v,
    f_ng, {==})
def neargt.c0b(+a: Nat) -> LE(a, 1n+Nat.add(a, 1n)):
  by_contra(a, 1n+Nat.add(a, 1n), ng => neargt.c0b.k(a, ng))

def neargt.w0(+a: Nat) -> {near(Nat.add(a, 1n), a) == True{} : Bool}:
  and_i(Nat.is_le(Nat.add(a, 1n), 1n+a), Nat.is_le(a, 1n+Nat.add(a, 1n)),
    neargt.c0a(a),
    neargt.c0b(a))
