import Base
import ./unicode.bend as U

law category_upper:
  {U.category('A') == "Lu" : String}

law category_digit:
  {U.category('9') == "Nd" : String}

law category_han:
  {U.category('\u{4E00}') == "Lo" : String}

law category_unassigned:
  {U.category('\u{378}') == "Cn" : String}

law category_surrogate:
  {U.category(Chr{55296}) == "Cs" : String}

law ccc_starter:
  {U.ccc('a') == 0 : U32}

law ccc_acute:
  {U.ccc('\u{301}') == 230 : U32}

# CaseFolding.txt: C folds one code point, F folds to several.
law fold_ascii:
  {U.fold("HeLLo") == "hello" : String}

law fold_sharp_s:
  {U.fold("Straße") == "strasse" : String}

law fold_dotted_i:
  {U.fold("\u{130}") == "i\u{307}" : String}

law fold_sigma:
  {U.fold("ΣΑΣ ς") == "σασ σ" : String}

law nfc_empty:
  {U.nfc("") == "" : String}

law graphemes_empty:
  {U.graphemes("") == [] : List<&2, String>}

# NormalizationTest.txt line 44.
law nfc_part0:
  {U.nfc("\u{1E0A}") == "\u{1E0A}" : String}

law nfd_part0:
  {U.nfd("\u{1E0A}") == "\u{44}\u{307}" : String}

# NormalizationTest.txt line 66.
law nfc_part0_order:
  {U.nfc("\u{592}\u{5B7}\u{5BC}\u{5A5}\u{5B0}\u{5C0}\u{5C4}\u{5AD}") == "\u{5B0}\u{5B7}\u{5BC}\u{5A5}\u{592}\u{5C0}\u{5AD}\u{5C4}" : String}

law nfd_part0_order:
  {U.nfd("\u{592}\u{5B7}\u{5BC}\u{5A5}\u{5B0}\u{5C0}\u{5C4}\u{5AD}") == "\u{5B0}\u{5B7}\u{5BC}\u{5A5}\u{592}\u{5C0}\u{5AD}\u{5C4}" : String}

# NormalizationTest.txt line 508.
law nfc_exclusion:
  {U.nfc("\u{958}") == "\u{915}\u{93C}" : String}

law nfd_exclusion:
  {U.nfd("\u{958}") == "\u{915}\u{93C}" : String}

# NormalizationTest.txt line 8636.
law nfc_hangul:
  {U.nfc("\u{C431}") == "\u{C431}" : String}

law nfd_hangul:
  {U.nfd("\u{C431}") == "\u{110A}\u{116C}\u{11AC}" : String}

# NormalizationTest.txt line 17182.
law nfc_part2_order:
  {U.nfc("\u{61}\u{315}\u{300}\u{5AE}\u{300}\u{62}") == "\u{E0}\u{5AE}\u{300}\u{315}\u{62}" : String}

law nfd_part2_order:
  {U.nfd("\u{61}\u{315}\u{300}\u{5AE}\u{300}\u{62}") == "\u{61}\u{5AE}\u{300}\u{300}\u{315}\u{62}" : String}

# NormalizationTest.txt line 19121.
law nfc_part3:
  {U.nfc("\u{9C7}\u{334}\u{9BE}") == "\u{9C7}\u{334}\u{9BE}" : String}

law nfd_part3:
  {U.nfd("\u{9C7}\u{334}\u{9BE}") == "\u{9C7}\u{334}\u{9BE}" : String}

# NormalizationTest.txt line 19318.
law nfc_part4:
  {U.nfc("\u{DC}\u{304}") == "\u{1D5}" : String}

law nfd_part4:
  {U.nfd("\u{DC}\u{304}") == "\u{55}\u{308}\u{304}" : String}

# NormalizationTest.txt line 20075.
law nfc_part5:
  {U.nfc("\u{1611E}\u{16121}\u{1611F}") == "\u{16121}\u{16123}" : String}

law nfd_part5:
  {U.nfd("\u{1611E}\u{16121}\u{1611F}") == "\u{1611E}\u{1611E}\u{1611E}\u{1611F}" : String}

# GraphemeBreakTest.txt line 29.
law graphemes_crlf:
  {U.graphemes("\u{D}\u{A}") == ["\u{D}\u{A}"] : List<&2, String>}

# GraphemeBreakTest.txt line 435.
law graphemes_hangul:
  {U.graphemes("\u{1100}\u{AC01}") == ["\u{1100}\u{AC01}"] : List<&2, String>}

# GraphemeBreakTest.txt line 756.
law graphemes_flags:
  {U.graphemes("\u{1F1E6}\u{1F1E7}\u{1F1E8}\u{62}") == ["\u{1F1E6}\u{1F1E7}", "\u{1F1E8}", "\u{62}"] : List<&2, String>}

# GraphemeBreakTest.txt line 768.
law graphemes_emoji_zwj:
  {U.graphemes("\u{1F476}\u{1F3FF}\u{308}\u{200D}\u{1F476}\u{1F3FF}") == ["\u{1F476}\u{1F3FF}\u{308}\u{200D}\u{1F476}\u{1F3FF}"] : List<&2, String>}

# GraphemeBreakTest.txt line 774.
law graphemes_conjunct:
  {U.graphemes("\u{915}\u{94D}\u{924}") == ["\u{915}\u{94D}\u{924}"] : List<&2, String>}

# GraphemeBreakTest.txt line 785.
law graphemes_conjunct_break:
  {U.graphemes("\u{1019}\u{1039}\u{1018}\u{102C}\u{1037}") == ["\u{1019}\u{1039}\u{1018}", "\u{102C}\u{1037}"] : List<&2, String>}
