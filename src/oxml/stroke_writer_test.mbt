// @oxml.write_stroke round-trip tests.

///|
fn stroke_to_xml(s : @oxml.Stroke) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  w.start_element(@xml.QName::unqualified("wrapper"))
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  @oxml.write_stroke(w, ctx, s)
  w.end_element()
  w.to_string()
}

///|
fn roundtrip_stroke(input_inner : String) -> @oxml.Stroke raise {
  let first = parse_stroke_inner(input_inner)
  let serialized = stroke_to_xml(first)
  let r = @xml.XmlReader::new(serialized)
  let _ = r.next() catch {
    _ => raise @oxml.StrokeError::MalformedStroke("rt wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise @oxml.StrokeError::MalformedStroke("rt inner failed")
    }
    match ev {
      Some(StartElement(_, attrs)) => return @oxml.parse_stroke(r, attrs)
      Some(EndElement(_)) =>
        raise @oxml.StrokeError::MalformedStroke("empty rt wrapper")
      Some(_) => ()
      None => raise @oxml.StrokeError::MalformedStroke("unexpected rt end")
    }
  }
  raise @oxml.StrokeError::MalformedStroke("unreachable")
}

///|
test "write_stroke: empty <a:ln> round-trips" {
  let xml = "<a:ln/>"
  let s0 = parse_stroke_inner(xml)
  let s1 = roundtrip_stroke(xml)
  assert_true(s0 == s1)
}

///|
test "write_stroke: width + cap + cmpd + algn round-trips" {
  let xml = "<a:ln w=\"12700\" cap=\"flat\" cmpd=\"sng\" algn=\"ctr\"/>"
  let s0 = parse_stroke_inner(xml)
  let s1 = roundtrip_stroke(xml)
  assert_true(s0 == s1)
}

///|
test "write_stroke: solidFill child round-trips" {
  let xml = "<a:ln w=\"6350\"><a:solidFill><a:srgbClr val=\"000000\"/></a:solidFill></a:ln>"
  let s0 = parse_stroke_inner(xml)
  let s1 = roundtrip_stroke(xml)
  assert_true(s0 == s1)
}

///|
test "write_stroke: prstDash round-trips" {
  let xml = "<a:ln><a:prstDash val=\"dash\"/></a:ln>"
  let s0 = parse_stroke_inner(xml)
  let s1 = roundtrip_stroke(xml)
  assert_true(s0 == s1)
}

///|
test "write_stroke: round/bevel/miter joins round-trip" {
  let cases = [
    "<a:ln><a:round/></a:ln>", "<a:ln><a:bevel/></a:ln>", "<a:ln><a:miter lim=\"400000\"/></a:ln>",
    "<a:ln><a:miter/></a:ln>", // miter with no limit
  ]
  for xml in cases {
    let s0 = parse_stroke_inner(xml)
    let s1 = roundtrip_stroke(xml)
    assert_true(s0 == s1)
  }
}

///|
test "write_stroke: headEnd + tailEnd with size attrs round-trip" {
  let xml = "<a:ln>" +
    "<a:headEnd type=\"triangle\" w=\"med\" len=\"lg\"/>" +
    "<a:tailEnd type=\"none\"/>" +
    "</a:ln>"
  let s0 = parse_stroke_inner(xml)
  let s1 = roundtrip_stroke(xml)
  assert_true(s0 == s1)
}

///|
test "write_stroke: extLst sibling preserved via extension" {
  let xml = "<a:ln><a:extLst><a:ext uri=\"{X}\"/></a:extLst></a:ln>"
  let s0 = parse_stroke_inner(xml)
  let s1 = roundtrip_stroke(xml)
  assert_true(s0 == s1)
  assert_eq(s1.extension.length(), 1)
}

///|
test "write_stroke: full kitchen-sink line round-trips" {
  let xml = "<a:ln w=\"19050\" cap=\"rnd\" cmpd=\"dbl\" algn=\"in\">" +
    "<a:gradFill>" +
    "<a:gsLst>" +
    "<a:gs pos=\"0\"><a:srgbClr val=\"FFFFFF\"/></a:gs>" +
    "<a:gs pos=\"100000\"><a:srgbClr val=\"000000\"/></a:gs>" +
    "</a:gsLst>" +
    "<a:lin ang=\"0\" scaled=\"1\"/>" +
    "</a:gradFill>" +
    "<a:prstDash val=\"lgDashDot\"/>" +
    "<a:miter lim=\"800000\"/>" +
    "<a:headEnd type=\"arrow\" w=\"lg\" len=\"med\"/>" +
    "<a:tailEnd type=\"diamond\"/>" +
    "</a:ln>"
  let s0 = parse_stroke_inner(xml)
  let s1 = roundtrip_stroke(xml)
  assert_true(s0 == s1)
}
