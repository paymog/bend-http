import Base
import ./url.bend as Url

law origin_only:
  {Url.parse("http://x") == None{} : Maybe<&2, Url.Url>}

law path_root:
  {Url.parse("/") == Some{Url.Url{"/", Map.new(&2, String)}} : Maybe<&2, Url.Url>}

law encode_root:
  {Url.encode(Url.Url{"/", Map.new(&2, String)}) == "/" : String}

law pct_space:
  {Url.pct.decode("%20") == Some{" "} : Maybe<&2, String>}

law pct_keep_a:
  {Url.pct.encode_path("a") == "a" : String}

# RFC 9112 §3.2.1: an empty path is sent as "/"; http's default port is 80.
law abs_basic:
  {Url.absolute("http://example.com") == Some{Url.Abs{"http", "example.com", 80, "/"}} : Maybe<&2, Url.Abs>}

# RFC 3986 §3.1, §3.2.2: scheme and host are case-insensitive; §3.5 the fragment is dropped.
law abs_full:
  {Url.absolute("HTTP://Example.COM:8080/a/b?x=1#top") == Some{Url.Abs{"http", "example.com", 8080, "/a/b?x=1"}} : Maybe<&2, Url.Abs>}

law abs_query_only:
  {Url.absolute("http://h?x=1") == Some{Url.Abs{"http", "h", 80, "/?x=1"}} : Maybe<&2, Url.Abs>}

law abs_https_default:
  {Url.absolute("https://h/") == Some{Url.Abs{"https", "h", 443, "/"}} : Maybe<&2, Url.Abs>}

# §3.2.3: an empty port is the default port.
law abs_empty_port:
  {Url.absolute("http://h:/x") == Some{Url.Abs{"http", "h", 80, "/x"}} : Maybe<&2, Url.Abs>}

law abs_userinfo_rejects:
  {Url.absolute("http://u:p@h/") == None{} : Maybe<&2, Url.Abs>}

# RFC 9110 §4.2.1: an http URI with an empty host is invalid.
law abs_empty_host_rejects:
  {Url.absolute("http:///x") == None{} : Maybe<&2, Url.Abs>}

law abs_port_range_rejects:
  {Url.absolute("http://h:65536/") == None{} : Maybe<&2, Url.Abs>}

law abs_port_digits_rejects:
  {Url.absolute("http://h:8o/") == None{} : Maybe<&2, Url.Abs>}

law abs_relative_rejects:
  {Url.absolute("example.com/x") == None{} : Maybe<&2, Url.Abs>}

law abs_unknown_scheme_rejects:
  {Url.absolute("ftp://h/") == None{} : Maybe<&2, Url.Abs>}

# RFC 9110 §7.2: Host carries the port only when it is not the default.
law host_default_port:
  {Url.host_field(Url.Abs{"http", "h", 80, "/"}) == "h" : String}

law host_other_port:
  {Url.host_field(Url.Abs{"http", "h", 8080, "/"}) == "h:8080" : String}

# RFC 3986 §5.4: examples against base http://a/b/c/d;p?q ('ab_' are §5.4.2).
law resolve_g:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g") == Some{Url.Abs{"http", "a", 80, "/b/c/g"}} : Maybe<&2, Url.Abs>}

law resolve_dot_g:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "./g") == Some{Url.Abs{"http", "a", 80, "/b/c/g"}} : Maybe<&2, Url.Abs>}

law resolve_g_slash:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g/") == Some{Url.Abs{"http", "a", 80, "/b/c/g/"}} : Maybe<&2, Url.Abs>}

law resolve_abs_path:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "/g") == Some{Url.Abs{"http", "a", 80, "/g"}} : Maybe<&2, Url.Abs>}

law resolve_net_path:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "//g") == Some{Url.Abs{"http", "g", 80, "/"}} : Maybe<&2, Url.Abs>}

law resolve_query:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "?y") == Some{Url.Abs{"http", "a", 80, "/b/c/d;p?y"}} : Maybe<&2, Url.Abs>}

law resolve_g_query:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g?y") == Some{Url.Abs{"http", "a", 80, "/b/c/g?y"}} : Maybe<&2, Url.Abs>}

law resolve_frag:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "#s") == Some{Url.Abs{"http", "a", 80, "/b/c/d;p?q"}} : Maybe<&2, Url.Abs>}

law resolve_g_frag:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g#s") == Some{Url.Abs{"http", "a", 80, "/b/c/g"}} : Maybe<&2, Url.Abs>}

law resolve_g_query_frag:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g?y#s") == Some{Url.Abs{"http", "a", 80, "/b/c/g?y"}} : Maybe<&2, Url.Abs>}

