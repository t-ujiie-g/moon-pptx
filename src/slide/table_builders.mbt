// Table builders — Phase 6c slice.
//
// Hand-friendly constructors for table cells / rows / tables and
// the surrounding `GraphicFrame` wrapper. Same pattern as the
// `AutoShape::rect / ellipse / textbox` builders in `builders.mbt`:
// produce values whose serialisation re-parses to an equal value
// from the second cycle onward (the first cycle adds the
// captured-wrapper trinkets `<p:cNvPr>` etc., per the Phase 4e
// design note in `slide/writer_test.mbt`).
//
// Cell-merge guide for hand-built tables:
//
//   - `TableCell::of_text` / `empty` — ordinary cell, no merging.
//   - `TableCell::merged_origin(text, grid_span=, row_span=)` —
//     top-left corner of a merged region. Covers `grid_span`
//     columns and `row_span` rows.
//   - `TableCell::h_merge_covered` — cell in the same row as a
//     `merged_origin` whose `grid_span > 1`, one column to the
//     right (and continuing for `grid_span - 1` cells total).
//   - `TableCell::v_merge_covered` — cell in the column below a
//     `merged_origin` whose `row_span > 1`.
//   - `TableCell::hv_merge_covered` — corner case: a cell covered
//     by both an `hMerge` and a `vMerge`.
//
// Builders synthesise an empty `<a:tcPr/>` element on every cell so
// the resulting XML matches what PowerPoint emits even when the
// hand-built cell has no styling. Parsed cells that already carry a
// `tcPr` keep their captured properties on round-trip.

///|
/// Build an empty `<a:tcPr/>` `XmlElement`. PowerPoint expects
/// every cell to carry one, even an empty one, so the builders
/// synthesise it eagerly rather than letting the writer skip it.
fn empty_tc_pr() -> @xml.XmlElement {
  @xml.XmlElement::new(@xml.QName::new(@oxml.drawing_ns, "tcPr"), [], [])
}

///|
/// Build an empty `<a:tblPr/>` `XmlElement`. Same rationale as
/// `empty_tc_pr`: every table emits one, even if it carries no
/// style hints.
fn empty_tbl_pr() -> @xml.XmlElement {
  @xml.XmlElement::new(@xml.QName::new(@oxml.drawing_ns, "tblPr"), [], [])
}

// --- TableCell builders ---

///|
/// Ordinary cell carrying a single paragraph of plain text.
pub fn TableCell::of_text(text : String) -> TableCell {
  {
    grid_span: 1,
    row_span: 1,
    h_merge: false,
    v_merge: false,
    text_body: Some(TextBody::of_text(text)),
    properties: Some(empty_tc_pr()),
    extension: [],
  }
}

///|
/// Empty cell — same as `of_text("")` but documents intent.
pub fn TableCell::empty() -> TableCell {
  TableCell::of_text("")
}

///|
/// Origin cell of a merged region. Spans `grid_span` columns and
/// `row_span` rows. Pair with `h_merge_covered` and / or
/// `v_merge_covered` to fill the cells covered by the merge.
pub fn TableCell::merged_origin(
  text : String,
  grid_span? : Int = 1,
  row_span? : Int = 1,
) -> TableCell {
  {
    grid_span,
    row_span,
    h_merge: false,
    v_merge: false,
    text_body: Some(TextBody::of_text(text)),
    properties: Some(empty_tc_pr()),
    extension: [],
  }
}

///|
/// Cell covered by a horizontal merge — sits to the right of a
/// `merged_origin` whose `grid_span > 1`. Carries an empty body
/// and the `hMerge="1"` flag.
pub fn TableCell::h_merge_covered() -> TableCell {
  {
    grid_span: 1,
    row_span: 1,
    h_merge: true,
    v_merge: false,
    text_body: Some(TextBody::of_text("")),
    properties: Some(empty_tc_pr()),
    extension: [],
  }
}

///|
/// Cell covered by a vertical merge — sits below a `merged_origin`
/// whose `row_span > 1`. Carries `vMerge="1"`.
pub fn TableCell::v_merge_covered() -> TableCell {
  {
    grid_span: 1,
    row_span: 1,
    h_merge: false,
    v_merge: true,
    text_body: Some(TextBody::of_text("")),
    properties: Some(empty_tc_pr()),
    extension: [],
  }
}

///|
/// Cell at the bottom-right corner of a merge that spans both
/// columns *and* rows — carries both `hMerge="1"` and `vMerge="1"`.
pub fn TableCell::hv_merge_covered() -> TableCell {
  {
    grid_span: 1,
    row_span: 1,
    h_merge: true,
    v_merge: true,
    text_body: Some(TextBody::of_text("")),
    properties: Some(empty_tc_pr()),
    extension: [],
  }
}

// --- TableRow + Table builders ---

///|
/// Build a row from a list of cells at a uniform height.
pub fn TableRow::of_cells(
  cells : Array[TableCell],
  height~ : @units.Emu,
) -> TableRow {
  { height, cells, extension: [] }
}

///|
/// Build a table from its rows + column widths.  Caller is
/// responsible for ensuring every row has `col_widths.length()`
/// cells (counting covered-merge cells as occupying one column).
pub fn Table::of_rows(
  rows : Array[TableRow],
  col_widths~ : Array[@units.Emu],
) -> Table {
  { properties: Some(empty_tbl_pr()), grid: col_widths, rows, extension: [] }
}

///|
/// One-call convenience: produce a table of identical text cells.
/// Useful for "give me an empty 3×4 grid" boilerplate before the
/// caller fills individual cells with `with_cell` (Phase 6d) or by
/// mutating the result.
pub fn Table::of_grid(
  rows~ : Int,
  cols~ : Int,
  col_width~ : @units.Emu,
  row_height~ : @units.Emu,
) -> Table {
  let grid : Array[@units.Emu] = []
  let mut i = 0
  while i < cols {
    grid.push(col_width)
    i = i + 1
  }
  let row_list : Array[TableRow] = []
  let mut r = 0
  while r < rows {
    let cells : Array[TableCell] = []
    let mut c = 0
    while c < cols {
      cells.push(TableCell::empty())
      c = c + 1
    }
    row_list.push(TableRow::of_cells(cells, height=row_height))
    r = r + 1
  }
  Table::of_rows(row_list, col_widths=grid)
}

// --- GraphicFrame builder ---

///|
/// Wrap a typed `Table` in a `GraphicFrame` with the given id /
/// name / placement. Same shape as `AutoShape::rect / textbox`
/// builders — accepts EMU values directly so the caller stays in
/// the typed unit world.
pub fn GraphicFrame::of_table(
  id : Int,
  name : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
  table : Table,
) -> GraphicFrame {
  {
    id,
    name,
    transform: Some({ offset: { x, y }, extent: { cx, cy } }),
    content: TableContent(table),
    extension: [],
  }
}
