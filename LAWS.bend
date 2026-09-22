import Base
import ./http.bend as Http

# LAW: the text after a blank line is the body.
law body_after_blank:
  for b: String
  {Http.body("\r\n\r\n" ++ b) == b : String}

# LAW: the body is a suffix of the text.
law body_suffix:
  for +s: String
  exs p: String
  {p ++ Http.body(s) == s : String}

# LAW: a response is some head, then a blank line, then the page.
law page_after_blank:
  for status: U32
  for headers: Map<&2, String>
  for +page: String
  exs head: String
  {head ++ ("\r\n\r\n" ++ page) == Http.response(status, headers, page) : String}

# LAW: equal 200 empty-header responses come from equal pages.
law response_inj:
  for +a: String
  for +b: String
  for e: {Http.response(200, Http.empty(), a) == Http.response(200, Http.empty(), b) : String}
  {a == b : String}

# LAW: sanitize drops CR.
law sanitize_drop_cr:
  for s: String
  {Http.sanitize(SCon{Chr{13}, s}) == Http.sanitize(s) : String}

# LAW: sanitize drops LF.
law sanitize_drop_lf:
  for s: String
  {Http.sanitize(SCon{Chr{10}, s}) == Http.sanitize(s) : String}

# RFC 9112 §3.2: HTTP/1.1 request without Host is not a message.
law http11_needs_host:
  for b: String
  {Http.parse("GET / HTTP/1.1\r\n\r\n" ++ b) == None{} : Maybe<&2, Http.Req>}

# RFC 9112 §6.3 (7): no CL and no TE ⇒ request body length 0.
law parse_zero_body:
  for b: String
  {Http.got_body(Http.parse("GET / HTTP/1.1\r\nHost: x\r\n\r\n" ++ b)) == "" : String}

# RFC 9112 §6.1/6.3: Transfer-Encoding without a chunked decoder is rejected.
law cl_te_rejects:
  for b: String
  {Http.parse("GET / HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n" ++ b) == None{} : Maybe<&2, Http.Req>}
