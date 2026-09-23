import Base
import ./encoding.bend as Hex

law encode_empty:
  {Hex.encode("") == "" : String}

law decode_empty:
  {Hex.decode("") == Some{""} : Maybe<&2, String>}

law decode_odd:
  {Hex.decode("a") == None{} : Maybe<&2, String>}

def bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, bytes(t)}

# RFC 3629 §3: ASCII is one octet, unchanged.
law utf8_ascii:
  {Hex.utf8.encode("GET /") == "GET /" : String}

# RFC 3629 §3: one example per sequence length.
law utf8_two:
  {Hex.utf8.encode("é") == bytes([195, 169]) : String}

law utf8_three:
  {Hex.utf8.encode("€") == bytes([226, 130, 172]) : String}

law utf8_four:
  {Hex.utf8.encode("😀") == bytes([240, 159, 152, 128]) : String}

law utf8_roundtrip:
  {Hex.utf8.decode(Hex.utf8.encode("aé€😀z")) == "aé€😀z" : String}

# WHATWG: bytes that cannot start a sequence decode to U+FFFD.
law utf8_bad_lead:
  {Hex.utf8.decode(bytes([255, 65])) == "\u{FFFD}A" : String}

# WHATWG: a broken sequence yields one U+FFFD and the breaking byte is read again.
law utf8_reprocess:
  {Hex.utf8.decode(bytes([195, 65])) == "\u{FFFD}A" : String}

law utf8_truncated:
  {Hex.utf8.decode(bytes([226, 130])) == "\u{FFFD}" : String}

# RFC 3629 §3: overlong forms and surrogates are not UTF-8.
law utf8_overlong:
  {Hex.utf8.decode(bytes([192, 128])) == "\u{FFFD}\u{FFFD}" : String}

law utf8_surrogate:
  {Hex.utf8.decode(bytes([237, 160, 128])) == "\u{FFFD}\u{FFFD}\u{FFFD}" : String}
