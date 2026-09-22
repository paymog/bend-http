import Base
import ./router.bend as R

law method_miss:
  {R.route("GET", "POST", "/x", "/x") == None{} : Maybe<&2, Map<&2, String>>}

law literal_hit:
  {R.route("GET", "GET", "/x", "/x") == Some{Map.new(&2, String)} : Maybe<&2, Map<&2, String>>}

law literal_miss:
  {R.route("GET", "GET", "/x", "/y") == None{} : Maybe<&2, Map<&2, String>>}
