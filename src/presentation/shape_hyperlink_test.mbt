// Tests for shape-level hyperlinks (roadmap v0.6 F5):
// `AutoShape` / `Picture` `with_hyperlink` / `with_hyperlink_to_slide`,
// resolved by `update_slide_mut` (shared resolver with run hyperlinks).

///|
/// Decoded XML of the named slide part.
fn slide_xml_of(prs : @presentation.Presentation, name : String) -> String {
  @oxml.bytes_to_string(prs.pkg.part_by_name(name).unwrap().bytes) catch {
    _ => abort("slide part is not valid UTF-8")
  }
}

///|
test "shape with_hyperlink: external URL → rel + <a:hlinkClick> on cNvPr" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let box = @slide.AutoShape::rect(
    2,
    "btn",
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    @units.Emu(2_000_000L),
    @units.Emu(800_000L),
  ).with_hyperlink(url="https://example.com")
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(box)))
  // A TargetMode::External hyperlink rel is registered on the slide.
  let rels = prs.pkg.relationships_for(slide_name)
  let hl = rels.by_type(@opc.rt_hyperlink)[0]
  assert_eq(hl.target, "https://example.com")
  assert_true(hl.target_mode is External)
  // The slide XML carries an <a:hlinkClick> referencing that rId.
  let xml = slide_xml_of(prs, slide_name)
  assert_true(has_substring(xml, "hlinkClick"))
  assert_true(has_substring(xml, "r:id=\"" + hl.id + "\""))
}

///|
test "shape with_hyperlink_to_slide: rt_slide rel + ppaction jump" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0) // target slide index 1 exists
  let box = @slide.AutoShape::rect(
    2,
    "nav",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(1_000_000L),
    @units.Emu(1_000_000L),
  ).with_hyperlink_to_slide(slide_idx=1)
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(box)))
  let rels = prs.pkg.relationships_for(slide_name)
  let jump = rels.by_type(@opc.rt_slide)[0]
  assert_true(jump.target_mode is Internal)
  let xml = slide_xml_of(prs, slide_name)
  assert_true(has_substring(xml, "ppaction://hlinksldjump"))
  assert_true(has_substring(xml, "r:id=\"" + jump.id + "\""))
}

///|
test "picture with_hyperlink: external URL → rel + hlinkClick" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let pic = @slide.Picture::of_image(
    3,
    "img",
    "rId99",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
  ).with_hyperlink(url="https://pics.example")
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.Picture(pic)))
  let rels = prs.pkg.relationships_for(slide_name)
  let hl = rels.by_type(@opc.rt_hyperlink)[0]
  assert_eq(hl.target, "https://pics.example")
  let xml = slide_xml_of(prs, slide_name)
  assert_true(has_substring(xml, "hlinkClick"))
  assert_true(has_substring(xml, "r:id=\"" + hl.id + "\""))
}

///|
test "shape with_hyperlink: survives save → reopen" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let box = @slide.AutoShape::rect(
    2,
    "btn",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(1_000_000L),
    @units.Emu(1_000_000L),
  ).with_hyperlink(url="https://saved.example")
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(box)))
  let prs2 = @presentation.Presentation::open(prs.save())
  let rels = prs2.pkg.relationships_for(slide_name)
  assert_eq(rels.by_type(@opc.rt_hyperlink)[0].target, "https://saved.example")
  // The reopened slide still has the hlinkClick (round-trips via captured cNvPr).
  assert_true(has_substring(slide_xml_of(prs2, slide_name), "hlinkClick"))
}

///|
test "shape without hyperlink: no hyperlink rel, no hlinkClick" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let box = @slide.AutoShape::rect(
    2,
    "plain",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(1_000_000L),
    @units.Emu(1_000_000L),
  )
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(box)))
  let rels = prs.pkg.relationships_for(slide_name)
  assert_eq(rels.by_type(@opc.rt_hyperlink).length(), 0)
  assert_eq(has_substring(slide_xml_of(prs, slide_name), "hlinkClick"), false)
}

///|
test "ShapeHyperlink::external / to_slide constructors carry the target" {
  let ext = @slide.ShapeHyperlink::external("https://example.com")
  assert_true(ext.target == Some(ExternalUrl("https://example.com")))
  assert_true(ext.click is None && ext.action is None)
  let jump = @slide.ShapeHyperlink::to_slide(3)
  assert_true(jump.target == Some(InternalSlide(3)))
  assert_true(jump.click is None && jump.action is None)
}

// --- F5-b: the remaining shape kinds (Connector / Group / GraphicFrame) ---

///|
/// A free-floating straight connector for the F5-b tests (no builder
/// constructor exists for connectors — literal construction is the norm).
fn test_connector(id : Int) -> @slide.Connector {
  {
    id,
    name: "conn",
    transform: Some(
      @slide.Transform::new(offset={ x: @units.Emu(0L), y: @units.Emu(0L) }, extent={
        cx: @units.Emu(1_000_000L),
        cy: @units.Emu(0L),
      }),
    ),
    geometry: Some(Preset(@slide.PresetShape::Line, [])),
    stroke: None,
    effects: None,
    start: None,
    end: None,
    hyperlink: None,
    extension: [],
  }
}

///|
test "connector with_hyperlink: external URL → rel + hlinkClick on cNvPr" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let conn = test_connector(2).with_hyperlink(url="https://conn.example")
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.Connector(conn)))
  let rels = prs.pkg.relationships_for(slide_name)
  let hl = rels.by_type(@opc.rt_hyperlink)[0]
  assert_eq(hl.target, "https://conn.example")
  assert_true(hl.target_mode is External)
  let xml = slide_xml_of(prs, slide_name)
  assert_true(has_substring(xml, "hlinkClick"))
  assert_true(has_substring(xml, "r:id=\"" + hl.id + "\""))
}

