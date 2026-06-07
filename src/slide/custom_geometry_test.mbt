// Custom-geometry parser tests.
//
// `slide_with_sp_pr` from `geometry_test.mbt` builds the surrounding
// `<p:sp><p:spPr>…</p:spPr></p:sp>` wrapper; each test below just
// supplies the inner `<a:custGeom>` body.

///|
/// Extract the typed CustomGeometry from a slide built with
/// `slide_with_sp_pr`, panicking if anything earlier in the chain
/// doesn't match — we test the parsed body, not the surrounding plumbing.
fn extract_custom_geometry(
  body : String,
) -> @slide.CustomGeometry raise @slide.SlideError {
  let slide = @slide.Slide::parse(slide_with_sp_pr(body))
  match slide.shapes[0] {
    AutoShape(s) =>
      match s.geometry.unwrap() {
        Custom(cg) => cg
        _ => panic()
      }
    _ => panic()
  }
}

// --- PathFillMode round-trip ---

///|
test "PathFillMode: round-trip every variant via to_xml -> from_xml" {
  let cases = [
    @slide.PathFillMode::PathFillNone,
    @slide.PathFillMode::PathFillNorm,
    @slide.PathFillMode::PathFillLighten,
    @slide.PathFillMode::PathFillLightenLess,
    @slide.PathFillMode::PathFillDarken,
    @slide.PathFillMode::PathFillDarkenLess,
  ]
  for c in cases {
    let xml = c.to_xml()
    assert_true(@slide.PathFillMode::from_xml(xml) == c)
  }
}

///|
test "PathFillMode::from_xml: unknown value defaults to PathFillNorm" {
  assert_true(
    @slide.PathFillMode::from_xml("bogus") == @slide.PathFillMode::PathFillNorm,
  )
}

// --- Empty / minimal custGeom ---

///|
test "parse: empty custGeom (no children) yields all-empty AST" {
  let cg = extract_custom_geometry("<a:custGeom/>")
  assert_eq(cg.adjust_values.length(), 0)
  assert_eq(cg.guides.length(), 0)
  assert_eq(cg.connection_sites.length(), 0)
  assert_true(cg.rect is None)
  assert_eq(cg.paths.length(), 0)
  assert_eq(cg.extension.length(), 0)
}

///|
test "parse: custGeom with empty pathLst yields zero-path CustomGeometry" {
  let cg = extract_custom_geometry("<a:custGeom><a:pathLst/></a:custGeom>")
  assert_eq(cg.paths.length(), 0)
}

// --- avLst / gdLst ---

///|
test "parse: avLst and gdLst populate independently in source order" {
  let body = "<a:custGeom>" +
    "<a:avLst>" +
    "<a:gd name=\"adj1\" fmla=\"val 25000\"/>" +
    "<a:gd name=\"adj2\" fmla=\"val 50000\"/>" +
    "</a:avLst>" +
    "<a:gdLst>" +
    "<a:gd name=\"x1\" fmla=\"*/ w adj1 100000\"/>" +
    "</a:gdLst>" +
    "<a:pathLst/>" +
    "</a:custGeom>"
  let cg = extract_custom_geometry(body)
  assert_eq(cg.adjust_values.length(), 2)
  assert_eq(cg.adjust_values[0].name, "adj1")
  assert_eq(cg.adjust_values[0].fmla, "val 25000")
  assert_eq(cg.adjust_values[1].name, "adj2")
  assert_eq(cg.guides.length(), 1)
  assert_eq(cg.guides[0].name, "x1")
  assert_eq(cg.guides[0].fmla, "*/ w adj1 100000")
}

// --- Path commands ---

///|
test "parse: moveTo + lnTo + close" {
  let body = "<a:custGeom><a:pathLst>" +
    "<a:path w=\"100\" h=\"100\">" +
    "<a:moveTo><a:pt x=\"0\" y=\"0\"/></a:moveTo>" +
    "<a:lnTo><a:pt x=\"100\" y=\"100\"/></a:lnTo>" +
    "<a:close/>" +
    "</a:path>" +
    "</a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  let p = cg.paths[0]
  assert_eq(p.commands.length(), 3)
  match p.commands[0] {
    MoveTo(pt) => {
      assert_true(pt.x == Literal(@units.Emu(0L)))
      assert_true(pt.y == Literal(@units.Emu(0L)))
    }
    _ => fail("expected MoveTo")
  }
  match p.commands[1] {
    LnTo(pt) => {
      assert_true(pt.x == Literal(@units.Emu(100L)))
      assert_true(pt.y == Literal(@units.Emu(100L)))
    }
    _ => fail("expected LnTo")
  }
  match p.commands[2] {
    Close => ()
    _ => fail("expected Close")
  }
}

