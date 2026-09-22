import Base
import ./encoding.bend as Hex

law encode_empty:
  {Hex.encode("") == "" : String}

law decode_empty:
  {Hex.decode("") == Some{""} : Maybe<&2, String>}

law decode_odd:
  {Hex.decode("a") == None{} : Maybe<&2, String>}
