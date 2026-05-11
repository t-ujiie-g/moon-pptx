// Integration tests for `<a:effectLst>` parsing on shape bodies (Phase 3e4).

///|
fn slide_with_sp_pr_for_effects(inner_sp_pr_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"S\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr>" +
    inner_sp_pr_body +
    "</p:spPr>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  fixture_bytes(xml)
}

///|
fn shape_effects(s : @slide.Slide) -> @oxml.EffectList? {
  match s.shapes[0] {
    AutoShape(sp) => sp.effects
    _ => abort("expected AutoShape")
  }
}

///|
test "shape effects: effectLst lifts to AutoShape.effects" {
  let body = "<a:effectLst>" +
    "<a:outerShdw blurRad=\"50800\" dist=\"38100\" dir=\"2700000\">" +
    "<a:srgbClr val=\"000000\"/>" +
    "</a:outerShdw>" +
    "</a:effectLst>"
  let slide = @slide.Slide::parse(slide_with_sp_pr_for_effects(body))
  let fx = shape_effects(slide).unwrap()
  let s = fx.outer_shadow.unwrap()
  assert_eq(s.blur_rad, @units.Emu(50800L))
  assert_eq(s.dist, @units.Emu(38100L))
  match s.color.base {
    Srgb(rgb) => assert_eq(rgb.to_hex(), "000000")
    _ => fail("expected Srgb")
  }
}

///|
test "shape effects: no effectLst leaves effects = None" {
  let body = "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>"
  let slide = @slide.Slide::parse(slide_with_sp_pr_for_effects(body))
  assert_true(shape_effects(slide) is None)
}

///|
test "shape effects: malformed nested colour bubbles up as SlideError" {
  let body = "<a:effectLst>" +
    "<a:glow rad=\"63500\"><a:srgbClr val=\"BAD\"/></a:glow>" +
    "</a:effectLst>"
  let r = try? @slide.Slide::parse(slide_with_sp_pr_for_effects(body))
  assert_true(r is Err(@slide.SlideError::Malformed(_)))
}
