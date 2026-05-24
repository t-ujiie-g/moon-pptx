// Graphic frame + table model.
//
// `<p:graphicFrame>` (ECMA-376 §19.3.1.21, `CT_GraphicalObjectFrame`)
// is the shape wrapper used to embed any of four "foreign" content
// kinds into a slide:
//
//   - tables       (uri `…/drawingml/2006/table`)
//   - charts       (uri `…/drawingml/2006/chart`)
//   - SmartArt     (uri `…/drawingml/2006/diagram`)
//   - OLE / other  (any other uri)
//
// Tables and charts (standard `<c:chart>` + extended `<cx:chart>`)
// lift to typed `GraphicFrameContent` variants. SmartArt and any
// other unmodelled URI round-trip via the `OtherGraphic(uri, captured)`
// variant per ADR-004.
//
// Shape of the frame:
//
//   <p:graphicFrame>
//     <p:nvGraphicFramePr>       (cNvPr + cNvGraphicFramePr + nvPr)
//     <p:xfrm>                   (NOTE: presentation-ns, not drawing-ns!)
//       <a:off x="…" y="…"/>
//       <a:ext cx="…" cy="…"/>
//     </p:xfrm>
//     <a:graphic>
//       <a:graphicData uri="…">
//         <a:tbl>…</a:tbl>       (when uri = table)
//       </a:graphicData>
//     </a:graphic>
//   </p:graphicFrame>

///|
/// Wrapper element for table / chart / SmartArt content embedded in a
/// slide. `id` / `name` / `transform` are the same shape as on
/// `AutoShape` and friends; `content` discriminates the embedded
/// content kind.
pub(all) struct GraphicFrame {
  id : Int
  name : String
  /// `<p:xfrm>` placement. Optional because some inheriting cases
  /// (e.g. placeholder-bound frames) omit it on the slide and pick
  /// it up from the layout.
  transform : Transform?
  /// What kind of foreign content sits inside `<a:graphicData>`.
  content : GraphicFrameContent
  /// Lossless preservation (ADR-004): captured `<p:cNvPr>` /
  /// `<p:cNvGraphicFramePr>` / `<p:nvPr>` wrappers + any other
  /// unmodelled `<p:graphicFrame>` children. Same wrapper pattern
  /// as `AutoShape` so the writer reuses the captured wrappers.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// The body of `<a:graphicData>`. Tables get a typed AST; chart /
/// SmartArt / OLE / future content kinds keep round-tripping via the
/// captured `<a:graphicData>` payload until a typed parser arrives.
pub(all) enum GraphicFrameContent {
  /// `uri = "…/drawingml/2006/table"`. Body parsed into a `Table`.
  TableContent(Table)
  /// `uri = "…/drawingml/2006/chart"`. The body is `<c:chart r:id="…"/>`,
  /// a relationship reference to a separate chart part
  /// (`/ppt/charts/chartN.xml`). The string is the `r:id` value; the
  /// actual chart data is fetched separately (see
  /// `@presentation.Presentation::charts()`).
  ChartContent(String)
  /// `uri = "…/2014/chartex"`. The body is `<cx:chart r:id="…"/>`,
  /// a relationship reference to an extended chart part
  /// (`/ppt/charts/chartExN.xml`) — Microsoft's 2016 chart families.
  /// The actual data is fetched via
  /// `@presentation.Presentation::charts_ex()`.
  ChartExContent(String)
  /// Anything else: SmartArt, OLE, or a third-party uri we don't
  /// recognise. The string is the raw `uri` attribute; the element
  /// is the full `<a:graphicData>` child(ren) captured as one
  /// `XmlElement` so the writer can re-emit it verbatim.
  OtherGraphic(String, @xml.XmlElement)
} derive(Eq, Debug)

// --- table ---

///|
/// `<a:tbl>` — a parsed table. Source order is preserved: rows are
/// emitted in array order, and cells within a row likewise.
pub(all) struct Table {
  /// `<a:tblPr>` typed body — style-hint flags + table style ID +
  /// fill. `None` when the spec-optional element is absent.
  /// `Some(TableProperties::default())` writes an empty `<a:tblPr/>`.
  properties : TableProperties?
  /// `<a:tblGrid>` — column widths in EMU, one entry per
  /// `<a:gridCol>`. Cell positions in `Table.rows[i].cells` line
  /// up with these positions.
  grid : Array[@units.Emu]
  /// `<a:tr>` rows in source order.
  rows : Array[TableRow]
  /// Lossless preservation (ADR-004) for unmodelled `<a:tbl>`
  /// children (none today beyond what's above; reserved for
  /// forward compat).
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// `<a:tr h="…">` — one table row.
pub(all) struct TableRow {
  /// `h` attribute — row height in EMU. The spec marks `h` as
  /// required; we surface it directly rather than `Option` because
  /// any well-formed table emits it.
  height : @units.Emu
  /// `<a:tc>` cells, left-to-right.
  cells : Array[TableCell]
  /// Lossless preservation (ADR-004).
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// `<a:tc>` — one cell.
///
/// Cell merging in OOXML uses two complementary mechanisms:
/// `gridSpan` / `rowSpan` on the *origin* cell (top-left of a
/// merged region), and `hMerge="1"` / `vMerge="1"` on the *covered*
/// cells (the ones the origin spans into). Both are surfaced here
/// so callers can identify either side of the merge.
pub(all) struct TableCell {
  /// `gridSpan` — number of columns this cell spans (default `1`).
  /// Only meaningful on origin cells; covered cells leave it at 1.
  grid_span : Int
  /// `rowSpan` — number of rows this cell spans (default `1`).
  row_span : Int
  /// `hMerge` — true if this cell is part of a horizontal merge
  /// (i.e. not the origin column). Default false.
  h_merge : Bool
  /// `vMerge` — true if this cell is part of a vertical merge
  /// (i.e. not the origin row). Default false.
  v_merge : Bool
  /// `<a:txBody>` cell contents. Empty when the cell is purely
  /// decorative or part of a merge.
  text_body : TextBody?
  /// `<a:tcPr>` typed body — margins, anchor, fill, borders.
  /// `None` when the spec-optional element is absent.
  properties : TableCellProperties?
  /// Lossless preservation (ADR-004) for any other captured `<a:tc>`
  /// children — `<a:extLst>` and similar.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