law resolve_semi:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, ";x") == Some{Url.Abs{"http", "a", 80, "/b/c/;x"}} : Maybe<&2, Url.Abs>}

law resolve_g_semi:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g;x") == Some{Url.Abs{"http", "a", 80, "/b/c/g;x"}} : Maybe<&2, Url.Abs>}

law resolve_empty:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "") == Some{Url.Abs{"http", "a", 80, "/b/c/d;p?q"}} : Maybe<&2, Url.Abs>}

law resolve_dot:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, ".") == Some{Url.Abs{"http", "a", 80, "/b/c/"}} : Maybe<&2, Url.Abs>}

law resolve_dot_slash:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "./") == Some{Url.Abs{"http", "a", 80, "/b/c/"}} : Maybe<&2, Url.Abs>}

law resolve_up:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "..") == Some{Url.Abs{"http", "a", 80, "/b/"}} : Maybe<&2, Url.Abs>}

law resolve_up_slash:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "../") == Some{Url.Abs{"http", "a", 80, "/b/"}} : Maybe<&2, Url.Abs>}

law resolve_up_g:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "../g") == Some{Url.Abs{"http", "a", 80, "/b/g"}} : Maybe<&2, Url.Abs>}

law resolve_up2:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "../..") == Some{Url.Abs{"http", "a", 80, "/"}} : Maybe<&2, Url.Abs>}

law resolve_up2_slash:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "../../") == Some{Url.Abs{"http", "a", 80, "/"}} : Maybe<&2, Url.Abs>}

law resolve_up2_g:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "../../g") == Some{Url.Abs{"http", "a", 80, "/g"}} : Maybe<&2, Url.Abs>}

law resolve_ab_up3_g:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "../../../g") == Some{Url.Abs{"http", "a", 80, "/g"}} : Maybe<&2, Url.Abs>}

law resolve_ab_up4_g:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "../../../../g") == Some{Url.Abs{"http", "a", 80, "/g"}} : Maybe<&2, Url.Abs>}

law resolve_ab_root_dot:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "/./g") == Some{Url.Abs{"http", "a", 80, "/g"}} : Maybe<&2, Url.Abs>}

law resolve_ab_root_up:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "/../g") == Some{Url.Abs{"http", "a", 80, "/g"}} : Maybe<&2, Url.Abs>}

law resolve_ab_g_dot:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g.") == Some{Url.Abs{"http", "a", 80, "/b/c/g."}} : Maybe<&2, Url.Abs>}

law resolve_ab_dot_g:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, ".g") == Some{Url.Abs{"http", "a", 80, "/b/c/.g"}} : Maybe<&2, Url.Abs>}

law resolve_ab_g_dotdot:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g..") == Some{Url.Abs{"http", "a", 80, "/b/c/g.."}} : Maybe<&2, Url.Abs>}

law resolve_ab_dotdot_g:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "..g") == Some{Url.Abs{"http", "a", 80, "/b/c/..g"}} : Maybe<&2, Url.Abs>}

law resolve_ab_dot_up_g:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "./../g") == Some{Url.Abs{"http", "a", 80, "/b/g"}} : Maybe<&2, Url.Abs>}

law resolve_ab_g_dot_end:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "./g/.") == Some{Url.Abs{"http", "a", 80, "/b/c/g/"}} : Maybe<&2, Url.Abs>}

law resolve_ab_g_dot_h:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g/./h") == Some{Url.Abs{"http", "a", 80, "/b/c/g/h"}} : Maybe<&2, Url.Abs>}

law resolve_ab_g_up_h:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g/../h") == Some{Url.Abs{"http", "a", 80, "/b/c/h"}} : Maybe<&2, Url.Abs>}

law resolve_ab_params_dot:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g;x=1/./y") == Some{Url.Abs{"http", "a", 80, "/b/c/g;x=1/y"}} : Maybe<&2, Url.Abs>}

law resolve_ab_params_up:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g;x=1/../y") == Some{Url.Abs{"http", "a", 80, "/b/c/y"}} : Maybe<&2, Url.Abs>}

law resolve_ab_query_dots:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "g?y/./x") == Some{Url.Abs{"http", "a", 80, "/b/c/g?y/./x"}} : Maybe<&2, Url.Abs>}

law resolve_absolute:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "HTTPS://x.y/z?1") == Some{Url.Abs{"https", "x.y", 443, "/z?1"}} : Maybe<&2, Url.Abs>}

# fetch can follow only http(s).
law resolve_other_scheme:
  {Url.resolve(Url.Abs{"http", "a", 80, "/b/c/d;p?q"}, "mailto:a@b") == None{} : Maybe<&2, Url.Abs>}
