# Unicode 17.0 general category, NFC/NFD, full case folding, and grapheme clusters. Source: https://github.com/paymog/bend-kit/tree/main/unicode
import Base
import ./tables.bend as T

# Text is a String of code points. Decode octets with the encoding package first.

# General category as its two-letter UCD alias: "Lu", "Nd", "Zs", ... Unassigned is "Cn".
def category(c: Char) -> String:
  Chr{+u} = c
  T.gc(u)

# Canonical combining class: 0 for a starter.
def ccc(c: Char) -> U32:
  Chr{+u} = c
  T.ccc(u)

# Hangul syllables decompose and compose by formula (Unicode §3.12).
def hangul.dec(+s: U32) -> String:
  +t = (s % 28 : U32)
  tail = Bool.pick(String, U32.is_eq(t, 0), SNil{}, SCon{Chr{(4519 + t : U32)}, SNil{}})
  SCon{Chr{(4352 + (s / 588) : U32)}, SCon{Chr{(4449 + ((s % 588) / 28) : U32)}, tail}}

def decomp.if(hangul: Bool, +s: U32, +c: U32) -> String:
  match hangul:
    case True{}:
      hangul.dec(s)
    case False{}:
      T.dec(c)

# The full canonical decomposition of c; c itself when it has none.
def decomp(+c: U32) -> String:
  +s = (c - 44032 : U32)
  decomp.if(U32.is_lt(s, 11172), s, c)

# Does the reversed output start with a mark of class above k?
def order.gt(acc: String, +k: U32) -> Bool:
  match acc:
    case SNil{}:
      False{}
    case SCon{Chr{+h}, t}:
      U32.is_lt(k, T.ccc(h))

# Canonical ordering: c, of class k > 0, goes past each mark of a higher class. go says whether acc's head is one.
def order.put(acc: String, go: Bool, +c: U32, +k: U32) -> String:
  match acc:
    case SNil{}:
      SCon{Chr{c}, SNil{}}
    case SCon{Chr{+h}, +t}:
      match go:
        case True{}:
          SCon{Chr{h}, order.put(t, order.gt(t, k), c, k)}
        case False{}:
          SCon{Chr{c}, SCon{Chr{h}, t}}

def nfd.put(starter: Bool, +acc: String, +c: U32, +k: U32) -> String:
  match starter:
    case True{}:
      SCon{Chr{c}, acc}
    case False{}:
      order.put(acc, order.gt(acc, k), c, k)

def nfd.push(d: String, acc: String) -> String:
  match d:
    case SNil{}:
      acc
    case SCon{Chr{+c}, t}:
      +k = T.ccc(c)
      nfd.push(t, nfd.put(U32.is_eq(k, 0), acc, c, k))

def nfd.go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+c}, t}:
      nfd.go(t, nfd.push(decomp(c), acc))

# Normalization Form D (UAX #15): full canonical decomposition, then canonical order.
def nfd(s: String) -> String:
  nfd.go(s, SNil{})

def hangul.lvt(ok: Bool, +a: U32, +t: U32) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{(a + t : U32)}
    case False{}:
      T.comp((4519 + t : U32), a)

def hangul.lv(ok: Bool, +a: U32, +b: U32) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      Some{(44032 + ((((a - 4352) * 21) + (b - 4449)) * 28) : U32)}
    case False{}:
      +t = (b - 4519 : U32)
      +s = (a - 44032 : U32)
      hangul.lvt(Bool.and(Bool.and(U32.is_lt(s, 11172), U32.is_eq((s % 28 : U32), 0)), Bool.and(U32.is_lt(0, t), U32.is_lt(t, 28))), a, t)

# The primary composite of a and b, if there is one.
def compose(+a: U32, +b: U32) -> Maybe<&2, U32>:
  hangul.lv(Bool.and(U32.is_lt((a - 4352 : U32), 19), U32.is_lt((b - 4449 : U32), 21)), a, b)

# Composition state: is there a starter, the starter, the class of the last pending mark
# (0 when none), the marks after the starter reversed, and the output reversed.
type Nfc is Data:
  Nfc{has: Bool, st: U32, last: U32, pend: String, out: String}

def nfc.flush(has: Bool, +s: U32, pend: String, out: String) -> String:
  match has:
    case True{}:
      String.append(pend, SCon{Chr{s}, out})
    case False{}:
      String.append(pend, out)

def nfc.miss(starter: Bool, +has: Bool, +s: U32, +last: U32, pend: String, out: String, +c: U32, +k: U32) -> Nfc:
  match starter:
    case True{}:
      Nfc{True{}, c, 0, SNil{}, nfc.flush(has, s, pend, out)}
    case False{}:
      Nfc{has, s, k, SCon{Chr{c}, pend}, out}

def nfc.hit(m: Maybe<&2, U32>, +has: Bool, +s: U32, +last: U32, pend: String, out: String, +c: U32, +k: U32) -> Nfc:
  match m:
    case Some{x}:
      Nfc{has, x, last, pend, out}
    case None{}:
      nfc.miss(U32.is_eq(k, 0), has, s, last, pend, out, c, k)

def nfc.try(free: Bool, +has: Bool, +s: U32, +last: U32, pend: String, out: String, +c: U32, +k: U32) -> Nfc:
  match free:
    case True{}:
      nfc.hit(compose(s, c), has, s, last, pend, out, c, k)
    case False{}:
      nfc.miss(U32.is_eq(k, 0), has, s, last, pend, out, c, k)

