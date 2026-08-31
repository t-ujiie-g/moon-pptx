// Theme font scheme — the major and minor font families (ECMA-376 §20.1.4.1.18).
//
//   <a:fontScheme name="Office">
//     <a:majorFont>
//       <a:latin typeface="Calibri Light"/>
//       <a:ea typeface=""/>
//       <a:cs typeface=""/>
//       <a:font script="Jpan" typeface="Yu Gothic Light"/>
//       …
//     </a:majorFont>
//     <a:minorFont>…</a:minorFont>
//   </a:fontScheme>

///|
/// One typeface assignment within a `FontCollection` for a specific script.
/// `script` is a four-letter ISO 15924 code (`"Jpan"`, `"Hans"`, `"Arab"`, …).
pub(all) struct ScriptFont {
  script : String
  typeface : String
} derive(Eq, Debug)

///|
pub impl Show for ScriptFont with fn output(self, logger) {
  logger.write_string("ScriptFont(")
  logger.write_object(self.script)
  logger.write_string(" -> ")
  logger.write_object(self.typeface)
  logger.write_string(")")
}

///|
/// A theme font family — the three baseline typefaces plus optional
/// per-script overrides.
///
/// - `latin` (`<a:latin typeface="…"/>`) — Latin script. Required.
/// - `ea` (`<a:ea typeface="…"/>`) — East Asian. May be empty.
/// - `cs` (`<a:cs typeface="…"/>`) — Complex Script. May be empty.
/// - `scripts` — `<a:font script="…" typeface="…"/>` overrides, in source
///   order.
pub(all) struct FontCollection {
  latin : String
  ea : String
  cs : String
  scripts : Array[ScriptFont]
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// The major (heading) and minor (body) font families.
///
/// - `extension` — `<a:extLst>` etc. on `<a:fontScheme>`.
pub(all) struct FontScheme {
  name : String
  major_font : FontCollection
  minor_font : FontCollection
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Which of the six theme fonts a `typeface="+mj-lt"`-style reference names.
/// PowerPoint writes these instead of a literal font name whenever a run
/// follows the theme, so a parsed `RunProperties.latin` very often holds
/// `"+mn-lt"` rather than something you can render.
pub(all) enum ThemeFontRef {
  MajorLatin
  MajorEastAsian
  MajorComplexScript
  MinorLatin
  MinorEastAsian
  MinorComplexScript
} derive(Eq, Debug)

///|
/// Parse a `typeface` attribute value as a theme reference. `None` for a
/// literal font name, which is every value not starting with `+`.
pub fn ThemeFontRef::from_xml(s : String) -> ThemeFontRef? {
  match s {
    "+mj-lt" => Some(MajorLatin)
    "+mj-ea" => Some(MajorEastAsian)
    "+mj-cs" => Some(MajorComplexScript)
    "+mn-lt" => Some(MinorLatin)
    "+mn-ea" => Some(MinorEastAsian)
    "+mn-cs" => Some(MinorComplexScript)
    _ => None
  }
}

///|
pub fn ThemeFontRef::to_xml(self : ThemeFontRef) -> String {
  match self {
    MajorLatin => "+mj-lt"
    MajorEastAsian => "+mj-ea"
    MajorComplexScript => "+mj-cs"
    MinorLatin => "+mn-lt"
    MinorEastAsian => "+mn-ea"
    MinorComplexScript => "+mn-cs"
  }
}

///|
/// Scripts PowerPoint renders with the `<a:ea>` slot when the collection has
/// no matching `<a:font script="…">` entry. ISO-15924 tags, matching the set
/// Office's own themes enumerate.
let east_asian_scripts : Array[String] = [
  "Hans", "Hant", "Hani", "Jpan", "Hira", "Kana", "Hang", "Kore", "Bopo", "Yiii",
]

///|
/// Scripts that fall back to the `<a:cs>` slot on the same terms.
let complex_scripts : Array[String] = [
  "Arab", "Hebr", "Thai", "Thaa", "Deva", "Beng", "Gujr", "Guru", "Knda", "Mlym",
  "Orya", "Sinh", "Taml", "Telu", "Tibt", "Khmr", "Laoo", "Mymr", "Syrc", "Syre",
  "Syrj", "Syrn", "Nkoo", "Tfng", "Mong", "Uigh",
]

///|
/// Which of a `FontCollection`'s three typeface slots renders a given script.
/// The run-level `<a:latin>` / `<a:ea>` / `<a:cs>` overrides follow the same
/// split, so callers use this to decide which override applies.
pub(all) enum ScriptSlot {
  LatinSlot
  EastAsianSlot
  ComplexScriptSlot
} derive(Eq, Debug)

///|
/// Classify an ISO-15924 script tag. Unknown tags map to `LatinSlot`, which
/// is also where alphabetic scripts (Cyrl, Grek, …) belong.
pub fn ScriptSlot::of_script(script : String) -> ScriptSlot {
  if east_asian_scripts.contains(script) {
    EastAsianSlot
  } else if complex_scripts.contains(script) {
    ComplexScriptSlot
  } else {
    LatinSlot
  }
}

///|
/// The typeface this collection uses for an ISO-15924 script tag such as
/// `"Jpan"`, `"Hans"`, or `"Arab"`.
///
/// Follows PowerPoint's order: an explicit `<a:font script="…">` entry wins;
/// otherwise the script's slot (`ea` for East Asian, `cs` for complex, `latin`
/// for the rest); and if that slot is the empty string — which Office themes
/// routinely leave `<a:ea typeface=""/>` — `latin`, since an empty typeface
/// selects nothing.
pub fn FontCollection::typeface_for_script(
  self : FontCollection,
  script : String,
) -> String {
  for f in self.scripts {
    if f.script == script {
      return f.typeface
    }
  }
  let slot = match ScriptSlot::of_script(script) {
    EastAsianSlot => self.ea
    ComplexScriptSlot => self.cs
    LatinSlot => self.latin
  }
  if slot.is_empty() {
    self.latin
  } else {
    slot
  }
}

///|
/// Resolve a `typeface` attribute value against this scheme: a theme
/// reference (`"+mn-ea"`) becomes the font it points at, and any literal name
/// is returned unchanged.
pub fn FontScheme::resolve_typeface(
  self : FontScheme,
  typeface : String,
) -> String {
  match ThemeFontRef::from_xml(typeface) {
    None => typeface
    Some(r) =>
      match r {
        MajorLatin => self.major_font.latin
        MajorEastAsian => self.major_font.ea
        MajorComplexScript => self.major_font.cs
        MinorLatin => self.minor_font.latin
        MinorEastAsian => self.minor_font.ea
        MinorComplexScript => self.minor_font.cs
      }
  }
}
