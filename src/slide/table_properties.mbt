// Typed `<a:tblPr>` + `<a:tcPr>` properties — Phase 6d slice.
//
// The Phase 6a/6b table parser/writer parked these elements as
// captured `@xml.XmlElement` values, which preserved them on
// round-trip but didn't let callers introspect or build them
// without dropping down to XmlElement construction. Phase 6d
// promotes the common-case fields to typed records:
//
//   - `<a:tblPr>` becomes `TableProperties` — the spec's seven
//     boolean style-hint attributes (`firstRow` / `firstCol` /
//     `lastRow` / `lastCol` / `bandRow` / `bandCol` / `rtl`), the
//     optional `<a:tableStyleId>{GUID}</a:tableStyleId>` reference,
//     and the optional fill choice.  `<a:tableStyle>` (inline
//     style — rare) and `<a:extLst>` ride on the `extension` array.
//
//   - `<a:tcPr>` becomes `TableCellProperties` — the four margins
//     (`marL` / `marR` / `marT` / `marB`), text anchor + anchor-
//     centred + vertical-text-direction attributes, the four
//     orthogonal borders (`lnL` / `lnR` / `lnT` / `lnB`), the two
//     diagonal borders (`lnTlToBr` / `lnBlToTr`), and the optional
//     fill choice.  Cell-3D + headers + extLst ride on `extension`.
//
// Both records keep an `extension : Array[XmlElement]` for ADR-004
// preservation of anything unmodelled.

///|
/// Typed body of `<a:tblPr>`.
pub(all) struct TableProperties {
  /// `firstRow` attribute — style first row differently (header).
  first_row : Bool?
  /// `firstCol` attribute.
  first_col : Bool?
  /// `lastRow` attribute.
  last_row : Bool?
  /// `lastCol` attribute.
  last_col : Bool?
  /// `bandRow` attribute — alternating row banding.
  band_row : Bool?
  /// `bandCol` attribute.
  band_col : Bool?
  /// `rtl` attribute — right-to-left text direction.
  rtl : Bool?
  /// Optional fill choice (`<a:noFill>` / `<a:solidFill>` / etc.)
  /// applied to the whole table background.
  fill : @oxml.Fill?
  /// `<a:tableStyleId>` body — a `{GUID}` referencing a style in
  /// the `tableStyles.xml` part. PowerPoint Office Theme defaults
  /// to `{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}`.
  table_style_id : String?
  /// ADR-004 preservation: `<a:tableStyle>` inline-style body
  /// (rare), `<a:extLst>`, and any future / foreign-namespace
  /// children of `<a:tblPr>`.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Construct an empty TableProperties — every field None / empty.
/// Produces an `<a:tblPr/>` on serialise.
pub fn TableProperties::default() -> TableProperties {
  {
    first_row: None,
    first_col: None,
    last_row: None,
    last_col: None,
    band_row: None,
    band_col: None,
    rtl: None,
    fill: None,
    table_style_id: None,
    extension: [],
  }
}

///|
/// Typed body of `<a:tcPr>`.
pub(all) struct TableCellProperties {
  /// `marL` attribute — left margin in EMU.
  margin_l : @units.Emu?
  /// `marR` attribute — right margin.
  margin_r : @units.Emu?
  /// `marT` attribute — top margin.
  margin_t : @units.Emu?
  /// `marB` attribute — bottom margin.
  margin_b : @units.Emu?
  /// `anchor` attribute — vertical text anchor.  Reuses the same
  /// `Anchor` enum as `BodyProperties.anchor`.
  anchor : Anchor?
  /// `anchorCtr` attribute — centred horizontally inside the cell.
  anchor_ctr : Bool?
  /// `vert` attribute — vertical text direction.  Reuses the same
  /// `VerticalText` enum as `BodyProperties.vertical_text`.
  vertical_text : VerticalText?
  /// `<a:lnL>` — left border.
  border_left : @oxml.Stroke?
  /// `<a:lnR>` — right border.
  border_right : @oxml.Stroke?
  /// `<a:lnT>` — top border.
  border_top : @oxml.Stroke?
  /// `<a:lnB>` — bottom border.
  border_bottom : @oxml.Stroke?
  /// `<a:lnTlToBr>` — top-left to bottom-right diagonal border.
  border_tl_to_br : @oxml.Stroke?
  /// `<a:lnBlToTr>` — bottom-left to top-right diagonal border.
  border_bl_to_tr : @oxml.Stroke?
  /// Cell fill (`<a:noFill>` / `<a:solidFill>` / etc.).
  fill : @oxml.Fill?
  /// ADR-004 preservation: `<a:cell3D>`, `<a:headers>`,
  /// `<a:extLst>`, foreign-namespace children of `<a:tcPr>`.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Construct an empty TableCellProperties — every field None.
/// Produces an `<a:tcPr/>` on serialise.
pub fn TableCellProperties::default() -> TableCellProperties {
  {
    margin_l: None,
    margin_r: None,
    margin_t: None,
    margin_b: None,
    anchor: None,
    anchor_ctr: None,
    vertical_text: None,
    border_left: None,
    border_right: None,
    border_top: None,
    border_bottom: None,
    border_tl_to_br: None,
    border_bl_to_tr: None,
    fill: None,
    extension: [],
  }
}

// --- fluent setters for builder use ---

///|
/// Return a new TableCellProperties with the given margins. Useful
/// in builder chains: `TableCellProperties::default().with_margins(…)`.
pub fn TableCellProperties::with_margins(
  self : TableCellProperties,
  left? : @units.Emu? = None,
  right? : @units.Emu? = None,
  top? : @units.Emu? = None,
  bottom? : @units.Emu? = None,
) -> TableCellProperties {
  { ..self, margin_l: left, margin_r: right, margin_t: top, margin_b: bottom }
}

///|
/// Return a new TableCellProperties with the given fill.
pub fn TableCellProperties::with_fill(
  self : TableCellProperties,
  fill : @oxml.Fill,
) -> TableCellProperties {
  { ..self, fill: Some(fill) }
}

///|
/// Return a new TableCellProperties with the given vertical anchor.
pub fn TableCellProperties::with_anchor(
  self : TableCellProperties,
  anchor : Anchor,
) -> TableCellProperties {
  { ..self, anchor: Some(anchor) }
}

///|
/// Return a new TableCellProperties with all four orthogonal borders
/// set to the same stroke. Use the per-side `with_border_*` helpers
/// for one-off edges.
pub fn TableCellProperties::with_border_all(
  self : TableCellProperties,
  stroke : @oxml.Stroke,
) -> TableCellProperties {
  {
    ..self,
    border_left: Some(stroke),
    border_right: Some(stroke),
    border_top: Some(stroke),
    border_bottom: Some(stroke),
  }
}

///|
pub fn TableCellProperties::with_border_left(
  self : TableCellProperties,
  stroke : @oxml.Stroke,
) -> TableCellProperties {
  { ..self, border_left: Some(stroke) }
}

///|
pub fn TableCellProperties::with_border_right(
  self : TableCellProperties,
  stroke : @oxml.Stroke,
) -> TableCellProperties {
  { ..self, border_right: Some(stroke) }
}

///|
pub fn TableCellProperties::with_border_top(
  self : TableCellProperties,
  stroke : @oxml.Stroke,
) -> TableCellProperties {
  { ..self, border_top: Some(stroke) }
}

///|
pub fn TableCellProperties::with_border_bottom(
  self : TableCellProperties,
  stroke : @oxml.Stroke,
) -> TableCellProperties {
  { ..self, border_bottom: Some(stroke) }
}
