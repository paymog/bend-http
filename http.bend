import Base

# HTTP/1.1 over TCP. No TLS, no DNS, no chunked.
#   import ./http.bend as Http
#   Http.serve(~handler, 8080)
#   Http.get("127.0.0.1", 8080, "localhost", "/")

type Req is Data:
  Req{method: String, path: String, headers: Map<&2, String>, body: String}

type Res is Data:
  Res{status: U32, headers: Map<&2, String>, body: String}

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

def req_line.path(m: String, t: List<&2, String>) -> String & String:
  match t:
    case Nil{}:
      (m, "")
    case Con{p, u}:
      (m, p)

def req_line.list(xs: List<&2, String>) -> String & String:
  match xs:
    case Nil{}:
      ("", "")
    case Con{m, t}:
      req_line.path(m, t)

def req_line(s: String) -> String & String:
  req_line.list(String.split(s, ' '))

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

def header_put.kv(m: Map<&2, String>, kv: String & String) -> Map<&2, String>:
  (k, v) = kv
  Map.set(&2, String, m, String.to_lower(k), String.trim(v))

def header_put.if(m: Map<&2, String>, line: String, empty: Bool) -> Map<&2, String>:
  match empty:
    case True{}:
      m
    case False{}:
      header_put.kv(m, split_colon(line))

def header_put(m: Map<&2, String>, +line: String) -> Map<&2, String>:
  header_put.if(m, line, String.is_empty(line))

def parse.headers(xs: List<&2, String>, m: Map<&2, String>) -> Map<&2, String>:
  match xs:
    case Nil{}:
      m
    case Con{line, rest}:
      parse.headers(rest, header_put(m, drop_cr(line)))

def clash.and(cl: Bool, r: Map<&2, String> & Bool) -> Bool:
  (h, te) = r
  Bool.and(cl, te)

def clash.te(r: Map<&2, String> & Bool) -> Bool:
  (h, cl) = r
  clash.and(cl, Map.has(&2, String, h, "transfer-encoding"))

def clash(+h: Map<&2, String>) -> Bool:
  clash.te(Map.has(&2, String, h, "content-length"))

def parse.clash(method: String, path: String, h: Map<&2, String>, b: String, bad: Bool) -> Maybe<&2, Req>:
  match bad:
    case True{}:
      None{}
    case False{}:
      Some{Req{method, path, h, b}}

def parse.done(method: String, path: String, +h: Map<&2, String>, b: String) -> Maybe<&2, Req>:
  parse.clash(method, path, h, b, clash(h))

def parse.rest(mp: String & String, rest: List<&2, String>, b: String) -> Maybe<&2, Req>:
  (method, path) = mp
  parse.done(method, path, parse.headers(rest, empty()), b)

def parse.lines(xs: List<&2, String>, b: String) -> Maybe<&2, Req>:
  match xs:
    case Nil{}:
      None{}
    case Con{line, rest}:
      parse.rest(req_line(drop_cr(line)), rest, b)

def parse.head(head: String, b: String) -> Maybe<&2, Req>:
  parse.lines(String.lines(head), b)

def parse.of(hb: String & String) -> Maybe<&2, Req>:
  (head, b) = hb
  parse.head(head, b)

def parse(raw: String) -> Maybe<&2, Req>:
  parse.of(split_at_blank(raw))

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

def encode(r: Res) -> String:
  Res{status, headers, body} = r
  response(status, headers, body)

def get_req(host: String, path: String) -> String:
  "GET " ++ path ++ " HTTP/1.1\r\nHost: " ++ host ++ "\r\nConnection: close\r\n\r\n"

def get_tail(head: String, m: Socket & Result<&1, &1, U32 & String, String>) -> IO(String):
  (s, r) = m
  do IO<String>:
    tail : String <- IO.pass(String, r)
    Socket.close(s)
    return body(head ++ tail)

def get_head(m: Socket & Result<&1, &1, U32 & String, String>) -> IO(String):
  (s, r) = m
  do IO<String>:
    head : String <- IO.pass(String, r)
    rest : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 8192)
    get_tail(head, rest)

def get_sent(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(String):
  (s, r) = m
  do IO<String>:
    IO.pass(Unit, r)
    read : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 8192)
    get_head(read)

def get(ip: String, port: U32, host: String, path: String) -> IO(String):
  do IO<String>:
    c    : Socket <- IO.try(Socket, TCP.connect(ip, port))
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(c, get_req(host, path))
    get_sent(sent)

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
