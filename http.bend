# HTTP/1.1 client for http and https, with DNS and TLS.
import Base
import ./about.bend as About
import ./wire.bend as Wire
import ./dns/dns.bend as Dns
import ./url/url.bend as Url

# HTTP/1.1 codec and client (RFC 9112) for http:// and https:// (OpenSSL 3 at run time).
# parse: start-line → field lines → blank → body length (§6.3); chunked (§7.1).
# Bodies are byte strings: one Char per octet, so lengths are exact.
# fetch reads until frame() says the response is whole. It returns Result, not Maybe.
# Build with -o for big bodies: the `bend file.bend` runner overflows on ~30 KB strings; native binaries do not.
#   import ./http.bend as Http

type Req is Data:
  Req{method: String, path: String, headers: Map<&2, List<&2, String>>, body: String}

type Res is Data:
  Res{status: U32, headers: Map<&2, List<&2, String>>, body: String}

# Why fetch failed. Wire errors keep the errno and the text the effect already had.
# ponytail: 60 and 110 are ETIMEDOUT on macOS and Linux. Windows is out of scope.
type Err is Data:
  ErrUrl{}
  ErrDns{}
  ErrConnect{code: U32, why: String}
  ErrTls{code: U32, why: String}
  ErrRead{code: U32, why: String}
  ErrWrite{code: U32, why: String}
  ErrTimeout{}
  ErrRedirect{}
  ErrBad{}

def err.late(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 60), U32.is_eq(code, 110))

def err.pick(e: Err, late: Bool) -> Err:
  match late:
    case True{}:
      ErrTimeout{}
    case False{}:
      e

def err.or_late(code: U32, e: Err) -> Err:
  err.pick(e, err.late(code))

type Fields is Data:
  FieldsBad{}
  FieldsOk{m: Map<&2, List<&2, String>>}

# One list per field name, in arrival order. header() is the first value.
# Set-Cookie is never joined. Encode writes one line per value.
def empty() -> Map<&2, List<&2, String>>:
  Map.new(&2, List<&2, String>)

def fields.of(r: Map<&2, List<&2, String>> & List<&2, String>) -> List<&2, String>:
  (h, xs) = r
  xs

def fields(+h: Map<&2, List<&2, String>>, k: String) -> List<&2, String>:
  fields.of(Map.get(List<&2, String>, Nil{}, h, k))

def header.first(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{v, t}:
      v

def header(+h: Map<&2, List<&2, String>>, k: String) -> String:
  header.first(fields(h, k))

def field.last(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{v, Nil{}}:
      v
    case Con{v, t}:
      field.last(t)

# Transfer-Encoding is a list; chunked, when present, is the last coding.
def header.last(+h: Map<&2, List<&2, String>>, k: String) -> String:
  field.last(fields(h, k))

def snoc(xs: List<&2, String>, v: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      [v]
    case Con{h, t}:
      Con{h, snoc(t, v)}

def set(m: Map<&2, List<&2, String>>, k: String, v: String) -> Map<&2, List<&2, String>>:
  Map.set(&2, List<&2, String>, m, k, [v])

def add(+m: Map<&2, List<&2, String>>, +k: String, v: String) -> Map<&2, List<&2, String>>:
  Map.set(&2, List<&2, String>, m, k, snoc(fields(m, k), v))

def sanitize.cons(ch: Char, rest: String, drop: Bool) -> String:
  match drop:
    case True{}:
      rest
    case False{}:
      SCon{ch, rest}

def sanitize(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      sanitize.cons(Chr{c}, sanitize(t), Bool.or(U32.is_eq(c, 13), U32.is_eq(c, 10)))

def drop_cr.if(+s: String, cr: Bool) -> String:
  match cr:
    case True{}:
      String.reverse(String.drop(String.reverse(s), 1n))
    case False{}:
      s

def drop_cr(+s: String) -> String:
  drop_cr.if(s, String.ends_with(s, "\r"))

def take_sp.go(s: String, +acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), SNil{})
    case SCon{Chr{+c}, +t}:
      Bool.pick(String & String, U32.is_eq(c, 32), (String.reverse(acc), t), take_sp.go(t, SCon{Chr{c}, acc}))

def take_sp(s: String) -> String & String:
  take_sp.go(s, SNil{})

def start_line.ver(m: String, pv: String & String) -> String & String & String:
  (p, v) = pv
  (m, p, drop_cr(v))

def start_line.rest(mr: String & String) -> String & String & String:
  (m, r) = mr
  start_line.ver(m, take_sp(r))

def start_line(s: String) -> String & String & String:
  start_line.rest(take_sp(s))

def split_at_blank.go(s: String, e: Bool, w: U32, acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), SNil{})
    case SCon{Chr{+a}, t}:
      match e:
        case True{}:
          (String.reverse(acc), SCon{Chr{a}, t})
        case False{}:
          +w2 = (w * 256 + a : U32)
          split_at_blank.go(t, U32.is_eq(w2, 218762506), w2, SCon{Chr{a}, acc})

def split_at_blank(s: String) -> String & String:
  split_at_blank.go(s, False{}, 0, SNil{})

def split_colon.go(s: String, +acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), SNil{})
    case SCon{Chr{+c}, +t}:
      Bool.pick(String & String, U32.is_eq(c, 58), (String.reverse(acc), t), split_colon.go(t, SCon{Chr{c}, acc}))

def split_colon(s: String) -> String & String:
  split_colon.go(s, SNil{})

def has_header.of(r: Map<&2, List<&2, String>> & Bool) -> Bool:
  (h, b) = r
  b

def has_header(+h: Map<&2, List<&2, String>>, k: String) -> Bool:
  has_header.of(Map.has(&2, List<&2, String>, h, k))

def folded(+line: String) -> Bool:
  Bool.or(String.starts_with(line, " "), String.starts_with(line, "\t"))

def tracked(+k: String) -> Bool:
  Bool.or(String.eq(k, "host"), String.eq(k, "content-length"))

def fields_put.dup(m: Map<&2, List<&2, String>>, k: String, v: String, bad: Bool) -> Fields:
  match bad:
    case True{}:
      FieldsBad{}
    case False{}:
      FieldsOk{add(m, k, v)}

def fields_put.key(+m: Map<&2, List<&2, String>>, +k: String, v: String) -> Fields:
  fields_put.dup(m, k, v, Bool.and(tracked(k), has_header(m, k)))

def fields_put.kv(m: Map<&2, List<&2, String>>, kv: String & String) -> Fields:
  (k, v) = kv
  fields_put.key(m, String.to_lower(k), String.trim(v))

def fields_put.fold(m: Map<&2, List<&2, String>>, line: String, fold: Bool) -> Fields:
  match fold:
    case True{}:
      FieldsBad{}
    case False{}:
      fields_put.kv(m, split_colon(line))

def fields_put.empty(m: Map<&2, List<&2, String>>, +line: String, e: Bool) -> Fields:
  match e:
    case True{}:
      FieldsOk{m}
    case False{}:
      fields_put.fold(m, line, folded(line))

def fields_put.ok(m: Map<&2, List<&2, String>>, +line: String) -> Fields:
  fields_put.empty(m, line, String.is_empty(line))

def fields_put(acc: Fields, line: String) -> Fields:
  match acc:
    case FieldsBad{}:
      FieldsBad{}
    case FieldsOk{m}:
      fields_put.ok(m, line)

def parse.headers.done(acc: Fields) -> Maybe<&2, Map<&2, List<&2, String>>>:
  match acc:
    case FieldsBad{}:
      None{}
    case FieldsOk{m}:
      Some{m}

def parse.headers(xs: List<&2, String>, acc: Fields) -> Maybe<&2, Map<&2, List<&2, String>>>:
  match xs:
    case Nil{}:
      parse.headers.done(acc)
    case Con{line, rest}:
      parse.headers(rest, fields_put(acc, drop_cr(line)))

def parse_u32.digit(+c: U32) -> Bool:
  Bool.and(U32.is_le(48, c), U32.is_le(c, 57))

def parse_u32.add(acc: U32, c: U32) -> U32:
  (acc * 10 + (c - 48 : U32) : U32)

def parse_u32.done(acc: U32, bad: Bool) -> Maybe<&2, U32>:
  match bad:
    case True{}:
      None{}
    case False{}:
      Some{acc}

def parse_u32.go(s: String, acc: U32, bad: Bool) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      parse_u32.done(acc, bad)
    case SCon{Chr{+c}, t}:
      parse_u32.go(t, parse_u32.add(acc, c), Bool.or(bad, Bool.not(parse_u32.digit(c))))

def parse_u32(s: String) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, t}:
      parse_u32.go(t, parse_u32.add(0, c), Bool.not(parse_u32.digit(c)))



