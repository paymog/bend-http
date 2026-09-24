import Base
import ./http.bend as Http
import ./url/url.bend as Url
import ./json/json.bend as Json

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
  for +status: U32
  for headers: Map<&2, List<&2, String>>
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

# A bad chunk is never a message, even while the connection is open.
law frame_chunk_bad_size:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nG\r\n", False{}, False{}) == Http.FrameBad{} : Http.Frame}

law frame_chunk_bad_data:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nokXX", False{}, False{}) == Http.FrameBad{} : Http.Frame}

law frame_chunk_bare_lf:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\n", False{}, False{}) == Http.FrameBad{} : Http.Frame}

# A size line that has not ended can still become a chunk.
law frame_chunk_size_more:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5", False{}, False{}) == Http.FrameMore{} : Http.Frame}

# RFC 9112 §6.3: both Content-Length and Transfer-Encoding is an error.
law frame_cl_and_te:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\nZ", False{}, False{}) == Http.FrameBad{} : Http.Frame}

law frame_bad_length:
  {Http.frame("HTTP/1.1 200 OK\r\nContent-Length: 5abc\r\n\r\n", False{}, False{}) == Http.FrameBad{} : Http.Frame}

# RFC 9112 §6.3: a transfer coding other than chunked is read until close.
law frame_te_gzip_more:
  {Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\nabc", False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_te_gzip_close:
  {body_of(Http.frame("HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\nabc", True{}, False{})) == Some{"abc"} : Maybe<&2, String>}

# The read loop frames a bad chunk even when the gate is shut.
law fetch_bad_chunk_now:
  {Http.fetch.try(False{}, Http.NeedChunk{}, String.reverse("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nG\r\n"), False{}, False{}) == Http.FrameBad{} : Http.Frame}

law text_utf8:
  {Http.text(Http.Res{200, Http.empty(), SCon{Chr{195}, SCon{Chr{169}, SNil{}}}}) == "é" : String}

law json_flag:
  {Http.json(Http.Res{200, Http.empty(), "true"}) == Some{Json.Flag{True{}}} : Maybe<&2, Json.Val>}


law req_keep:
  {Http.encode_req.on("GET", "/x", "h", Http.empty(), "", False{}) == "GET /x HTTP/1.1\r\nconnection: keep-alive\r\nhost: h\r\n\r\n" : String}

law again_keep:
  {Http.again(False{}, Http.empty(), Some{"x"}) == True{} : Bool}

law again_asked_close:
  {Http.again(True{}, Http.empty(), Some{"x"}) == False{} : Bool}

law again_peer_close:
  {Http.again(False{}, Http.set(Http.empty(), "connection", "Close"), Some{"x"}) == False{} : Bool}

law again_until_close:
  {Http.again(False{}, Http.empty(), None{}) == False{} : Bool}

def sample_hop() -> Http.Hop:
  Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/"}, Http.empty(), ""}

law policy_manual:
  {Http.fetch.policy(Http.ModeManual{}, 19n, sample_hop(), Done{Http.Res{301, Http.set(Http.empty(), "location", "/z"), ""}}) == Http.NDone{Done{Http.Res{301, Http.set(Http.empty(), "location", "/z"), ""}}} : Http.Next}

law policy_error:
  {Http.fetch.policy(Http.ModeError{}, 19n, sample_hop(), Done{Http.Res{301, Http.set(Http.empty(), "location", "/z"), ""}}) == Http.NDone{Fail{Http.ErrRedirect{}}} : Http.Next}

law policy_error_ok:
  {Http.fetch.policy(Http.ModeError{}, 19n, sample_hop(), Done{Http.Res{200, Http.empty(), ""}}) == Http.NDone{Done{Http.Res{200, Http.empty(), ""}}} : Http.Next}
law fetch_short_chunk_more:
  {Http.fetch.try(False{}, Http.NeedChunk{}, String.reverse("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhel"), False{}, False{}) == Http.FrameMore{} : Http.Frame}

def hints(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      "HTTP/1.1 100 Continue\r\n\r\n" ++ hints(p)

# RFC 9110 §15.2: 100 and 103 are not the final response.
law frame_100_waits:
  {Http.frame("HTTP/1.1 100 Continue\r\n\r\n", False{}, False{}) == Http.FrameMore{} : Http.Frame}

law frame_100_cut:
  {Http.frame("HTTP/1.1 100 Continue\r\n\r\n", True{}, False{}) == Http.FrameBad{} : Http.Frame}

law frame_100_then_ok:
  {body_of(Http.frame("HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok", False{}, False{})) == Some{"ok"} : Maybe<&2, String>}

law frame_103_then_ok:
  {body_of(Http.frame("HTTP/1.1 103 Early Hints\r\nLink: </a>; rel=preload\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok", False{}, False{})) == Some{"ok"} : Maybe<&2, String>}

# 101 switches the protocol; nothing follows.
law frame_101_final:
  {body_of(Http.frame("HTTP/1.1 101 Switching Protocols\r\n\r\n", False{}, False{})) == Some{""} : Maybe<&2, String>}

law frame_interim_cap:
  {Http.frame(hints(9n), False{}, False{}) == Http.FrameBad{} : Http.Frame}

law frame_interim_eight:
  {body_of(Http.frame(hints(8n) ++ "HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\nZ", False{}, False{})) == Some{"Z"} : Maybe<&2, String>}

# RFC 9110 §8.6: a bodiless GET carries no Content-Length.
law req_get:
  {Http.encode_req("GET", "/x", "h", Http.empty(), "") == "GET /x HTTP/1.1\r\nconnection: close\r\nhost: h\r\n\r\n" : String}

# Content-Length counts octets; caller CL/TE never reach the wire; field values cannot inject lines.
law req_post_guarded:
  {Http.encode_req("POST", "/", "h:8080", Http.set(Http.set(Http.set(Http.empty(), "Content-Length", "99"), "Transfer-Encoding", "chunked"), "X-A", "1\r\nEvil: 1"), SCon{Chr{195}, SCon{Chr{169}, SNil{}}}) == "POST / HTTP/1.1\r\nconnection: close\r\ncontent-length: 2\r\nhost: h:8080\r\nx-a: 1Evil: 1\r\n\r\n" ++ SCon{Chr{195}, SCon{Chr{169}, SNil{}}} : String}

# What the client sends, the server parses back to the same body.
law req_roundtrip:
  {Http.got_body(Http.parse(Http.encode_req("PUT", "/k", "h", Http.empty(), "v=1"))) == "v=1" : String}

# RFC 9110 §15.4.2 note: user agents change POST to GET on 301 and 302; body headers go with the body.
law redirect_301_post_to_get:
  {Http.redirect(301, Http.set(Http.empty(), "location", "z"), Http.Hop{"POST", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), "b"}) == Some{Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/z"}, Http.set(Http.empty(), "x-a", "1"), ""}} : Maybe<&2, Http.Hop>}

law redirect_302_get_kept:
  {Http.redirect(302, Http.set(Http.empty(), "location", "/q?1"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.empty(), "x-a", "1"), ""}) == Some{Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/q?1"}, Http.set(Http.empty(), "x-a", "1"), ""}} : Maybe<&2, Http.Hop>}

# §15.4.4: 303 means GET the new URI.
law redirect_303_put_to_get:
  {Http.redirect(303, Http.set(Http.empty(), "location", "/done"), Http.Hop{"PUT", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), "b"}) == Some{Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/done"}, Http.set(Http.empty(), "x-a", "1"), ""}} : Maybe<&2, Http.Hop>}

law redirect_303_head_kept:
  {Http.redirect(303, Http.set(Http.empty(), "location", "/done"), Http.Hop{"HEAD", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.empty(), ""}) == Some{Http.Hop{"HEAD", Url.Abs{"https", "a.com", 443, "/done"}, Http.empty(), ""}} : Maybe<&2, Http.Hop>}

# §15.4.8, §15.4.9: 307 and 308 keep the method and the body.
law redirect_307_keeps_post:
  {Http.redirect(307, Http.set(Http.empty(), "location", "/v2"), Http.Hop{"POST", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), "b"}) == Some{Http.Hop{"POST", Url.Abs{"https", "a.com", 443, "/v2"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), "b"}} : Maybe<&2, Http.Hop>}

law redirect_308_keeps_put:
  {Http.redirect(308, Http.set(Http.empty(), "location", "/v2"), Http.Hop{"PUT", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), "b"}) == Some{Http.Hop{"PUT", Url.Abs{"https", "a.com", 443, "/v2"}, Http.set(Http.set(Http.empty(), "content-type", "text/plain"), "x-a", "1"), "b"}} : Maybe<&2, Http.Hop>}

# Credentials never follow a hop to another origin.
law redirect_cross_origin_drops_creds:
  {Http.redirect(302, Http.set(Http.empty(), "location", "https://evil.com/"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.set(Http.set(Http.empty(), "authorization", "t"), "cookie", "c"), "x-a", "1"), ""}) == Some{Http.Hop{"GET", Url.Abs{"https", "evil.com", 443, "/"}, Http.set(Http.empty(), "x-a", "1"), ""}} : Maybe<&2, Http.Hop>}

law redirect_same_origin_keeps_creds:
  {Http.redirect(302, Http.set(Http.empty(), "location", "/b"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.empty(), "authorization", "t"), ""}) == Some{Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/b"}, Http.set(Http.empty(), "authorization", "t"), ""}} : Maybe<&2, Http.Hop>}

# https to http is another origin too.
law redirect_downgrade_is_cross_origin:
  {Http.redirect(302, Http.set(Http.empty(), "location", "http://a.com/x/y"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.set(Http.empty(), "authorization", "t"), ""}) == Some{Http.Hop{"GET", Url.Abs{"http", "a.com", 80, "/x/y"}, Http.empty(), ""}} : Maybe<&2, Http.Hop>}

law redirect_200_none:
  {Http.redirect(200, Http.set(Http.empty(), "location", "/z"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.empty(), ""}) == None{} : Maybe<&2, Http.Hop>}

law redirect_no_location_none:
  {Http.redirect(301, Http.empty(), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.empty(), ""}) == None{} : Maybe<&2, Http.Hop>}

law redirect_other_scheme_none:
  {Http.redirect(301, Http.set(Http.empty(), "location", "ftp://a.com/"), Http.Hop{"GET", Url.Abs{"https", "a.com", 443, "/x/y"}, Http.empty(), ""}) == None{} : Maybe<&2, Http.Hop>}

# The hint: the header block is not complete yet.
law need_head:
  {Http.need("HTTP/1.1 200 OK\r\nContent-", False{}) == Http.NeedHead{} : Http.Need}

# Content-Length: the whole message is the header block plus the body.
law need_len:
  {Http.need("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhe", False{}) == Http.NeedLen{43n} : Http.Need}

law need_chunk:
  {Http.need("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhe", False{}) == Http.NeedChunk{} : Http.Need}

law need_close:
  {Http.need("HTTP/1.1 200 OK\r\n\r\nabc", False{}) == Http.NeedClose{} : Http.Need}

# HEAD, 1xx, 204, 304: frame at once.
law need_head_request:
  {Http.need("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n", True{}) == Http.NeedNow{} : Http.Need}

law need_204:
  {Http.need("HTTP/1.1 204 No Content\r\n\r\n", False{}) == Http.NeedNow{} : Http.Need}

# Malformed framing: frame at once and let it say Bad.
law need_cl_te:
  {Http.need("HTTP/1.1 200 OK\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\n", False{}) == Http.NeedNow{} : Http.Need}

law need_bad_status:
  {Http.need("HTTP/1.1 abc\r\n\r\n", False{}) == Http.NeedNow{} : Http.Need}

law need_te_gzip:
  {Http.need("HTTP/1.1 200 OK\r\nTransfer-Encoding: gzip\r\n\r\nabc", False{}) == Http.NeedClose{} : Http.Need}

law after_cl:
  {Http.after("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nokNEXT", False{}) == Some{"NEXT"} : Maybe<&2, String>}

law after_chunk:
  {Http.after("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nok\r\n0\r\n\r\nNEXT", False{}) == Some{"NEXT"} : Maybe<&2, String>}

law after_close_none:
  {Http.after("HTTP/1.1 200 OK\r\n\r\nhello", False{}) == None{} : Maybe<&2, String>}

law after_204:
  {Http.after("HTTP/1.1 204 No Content\r\n\r\nNEXT", False{}) == Some{"NEXT"} : Maybe<&2, String>}

# The gate opens once Content-Length bytes are in, never before.
law gate_len_reached:
  {Http.fetch.gate(False{}, Http.NeedLen{43n}, 43n, "x") == True{} : Bool}

law gate_len_short:
  {Http.fetch.gate(False{}, Http.NeedLen{43n}, 42n, "x") == False{} : Bool}

# A complete chunked message ends in CRLF CRLF.
law gate_chunk_end:
  {Http.fetch.gate(False{}, Http.NeedChunk{}, 99n, "0\r\n\r\n") == True{} : Bool}

law gate_chunk_mid:
  {Http.fetch.gate(False{}, Http.NeedChunk{}, 99n, "hello") == False{} : Bool}

# A piece under 4 bytes may finish a CRLF CRLF split across reads.
law gate_chunk_tiny_piece:
  {Http.fetch.gate(False{}, Http.NeedChunk{}, 99n, "\n") == True{} : Bool}

law gate_close_waits:
  {Http.fetch.gate(False{}, Http.NeedClose{}, 99n, "x") == False{} : Bool}

# After close, frame always decides.
law gate_closed_always:
  {Http.fetch.gate(True{}, Http.NeedHead{}, 0n, "") == True{} : Bool}

# A macOS ETIMEDOUT is a timeout, not a connect error.
law err_timeout_mac:
  {Http.err.or_late(60, Http.ErrConnect{60, "x"}) == Http.ErrTimeout{} : Http.Err}

# A Linux ETIMEDOUT is a timeout, not a read error.
law err_timeout_linux:
  {Http.err.or_late(110, Http.ErrRead{110, ""}) == Http.ErrTimeout{} : Http.Err}

# A TLS failure keeps the verify text the effect already returned.
law err_tls_keeps_why:
  {Http.err.or_late(1, Http.ErrTls{1, "expired"}) == Http.ErrTls{1, "expired"} : Http.Err}

# A refused connect keeps the errno.
law err_connect_keeps_code:
  {Http.err.or_late(61, Http.ErrConnect{61, ""}) == Http.ErrConnect{61, ""} : Http.Err}

# Repeated Set-Cookie lines stay separate, in order. header() is the first, never a join.
law set_cookie_kept:
  {Http.res_fields(Http.parse_res("HTTP/1.1 200 OK\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\n\r\n"), "set-cookie") == ["a=1", "b=2"] : List<&2, String>}

law set_cookie_not_joined:
  {Http.header(Http.add(Http.add(Http.empty(), "set-cookie", "a=1"), "set-cookie", "b=2"), "set-cookie") == "a=1" : String}

# RFC 9110 §5.3: a repeated list field keeps every value.
law vary_kept:
  {Http.res_fields(Http.parse_res("HTTP/1.1 200 OK\r\nVary: accept\r\nVary: accept-encoding\r\n\r\n"), "vary") == ["accept", "accept-encoding"] : List<&2, String>}

law set_cookie_lines:
  {Http.headers_block(Http.add(Http.add(Http.empty(), "set-cookie", "a=1"), "set-cookie", "b=2")) == "\r\nset-cookie: a=1\r\nset-cookie: b=2" : String}

# serve reads on while the header block is open.
law req_head_more:
  {Http.parse.got("GET / HTTP/1.1\r\nHost: x\r\n") == Http.GotMore{} : Http.Got}

# RFC 9112 §6.3 (6): a body shorter than Content-Length is read on, not refused.
law req_cl_more:
  {Http.parse.got("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhi") == Http.GotMore{} : Http.Got}

# RFC 9112 §7.1: an open chunked body is read on.
law req_chunk_more:
  {Http.parse.got("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nhi") == Http.GotMore{} : Http.Got}

# A bad chunk size is refused at once, not waited on.
law req_chunk_bad:
  {Http.parse.got("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\nzz\r\n") == Http.GotBad{} : Http.Got}

# RFC 9112 §6.3 (4): a request coding other than chunked is refused.
law req_te_other_bad:
  {Http.parse.got("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: gzip\r\n\r\n") == Http.GotBad{} : Http.Got}

# Only HTTP/1.1 and HTTP/1.0 request lines are messages.
law req_http2_bad:
  {Http.parse.got("GET / HTTP/2.0\r\nHost: x\r\n\r\n") == Http.GotBad{} : Http.Got}

# RFC 9112 §3.2: HTTP/1.0 does not need Host.
law req_http10_no_host:
  {Http.got_body(Http.parse("POST / HTTP/1.0\r\nContent-Length: 2\r\n\r\nhi")) == "hi" : String}

# RFC 9110 §15: the reason phrase follows the status.
law reason_404:
  {Http.response(404, Http.empty(), "") == "HTTP/1.1 404 Not Found\r\n\r\n" : String}

# RFC 9112 §4: an unknown status has an empty reason.
law reason_unknown:
  {Http.response(599, Http.empty(), "") == "HTTP/1.1 599 \r\n\r\n" : String}

# RFC 9110 §8.6: 204 has no body and no Content-Length.
law encode_204_nobody:
  {Http.encode(Http.Res{204, Http.empty(), "x"}) == "HTTP/1.1 204 No Content\r\n\r\n" : String}

# RFC 9110 §9.3.2: HEAD gets the length but not the body.
law encode_head:
  {Http.encode.on(Http.Res{200, Http.empty(), "hi"}, True{}) == "HTTP/1.1 200 OK\r\ncontent-length: 2\r\n\r\n" : String}


# RFC 9112 §9.3: an HTTP/1.1 request without close keeps the connection.
law serve_keep_v11:
  {Http.serve.keep(Http.empty(), True{}, 200, Http.empty()) == True{} : Bool}

# RFC 9112 §9.3: a request that says close ends the connection.
law serve_keep_close:
  {Http.serve.keep(Http.set(Http.empty(), "connection", "close"), True{}, 200, Http.empty()) == False{} : Bool}

# HTTP/1.0 may close after each response.
law serve_keep_http10:
  {Http.serve.keep(Http.empty(), False{}, 200, Http.empty()) == False{} : Bool}

# Request Content-Length determines the full message size before its body arrives.
law req_need_content_length:
  {Http.req.need("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 2\r\n\r\n") == Http.NeedLen{49n} : Http.Need}

# A complete Content-Length request leaves the next request untouched.
law req_after_content_length:
  {Http.req.after("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 2\r\n\r\nhiGET / HTTP/1.1\r\nHost: x\r\n\r\n") == Some{"GET / HTTP/1.1\r\nHost: x\r\n\r\n"} : Maybe<&2, String>}

# A complete chunked request leaves the next request untouched.
law req_after_chunked:
  {Http.req.after("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nhi\r\n0\r\n\r\nGET / HTTP/1.1\r\nHost: x\r\n\r\n") == Some{"GET / HTTP/1.1\r\nHost: x\r\n\r\n"} : Maybe<&2, String>}

# A complete request is never skipped by the framing hint.
law req_hint_complete:
  {Http.serve.try(True{}, Http.req.need("GET / HTTP/1.1\r\nHost: x\r\n\r\n"), String.reverse("GET / HTTP/1.1\r\nHost: x\r\n\r\n"), False{}) == Http.parse.got("GET / HTTP/1.1\r\nHost: x\r\n\r\n") : Http.Got}

# A chunked body fed in two pieces decodes as if it came at once.
law chunk_feed_split:
  {Http.chunk.hold(Http.serve.dc.more("lo\r\n0\r\n\r\n", Http.dc.feed("5\r\nhel", Http.dc.start(), ""))) == Http.HoldBody{"hello"} : Http.Hold}

# A split inside the size line or the final CRLF CRLF still decodes.
law chunk_feed_split_size:
  {Http.chunk.hold(Http.serve.dc.more("\r\nabc\r\n0\r\n\r", Http.dc.feed("3", Http.dc.start(), ""))) == Http.HoldMore{} : Http.Hold}

# Bytes after the last chunk and trailer belong to the next request.
law chunk_suffix_pipelined:
  {Http.chunk.suffix("1\r\na\r\n0\r\nT: 1\r\n\r\nGET") == Some{"GET"} : Maybe<&2, String>}

# Idle sockets are keyed by origin: scheme, host, and port.
law pool_key_origin:
  {Http.pool.key("https", "example.com", 443) == "https://example.com:443" : String}

# RFC 9112 §9.3.1: an idempotent request on a reused socket that got no response byte is retried.
law pool_retry_get_stale:
  {Http.pool.retry(True{}, Http.pool.idempotent("GET")) == True{} : Bool}

# RFC 9110 §9.2.2: POST is not idempotent, so it is never retried.
law pool_no_retry_post:
  {Http.pool.retry(True{}, Http.pool.idempotent("POST")) == False{} : Bool}

# A response that had started is never retried.
law pool_no_retry_partial:
  {Http.pool.retry(False{}, Http.pool.idempotent("GET")) == False{} : Bool}

def gzbytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, gzbytes(t)}

# RFC 9110 §8.4.1.3: a gzip body is decoded; the headers stay as sent.
law decoded_gzip:
  {Http.res_body(Http.decoded.some(Http.Res{200, Http.set(Http.empty(), "content-encoding", "gzip"), gzbytes([31, 139, 8, 0, 0, 0, 0, 0, 2, 255, 203, 72, 205, 201, 201, 87, 72, 175, 202, 44, 80, 40, 207, 47, 202, 73, 1, 0, 107, 125, 232, 183, 16, 0, 0, 0])})) == "hello gzip world" : String}

# RFC 9110 §8.4: codings are listed in the order applied, so they are undone in reverse.
law decoded_order:
  {Http.res_body(Http.decoded.some(Http.Res{200, Http.set(Http.empty(), "content-encoding", "deflate, gzip"), gzbytes([31, 139, 8, 0, 0, 0, 0, 0, 2, 255, 171, 152, 163, 173, 121, 62, 252, 132, 231, 26, 31, 93, 45, 54, 6, 209, 15, 44, 220, 0, 65, 130, 38, 92, 18, 0, 0, 0])})) == "two layers" : String}

# A coding we cannot decode leaves the body as sent.
law decoded_unknown:
  {Http.res_body(Http.decoded.some(Http.Res{200, Http.set(Http.empty(), "content-encoding", "br"), "xyz"})) == "xyz" : String}

# A corrupt gzip body is a malformed response.
law decoded_corrupt:
  {Http.decoded(Http.Res{200, Http.set(Http.empty(), "content-encoding", "gzip"), "not gzip"}) == Fail{Http.ErrBad{}} : Result<&2, &2, Http.Err, Http.Res>}

# An empty body (HEAD, 204, 304) is never decoded.
law decoded_empty:
  {Http.res_body(Http.decoded.some(Http.Res{200, Http.set(Http.empty(), "content-encoding", "gzip"), ""})) == "" : String}

# fetch asks for gzip and deflate unless the caller says otherwise.
law accept_enc_default:
  {Http.header(Http.accept.enc(Http.empty()), "accept-encoding") == "gzip, deflate" : String}

# A caller's own Accept-Encoding wins.
law accept_enc_caller:
  {Http.header(Http.accept.enc(Http.set(Http.empty(), "accept-encoding", "identity")), "accept-encoding") == "identity" : String}
