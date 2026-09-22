import Base

# HTTP/1.1 codec (RFC 9112). No TLS, no DNS, no chunked.
# parse: start-line → field lines → blank → body length (§6.3).
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



def parse.take(rest: String, n: Maybe<&2, U32>) -> Maybe<&2, String>:
  match n:
    case None{}:
      None{}
    case Some{k}:
      Some{String.take(rest, U32.to_nat(k))}

type HexSize is Data:
  HexSize{n: U32, rest: String}

def is_hex(+c: U32) -> Bool:
  Bool.or(parse_u32.digit(c), Bool.or(Bool.and(U32.is_le(97, c), U32.is_le(c, 102)), Bool.and(U32.is_le(65, c), U32.is_le(c, 70))))

def hexv(+c: U32) -> U32:
  Bool.pick(U32, parse_u32.digit(c), (c - 48 : U32), Bool.pick(U32, U32.is_le(c, 70), (c - 55 : U32), (c - 87 : U32)))

def chunk.lf1(r: String, n: U32, lf: Bool) -> Maybe<&2, HexSize>:
  match lf:
    case False{}:
      None{}
    case True{}:
      Some{HexSize{n, r}}

def chunk.lf(t: String, n: U32) -> Maybe<&2, HexSize>:
  match t:
    case SNil{}:
      None{}
    case SCon{Chr{c}, r}:
      chunk.lf1(r, n, U32.is_eq(c, 10))

def chunk.cr(c: U32, t: String, n: U32, seen: Bool, cr: Bool) -> Maybe<&2, HexSize>:
  match cr:
    case True{}:
      chunk.lf(t, n)
    case False{}:
      None{}

def chunk.size.go(s: String, +acc: U32, seen: Bool) -> Maybe<&2, HexSize>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, +t}:
      Bool.pick(Maybe<&2, HexSize>, is_hex(c), chunk.size.go(t, (acc * 16 + hexv(c) : U32), True{}), chunk.cr(c, t, acc, seen, U32.is_eq(c, 13)))

def chunk.size(s: String) -> Maybe<&2, HexSize>:
  chunk.size.go(s, 0, False{})