def parse.take.if(+rest: String, +k: Nat, short: Bool) -> Maybe<&2, String>:
  match short:
    case True{}:
      None{}
    case False{}:
      Some{String.take(rest, k)}

# RFC 9112 §8: fewer bytes than Content-Length is an incomplete message.
def parse.take.have(+rest: String, +k: Nat) -> Maybe<&2, String>:
  parse.take.if(rest, k, Nat.is_lt(String.length(rest), k))

def parse.take(rest: String, n: Maybe<&2, U32>) -> Maybe<&2, String>:
  match n:
    case None{}:
      None{}
    case Some{k}:
      parse.take.have(rest, U32.to_nat(k))

type HexSize is Data:
  HexSize{n: U32, rest: String}

type Step is Data:
  StepFail{}
  StepDone{body: String}
  StepNext{rest: String, acc: String}

def is_hex(+c: U32) -> Bool:
  Bool.or(parse_u32.digit(c), Bool.or(Bool.and(U32.is_le(97, c), U32.is_le(c, 102)), Bool.and(U32.is_le(65, c), U32.is_le(c, 70))))

def hexv(+c: U32) -> U32:
  Bool.pick(U32, parse_u32.digit(c), (c - 48 : U32), Bool.pick(U32, U32.is_le(c, 70), (c - 55 : U32), (c - 87 : U32)))

def chunk.lf1(r: String, n: U32, lf: Bool) -> Maybe<&2, HexSize>:
  match lf:
    case True{}:
      Some{HexSize{n, r}}
    case False{}:
      None{}

def chunk.lf(t: String, n: U32) -> Maybe<&2, HexSize>:
  match t:
    case SNil{}:
      None{}
    case SCon{Chr{c}, r}:
      chunk.lf1(r, n, U32.is_eq(c, 10))

# Bool.pick evaluates both arms, so a loop that recursed inside it would scan
# the whole body at every byte. These loops classify the next char into a
# Bool param and recurse only in the arm that matches.

def chunk.ext.go(t: String, +c: U32, +n: U32, stop: Bool) -> Maybe<&2, HexSize>:
  match t:
    case SNil{}:
      None{}
    case SCon{Chr{+d}, u}:
      match stop:
        case True{}:
          chunk.lf1(u, n, Bool.and(U32.is_eq(c, 13), U32.is_eq(d, 10)))
        case False{}:
          chunk.ext.go(u, d, n, Bool.or(U32.is_eq(d, 13), U32.is_eq(d, 10)))

# RFC 9112 §7.1.1: recipients ignore unknown chunk extensions; a bare LF is not CRLF.
def chunk.ext(s: String, n: U32) -> Maybe<&2, HexSize>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, t}:
      chunk.ext.go(t, c, n, Bool.or(U32.is_eq(c, 13), U32.is_eq(c, 10)))

def chunk.size.end(+c: U32, +t: String, +n: U32, seen: Bool) -> Maybe<&2, HexSize>:
  match seen:
    case False{}:
      None{}
    case True{}:
      Bool.pick(Maybe<&2, HexSize>, U32.is_eq(c, 13), chunk.lf(t, n), Bool.pick(Maybe<&2, HexSize>, U32.is_eq(c, 59), chunk.ext(t, n), None{}))

# A size that would overflow 32 bits ends the digits, and size.end then refuses it.
def chunk.digit(+c: U32, +acc: U32) -> Bool:
  Bool.and(is_hex(c), U32.is_le(acc, 268435455))

