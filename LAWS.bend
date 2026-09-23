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

# RFC 9112 §6.3 (6): response Content-Length is the body.
law parse_res_body:
  {Http.res_body(Http.parse_res("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")) == "ok" : String}

# RFC 9112 §8: a body shorter than Content-Length is incomplete, not a message.
law cl_short_rejects:
  {Http.parse("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhi") == None{} : Maybe<&2, Http.Req>}

# RFC 9112 §7.1: last-chunk then an empty trailer ends the body; later bytes are not body.
law chunk_last_ends:
  for b: String
  {Http.chunk.decode("0\r\n\r\n" ++ b) == Some{""} : Maybe<&2, String>}

# RFC 9112 §7.1: chunk-data is opaque; any octet, CR and LF included, passes through.
law chunk_data_opaque:
  for c: U32
  {Http.chunk.decode("1\r\n" ++ SCon{Chr{c}, "\r\n0\r\n\r\n"}) == Some{SCon{Chr{c}, SNil{}}} : Maybe<&2, String>}

# RFC 9112 §7.1: chunk-size is 1*HEXDIG; an empty size is not a chunk.
law chunk_needs_size:
  for b: String
  {Http.chunk.decode("\r\n" ++ b) == None{} : Maybe<&2, String>}

law chunk_hello:
  {Http.chunk.decode("5\r\nhello\r\n0\r\n\r\n") == Some{"hello"} : Maybe<&2, String>}

law chunk_many:
  {Http.chunk.decode("5\r\nhello\r\n1\r\n \r\n5\r\nworld\r\n0\r\n\r\n") == Some{"hello world"} : Maybe<&2, String>}

# chunk-size is case-insensitive hex.
law chunk_hex_case:
  {Http.chunk.decode("a\r\n0123456789\r\nA\r\n0123456789\r\n0\r\n\r\n") == Some{"01234567890123456789"} : Maybe<&2, String>}

# RFC 9112 §7.1.1: unknown chunk extensions are ignored.
law chunk_ext_ignored:
  {Http.chunk.decode("5;name=\"v\"\r\nhello\r\n0;x\r\n\r\n") == Some{"hello"} : Maybe<&2, String>}

# RFC 9112 §7.1.2: trailer fields end with an empty line.
law chunk_trailer:
  {Http.chunk.decode("2\r\nok\r\n0\r\nExpires: never\r\n\r\n") == Some{"ok"} : Maybe<&2, String>}

law chunk_short_rejects:
  {Http.chunk.decode("5\r\nhi\r\n0\r\n\r\n") == None{} : Maybe<&2, String>}

law chunk_no_crlf_after_data_rejects:
  {Http.chunk.decode("2\r\nokXX0\r\n\r\n") == None{} : Maybe<&2, String>}

law chunk_unterminated_rejects:
  {Http.chunk.decode("2\r\nok\r\n0\r\n") == None{} : Maybe<&2, String>}

law chunk_bare_lf_rejects:
  {Http.chunk.decode("2\nok\r\n0\r\n\r\n") == None{} : Maybe<&2, String>}

# A size that overflows 32 bits must not wrap to a small length (smuggling).
law chunk_overflow_rejects:
  {Http.chunk.decode("100000002\r\nok\r\n0\r\n\r\n") == None{} : Maybe<&2, String>}

# RFC 9112 §6.1: chunked request without Content-Length is framed by chunks.
law parse_chunked_req:
  {Http.got_body(Http.parse("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nhi\r\n3\r\n yo\r\n0\r\n\r\n")) == "hi yo" : String}

def body_of(f: Http.Frame) -> Maybe<&2, String>:
  match f:
    case Http.FrameDone{r}:
      Some{Http.res_body(Some{r})}
    case Http.FrameBad{}:
      None{}
    case Http.FrameMore{}:
      None{}

# Header block not finished: read on while open; a cut after close is not a message.
law frame_head_more:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-", False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_head_cut_bad:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-", True{}, False{}) == Http.FrameBad{} : Http.Frame}

# RFC 9112 §6.3 (6) and §8: short Content-Length body.
law frame_cl_more:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhi", False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_cl_cut_bad:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhi", True{}, False{}) == Http.FrameBad{} : Http.Frame}

# Content-Length ends the message; no need to wait for close, extra bytes are not body.
law frame_cl_done:
  for b: String
  {body_of(Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok" ++ b, False{}, False{})) == Some{"ok"} : Maybe<&2, String>}

# RFC 9112 §6.3 (8): no framing ⇒ wait for close, then everything is body.
law frame_open_more:
  for b: String
  {Http.frame("HTTP/1.1 200 OK\r\n\r\n" ++ b, False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_open_close:
  for b: String
  {body_of(Http.frame("HTTP/1.1 200 OK\r\n\r\n" ++ b, True{}, False{})) == Some{b} : Maybe<&2, String>}

# Chunked: a partial chunk reads on; the last-chunk ends it without close.
law frame_chunked_more:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhel", False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_chunked_done:
  {body_of(Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n", False{}, False{})) == Some{"hello"} : Maybe<&2, String>}

# RFC 9112 §6.3 (1): a HEAD response has no body, whatever Content-Length says.
law frame_head_request:
  for b: String
  {body_of(Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n" ++ b, False{}, True{})) == Some{""} : Maybe<&2, String>}

# RFC 9112 §6.3 (1): 204 and 304 have no body.
law frame_204:
  {body_of(Http.frame("HTTP/1.1 204 No Content\r\n\r\n", False{}, False{})) == Some{""} : Maybe<&2, String>}

law frame_304:
  {body_of(Http.frame("HTTP/1.1 304 Not Modified\r\nContent-Length: 9\r\n\r\n", False{}, False{})) == Some{""} : Maybe<&2, String>}

law frame_bad_status:
  {Http.frame("HTTP/1.1 abc OK\r\n\r\n", False{}, False{}) == Http.FrameBad{} : Http.Frame}
