import Base
import ./url.bend as Url

law origin_only:
  {Url.parse("http://x") == None{} : Maybe<&2, Url.Url>}

law path_root:
  {Url.parse("/") == Some{Url.Url{"/", Map.new(&2, String)}} : Maybe<&2, Url.Url>}

law encode_root:
  {Url.encode(Url.Url{"/", Map.new(&2, String)}) == "/" : String}
