// Graphic frame + table model — Phase 6a slice.
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
// Phase 6 types the table case end-to-end. Charts / SmartArt / OLE
// keep round-tripping via raw `@xml.XmlElement` capture per ADR-004
// until their own phases land.
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
  /// Anything else: chart, SmartArt, OLE, or a third-party uri we
  /// don't recognise. The string is the raw `uri` attribute; the
  /// element is the full `<a:graphicData>` child(ren) captured as
  /// one `XmlElement` so the writer can re-emit it verbatim.
  OtherGraphic(String, @xml.XmlElement)
} derive(Eq, Debug)

// --- table ---

///|
/// `<a:tbl>` — a parsed table. Source order is preserved: rows are
/// emitted in array order, and cells within a row likewise.
pub(all) struct Table {
  /// `<a:tblPr>` body captured wholesale. The table-properties
  /// schema mixes simple booleans (`firstRow`, `firstCol`,
  /// `bandRow`, etc.) with nested elements (`<a:tableStyleId>`,
  /// `<a:tableStyle>`); typing it gradually is fine because the
  /// writer just re-emits the captured element. The `Option`
  /// distinguishes "absent" (PowerPoint sometimes omits) from
  /// "present but empty".
  properties : @xml.XmlElement?
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
  /// `<a:tcPr>` body captured wholesale. Cell margins (`marL` /
  /// `marR` / `marT` / `marB`), text anchor, fill choice, borders
  /// (`lnL` / `lnR` / `lnT` / `lnB` / `lnTlToBr` / `lnBlToTr`) all
  /// live inside it. Phase 6d lifts the common fields into typed
  /// `TableCellProperties`.
  properties : @xml.XmlElement?
  /// Lossless preservation (ADR-004) for any other captured `<a:tc>`
  /// children — `<a:extLst>` and similar.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
