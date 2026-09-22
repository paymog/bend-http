import Base
import ./http.bend as Http

# LAW: the text after a blank line is the body.
law body_after_blank:
  for b: String
  {Http.body("\r\n\r\n" ++ b) == b : String}

# LAW: the body is a suffix of the text.
law body_suffix:
  for +s: String
  exs p: String
  {p ++ Http.body(s) == s : String}

# LAW: a response is some head, then a blank line, then the page.
law page_after_blank:
  for status: U32
  for +page: String
  exs head: String
  {head ++ ("\r\n\r\n" ++ page) == Http.response(status, page) : String}

# LAW: equal 200 responses come from equal pages.
law response_inj:
  for +a: String
  for +b: String
  for e: {Http.response(200, a) == Http.response(200, b) : String}
  {a == b : String}
