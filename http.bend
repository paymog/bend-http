import Base
import ./wire.bend as Wire
import ./dns/dns.bend as Dns
import ./url/url.bend as Url

# HTTP/1.1 codec and client (RFC 9112) for http:// and https:// (OpenSSL 3 at run time).
# parse: start-line → field lines → blank → body length (§6.3); chunked (§7.1).
# Bodies are byte strings: one Char per octet, so lengths are exact.
# fetch reads until frame() says the response is whole. Build with -o for big bodies:
# the `bend file.bend` runner overflows on ~30 KB strings; native binaries do not.
#   import ./http.bend as Http

type Req is Data:
  Req{method: String, path: String, headers: Map<&2, String>, body: String}

type Res is Data:
  Res{status: U32, headers: Map<&2, String>, body: String}

type Fields is Data:
  FieldsBad{}
  FieldsOk{m: Map<&2, String>}

def empty() -> Map<&2, String>:
  Map.new(&2, String)

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

def has_header.of(r: Map<&2, String> & Bool) -> Bool:
  (h, b) = r
  b

def has_header(+h: Map<&2, String>, k: String) -> Bool:
  has_header.of(Map.has(&2, String, h, k))

def header.of(r: Map<&2, String> & String) -> String:
  (h, v) = r
  v

def header(+h: Map<&2, String>, k: String) -> String:
  header.of(Map.get(String, "", h, k))

def folded(+line: String) -> Bool:
  Bool.or(String.starts_with(line, " "), String.starts_with(line, "\t"))

def tracked(+k: String) -> Bool:
  Bool.or(String.eq(k, "host"), String.eq(k, "content-length"))

def fields_put.dup(m: Map<&2, String>, k: String, v: String, bad: Bool) -> Fields:
  match bad:
    case True{}:
      FieldsBad{}
    case False{}:
      FieldsOk{Map.set(&2, String, m, k, v)}

def fields_put.key(+m: Map<&2, String>, +k: String, v: String) -> Fields:
  fields_put.dup(m, k, v, Bool.and(tracked(k), has_header(m, k)))

def fields_put.kv(m: Map<&2, String>, kv: String & String) -> Fields:
  (k, v) = kv
  fields_put.key(m, String.to_lower(k), String.trim(v))

def fields_put.fold(m: Map<&2, String>, line: String, fold: Bool) -> Fields:
  match fold:
    case True{}:
      FieldsBad{}
    case False{}:
      fields_put.kv(m, split_colon(line))

def fields_put.empty(m: Map<&2, String>, +line: String, e: Bool) -> Fields:
  match e:
    case True{}:
      FieldsOk{m}
    case False{}:
      fields_put.fold(m, line, folded(line))

def fields_put.ok(m: Map<&2, String>, +line: String) -> Fields:
  fields_put.empty(m, line, String.is_empty(line))

def fields_put(acc: Fields, line: String) -> Fields:
  match acc:
    case FieldsBad{}:
      FieldsBad{}
    case FieldsOk{m}:
      fields_put.ok(m, line)

def parse.headers.done(acc: Fields) -> Maybe<&2, Map<&2, String>>:
  match acc:
    case FieldsBad{}:
      None{}
    case FieldsOk{m}:
      Some{m}

def parse.headers(xs: List<&2, String>, acc: Fields) -> Maybe<&2, Map<&2, String>>:
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

def chunk.trailer.ok(acc: String, ok: Bool) -> Step:
  match ok:
    case True{}:
      StepDone{acc}
    case False{}:
      StepFail{}

def chunk.trailer.end(hb: String & String, acc: String) -> Step:
  (+h, r) = hb
  chunk.trailer.ok(acc, String.ends_with(h, "\r\n\r\n"))

def chunk.trailer.if(rest: String, acc: String, blank: Bool) -> Step:
  match blank:
    case True{}:
      StepDone{acc}
    case False{}:
      chunk.trailer.end(split_at_blank(rest), acc)

# ponytail: trailer fields are dropped unparsed (§7.1.2 allows discarding)
def chunk.trailer(+rest: String, acc: String) -> Step:
  chunk.trailer.if(rest, acc, String.starts_with(rest, "\r\n"))

def chunk.crlf.if(data: String, +after: String, acc: String, ok: Bool) -> Step:
  match ok:
    case True{}:
      StepNext{String.drop(after, 2n), acc ++ data}
    case False{}:
      StepFail{}

def chunk.crlf(data: String, +after: String, acc: String) -> Step:
  chunk.crlf.if(data, after, acc, String.starts_with(after, "\r\n"))

def chunk.data.if(+rest: String, +k: Nat, acc: String, short: Bool) -> Step:
  match short:
    case True{}:
      StepFail{}
    case False{}:
      chunk.crlf(String.take(rest, k), String.drop(rest, k), acc)

