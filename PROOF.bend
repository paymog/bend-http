import Base
import ./http.bend as Http
import ./LAWS.bend as Laws

def Laws.body_after_blank(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def suffix_step(
  a: U32, -t: String, -e: Bool, -w: U32, -acc: String,
  ih: (&p: String -> {p ++ Http.body.of(Http.split_at_blank.go(t, e, w, acc)) == t : String})
) -> (&p: String -> {p ++ Http.body.of(Http.split_at_blank.go(t, e, w, acc)) == SCon{Chr{a}, t} : String}):
  (p, pf) = ih
  (SCon{Chr{a}, p}, Equal.cong(String, String, x => SCon{Chr{a}, x}, p ++ Http.body.of(Http.split_at_blank.go(t, e, w, acc)), t, pf))

def suffix_go(s: String, e: Bool, w: U32, acc: String) ->
  (&p: String -> {p ++ Http.body.of(Http.split_at_blank.go(s, e, w, acc)) == s : String}):
  match s:
    case SNil{}:
      ("", {==})
    case SCon{Chr{+a}, +t}:
      match e:
        case True{}:
          ("", {==})
        case False{}:
          +w2 = (w * 256 + a : U32)
          suffix_step(a, t, U32.is_eq(w2, 218762506), w2, SCon{Chr{a}, acc}, suffix_go(t, U32.is_eq(w2, 218762506), w2, SCon{Chr{a}, acc}))

def Laws.body_suffix(s):
  suffix_go(s, False{}, 0, SNil{})

def Laws.page_after_blank(status, headers, page):
  ("HTTP/1.1 " ++ U32.show(status) ++ " OK" ++ Http.headers_block(headers), {==})

def drop(n: Nat, s: String) -> String:
  match n:
    case 0n:
      s
    case 1n+p:
      match s:
        case SNil{}:
          SNil{}
        case SCon{h, t}:
          drop(p, t)

def Laws.response_inj(a, b, e):
  Equal.cong(String, String, s => drop(19n, s), Http.response(200, Http.empty(), a), Http.response(200, Http.empty(), b), e)

def Laws.sanitize_drop_cr(s):
  {==}

def Laws.sanitize_drop_lf(s):
  {==}

def Laws.http11_needs_host(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.parse_zero_body(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.cl_te_rejects(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.parse_res_body():
  {==}

def Laws.cl_short_rejects():
  {==}

def Laws.chunk_last_ends(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.chunk_data_opaque(c):
  {==}

def Laws.chunk_needs_size(b):
  {==}

def Laws.chunk_hello():
  {==}

def Laws.chunk_many():
  {==}

def Laws.chunk_hex_case():
  {==}

def Laws.chunk_ext_ignored():
  {==}

def Laws.chunk_trailer():
  {==}

def Laws.chunk_short_rejects():
  {==}

def Laws.chunk_no_crlf_after_data_rejects():
  {==}

def Laws.chunk_unterminated_rejects():
  {==}

def Laws.chunk_bare_lf_rejects():
  {==}

def Laws.chunk_overflow_rejects():
  {==}

def Laws.parse_chunked_req():
  {==}

def Laws.frame_head_more():
  {==}

def Laws.frame_head_cut_bad():
  {==}

def Laws.frame_cl_more():
  {==}

def Laws.frame_cl_cut_bad():
  {==}

def Laws.frame_cl_done(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.frame_open_more(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.frame_open_close(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.frame_chunked_more():
  {==}

def Laws.frame_chunked_done():
  {==}

def Laws.frame_head_request(b):
  match b:
    case SNil{}:
      {==}
    case SCon{Chr{a}, t}:
      {==}

def Laws.frame_204():
  {==}

def Laws.frame_304():
  {==}

def Laws.frame_bad_status():
  {==}

def Laws.req_get():
  {==}

def Laws.req_post_guarded():
  {==}

def Laws.req_roundtrip():
  {==}

def Laws.redirect_301_post_to_get():
  {==}

def Laws.redirect_302_get_kept():
  {==}

def Laws.redirect_303_put_to_get():
  {==}

def Laws.redirect_303_head_kept():
  {==}

def Laws.redirect_307_keeps_post():
  {==}

def Laws.redirect_308_keeps_put():
  {==}

def Laws.redirect_cross_origin_drops_creds():
  {==}

def Laws.redirect_same_origin_keeps_creds():
  {==}

def Laws.redirect_downgrade_is_cross_origin():
  {==}

def Laws.redirect_200_none():
  {==}

def Laws.redirect_no_location_none():
  {==}

def Laws.redirect_other_scheme_none():
  {==}

def Laws.need_head():
  {==}

def Laws.need_len():
  {==}

def Laws.need_chunk():
  {==}

def Laws.need_close():
  {==}

def Laws.need_head_request():
  {==}

def Laws.need_204():
  {==}

def Laws.need_cl_te():
  {==}

def Laws.need_bad_status():
  {==}

def Laws.gate_len_reached():
  {==}

def Laws.gate_len_short():
  {==}

def Laws.gate_chunk_end():
  {==}

def Laws.gate_chunk_mid():
  {==}

def Laws.gate_chunk_tiny_piece():
  {==}

def Laws.gate_close_waits():
  {==}

def Laws.gate_closed_always():
  {==}
