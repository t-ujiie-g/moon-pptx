// Geometry parser tests (Phase 3c2).

///|
/// Build a minimal slide containing one auto-shape whose `<p:spPr>` body
/// is `inner_sp_pr_body` (the part between `<p:spPr>` and `</p:spPr>`).
fn slide_with_sp_pr(inner_sp_pr_body : String) -> FixedArray[Byte] {
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
    "<p:spPr>" +
    inner_sp_pr_body +
    "</p:spPr>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  fixture_bytes(xml)
}

// --- PresetShape::from_xml / to_xml ---

///|
test "PresetShape: round-trip every variant via to_xml -> from_xml" {
  // Spot-check a representative spread covering each grouping in the enum.
  let cases = [
    @slide.PresetShape::Rect,
    @slide.PresetShape::RoundRect,
    @slide.PresetShape::Triangle,
    @slide.PresetShape::Pentagon,
    @slide.PresetShape::Star8,
    @slide.PresetShape::IrregularSeal2,
    @slide.PresetShape::Ellipse,
    @slide.PresetShape::Pie,
    @slide.PresetShape::RightArrow,
    @slide.PresetShape::QuadArrow,
    @slide.PresetShape::CurvedRightArrow,
    @slide.PresetShape::WedgeRectCallout,
    @slide.PresetShape::FlowChartProcess,
    @slide.PresetShape::FlowChartOffpageConnector,
    @slide.PresetShape::ActionButtonHome,
    @slide.PresetShape::ActionButtonMovie,
    @slide.PresetShape::MathPlus,
    @slide.PresetShape::Gear9,
    @slide.PresetShape::ChartPlus,
  ]
  for c in cases {
    let xml = c.to_xml()
    let parsed = @slide.PresetShape::from_xml(xml)
    assert_true(parsed == c)
  }
}

///|
test "PresetShape::from_xml: unknown value rejected" {
  let r = try? @slide.PresetShape::from_xml("notashape")
  assert_true(r is Err(@slide.SlideError::Malformed(_)))
}

// --- Slide / parser integration ---

///|
test "parse: prstGeom rect with no adjustments" {
  let bytes = slide_with_sp_pr(
    "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom>",
  )
  let slide = @slide.Slide::parse(bytes)
  match slide.shapes[0] {
    AutoShape(s) =>
      match s.geometry.unwrap() {
        Preset(kind, adj) => {
          assert_true(kind is @slide.PresetShape::Rect)
          assert_eq(adj.length(), 0)
        }
        _ => fail("expected Preset")
      }
    _ => fail("expected AutoShape")
  }
}

///|
test "parse: prstGeom roundRect carries adjustment values in source order" {
  let body = "<a:prstGeom prst=\"roundRect\">" +
    "<a:avLst>" +
    "<a:gd name=\"adj\" fmla=\"val 16667\"/>" +
    "<a:gd name=\"adj2\" fmla=\"val 25000\"/>" +
    "</a:avLst>" +
    "</a:prstGeom>"
  let slide = @slide.Slide::parse(slide_with_sp_pr(body))
  match slide.shapes[0] {
    AutoShape(s) =>
      match s.geometry.unwrap() {
        Preset(kind, adj) => {
          assert_true(kind is @slide.PresetShape::RoundRect)
          assert_eq(adj.length(), 2)
          assert_eq(adj[0].name, "adj")
          assert_eq(adj[0].fmla, "val 16667")
          assert_eq(adj[1].name, "adj2")
          assert_eq(adj[1].fmla, "val 25000")
        }
        _ => fail("expected Preset")
      }
    _ => fail("expected AutoShape")
  }
}

///|
test "parse: custGeom records Custom" {
  let body = "<a:custGeom>" +
    "<a:pathLst><a:path w=\"100\" h=\"100\"><a:moveTo><a:pt x=\"0\" y=\"0\"/></a:moveTo></a:path></a:pathLst>" +
    "</a:custGeom>"
  let slide = @slide.Slide::parse(slide_with_sp_pr(body))
  match slide.shapes[0] {
    AutoShape(s) => assert_true(s.geometry.unwrap() is @slide.Geometry::Custom)
    _ => fail("expected AutoShape")
  }
}

///|
test "parse: missing geometry leaves field None (permissive)" {
  let bytes = slide_with_sp_pr(
    "<a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1\" cy=\"1\"/></a:xfrm>",
  )
  let slide = @slide.Slide::parse(bytes)
  match slide.shapes[0] {
    AutoShape(s) => assert_true(s.geometry is None)
    _ => fail("expected AutoShape")
  }
}

///|
test "parse: prstGeom unknown preset value rejected" {
  let body = "<a:prstGeom prst=\"unknownPreset\"><a:avLst/></a:prstGeom>"
  let r = try? @slide.Slide::parse(slide_with_sp_pr(body))
  assert_true(r is Err(@slide.SlideError::Malformed(_)))
}

///|
test "parse: xfrm + prstGeom coexist on the same shape" {
  let body = "<a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm>" +
    "<a:prstGeom prst=\"ellipse\"><a:avLst/></a:prstGeom>"
  let slide = @slide.Slide::parse(slide_with_sp_pr(body))
  match slide.shapes[0] {
    AutoShape(s) => {
      let xfrm = s.transform.unwrap()
      assert_eq(xfrm.offset.x, @units.Emu(100L))
      match s.geometry.unwrap() {
        Preset(kind, _) => assert_true(kind is @slide.PresetShape::Ellipse)
        _ => fail("expected Preset")
      }
    }
    _ => fail("expected AutoShape")
  }
}
