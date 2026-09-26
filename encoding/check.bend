import Base
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import ./encoding.bend as Enc

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Bytes.to_hex(Enc.utf8.encode("aé€😀z")))
    IO.print(Enc.utf8.decode(Enc.utf8.encode("aé€😀z")))
    IO.print(Enc.utf8.decode(Bytes.from_string("\u{FF}A")))