def chunk.size.go(t: String, +c: U32, +acc: U32, seen: Bool, digit: Bool) -> Maybe<&2, HexSize>:
  match t:
    case SNil{}:
      None{}
    case SCon{Chr{+d}, u}:
      match digit:
        case False{}:
          chunk.size.end(c, SCon{Chr{d}, u}, acc, seen)
        case True{}:
          +acc2 = (acc * 16 + hexv(c) : U32)
          chunk.size.go(u, d, acc2, True{}, chunk.digit(d, acc2))

def chunk.size(s: String) -> Maybe<&2, HexSize>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, t}:
      chunk.size.go(t, c, 0, False{}, chunk.digit(c, 0))

# The body is built reversed (racc) and turned around once at the end.

def chunk.trailer.ok(racc: String, ok: Bool) -> Step:
  match ok:
    case True{}:
      StepDone{String.reverse(racc)}
    case False{}:
      StepFail{}

def chunk.trailer.end(hb: String & String, racc: String) -> Step:
  (+h, r) = hb
  chunk.trailer.ok(racc, String.ends_with(h, "\r\n\r\n"))

def chunk.trailer.if(rest: String, racc: String, blank: Bool) -> Step:
  match blank:
    case True{}:
      StepDone{String.reverse(racc)}
    case False{}:
      chunk.trailer.end(split_at_blank(rest), racc)

# ponytail: trailer fields are dropped unparsed (§7.1.2 allows discarding)
def chunk.trailer(+rest: String, racc: String) -> Step:
  chunk.trailer.if(rest, racc, String.starts_with(rest, "\r\n"))

type Took is Data:
  Took{racc: String, rest: String}

# Moves exactly k chars onto racc; None if s runs out first. O(k), no length scan.
def take.exact(s: String, k: Nat, racc: String) -> Maybe<&2, Took>:
  match s:
    case SNil{}:
      match k:
        case 0n:
          Some{Took{racc, SNil{}}}
        case 1n+j:
          None{}
    case SCon{c, t}:
      match k:
        case 0n:
          Some{Took{racc, SCon{c, t}}}
        case 1n+j:
          take.exact(t, j, SCon{c, racc})

def chunk.crlf.if(racc: String, +after: String, ok: Bool) -> Step:
  match ok:
    case True{}:
      StepNext{String.drop(after, 2n), racc}
    case False{}:
      StepFail{}

def chunk.data(m: Maybe<&2, Took>) -> Step:
  match m:
    case None{}:
      StepFail{}
    case Some{Took{racc, +after}}:
      chunk.crlf.if(racc, after, String.starts_with(after, "\r\n"))

def chunk.step.n(+n: U32, rest: String, racc: String, zero: Bool) -> Step:
  match zero:
    case True{}:
      chunk.trailer(rest, racc)
    case False{}:
      chunk.data(take.exact(rest, U32.to_nat(n), racc))

def chunk.step.got(got: Maybe<&2, HexSize>, racc: String) -> Step:
  match got:
    case None{}:
      StepFail{}
    case Some{HexSize{+n, rest}}:
      chunk.step.n(n, rest, racc, U32.is_eq(n, 0))

def chunk.step(s: String, racc: String) -> Step:
  chunk.step.got(chunk.size(s), racc)

def chunk.go(fuel: Nat, st: Step) -> Maybe<&2, String>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      match st:
        case StepFail{}:
          None{}
        case StepDone{b}:
          Some{b}
        case StepNext{r, a}:
          chunk.go(f, chunk.step(r, a))

# Every chunk eats at least 3 bytes, so length(s) steps always suffice.
def chunk.decode(+s: String) -> Maybe<&2, String>:
  chunk.go(String.length(s), chunk.step(s, ""))

