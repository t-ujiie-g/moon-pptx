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
  let first = parse_inner_fill(input_inner)
  let serialized = fill_to_xml(first)
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
