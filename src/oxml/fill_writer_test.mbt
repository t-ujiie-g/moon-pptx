// @oxml.write_fill round-trip tests.
//
// `parse_inner_fill` from `fill_test.mbt` is shared at the test-
// package level so we re-use it directly rather than redefining.

///|
fn fill_to_xml(f : @oxml.Fill) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  // Wrap in a synthetic root so the resulting XML re-parses through
  // `parse_inner_fill` (which expects a `<wrapper>`).  We emit the
  // namespace declarations on the root.
  w.start_element(@xml.QName::unqualified("wrapper"))
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  @oxml.write_fill(w, ctx, f)
  w.end_element()
  w.to_string()
}

///|
fn roundtrip_fill(input_inner : String) -> @oxml.Fill raise {
  reparse_fill(parse_inner_fill(input_inner))
}

///|
/// Serialize a fill value and parse it back — the write-side inverse
/// check, also usable on builder-constructed fills.
fn reparse_fill(f : @oxml.Fill) -> @oxml.Fill raise {
  let serialized = fill_to_xml(f)
  // The serialised string is already a full document with one fill
  // inside, so extract the fill body the same way.
  let r = @xml.XmlReader::new(serialized)
  let _ = r.next() catch {
    _ => raise @oxml.FillError::MalformedFill("rt wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise @oxml.FillError::MalformedFill("rt inner failed")
    }
    match ev {
      Some(StartElement(name, attrs)) => return @oxml.parse_fill(r, name, attrs)
      Some(EndElement(_)) =>
        raise @oxml.FillError::MalformedFill("empty rt wrapper")
      Some(_) => ()
      None => raise @oxml.FillError::MalformedFill("unexpected rt end")
    }
  }
  raise @oxml.FillError::MalformedFill("unreachable")
}

///|
test "write_fill: noFill round-trips" {
  let f0 = parse_inner_fill("<a:noFill/>")
  let f1 = roundtrip_fill("<a:noFill/>")
  assert_true(f0 == f1)
}

///|
test "write_fill: solidFill round-trips" {
  let xml = "<a:solidFill><a:srgbClr val=\"FF0000\"/></a:solidFill>"
  let f0 = parse_inner_fill(xml)
  let f1 = roundtrip_fill(xml)
  assert_true(f0 == f1)
}

///|
test "write_fill: gradFill with two stops + linear direction round-trips" {
  let xml = "<a:gradFill rotWithShape=\"1\">" +
    "<a:gsLst>" +
    "<a:gs pos=\"0\"><a:srgbClr val=\"FFFFFF\"/></a:gs>" +
    "<a:gs pos=\"100000\"><a:srgbClr val=\"000000\"/></a:gs>" +
    "</a:gsLst>" +
    "<a:lin ang=\"5400000\" scaled=\"0\"/>" +
    "</a:gradFill>"
  let f0 = parse_inner_fill(xml)
  let f1 = roundtrip_fill(xml)
  assert_true(f0 == f1)
}

///|
test "write_fill: gradFill with path-rect direction round-trips" {
  let xml = "<a:gradFill>" +
    "<a:gsLst>" +
    "<a:gs pos=\"0\"><a:srgbClr val=\"FFFFFF\"/></a:gs>" +
    "<a:gs pos=\"100000\"><a:srgbClr val=\"000000\"/></a:gs>" +
    "</a:gsLst>" +
    "<a:path path=\"rect\"/>" +
    "</a:gradFill>"
  let f0 = parse_inner_fill(xml)
  let f1 = roundtrip_fill(xml)
  assert_true(f0 == f1)
}

///|
test "write_fill: pattFill with preset round-trips" {
  let xml = "<a:pattFill prst=\"pct50\">" +
    "<a:fgClr><a:srgbClr val=\"112233\"/></a:fgClr>" +
    "<a:bgClr><a:srgbClr val=\"AABBCC\"/></a:bgClr>" +
    "</a:pattFill>"
  let f0 = parse_inner_fill(xml)
  let f1 = roundtrip_fill(xml)
  assert_true(f0 == f1)
}

///|
test "write_fill: blipFill with stretch round-trips" {
  let xml = "<a:blipFill>" +
    "<a:blip r:embed=\"rId1\"/>" +
    "<a:stretch><a:fillRect/></a:stretch>" +
    "</a:blipFill>"
  let f0 = parse_inner_fill(xml)
  let f1 = roundtrip_fill(xml)
  assert_true(f0 == f1)
}

