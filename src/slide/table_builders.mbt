// Table builders.
//
// Hand-friendly constructors for table cells / rows / tables and
// the surrounding `GraphicFrame` wrapper. Same pattern as the
// `AutoShape::rect / ellipse / textbox` builders in `builders.mbt`:
// produce values whose serialisation re-parses to an equal value
// from the second cycle onward (the first cycle adds the
// captured-wrapper trinkets `<p:cNvPr>` etc. — see the design note
// in `slide/writer_test.mbt`).
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

// PowerPoint expects every cell to carry an `<a:tcPr/>` and every
// table to carry an `<a:tblPr/>`, even if both are empty. The
// builders synthesise `TableCellProperties::default()` /
// `TableProperties::default()` so the resulting XML always has
// those elements.

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
    properties: Some(TableCellProperties::default()),
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
    properties: Some(TableCellProperties::default()),
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
    properties: Some(TableCellProperties::default()),
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
    properties: Some(TableCellProperties::default()),
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
    properties: Some(TableCellProperties::default()),
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
  {
    properties: Some(TableProperties::default()),
    grid: col_widths,
    rows,
    extension: [],
  }
}

///|
/// One-call convenience: produce a table of identical text cells.
/// Useful for "give me an empty 3×4 grid" boilerplate before the
/// caller mutates individual cells via field replacement.
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
