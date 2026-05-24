// Chart model — Phase 7a1 slice.
//
// A chart part (`/ppt/charts/chartN.xml`) is rooted at
// `<c:chartSpace>` (DrawingML chart namespace,
// `http://schemas.openxmlformats.org/drawingml/2006/chart`).
//
// `<c:chartSpace>` (ECMA-376 §21.2.2.29, `CT_ChartSpace`) contains:
//
//   <c:date1904>       (Bool — workbook epoch flag, optional)
//   <c:lang>           (String — natural language, optional)
//   <c:roundedCorners> (Bool — optional)
//   <c:style>          (UInt — preset style, optional)
//   <c:clrMapOvr>      (CT_ColorMapping — optional override)
//   <c:pivotSource>    (pivot-table source, optional)
//   <c:protection>     (optional)
//   <c:chart>          (CT_Chart — REQUIRED; the actual chart definition)
//   <c:spPr>           (shape properties — optional)
//   <c:txPr>           (text properties — optional)
//   <c:externalData>   (rId reference to embedded XLSX — optional)
//   <c:printSettings>  (optional)
//   <c:userShapes>     (rId reference — optional)
//   <c:extLst>         (extension list — optional)
//
// Phase 7a1 carries the entire `<c:chartSpace>` body as a single
// `XmlElement` via ADR-004 extension. This is enough to:
//
//   - read every existing PPTX chart part without loss
//   - round-trip the chart through `parse → serialize`
//   - dispatch the chart part from `Presentation::charts()`
//
// Phase 7a2 onward will lift the typed fields out of `space_body` one
// at a time (chart / title / plotArea / legend / chart-family bodies)
// without changing the public surface — `Chart.space_body` becomes
// "everything not yet typed", same migration pattern as `<a:custGeom>`
// in Phase 3h.

///|
/// A parsed chart part (`/ppt/charts/chartN.xml`).
///
/// Phase 7a1 keeps the entire `<c:chartSpace>` body opaque inside
/// `space_body` (an ad-hoc DOM element) so the chart part round-trips
/// losslessly even though we don't yet inspect its contents. Later
/// 7a sub-phases promote modelled fields out of `space_body` one at a
/// time.
pub(all) struct Chart {
  /// The full `<c:chartSpace>` element, including all of its children,
  /// captured verbatim per ADR-004. The wrapper itself (`name = c:chartSpace`,
  /// no attributes beyond xmlns) is canonical; only the children carry
  /// meaningful content today.
  space_body : @xml.XmlElement
} derive(Eq, Debug)

///|
pub impl Show for Chart with fn output(self, logger) {
  logger.write_string("Chart { space_body: ")
  logger.write_object(self.space_body)
  logger.write_string(" }")
}
