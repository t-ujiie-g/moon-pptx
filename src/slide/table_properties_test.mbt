// TableProperties / TableCellProperties tests.

///|
fn slide_with_table_xml(table_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<p:graphicFrame>" +
    "<p:nvGraphicFramePr><p:cNvPr id=\"2\" name=\"T\"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>" +
    "<p:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></p:xfrm>" +
    "<a:graphic><a:graphicData uri=\"" +
    @oxml.graphic_data_table_uri +
    "\">" +
    table_body +
    "</a:graphicData></a:graphic>" +
    "</p:graphicFrame>" +
    "</p:spTree></p:cSld></p:sld>"
  fixture_bytes(xml)
}

///|
/// Pull the parsed Table out of a slide built with `slide_with_table_xml`.
fn extract_table(bytes : FixedArray[Byte]) -> @slide.Table raise {
  let s = @slide.Slide::parse(bytes)
  match s.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        TableContent(t) => t
        _ => panic()
      }
    _ => panic()
  }
}

// --- TableProperties parsing ---

///|
test "TableProperties: style-hint attributes lift into typed flags" {
  let body = "<a:tbl>" +
    "<a:tblPr firstRow=\"1\" lastCol=\"0\" bandRow=\"1\" rtl=\"0\"/>" +
    "<a:tblGrid><a:gridCol w=\"100\"/></a:tblGrid>" +
    "<a:tr h=\"50\"><a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody><a:tcPr/></a:tc></a:tr>" +
    "</a:tbl>"
  let t = extract_table(slide_with_table_xml(body))
  let p = t.properties.unwrap()
  assert_true(p.first_row == Some(true))
  assert_true(p.last_col == Some(false))
  assert_true(p.band_row == Some(true))
  assert_true(p.rtl == Some(false))
  // Absent attributes stay None.
  assert_true(p.first_col is None)
  assert_true(p.last_row is None)
  assert_true(p.band_col is None)
}

///|
test "TableProperties: <a:tableStyleId> lifts to typed string" {
  let body = "<a:tbl>" +
    "<a:tblPr><a:tableStyleId>{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}</a:tableStyleId></a:tblPr>" +
    "<a:tblGrid><a:gridCol w=\"100\"/></a:tblGrid>" +
    "<a:tr h=\"50\"><a:tc><a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody><a:tcPr/></a:tc></a:tr>" +
    "</a:tbl>"
  let t = extract_table(slide_with_table_xml(body))
  assert_eq(
    t.properties.unwrap().table_style_id.unwrap(),
    "{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}",
  )
}

// --- TableCellProperties parsing ---

///|
test "TableCellProperties: margins + anchor lift to typed fields" {
  let body = "<a:tbl>" +
    "<a:tblPr/>" +
    "<a:tblGrid><a:gridCol w=\"100\"/></a:tblGrid>" +
    "<a:tr h=\"50\">" +
    "<a:tc>" +
    "<a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody>" +
    "<a:tcPr marL=\"45720\" marR=\"45720\" marT=\"30480\" marB=\"30480\" anchor=\"ctr\"/>" +
    "</a:tc>" +
    "</a:tr></a:tbl>"
  let t = extract_table(slide_with_table_xml(body))
  let p = t.rows[0].cells[0].properties.unwrap()
  assert_eq(p.margin_l.unwrap(), @units.Emu(45720L))
  assert_eq(p.margin_r.unwrap(), @units.Emu(45720L))
  assert_eq(p.margin_t.unwrap(), @units.Emu(30480L))
  assert_eq(p.margin_b.unwrap(), @units.Emu(30480L))
  assert_true(p.anchor == Some(@slide.Anchor::AnchorCenter))
}

///|
test "TableCellProperties: borders lift to typed Stroke values" {
  let body = "<a:tbl>" +
    "<a:tblPr/>" +
    "<a:tblGrid><a:gridCol w=\"100\"/></a:tblGrid>" +
    "<a:tr h=\"50\"><a:tc>" +
    "<a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody>" +
    "<a:tcPr>" +
    "<a:lnL w=\"12700\"><a:solidFill><a:srgbClr val=\"000000\"/></a:solidFill></a:lnL>" +
    "<a:lnB w=\"25400\"><a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill></a:lnB>" +
    "</a:tcPr>" +
    "</a:tc></a:tr></a:tbl>"
  let t = extract_table(slide_with_table_xml(body))
  let p = t.rows[0].cells[0].properties.unwrap()
  let left = p.border_left.unwrap()
  assert_eq(left.width.unwrap(), @units.Emu(12700L))
  let bottom = p.border_bottom.unwrap()
  assert_eq(bottom.width.unwrap(), @units.Emu(25400L))
  assert_true(p.border_right is None)
  assert_true(p.border_top is None)
}

///|
test "TableCellProperties: fill choice lifts to typed Fill" {
  let body = "<a:tbl>" +
    "<a:tblPr/>" +
    "<a:tblGrid><a:gridCol w=\"100\"/></a:tblGrid>" +
    "<a:tr h=\"50\"><a:tc>" +
    "<a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody>" +
    "<a:tcPr>" +
    "<a:solidFill><a:srgbClr val=\"FFFF00\"/></a:solidFill>" +
    "</a:tcPr>" +
    "</a:tc></a:tr></a:tbl>"
  let t = extract_table(slide_with_table_xml(body))
  let p = t.rows[0].cells[0].properties.unwrap()
  assert_true(p.fill is Some(SolidFill(_)))
}

