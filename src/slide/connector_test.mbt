// Connector parser tests (Phase 3c4).

///|
fn slide_with_cxn(inner : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:cxnSp>" +
    inner +
    "</p:cxnSp>" +
    "</p:spTree></p:cSld></p:sld>"
  fixture_bytes(xml)
}

// --- happy path ---

///|
test "parse: bound connector with both stCxn and endCxn" {
  let inner = "<p:nvCxnSpPr>" +
    "<p:cNvPr id=\"6\" name=\"Straight Connector 5\"/>" +
    "<p:cNvCxnSpPr>" +
    "<a:stCxn id=\"2\" idx=\"3\"/>" +
    "<a:endCxn id=\"3\" idx=\"1\"/>" +
    "</p:cNvCxnSpPr>" +
    "<p:nvPr/>" +
    "</p:nvCxnSpPr>" +
    "<p:spPr>" +
    "<a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm>" +
    "<a:prstGeom prst=\"straightConnector1\"><a:avLst/></a:prstGeom>" +
    "</p:spPr>"
  let slide = @slide.Slide::parse(slide_with_cxn(inner))
  match slide.shapes[0] {
    Connector(c) => {
      assert_eq(c.id, 6)
      assert_eq(c.name, "Straight Connector 5")
      let st = c.start.unwrap()
      assert_eq(st.shape_id, 2)
      assert_eq(st.idx, 3)
      let en = c.end.unwrap()
      assert_eq(en.shape_id, 3)
      assert_eq(en.idx, 1)
      match c.geometry.unwrap() {
        Preset(kind, _) =>
          assert_true(kind is @slide.PresetShape::StraightConnector1)
        _ => fail("expected Preset")
      }
    }
    _ => fail("expected Connector")
  }
}

///|
test "parse: free-floating connector (no stCxn / endCxn)" {
  let inner = "<p:nvCxnSpPr>" +
    "<p:cNvPr id=\"7\" name=\"Free\"/>" +
    "<p:cNvCxnSpPr/>" +
    "<p:nvPr/>" +
    "</p:nvCxnSpPr>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_cxn(inner))
  match slide.shapes[0] {
    Connector(c) => {
      assert_true(c.start is None)
      assert_true(c.end is None)
      assert_eq(c.id, 7)
    }
    _ => fail("expected Connector")
  }
}

///|
test "parse: connector with only stCxn" {
  let inner = "<p:nvCxnSpPr>" +
    "<p:cNvPr id=\"8\" name=\"Half\"/>" +
    "<p:cNvCxnSpPr><a:stCxn id=\"2\" idx=\"0\"/></p:cNvCxnSpPr>" +
    "<p:nvPr/>" +
    "</p:nvCxnSpPr>" +
    "<p:spPr/>"
  let slide = @slide.Slide::parse(slide_with_cxn(inner))
  match slide.shapes[0] {
    Connector(c) => {
      assert_true(!(c.start is None))
      assert_true(c.end is None)
    }
    _ => fail("expected Connector")
  }
}
