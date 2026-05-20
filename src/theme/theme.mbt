// Top-level Theme model.
//
// A theme part (`/ppt/theme/theme1.xml`, content type
// `application/vnd.openxmlformats-officedocument.theme+xml`) carries:
//   * `themeElements` containing `clrScheme`, `fontScheme`, `fmtScheme`
//   * optional `objectDefaults`, `extraClrSchemeLst`, `custClrLst`, `extLst`
//
// Phase 3a models `clrScheme` and `fontScheme`; everything else is parsed
// as opaque XML and preserved for round-trip (ADR-004 implementation will
// firm up the preservation API in a later phase).

///|
/// Parsed `<a:theme>` document. The `name` attribute mirrors the OOXML
/// `name` on the root element.
pub(all) struct Theme {
  name : String
  color_scheme : ColorScheme
  font_scheme : FontScheme
  /// Lossless preservation (ADR-004): captures any unmodelled child of
  /// `<a:theme>` (`<a:extraClrSchemeLst>`, `<a:custClrLst>`, `<a:extLst>`,
  /// foreign-namespace extensions) **and** any unmodelled child of the
  /// nested `<a:themeElements>` (`<a:fmtScheme>`, `<a:objectDefaults>`).
  /// The original parent is recoverable from the element's `name.uri` /
  /// `name.local_name` when Phase 4 writers re-emit.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
