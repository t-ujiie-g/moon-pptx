// Integration tests for `<a:ln>` parsing on shape bodies (Phase 3e3).

///|
fn slide_with_sp_body(inner_sp_pr_body : String) -> FixedArray[Byte] {
  // Builds a slide with one `<p:sp>` whose `<p:spPr>` body is supplied
  // verbatim. We use this to attach `<a:xfrm>` + `<a:ln>` + geometry
  // combinations without dragging the rest of the slide around.
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
fn shape_stroke(s : @slide.Slide) -> @oxml.Stroke? {
  match s.shapes[0] {
    AutoShape(sp) => sp.stroke
    _ => abort("expected AutoShape")
  }
}

// --- shape body integration ---

///|
test "shape stroke: a:ln on spPr lifts to AutoShape.stroke" {
  let body = "<a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1\" cy=\"1\"/></a:xfrm>" +
    "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>" +
    "<a:ln w=\"9525\" cap=\"flat\">" +
    "<a:solidFill><a:srgbClr val=\"123456\"/></a:solidFill>" +
    "<a:prstDash val=\"dash\"/>" +
    "</a:ln>"
  let slide = @slide.Slide::parse(slide_with_sp_body(body))
  let s = shape_stroke(slide).unwrap()
  assert_eq(s.width.unwrap(), @units.Emu(9525L))
  assert_true(s.cap.unwrap() is @oxml.LineCap::CapFlat)
  assert_true(s.dash.unwrap() is @oxml.DashStyle::DashDash)
  match s.fill.unwrap() {
    SolidFill(c) =>
      match c.base {
        Srgb(rgb) => assert_eq(rgb.to_hex(), "123456")
        _ => fail("expected Srgb")
      }
    _ => fail("expected SolidFill")
  }
}

///|
test "shape stroke: shape without a:ln leaves stroke = None" {
  let body = "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>"
  let slide = @slide.Slide::parse(slide_with_sp_body(body))
  assert_true(shape_stroke(slide) is None)
}

///|
test "shape stroke: a:ln with arrows lands on the right ends" {
  let body = "<a:ln w=\"6350\">" +
    "<a:headEnd type=\"oval\"/>" +
    "<a:tailEnd type=\"triangle\" w=\"lg\" len=\"med\"/>" +
    "</a:ln>"
  let slide = @slide.Slide::parse(slide_with_sp_body(body))
  let s = shape_stroke(slide).unwrap()
  assert_true(s.head_end.unwrap().arrow_type is @oxml.ArrowType::ArrowOval)
  let t = s.tail_end.unwrap()
  assert_true(t.arrow_type is @oxml.ArrowType::ArrowTriangle)
  assert_true(t.width.unwrap() is @oxml.ArrowSize::SizeLarge)
}

///|
test "shape stroke: bad inner colour bubbles up as SlideError" {
  let body = "<a:ln><a:solidFill><a:srgbClr val=\"GGGGGG\"/></a:solidFill></a:ln>"
  let r = try? @slide.Slide::parse(slide_with_sp_body(body))
  assert_true(r is Err(@slide.SlideError::Malformed(_)))
}
