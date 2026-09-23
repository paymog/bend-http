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
