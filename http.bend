# HTTP/1.1 client for http and https, with DNS and TLS.
import Base
import ./about.bend as About
import ./wire.bend as Wire
import ./dns/dns.bend as Dns
import ./url/url.bend as Url
import ./encoding/encoding.bend as Enc
import ./json/json.bend as Json
import ./zlib/zlib.bend as Zlib

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

# Bool.pick evaluates both arms; a split that recursed inside it would reverse acc at every byte.
def take.cut(acc: String, rest: String) -> String & String:
  (String.reverse(String.drop(acc, 1n)), rest)

# hit: the last char pushed onto acc was the stop char.
def take_sp.go(s: String, acc: String, hit: Bool) -> String & String:
  match s:
    case SNil{}:
      match hit:
        case True{}:
          take.cut(acc, SNil{})
        case False{}:
          (String.reverse(acc), SNil{})
    case SCon{Chr{+c}, t}:
      match hit:
        case True{}:
          take.cut(acc, SCon{Chr{c}, t})
        case False{}:
          take_sp.go(t, SCon{Chr{c}, acc}, U32.is_eq(c, 32))

def take_sp(s: String) -> String & String:
  take_sp.go(s, SNil{}, False{})

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

def split_colon.go(s: String, acc: String, hit: Bool) -> String & String:
  match s:
    case SNil{}:
      match hit:
        case True{}:
          take.cut(acc, SNil{})
        case False{}:
          (String.reverse(acc), SNil{})
    case SCon{Chr{+c}, t}:
      match hit:
        case True{}:
          take.cut(acc, SCon{Chr{c}, t})
        case False{}:
          split_colon.go(t, SCon{Chr{c}, acc}, U32.is_eq(c, 58))

def split_colon(s: String) -> String & String:
  split_colon.go(s, SNil{}, False{})

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

# More: a valid prefix. Bad: cannot become a body. Body: a whole chunked body.
type Hold is Data:
  HoldMore{}
  HoldBad{}
  HoldBody{b: String}
  HoldUntil{b: String}

def is_hex(+c: U32) -> Bool:
  Bool.or(parse_u32.digit(c), Bool.or(Bool.and(U32.is_le(97, c), U32.is_le(c, 102)), Bool.and(U32.is_le(65, c), U32.is_le(c, 70))))

def hexv(+c: U32) -> U32:
  Bool.pick(U32, parse_u32.digit(c), (c - 48 : U32), Bool.pick(U32, U32.is_le(c, 70), (c - 55 : U32), (c - 87 : U32)))

# A chunked body decoder that reads each byte once, so a body fed in pieces
# costs O(bytes) in total. Tr{j}: j bytes of the closing CRLF CRLF matched.
type Dc is Data:
  DcSize{acc: U32, seen: Bool}
  DcExt{n: U32}
  DcSizeLf{n: U32}
  DcData{k: Nat}
  DcDataCr{}
  DcDataLf{}
  DcTr{j: U32}
  DcDone{}
  DcBad{}

# st: where the decoder is. racc: the body so far, reversed. rest: bytes after a Done body.
type Dco is Data:
  Dco{st: Dc, racc: String, rest: String}

def dc.start() -> Dc:
  DcSize{0, False{}}

def dc.size.semi(+n: U32, semi: Bool) -> Dc:
  match semi:
    case True{}:
      DcExt{n}
    case False{}:
      DcBad{}

def dc.size.cr(+n: U32, +c: U32, cr: Bool) -> Dc:
  match cr:
    case True{}:
      DcSizeLf{n}
    case False{}:
      dc.size.semi(n, U32.is_eq(c, 59))

def dc.size.end(+n: U32, +c: U32, seen: Bool) -> Dc:
  match seen:
    case False{}:
      DcBad{}
    case True{}:
      dc.size.cr(n, c, U32.is_eq(c, 13))

# A size that would overflow 32 bits ends the digits, and size.end then refuses it.
def dc.size(+acc: U32, seen: Bool, +c: U32, digit: Bool) -> Dc:
  match digit:
    case True{}:
      DcSize{(acc * 16 + hexv(c) : U32), True{}}
    case False{}:
      dc.size.end(acc, c, seen)

# RFC 9112 §7.1.1: recipients ignore unknown chunk extensions; a bare LF is not CRLF.
def dc.ext.lf(+n: U32, lf: Bool) -> Dc:
  match lf:
    case True{}:
      DcBad{}
    case False{}:
      DcExt{n}

def dc.ext(+n: U32, +c: U32, cr: Bool) -> Dc:
  match cr:
    case True{}:
      DcSizeLf{n}
    case False{}:
      dc.ext.lf(n, U32.is_eq(c, 10))

def dc.sized(+n: U32, zero: Bool) -> Dc:
  match zero:
    case True{}:
      DcTr{2}
    case False{}:
      DcData{U32.to_nat(n)}

def dc.size.lf(+n: U32, lf: Bool) -> Dc:
  match lf:
    case True{}:
      dc.sized(n, U32.is_eq(n, 0))
    case False{}:
      DcBad{}

def dc.data(k: Nat) -> Dc:
  match k:
    case 0n:
      DcDataCr{}
    case 1n+p:
      match p:
        case 0n:
          DcDataCr{}
        case 1n+q:
          DcData{1n+q}

def dc.pick(ok: Bool, next: Dc) -> Dc:
  match ok:
    case True{}:
      next
    case False{}:
      DcBad{}

# ponytail: trailer fields are dropped unparsed (§7.1.2 allows discarding)
def dc.tr.hit(+j: U32) -> Dc:
  Bool.pick(Dc, U32.is_eq(j, 3), DcDone{}, DcTr{(j + 1 : U32)})

def dc.tr(+j: U32, +c: U32, hit: Bool) -> Dc:
  match hit:
    case True{}:
      dc.tr.hit(j)
    case False{}:
      Bool.pick(Dc, U32.is_eq(c, 13), DcTr{1}, DcTr{0})

def dc.tr.want(+j: U32) -> U32:
  Bool.pick(U32, U32.is_eq(U32.mod(j, 2), 0), 13, 10)

def dc.byte(h: Char) -> U32:
  Chr{c} = h
  c

# Done and Bad never look at the next byte, and data bytes are never inspected.
def dc.feed(s: String, st: Dc, racc: String) -> Dco:
  match s:
    case SNil{}:
      Dco{st, racc, ""}
    case SCon{h, t}:
      match st:
        case DcBad{}:
          Dco{DcBad{}, racc, ""}
        case DcSize{+acc, seen}:
          +c = dc.byte(h)
          dc.feed(t, dc.size(acc, seen, c, Bool.and(is_hex(c), U32.is_le(acc, 268435455))), racc)
        case DcExt{+n}:
          +c = dc.byte(h)
          dc.feed(t, dc.ext(n, c, U32.is_eq(c, 13)), racc)
        case DcSizeLf{+n}:
          +c = dc.byte(h)
          dc.feed(t, dc.size.lf(n, U32.is_eq(c, 10)), racc)
        case DcDataCr{}:
          +c = dc.byte(h)
          dc.feed(t, dc.pick(U32.is_eq(c, 13), DcDataLf{}), racc)
        case DcDataLf{}:
          +c = dc.byte(h)
          dc.feed(t, dc.pick(U32.is_eq(c, 10), dc.start()), racc)
        case DcTr{+j}:
          +c = dc.byte(h)
          dc.feed(t, dc.tr(j, c, U32.is_eq(c, dc.tr.want(j))), racc)
        case DcData{k}:
          dc.feed(t, dc.data(k), SCon{h, racc})
        case DcDone{}:
          Dco{DcDone{}, racc, SCon{h, t}}

def chunk.hold(o: Dco) -> Hold:
  Dco{st, racc, rest} = o
  match st:
    case DcDone{}:
      HoldBody{String.reverse(racc)}
    case DcBad{}:
      HoldBad{}
    case DcSize{a, b}:
      HoldMore{}
    case DcExt{n}:
      HoldMore{}
    case DcSizeLf{n}:
      HoldMore{}
    case DcData{k}:
      HoldMore{}
    case DcDataCr{}:
      HoldMore{}
    case DcDataLf{}:
      HoldMore{}
    case DcTr{j}:
      HoldMore{}

def chunk.live(s: String) -> Hold:
  chunk.hold(dc.feed(s, dc.start(), ""))