def chunk.data(+rest: String, +k: Nat, acc: String) -> Step:
  chunk.data.if(rest, k, acc, Nat.is_lt(String.length(rest), k))

def chunk.step.n(+n: U32, rest: String, acc: String, zero: Bool) -> Step:
  match zero:
    case True{}:
      chunk.trailer(rest, acc)
    case False{}:
      chunk.data(rest, U32.to_nat(n), acc)

def chunk.step.got(got: Maybe<&2, HexSize>, acc: String) -> Step:
  match got:
    case None{}:
      StepFail{}
    case Some{HexSize{+n, rest}}:
      chunk.step.n(n, rest, acc, U32.is_eq(n, 0))

def chunk.step(s: String, acc: String) -> Step:
  chunk.step.got(chunk.size(s), acc)

# ponytail: acc ++ per chunk is O(body * chunks); a chunk list if bodies get big
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

def parse.body.cl(+h: Map<&2, String>, rest: String, hascl: Bool) -> Maybe<&2, String>:
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

def parse.body.chunked(+h: Map<&2, String>, rest: String, hascl: Bool) -> Maybe<&2, String>:
  match hascl:
    case True{}:
      None{}
    case False{}:
      parse.body.chunked.val(header(h, "transfer-encoding"), rest)

def parse.body.te(+h: Map<&2, String>, rest: String, te: Bool) -> Maybe<&2, String>:
  match te:
    case True{}:
      parse.body.chunked(h, rest, has_header(h, "content-length"))
    case False{}:
      parse.body.cl(h, rest, has_header(h, "content-length"))

def parse.body(+h: Map<&2, String>, rest: String) -> Maybe<&2, String>:
  parse.body.te(h, rest, has_header(h, "transfer-encoding"))

def parse.finish(method: String, path: String, h: Map<&2, String>, body: Maybe<&2, String>) -> Maybe<&2, Req>:
  match body:
    case None{}:
      None{}
    case Some{b}:
      Some{Req{method, path, h, b}}

def parse.host(method: String, path: String, +h: Map<&2, String>, rest: String, has: Bool) -> Maybe<&2, Req>:
  match has:
    case False{}:
      None{}
    case True{}:
      parse.finish(method, path, h, parse.body(h, rest))

def parse.fields(method: String, path: String, rest: String, fs: Maybe<&2, Map<&2, String>>) -> Maybe<&2, Req>:
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

def parse.res.cl(+h: Map<&2, String>, rest: String, hascl: Bool) -> Maybe<&2, String>:
  match hascl:
    case False{}:
      Some{rest}
    case True{}:
      parse.take(rest, parse_u32(header(h, "content-length")))

def parse.res.te(+h: Map<&2, String>, rest: String, te: Bool) -> Maybe<&2, String>:
  match te:
    case True{}:
      parse.body.chunked(h, rest, has_header(h, "content-length"))
    case False{}:
      parse.res.cl(h, rest, has_header(h, "content-length"))

def parse.res.body(+h: Map<&2, String>, rest: String) -> Maybe<&2, String>:
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

def frame.done(status: U32, h: Map<&2, String>, body: Maybe<&2, String>, +closed: Bool, open: Bool) -> Frame:
  match body:
    case None{}:
      frame.cut(closed)
    case Some{b}:
      frame.wait(Res{status, h, b}, Bool.and(open, Bool.not(closed)))

# RFC 9112 §6.3 (8): no TE and no CL ⇒ the body runs until the server closes.
def frame.open(+h: Map<&2, String>) -> Bool:
  Bool.not(Bool.or(has_header(h, "transfer-encoding"), has_header(h, "content-length")))

# RFC 9112 §6.3 (1): HEAD, 1xx, 204 and 304 responses end at the blank line.
# ponytail: 1xx is returned as final; skip interim responses if a server sends 103
def frame.nobody(+status: U32, head: Bool) -> Bool:
  Bool.or(head, Bool.or(U32.is_lt(status, 200), Bool.or(U32.is_eq(status, 204), U32.is_eq(status, 304))))

def frame.status(status: U32, +h: Map<&2, String>, rest: String, closed: Bool, nobody: Bool) -> Frame:
  match nobody:
    case True{}:
      FrameDone{Res{status, h, ""}}
    case False{}:
      frame.done(status, h, parse.res.body(h, rest), closed, frame.open(h))

def parse.res.fields(+status: U32, rest: String, fs: Maybe<&2, Map<&2, String>>, closed: Bool, head: Bool) -> Frame:
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

