# Byte buffers packed four bytes to a U32, with bounds-checked access.
import Base

# Bytes{len, buf}: byte i is bits 8*(i%4) of buf[i/4]. buf has the fewest 2^d words
# that hold len bytes. Every byte at or past len is 0, so equal buffers have equal words.
# Out-of-range reads answer None and out-of-range writes do nothing; Array alone would wrap.
#   import ./bytes/bytes.bend as Bytes

type Bytes is Type:
  Bytes{len: U32, buf: Array<U32>}

def b8(+x: U32) -> U32:
  (x .&. 255 : U32)

def shift(+i: U32) -> Nat:
  U32.to_nat(((i .&. 3 : U32) * 8 : U32))

def words(+n: U32) -> U32:
  ((n + 3 : U32) >> 2n : U32)

# The fewest d with 2^d >= w.
def depth.go(f: Nat, more: Bool, +w: U32, +d: Nat, +cap: U32) -> Nat:
  match f:
    case 0n:
      d
    case 1n+p:
      match more:
        case False{}:
          d
        case True{}:
          depth.go(p, U32.is_lt((cap * 2 : U32), w), w, 1n+d, (cap * 2 : U32))

def depth(+w: U32) -> Nat:
  depth.go(32n, U32.is_lt(1, w), w, 0n, 1)

def alloc(+n: U32) -> Array<U32>:
  Array.new(U32, depth(words(n)), 0)

# Unchecked byte read and write. Callers keep i below len.
def peek.of(+sh: Nat, r: Array<U32> & U32) -> Array<U32> & U32:
  (a, w) = r
  (a, b8(U32.shrn(w, sh)))

def peek(a: Array<U32>, +i: U32) -> Array<U32> & U32:
  peek.of(shift(i), Array.get(U32, a, (i >> 2n : U32)))

def poke.of(+i: U32, +v: U32, r: Array<U32> & U32) -> Array<U32>:
  (a, w) = r
  +sh = shift(i)
  Array.set(U32, a, (i >> 2n : U32), ((w .&. ((255 << sh) .^. 4294967295)) .|. (b8(v) << sh) : U32))

def poke(a: Array<U32>, +i: U32, +v: U32) -> Array<U32>:
  poke.of(i, v, Array.get(U32, a, (i >> 2n : U32)))

# n bytes from src[s..] to dst[d..], one byte at a time.
# ponytail: byte loop; copy whole words when s and d are both word-aligned if copies get hot.
def copy.go(n: Nat, r: Array<U32> & U32, dst: Array<U32>, +s: U32, +d: U32) -> Array<U32> & Array<U32>:
  match n:
    case 0n:
      (a, v) = r
      (a, dst)
    case 1n+p:
      (a, v) = r
      copy.go(p, peek(a, (s + 1 : U32)), poke(dst, d, v), (s + 1 : U32), (d + 1 : U32))

def copy(n: Nat, src: Array<U32>, dst: Array<U32>, +s: U32, +d: U32) -> Array<U32> & Array<U32>:
  copy.go(n, peek(src, s), dst, s, d)

# n zero bytes.
def new(+n: U32) -> Bytes:
  Bytes{n, alloc(n)}

def length(b: Bytes) -> Bytes & U32:
  Bytes{+len, buf} = b
  (Bytes{len, buf}, len)

def get.some(+len: U32, r: Array<U32> & U32) -> Bytes & Maybe<&2, U32>:
  (a, v) = r
  (Bytes{len, a}, Some{v})

def get.if(ok: Bool, +len: U32, buf: Array<U32>, +i: U32) -> Bytes & Maybe<&2, U32>:
  match ok:
    case True{}:
      get.some(len, peek(buf, i))
    case False{}:
      (Bytes{len, buf}, None{})

# Byte i, or None when i >= len.
def get(b: Bytes, +i: U32) -> Bytes & Maybe<&2, U32>:
  Bytes{+len, buf} = b
  get.if(U32.is_lt(i, len), len, buf, i)

def set.if(ok: Bool, +len: U32, buf: Array<U32>, +i: U32, +v: U32) -> Bytes:
  match ok:
    case True{}:
      Bytes{len, poke(buf, i, v)}
    case False{}:
      Bytes{len, buf}

# Byte i becomes v & 255. Nothing changes when i >= len.
def set(b: Bytes, +i: U32, +v: U32) -> Bytes:
  Bytes{+len, buf} = b
  set.if(U32.is_lt(i, len), len, buf, i, v)

def from.go(s: String, a: Array<U32>, +i: U32, +w: U32) -> Array<U32>:
  match s:
    case SNil{}:
      a
    case SCon{Chr{+c}, t}:
      +w2 = (w .|. (b8(c) << shift(i)) : U32)
      from.go(t, Array.set(U32, a, (i >> 2n : U32), w2), (i + 1 : U32), Bool.pick(U32, U32.is_eq((i .&. 3 : U32), 3), 0, w2))

# A byte string (one Char per octet, as Wire and Http use) to Bytes. Each Char keeps its low 8 bits.
def from_string(+s: String) -> Bytes:
  +n = U32.from_nat(String.length(s))
  Bytes{n, from.go(s, alloc(n), 0, 0)}

