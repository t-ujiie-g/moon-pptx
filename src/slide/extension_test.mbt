// Lossless preservation tests (ADR-004) for slide-level + shape-level
// `extension` arrays. The fixtures intentionally pack in elements the
// typed parsers do *not* model (transition / timing / style / extLst /
// graphicFrame / foreign-namespace nodes) and assert that every one
// survives the parse.

///|
/// Find the captured `<p:transition>` (or any other element by local name)
/// inside a `Slide.extension` array. Returns the first match, or `None`.
fn find_ext(slide : @slide.Slide, local_name : String) -> @xml.XmlElement? {
  for el in slide.extension {
    if el.name.local_name == local_name {
      return Some(el)
    }
  }
  None
}

// --- Slide.extension captures the top-level non-shape children. ---

///|
test "ADR-004: slide-level transition and timing survive parse" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<p:transition spd=\"med\"><p:fade/></p:transition>" +
    "<p:timing/>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  // transition + timing + nvGrpSpPr + grpSpPr = 4 captured nodes.
  // (Implicit-root-group metadata moves to the slide-level extension too.)
  let transition = find_ext(slide, "transition")
  assert_true(transition is Some(_))
  let t = transition.unwrap()
  assert_eq(t.name.uri, pml_ns)
  // Source-order attribute and child are preserved.
  assert_eq(t.attributes.length(), 1)
  assert_eq(t.attributes[0].0.local_name, "spd")
  assert_eq(t.attributes[0].1, "med")
  assert_eq(t.children.length(), 1)
  match t.children[0] {
    Element(fade) => assert_eq(fade.name.local_name, "fade")
    _ => fail("expected <p:fade/> child")
  }
  let timing = find_ext(slide, "timing")
  assert_true(timing is Some(_))
}

///|
test "ADR-004: <p:cSld><p:bg> survives as slide extension" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld>" +
    "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>" +
    "<p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree>" +
    "</p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  let bg = find_ext(slide, "bg")
  assert_true(bg is Some(_))
  let b = bg.unwrap()
  assert_eq(b.children.length(), 1)
  match b.children[0] {
    Element(bg_ref) => {
      assert_eq(bg_ref.name.local_name, "bgRef")
      assert_eq(bg_ref.attributes[0].0.local_name, "idx")
      assert_eq(bg_ref.attributes[0].1, "1001")
    }
    _ => fail("expected <p:bgRef> child")
  }
}

///|
test "ADR-004: foreign-namespace <p:sld> child is preserved" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:x=\"http://example.org/ext\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "</p:spTree></p:cSld>" +
    "<x:custom payload=\"42\"/>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  let custom = find_ext(slide, "custom")
  assert_true(custom is Some(_))
  let c = custom.unwrap()
  assert_eq(c.name.uri, "http://example.org/ext")
  assert_eq(c.attributes[0].0.local_name, "payload")
  assert_eq(c.attributes[0].1, "42")
}

// --- Shape::GraphicFrame chart content lifts to ChartContent(rid). ---

///|
test "chart graphicFrame lifts to GraphicFrame(ChartContent)" {
  // Chart embedded in a graphicFrame. The chart-uri case lifts
  // alongside the table-uri case: the slide-side body is just
  // `<c:chart r:id="…"/>`, so we lift the rel id to `ChartContent(rid)`
  // and leave the actual chart data (in a separate `chartN.xml` part)
  // to `@presentation.Presentation::charts()`.
  let chart_uri = "http://schemas.openxmlformats.org/drawingml/2006/chart"
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:r=\"" +
    off_rel_ns +
    "\" xmlns:c=\"" +
    chart_uri +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:graphicFrame>" +
    "<p:nvGraphicFramePr><p:cNvPr id=\"5\" name=\"Chart 1\"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>" +
    "<p:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"200\"/></p:xfrm>" +
    "<a:graphic><a:graphicData uri=\"" +
    chart_uri +
    "\"><c:chart r:id=\"rId7\"/></a:graphicData></a:graphic>" +
    "</p:graphicFrame>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  assert_eq(slide.shapes.length(), 1)
  match slide.shapes[0] {
    GraphicFrame(gf) => {
      assert_eq(gf.id, 5)
      assert_eq(gf.name, "Chart 1")
      match gf.content {
        ChartContent(rid) => assert_eq(rid, "rId7")
        _ => fail("expected ChartContent for chart uri")
      }
    }
    _ => fail("expected GraphicFrame shape")
  }
}

// --- AutoShape.extension captures sibling elements like <p:style>. ---

///|
test "ADR-004: AutoShape preserves <p:style> in extension" {
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
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm></p:spPr>" +
    "<p:style><a:lnRef idx=\"2\"><a:schemeClr val=\"accent1\"/></a:lnRef></p:style>" +
    "</p:sp>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  match slide.shapes[0] {
    AutoShape(s) => {
      // Find <p:style> in the extension. The parser also captures
      // <p:cNvPr>, <p:cNvSpPr> etc. from inside <p:nvSpPr>, so there
      // are several entries — assert on the one we care about by name.
      let style = find_local(s.extension, "style").unwrap()
      assert_eq(style.children.length(), 1)
      match style.children[0] {
        Element(ln_ref) => assert_eq(ln_ref.name.local_name, "lnRef")
        _ => fail("expected <a:lnRef> child of <p:style>")
      }
    }
    _ => fail("expected AutoShape")
  }
}

///|
/// Locate an element by local name inside an `extension` array.
fn find_local(
  extension : Array[@xml.XmlElement],
  local_name : String,
) -> @xml.XmlElement? {
  for el in extension {
    if el.name.local_name == local_name {
      return Some(el)
    }
  }
  None
}

// --- Picture.extension and Connector.extension behave the same way. ---

///|
test "ADR-004: Picture preserves <p:extLst> in extension" {
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
    "<p:nvPicPr><p:cNvPr id=\"4\" name=\"P\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId2\"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>" +
    "<p:spPr/>" +
    "<p:extLst><p:ext uri=\"{x}\"><p:custom/></p:ext></p:extLst>" +
    "</p:pic>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  match slide.shapes[0] {
    Picture(p) => assert_true(find_local(p.extension, "extLst") is Some(_))
    _ => fail("expected Picture")
  }
}

///|
test "ADR-004: Connector preserves <p:style> in extension" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:cxnSp>" +
    "<p:nvCxnSpPr><p:cNvPr id=\"6\" name=\"C\"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>" +
    "<p:spPr/>" +
    "<p:style><a:lnRef idx=\"1\"/></p:style>" +
    "</p:cxnSp>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  match slide.shapes[0] {
    Connector(c) => assert_true(find_local(c.extension, "style") is Some(_))
    _ => fail("expected Connector")
  }
}

///|
test "ADR-004: GroupShape captures foreign-namespace siblings" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<p:sld xmlns:p=\"" +
    pml_ns +
    "\" xmlns:a=\"" +
    dml_ns +
    "\" xmlns:x=\"http://example.org/ext\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>" +
    "<p:grpSp>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"10\" name=\"G\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr/>" +
    "<x:special tag=\"1\"/>" +
    "</p:grpSp>" +
    "</p:spTree></p:cSld>" +
    "</p:sld>"
  let slide = @slide.Slide::parse(fixture_bytes(xml))
  match slide.shapes[0] {
    Group(g) => {
      let special = find_local(g.extension, "special").unwrap()
      assert_eq(special.name.uri, "http://example.org/ext")
    }
    _ => fail("expected Group")
  }
}