///|
test "parse: cubicBezTo carries three points in source order" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:cubicBezTo>" +
    "<a:pt x=\"10\" y=\"20\"/>" +
    "<a:pt x=\"30\" y=\"40\"/>" +
    "<a:pt x=\"50\" y=\"60\"/>" +
    "</a:cubicBezTo>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    CubicBezTo(c1, c2, end) => {
      assert_true(c1.x == Literal(@units.Emu(10L)))
      assert_true(c2.x == Literal(@units.Emu(30L)))
      assert_true(end.x == Literal(@units.Emu(50L)))
    }
    _ => fail("expected CubicBezTo")
  }
}

///|
test "parse: quadBezTo carries two points" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:quadBezTo>" +
    "<a:pt x=\"1\" y=\"2\"/><a:pt x=\"3\" y=\"4\"/>" +
    "</a:quadBezTo>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    QuadBezTo(c, end) => {
      assert_true(c.x == Literal(@units.Emu(1L)))
      assert_true(end.y == Literal(@units.Emu(4L)))
    }
    _ => fail("expected QuadBezTo")
  }
}

///|
test "parse: arcTo carries wR/hR/stAng/swAng" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:arcTo wR=\"500\" hR=\"600\" stAng=\"0\" swAng=\"5400000\"/>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    ArcTo(w_r, h_r, st, sw) => {
      assert_true(w_r == Literal(@units.Emu(500L)))
      assert_true(h_r == Literal(@units.Emu(600L)))
      assert_true(st == AdjAngle::Literal(@units.Angle::from_ooxml(0)))
      assert_true(sw == AdjAngle::Literal(@units.Angle::from_ooxml(5400000)))
    }
    _ => fail("expected ArcTo")
  }
}

///|
test "parse: cubicBezTo with wrong point count raises Malformed" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:cubicBezTo><a:pt x=\"0\" y=\"0\"/></a:cubicBezTo>" +
    "</a:path></a:pathLst></a:custGeom>"
  try @slide.Slide::parse(slide_with_sp_pr(body)) catch {
    @slide.SlideError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

// --- AdjCoordinate / AdjAngle disambiguation ---

///|
test "parse: guide-name in coordinate becomes GuideRef" {
  let body = "<a:custGeom><a:pathLst><a:path w=\"21600\" h=\"21600\">" +
    "<a:moveTo><a:pt x=\"adj1\" y=\"0\"/></a:moveTo>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    MoveTo(pt) => {
      assert_true(pt.x == GuideRef("adj1"))
      assert_true(pt.y == Literal(@units.Emu(0L)))
    }
    _ => fail("expected MoveTo")
  }
}

///|
test "parse: guide-name in arcTo angle becomes AdjAngle::GuideRef" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:arcTo wR=\"100\" hR=\"100\" stAng=\"startAng\" swAng=\"swA\"/>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    ArcTo(_, _, st, sw) => {
      assert_true(st == AdjAngle::GuideRef("startAng"))
      assert_true(sw == AdjAngle::GuideRef("swA"))
    }
    _ => fail("expected ArcTo")
  }
}

///|
test "parse: negative coordinate parses as Literal Emu" {
  let body = "<a:custGeom><a:pathLst><a:path>" +
    "<a:moveTo><a:pt x=\"-100\" y=\"-200\"/></a:moveTo>" +
    "</a:path></a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  match cg.paths[0].commands[0] {
    MoveTo(pt) => {
      assert_true(pt.x == Literal(@units.Emu(-100L)))
      assert_true(pt.y == Literal(@units.Emu(-200L)))
    }
    _ => fail("expected MoveTo")
  }
}

// --- Path attribute defaults ---

///|
test "parse: path without w/h/fill/stroke/extrusionOk uses defaults" {
  let cg = extract_custom_geometry(
    "<a:custGeom><a:pathLst><a:path/></a:pathLst></a:custGeom>",
  )
  let p = cg.paths[0]
  assert_eq(p.w, @units.Emu(0L))
  assert_eq(p.h, @units.Emu(0L))
  assert_true(p.fill == @slide.PathFillMode::PathFillNorm)
  assert_eq(p.stroke, true)
  assert_eq(p.extrusion_ok, true)
}