// --- Round-trip ---

///|
test "tblPr + tcPr round-trip preserves typed fields" {
  let body = "<a:tbl>" +
    "<a:tblPr firstRow=\"1\" bandRow=\"1\">" +
    "<a:solidFill><a:srgbClr val=\"DDDDDD\"/></a:solidFill>" +
    "<a:tableStyleId>{ABCDEF}</a:tableStyleId>" +
    "</a:tblPr>" +
    "<a:tblGrid><a:gridCol w=\"100\"/></a:tblGrid>" +
    "<a:tr h=\"50\"><a:tc>" +
    "<a:txBody><a:bodyPr/><a:lstStyle/><a:p/></a:txBody>" +
    "<a:tcPr marL=\"45720\" anchor=\"ctr\">" +
    "<a:lnL w=\"12700\"><a:solidFill><a:srgbClr val=\"000000\"/></a:solidFill></a:lnL>" +
    "<a:solidFill><a:srgbClr val=\"FFFF00\"/></a:solidFill>" +
    "</a:tcPr>" +
    "</a:tc></a:tr></a:tbl>"
  let bytes = slide_with_table_xml(body)
  let s0 = @slide.Slide::parse(bytes)
  let s1 = @slide.Slide::parse(s0.serialize())
  assert_true(s0 == s1)
}

// --- Builders with typed properties ---

///|
test "TableCellProperties::with_margins / with_fill / with_anchor: fluent set" {
  let p = @slide.TableCellProperties::default()
    .with_margins(left=Some(@units.Emu(45720L)), right=Some(@units.Emu(45720L)))
    .with_fill(
      @oxml.Fill::SolidFill(
        @oxml.Color::srgb(@units.RgbColor::parse_hex("FFFF00")),
      ),
    )
    .with_anchor(@slide.Anchor::AnchorCenter)
  assert_eq(p.margin_l.unwrap(), @units.Emu(45720L))
  assert_eq(p.margin_r.unwrap(), @units.Emu(45720L))
  assert_true(p.fill is Some(SolidFill(_)))
  assert_true(p.anchor == Some(@slide.Anchor::AnchorCenter))
}

///|
test "TableCellProperties: builder-produced values survive serialize → reparse" {
  // Build a cell with properties set via fluent builders, drop it
  // into a graphicFrame on a slide, serialise the slide, re-parse,
  // and confirm every typed field comes back with the same value.
  let yellow = @units.RgbColor::parse_hex("FFFF00")
  let props = @slide.TableCellProperties::default()
    .with_margins(
      left=Some(@units.Emu(45720L)),
      right=Some(@units.Emu(45720L)),
      top=Some(@units.Emu(30480L)),
      bottom=Some(@units.Emu(30480L)),
    )
    .with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(yellow)))
    .with_anchor(@slide.Anchor::AnchorCenter)
  let cell : @slide.TableCell = {
    grid_span: 1,
    row_span: 1,
    h_merge: false,
    v_merge: false,
    text_body: Some(@slide.TextBody::of_text("X")),
    properties: Some(props),
    extension: [],
  }
  let row = @slide.TableRow::of_cells([cell], height=@units.Emu(457200L))
  let t = @slide.Table::of_rows([row], col_widths=[@units.Emu(914400L)])
  let gf = @slide.GraphicFrame::of_table(
    7,
    "T",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914400L),
    @units.Emu(457200L),
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
  let s = base.with_shape(@slide.GraphicFrame(gf))
  let reparsed = @slide.Slide::parse(s.serialize())
  match reparsed.shapes[0] {
    GraphicFrame(parsed_gf) =>
      match parsed_gf.content {
        TableContent(parsed_t) => {
          let p = parsed_t.rows[0].cells[0].properties.unwrap()
          assert_eq(p.margin_l.unwrap(), @units.Emu(45720L))
          assert_eq(p.margin_r.unwrap(), @units.Emu(45720L))
          assert_eq(p.margin_t.unwrap(), @units.Emu(30480L))
          assert_eq(p.margin_b.unwrap(), @units.Emu(30480L))
          assert_true(p.anchor == Some(@slide.Anchor::AnchorCenter))
          assert_true(p.fill is Some(SolidFill(_)))
        }
        _ => fail("expected TableContent")
      }
    _ => fail("expected GraphicFrame")
  }
}

///|
/// Minimal Stroke value for fluency tests — sets only a width so
/// the value is non-default; every other field stays `None`.
fn minimal_stroke() -> @oxml.Stroke {
  {
    width: Some(@units.Emu(6350L)),
    cap: None,
    compound: None,
    alignment: None,
    fill: None,
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
}

///|
test "TableCellProperties::with_borders: applies only the Some edges" {
  let s = minimal_stroke()
  let p = @slide.TableCellProperties::default().with_borders(left=s, top=s)
  assert_true(p.border_left is Some(_))
  assert_true(p.border_right is None)
  assert_true(p.border_top is Some(_))
  assert_true(p.border_bottom is None)
}

///|
test "TableCellProperties::with_borders: None args leave existing borders alone" {
  let s = minimal_stroke()
  let p = @slide.TableCellProperties::default()
    .with_border_all(s)
    .with_borders(top=s) // leaves left/right/bottom intact
  assert_true(p.border_left is Some(_))
  assert_true(p.border_right is Some(_))
  assert_true(p.border_top is Some(_))
  assert_true(p.border_bottom is Some(_))
}
