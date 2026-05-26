// Slide writer round-trip tests.

///|
fn roundtrip_slide(bytes : FixedArray[Byte]) -> @slide.Slide raise {
  let first = @slide.Slide::parse(bytes)
  @slide.Slide::parse(first.serialize())
}

// --- Minimal title slide (re-uses the fixture from parser_test.mbt) ---

///|
test "Slide::serialize: round-trips the typical title slide" {
  let s0 = @slide.Slide::parse(typical_title_slide())
  let s1 = roundtrip_slide(typical_title_slide())
  // Identify which field differs to make failure self-diagnosing.
  assert_eq(s0.name, s1.name)
  assert_eq(s0.shapes.length(), s1.shapes.length())
  assert_eq(s0.extension.length(), s1.extension.length())
  // Compare each shape (where a structural diff surfaces fastest).
  for i, sh in s0.shapes {
    assert_true(sh == s1.shapes[i])
  }
  // Compare extension by local-name + attribute count, since cross-
  // section ordering inside the array isn't part of the contract.
  for i, ex in s0.extension {
    assert_eq(ex.name.local_name, s1.extension[i].name.local_name)
  }
  assert_true(s0 == s1)
}

///|
test "Slide::serialize: shape count + auto-shape metadata survive" {
  let s1 = roundtrip_slide(typical_title_slide())
  assert_eq(s1.shapes.length(), 3)
  match s1.shapes[0] {
    AutoShape(sp) => {
      assert_eq(sp.id, 2)
      assert_eq(sp.name, "Title 1")
      assert_eq(sp.placeholder.unwrap().ph_type, "ctrTitle")
    }
    _ => fail("expected AutoShape at [0]")
  }
}

///|
test "Slide::serialize: clrMapOvr (master mapping) round-trips" {
  let s1 = roundtrip_slide(typical_title_slide())
  assert_true(
    s1.clr_map_override is @slide_master.ClrMapOverride::MasterMapping,
  )
}

///|
test "Slide::serialize: slide-level extension (transition / timing) preserved" {
  let s1 = roundtrip_slide(typical_title_slide())
  let names = s1.extension.map(fn(e) { e.name.local_name })
  // The fixture has <p:transition> + <p:timing> at sld level, plus the
  // root-group metadata (<p:nvGrpSpPr> + <p:grpSpPr>) inside spTree.
  assert_true(names.contains("transition"))
  assert_true(names.contains("timing"))
  assert_true(names.contains("nvGrpSpPr"))
  assert_true(names.contains("grpSpPr"))
}

// --- Slide with picture ---

///|
test "Slide::serialize: picture shape round-trips" {
  let body = "<p:pic>" +
    "<p:nvPicPr><p:cNvPr id=\"5\" name=\"Pic\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId2\"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm>" +
    "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr>" +
    "</p:pic>"
  let xml = wrap_slide(body)
  let s0 = @slide.Slide::parse(fixture_bytes(xml))
  let s1 = roundtrip_slide(fixture_bytes(xml))
  assert_true(s0 == s1)
}

///|
test "Slide::serialize: connector round-trips" {
  let body = "<p:cxnSp>" +
    "<p:nvCxnSpPr>" +
    "<p:cNvPr id=\"7\" name=\"Conn\"/>" +
    "<p:cNvCxnSpPr><a:stCxn id=\"2\" idx=\"0\"/><a:endCxn id=\"3\" idx=\"1\"/></p:cNvCxnSpPr>" +
    "<p:nvPr/>" +
    "</p:nvCxnSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"50\" cy=\"50\"/></a:xfrm>" +
    "<a:prstGeom prst=\"straightConnector1\"><a:avLst/></a:prstGeom></p:spPr>" +
    "</p:cxnSp>"
  let xml = wrap_slide(body)
  let s0 = @slide.Slide::parse(fixture_bytes(xml))
  let s1 = roundtrip_slide(fixture_bytes(xml))
  assert_true(s0 == s1)
}

