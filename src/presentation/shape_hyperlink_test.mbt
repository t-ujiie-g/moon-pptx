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
