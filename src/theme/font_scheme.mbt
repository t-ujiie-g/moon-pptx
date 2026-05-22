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
pub(all) struct FontCollection {
  /// `<a:latin typeface="…"/>` — Latin script. Required.
  latin : String
  /// `<a:ea typeface="…"/>` — East Asian. May be empty.
  ea : String
  /// `<a:cs typeface="…"/>` — Complex Script. May be empty.
  cs : String
  /// `<a:font script="…" typeface="…"/>` overrides, in source order.
  scripts : Array[ScriptFont]
  /// Lossless preservation (ADR-004): per-typeface decoration children
  /// (`<a:fill>`, `<a:effectLst>`, …) and unmodelled siblings.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// The major (heading) and minor (body) font families.
pub(all) struct FontScheme {
  name : String
  major_font : FontCollection
  minor_font : FontCollection
  /// Lossless preservation (ADR-004): `<a:extLst>` etc. on `<a:fontScheme>`.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
