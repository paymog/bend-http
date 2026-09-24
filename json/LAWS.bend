import Base
import ./json.bend as Json

def obj1(k: String, v: Json.Val) -> Json.Val:
  Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), k, v)}

# RFC 8259 §3: literal names.
law parse_null:
  {Json.parse("null") == Some{Json.Null{}} : Maybe<&2, Json.Val>}

law parse_true:
  {Json.parse("true") == Some{Json.Flag{True{}}} : Maybe<&2, Json.Val>}

law parse_false:
  {Json.parse("false") == Some{Json.Flag{False{}}} : Maybe<&2, Json.Val>}

law parse_empty_arr:
  {Json.parse("[]") == Some{Json.Arr{Nil{}}} : Maybe<&2, Json.Val>}

law parse_empty_obj:
  {Json.parse("{}") == Some{Json.Obj{Map.new(&2, Json.Val)}} : Maybe<&2, Json.Val>}

law at_index:
  {Json.at(Json.Arr{[Json.Str{"a"}, Json.Str{"b"}]}, 1n) == Some{Json.Str{"b"}} : Maybe<&2, Json.Val>}

law at_object_none:
  {Json.at(Json.Null{}, 0n) == None{} : Maybe<&2, Json.Val>}

law u32_twelve:
  {Json.u32(Json.Num{"12"}) == Some{12} : Maybe<&2, U32>}

law u32_fraction_none:
  {Json.u32(Json.Num{"1.5"}) == None{} : Maybe<&2, U32>}

law u32_overflow_none:
  {Json.u32(Json.Num{"4294967296"}) == None{} : Maybe<&2, U32>}

# §2: one value per text.
law trailing_junk:
  {Json.parse("null x") == None{} : Maybe<&2, Json.Val>}

law parse_nested:
  {Json.parse("{\"a\":[1,{\"b\":null}],\"c\":\"x\"}") == Some{Json.Obj{Map.set(&2, Json.Val, Map.set(&2, Json.Val, Map.new(&2, Json.Val), "a", Json.Arr{[Json.Num{"1"}, obj1("b", Json.Null{})]}), "c", Json.Str{"x"})}} : Maybe<&2, Json.Val>}

# §2: insignificant whitespace around structural characters.
law parse_ws:
  {Json.parse(" \t{ \"a\" :\n[ 1 , 2 ]\r\n} ") == Some{obj1("a", Json.Arr{[Json.Num{"1"}, Json.Num{"2"}]})} : Maybe<&2, Json.Val>}

law parse_deep:
  {Json.parse("[[[[[]]]]]") == Some{Json.Arr{[Json.Arr{[Json.Arr{[Json.Arr{[Json.Arr{Nil{}}]}]}]}]}} : Maybe<&2, Json.Val>}

# §4: names SHOULD be unique; like most parsers, the last one wins.
law dup_key_last:
  {Json.parse("{\"a\":1,\"a\":2}") == Some{obj1("a", Json.Num{"2"})} : Maybe<&2, Json.Val>}

# §6: number grammar; the text is kept exactly.
law num_neg_frac_exp:
  {Json.parse("-12.5e+3") == Some{Json.Num{"-12.5e+3"}} : Maybe<&2, Json.Val>}

law num_neg_zero:
  {Json.parse("-0") == Some{Json.Num{"-0"}} : Maybe<&2, Json.Val>}

law num_big_exp:
  {Json.parse("1E400") == Some{Json.Num{"1E400"}} : Maybe<&2, Json.Val>}

law num_leading_zero_rejects:
  {Json.parse("01") == None{} : Maybe<&2, Json.Val>}

law num_bare_minus_rejects:
  {Json.parse("-") == None{} : Maybe<&2, Json.Val>}

law num_dot_end_rejects:
  {Json.parse("1.") == None{} : Maybe<&2, Json.Val>}

law num_dot_start_rejects:
  {Json.parse(".5") == None{} : Maybe<&2, Json.Val>}

law num_exp_end_rejects:
  {Json.parse("1e") == None{} : Maybe<&2, Json.Val>}

law num_plus_rejects:
  {Json.parse("+1") == None{} : Maybe<&2, Json.Val>}

# §7: escapes.
law str_escapes:
  {Json.parse("\"a\\\"b\\\\c\\/d\\n\\t\"") == Some{Json.Str{"a\"b\\c/d\n\t"}} : Maybe<&2, Json.Val>}

law str_unicode_pair:
  {Json.parse("\"\\u00e9\\ud83d\\ude00\"") == Some{Json.Str{"é😀"}} : Maybe<&2, Json.Val>}

# §8.2: an unpaired surrogate becomes U+FFFD.
law str_lone_surrogate:
  {Json.parse("\"\\ud83dx\"") == Some{Json.Str{"\u{FFFD}x"}} : Maybe<&2, Json.Val>}

law str_raw_control_rejects:
  {Json.parse("\"a\nb\"") == None{} : Maybe<&2, Json.Val>}

law str_bad_escape_rejects:
  {Json.parse("\"\\x\"") == None{} : Maybe<&2, Json.Val>}

law str_unterminated_rejects:
  {Json.parse("\"abc") == None{} : Maybe<&2, Json.Val>}

# §5, §4: structure.
law arr_trailing_comma_rejects:
  {Json.parse("[1,]") == None{} : Maybe<&2, Json.Val>}

law arr_missing_comma_rejects:
  {Json.parse("[1 2]") == None{} : Maybe<&2, Json.Val>}

law obj_missing_colon_rejects:
  {Json.parse("{\"a\" 1}") == None{} : Maybe<&2, Json.Val>}

law obj_trailing_comma_rejects:
  {Json.parse("{\"a\":1,}") == None{} : Maybe<&2, Json.Val>}

law obj_number_key_rejects:
  {Json.parse("{1:2}") == None{} : Maybe<&2, Json.Val>}

law unclosed_rejects:
  {Json.parse("[{\"a\":[1]") == None{} : Maybe<&2, Json.Val>}

law empty_rejects:
  {Json.parse("  ") == None{} : Maybe<&2, Json.Val>}

# Encoding is compact with sorted keys.
law encode_canonical:
  {Json.encode(Json.Obj{Map.set(&2, Json.Val, Map.set(&2, Json.Val, Map.new(&2, Json.Val), "b", Json.Arr{[Json.Num{"1"}, Json.Num{"-2.5e3"}, Json.Flag{True{}}]}), "a", Json.Obj{Map.new(&2, Json.Val)})}) == "{\"a\":{},\"b\":[1,-2.5e3,true]}" : String}

# §7: quote, backslash and control chars are escaped.
law encode_escapes:
  {Json.encode(Json.Str{"a\"\\\n\u{1}"}) == "\"a\\\"\\\\\\n\\u0001\"" : String}

law roundtrip:
  {Json.parse(Json.encode(Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), "k\"ey", Json.Arr{[Json.Str{"é\n😀"}, Json.Null{}, Json.Num{"-0.5"}]})})) == Some{Json.Obj{Map.set(&2, Json.Val, Map.new(&2, Json.Val), "k\"ey", Json.Arr{[Json.Str{"é\n😀"}, Json.Null{}, Json.Num{"-0.5"}]})}} : Maybe<&2, Json.Val>}