def headers_block.go(xs: List<&2, Sigma<&2, &2, String, _ => String>>, acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case (k, v) <> t:
      headers_block.go(t, acc ++ ("\r\n" ++ sanitize(k) ++ ": " ++ sanitize(v)))

def headers_block(h: Map<&2, String>) -> String:
  headers_block.go(Map.to_list(&2, String, h), "")

def response(status: U32, headers: Map<&2, String>, body: String) -> String:
  ("HTTP/1.1 " ++ U32.show(status) ++ " OK" ++ headers_block(headers)) ++ ("\r\n\r\n" ++ body)

def nat_u32(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      (nat_u32(p) + 1 : U32)

def encode(r: Res) -> String:
  Res{status, headers, +body} = r
  response(status, Map.set(&2, String, headers, "content-length", U32.show(nat_u32(String.length(body)))), body)

def request(method: String, path: String, headers: Map<&2, String>, body: String) -> String:
  (method ++ " " ++ path ++ " HTTP/1.1" ++ headers_block(headers)) ++ ("\r\n\r\n" ++ body)

def req.reserved(+k: String) -> Bool:
  Bool.or(Bool.or(String.eq(k, "host"), String.eq(k, "connection")), Bool.or(String.eq(k, "content-length"), String.eq(k, "transfer-encoding")))

def req.put.one(m: Map<&2, String>, +k: String, v: String, skip: Bool) -> Map<&2, String>:
  match skip:
    case True{}:
      m
    case False{}:
      Map.set(&2, String, m, k, v)

def req.put(xs: List<&2, Sigma<&2, &2, String, _ => String>>, m: Map<&2, String>) -> Map<&2, String>:
  match xs:
    case Nil{}:
      m
    case (k, v) <> t:
      +lk = String.to_lower(k)
      req.put(t, req.put.one(m, lk, v, req.reserved(lk)))

# RFC 9110 §8.6: no Content-Length on a bodiless request whose method gives a body no meaning.
def req.cl(+m: Map<&2, String>, +method: String, +body: String) -> Map<&2, String>:
  +bodied = Bool.or(Bool.not(String.is_empty(body)), Bool.or(String.eq(method, "POST"), Bool.or(String.eq(method, "PUT"), String.eq(method, "PATCH"))))
  Bool.pick(Map<&2, String>, bodied, Map.set(&2, String, m, "content-length", U32.show(nat_u32(String.length(body)))), m)

# Caller headers are lowercased so they cannot duplicate ours; host, connection,
# content-length and transfer-encoding are always ours (no smuggling through them).
def encode_req(+method: String, target: String, host: String, headers: Map<&2, String>, +body: String) -> String:
  +h = Map.set(&2, String, Map.set(&2, String, req.put(Map.to_list(&2, String, headers), empty()), "host", host), "connection", "close")
  request(method, target, req.cl(h, method, body), body)

# Transport: plain TCP or TLS over the same socket.
def io.recv(tls: Bool, s: Socket, max: U32) -> IO(Socket & Result<&1, &1, U32 & String, String>):
  match tls:
    case True{}:
      Wire.tls.recv(s, max)
    case False{}:
      Wire.recv(s, max)

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

def fetch.close(tls: Bool, s: Socket, r: Maybe<&2, Res>) -> IO(Maybe<&2, Res>):
  do IO<Maybe<&2, Res>>:
    io.close(tls, s)
    return r

def fetch.none() -> IO(Maybe<&2, Res>):
  IO.pure(Maybe<&2, Res>, None{})

def fetch.cap(f: Frame, over: Bool) -> Frame:
  match over:
    case True{}:
      FrameBad{}
    case False{}:
      f

# Untrusted servers must not grow the buffer without bound.
def fetch.max() -> Nat:
  U32.to_nat(16777216)

def fetch.next.buf(s: Socket, +buf: String, closed: Bool, head: Bool) -> Socket & String & Frame:
  (s, buf, fetch.cap(frame(buf, closed, head), Nat.is_lt(fetch.max(), String.length(buf))))

def fetch.next.r(head: Bool, s: Socket, buf: String, r: Result<&1, &1, U32 & String, String>) -> Socket & String & Frame:
  match r:
    case Fail{e}:
      (s, buf, FrameBad{})
    case Done{+got}:
      fetch.next.buf(s, buf ++ got, String.is_empty(got), head)

def fetch.next(head: Bool, buf: String, m: Socket & Result<&1, &1, U32 & String, String>) -> Socket & String & Frame:
  (s, r) = m
  fetch.next.r(head, s, buf, r)

# Reads until frame says Done or Bad; an empty recv means the server closed.
@unsafe
def fetch.read(+head: Bool, +tls: Bool, st: Socket & String & Frame) -> IO(Maybe<&2, Res>):
  (s, buf, f) = st
  match f:
    case FrameMore{}:
      do IO<Maybe<&2, Res>>:
        m : Socket & Result<&1, &1, U32 & String, String> <- io.recv(tls, s, 65536)
        fetch.read(head, tls, fetch.next(head, buf, m))
    case FrameBad{}:
      fetch.close(tls, s, None{})
    case FrameDone{res}:
      fetch.close(tls, s, Some{res})

def fetch.sent(head: Bool, tls: Bool, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Maybe<&2, Res>):
  (s, r) = m
  match r:
    case Fail{e}:
      fetch.close(tls, s, None{})
    case Done{u}:
      fetch.read(head, tls, (s, "", FrameMore{}))

def fetch.send(head: Bool, +tls: Bool, s: Socket, wire: String) -> IO(Maybe<&2, Res>):
  do IO<Maybe<&2, Res>>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send(tls, s, wire)
    fetch.sent(head, tls, sent)

# A failed handshake (bad chain, wrong host, no OpenSSL) is None, never plaintext.
def fetch.shook(head: Bool, wire: String, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Maybe<&2, Res>):
  (s, r) = m
  match r:
    case Fail{e}:
      fetch.close(True{}, s, None{})
    case Done{u}:
      fetch.send(head, True{}, s, wire)

def fetch.secure(head: Bool, sni: String, wire: String, c: Socket, tls: Bool) -> IO(Maybe<&2, Res>):
  match tls:
    case False{}:
      fetch.send(head, False{}, c, wire)
    case True{}:
      do IO<Maybe<&2, Res>>:
        hs : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(c, sni)
        fetch.shook(head, wire, hs)

def fetch.conn(head: Bool, sni: String, wire: String, tls: Bool, r: Result<&1, &1, U32 & String, Socket>) -> IO(Maybe<&2, Res>):
  match r:
    case Fail{e}:
      fetch.none()
    case Done{c}:
      fetch.secure(head, sni, wire, c, tls)

# One request on one connection to an IPv4 address. Bodies are byte strings.
def fetch.ip(+method: String, ip: String, port: U32, sni: String, hf: String, target: String, headers: Map<&2, String>, body: String, tls: Bool) -> IO(Maybe<&2, Res>):
  do IO<Maybe<&2, Res>>:
    c : Result<&1, &1, U32 & String, Socket> <- TCP.connect(ip, port)
    fetch.conn(String.eq(method, "HEAD"), sni, encode_req(method, target, hf, headers, body), tls, c)

def fetch.addr(method: String, port: U32, sni: String, hf: String, target: String, headers: Map<&2, String>, body: String, tls: Bool, ip: Maybe<&2, String>) -> IO(Maybe<&2, Res>):
  match ip:
    case None{}:
      fetch.none()
    case Some{addr}:
      fetch.ip(method, addr, port, sni, hf, target, headers, body, tls)

def fetch.dns(method: String, +host: String, port: U32, hf: String, target: String, headers: Map<&2, String>, body: String, tls: Bool) -> IO(Maybe<&2, Res>):
  do IO<Maybe<&2, Res>>:
    ip : Maybe<&2, String> <- Dns.resolve(host)
    fetch.addr(method, port, host, hf, target, headers, body, tls, ip)

def fetch.scheme(method: String, host: String, port: U32, hf: String, target: String, headers: Map<&2, String>, body: String, +scheme: String, known: Bool) -> IO(Maybe<&2, Res>):
  match known:
    case False{}:
      fetch.none()
    case True{}:
      fetch.dns(method, host, port, hf, target, headers, body, String.eq(scheme, "https"))

def fetch.abs(method: String, headers: Map<&2, String>, body: String, hf: String, a: Url.Abs) -> IO(Maybe<&2, Res>):
  Url.Abs{+scheme, host, port, target} = a
  fetch.scheme(method, host, port, hf, target, headers, body, scheme, Bool.or(String.eq(scheme, "http"), String.eq(scheme, "https")))

def fetch.url(method: String, headers: Map<&2, String>, body: String, u: Maybe<&2, Url.Abs>) -> IO(Maybe<&2, Res>):
  match u:
    case None{}:
      fetch.none()
    case Some{+a}:
      fetch.abs(method, headers, body, Url.host_field(a), a)

# fetch("GET", "http://example.com/x?y=1", headers, body): None on a bad URL,
# a failed lookup or connect, or a malformed response. Body and response body are bytes.
def fetch(method: String, url: String, headers: Map<&2, String>, body: String) -> IO(Maybe<&2, Res>):
  fetch.url(method, headers, body, Url.absolute(url))

def get(url: String) -> IO(String):
  do IO<String>:
    m : Maybe<&2, Res> <- fetch("GET", url, empty(), "")
    return res_body(m)

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
    read : Socket & Result<&1, &1, U32 & String, String> <- Wire.recv(s, 8192)
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