def chunk.rest(o: Dco) -> Maybe<&2, String>:
  Dco{st, racc, rest} = o
  match st:
    case DcDone{}:
      Some{rest}
    case DcBad{}:
      None{}
    case DcSize{a, b}:
      None{}
    case DcExt{n}:
      None{}
    case DcSizeLf{n}:
      None{}
    case DcData{k}:
      None{}
    case DcDataCr{}:
      None{}
    case DcDataLf{}:
      None{}
    case DcTr{j}:
      None{}

def chunk.suffix(s: String) -> Maybe<&2, String>:
  chunk.rest(dc.feed(s, dc.start(), ""))

def chunk.decode.hold(h: Hold) -> Maybe<&2, String>:
  match h:
    case HoldMore{}:
      None{}
    case HoldBad{}:
      None{}
    case HoldUntil{b}:
      None{}
    case HoldBody{b}:
      Some{b}

def chunk.decode(s: String) -> Maybe<&2, String>:
  chunk.decode.hold(chunk.live(s))

def parse.res.cl.have(+rest: String, +k: Nat, short: Bool) -> Hold:
  match short:
    case True{}:
      HoldMore{}
    case False{}:
      HoldBody{String.take(rest, k)}

def parse.res.cl.k(+rest: String, +k: Nat) -> Hold:
  parse.res.cl.have(rest, k, Nat.is_lt(String.length(rest), k))

def parse.res.cl.n(rest: String, n: Maybe<&2, U32>) -> Hold:
  match n:
    case None{}:
      HoldBad{}
    case Some{k}:
      parse.res.cl.k(rest, U32.to_nat(k))

