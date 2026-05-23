// Table builder tests — Phase 6c.

///|
test "TableCell::of_text: carries text + default span / merge" {
  let c = @slide.TableCell::of_text("Hello")
  assert_eq(c.text_body.unwrap().plain_text(), "Hello")
  assert_eq(c.grid_span, 1)
  assert_eq(c.row_span, 1)
  assert_true(!c.h_merge)
  assert_true(!c.v_merge)
  // Synthesises an empty <a:tcPr/>.
  assert_true(c.properties is Some(_))
}

///|
test "TableCell::merged_origin: spans columns and rows" {
  let c = @slide.TableCell::merged_origin("Joined", grid_span=3, row_span=2)
  assert_eq(c.grid_span, 3)
  assert_eq(c.row_span, 2)
  // The origin cell itself is NOT covered — only the cells it
  // spans into are.
  assert_true(!c.h_merge)
  assert_true(!c.v_merge)
}

///|
test "TableCell::*_merge_covered: carry the right flags" {
  let h = @slide.TableCell::h_merge_covered()
  assert_true(h.h_merge)
  assert_true(!h.v_merge)
  let v = @slide.TableCell::v_merge_covered()
  assert_true(!v.h_merge)
  assert_true(v.v_merge)
  let hv = @slide.TableCell::hv_merge_covered()
  assert_true(hv.h_merge)
  assert_true(hv.v_merge)
}

///|
test "Table::of_grid: produces correctly-sized empty grid" {
  let t = @slide.Table::of_grid(
    rows=3,
    cols=4,
    col_width=@units.Emu(914400L),
    row_height=@units.Emu(457200L),
  )
  assert_eq(t.grid.length(), 4)
  assert_eq(t.rows.length(), 3)
  for row in t.rows {
    assert_eq(row.cells.length(), 4)
    assert_eq(row.height, @units.Emu(457200L))
  }
  // Each column gets the requested width.
  for col_w in t.grid {
    assert_eq(col_w, @units.Emu(914400L))
  }
}

///|
test "Table::of_rows: custom cell mix" {
  let row0 = @slide.TableRow::of_cells(
    [@slide.TableCell::of_text("A1"), @slide.TableCell::of_text("B1")],
    height=@units.Emu(457200L),
  )
  let row1 = @slide.TableRow::of_cells(
    [
      @slide.TableCell::merged_origin("A2-merged", grid_span=2),
      @slide.TableCell::h_merge_covered(),
    ],
    height=@units.Emu(457200L),
  )
  let t = @slide.Table::of_rows([row0, row1], col_widths=[
    @units.Emu(914400L),
    @units.Emu(914400L),
  ])
  assert_eq(t.rows.length(), 2)
  assert_eq(t.rows[1].cells[0].grid_span, 2)
  assert_true(t.rows[1].cells[1].h_merge)
}

///|
test "GraphicFrame::of_table: id / name / transform / content" {
  let t = @slide.Table::of_grid(
    rows=1,
    cols=1,
    col_width=@units.Emu(914400L),
    row_height=@units.Emu(457200L),
  )
  let gf = @slide.GraphicFrame::of_table(
    42,
    "Grid 1",
    @units.Emu(100L),
    @units.Emu(200L),
    @units.Emu(300L),
    @units.Emu(400L),
    t,
  )
  assert_eq(gf.id, 42)
  assert_eq(gf.name, "Grid 1")
  let xfrm = gf.transform.unwrap()
  assert_eq(xfrm.offset.x, @units.Emu(100L))
  assert_eq(xfrm.extent.cy, @units.Emu(400L))
  match gf.content {
    TableContent(_) => ()
    _ => fail("expected TableContent")
  }
}

///|
test "GraphicFrame::of_table: round-trips via Slide::serialize" {
  // Build a slide → add a table-bearing graphicFrame → serialise →
  // reparse. The structural-equivalence floor matches what the
  // AutoShape builder test asserts (first round-trip adds captured
  // wrappers).
  let base_xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let base = @slide.Slide::parse(fixture_bytes(base_xml))
  let t = @slide.Table::of_grid(
    rows=2,
    cols=2,
    col_width=@units.Emu(914400L),
    row_height=@units.Emu(457200L),
  )
  let gf = @slide.GraphicFrame::of_table(
    7,
    "Table 1",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(1828800L),
    @units.Emu(914400L),
    t,
  )
  let s = base.with_shape(@slide.GraphicFrame(gf))
  let s_reparsed = @slide.Slide::parse(s.serialize())
  assert_eq(s_reparsed.shapes.length(), 1)
  match s_reparsed.shapes[0] {
    GraphicFrame(parsed_gf) => {
      assert_eq(parsed_gf.id, 7)
      assert_eq(parsed_gf.name, "Table 1")
      match parsed_gf.content {
        TableContent(parsed_t) => {
          assert_eq(parsed_t.grid.length(), 2)
          assert_eq(parsed_t.rows.length(), 2)
        }
        _ => fail("expected TableContent")
      }
    }
    _ => fail("expected GraphicFrame")
  }
}

///|
test "GraphicFrame::of_table: second round-trip is Eq-stable" {
  let t = @slide.Table::of_grid(
    rows=2,
    cols=2,
    col_width=@units.Emu(914400L),
    row_height=@units.Emu(457200L),
  )
  let gf = @slide.GraphicFrame::of_table(
    7,
    "Tbl",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914400L),
    @units.Emu(914400L),
    t,
  )
  let base_xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\"><p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "</p:spTree></p:cSld></p:sld>"
  let base = @slide.Slide::parse(fixture_bytes(base_xml))
  let s1 = @slide.Slide::parse(
    base.with_shape(@slide.GraphicFrame(gf)).serialize(),
  )
  let s2 = @slide.Slide::parse(s1.serialize())
  assert_true(s1 == s2)
}
