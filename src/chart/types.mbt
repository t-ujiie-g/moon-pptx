// Chart model — Phase 7a1 + 7a2 slices.
//
// A chart part (`/ppt/charts/chartN.xml`) is rooted at
// `<c:chartSpace>` (DrawingML chart namespace,
// `http://schemas.openxmlformats.org/drawingml/2006/chart`).
//
// `<c:chartSpace>` (ECMA-376 §21.2.2.29, `CT_ChartSpace`) wraps:
//
//   <c:date1904>       (Bool — workbook epoch flag, optional)
//   <c:lang>           (String — natural language, optional)
//   <c:roundedCorners> (Bool — optional)
//   <c:style>          (UInt — preset style, optional)
//   <c:clrMapOvr>      (optional)
//   <c:pivotSource>    (optional)
//   <c:protection>     (optional)
//   <c:chart>          (CT_Chart — REQUIRED; the actual chart definition)
//   <c:spPr>           (shape properties — optional)
//   <c:txPr>           (text properties — optional)
//   <c:externalData>   (rId reference to embedded XLSX — optional)
//   <c:printSettings>  (optional)
//   <c:userShapes>     (rId reference — optional)
//   <c:extLst>         (extension list — optional)
//
// Phase 7a1 captured the entire body wholesale. Phase 7a2 lifts the
// chartSpace-level scalar fields (`date1904` / `lang` /
// `roundedCorners` / `style`) and the `<c:chart>` body's scalar
// + enum header fields. The remaining children (`title` / `plotArea`
// / `legend` / 3-D wrappers / clrMapOvr / pivotSource / protection /
// spPr / txPr / externalData / printSettings / userShapes / extLst /
// foreign-namespace) all ride on the appropriate `extension` array
// per ADR-004 until later 7a slices type them.

///|
/// A parsed chart part (`/ppt/charts/chartN.xml`).
pub(all) struct Chart {
  /// `<c:date1904>` — workbook epoch flag. `None` when absent.
  date1904 : Bool?
  /// `<c:lang>` — natural language identifier (e.g. `en-US`).
  /// `None` when absent.
  lang : String?
  /// `<c:roundedCorners>` — `None` when absent.
  rounded_corners : Bool?
  /// `<c:style>` — preset style index (1..48 in practice). `None`
  /// when absent.
  style : Int?
  /// `<c:chart>` — REQUIRED chart definition body.
  chart : ChartBody
  /// chartSpace-level unmodelled children: clrMapOvr / pivotSource /
  /// protection / spPr / txPr / externalData / printSettings /
  /// userShapes / extLst plus any foreign-namespace siblings. ADR-004.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for Chart with fn output(self, logger) {
  // `assert_eq` requires Show; derive(Debug) gives us the diagnostic
  // payload. Keep this stub minimal to avoid invoking Show on
  // container fields (Option / Array) — current `core` deprecates
  // that path in favour of Debug.
  logger.write_string("Chart { … }")
  ignore(self)
}

///|
fn[T] ignore(_x : T) -> Unit {

}

///|
/// `<c:chart>` body (ECMA-376 §21.2.2.6, `CT_Chart`). Most of the
/// children are themselves substantial subtrees (title, plot area,
/// legend, 3-D wrappers) and are kept as captured `XmlElement?` here
/// until 7a3 (plot area) and later slices type them. The scalar /
/// enum-valued leaves (`autoTitleDeleted`, `plotVisOnly`,
/// `dispBlanksAs`, `showDLblsOverMax`) are lifted in Phase 7a2.
pub(all) struct ChartBody {
  /// `<c:title>` (CT_Title). Optional. Captured verbatim until typed.
  title : @xml.XmlElement?
  /// `<c:autoTitleDeleted val="…"/>`. Optional Bool.
  auto_title_deleted : Bool?
  /// `<c:pivotFmts>` (CT_PivotFmts). Optional. Captured verbatim.
  pivot_fmts : @xml.XmlElement?
  /// `<c:view3D>` (CT_View3D). Optional. Captured verbatim — only
  /// emitted by 3-D chart variants.
  view3d : @xml.XmlElement?
  /// `<c:floor>` (CT_Surface). Optional. Captured verbatim (3-D).
  floor : @xml.XmlElement?
  /// `<c:sideWall>` (CT_Surface). Optional. Captured verbatim (3-D).
  side_wall : @xml.XmlElement?
  /// `<c:backWall>` (CT_Surface). Optional. Captured verbatim (3-D).
  back_wall : @xml.XmlElement?
  /// `<c:plotArea>` (CT_PlotArea). REQUIRED. Captured verbatim until
  /// Phase 7a3 lifts it.
  plot_area : @xml.XmlElement
  /// `<c:legend>` (CT_Legend). Optional. Captured verbatim until typed.
  legend : @xml.XmlElement?
  /// `<c:plotVisOnly val="…"/>` — show only data on visible cells.
  plot_vis_only : Bool?
  /// `<c:dispBlanksAs val="…"/>` — how to render gaps. Three-value
  /// enum: `span` / `gap` / `zero`.
  disp_blanks_as : DisplayBlanksAs?
  /// `<c:showDLblsOverMax val="…"/>` — show data labels past chart
  /// scale max.
  show_d_lbls_over_max : Bool?
  /// `<c:chart>`-level unmodelled children (`<c:extLst>`,
  /// foreign-namespace).
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ChartBody with fn output(self, logger) {
  logger.write_string("ChartBody { … }")
  ignore(self)
}

///|
/// `<c:dispBlanksAs val="…"/>` (CT_DispBlanksAs). How blank cells in
/// the source range render on the chart.
pub(all) enum DisplayBlanksAs {
  /// `val="span"` — interpolate across the gap.
  Span
  /// `val="gap"` — leave the gap visible (default).
  Gap
  /// `val="zero"` — treat blank as zero.
  Zero
} derive(Eq, Debug)

///|
pub impl Show for DisplayBlanksAs with fn output(self, logger) {
  match self {
    Span => logger.write_string("Span")
    Gap => logger.write_string("Gap")
    Zero => logger.write_string("Zero")
  }
}

///|
/// Parse `<c:dispBlanksAs val>` token into the enum. Returns `None`
/// for an unknown token so the caller can decide whether to ignore
/// or raise. (Phase 7a2: ignored — schema requires the value but
/// we'd rather round-trip the rest of the chart than reject on a
/// schema violation in one leaf.)
pub fn DisplayBlanksAs::from_xml(s : String) -> DisplayBlanksAs? {
  match s {
    "span" => Some(Span)
    "gap" => Some(Gap)
    "zero" => Some(Zero)
    _ => None
  }
}

///|
/// Inverse of `from_xml`.
pub fn DisplayBlanksAs::to_xml(self : DisplayBlanksAs) -> String {
  match self {
    Span => "span"
    Gap => "gap"
    Zero => "zero"
  }
}