///|
test "parse: path explicit fill / stroke=0 / extrusionOk=0" {
  let body = "<a:custGeom><a:pathLst>" +
    "<a:path w=\"500\" h=\"800\" fill=\"lighten\" stroke=\"0\" extrusionOk=\"0\"/>" +
    "</a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  let p = cg.paths[0]
  assert_eq(p.w, @units.Emu(500L))
  assert_eq(p.h, @units.Emu(800L))
  assert_true(p.fill == @slide.PathFillMode::PathFillLighten)
  assert_eq(p.stroke, false)
  assert_eq(p.extrusion_ok, false)
}

// --- cxnLst / rect ---

///|
test "parse: cxnLst with two connection sites" {
  let body = "<a:custGeom><a:cxnLst>" +
    "<a:cxn ang=\"0\"><a:pos x=\"0\" y=\"0\"/></a:cxn>" +
    "<a:cxn ang=\"5400000\"><a:pos x=\"100\" y=\"200\"/></a:cxn>" +
    "</a:cxnLst><a:pathLst/></a:custGeom>"
  let cg = extract_custom_geometry(body)
  assert_eq(cg.connection_sites.length(), 2)
  let s0 = cg.connection_sites[0]
  assert_true(s0.ang == AdjAngle::Literal(@units.Angle::from_ooxml(0)))
  assert_true(s0.pos.x == Literal(@units.Emu(0L)))
  let s1 = cg.connection_sites[1]
  assert_true(s1.pos.y == Literal(@units.Emu(200L)))
}

///|
test "parse: cxn without <a:pos> raises Malformed" {
  let body = "<a:custGeom><a:cxnLst>" +
    "<a:cxn ang=\"0\"/>" +
    "</a:cxnLst><a:pathLst/></a:custGeom>"
  try @slide.Slide::parse(slide_with_sp_pr(body)) catch {
    @slide.SlideError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "parse: rect with literal corners + guide refs" {
  let body = "<a:custGeom>" +
    "<a:rect l=\"0\" t=\"0\" r=\"w\" b=\"h\"/>" +
    "<a:pathLst/></a:custGeom>"
  let cg = extract_custom_geometry(body)
  let r = cg.rect.unwrap()
  assert_true(r.l == Literal(@units.Emu(0L)))
  assert_true(r.t == Literal(@units.Emu(0L)))
  assert_true(r.r == GuideRef("w"))
  assert_true(r.b == GuideRef("h"))
}

// --- Lossless preservation ---

///|
test "parse: <a:ahLst> is preserved on CustomGeometry.extension" {
  let body = "<a:custGeom>" +
    "<a:ahLst><a:ahXY gdRefX=\"adj1\" minX=\"0\" maxX=\"100\"><a:pos x=\"0\" y=\"0\"/></a:ahXY></a:ahLst>" +
    "<a:pathLst/></a:custGeom>"
  let cg = extract_custom_geometry(body)
  assert_eq(cg.extension.length(), 1)
  assert_eq(cg.extension[0].name.local_name, "ahLst")
}

///|
test "parse: foreign-namespace child of custGeom is preserved" {
  let body = "<a:custGeom xmlns:x=\"urn:x\">" +
    "<x:future foo=\"bar\"/>" +
    "<a:pathLst/></a:custGeom>"
  let cg = extract_custom_geometry(body)
  assert_eq(cg.extension.length(), 1)
  assert_eq(cg.extension[0].name.local_name, "future")
}

///|
test "parse: unknown child of <a:path> is preserved on Path.extension" {
  let body = "<a:custGeom><a:pathLst>" +
    "<a:path><a:futureCmd foo=\"x\"/></a:path>" +
    "</a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  let p = cg.paths[0]
  assert_eq(p.commands.length(), 0)
  assert_eq(p.extension.length(), 1)
  assert_eq(p.extension[0].name.local_name, "futureCmd")
}

// --- Multiple paths ---

///|
test "parse: multiple <a:path> children land in source order" {
  let body = "<a:custGeom><a:pathLst>" +
    "<a:path w=\"100\" h=\"100\"><a:moveTo><a:pt x=\"0\" y=\"0\"/></a:moveTo></a:path>" +
    "<a:path w=\"200\" h=\"200\"><a:moveTo><a:pt x=\"10\" y=\"10\"/></a:moveTo></a:path>" +
    "</a:pathLst></a:custGeom>"
  let cg = extract_custom_geometry(body)
  assert_eq(cg.paths.length(), 2)
  assert_eq(cg.paths[0].w, @units.Emu(100L))
  assert_eq(cg.paths[1].w, @units.Emu(200L))
}