def to.go(n: Nat, r: Array<U32> & U32, +i: U32, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      (a, v) = r
      to.go(p, peek(a, (i - 1 : U32)), (i - 1 : U32), SCon{Chr{v}, acc})

# Bytes to a byte string, one Char per octet.
def to_string(b: Bytes) -> String:
  Bytes{+len, buf} = b
  to.go(U32.to_nat(len), peek(buf, (len - 1 : U32)), (len - 1 : U32), SNil{})

def slice.fin(+len: U32, +m: U32, r: Array<U32> & Array<U32>) -> Bytes & Bytes:
  (a, c) = r
  (Bytes{len, a}, Bytes{m, c})

def slice.at(+len: U32, buf: Array<U32>, +s: U32, +m: U32) -> Bytes & Bytes:
  slice.fin(len, m, copy(U32.to_nat(m), buf, alloc(m), s, 0))

# The buffer back, and a copy of up to n bytes from start. Both ends are clamped to len.
def slice(b: Bytes, +start: U32, +n: U32) -> Bytes & Bytes:
  Bytes{+len, buf} = b
  +s = U32.min(start, len)
  slice.at(len, buf, s, U32.min(n, (len - s : U32)))

def append.fin(+n: U32, r: Array<U32> & Array<U32>) -> Bytes:
  (x, out) = r
  Bytes{n, out}

def append.two(+n: U32, +la: U32, +lb: U32, bb: Array<U32>, r: Array<U32> & Array<U32>) -> Bytes:
  (x, out) = r
  append.fin(n, copy(U32.to_nat(lb), bb, out, 0, la))

# a then b, in a new buffer.
def append(a: Bytes, b: Bytes) -> Bytes:
  Bytes{+la, ba} = a
  Bytes{+lb, bb} = b
  +n = (la + lb : U32)
  append.two(n, la, lb, bb, copy(U32.to_nat(la), ba, alloc(n), 0, 0))

# Does needle match at j? Short needles, so no early exit.
def at.go(needle: String, r: Array<U32> & U32, +j: U32, ok: Bool) -> Array<U32> & Bool:
  match needle:
    case SNil{}:
      (a, v) = r
      (a, ok)
    case SCon{Chr{+c}, t}:
      (a, +v) = r
      at.go(t, peek(a, (j + 1 : U32)), (j + 1 : U32), Bool.and(ok, U32.is_eq(v, c)))

def at(a: Array<U32>, +needle: String, +j: U32) -> Array<U32> & Bool:
  at.go(needle, peek(a, j), j, True{})

# ponytail: naive O(len * needle) search; add a first-byte skip or SWAR scan if find gets hot.
def find.go(f: Nat, r: Array<U32> & Bool, +needle: String, +i: U32) -> Array<U32> & Maybe<&2, U32>:
  match f:
    case 0n:
      (a, hit) = r
      (a, Bool.pick(Maybe<&2, U32>, hit, Some{i}, None{}))
    case 1n+p:
      (a, hit) = r
      match hit:
        case True{}:
          (a, Some{i})
        case False{}:
          find.go(p, at(a, needle, (i + 1 : U32)), needle, (i + 1 : U32))

def find.fin(+len: U32, r: Array<U32> & Maybe<&2, U32>) -> Bytes & Maybe<&2, U32>:
  (a, x) = r
  (Bytes{len, a}, x)

def find.at(big: Bool, +len: U32, buf: Array<U32>, +needle: String, +m: U32) -> Bytes & Maybe<&2, U32>:
  match big:
    case True{}:
      (Bytes{len, buf}, None{})
    case False{}:
      find.fin(len, find.go(U32.to_nat((len - m : U32)), at(buf, needle, 0), needle, 0))

# Index of the first match of needle (a byte string), or None. An empty needle matches at 0.
def find(b: Bytes, +needle: String) -> Bytes & Maybe<&2, U32>:
  Bytes{+len, buf} = b
  +m = U32.from_nat(String.length(needle))
  find.at(U32.is_lt(len, m), len, buf, needle, m)

# Compares whole words; same tells whether the previous pair matched.
def eq.go(n: Nat, same: Bool, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32) -> Array<U32> & Array<U32> & Bool:
  match n:
    case 0n:
      (x, v) = r
      (y, w) = s
      (x, y, same)
    case 1n+p:
      match same:
        case False{}:
          (x, v) = r
          (y, w) = s
          (x, y, False{})
        case True{}:
          (x, +v) = r
          (y, +w) = s
          eq.go(p, U32.is_eq(v, w), Array.get(U32, x, (i + 1 : U32)), Array.get(U32, y, (i + 1 : U32)), (i + 1 : U32))

def eq.fin(+la: U32, +lb: U32, r: Array<U32> & Array<U32> & Bool) -> Bytes & Bytes & Bool:
  (x, y, ok) = r
  (Bytes{la, x}, Bytes{lb, y}, ok)

def eq.len(same: Bool, +la: U32, xa: Array<U32>, +lb: U32, ya: Array<U32>) -> Bytes & Bytes & Bool:
  match same:
    case False{}:
      (Bytes{la, xa}, Bytes{lb, ya}, False{})
    case True{}:
      eq.fin(la, lb, eq.go(U32.to_nat(words(la)), True{}, Array.get(U32, xa, 0), Array.get(U32, ya, 0), 0))

# Both buffers back, and whether they hold the same bytes.
def eq(a: Bytes, b: Bytes) -> Bytes & Bytes & Bool:
  Bytes{+la, xa} = a
  Bytes{+lb, ya} = b
  eq.len(U32.is_eq(la, lb), la, xa, lb, ya)
