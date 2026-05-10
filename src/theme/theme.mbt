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
} derive(Eq, Debug)