def parse.body.cl(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Hold:
  match hascl:
    case False{}:
      HoldBody{""}
    case True{}:
      parse.res.cl.n(rest, parse_u32(header(h, "content-length")))

# RFC 9112 §6.3 (4): a request coding other than chunked cannot be framed.
def parse.body.chunked.eq(rest: String, ok: Bool) -> Hold:
  match ok:
    case False{}:
      HoldBad{}
    case True{}:
      chunk.live(rest)

def parse.body.chunked.val(te: String, rest: String) -> Hold:
  parse.body.chunked.eq(rest, String.eq(String.to_lower(te), "chunked"))

def parse.body.chunked(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Hold:
  match hascl:
    case True{}:
      HoldBad{}
    case False{}:
      parse.body.chunked.val(header.last(h, "transfer-encoding"), rest)

def parse.body.te(+h: Map<&2, List<&2, String>>, rest: String, te: Bool) -> Hold:
  match te:
    case True{}:
      parse.body.chunked(h, rest, has_header(h, "content-length"))
    case False{}:
      parse.body.cl(h, rest, has_header(h, "content-length"))

def parse.body(+h: Map<&2, List<&2, String>>, rest: String) -> Hold:
  parse.body.te(h, rest, has_header(h, "transfer-encoding"))

# Bad: never a request. More: a valid prefix; read on. Whole: a request.
type Got is Data:
  GotBad{}
  GotMore{}
  GotReq{req: Req}

def parse.finish(method: String, path: String, h: Map<&2, List<&2, String>>, body: Hold) -> Got:
  match body:
    case HoldBad{}:
      GotBad{}
    case HoldMore{}:
      GotMore{}
    case HoldUntil{b}:
      GotBad{}
    case HoldBody{b}:
      GotReq{Req{method, path, h, b}}

def parse.host(method: String, path: String, +h: Map<&2, List<&2, String>>, rest: String, has: Bool) -> Got:
  match has:
    case False{}:
      GotBad{}
    case True{}:
      parse.finish(method, path, h, parse.body(h, rest))

# RFC 9112 §3.2: only HTTP/1.1 requires Host.
def parse.fields(method: String, path: String, rest: String, v11: Bool, fs: Maybe<&2, Map<&2, List<&2, String>>>) -> Got:
  match fs:
    case None{}:
      GotBad{}
    case Some{+h}:
      parse.host(method, path, h, rest, Bool.or(Bool.not(v11), has_header(h, "host")))

def target_ok(+p: String) -> Bool:
  Bool.or(String.starts_with(p, "/"), Bool.or(String.eq(p, "*"), String.starts_with(p, "http://")))

def parse.target(method: String, +path: String, headers: List<&2, String>, rest: String, v11: Bool, ok: Bool) -> Got:
  match ok:
    case False{}:
      GotBad{}
    case True{}:
      parse.fields(method, path, rest, v11, parse.headers(headers, FieldsOk{empty()}))

def parse.ver(method: String, +path: String, +v: String, headers: List<&2, String>, rest: String, ok: Bool) -> Got:
  match ok:
    case False{}:
      GotBad{}
    case True{}:
      parse.target(method, path, headers, rest, String.eq(v, "HTTP/1.1"), target_ok(path))

def parse.empty_method(method: String, path: String, +v: String, headers: List<&2, String>, rest: String, empty: Bool) -> Got:
  match empty:
    case True{}:
      GotBad{}
    case False{}:
      parse.ver(method, path, v, headers, rest, Bool.or(String.eq(v, "HTTP/1.1"), String.eq(v, "HTTP/1.0")))

def parse.start3(mpv: String & String & String, headers: List<&2, String>, rest: String) -> Got:
  (+method, path, v) = mpv
  parse.empty_method(method, path, v, headers, rest, String.is_empty(method))

def parse.lines(xs: List<&2, String>, rest: String) -> Got:
  match xs:
    case Nil{}:
      GotBad{}
    case Con{line, headers}:
      parse.start3(start_line(line), headers, rest)

def parse.head(+head: String, rest: String, whole: Bool) -> Got:
  match whole:
    case False{}:
      GotMore{}
    case True{}:
      parse.lines(String.lines(head), rest)

def parse.of(hb: String & String) -> Got:
  (+head, rest) = hb
  parse.head(head, rest, String.ends_with(head, "\r\n\r\n"))

# serve reads until this is not GotMore.
def parse.got(raw: String) -> Got:
  parse.of(split_at_blank(raw))

def parse.req(g: Got) -> Maybe<&2, Req>:
  match g:
    case GotReq{req}:
      Some{req}
    case GotBad{}:
      None{}
    case GotMore{}:
      None{}

def parse(raw: String) -> Maybe<&2, Req>:
  parse.req(parse.got(raw))

def parse.res.cl(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Hold:
  match hascl:
    case False{}:
      HoldBody{rest}
    case True{}:
      parse.res.cl.n(rest, parse_u32(header(h, "content-length")))

def parse.res.chunked.eq(rest: String, ok: Bool) -> Hold:
  match ok:
    case False{}:
      HoldUntil{rest}
    case True{}:
      chunk.live(rest)

def parse.res.chunked.val(te: String, rest: String) -> Hold:
  parse.res.chunked.eq(rest, String.eq(String.to_lower(te), "chunked"))

def parse.res.chunked(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Hold:
  match hascl:
    case True{}:
      HoldBad{}
    case False{}:
      parse.res.chunked.val(header.last(h, "transfer-encoding"), rest)

def parse.res.te(+h: Map<&2, List<&2, String>>, rest: String, te: Bool) -> Hold:
  match te:
    case True{}:
      parse.res.chunked(h, rest, has_header(h, "content-length"))
    case False{}:
      parse.res.cl(h, rest, has_header(h, "content-length"))

def parse.res.body(+h: Map<&2, List<&2, String>>, rest: String) -> Hold:
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

def frame.done(status: U32, h: Map<&2, List<&2, String>>, body: Hold, +closed: Bool, open: Bool) -> Frame:
  match body:
    case HoldBad{}:
      FrameBad{}
    case HoldMore{}:
      frame.cut(closed)
    case HoldUntil{b}:
      frame.wait(Res{status, h, b}, Bool.not(closed))
    case HoldBody{b}:
      frame.wait(Res{status, h, b}, Bool.and(open, Bool.not(closed)))

# RFC 9112 §6.3 (8): no TE and no CL ⇒ the body runs until the server closes.
def frame.open(+h: Map<&2, List<&2, String>>) -> Bool:
  Bool.not(Bool.or(has_header(h, "transfer-encoding"), has_header(h, "content-length")))

# RFC 9112 §6.3 (1): HEAD, 1xx, 204 and 304 responses end at the blank line.
def frame.nobody(+status: U32, head: Bool) -> Bool:
  Bool.or(head, Bool.or(U32.is_lt(status, 200), Bool.or(U32.is_eq(status, 204), U32.is_eq(status, 304))))

# 101 is the final response. Other 1xx are interim; a final response follows.
def frame.interim(+status: U32) -> Bool:
  Bool.and(U32.is_lt(status, 200), Bool.not(U32.is_eq(status, 101)))

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

type Lead is Data:
  LeadCut{}
  LeadFinal{}
  LeadSkip{rest: String}

def frame.lead.if(rest: String, interim: Bool) -> Lead:
  match interim:
    case True{}:
      LeadSkip{rest}
    case False{}:
      LeadFinal{}

def frame.lead.num(n: Maybe<&2, U32>, rest: String) -> Lead:
  match n:
    case None{}:
      LeadFinal{}
    case Some{s}:
      frame.lead.if(rest, frame.interim(s))

def frame.lead.code(mpv: String & String & String, rest: String) -> Lead:
  (ver, code, reason) = mpv
  frame.lead.num(parse_u32(code), rest)

def frame.lead.lines(xs: List<&2, String>, rest: String) -> Lead:
  match xs:
    case Nil{}:
      LeadFinal{}
    case Con{line, headers}:
      frame.lead.code(start_line(line), rest)

def frame.lead.blank(+hd: String, rest: String, ok: Bool) -> Lead:
  match ok:
    case False{}:
      LeadCut{}
    case True{}:
      frame.lead.lines(String.lines(hd), rest)

def frame.lead(hb: String & String) -> Lead:
  (+hd, rest) = hb
  frame.lead.blank(hd, rest, String.ends_with(hd, "\r\n\r\n"))

def frame.at.zero.go(+raw: String, closed: Bool, head: Bool, lead: Lead) -> Frame:
  match lead:
    case LeadCut{}:
      frame.cut(closed)
    case LeadFinal{}:
      parse.res.of(split_at_blank(raw), closed, head)
    case LeadSkip{rest}:
      FrameBad{}

def frame.at.zero(+raw: String, closed: Bool, head: Bool) -> Frame:
  frame.at.zero.go(raw, closed, head, frame.lead(split_at_blank(raw)))

def frame.at.cont(+raw: String, lead: Lead) -> String:
  match lead:
    case LeadCut{}:
      raw
    case LeadFinal{}:
      raw
    case LeadSkip{rest}:
      rest

# ponytail: 8 interim responses; raise the fuel if a server sends more
def frame.at(fuel: Nat, +raw: String, closed: Bool, head: Bool) -> Frame:
  match fuel:
    case 0n:
      frame.at.zero(raw, closed, head)
    case 1n+f:
      frame.at(f, frame.at.cont(raw, frame.lead(split_at_blank(raw))), closed, head)

# frame(bytes so far, server closed?, request was HEAD?)
def frame(raw: String, closed: Bool, head: Bool) -> Frame:
  frame.at(8n, raw, closed, head)

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

def need.te.kind(chunked: Bool) -> Need:
  match chunked:
    case True{}:
      NeedChunk{}
    case False{}:
      NeedClose{}

def need.te(+h: Map<&2, List<&2, String>>, cl: Bool, chunked: Bool) -> Need:
  match cl:
    case True{}:
      NeedNow{}
    case False{}:
      need.te.kind(chunked)

def need.framing(+h: Map<&2, List<&2, String>>, hlen: Nat, te: Bool, cl: Bool) -> Need:
  match te:
    case True{}:
      need.te(h, cl, String.eq(String.to_lower(header.last(h, "transfer-encoding")), "chunked"))
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

def after.rest(hb: String & String) -> String:
  (hd, rest) = hb
  rest

def after.chunk(hb: String & String) -> Maybe<&2, String>:
  (hd, rest) = hb
  chunk.suffix(rest)

def after.need(+raw: String, n: Need) -> Maybe<&2, String>:
  match n:
    case NeedHead{}:
      None{}
    case NeedLen{t}:
      Some{String.drop(raw, t)}
    case NeedChunk{}:
      after.chunk(split_at_blank(raw))
    case NeedClose{}:
      None{}
    case NeedNow{}:
      Some{after.rest(split_at_blank(raw))}

def after.go(+raw: String, n: Need, f: Frame) -> Maybe<&2, String>:
  match f:
    case FrameMore{}:
      None{}
    case FrameBad{}:
      None{}
    case FrameDone{res}:
      after.need(raw, n)

# Bytes after a complete self-delimited message. None if it is not one yet.
def after(+raw: String, +head: Bool) -> Maybe<&2, String>:
  after.go(raw, need(raw, head), frame(raw, False{}, head))

def req.need.te.kind(chunked: Bool) -> Need:
  match chunked:
    case True{}:
      NeedChunk{}
    case False{}:
      NeedNow{}

def req.need.te(+h: Map<&2, List<&2, String>>, cl: Bool, chunked: Bool) -> Need:
  match cl:
    case True{}:
      NeedNow{}
    case False{}:
      req.need.te.kind(chunked)

def req.need.cl(+h: Map<&2, List<&2, String>>, hlen: Nat, cl: Bool) -> Need:
  match cl:
    case True{}:
      need.cl(hlen, parse_u32(header(h, "content-length")))
    case False{}:
      NeedNow{}

def req.need.framing(+h: Map<&2, List<&2, String>>, hlen: Nat, te: Bool, cl: Bool) -> Need:
  match te:
    case True{}:
      req.need.te(h, cl, String.eq(String.to_lower(header.last(h, "transfer-encoding")), "chunked"))
    case False{}:
      req.need.cl(h, hlen, cl)

def req.need.headers(hlen: Nat, fs: Maybe<&2, Map<&2, List<&2, String>>>) -> Need:
  match fs:
    case None{}:
      NeedNow{}
    case Some{+h}:
      req.need.framing(h, hlen, has_header(h, "transfer-encoding"), has_header(h, "content-length"))

def req.need.start3(mpv: String & String & String, headers: List<&2, String>, hlen: Nat) -> Need:
  (+method, path, version) = mpv
  req.need.headers(hlen, parse.headers(headers, FieldsOk{empty()}))

def req.need.lines(xs: List<&2, String>, hlen: Nat) -> Need:
  match xs:
    case Nil{}:
      NeedNow{}
    case Con{line, headers}:
      req.need.start3(start_line(line), headers, hlen)

def req.need.blank(+hd: String, ok: Bool) -> Need:
  match ok:
    case False{}:
      NeedHead{}
    case True{}:
      req.need.lines(String.lines(hd), String.length(hd))

def req.need.of(hb: String & String) -> Need:
  (+hd, rest) = hb
  req.need.blank(hd, String.ends_with(hd, "\r\n\r\n"))

def req.need(+raw: String) -> Need:
  req.need.of(split_at_blank(raw))

def req.after.got(+raw: String, n: Need, g: Got) -> Maybe<&2, String>:
  match g:
    case GotBad{}:
      None{}
    case GotMore{}:
      None{}
    case GotReq{req}:
      after.need(raw, n)

def req.after(+raw: String) -> Maybe<&2, String>:
  req.after.got(raw, req.need(raw), parse.got(raw))


def req.v11.ver(mpv: String & String & String) -> Bool:
  (+method, path, v) = mpv
  String.eq(v, "HTTP/1.1")

def req.v11.line(+line: String) -> Bool:
  req.v11.ver(start_line(line))

def req.v11.lines(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{line, headers}:
      req.v11.line(line)

def req.v11.pick(+head: String, ok: Bool) -> Bool:
  match ok:
    case False{}:
      False{}
    case True{}:
      req.v11.lines(String.lines(head))

def req.v11.of(hb: String & String) -> Bool:
  (+head, rest) = hb
  req.v11.pick(head, String.ends_with(head, "\r\n\r\n"))

def req.v11(+raw: String) -> Bool:
  req.v11.of(split_at_blank(raw))

def req.conn_close(+headers: Map<&2, List<&2, String>>) -> Bool:
  String.eq(String.to_lower(header(headers, "connection")), "close")

def res.conn_close(+headers: Map<&2, List<&2, String>>) -> Bool:
  String.eq(String.to_lower(header(headers, "connection")), "close")

def serve.fail_close(+status: U32) -> Bool:
  Bool.or(U32.is_eq(status, 400), Bool.or(U32.is_eq(status, 413), U32.is_eq(status, 431)))

def serve.keep.ok(fail: Bool, res_close: Bool) -> Bool:
  match fail:
    case True{}:
      False{}
    case False{}:
      Bool.not(res_close)

def serve.keep.v11(v11: Bool, +req_close: Bool, +status: U32, res_close: Bool) -> Bool:
  match v11:
    case False{}:
      False{}
    case True{}:
      match req_close:
        case True{}:
          False{}
        case False{}:
          serve.keep.ok(serve.fail_close(status), res_close)

def serve.keep(+headers: Map<&2, List<&2, String>>, v11: Bool, +status: U32, +res: Map<&2, List<&2, String>>) -> Bool:
  serve.keep.v11(v11, req.conn_close(headers), status, res.conn_close(res))


def again.rest(+close: Bool, +h: Map<&2, List<&2, String>>, rest: Maybe<&2, String>) -> Bool:
  match rest:
    case None{}:
      False{}
    case Some{x}:
      Bool.not(String.eq(String.to_lower(header(h, "connection")), "close"))

# True when the request did not ask to close, the response is self-delimited, and the peer did not say close.
def again(+close: Bool, h: Map<&2, List<&2, String>>, rest: Maybe<&2, String>) -> Bool:
  match close:
    case True{}:
      False{}
    case False{}:
      again.rest(close, h, rest)

def res_body.res(res: Res) -> String:
  Res{status, headers, body} = res
  body

def res_body(m: Maybe<&2, Res>) -> String:
  match m:
    case None{}:
      ""
    case Some{res}:
      res_body.res(res)

def text(res: Res) -> String:
  Enc.utf8.decode(res_body.res(res))

def json(res: Res) -> Maybe<&2, Json.Val>:
  Json.parse(text(res))

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

# RFC 9110 §15. An unknown code gets an empty reason, which RFC 9112 §4 allows.
type Reason is Data:
  Reason{code: U32, text: String}

def reasons() -> List<&2, Reason>:
  [Reason{100, "Continue"}, Reason{101, "Switching Protocols"}, Reason{103, "Early Hints"},
   Reason{200, "OK"}, Reason{201, "Created"}, Reason{202, "Accepted"}, Reason{203, "Non-Authoritative Information"}, Reason{204, "No Content"}, Reason{205, "Reset Content"}, Reason{206, "Partial Content"},
   Reason{300, "Multiple Choices"}, Reason{301, "Moved Permanently"}, Reason{302, "Found"}, Reason{303, "See Other"}, Reason{304, "Not Modified"}, Reason{307, "Temporary Redirect"}, Reason{308, "Permanent Redirect"},
   Reason{400, "Bad Request"}, Reason{401, "Unauthorized"}, Reason{402, "Payment Required"}, Reason{403, "Forbidden"}, Reason{404, "Not Found"}, Reason{405, "Method Not Allowed"}, Reason{406, "Not Acceptable"}, Reason{407, "Proxy Authentication Required"}, Reason{408, "Request Timeout"}, Reason{409, "Conflict"}, Reason{410, "Gone"}, Reason{411, "Length Required"}, Reason{412, "Precondition Failed"}, Reason{413, "Content Too Large"}, Reason{414, "URI Too Long"}, Reason{415, "Unsupported Media Type"}, Reason{416, "Range Not Satisfiable"}, Reason{417, "Expectation Failed"}, Reason{421, "Misdirected Request"}, Reason{422, "Unprocessable Content"}, Reason{426, "Upgrade Required"}, Reason{428, "Precondition Required"}, Reason{429, "Too Many Requests"}, Reason{431, "Request Header Fields Too Large"},
   Reason{500, "Internal Server Error"}, Reason{501, "Not Implemented"}, Reason{502, "Bad Gateway"}, Reason{503, "Service Unavailable"}, Reason{504, "Gateway Timeout"}, Reason{505, "HTTP Version Not Supported"}]

def reason.go(xs: List<&2, Reason>, +status: U32) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{Reason{k, v}, t}:
      Bool.pick(String, U32.is_eq(k, status), v, reason.go(t, status))

def reason(+status: U32) -> String:
  reason.go(reasons(), status)

def response(+status: U32, headers: Map<&2, List<&2, String>>, body: String) -> String:
  ("HTTP/1.1 " ++ U32.show(status) ++ " " ++ reason(status) ++ headers_block(headers)) ++ ("\r\n\r\n" ++ body)

def nat_u32(n: Nat) -> U32:
  match n:
    case 0n:
      0
    case 1n+p:
      (nat_u32(p) + 1 : U32)

# RFC 9110 §6.4.1, §8.6: 1xx, 204 and 304 have no body; HEAD gets the length but no body.
def encode.pick(+status: U32, headers: Map<&2, List<&2, String>>, +body: String, head: Bool, nobody: Bool) -> String:
  match nobody:
    case True{}:
      response(status, headers, "")
    case False{}:
      response(status, set(headers, "content-length", U32.show(nat_u32(String.length(body)))), Bool.pick(String, head, "", body))

def encode.on(r: Res, head: Bool) -> String:
  Res{+status, headers, body} = r
  encode.pick(status, headers, body, head, frame.nobody(status, False{}))

def encode(r: Res) -> String:
  encode.on(r, False{})

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
def encode_req.word(close: Bool) -> String:
  match close:
    case True{}:
      "close"
    case False{}:
      "keep-alive"

def encode_req.on(+method: String, target: String, host: String, headers: Map<&2, List<&2, String>>, +body: String, close: Bool) -> String:
  +h = set(set(req.put(Map.to_list(&2, List<&2, String>, headers), empty()), "host", host), "connection", encode_req.word(close))
  request(method, target, req.cl(h, method, body), body)

def encode_req(+method: String, target: String, host: String, headers: Map<&2, List<&2, String>>, +body: String) -> String:
  encode_req.on(method, target, host, headers, body, True{})

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

def fetch.try.gate(gate: Bool, rbuf: String, closed: Bool, head: Bool) -> Frame:
  match gate:
    case True{}:
      frame(String.reverse(rbuf), closed, head)
    case False{}:
      FrameMore{}

def fetch.chunked(need: Need) -> Bool:
  match need:
    case NeedChunk{}:
      True{}
    case NeedHead{}:
      False{}
    case NeedLen{t}:
      False{}
    case NeedClose{}:
      False{}
    case NeedNow{}:
      False{}

# A bad chunk does not end in CRLF CRLF, so the gate must not skip it.
def fetch.try.go(gate: Bool, chunked: Bool, rbuf: String, closed: Bool, head: Bool) -> Frame:
  match chunked:
    case True{}:
      frame(String.reverse(rbuf), closed, head)
    case False{}:
      fetch.try.gate(gate, rbuf, closed, head)

def fetch.try(gate: Bool, need: Need, rbuf: String, closed: Bool, head: Bool) -> Frame:
  fetch.try.go(gate, fetch.chunked(need), rbuf, closed, head)

def fetch.step(+head: Bool, s: Socket, rd: Rd, +got: String, +closed: Bool) -> Socket & Rd:
  Rd{rbuf, n, need, f, err} = rd
  +rbuf2 = {String.reverse(got) ++ rbuf : String}
  +n2 = Nat.add(n, String.length(got))
  +need2 = fetch.need(need, rbuf2, head)
  (s, Rd{rbuf2, n2, need2, fetch.cap(fetch.try(fetch.gate(closed, need2, n2, got), need2, rbuf2, closed, head), Nat.is_lt(fetch.max(), n2)), None{}})

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

# none: no response byte arrived, so an idempotent request may be retried (RFC 9112 §9.3.1).
# sock: the socket, when it can take another request.
type Out is Type:
  OutDone{res: Res, sock: Maybe<&1, Socket>, rest: String}
  OutFail{e: Err, none: Bool}

def fetch.boxed(r: Result<&2, &2, Err, Res>, none: Bool) -> Out:
  match r:
    case Done{res}:
      OutDone{res, None{}, ""}
    case Fail{e}:
      OutFail{e, none}

def fetch.bad(tls: Bool, s: Socket, e: Maybe<&2, Err>) -> IO(Result<&2, &2, Err, Res>):
  match e:
    case None{}:
      fetch.close(tls, s, Fail{ErrBad{}})
    case Some{err}:
      fetch.close(tls, s, Fail{err})

def fetch.rest(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      ""
    case Some{s}:
      s

def fetch.shut(tls: Bool, s: Socket, r: Result<&2, &2, Err, Res>, none: Bool) -> IO(Out):
  do IO<Out>:
    x : Result<&2, &2, Err, Res> <- fetch.close(tls, s, r)
    return fetch.boxed(x, none)

def fetch.hold.go(tls: Bool, s: Socket, res: Res, left: Maybe<&2, String>, ok: Bool) -> IO(Out):
  match ok:
    case True{}:
      IO.pure(Out, OutDone{res, Some{s}, fetch.rest(left)})
    case False{}:
      fetch.shut(tls, s, Done{res}, False{})

def fetch.hold(tls: Bool, +close: Bool, s: Socket, +rbuf: String, head: Bool, res: Res) -> IO(Out):
  Res{status, +headers, body} = res
  +left = after(String.reverse(rbuf), head)
  fetch.hold.go(tls, s, res, left, again(close, headers, left))

def fetch.failout(tls: Bool, s: Socket, e: Maybe<&2, Err>, none: Bool) -> IO(Out):
  do IO<Out>:
    r : Result<&2, &2, Err, Res> <- fetch.bad(tls, s, e)
    return fetch.boxed(r, none)

# Reads until frame says Done or Bad; an empty recv means the server closed.
@unsafe
def fetch.loop(+close: Bool, +head: Bool, +tls: Bool, +ms: U32, st: Socket & Rd) -> IO(Out):
  (s, rd) = st
  Rd{rbuf, +n, need, f, err} = rd
  match f:
    case FrameMore{}:
      do IO<Out>:
        m : Socket & Result<&1, &1, U32 & String, String> <- io.recv(tls, s, 65536, ms)
        fetch.loop(close, head, tls, ms, fetch.next(head, Rd{rbuf, n, need, FrameMore{}, None{}}, m))
    case FrameBad{}:
      fetch.failout(tls, s, err, Nat.is_eq(n, 0n))
    case FrameDone{res}:
      fetch.hold(tls, close, s, rbuf, head, res)

def exchange.sent(+tls: Bool, +ms: U32, +close: Bool, +head: Bool, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Out):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      fetch.shut(tls, s, Fail{err.or_late(code, ErrWrite{code, why})}, True{})
    case Done{u}:
      fetch.loop(close, head, tls, ms, (s, Rd{"", 0n, NeedHead{}, FrameMore{}, None{}}))

def exchange.go(+tls: Bool, +ms: U32, +close: Bool, +head: Bool, s: Socket, wire: String) -> IO(Out):
  do IO<Out>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send(tls, s, wire)
    exchange.sent(tls, ms, close, head, sent)

def exchange.tup(o: Out) -> Maybe<&1, Socket> & Result<&2, &2, Err, Res> & String:
  match o:
    case OutFail{e, none}:
      (None{}, Fail{e}, "")
    case OutDone{res, sock, rest}:
      (sock, Done{res}, rest)

# One request on an open socket. Some{socket}: it can take another request.
def exchange(+tls: Bool, +ms: U32, +close: Bool, +head: Bool, s: Socket, wire: String) -> IO(Maybe<&1, Socket> & Result<&2, &2, Err, Res> & String):
  do IO<Maybe<&1, Socket> & Result<&2, &2, Err, Res> & String>:
    o : Out <- exchange.go(tls, ms, close, head, s, wire)
    return exchange.tup(o)

# Connection pool: idle sockets by scheme, host, and port. fetch uses a fresh pool per call.
type Conn is Type:
  Conn{tls: Bool, s: Socket}

type Pool is Type:
  Pool{idle: Map<&1, Conn>}

def pool.new() -> Pool:
  Pool{Map.new(&1, Conn)}

def pool.key(+scheme: String, +host: String, +port: U32) -> String:
  scheme ++ "://" ++ host ++ ":" ++ U32.show(port)

def pool.take.of(r: Map<&1, Conn> & Maybe<&1, Conn>) -> Pool & Maybe<&1, Conn>:
  (m, c) = r
  (Pool{m}, c)

def pool.take(p: Pool, +key: String) -> Pool & Maybe<&1, Conn>:
  Pool{idle} = p
  pool.take.of(Map.pop(&1, Conn, idle, key))

def conn.close(c: Conn) -> IO(Unit):
  Conn{tls, s} = c
  io.close(tls, s)

def conn.drop(m: Maybe<&1, Conn>) -> IO(Unit):
  match m:
    case None{}:
      IO.pure(Unit, Unit{})
    case Some{c}:
      conn.close(c)

# ponytail: one idle socket per origin; a second one replaces the first.
def pool.give.of(+key: String, c: Conn, r: Map<&1, Conn> & Maybe<&1, Conn>) -> IO(Pool):
  (m, old) = r
  do IO<Pool>:
    conn.drop(old)
    return Pool{Map.set(&1, Conn, m, key, c)}

def pool.give(p: Pool, +key: String, c: Conn) -> IO(Pool):
  Pool{idle} = p
  pool.give.of(key, c, Map.pop(&1, Conn, idle, key))

def pool.close.go(xs: List<&1, Conn>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{c, t}:
      do IO<Unit>:
        conn.close(c)
        pool.close.go(t)

def pool.close(p: Pool) -> IO(Unit):
  Pool{idle} = p
  pool.close.go(Map.values(&1, Conn, idle))

# RFC 9110 §9.2.2
def pool.idempotent(+method: String) -> Bool:
  Bool.or(String.eq(method, "GET"), Bool.or(String.eq(method, "HEAD"), Bool.or(String.eq(method, "OPTIONS"), Bool.or(String.eq(method, "TRACE"), Bool.or(String.eq(method, "PUT"), String.eq(method, "DELETE"))))))

def conn.tls(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Err, Conn>):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      do IO<Result<&1, &1, Err, Conn>>:
        Wire.tls.close(s)
        return Fail{err.or_late(code, ErrTls{code, why})}
    case Done{u}:
      IO.pure(Result<&1, &1, Err, Conn>, Done{Conn{True{}, s}})

# A failed handshake is an error, never plaintext.
def conn.secure(+ms: U32, sni: String, s: Socket, tls: Bool) -> IO(Result<&1, &1, Err, Conn>):
  match tls:
    case False{}:
      IO.pure(Result<&1, &1, Err, Conn>, Done{Conn{False{}, s}})
    case True{}:
      do IO<Result<&1, &1, Err, Conn>>:
        hs : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(s, sni, ms)
        conn.tls(hs)

def conn.made(+ms: U32, sni: String, tls: Bool, r: Result<&1, &1, U32 & String, Socket>) -> IO(Result<&1, &1, Err, Conn>):
  match r:
    case Fail{(+code, why)}:
      IO.pure(Result<&1, &1, Err, Conn>, Fail{err.or_late(code, ErrConnect{code, why})})
    case Done{s}:
      conn.secure(ms, sni, s, tls)

def conn.open(+tls: Bool, +ms: U32, sni: String, ip: String, port: U32) -> IO(Result<&1, &1, Err, Conn>):
  do IO<Result<&1, &1, Err, Conn>>:
    c : Result<&1, &1, U32 & String, Socket> <- Wire.connect(ip, port, ms)
    conn.made(ms, sni, tls, c)

def conn.ex(c: Conn, +ms: U32, +head: Bool, wire: String) -> IO(Out):
  Conn{+tls, s} = c
  exchange.go(tls, ms, False{}, head, s, wire)

# A socket with bytes past the response is out of step with the server, so it is closed.
def pool.keep.s(p: Pool, +key: String, +tls: Bool, res: Res, s: Socket, clean: Bool) -> IO(Pool & Result<&2, &2, Err, Res>):
  match clean:
    case True{}:
      do IO<Pool & Result<&2, &2, Err, Res>>:
        p2 : Pool <- pool.give(p, key, Conn{tls, s})
        return (p2, Done{res})
    case False{}:
      do IO<Pool & Result<&2, &2, Err, Res>>:
        io.close(tls, s)
        return (p, Done{res})

def pool.keep(p: Pool, +key: String, +tls: Bool, res: Res, sock: Maybe<&1, Socket>, +rest: String) -> IO(Pool & Result<&2, &2, Err, Res>):
  match sock:
    case None{}:
      IO.pure(Pool & Result<&2, &2, Err, Res>, (p, Done{res}))
    case Some{s}:
      pool.keep.s(p, key, tls, res, s, String.is_empty(rest))

def pool.after(p: Pool, +key: String, +tls: Bool, o: Out) -> IO(Pool & Result<&2, &2, Err, Res>):
  match o:
    case OutFail{e, none}:
      IO.pure(Pool & Result<&2, &2, Err, Res>, (p, Fail{e}))
    case OutDone{res, sock, rest}:
      pool.keep(p, key, tls, res, sock, rest)

def pool.fresh.conn(p: Pool, +key: String, +tls: Bool, +ms: U32, +head: Bool, wire: String, r: Result<&1, &1, Err, Conn>) -> IO(Pool & Result<&2, &2, Err, Res>):
  match r:
    case Fail{e}:
      IO.pure(Pool & Result<&2, &2, Err, Res>, (p, Fail{e}))
    case Done{c}:
      do IO<Pool & Result<&2, &2, Err, Res>>:
        o : Out <- conn.ex(c, ms, head, wire)
        pool.after(p, key, tls, o)

def pool.fresh.ip(p: Pool, +key: String, +tls: Bool, +ms: U32, +head: Bool, +host: String, +port: U32, wire: String, ip: Maybe<&2, String>) -> IO(Pool & Result<&2, &2, Err, Res>):
  match ip:
    case None{}:
      IO.pure(Pool & Result<&2, &2, Err, Res>, (p, Fail{ErrDns{}}))
    case Some{addr}:
      do IO<Pool & Result<&2, &2, Err, Res>>:
        c : Result<&1, &1, Err, Conn> <- conn.open(tls, ms, host, addr, port)
        pool.fresh.conn(p, key, tls, ms, head, wire, c)

def pool.fresh(p: Pool, +key: String, +tls: Bool, +ms: U32, +head: Bool, +host: String, +port: U32, wire: String) -> IO(Pool & Result<&2, &2, Err, Res>):
  do IO<Pool & Result<&2, &2, Err, Res>>:
    ip : Maybe<&2, String> <- Dns.resolve(host)
    pool.fresh.ip(p, key, tls, ms, head, host, port, wire, ip)

# A reused socket the server already closed fails before any response byte.
def pool.retry(+none: Bool, +idem: Bool) -> Bool:
  Bool.and(none, idem)

def pool.stale(p: Pool, +key: String, +tls: Bool, +ms: U32, +head: Bool, +host: String, +port: U32, wire: String, e: Err, again: Bool) -> IO(Pool & Result<&2, &2, Err, Res>):
  match again:
    case True{}:
      pool.fresh(p, key, tls, ms, head, host, port, wire)
    case False{}:
      IO.pure(Pool & Result<&2, &2, Err, Res>, (p, Fail{e}))

def pool.reused(p: Pool, +key: String, +tls: Bool, +ms: U32, +head: Bool, +idem: Bool, +host: String, +port: U32, wire: String, o: Out) -> IO(Pool & Result<&2, &2, Err, Res>):
  match o:
    case OutFail{e, +none}:
      pool.stale(p, key, tls, ms, head, host, port, wire, e, pool.retry(none, idem))
    case OutDone{res, sock, rest}:
      pool.keep(p, key, tls, res, sock, rest)

def pool.idle(taken: Pool & Maybe<&1, Conn>, +key: String, +tls: Bool, +ms: U32, +head: Bool, +idem: Bool, +host: String, +port: U32, +wire: String) -> IO(Pool & Result<&2, &2, Err, Res>):
  (p, m) = taken
  match m:
    case None{}:
      pool.fresh(p, key, tls, ms, head, host, port, wire)
    case Some{c}:
      do IO<Pool & Result<&2, &2, Err, Res>>:
        o : Out <- conn.ex(c, ms, head, wire)
        pool.reused(p, key, tls, ms, head, idem, host, port, wire, o)

def pool.origin(p: Pool, +method: String, +ms: U32, headers: Map<&2, List<&2, String>>, body: String, +hf: String, a: Url.Abs, known: Bool) -> IO(Pool & Result<&2, &2, Err, Res>):
  Url.Abs{+scheme, +host, +port, target} = a
  match known:
    case False{}:
      IO.pure(Pool & Result<&2, &2, Err, Res>, (p, Fail{ErrUrl{}}))
    case True{}:
      +key = pool.key(scheme, host, port)
      pool.idle(pool.take(p, key), key, String.eq(scheme, "https"), ms, String.eq(method, "HEAD"), pool.idempotent(method), host, port, encode_req.on(method, target, hf, headers, body, False{}))

def pool.scheme.ok(a: Url.Abs) -> Bool:
  Url.Abs{+scheme, host, port, target} = a
  Bool.or(String.eq(scheme, "http"), String.eq(scheme, "https"))

# One request, on an idle socket to its origin when the pool has one.
def pool.one(p: Pool, h: Hop, +ms: U32) -> IO(Pool & Result<&2, &2, Err, Res>):
  Hop{method, +url, headers, body} = h
  pool.origin(p, method, ms, headers, body, Url.host_field(url), url, pool.scheme.ok(url))

type Next is Data:
  NDone{res: Result<&2, &2, Err, Res>}
  NStop{}
  NGo{left: Nat, hop: Hop}

type Mode is Data:
  ModeFollow{}
  ModeManual{}
  ModeError{}

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

def fetch.error.res(r: Res, bad: Bool) -> Next:
  match bad:
    case True{}:
      NDone{Fail{ErrRedirect{}}}
    case False{}:
      NDone{Done{r}}

def fetch.error(h: Hop, m: Result<&2, &2, Err, Res>) -> Next:
  match m:
    case Fail{e}:
      NDone{Fail{e}}
    case Done{r}:
      Res{+status, +headers, body} = r
      fetch.error.res(r, Bool.and(redirect.code(status), has_header(headers, "location")))

def fetch.policy(mode: Mode, left: Nat, h: Hop, m: Result<&2, &2, Err, Res>) -> Next:
  match mode:
    case ModeFollow{}:
      fetch.decide(left, h, m)
    case ModeManual{}:
      NDone{m}
    case ModeError{}:
      fetch.error(h, m)

# A caller's own Accept-Encoding wins.
def accept.enc(+h: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  Bool.pick(Map<&2, List<&2, String>>, has_header(h, "accept-encoding"), h, set(h, "accept-encoding", "gzip, deflate"))

def fetch.start(method: String, headers: Map<&2, List<&2, String>>, body: String, u: Maybe<&2, Url.Abs>) -> Next:
  match u:
    case None{}:
      NDone{Fail{ErrUrl{}}}
    case Some{a}:
      NGo{20n, Hop{method, a, accept.enc(req.put(Map.to_list(&2, List<&2, String>, headers), empty())), body}}

def pool.next(+mode: Mode, left: Nat, h: Hop, pr: Pool & Result<&2, &2, Err, Res>) -> Pool & Next:
  (p, m) = pr
  (p, fetch.policy(mode, left, h, m))

# NGo.left is how many redirects may follow this request. 20 is WHATWG's limit.
@unsafe
def pool.hops(+mode: Mode, +ms: U32, st: Pool & Next) -> IO(Pool & Result<&2, &2, Err, Res>):
  (p, n) = st
  match n:
    case NDone{m}:
      IO.pure(Pool & Result<&2, &2, Err, Res>, (p, m))
    case NStop{}:
      IO.pure(Pool & Result<&2, &2, Err, Res>, (p, Fail{ErrRedirect{}}))
    case NGo{+left, +h}:
      do IO<Pool & Result<&2, &2, Err, Res>>:
        pr : Pool & Result<&2, &2, Err, Res> <- pool.one(p, h, ms)
        pool.hops(mode, ms, pool.next(mode, left, h, pr))

# Content-Encoding (RFC 9110 §8.4): each value, trimmed and lowercased, in the order applied.
def ce.keep(+w: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.is_empty(w), rest, Con{w, rest})

def ce.norm(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{v, t}:
      ce.keep(String.to_lower(String.trim(v)), ce.norm(t))

def ce.split(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{v, t}:
      List.append(&2, String, ce.norm(String.split(v, ',')), ce.split(t))

# Ok: decoded so far. Bad: a coding failed. Skip: a coding we cannot decode, so the body stays as sent.
type Dec is Data:
  DecOk{b: String}
  DecBad{}
  DecSkip{}

def ce.of(m: Maybe<&2, String>) -> Dec:
  match m:
    case None{}:
      DecBad{}
    case Some{b}:
      DecOk{b}

# Servers send deflate both with and without the zlib wrapper.
def ce.deflate(+b: String, m: Maybe<&2, String>) -> Dec:
  match m:
    case Some{out}:
      DecOk{out}
    case None{}:
      ce.of(Zlib.inflate(b))

def ce.apply(+c: String, +b: String) -> Dec:
  Bool.pick(Dec, Bool.or(String.eq(c, "gzip"), String.eq(c, "x-gzip")), ce.of(Zlib.gunzip(b)),
    Bool.pick(Dec, String.eq(c, "deflate"), ce.deflate(b, Zlib.unzlib(b)),
      Bool.pick(Dec, String.eq(c, "identity"), DecOk{b}, DecSkip{})))

def ce.go(cs: List<&2, String>, d: Dec) -> Dec:
  match cs:
    case Nil{}:
      d
    case Con{+c, t}:
      match d:
        case DecOk{+b}:
          ce.go(t, ce.apply(c, b))
        case DecBad{}:
          DecBad{}
        case DecSkip{}:
          DecSkip{}

def decoded.pick(d: Dec, +status: U32, headers: Map<&2, List<&2, String>>, body: String) -> Result<&2, &2, Err, Res>:
  match d:
    case DecOk{b}:
      Done{Res{status, headers, b}}
    case DecBad{}:
      Fail{ErrBad{}}
    case DecSkip{}:
      Done{Res{status, headers, body}}

def decoded.go(empty: Bool, +status: U32, +headers: Map<&2, List<&2, String>>, +body: String) -> Result<&2, &2, Err, Res>:
  match empty:
    case True{}:
      Done{Res{status, headers, body}}
    case False{}:
      decoded.pick(ce.go(List.reverse(&2, String, ce.split(fields(headers, "content-encoding"))), DecOk{body}), status, headers, body)

# The body decoded per Content-Encoding; the headers stay as sent. A corrupt body is ErrBad.
def decoded(res: Res) -> Result<&2, &2, Err, Res>:
  Res{+status, +headers, +body} = res
  decoded.go(String.is_empty(body), status, headers, body)

def decoded.m(r: Result<&2, &2, Err, Res>) -> Maybe<&2, Res>:
  match r:
    case Done{x}:
      Some{x}
    case Fail{e}:
      None{}

def decoded.some(res: Res) -> Maybe<&2, Res>:
  decoded.m(decoded(res))

# The final response of a fetch, after redirects.
def fetch.final(r: Result<&2, &2, Err, Res>) -> Result<&2, &2, Err, Res>:
  match r:
    case Done{res}:
      decoded(res)
    case Fail{e}:
      Fail{e}

def pool.final(pr: Pool & Result<&2, &2, Err, Res>) -> Pool & Result<&2, &2, Err, Res>:
  (p, r) = pr
  (p, fetch.final(r))

# pool.how(p, "GET", "https://example.com/x?y=1", headers, body, ms, mode) follows redirects
# on p's idle sockets. Fail is a bad URL, a failed lookup, connect, handshake, send, read,
# a malformed response, more than 20 redirects, or a step past ms. Bodies are bytes.
def pool.how(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: String, ms: U32, mode: Mode) -> IO(Pool & Result<&2, &2, Err, Res>):
  do IO<Pool & Result<&2, &2, Err, Res>>:
    pr : Pool & Result<&2, &2, Err, Res> <- pool.hops(mode, ms, (p, fetch.start(method, headers, body, Url.absolute(url))))
    return pool.final(pr)

def pool.fetch.with(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: String, ms: U32) -> IO(Pool & Result<&2, &2, Err, Res>):
  pool.how(p, method, url, headers, body, ms, ModeFollow{})

def pool.fetch(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: String) -> IO(Pool & Result<&2, &2, Err, Res>):
  pool.fetch.with(p, method, url, headers, body, 30000)

def fetch.end(pr: Pool & Result<&2, &2, Err, Res>) -> IO(Result<&2, &2, Err, Res>):
  (p, r) = pr
  do IO<Result<&2, &2, Err, Res>>:
    pool.close(p)
    return r

# fetch is pool.how on a fresh pool that closes afterwards.
def fetch.how(method: String, url: String, headers: Map<&2, List<&2, String>>, body: String, ms: U32, mode: Mode) -> IO(Result<&2, &2, Err, Res>):
  do IO<Result<&2, &2, Err, Res>>:
    pr : Pool & Result<&2, &2, Err, Res> <- pool.how(pool.new(), method, url, headers, body, ms, mode)
    fetch.end(pr)

def fetch.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: String, ms: U32) -> IO(Result<&2, &2, Err, Res>):
  fetch.how(method, url, headers, body, ms, ModeFollow{})

# fetch.with and a 30 s step timeout.
def fetch(method: String, url: String, headers: Map<&2, List<&2, String>>, body: String) -> IO(Result<&2, &2, Err, Res>):
  fetch.with(method, url, headers, body, 30000)

def get(url: String) -> IO(Result<&2, &2, Err, Res>):
  fetch("GET", url, empty(), "")

def reply.bytes(res: Res, head: Bool, close: Bool) -> String:
  Res{+status, +headers, +body} = res
  encode.on(Res{status, Bool.pick(Map<&2, List<&2, String>>, close, set(headers, "connection", "close"), headers), body}, head)

def reply.fail.bytes(+status: U32) -> Res:
  Res{status, empty(), reason(status)}

def reply.sent.close(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def reply_fail(s: Socket, +status: U32) -> IO(Unit):
  do IO<Unit>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send(s, encode(reply.fail.bytes(status)))
    reply.sent.close(sent)


# dc decodes a chunked body as it arrives, so the whole buffer is framed once.
type Rq is Data:
  Rq{rbuf: String, n: Nat, need: Need, g: Got, dc: Dco}

type Turn is Data:
  TurnClose{}
  TurnFail{status: U32}
  TurnReq{req: Req, rest: Maybe<&2, String>, v11: Bool}
  TurnMore{rq: Rq}

def serve.need(hint: Need, +rbuf: String) -> Need:
  match hint:
    case NeedHead{}:
      req.need(String.reverse(rbuf))
    case NeedLen{t}:
      NeedLen{t}
    case NeedChunk{}:
      NeedChunk{}
    case NeedClose{}:
      NeedClose{}
    case NeedNow{}:
      NeedNow{}

def serve.gate(closed: Bool, need: Need, +n: Nat, +got: String) -> Bool:
  fetch.gate(closed, need, n, got)

def serve.try.gate(gate: Bool, +rbuf: String) -> Got:
  match gate:
    case True{}:
      parse.got(String.reverse(rbuf))
    case False{}:
      GotMore{}

def serve.try.go(gate: Bool, chunked: Bool, rbuf: String) -> Got:
  match chunked:
    case True{}:
      parse.got(String.reverse(rbuf))
    case False{}:
      serve.try.gate(gate, rbuf)

def serve.try.closed.got(closed: Bool, g: Got) -> Got:
  match closed:
    case False{}:
      g
    case True{}:
      match g:
        case GotMore{}:
          GotBad{}
        case GotBad{}:
          GotBad{}
        case GotReq{req}:
          GotReq{req}

def serve.try(gate: Bool, need: Need, rbuf: String, closed: Bool) -> Got:
  serve.try.closed.got(closed, serve.try.go(gate, fetch.chunked(need), rbuf))

# ponytail: 64 KiB header allowance above the body cap; larger configurable headers need a separate limit.
def serve.limit(+max: Nat) -> Nat:
  Nat.add(max, 65536n)

def serve.big(+max: Nat, +n: Nat) -> Bool:
  Nat.is_lt(serve.limit(max), n)

def serve.cl_big(+max: Nat, need: Need) -> Bool:
  match need:
    case NeedLen{t}:
      Nat.is_lt(serve.limit(max), t)
    case NeedHead{}:
      False{}
    case NeedChunk{}:
      False{}
    case NeedClose{}:
      False{}
    case NeedNow{}:
      False{}

# RFC 6585 §5: a head over 64 KiB is refused; an open one is refused before it can cost O(n²).
def serve.head_big(+n: Nat, need: Need) -> Bool:
  match need:
    case NeedHead{}:
      Nat.is_lt(65536n, n)
    case NeedLen{t}:
      False{}
    case NeedChunk{}:
      False{}
    case NeedClose{}:
      False{}
    case NeedNow{}:
      False{}

def serve.too_big(+max: Nat, n: Nat, need: Need) -> Bool:
  Bool.or(serve.big(max, n), serve.cl_big(max, need))

def dc.none() -> Dco:
  Dco{dc.start(), "", ""}

def talk.rq0() -> Rq:
  Rq{"", 0n, NeedHead{}, GotMore{}, dc.none()}

def serve.body.of(hb: String & String) -> String:
  (hd, rest) = hb
  rest

# The head just came in: decode the body bytes that came with it. Later reads feed only their own bytes.
def serve.dc.more(got: String, o: Dco) -> Dco:
  Dco{st, racc, rest} = o
  dc.feed(got, st, racc)

# The head just came in: decode the body bytes that came with it. Later reads feed only their own bytes.
def serve.dc(old: Need, +rbuf: String, got: String, o: Dco) -> Dco:
  match old:
    case NeedHead{}:
      dc.feed(serve.body.of(split_at_blank(String.reverse(rbuf))), dc.start(), "")
    case NeedLen{t}:
      serve.dc.more(got, o)
    case NeedChunk{}:
      serve.dc.more(got, o)
    case NeedClose{}:
      serve.dc.more(got, o)
    case NeedNow{}:
      serve.dc.more(got, o)

def serve.dc.got(o: Dco, +rbuf: String, closed: Bool) -> Got:
  Dco{st, racc, rest} = o
  match st:
    case DcDone{}:
      parse.got(String.reverse(rbuf))
    case DcBad{}:
      GotBad{}
    case DcSize{a, b}:
      Bool.pick(Got, closed, GotBad{}, GotMore{})
    case DcExt{x}:
      Bool.pick(Got, closed, GotBad{}, GotMore{})
    case DcSizeLf{x}:
      Bool.pick(Got, closed, GotBad{}, GotMore{})
    case DcData{k}:
      Bool.pick(Got, closed, GotBad{}, GotMore{})
    case DcDataCr{}:
      Bool.pick(Got, closed, GotBad{}, GotMore{})
    case DcDataLf{}:
      Bool.pick(Got, closed, GotBad{}, GotMore{})
    case DcTr{j}:
      Bool.pick(Got, closed, GotBad{}, GotMore{})

def talk.step.pick(chunked: Bool, +rbuf2: String, +n2: Nat, +need: Need, +need2: Need, +got: String, +closed: Bool, dc: Dco) -> Rq:
  match chunked:
    case True{}:
      +dc2 = serve.dc(need, rbuf2, got, dc)
      Rq{rbuf2, n2, need2, serve.dc.got(dc2, rbuf2, closed), dc2}
    case False{}:
      Rq{rbuf2, n2, need2, serve.try(serve.gate(closed, need2, n2, got), need2, rbuf2, closed), dc}

def talk.step(rq: Rq, +got: String, +closed: Bool) -> Rq:
  Rq{rbuf, n, +need, g, dc} = rq
  +rbuf2 = {String.reverse(got) ++ rbuf : String}
  +n2 = Nat.add(n, String.length(got))
  +need2 = serve.need(need, rbuf2)
  talk.step.pick(fetch.chunked(need2), rbuf2, n2, need, need2, got, closed, dc)

# Pipelined bytes left over from the last request.
def talk.rq(+raw: String) -> Rq:
  talk.step(talk.rq0(), raw, False{})

def serve.head_long(hb: String & String) -> Bool:
  (+hd, rest) = hb
  Nat.is_lt(65536n, String.length(hd))

def talk.turn.req(req: Req, +raw: String, long: Bool) -> Turn:
  match long:
    case True{}:
      TurnFail{431}
    case False{}:
      TurnReq{req, req.after(raw), req.v11(raw)}

def talk.turn.got(+rbuf: String, n: Nat, need: Need, g: Got, dc: Dco) -> Turn:
  match g:
    case GotBad{}:
      TurnFail{400}
    case GotMore{}:
      TurnMore{Rq{rbuf, n, need, g, dc}}
    case GotReq{req}:
      +raw = String.reverse(rbuf)
      talk.turn.req(req, raw, serve.head_long(split_at_blank(raw)))

def talk.turn.head(big: Bool, rbuf: String, n: Nat, need: Need, g: Got, dc: Dco) -> Turn:
  match big:
    case True{}:
      TurnFail{431}
    case False{}:
      talk.turn.got(rbuf, n, need, g, dc)

def talk.turn.pick(big: Bool, rbuf: String, +n: Nat, +need: Need, g: Got, dc: Dco) -> Turn:
  match big:
    case True{}:
      TurnFail{413}
    case False{}:
      talk.turn.head(serve.head_big(n, need), rbuf, n, need, g, dc)

def talk.turn.check(+max: Nat, +n: Nat, +need: Need, rbuf: String, g: Got, dc: Dco) -> Turn:
  talk.turn.pick(serve.too_big(max, n, need), rbuf, n, need, g, dc)

def talk.turn(max: Nat, rq: Rq) -> Turn:
  Rq{rbuf, n, need, g, dc} = rq
  talk.turn.check(max, n, need, rbuf, g, dc)

def serve.max() -> Nat:
  fetch.max()

def talk.next(+max: Nat, rq: Rq, m: Socket & Result<&1, &1, U32 & String, String>) -> Socket & Turn:
  (s, r) = m
  match r:
    case Fail{e}:
      (s, TurnClose{})
    case Done{+got}:
      (s, talk.turn(max, talk.step(rq, got, String.is_empty(got))))


def talk.keep(+headers: Map<&2, List<&2, String>>, v11: Bool, +res: Res) -> Bool:
  Res{+status, +rh, body} = res
  serve.keep(headers, v11, status, rh)


def talk.after.rest.raw(+max: Nat, +raw: String, empty: Bool, s: Socket) -> Socket & Turn:
  match empty:
    case True{}:
      (s, TurnMore{talk.rq0()})
    case False{}:
      (s, talk.turn(max, talk.rq(raw)))

def talk.after.rest(+max: Nat, rest: Maybe<&2, String>, s: Socket) -> Socket & Turn:
  match rest:
    case None{}:
      (s, TurnMore{talk.rq0()})
    case Some{+raw}:
      talk.after.rest.raw(max, raw, String.is_empty(raw), s)


def talk.after.keep(+max: Nat, keep: Bool, rest: Maybe<&2, String>, s: Socket) -> Socket & Turn:
  match keep:
    case False{}:
      (s, TurnClose{})
    case True{}:
      talk.after.rest(max, rest, s)

def talk.after(+max: Nat, keep: Bool, rest: Maybe<&2, String>, m: Socket & Result<&1, &1, U32 & String, Unit>) -> Socket & Turn:
  (s, r) = m
  match r:
    case Fail{e}:
      (s, TurnClose{})
    case Done{unit}:
      talk.after.keep(max, keep, rest, s)

def talk.send(+max: Nat, s: Socket, rest: Maybe<&2, String>, +headers: Map<&2, List<&2, String>>, v11: Bool, +head: Bool, +res: Res) -> IO(Socket & Turn):
  +keep = talk.keep(headers, v11, res)
  do IO<Socket & Turn>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send(s, reply.bytes(res, head, Bool.not(keep)))
    return talk.after(max, keep, rest, sent)


@unsafe
def talk(~h: Req -> IO(Res), +max: Nat, st: Socket & Turn) -> IO(Unit):
  (s, t) = st
  match t:
    case TurnMore{rq}:
      do IO<Unit>:
        m : Socket & Result<&1, &1, U32 & String, String> <- Wire.recv(s, 65536, 30000)
        talk(~h, max, talk.next(max, rq, m))
    case TurnReq{req, rest, v11}:
      Req{+method, path, +headers, body} = req
      do IO<Unit>:
        res : Res <- h(Req{method, path, headers, body})
        next : Socket & Turn <- talk.send(max, s, rest, headers, v11, String.eq(method, "HEAD"), res)
        talk(~h, max, next)
    case TurnFail{status}:
      reply_fail(s, status)
    case TurnClose{}:
      Socket.close(s)

def conn(~h: Req -> IO(Res), +max: Nat, m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, talk(~h, max, (s, TurnMore{talk.rq0()})))
    return l

@unsafe
def loop(~h: Req -> IO(Res), +max: Nat, l: Listener) -> IO(Unit):
  do IO<Unit>:
    m  : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- conn(~h, max, m)
    loop(~h, max, l2)

def serve.with(~h: Req -> IO(Res), +port: U32, +max: Nat) -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(port))
    IO.print("http://127.0.0.1:" ++ U32.show(port))
    loop(~h, max, l)

def serve(~h: Req -> IO(Res), +port: U32) -> IO(Unit):
  serve.with(~h, port, serve.max())