///|
test "write_fill: blipFill with srcRect crop round-trips" {
  let xml = "<a:blipFill>" +
    "<a:blip r:embed=\"rId1\"/>" +
    "<a:srcRect l=\"5000\" t=\"5000\" r=\"5000\" b=\"5000\"/>" +
    "<a:stretch/>" +
    "</a:blipFill>"
  let f0 = parse_inner_fill(xml)
  let f1 = roundtrip_fill(xml)
  assert_true(f0 == f1)
}

///|
test "write_fill: blipFill with tile round-trips" {
  let xml = "<a:blipFill>" +
    "<a:blip r:embed=\"rId1\"/>" +
    "<a:tile tx=\"0\" ty=\"0\" sx=\"100000\" sy=\"100000\" flip=\"none\" algn=\"tl\"/>" +
    "</a:blipFill>"
  let f0 = parse_inner_fill(xml)
  let f1 = roundtrip_fill(xml)
  assert_true(f0 == f1)
}

///|
test "write_fill: blipFill preserves <a:blip> children via extension" {
  // The `<a:duotone>` child of `<a:blip>` is not modeled; the parser
  // captures the entire <a:blip> subtree into BlipFill.extension and
  // we re-emit it verbatim.
  let xml = "<a:blipFill>" +
    "<a:blip r:embed=\"rId1\">" +
    "<a:duotone>" +
    "<a:srgbClr val=\"000000\"/>" +
    "<a:srgbClr val=\"FFFFFF\"/>" +
    "</a:duotone>" +
    "</a:blip>" +
    "<a:stretch><a:fillRect/></a:stretch>" +
    "</a:blipFill>"
  let f0 = parse_inner_fill(xml)
  let f1 = roundtrip_fill(xml)
  assert_true(f0 == f1)
}

// --- convenience constructors ---

///|
test "Fill::solid builds SolidFill(srgb)" {
  let f = @oxml.Fill::solid(@units.RgbColor::new(0x11, 0x22, 0x33))
  assert_true(
    f == SolidFill(@oxml.Color::srgb(@units.RgbColor::new(0x11, 0x22, 0x33))),
  )
}

///|
test "Fill::linear_gradient: endpoints at 0/100, via evenly spaced" {
  let red = @units.RgbColor::new(0xFF, 0x00, 0x00)
  let green = @units.RgbColor::new(0x00, 0xFF, 0x00)
  let blue = @units.RgbColor::new(0x00, 0x00, 0xFF)
  match @oxml.Fill::linear_gradient(red, blue, via=[green]) {
    GradientFill(g) => {
      assert_eq(g.stops.length(), 3)
      assert_true(g.stops[0].position == @units.Percentage(0.0))
      assert_true(g.stops[1].position == @units.Percentage(50.0))
      assert_true(g.stops[2].position == @units.Percentage(100.0))
      assert_true(g.stops[0].color == @oxml.Color::srgb(red))
      assert_true(g.stops[2].color == @oxml.Color::srgb(blue))
      // Default direction: top -> bottom, scaled (what PowerPoint emits).
      assert_true(g.direction == Linear(@units.Angle(90.0), true))
    }
    _ => fail("expected GradientFill")
  }
}

///|
test "Fill::linear_gradient: custom angle + write -> parse round-trip" {
  let f = @oxml.Fill::linear_gradient(
    @units.RgbColor::new(0x10, 0x20, 0x30),
    @units.RgbColor::new(0xA0, 0xB0, 0xC0),
    angle=@units.Angle(45.0),
  )
  match f {
    GradientFill(g) =>
      assert_true(g.direction == Linear(@units.Angle(45.0), true))
    _ => fail("expected GradientFill")
  }
  assert_true(reparse_fill(f) == f)
}

///|
test "Fill::pattern: fields set + write -> parse round-trip" {
  let f = @oxml.Fill::pattern(
    "pct50",
    fg=@units.RgbColor::new(0xFF, 0xFF, 0xFF),
    bg=@units.RgbColor::new(0x00, 0x00, 0x00),
  )
  match f {
    PatternFill(p) => {
      assert_eq(p.preset, "pct50")
      assert_true(
        p.fg == @oxml.Color::srgb(@units.RgbColor::new(0xFF, 0xFF, 0xFF)),
      )
      assert_true(
        p.bg == @oxml.Color::srgb(@units.RgbColor::new(0x00, 0x00, 0x00)),
      )
    }
    _ => fail("expected PatternFill")
  }
  assert_true(reparse_fill(f) == f)
}
