import Base
import ./files.bend as Fs

# Lexical POSIX paths; RFC 3986 section 5.2.4 dot-segment cases adapted
# to filesystem normalization (no trailing slash, relative paths stay relative).
law normalize_empty:
  {Fs.path.normalize("") == "." : String}

law normalize_root:
  {Fs.path.normalize("/a/../../b") == "/b" : String}

law normalize_dot:
  {Fs.path.normalize("/a/b/./c/.") == "/a/b/c" : String}

law normalize_parent:
  {Fs.path.normalize("/a/b/../c") == "/a/c" : String}

law normalize_duplicate_separators:
  {Fs.path.normalize("//a///b//") == "/a/b" : String}

law normalize_relative:
  {Fs.path.normalize("a/../../b") == "../b" : String}

law normalize_relative_parents:
  {Fs.path.normalize("../../a/../b") == "../../b" : String}

law join_absolute:
  {Fs.path.join("a/b", "/c") == "/c" : String}

law parent_file:
  {Fs.path.parent("a/b") == "a" : String}

law file_name_root:
  {Fs.path.file_name("/") == "" : String}

law extension_dotfile:
  {Fs.path.extension(".profile") == "" : String}

law extension_multi:
  {Fs.path.extension("a.tar.gz") == "gz" : String}