def parse.body.cl(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Maybe<&2, String>:
  match hascl:
    case False{}:
      Some{""}
    case True{}:
      parse.take(rest, parse_u32(header(h, "content-length")))

def parse.body.chunked.eq(rest: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case False{}:
      None{}
    case True{}:
      chunk.decode(rest)

def parse.body.chunked.val(te: String, rest: String) -> Maybe<&2, String>:
  parse.body.chunked.eq(rest, String.eq(String.to_lower(te), "chunked"))

def parse.body.chunked(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Maybe<&2, String>:
  match hascl:
    case True{}:
      None{}
    case False{}:
      parse.body.chunked.val(header.last(h, "transfer-encoding"), rest)

def parse.body.te(+h: Map<&2, List<&2, String>>, rest: String, te: Bool) -> Maybe<&2, String>:
  match te:
    case True{}:
      parse.body.chunked(h, rest, has_header(h, "content-length"))
    case False{}:
      parse.body.cl(h, rest, has_header(h, "content-length"))

def parse.body(+h: Map<&2, List<&2, String>>, rest: String) -> Maybe<&2, String>:
  parse.body.te(h, rest, has_header(h, "transfer-encoding"))

def parse.finish(method: String, path: String, h: Map<&2, List<&2, String>>, body: Maybe<&2, String>) -> Maybe<&2, Req>:
  match body:
    case None{}:
      None{}
    case Some{b}:
      Some{Req{method, path, h, b}}

def parse.host(method: String, path: String, +h: Map<&2, List<&2, String>>, rest: String, has: Bool) -> Maybe<&2, Req>:
  match has:
    case False{}:
      None{}
    case True{}:
      parse.finish(method, path, h, parse.body(h, rest))

def parse.fields(method: String, path: String, rest: String, fs: Maybe<&2, Map<&2, List<&2, String>>>) -> Maybe<&2, Req>:
  match fs:
    case None{}:
      None{}
    case Some{+h}:
      parse.host(method, path, h, rest, has_header(h, "host"))

def target_ok(+p: String) -> Bool:
  Bool.or(String.starts_with(p, "/"), Bool.or(String.eq(p, "*"), String.starts_with(p, "http://")))

def parse.target(method: String, +path: String, headers: List<&2, String>, rest: String, ok: Bool) -> Maybe<&2, Req>:
  match ok:
    case False{}:
      None{}
    case True{}:
      parse.fields(method, path, rest, parse.headers(headers, FieldsOk{empty()}))

def parse.ver(method: String, +path: String, v: String, headers: List<&2, String>, rest: String, ok: Bool) -> Maybe<&2, Req>:
  match ok:
    case False{}:
      None{}
    case True{}:
      parse.target(method, path, headers, rest, target_ok(path))

def parse.empty_method(method: String, path: String, +v: String, headers: List<&2, String>, rest: String, empty: Bool) -> Maybe<&2, Req>:
  match empty:
    case True{}:
      None{}
    case False{}:
      parse.ver(method, path, v, headers, rest, String.eq(v, "HTTP/1.1"))

def parse.start3(mpv: String & String & String, headers: List<&2, String>, rest: String) -> Maybe<&2, Req>:
  (+method, path, v) = mpv
  parse.empty_method(method, path, v, headers, rest, String.is_empty(method))

def parse.lines(xs: List<&2, String>, rest: String) -> Maybe<&2, Req>:
  match xs:
    case Nil{}:
      None{}
    case Con{line, headers}:
      parse.start3(start_line(line), headers, rest)

def parse.head(head: String, rest: String) -> Maybe<&2, Req>:
  parse.lines(String.lines(head), rest)

def parse.of(hb: String & String) -> Maybe<&2, Req>:
  (head, rest) = hb
  parse.head(head, rest)

def parse(raw: String) -> Maybe<&2, Req>:
  parse.of(split_at_blank(raw))

def parse.res.cl(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Maybe<&2, String>:
  match hascl:
    case False{}:
      Some{rest}
    case True{}:
      parse.take(rest, parse_u32(header(h, "content-length")))

def parse.res.te(+h: Map<&2, List<&2, String>>, rest: String, te: Bool) -> Maybe<&2, String>:
  match te:
    case True{}:
      parse.body.chunked(h, rest, has_header(h, "content-length"))
    case False{}:
      parse.res.cl(h, rest, has_header(h, "content-length"))

def parse.res.body(+h: Map<&2, List<&2, String>>, rest: String) -> Maybe<&2, String>:
  parse.res.te(h, rest, has_header(h, "transfer-encoding"))

# Bad: never a message. More: a valid prefix; read on. Done: a whole response.
type Frame is Data:
  FrameBad{}
  FrameMore{}
  FrameDone{res: Res}

# RFC 9112 §8: a message cut short by close is incomplete, not valid.
def frame.cut(closed: Bool) -> Frame:
  match closed:
    case True{}:
      FrameBad{}
    case False{}:
      FrameMore{}

def frame.wait(res: Res, wait: Bool) -> Frame:
  match wait:
    case True{}:
      FrameMore{}
    case False{}:
      FrameDone{res}

def frame.done(status: U32, h: Map<&2, List<&2, String>>, body: Maybe<&2, String>, +closed: Bool, open: Bool) -> Frame:
  match body:
    case None{}:
      frame.cut(closed)
    case Some{b}:
      frame.wait(Res{status, h, b}, Bool.and(open, Bool.not(closed)))

# RFC 9112 §6.3 (8): no TE and no CL ⇒ the body runs until the server closes.
def frame.open(+h: Map<&2, List<&2, String>>) -> Bool:
  Bool.not(Bool.or(has_header(h, "transfer-encoding"), has_header(h, "content-length")))

# RFC 9112 §6.3 (1): HEAD, 1xx, 204 and 304 responses end at the blank line.
# ponytail: 1xx is returned as final; skip interim responses if a server sends 103
def frame.nobody(+status: U32, head: Bool) -> Bool:
  Bool.or(head, Bool.or(U32.is_lt(status, 200), Bool.or(U32.is_eq(status, 204), U32.is_eq(status, 304))))

def frame.status(status: U32, +h: Map<&2, List<&2, String>>, rest: String, closed: Bool, nobody: Bool) -> Frame:
  match nobody:
    case True{}:
      FrameDone{Res{status, h, ""}}
    case False{}:
      frame.done(status, h, parse.res.body(h, rest), closed, frame.open(h))

def parse.res.fields(+status: U32, rest: String, fs: Maybe<&2, Map<&2, List<&2, String>>>, closed: Bool, head: Bool) -> Frame:
  match fs:
    case None{}:
      FrameBad{}
    case Some{h}:
      frame.status(status, h, rest, closed, frame.nobody(status, head))

def parse.res.num(code: Maybe<&2, U32>, headers: List<&2, String>, rest: String, closed: Bool, head: Bool) -> Frame:
  match code:
    case None{}:
      FrameBad{}
    case Some{n}:
      parse.res.fields(n, rest, parse.headers(headers, FieldsOk{empty()}), closed, head)

def parse.res.ver(code: String, headers: List<&2, String>, rest: String, closed: Bool, head: Bool, ok: Bool) -> Frame:
  match ok:
    case False{}:
      FrameBad{}
    case True{}:
      parse.res.num(parse_u32(code), headers, rest, closed, head)

def parse.res.start3(mpv: String & String & String, headers: List<&2, String>, rest: String, closed: Bool, head: Bool) -> Frame:
  (+ver, code, reason) = mpv
  parse.res.ver(code, headers, rest, closed, head, Bool.or(String.eq(ver, "HTTP/1.1"), String.eq(ver, "HTTP/1.0")))

def parse.res.lines(xs: List<&2, String>, rest: String, closed: Bool, head: Bool) -> Frame:
  match xs:
    case Nil{}:
      FrameBad{}
    case Con{line, headers}:
      parse.res.start3(start_line(line), headers, rest, closed, head)

def parse.res.blank(hd: String, rest: String, +closed: Bool, head: Bool, ok: Bool) -> Frame:
  match ok:
    case False{}:
      frame.cut(closed)
    case True{}:
      parse.res.lines(String.lines(hd), rest, closed, head)

def parse.res.of(hb: String & String, closed: Bool, head: Bool) -> Frame:
  (+hd, rest) = hb
  parse.res.blank(hd, rest, closed, head, String.ends_with(hd, "\r\n\r\n"))

# frame(bytes so far, server closed?, request was HEAD?)
def frame(raw: String, closed: Bool, head: Bool) -> Frame:
  parse.res.of(split_at_blank(raw), closed, head)

def frame.res(f: Frame) -> Maybe<&2, Res>:
  match f:
    case FrameDone{res}:
      Some{res}
    case FrameBad{}:
      None{}
    case FrameMore{}:
      None{}

def parse_res(raw: String) -> Maybe<&2, Res>:
  frame.res(frame(raw, True{}, False{}))

def res_fields.res(res: Res, k: String) -> List<&2, String>:
  Res{status, headers, body} = res
  fields(headers, k)

def res_fields(m: Maybe<&2, Res>, k: String) -> List<&2, String>:
  match m:
    case None{}:
      Nil{}
    case Some{res}:
      res_fields.res(res, k)

# When can a response be whole? fetch uses this to skip re-framing a growing
# buffer after every read. Head: the header block is not in yet. Len: the
# message is total bytes long. Chunk: it ends with CRLF CRLF. Close: only at
# close. Now: frame it at once (no body, or already malformed).
type Need is Data:
  NeedHead{}
  NeedLen{total: Nat}
  NeedChunk{}
  NeedClose{}
  NeedNow{}

def need.cl(hlen: Nat, n: Maybe<&2, U32>) -> Need:
  match n:
    case None{}:
      NeedNow{}
    case Some{k}:
      NeedLen{Nat.add(hlen, U32.to_nat(k))}

def need.framing(+h: Map<&2, List<&2, String>>, hlen: Nat, te: Bool, cl: Bool) -> Need:
  match te:
    case True{}:
      Bool.pick(Need, Bool.or(cl, Bool.not(String.eq(String.to_lower(header.last(h, "transfer-encoding")), "chunked"))), NeedNow{}, NeedChunk{})
    case False{}:
      match cl:
        case True{}:
          need.cl(hlen, parse_u32(header(h, "content-length")))
        case False{}:
          NeedClose{}

def need.fields(hlen: Nat, nobody: Bool, fs: Maybe<&2, Map<&2, List<&2, String>>>) -> Need:
  match nobody:
    case True{}:
      NeedNow{}
    case False{}:
      match fs:
        case None{}:
          NeedNow{}
        case Some{+h}:
          need.framing(h, hlen, has_header(h, "transfer-encoding"), has_header(h, "content-length"))

def need.num(code: Maybe<&2, U32>, headers: List<&2, String>, hlen: Nat, head: Bool) -> Need:
  match code:
    case None{}:
      NeedNow{}
    case Some{+n}:
      need.fields(hlen, frame.nobody(n, head), parse.headers(headers, FieldsOk{empty()}))

def need.start3(mpv: String & String & String, headers: List<&2, String>, hlen: Nat, head: Bool) -> Need:
  (ver, code, reason) = mpv
  need.num(parse_u32(code), headers, hlen, head)

def need.lines(xs: List<&2, String>, hlen: Nat, head: Bool) -> Need:
  match xs:
    case Nil{}:
      NeedNow{}
    case Con{line, headers}:
      need.start3(start_line(line), headers, hlen, head)

def need.blank(+hd: String, head: Bool, ok: Bool) -> Need:
  match ok:
    case False{}:
      NeedHead{}
    case True{}:
      need.lines(String.lines(hd), String.length(hd), head)

def need.of(hb: String & String, head: Bool) -> Need:
  (+hd, rest) = hb
  need.blank(hd, head, String.ends_with(hd, "\r\n\r\n"))

# A hint only: frame() stays the judge of every byte.
def need(raw: String, head: Bool) -> Need:
  need.of(split_at_blank(raw), head)

def res_body.res(res: Res) -> String:
  Res{status, headers, body} = res
  body

def res_body(m: Maybe<&2, Res>) -> String:
  match m:
    case None{}:
      ""
    case Some{res}:
      res_body.res(res)

def got_body.req(req: Req) -> String:
  Req{method, path, headers, body} = req
  body

def got_body(m: Maybe<&2, Req>) -> String:
  match m:
    case None{}:
      ""
    case Some{req}:
      got_body.req(req)

def body.of(hb: String & String) -> String:
  (h, b) = hb
  b

def body(s: String) -> String:
  body.of(split_at_blank(s))

def headers_lines(+k: String, vs: List<&2, String>, acc: String) -> String:
  match vs:
    case Nil{}:
      acc
    case Con{v, t}:
      headers_lines(k, t, acc ++ ("\r\n" ++ sanitize(k) ++ ": " ++ sanitize(v)))

def headers_block.go(xs: List<&2, Sigma<&2, &2, String, _ => List<&2, String>>>, acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case (k, vs) <> t:
      headers_block.go(t, headers_lines(k, vs, acc))

def headers_block(h: Map<&2, List<&2, String>>) -> String:
  headers_block.go(Map.to_list(&2, List<&2, String>, h), "")

def response(status: U32, headers: Map<&2, List<&2, String>>, body: String) -> String:
  ("HTTP/1.1 " ++ U32.show(status) ++ " OK" ++ headers_block(headers)) ++ ("\r\n\r\n" ++ body)

def nat_u32(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      (nat_u32(p) + 1 : U32)

def encode(r: Res) -> String:
  Res{status, headers, +body} = r
  response(status, set(headers, "content-length", U32.show(nat_u32(String.length(body)))), body)

def request(method: String, path: String, headers: Map<&2, List<&2, String>>, body: String) -> String:
  (method ++ " " ++ path ++ " HTTP/1.1" ++ headers_block(headers)) ++ ("\r\n\r\n" ++ body)

def req.reserved(+k: String) -> Bool:
  Bool.or(Bool.or(String.eq(k, "host"), String.eq(k, "connection")), Bool.or(String.eq(k, "content-length"), String.eq(k, "transfer-encoding")))

def req.put.one(m: Map<&2, List<&2, String>>, +k: String, vs: List<&2, String>, skip: Bool) -> Map<&2, List<&2, String>>:
  match skip:
    case True{}:
      m
    case False{}:
      Map.set(&2, List<&2, String>, m, k, vs)

def req.put(xs: List<&2, Sigma<&2, &2, String, _ => List<&2, String>>>, m: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  match xs:
    case Nil{}:
      m
    case (k, vs) <> t:
      +lk = String.to_lower(k)
      req.put(t, req.put.one(m, lk, vs, req.reserved(lk)))

# RFC 9110 §8.6: no Content-Length on a bodiless request whose method gives a body no meaning.
def req.cl(+m: Map<&2, List<&2, String>>, +method: String, +body: String) -> Map<&2, List<&2, String>>:
  +bodied = Bool.or(Bool.not(String.is_empty(body)), Bool.or(String.eq(method, "POST"), Bool.or(String.eq(method, "PUT"), String.eq(method, "PATCH"))))
  Bool.pick(Map<&2, List<&2, String>>, bodied, set(m, "content-length", U32.show(nat_u32(String.length(body)))), m)

# Caller headers are lowercased so they cannot duplicate ours; host, connection,
# content-length and transfer-encoding are always ours (no smuggling through them).
def encode_req(+method: String, target: String, host: String, headers: Map<&2, List<&2, String>>, +body: String) -> String:
  +h = set(set(req.put(Map.to_list(&2, List<&2, String>, headers), empty()), "host", host), "connection", "close")
  request(method, target, req.cl(h, method, body), body)

# Redirects (RFC 9110 §15.4, as WHATWG fetch applies them)
# --------------------------------------------------------

# One request to make: headers are already lowercased (see req.put).
type Hop is Data:
  Hop{method: String, url: Url.Abs, headers: Map<&2, List<&2, String>>, body: String}

def redirect.code(+s: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(s, 301), U32.is_eq(s, 302)), Bool.or(U32.is_eq(s, 303), Bool.or(U32.is_eq(s, 307), U32.is_eq(s, 308))))

def redirect.origin(a: Url.Abs) -> String:
  Url.Abs{scheme, host, port, target} = a
  scheme ++ "://" ++ host ++ ":" ++ U32.show(port)

def redirect.del(ks: List<&2, String>, m: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  match ks:
    case Nil{}:
      m
    case Con{k, t}:
      redirect.del(t, Map.del(&2, List<&2, String>, m, k))

def redirect.hdrs(+h: Map<&2, List<&2, String>>, drop: Bool, cross: Bool) -> Map<&2, List<&2, String>>:
  +h2 = Bool.pick(Map<&2, List<&2, String>>, drop, redirect.del(["content-type", "content-encoding", "content-language", "content-location"], h), h)
  Bool.pick(Map<&2, List<&2, String>>, cross, redirect.del(["authorization", "cookie", "proxy-authorization"], h2), h2)

# 303 turns any method but HEAD into GET; 301 and 302 turn POST into GET;
# 307 and 308 keep method and body. A GET carries no body or body headers.
# Credentials do not follow a hop to another origin.
def redirect.to(+status: U32, +method: String, +from: Url.Abs, headers: Map<&2, List<&2, String>>, +body: String, next: Maybe<&2, Url.Abs>) -> Maybe<&2, Hop>:
  match next:
    case None{}:
      None{}
    case Some{+to}:
      +drop = Bool.or(Bool.and(U32.is_eq(status, 303), Bool.not(String.eq(method, "HEAD"))), Bool.and(Bool.or(U32.is_eq(status, 301), U32.is_eq(status, 302)), String.eq(method, "POST")))
      Some{Hop{Bool.pick(String, drop, "GET", method), to, redirect.hdrs(headers, drop, Bool.not(String.eq(redirect.origin(from), redirect.origin(to)))), Bool.pick(String, drop, "", body)}}

def redirect.hop(status: U32, h: Hop, loc: String) -> Maybe<&2, Hop>:
  Hop{method, +url, headers, body} = h
  redirect.to(status, method, url, headers, body, Url.resolve(url, loc))

def redirect.if(status: U32, h: Hop, loc: String, ok: Bool) -> Maybe<&2, Hop>:
  match ok:
    case False{}:
      None{}
    case True{}:
      redirect.hop(status, h, loc)

# The next request after a response, or None when it is not a redirect we follow.
def redirect(+status: U32, +headers: Map<&2, List<&2, String>>, h: Hop) -> Maybe<&2, Hop>:
  redirect.if(status, h, header(headers, "location"), Bool.and(redirect.code(status), has_header(headers, "location")))

# Transport: plain TCP or TLS over the same socket.
def io.recv(tls: Bool, s: Socket, max: U32, ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, String>):
  match tls:
    case True{}:
      Wire.tls.recv(s, max, ms)
    case False{}:
      Wire.recv(s, max, ms)

def io.send(tls: Bool, s: Socket, data: String) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match tls:
    case True{}:
      Wire.tls.send(s, data)
    case False{}:
      Wire.send(s, data)

def io.close(tls: Bool, s: Socket) -> IO(Unit):
  match tls:
    case True{}:
      Wire.tls.close(s)
    case False{}:
      Socket.close(s)

def fetch.close(tls: Bool, s: Socket, r: Result<&2, &2, Err, Res>) -> IO(Result<&2, &2, Err, Res>):
  do IO<Result<&2, &2, Err, Res>>:
    io.close(tls, s)
    return r

def fetch.fail(e: Err) -> IO(Result<&2, &2, Err, Res>):
  IO.pure(Result<&2, &2, Err, Res>, Fail{e})

def fetch.cap(f: Frame, over: Bool) -> Frame:
  match over:
    case True{}:
      FrameBad{}
    case False{}:
      f

# Untrusted servers must not grow the buffer without bound.
def fetch.max() -> Nat:
  U32.to_nat(16777216)

# Read state: bytes so far reversed (appends are cheap), their count, the
# framing hint, the last verdict, and a wire error if the read itself failed.
type Rd is Data:
  Rd{rbuf: String, n: Nat, need: Need, f: Frame, err: Maybe<&2, Err>}

# The hint is worked out once, when the header block has arrived.
def fetch.need(hint: Need, +rbuf: String, head: Bool) -> Need:
  match hint:
    case NeedHead{}:
      need(String.reverse(rbuf), head)
    case NeedLen{t}:
      NeedLen{t}
    case NeedChunk{}:
      NeedChunk{}
    case NeedClose{}:
      NeedClose{}
    case NeedNow{}:
      NeedNow{}

# Could the buffer hold a whole response now? A yes may be wrong (frame then
# says More); a no must never be.
def fetch.gate(closed: Bool, need: Need, +n: Nat, +got: String) -> Bool:
  match closed:
    case True{}:
      True{}
    case False{}:
      match need:
        case NeedHead{}:
          False{}
        case NeedLen{t}:
          Nat.is_le(t, n)
        case NeedChunk{}:
          Bool.or(Nat.is_lt(String.length(got), 4n), String.ends_with(got, "\r\n\r\n"))
        case NeedClose{}:
          False{}
        case NeedNow{}:
          True{}

def fetch.try(gate: Bool, rbuf: String, closed: Bool, head: Bool) -> Frame:
  match gate:
    case True{}:
      frame(String.reverse(rbuf), closed, head)
    case False{}:
      FrameMore{}

def fetch.step(+head: Bool, s: Socket, rd: Rd, +got: String, +closed: Bool) -> Socket & Rd:
  Rd{rbuf, n, need, f, err} = rd
  +rbuf2 = {String.reverse(got) ++ rbuf : String}
  +n2 = Nat.add(n, String.length(got))
  +need2 = fetch.need(need, rbuf2, head)
  (s, Rd{rbuf2, n2, need2, fetch.cap(fetch.try(fetch.gate(closed, need2, n2, got), rbuf2, closed, head), Nat.is_lt(fetch.max(), n2)), None{}})

def fetch.wire(s: Socket, rd: Rd, +code: U32, why: String) -> Socket & Rd:
  Rd{rbuf, n, need, f, err} = rd
  (s, Rd{rbuf, n, need, FrameBad{}, Some{err.or_late(code, ErrRead{code, why})}})


def fetch.next.go(+head: Bool, s: Socket, rd: Rd, r: Result<&1, &1, U32 & String, String>) -> Socket & Rd:
  match r:
    case Fail{(+code, why)}:
      fetch.wire(s, rd, code, why)
    case Done{+got}:
      fetch.step(head, s, rd, got, String.is_empty(got))

def fetch.next(head: Bool, rd: Rd, m: Socket & Result<&1, &1, U32 & String, String>) -> Socket & Rd:
  (s, r) = m
  fetch.next.go(head, s, rd, r)

def fetch.bad(tls: Bool, s: Socket, e: Maybe<&2, Err>) -> IO(Result<&2, &2, Err, Res>):
  match e:
    case None{}:
      fetch.close(tls, s, Fail{ErrBad{}})
    case Some{err}:
      fetch.close(tls, s, Fail{err})

# Reads until frame says Done or Bad; an empty recv means the server closed.
@unsafe
def fetch.read(+head: Bool, +tls: Bool, +ms: U32, st: Socket & Rd) -> IO(Result<&2, &2, Err, Res>):
  (s, rd) = st
  Rd{rbuf, n, need, f, err} = rd
  match f:
    case FrameMore{}:
      do IO<Result<&2, &2, Err, Res>>:
        m : Socket & Result<&1, &1, U32 & String, String> <- io.recv(tls, s, 65536, ms)
        fetch.read(head, tls, ms, fetch.next(head, Rd{rbuf, n, need, FrameMore{}, None{}}, m))
    case FrameBad{}:
      fetch.bad(tls, s, err)
    case FrameDone{res}:
      fetch.close(tls, s, Done{res})

def fetch.sent(head: Bool, tls: Bool, ms: U32, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&2, &2, Err, Res>):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      fetch.close(tls, s, Fail{err.or_late(code, ErrWrite{code, why})})
    case Done{u}:
      fetch.read(head, tls, ms, (s, Rd{"", 0n, NeedHead{}, FrameMore{}, None{}}))

def fetch.send(head: Bool, +tls: Bool, ms: U32, s: Socket, wire: String) -> IO(Result<&2, &2, Err, Res>):
  do IO<Result<&2, &2, Err, Res>>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send(tls, s, wire)
    fetch.sent(head, tls, ms, sent)

# A failed handshake is an error, never plaintext.
def fetch.shook(head: Bool, ms: U32, wire: String, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&2, &2, Err, Res>):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      fetch.close(True{}, s, Fail{err.or_late(code, ErrTls{code, why})})
    case Done{u}:
      fetch.send(head, True{}, ms, s, wire)

def fetch.secure(head: Bool, +ms: U32, sni: String, wire: String, c: Socket, tls: Bool) -> IO(Result<&2, &2, Err, Res>):
  match tls:
    case False{}:
      fetch.send(head, False{}, ms, c, wire)
    case True{}:
      do IO<Result<&2, &2, Err, Res>>:
        hs : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(c, sni, ms)
        fetch.shook(head, ms, wire, hs)

def fetch.conn(head: Bool, ms: U32, sni: String, wire: String, tls: Bool, r: Result<&1, &1, U32 & String, Socket>) -> IO(Result<&2, &2, Err, Res>):
  match r:
    case Fail{(+code, why)}:
      fetch.fail(err.or_late(code, ErrConnect{code, why}))
    case Done{c}:
      fetch.secure(head, ms, sni, wire, c, tls)

# One request on one connection to an IPv4 address. Bodies are byte strings.
def fetch.ip(+method: String, ip: String, port: U32, sni: String, hf: String, target: String, headers: Map<&2, List<&2, String>>, body: String, tls: Bool, +ms: U32) -> IO(Result<&2, &2, Err, Res>):
  do IO<Result<&2, &2, Err, Res>>:
    c : Result<&1, &1, U32 & String, Socket> <- Wire.connect(ip, port, ms)
    fetch.conn(String.eq(method, "HEAD"), ms, sni, encode_req(method, target, hf, headers, body), tls, c)

def fetch.addr(method: String, port: U32, sni: String, hf: String, target: String, headers: Map<&2, List<&2, String>>, body: String, tls: Bool, ms: U32, ip: Maybe<&2, String>) -> IO(Result<&2, &2, Err, Res>):
  match ip:
    case None{}:
      fetch.fail(ErrDns{})
    case Some{addr}:
      fetch.ip(method, addr, port, sni, hf, target, headers, body, tls, ms)

def fetch.dns(method: String, +host: String, port: U32, hf: String, target: String, headers: Map<&2, List<&2, String>>, body: String, tls: Bool, ms: U32) -> IO(Result<&2, &2, Err, Res>):
  do IO<Result<&2, &2, Err, Res>>:
    ip : Maybe<&2, String> <- Dns.resolve(host)
    fetch.addr(method, port, host, hf, target, headers, body, tls, ms, ip)

def fetch.scheme(method: String, host: String, port: U32, hf: String, target: String, headers: Map<&2, List<&2, String>>, body: String, ms: U32, +scheme: String, known: Bool) -> IO(Result<&2, &2, Err, Res>):
  match known:
    case False{}:
      fetch.fail(ErrUrl{})
    case True{}:
      fetch.dns(method, host, port, hf, target, headers, body, String.eq(scheme, "https"), ms)

def fetch.abs(method: String, headers: Map<&2, List<&2, String>>, body: String, ms: U32, hf: String, a: Url.Abs) -> IO(Result<&2, &2, Err, Res>):
  Url.Abs{+scheme, host, port, target} = a
  fetch.scheme(method, host, port, hf, target, headers, body, ms, scheme, Bool.or(String.eq(scheme, "http"), String.eq(scheme, "https")))

def fetch.one(h: Hop, ms: U32) -> IO(Result<&2, &2, Err, Res>):
  Hop{method, +url, headers, body} = h
  fetch.abs(method, headers, body, ms, Url.host_field(url), url)

type Next is Data:
  NDone{res: Result<&2, &2, Err, Res>}
  NStop{}
  NGo{left: Nat, hop: Hop}

# left: redirects still allowed after the request we just finished.
def fetch.hop(left: Nat, h: Hop) -> Next:
  match left:
    case 0n:
      NStop{}
    case 1n+p:
      NGo{p, h}

def fetch.decide.r(left: Nat, +r: Res, next: Maybe<&2, Hop>) -> Next:
  match next:
    case None{}:
      NDone{Done{r}}
    case Some{h}:
      fetch.hop(left, h)

def fetch.decide.res(left: Nat, h: Hop, +r: Res) -> Next:
  Res{status, headers, body} = r
  fetch.decide.r(left, r, redirect(status, headers, h))

def fetch.decide(left: Nat, h: Hop, m: Result<&2, &2, Err, Res>) -> Next:
  match m:
    case Fail{e}:
      NDone{Fail{e}}
    case Done{r}:
      fetch.decide.res(left, h, r)

# NGo.left is how many redirects may follow this request. 20 is WHATWG's limit.
@unsafe
def fetch.hops(+ms: U32, st: Next) -> IO(Result<&2, &2, Err, Res>):
  match st:
    case NDone{m}:
      IO.pure(Result<&2, &2, Err, Res>, m)
    case NStop{}:
      fetch.fail(ErrRedirect{})
    case NGo{+left, +h}:
      do IO<Result<&2, &2, Err, Res>>:
        m : Result<&2, &2, Err, Res> <- fetch.one(h, ms)
        fetch.hops(ms, fetch.decide(left, h, m))

def fetch.start(method: String, headers: Map<&2, List<&2, String>>, body: String, u: Maybe<&2, Url.Abs>) -> Next:
  match u:
    case None{}:
      NDone{Fail{ErrUrl{}}}
    case Some{a}:
      NGo{20n, Hop{method, a, req.put(Map.to_list(&2, List<&2, String>, headers), empty()), body}}

# fetch("GET", "https://example.com/x?y=1", headers, body) follows redirects.
# Fail is a bad URL, a failed lookup, connect, handshake, send, read, a
# malformed response, more than 20 redirects, or a step past ms.
# Body and response body are bytes.
def fetch.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: String, ms: U32) -> IO(Result<&2, &2, Err, Res>):
  fetch.hops(ms, fetch.start(method, headers, body, Url.absolute(url)))

# fetch.with and a 30 s step timeout.
def fetch(method: String, url: String, headers: Map<&2, List<&2, String>>, body: String) -> IO(Result<&2, &2, Err, Res>):
  fetch.with(method, url, headers, body, 30000)

def get(url: String) -> IO(Result<&2, &2, Err, Res>):
  fetch("GET", url, empty(), "")

def sent_fin(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def reply_send(s: Socket, res: Res) -> IO(Unit):
  do IO<Unit>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send(s, encode(res))
    sent_fin(sent)

def reply_handle(~h: Req -> IO(Res), s: Socket, req: Req) -> IO(Unit):
  do IO<Unit>:
    res : Res <- h(req)
    reply_send(s, res)

def reply_parsed(~h: Req -> IO(Res), s: Socket, m: Maybe<&2, Req>) -> IO(Unit):
  match m:
    case None{}:
      reply_send(s, Res{400, empty(), "bad"})
    case Some{req}:
      reply_handle(~h, s, req)

def reply_ok(~h: Req -> IO(Res), s: Socket, raw: String) -> IO(Unit):
  reply_parsed(~h, s, parse(raw))

def reply(~h: Req -> IO(Res), m: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (s, r) = m
  match r:
    case Done{raw}:
      reply_ok(~h, s, raw)
    case Fail{e}:
      Socket.close(s)

def talk(~h: Req -> IO(Res), s: Socket) -> IO(Unit):
  do IO<Unit>:
    read : Socket & Result<&1, &1, U32 & String, String> <- Wire.recv(s, 8192, 30000)
    reply(~h, read)

def conn(~h: Req -> IO(Res), m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, talk(~h, s))
    return l

@unsafe
def loop(~h: Req -> IO(Res), l: Listener) -> IO(Unit):
  do IO<Unit>:
    m  : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- conn(~h, m)
    loop(~h, l2)

def serve(~h: Req -> IO(Res), +port: U32) -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(port))
    IO.print("http://127.0.0.1:" ++ U32.show(port))
    loop(~h, l)
