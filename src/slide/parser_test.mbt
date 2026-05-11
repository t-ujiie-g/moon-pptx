// Slide parser tests (Phase 3c1 skeleton).

///|
fn typical_title_slide() -> FixedArray[Byte] {
  // A trimmed-down but realistic title slide: spTree with the implicit
  // root group + two placeholders, plus a body picture stand-in to verify
  // Unknown-shape preservation.
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\">" +
    "<p:cSld name=\"Title Slide\">" +
    "<p:spTree>" +
    "<p:nvGrpSpPr>" +
    "<p:cNvPr id=\"1\" name=\"\"/>" +
    "<p:cNvGrpSpPr/>" +
    "<p:nvPr/>" +
    "</p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/>" +
    "<a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    // Title placeholder shape
    "<p:sp>" +
    "<p:nvSpPr>" +
    "<p:cNvPr id=\"2\" name=\"Title 1\"/>" +
    "<p:cNvSpPr><a:spLocks noGrp=\"1\"/></p:cNvSpPr>" +
    "<p:nvPr><p:ph type=\"ctrTitle\"/></p:nvPr>" +
    "</p:nvSpPr>" +
    "<p:spPr>" +
    "<a:xfrm>" +
    "<a:off x=\"838200\" y=\"365125\"/>" +
    "<a:ext cx=\"10515600\" cy=\"1325563\"/>" +
    "</a:xfrm>" +
    "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>" +
    "</p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody>" +
    "</p:sp>" +
    // Body placeholder shape
    "<p:sp>" +
    "<p:nvSpPr>" +
    "<p:cNvPr id=\"3\" name=\"Subtitle 2\"/>" +
    "<p:cNvSpPr/>" +
    "<p:nvPr><p:ph type=\"subTitle\" idx=\"1\"/></p:nvPr>" +
    "</p:nvSpPr>" +
    "<p:spPr>" +
    "<a:xfrm>" +
    "<a:off x=\"1700213\" y=\"3886200\"/>" +
    "<a:ext cx=\"8791575\" cy=\"1752600\"/>" +
    "</a:xfrm>" +
    "</p:spPr>" +
    "</p:sp>" +
    // Picture placeholder — should land as Unknown(\"pic\")
    "<p:pic>" +
    "<p:nvPicPr><p:cNvPr id=\"4\" name=\"Pic\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId2\"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>" +
    "<p:spPr/>" +
    "</p:pic>" +
    "</p:spTree>" +
    "</p:cSld>" +
    "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>" +
    "<p:transition><p:fade/></p:transition>" +
    "<p:timing/>" +
    "</p:sld>"
  fixture_bytes(xml)
}

// --- happy path ---

///|
test "parse: slide name and shape count" {
  let slide = @slide.Slide::parse(typical_title_slide())
  assert_eq(slide.name, "Title Slide")
  assert_eq(slide.shapes.length(), 3) // two p:sp + one p:pic
}

///|
test "parse: clrMapOvr defaults to MasterMapping" {
  let slide = @slide.Slide::parse(typical_title_slide())
  assert_true(
    slide.clr_map_override is @slide_master.ClrMapOverride::MasterMapping,
  )
}

// --- AutoShape ---

///|
test "parse: AutoShape carries id/name/placeholder/transform" {
  let slide = @slide.Slide::parse(typical_title_slide())
  match slide.shapes[0] {
    AutoShape(s) => {
      assert_eq(s.id, 2)
      assert_eq(s.name, "Title 1")
      let ph = s.placeholder.unwrap()
      assert_eq(ph.ph_type, "ctrTitle")
      assert_eq(ph.idx, 0) // missing idx defaults to 0
      let xfrm = s.transform.unwrap()
      assert_eq(xfrm.offset.x, @units.Emu(838200L))
      assert_eq(xfrm.offset.y, @units.Emu(365125L))
      assert_eq(xfrm.extent.cx, @units.Emu(10515600L))
      assert_eq(xfrm.extent.cy, @units.Emu(1325563L))
    }
    _ => fail("expected AutoShape at index 0")
  }
}

///|
test "parse: AutoShape with explicit placeholder idx" {
  let slide = @slide.Slide::parse(typical_title_slide())
  match slide.shapes[1] {
    AutoShape(s) => {
      let ph = s.placeholder.unwrap()
      assert_eq(ph.ph_type, "subTitle")
      assert_eq(ph.idx, 1)
    }
    _ => fail("expected AutoShape at index 1")
  }
}

///|
test "parse: shape order is preserved" {
  let slide = @slide.Slide::parse(typical_title_slide())
  // shapes[0] = title sp, shapes[1] = subtitle sp, shapes[2] = picture
  match slide.shapes[0] {
    AutoShape(s) => assert_eq(s.id, 2)
    _ => fail("expected AutoShape at index 0")
  }
  match slide.shapes[1] {
    AutoShape(s) => assert_eq(s.id, 3)
    _ => fail("expected AutoShape at index 1")
  }
  match slide.shapes[2] {
    Picture(p) => {
      assert_eq(p.id, 4)
      assert_eq(p.embed_id, "rId2")
    }
    _ => fail("expected Picture at index 2")
  }
}

// --- override mapping ---

///|
test "parse: clrMapOvr with overrideClrMapping carries through" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/></p:spTree></p:cSld>" +
    "<p:clrMapOvr>" +
    "<a:overrideClrMapping bg1=\"dk1\" tx1=\"lt1\" bg2=\"dk2\" tx2=\"lt2\"" +
    " accent1=\"accent2\" accent2=\"accent3\" accent3=\"accent4\"" +
    " accent4=\"accent5\" accent5=\"accent6\" accent6=\"accent1\"" +
    " hlink=\"folHlink\" folHlink=\"hlink\"/>" +
    "</p:clrMapOvr>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  match slide.clr_map_override {
    Override(cm) => {
      assert_true(cm.bg1 is @units.ThemeColor::Dk1)
      assert_true(cm.accent1 is @units.ThemeColor::Accent2)
    }
    _ => fail("expected Override")
  }
}

// --- error cases ---

///|
test "parse: missing xfrm components is rejected" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"x\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/></a:xfrm></p:spPr>" + // ext missing
    "</p:sp>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let r = try? @slide.Slide::parse(fixture_bytes(xml))
  assert_true(r is Err(@slide.SlideError::Malformed(_)))
}

///|
test "parse: non-integer offset attribute is rejected" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"x\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"abc\" y=\"0\"/><a:ext cx=\"1\" cy=\"1\"/></a:xfrm></p:spPr>" +
    "</p:sp>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let r = try? @slide.Slide::parse(fixture_bytes(xml))
  assert_true(r is Err(@slide.SlideError::Malformed(_)))
}

///|
test "parse: malformed XML wraps as XmlFailure" {
  let r = try? @slide.Slide::parse(fixture_bytes("<p:sld"))
  assert_true(r is Err(@slide.SlideError::XmlFailure(_, _)))
}

///|
test "parse: shape with no placeholder leaves field None" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"5\" name=\"Rect\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm></p:spPr>" +
    "</p:sp>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  match slide.shapes[0] {
    AutoShape(s) => {
      assert_true(s.placeholder is None)
      assert_eq(s.id, 5)
      assert_eq(s.name, "Rect")
    }
    _ => fail("expected AutoShape")
  }
}
