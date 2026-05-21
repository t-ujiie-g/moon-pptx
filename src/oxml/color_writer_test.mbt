// @oxml.write_color round-trip tests (Phase 4c — colour slice).

///|
/// Serialise `c` as a standalone `<a:…Clr>` element (no wrapper) and
/// return the resulting XML string. Tests pipe this back through the
/// parser to assert round-trip equality.
fn color_to_xml(c : @oxml.Color) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("a", @oxml.drawing_ns)
  // We don't emit an xml declaration — write_color emits a single
  // colour element, and the round-trip helper wraps it before parsing.
  @oxml.write_color(w, ctx, c)
  w.to_string()
}

///|
/// Parse → serialize → re-parse, returning the second-parse `Color`
/// so tests can compare against the first parse.
fn roundtrip_color(input_inner : String) -> @oxml.Color raise {
  let first = parse_inner_color(input_inner)
  let serialized = color_to_xml(first)
  parse_inner_color(serialized)
}

// --- base colour kinds ---

///|
test "write_color: srgbClr round-trips" {
  let c0 = parse_inner_color("<a:srgbClr val=\"FF8800\"/>")
  let c1 = roundtrip_color("<a:srgbClr val=\"FF8800\"/>")
  assert_true(c0 == c1)
}

///|
test "write_color: schemeClr round-trips" {
  let c0 = parse_inner_color("<a:schemeClr val=\"accent3\"/>")
  let c1 = roundtrip_color("<a:schemeClr val=\"accent3\"/>")
  assert_true(c0 == c1)
}

///|
test "write_color: sysClr with lastClr round-trips" {
  let xml = "<a:sysClr val=\"windowText\" lastClr=\"112233\"/>"
  let c0 = parse_inner_color(xml)
  let c1 = roundtrip_color(xml)
  assert_true(c0 == c1)
}

///|
test "write_color: sysClr without lastClr round-trips" {
  let xml = "<a:sysClr val=\"window\"/>"
  let c0 = parse_inner_color(xml)
  let c1 = roundtrip_color(xml)
  assert_true(c0 == c1)
}

///|
test "write_color: hslClr round-trips" {
  let xml = "<a:hslClr hue=\"7200000\" sat=\"50000\" lum=\"60000\"/>"
  let c0 = parse_inner_color(xml)
  let c1 = roundtrip_color(xml)
  assert_true(c0 == c1)
}

///|
test "write_color: prstClr round-trips" {
  let xml = "<a:prstClr val=\"slateGray\"/>"
  let c0 = parse_inner_color(xml)
  let c1 = roundtrip_color(xml)
  assert_true(c0 == c1)
}

///|
test "write_color: scrgbClr round-trips" {
  let xml = "<a:scrgbClr r=\"25000\" g=\"50000\" b=\"75000\"/>"
  let c0 = parse_inner_color(xml)
  let c1 = roundtrip_color(xml)
  assert_true(c0 == c1)
}

// --- modifiers ---

///|
test "write_color: modeled transforms preserved in source order" {
  let xml = "<a:srgbClr val=\"5B9BD5\">" +
    "<a:tint val=\"40000\"/>" +
    "<a:satMod val=\"75000\"/>" +
    "<a:lumMod val=\"110000\"/>" +
    "</a:srgbClr>"
  let c0 = parse_inner_color(xml)
  let c1 = roundtrip_color(xml)
  assert_true(c0 == c1)
  assert_eq(c1.transforms.length(), 3)
}

///|
test "write_color: every modeled transform variant" {
  let xml = "<a:schemeClr val=\"accent1\">" +
    "<a:tint val=\"10000\"/>" +
    "<a:shade val=\"20000\"/>" +
    "<a:satMod val=\"30000\"/>" +
    "<a:lumMod val=\"40000\"/>" +
    "<a:alpha val=\"50000\"/>" +
    "</a:schemeClr>"
  let c0 = parse_inner_color(xml)
  let c1 = roundtrip_color(xml)
  assert_true(c0 == c1)
}

///|
test "write_color: unmodelled tail modifier rides on extension" {
  // <a:hueMod> is recognised by the parser but currently dropped into
  // `extension` for forward-compat per ADR-004.  Round-trip must keep
  // it.
  let xml = "<a:schemeClr val=\"accent2\">" +
    "<a:hueMod val=\"50000\"/>" +
    "</a:schemeClr>"
  let c0 = parse_inner_color(xml)
  let c1 = roundtrip_color(xml)
  assert_true(c0 == c1)
  assert_eq(c1.extension.length(), 1)
  assert_eq(c1.extension[0].name.local_name, "hueMod")
}

///|
test "write_color: modeled transform + unmodelled modifier coexist" {
  let xml = "<a:srgbClr val=\"112233\">" +
    "<a:tint val=\"50000\"/>" +
    "<a:gamma/>" +
    "</a:srgbClr>"
  let c0 = parse_inner_color(xml)
  let c1 = roundtrip_color(xml)
  assert_true(c0 == c1)
}