///|
test "Slide::serialize: group shape with one child round-trips" {
  let body = "<p:grpSp>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"10\" name=\"Group\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr>" +
    "<a:xfrm>" +
    "<a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/>" +
    "<a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"100\" cy=\"100\"/>" +
    "</a:xfrm>" +
    "</p:grpSpPr>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"11\" name=\"Child\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"5\" y=\"5\"/><a:ext cx=\"20\" cy=\"20\"/></a:xfrm>" +
    "<a:prstGeom prst=\"ellipse\"><a:avLst/></a:prstGeom></p:spPr>" +
    "</p:sp>" +
    "</p:grpSp>"
  let xml = wrap_slide(body)
  let s0 = @slide.Slide::parse(fixture_bytes(xml))
  let s1 = roundtrip_slide(fixture_bytes(xml))
  assert_true(s0 == s1)
}

///|
test "Slide::serialize: AutoShape with custGeom round-trips" {
  let body = "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"3\" name=\"Custom\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr>" +
    "<a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm>" +
    "<a:custGeom>" +
    "<a:avLst/>" +
    "<a:gdLst/>" +
    "<a:rect l=\"0\" t=\"0\" r=\"100\" b=\"100\"/>" +
    "<a:pathLst>" +
    "<a:path w=\"100\" h=\"100\">" +
    "<a:moveTo><a:pt x=\"50\" y=\"0\"/></a:moveTo>" +
    "<a:lnTo><a:pt x=\"100\" y=\"100\"/></a:lnTo>" +
    "<a:lnTo><a:pt x=\"0\" y=\"100\"/></a:lnTo>" +
    "<a:close/>" +
    "</a:path>" +
    "</a:pathLst>" +
    "</a:custGeom>" +
    "</p:spPr>" +
    "</p:sp>"
  let xml = wrap_slide(body)
  // Two re-serialise cycles: the first cycle injects PowerPoint-Online-
  // expected `<a:ahLst/>` (the fixture omits it) so equality only holds
  // from the second cycle onward.
  let s1 = roundtrip_slide(fixture_bytes(xml))
  let s2 = roundtrip_slide(s1.serialize())
  assert_true(s1 == s2)
}

///|
test "Slide::serialize: AutoShape with text body round-trips" {
  let body = "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"2\" name=\"Title 1\"/><p:cNvSpPr/><p:nvPr><p:ph type=\"ctrTitle\"/></p:nvPr></p:nvSpPr>" +
    "<p:spPr>" +
    "<a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm>" +
    "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>" +
    "</p:spPr>" +
    "<p:txBody>" +
    "<a:bodyPr/><a:lstStyle/>" +
    "<a:p>" +
    "<a:pPr lvl=\"0\" algn=\"ctr\"/>" +
    "<a:r>" +
    "<a:rPr lang=\"en-US\" sz=\"2400\" b=\"1\" i=\"1\">" +
    "<a:solidFill><a:srgbClr val=\"FFFFFF\"/></a:solidFill>" +
    "</a:rPr>" +
    "<a:t>Bold italic title.</a:t>" +
    "</a:r>" +
    "</a:p>" +
    "</p:txBody>" +
    "</p:sp>"
  let xml = wrap_slide(body)
  let s0 = @slide.Slide::parse(fixture_bytes(xml))
  let s1 = roundtrip_slide(fixture_bytes(xml))
  assert_true(s0 == s1)
}

///|
test "Slide::serialize: empty slide (no shapes) round-trips" {
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
    "</p:spTree></p:cSld></p:sld>"
  let s0 = @slide.Slide::parse(fixture_bytes(xml))
  let s1 = roundtrip_slide(fixture_bytes(xml))
  assert_true(s0 == s1)
}

///|
/// Wrap a shape (or shape sequence) inside a complete `<p:sld>` with the
/// required namespace bindings and root-group metadata.
fn wrap_slide(inner_shapes : String) -> String {
  "<?xml version=\"1.0\"?>" +
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
  inner_shapes +
  "</p:spTree></p:cSld></p:sld>"
}