///|
test "group with_hyperlink_to_slide: rt_slide rel + ppaction jump" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0) // target slide index 1 exists
  let g : @slide.GroupShape = {
    id: 2,
    name: "grp",
    transform: Some(
      @slide.Transform::new(offset={ x: @units.Emu(0L), y: @units.Emu(0L) }, extent={
        cx: @units.Emu(1_000_000L),
        cy: @units.Emu(1_000_000L),
      }),
    ),
    child_offset: Some({ x: @units.Emu(0L), y: @units.Emu(0L) }),
    child_extent: Some({
      cx: @units.Emu(1_000_000L),
      cy: @units.Emu(1_000_000L),
    }),
    children: [],
    hyperlink: None,
    extension: [],
  }
  prs.update_slide_mut(
    0,
    prs.slides()[0].with_shape(
      @slide.Group(g.with_hyperlink_to_slide(slide_idx=1)),
    ),
  )
  let rels = prs.pkg.relationships_for(slide_name)
  let jump = rels.by_type(@opc.rt_slide)[0]
  assert_true(jump.target_mode is Internal)
  let xml = slide_xml_of(prs, slide_name)
  assert_true(has_substring(xml, "ppaction://hlinksldjump"))
  assert_true(has_substring(xml, "r:id=\"" + jump.id + "\""))
}

///|
test "graphic frame with_hyperlink: a clickable table survives save → reopen" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  let table = @slide.Table::of_grid(
    rows=2,
    cols=2,
    col_width=@units.Emu(1_000_000L),
    row_height=@units.Emu(370_000L),
  )
  let frame = @slide.GraphicFrame::of_table(
    2,
    "tbl",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(2_000_000L),
    @units.Emu(740_000L),
    table,
  ).with_hyperlink(url="https://table.example")
  prs.update_slide_mut(
    0,
    prs.slides()[0].with_shape(@slide.GraphicFrame(frame)),
  )
  let rels = prs.pkg.relationships_for(slide_name)
  assert_eq(rels.by_type(@opc.rt_hyperlink)[0].target, "https://table.example")
  let xml = slide_xml_of(prs, slide_name)
  assert_true(has_substring(xml, "hlinkClick"))
  // Save → reopen: the hlinkClick round-trips via the captured cNvPr.
  let prs2 = @presentation.Presentation::open(prs.save())
  assert_true(has_substring(slide_xml_of(prs2, slide_name), "hlinkClick"))
}

///|
test "F5-b builders set the unresolved target and leave the original intact" {
  let conn = test_connector(9)
  let conn_ext = conn.with_hyperlink(url="https://a.example")
  let conn_jump = conn.with_hyperlink_to_slide(slide_idx=2)
  assert_true(conn.hyperlink is None) // ADR-003 immutability
  assert_true(
    conn_ext.hyperlink.unwrap().target == Some(ExternalUrl("https://a.example")),
  )
  assert_true(conn_jump.hyperlink.unwrap().target == Some(InternalSlide(2)))
  let frame = @slide.GraphicFrame::of_table(
    1,
    "t",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(1L),
    @units.Emu(1L),
    @slide.Table::of_grid(
      rows=1,
      cols=1,
      col_width=@units.Emu(1L),
      row_height=@units.Emu(1L),
    ),
  )
  assert_true(
    frame.with_hyperlink(url="https://f.example").hyperlink.unwrap().target ==
    Some(ExternalUrl("https://f.example")),
  )
  assert_true(
    frame.with_hyperlink_to_slide(slide_idx=1).hyperlink.unwrap().target ==
    Some(InternalSlide(1)),
  )
  assert_true(frame.hyperlink is None)
  let g : @slide.GroupShape = {
    id: 3,
    name: "g",
    transform: None,
    child_offset: None,
    child_extent: None,
    children: [],
    hyperlink: None,
    extension: [],
  }
  assert_true(
    g.with_hyperlink(url="https://g.example").hyperlink.unwrap().target ==
    Some(ExternalUrl("https://g.example")),
  )
  assert_true(g.hyperlink is None)
}

///|
test "picture with_hyperlink_to_slide: rt_slide rel + ppaction jump" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  // A 1×1 BMP is enough for add_picture_mut; then rebuild the picture
  // with the jump hyperlink via update.
  let bmp : FixedArray[Byte] = [
    b'B', b'M', 58, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0, 1, 0, 0, 0, 1,
    0, 0, 0, 1, 0, 24, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 255, 255, 255, 0,
  ]
  prs.add_picture_mut(
    0,
    bmp,
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  prs.update_slide_mut(
    0,
    prs.slides()[0].map_shapes(s => {
      match s {
        Picture(p) => Picture(p.with_hyperlink_to_slide(slide_idx=1))
        other => other
      }
    }),
  )
  let xml = @oxml.bytes_to_string(
    prs.pkg.part_by_name("/ppt/slides/slide1.xml").unwrap().bytes,
  )
  assert_true(xml.find("ppaction://hlinksldjump") is Some(_))
  // The slide rels carry an rt_slide relationship at slide2.
  let rels = @oxml.bytes_to_string(
    prs.pkg.part_by_name("/ppt/slides/_rels/slide1.xml.rels").unwrap().bytes,
  )
  assert_true(rels.find("slide2.xml") is Some(_))
}
