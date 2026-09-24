import Base
import ./bytes.bend as Bytes

def bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, bytes(t)}

def of(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def str(b: Bytes.Bytes) -> String:
  Bytes.to_string(b)

def val(r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&2, U32>:
  (b, x) = r
  x

def num(r: Bytes.Bytes & U32) -> U32:
  (b, n) = r
  n

def left(r: Bytes.Bytes & Bytes.Bytes) -> String:
  (a, b) = r
  str(a)

def right(r: Bytes.Bytes & Bytes.Bytes) -> String:
  (a, b) = r
  str(b)

def same(r: Bytes.Bytes & Bytes.Bytes & Bool) -> Bool:
  (a, b, ok) = r
  ok

# Round trips, inside one word, across words, and at every octet boundary.
law roundtrip_empty:
  {str(of("")) == "" : String}

law roundtrip_word:
  {str(of("abcd")) == "abcd" : String}

law roundtrip_words:
  {str(of("hello, world")) == "hello, world" : String}

law roundtrip_octets:
  {str(of(bytes([0, 128, 255, 13, 10]))) == bytes([0, 128, 255, 13, 10]) : String}

# A Char above 255 keeps its low 8 bits.
law from_masks:
  {str(of(bytes([321]))) == "A" : String}

law new_zeros:
  {str(Bytes.new(5)) == bytes([0, 0, 0, 0, 0]) : String}

law length_of:
  {num(Bytes.length(of("hello"))) == 5 : U32}

law get_first:
  {val(Bytes.get(of("hello"), 0)) == Some{104} : Maybe<&2, U32>}

law get_second_word:
  {val(Bytes.get(of("hello"), 4)) == Some{111} : Maybe<&2, U32>}

# The word has room for 4 bytes, but index 2 is past len.
law get_past_len:
  {val(Bytes.get(of("hi"), 2)) == None{} : Maybe<&2, U32>}

law set_middle:
  {str(Bytes.set(of("abc"), 1, 120)) == "axc" : String}

law set_second_word:
  {str(Bytes.set(of("hello"), 4, 33)) == "hell!" : String}

law set_masks:
  {str(Bytes.set(of("abc"), 0, 376)) == "xbc" : String}

law set_past_len:
  {str(Bytes.set(of("abc"), 3, 120)) == "abc" : String}

law slice_middle:
  {right(Bytes.slice(of("hello"), 1, 3)) == "ell" : String}

law slice_keeps_source:
  {left(Bytes.slice(of("hello"), 1, 3)) == "hello" : String}

law slice_clamps_count:
  {right(Bytes.slice(of("hello"), 3, 10)) == "lo" : String}

law slice_clamps_start:
  {right(Bytes.slice(of("hello"), 9, 2)) == "" : String}

law append_two:
  {str(Bytes.append(of("ab"), of("cde"))) == "abcde" : String}

law append_empty:
  {str(Bytes.append(of(""), of("xyz"))) == "xyz" : String}

# RFC 9112 §2.1: the header section ends at the first empty line.
law find_header_end:
  {val(Bytes.find(of("GET / HTTP/1.1\r\n\r\nbody"), "\r\n\r\n")) == Some{14} : Maybe<&2, U32>}

law find_across_words:
  {val(Bytes.find(of("abc\r\n\r\nx"), "\r\n\r\n")) == Some{3} : Maybe<&2, U32>}

law find_first_of_two:
  {val(Bytes.find(of("xabab"), "ab")) == Some{1} : Maybe<&2, U32>}

law find_at_end:
  {val(Bytes.find(of("xyzab"), "ab")) == Some{3} : Maybe<&2, U32>}

law find_missing:
  {val(Bytes.find(of("hello"), "lx")) == None{} : Maybe<&2, U32>}

law find_needle_too_long:
  {val(Bytes.find(of("ab"), "abc")) == None{} : Maybe<&2, U32>}

law find_empty_needle:
  {val(Bytes.find(of("ab"), "")) == Some{0} : Maybe<&2, U32>}

law eq_same:
  {same(Bytes.eq(of("hello"), of("hello"))) == True{} : Bool}

law eq_last_byte:
  {same(Bytes.eq(of("hello"), of("hellp"))) == False{} : Bool}

law eq_length:
  {same(Bytes.eq(of("hell"), of("hello"))) == False{} : Bool}

law eq_empty:
  {same(Bytes.eq(of(""), of(""))) == True{} : Bool}

# A buffer that was written to equals a fresh one with the same bytes.
law eq_after_set:
  {same(Bytes.eq(Bytes.set(of("abc"), 1, 98), of("abc"))) == True{} : Bool}

law eq_after_append:
  {same(Bytes.eq(Bytes.append(of("ab"), of("cde")), of("abcde"))) == True{} : Bool}
