import Base
import ./json.bend as Json

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

law trailing_junk:
  {Json.parse("null x") == None{} : Maybe<&2, Json.Val>}

law encode_null:
  {Json.encode(Json.Null{}) == "null" : String}

law roundtrip_null:
  {Json.parse(Json.encode(Json.Null{})) == Some{Json.Null{}} : Maybe<&2, Json.Val>}