def chunk.last.if(+s: String, acc: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{acc}

def chunk.last(+s: String, acc: String) -> Maybe<&2, String>:
  chunk.last.if(s, acc, String.starts_with(s, "\r\n"))

def chunk.end1(n: U32, rest: String, acc: String, zero: Bool) -> Maybe<&2, String>:
  match zero:
    case False{}:
      None{}
    case True{}:
      chunk.last(rest, acc)

def chunk.end(got: Maybe<&2, HexSize>, acc: String) -> Maybe<&2, String>:
  match got:
    case None{}:
      None{}
    case Some{HexSize{+n, rest}}:
      chunk.end1(n, rest, acc, U32.is_eq(n, 0))

def chunk.mid1(+after: String, acc: String, ok: Bool) -> Maybe<&2, String>:
  match ok:
    case False{}:
      None{}
    case True{}:
      chunk.end(chunk.size(String.drop(after, 2n)), acc)

def chunk.mid(+after: String, acc: String) -> Maybe<&2, String>:
  chunk.mid1(after, acc, String.starts_with(after, "\r\n"))

def chunk.data.if(+n: U32, +rest: String, acc: String, short: Bool) -> Maybe<&2, String>:
  match short:
    case True{}:
      None{}
    case False{}:
      chunk.mid(String.drop(rest, U32.to_nat(n)), acc ++ String.take(rest, U32.to_nat(n)))

def chunk.data(+n: U32, +rest: String, acc: String) -> Maybe<&2, String>:
  chunk.data.if(n, rest, acc, Nat.is_lt(String.length(rest), U32.to_nat(n)))

def chunk.more1(n: U32, rest: String, acc: String, zero: Bool) -> Maybe<&2, String>:
  match zero:
    case True{}:
      chunk.last(rest, acc)
    case False{}:
      chunk.data(n, rest, acc)

def chunk.more(got: Maybe<&2, HexSize>, acc: String) -> Maybe<&2, String>:
  match got:
    case None{}:
      None{}
    case Some{HexSize{+n, rest}}:
      chunk.more1(n, rest, acc, U32.is_eq(n, 0))

# ponytail: one data chunk then last-chunk; multi-chunk when a loop is easy
def chunk.decode(s: String) -> Maybe<&2, String>:
  chunk.more(chunk.size(s), "")

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

def parse.res.finish(status: U32, h: Map<&2, String>, body: Maybe<&2, String>) -> Maybe<&2, Res>:
  match body:
    case None{}:
      None{}
    case Some{b}:
      Some{Res{status, h, b}}

def parse.res.fields(status: U32, rest: String, fs: Maybe<&2, Map<&2, String>>) -> Maybe<&2, Res>:
  match fs:
    case None{}:
      None{}
    case Some{+h}:
      parse.res.finish(status, h, parse.res.body(h, rest))

def parse.res.num(code: Maybe<&2, U32>, headers: List<&2, String>, rest: String) -> Maybe<&2, Res>:
  match code:
    case None{}:
      None{}
    case Some{n}:
      parse.res.fields(n, rest, parse.headers(headers, FieldsOk{empty()}))

def parse.res.ver(ver: String, code: String, headers: List<&2, String>, rest: String, ok: Bool) -> Maybe<&2, Res>:
  match ok:
    case False{}:
      None{}
    case True{}:
      parse.res.num(parse_u32(code), headers, rest)

def parse.res.start3(mpv: String & String & String, headers: List<&2, String>, rest: String) -> Maybe<&2, Res>:
  (+ver, code, reason) = mpv
  parse.res.ver(ver, code, headers, rest, String.eq(ver, "HTTP/1.1"))

def parse.res.lines(xs: List<&2, String>, rest: String) -> Maybe<&2, Res>:
  match xs:
    case Nil{}:
      None{}
    case Con{line, headers}:
      parse.res.start3(start_line(line), headers, rest)

def parse.res.head(head: String, rest: String) -> Maybe<&2, Res>:
  parse.res.lines(String.lines(head), rest)

def parse.res.of(hb: String & String) -> Maybe<&2, Res>:
  (head, rest) = hb
  parse.res.head(head, rest)

def parse_res(raw: String) -> Maybe<&2, Res>:
  parse.res.of(split_at_blank(raw))

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

def encode_req(method: String, path: String, host: String, +body: String) -> String:
  request(method, path, Map.set(&2, String, Map.set(&2, String, Map.set(&2, String, empty(), "host", host), "connection", "close"), "content-length", U32.show(nat_u32(String.length(body)))), body)

# ponytail: two recvs; loop when bodies exceed 16KiB
def fetch_tail(head: String, m: Socket & Result<&1, &1, U32 & String, String>) -> IO(Maybe<&2, Res>):
  (s, r) = m
  do IO<Maybe<&2, Res>>:
    tail : String <- IO.pass(String, r)
    Socket.close(s)
    return parse_res(head ++ tail)

def fetch_head(m: Socket & Result<&1, &1, U32 & String, String>) -> IO(Maybe<&2, Res>):
  (s, r) = m
  do IO<Maybe<&2, Res>>:
    head : String <- IO.pass(String, r)
    rest : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 8192)
    fetch_tail(head, rest)

def fetch_sent(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Maybe<&2, Res>):
  (s, r) = m
  do IO<Maybe<&2, Res>>:
    IO.pass(Unit, r)
    read : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 8192)
    fetch_head(read)

def fetch(method: String, ip: String, port: U32, host: String, path: String, body: String) -> IO(Maybe<&2, Res>):
  do IO<Maybe<&2, Res>>:
    c    : Socket <- IO.try(Socket, TCP.connect(ip, port))
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(c, encode_req(method, path, host, body))
    fetch_sent(sent)

def get_body.res(res: Res) -> String:
  Res{status, headers, body} = res
  body

def get_body(m: Maybe<&2, Res>) -> String:
  match m:
    case None{}:
      ""
    case Some{res}:
      get_body.res(res)

def get(ip: String, port: U32, host: String, path: String) -> IO(String):
  do IO<String>:
    m : Maybe<&2, Res> <- fetch("GET", ip, port, host, path, "")
    return get_body(m)

def sent_fin(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def reply_send(s: Socket, res: Res) -> IO(Unit):
  do IO<Unit>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(s, encode(res))
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
    read : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 8192)
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