# c joins the starter unless a mark between them has class 0 or at least c's class.
def nfc.step(z: Nfc, +c: U32) -> Nfc:
  Nfc{+has, +s, +last, pend, out} = z
  +k = T.ccc(c)
  nfc.try(Bool.and(has, Bool.not(Bool.and(U32.is_ne(last, 0), U32.is_le(k, last)))), has, s, last, pend, out, c, k)

def nfc.go(s: String, z: Nfc) -> String:
  match s:
    case SNil{}:
      Nfc{+has, +st, last, pend, out} = z
      String.reverse(nfc.flush(has, st, pend, out))
    case SCon{Chr{+c}, t}:
      nfc.go(t, nfc.step(z, c))

# Normalization Form C (UAX #15): NFD, then canonical composition.
def nfc(s: String) -> String:
  nfc.go(nfd(s), Nfc{False{}, 0, 0, SNil{}, SNil{}})

def fold.go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+c}, t}:
      fold.go(t, String.reverse.go(T.fold(c), acc))

# Full case folding (CaseFolding.txt, statuses C and F): "Straße" folds to "strasse".
def fold(s: String) -> String:
  fold.go(s, SNil{})

# T.gb packs Grapheme_Cluster_Break in bits 0-3 (Other 0, CR 1, LF 2, Control 3, Extend 4,
# ZWJ 5, Regional_Indicator 6, Prepend 7, SpacingMark 8, L 9, V 10, T 11, LV 12, LVT 13),
# Extended_Pictographic in bit 4, and InCB in bits 5-6 (Consonant 1, Extend 2, Linker 3).
def gcb(+q: U32) -> U32:
  (q .&. 15 : U32)

def eq(+g: U32, +v: U32) -> Bool:
  U32.is_eq(g, v)

def hangul.join(+p: U32, +q: U32) -> Bool:
  +l = eq(p, 9) && (eq(q, 9) || eq(q, 10) || eq(q, 12) || eq(q, 13))
  +v = (eq(p, 12) || eq(p, 10)) && (eq(q, 10) || eq(q, 11))
  l || v || ((eq(p, 13) || eq(p, 11)) && eq(q, 11))

# UAX #29 GB3-GB13. ri: the regional indicators before q are odd in number.
# ep: 1 after ExtPict Extend*, 2 after ExtPict Extend* ZWJ.
# incb: 1 after an InCB consonant and extenders, 2 once a linker follows it.
def brk(+p: U32, +q: U32, +ri: Bool, +ep: U32, +incb: U32) -> Bool:
  +gp = gcb(p)
  +gq = gcb(q)
  +ctl = (U32.is_le(1, gp) && U32.is_le(gp, 3)) || (U32.is_le(1, gq) && U32.is_le(gq, 3))
  +glue = hangul.join(gp, gq) || eq(gq, 4) || eq(gq, 5) || eq(gq, 8) || eq(gp, 7)
  +conj = eq(incb, 2) && eq((q >> 5n : U32), 1)
  +emoji = eq(ep, 2) && U32.is_ne((q .&. 16 : U32), 0)
  +flag = eq(gp, 6) && eq(gq, 6) && ri
  Bool.not((eq(gp, 1) && eq(gq, 2)) || (Bool.not(ctl) && (glue || conj || emoji || flag)))

def next.ri(+p: U32, +q: U32, +ri: Bool) -> Bool:
  eq(gcb(q), 6) && Bool.not(eq(gcb(p), 6) && ri)

def next.ep(+q: U32, +ep: U32) -> U32:
  +more = Bool.pick(U32, eq(ep, 1) && eq(gcb(q), 5), 2, Bool.pick(U32, eq(ep, 1) && eq(gcb(q), 4), 1, 0))
  Bool.pick(U32, U32.is_ne((q .&. 16 : U32), 0), 1, more)

def next.incb(+q: U32, +incb: U32) -> U32:
  +i = (q >> 5n : U32)
  +on = U32.is_ne(incb, 0)
  +more = Bool.pick(U32, on && eq(i, 3), 2, Bool.pick(U32, on && eq(i, 2), incb, 0))
  Bool.pick(U32, eq(i, 1), 1, more)

# Segmentation state: the previous character's T.gb, ri, ep, incb, the current
# cluster reversed, and the finished clusters reversed.
type Gr is Data:
  Gr{p: U32, ri: Bool, ep: U32, incb: U32, cur: String, out: List<&2, String>}

def gr.cut(b: Bool, +q: U32, +ri: Bool, +ep: U32, +incb: U32, +c: U32, cur: String, out: List<&2, String>) -> Gr:
  match b:
    case True{}:
      Gr{q, ri, ep, incb, SCon{Chr{c}, SNil{}}, String.reverse(cur) <> out}
    case False{}:
      Gr{q, ri, ep, incb, SCon{Chr{c}, cur}, out}

def gr.step(z: Gr, +c: U32) -> Gr:
  Gr{+p, +ri, +ep, +incb, cur, out} = z
  +q = T.gb(c)
  gr.cut(brk(p, q, ri, ep, incb), q, next.ri(p, q, ri), next.ep(q, ep), next.incb(q, incb), c, cur, out)

def gr.go(s: String, z: Gr) -> List<&2, String>:
  match s:
    case SNil{}:
      Gr{p, ri, ep, incb, cur, out} = z
      List.reverse(&2, String, String.reverse(cur) <> out)
    case SCon{Chr{+c}, t}:
      gr.go(t, gr.step(z, c))

# Extended grapheme clusters (UAX #29): "e\u{301}x" is ["e\u{301}", "x"].
def graphemes(s: String) -> List<&2, String>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{+c}, t}:
      +q = T.gb(c)
      gr.go(t, Gr{q, next.ri(0, q, False{}), next.ep(q, 0), next.incb(q, 0), SCon{Chr{c}, SNil{}}, Nil{}})
