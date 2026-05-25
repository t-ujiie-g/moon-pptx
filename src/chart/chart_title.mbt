// Typed chart-title body (CT_Title).
//
// `<c:title>` appears in two places in the chart schema:
//
//   - Chart-level: `<c:chart>` ▸ `<c:title>` — the overall chart
//     title.
//   - Axis-level: `<c:catAx>` / `<c:valAx>` / `<c:dateAx>` /
//     `<c:serAx>` ▸ `<c:title>` — the axis title.
//
// Both points carry the same `CT_Title` schema (ECMA-376 §21.2.2.210):
//
//   <c:tx>?      (CT_Tx — rich text body or string reference)
//   <c:layout>?  (CT_Layout)
//   <c:overlay>? (CT_Boolean)
//   <c:spPr>?    (CT_ShapeProperties)
//   <c:txPr>?    (CT_TextBody)
//   <c:extLst>?
//
// Only the `<c:overlay>` Bool leaf is typed; the substantial subtrees
// (rich text body in `<c:tx>`, the layout positioning, and the shape
// / text properties) stay as captured `XmlElement` until later slices
// type them. Foreign-namespace siblings and `<c:extLst>` ride on
// `extension` per ADR-004.

///|
/// Body of a `<c:title>` element. Used by both `ChartBody.title`
/// (chart-level title) and `AxisCore.title` (per-axis title).
pub(all) struct ChartTitle {
  /// `<c:tx>` (CT_Tx) — title text. Either a `<c:rich>` rich-text
  /// body or a `<c:strRef>` reference to a cell. Captured verbatim
  /// until typed.
  tx : @xml.XmlElement?
  /// `<c:layout>` (CT_Layout) — positioning. Captured.
  layout : @xml.XmlElement?
  /// `<c:overlay val="…"/>` — when `true`, the title overlays the
  /// plot area instead of reserving space outside it.
  overlay : Bool?
  /// `<c:spPr>` (CT_ShapeProperties) — title-box fill / stroke /
  /// effect. Captured.
  sp_pr : @xml.XmlElement?
  /// `<c:txPr>` (CT_TextBody) — default text run styling for the
  /// title. Captured.
  tx_pr : @xml.XmlElement?
  /// `<c:extLst>` and foreign-namespace siblings. ADR-004.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for ChartTitle with fn output(self, logger) {
  logger.write_string("ChartTitle { … }")
  let _ = self
}

// --- parsing -----------------------------------------------------------------

///|
/// Walk a captured `<c:title>` element into a typed `ChartTitle`.
/// Used by both the chart-level title parser (`parse_chart_body` in
/// parser.mbt) and the axis-level title parser (`parse_axis_core`).
pub fn parse_chart_title(el : @xml.XmlElement) -> ChartTitle {
  let mut tx : @xml.XmlElement? = None
  let mut layout : @xml.XmlElement? = None
  let mut overlay : Bool? = None
  let mut sp_pr : @xml.XmlElement? = None
  let mut tx_pr : @xml.XmlElement? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "tx" => tx = Some(c)
            "layout" => layout = Some(c)
            "overlay" => overlay = val_bool(c)
            "spPr" => sp_pr = Some(c)
            "txPr" => tx_pr = Some(c)
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { tx, layout, overlay, sp_pr, tx_pr, extension }
}

// --- writing -----------------------------------------------------------------

///|
/// Emit a `<c:title>` element. Child order follows the ECMA-376
/// schema: tx → layout → overlay → spPr → txPr → extension.
pub fn write_chart_title(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  t : ChartTitle,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "title"))
  match t.tx {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match t.layout {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match t.overlay {
    Some(b) => emit_val_bool(w, "overlay", b)
    None => ()
  }
  match t.sp_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match t.tx_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for ext in t.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}
