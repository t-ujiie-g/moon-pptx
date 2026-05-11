// Picture parser tests (Phase 3c3).

///|
/// Build a slide containing a single `<p:pic>` whose body is provided
/// verbatim. Caller controls the inner shape so we can exercise srcRect,
/// stretch, etc. independently.
fn slide_with_pic(inner : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:pic>" +
    inner +
    "</p:pic>" +
    "</p:spTree></p:cSld></p:sld>"
  fixture_bytes(xml)
}

// --- happy path ---

///|
test "parse: typical picture with embed and stretch" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"5\" name=\"Pic1\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill>" +
    "<a:blip r:embed=\"rId7\" cstate=\"print\"/>" +
    "<a:stretch><a:fillRect/></a:stretch>" +
    "</p:blipFill>" +
    "<p:spPr>" +
    "<a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm>" +
    "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>" +
    "</p:spPr>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(p) => {
      assert_eq(p.id, 5)
      assert_eq(p.name, "Pic1")
      assert_eq(p.embed_id, "rId7")
      assert_eq(p.link_id, "")
      assert_true(p.src_rect is None)
      let xfrm = p.transform.unwrap()
      assert_eq(xfrm.offset.x, @units.Emu(100L))
      assert_eq(xfrm.extent.cy, @units.Emu(400L))
      match p.geometry.unwrap() {
        Preset(kind, _) => assert_true(kind is @slide.PresetShape::Rect)
        _ => fail("expected Preset")
      }
    }
    _ => fail("expected Picture")
  }
}

///|
test "parse: picture with linked rId (no embed)" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"6\" name=\"Linked\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:link=\"rId9\"/></p:blipFill>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(p) => {
      assert_eq(p.embed_id, "")
      assert_eq(p.link_id, "rId9")
    }
    _ => fail("expected Picture")
  }
}

///|
test "parse: picture with srcRect crop" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"7\" name=\"Cropped\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill>" +
    "<a:blip r:embed=\"rId1\"/>" +
    "<a:srcRect l=\"10000\" t=\"20000\" r=\"5000\" b=\"5000\"/>" +
    "<a:stretch><a:fillRect/></a:stretch>" +
    "</p:blipFill>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(p) => {
      let sr = p.src_rect.unwrap()
      // l=10000 = 10% (1000ths-of-percent)
      assert_eq(sr.left, @units.Percentage(10.0))
      assert_eq(sr.top, @units.Percentage(20.0))
      assert_eq(sr.right, @units.Percentage(5.0))
      assert_eq(sr.bottom, @units.Percentage(5.0))
    }
    _ => fail("expected Picture")
  }
}

///|
test "parse: srcRect with no attributes defaults to zeros" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"8\" name=\"x\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId1\"/><a:srcRect/></p:blipFill>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(p) => {
      let sr = p.src_rect.unwrap()
      assert_eq(sr.left, @units.Percentage(0.0))
      assert_eq(sr.top, @units.Percentage(0.0))
      assert_eq(sr.right, @units.Percentage(0.0))
      assert_eq(sr.bottom, @units.Percentage(0.0))
    }
    _ => fail("expected Picture")
  }
}

///|
test "parse: tile fill is consumed without raising" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"9\" name=\"Tiled\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill>" +
    "<a:blip r:embed=\"rId1\"/>" +
    "<a:tile tx=\"0\" ty=\"0\" sx=\"100000\" sy=\"100000\" flip=\"none\" algn=\"tl\"/>" +
    "</p:blipFill>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(_) => () // ok
    _ => fail("expected Picture")
  }
}

///|
test "parse: blip with image effects nested children skipped cleanly" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"10\" name=\"Mod\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill>" +
    "<a:blip r:embed=\"rId1\">" +
    "<a:lum bright=\"-20000\"/>" +
    "<a:alphaModFix amt=\"50000\"/>" +
    "<a:extLst><a:ext uri=\"{x}\"><a:y/></a:ext></a:extLst>" +
    "</a:blip>" +
    "<a:stretch><a:fillRect/></a:stretch>" +
    "</p:blipFill>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_pic(inner))
  match slide.shapes[0] {
    Picture(p) => assert_eq(p.embed_id, "rId1")
    _ => fail("expected Picture")
  }
}

// --- error cases ---

///|
test "parse: blip with neither embed nor link is rejected" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"1\" name=\"x\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip/></p:blipFill>" +
    "<p:spPr/>"
  let r = try? @slide.Slide::parse(slide_with_pic(inner))
  assert_true(r is Err(@slide.SlideError::Malformed(_)))
}

///|
test "parse: srcRect with non-integer attribute is rejected" {
  let inner = "<p:nvPicPr><p:cNvPr id=\"1\" name=\"x\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId1\"/><a:srcRect l=\"oops\"/></p:blipFill>" +
    "<p:spPr/>"
  let r = try? @slide.Slide::parse(slide_with_pic(inner))
  assert_true(r is Err(@slide.SlideError::Malformed(_)))
}
