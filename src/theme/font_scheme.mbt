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
