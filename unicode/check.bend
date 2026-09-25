import Base
import ./unicode.bend as U

def hex(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, t}:
      U32.show(c) ++ " " ++ hex(t)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(U.category('A') ++ " " ++ U.category('9') ++ " " ++ U.category('\u{4E00}'))
    IO.print(hex(U.nfd("\u{1E0A}\u{323}")))
    IO.print(hex(U.nfc("D\u{307}\u{323}")))
    IO.print(hex(U.nfc("\u{1100}\u{1161}\u{11A8}")))
    IO.print(U.fold("Straße ΣΑΣ"))
    IO.print(String.join(U.graphemes("e\u{301}x\u{1F1FA}\u{1F1F8}\r\n"), "|"))
