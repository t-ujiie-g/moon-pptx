// @oxml.write_effect_list round-trip tests.

///|
fn effect_to_xml(el : @oxml.EffectList) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("a", @oxml.drawing_ns)
  w.start_element(@xml.QName::unqualified("wrapper"))
  w.namespace_attr("a", @oxml.drawing_ns)
  @oxml.write_effect_list(w, ctx, el)
  w.end_element()
  w.to_string()
}

///|
fn roundtrip_effect_list(input_inner : String) -> @oxml.EffectList raise {
  let first = parse_effect_list_inner(input_inner)
  let serialized = effect_to_xml(first)
  let r = @xml.XmlReader::new(serialized)
  let _ = r.next() catch {
    _ => raise @oxml.EffectError::MalformedEffect("rt wrapper open failed")
  }
  while true {
    let ev = r.next() catch {
      _ => raise @oxml.EffectError::MalformedEffect("rt inner failed")
    }
    match ev {
      Some(StartElement(_, _)) => return @oxml.parse_effect_list(r)
      Some(EndElement(_)) =>
        raise @oxml.EffectError::MalformedEffect("empty rt wrapper")
      Some(_) => ()
      None => raise @oxml.EffectError::MalformedEffect("unexpected rt end")
    }
  }
  raise @oxml.EffectError::MalformedEffect("unreachable")
}

///|
test "write_effect_list: empty <a:effectLst/> round-trips" {
  let el0 = parse_effect_list_inner("")
  let el1 = roundtrip_effect_list("")
  assert_true(el0 == el1)
}

///|
test "write_effect_list: blur round-trips" {
  let xml = "<a:blur rad=\"50800\" grow=\"1\"/>"
  let el0 = parse_effect_list_inner(xml)
  let el1 = roundtrip_effect_list(xml)
  assert_true(el0 == el1)
}

///|
test "write_effect_list: glow round-trips" {
  let xml = "<a:glow rad=\"63500\"><a:srgbClr val=\"FF0000\"/></a:glow>"
  let el0 = parse_effect_list_inner(xml)
  let el1 = roundtrip_effect_list(xml)
  assert_true(el0 == el1)
}

///|
test "write_effect_list: innerShdw round-trips" {
  let xml = "<a:innerShdw blurRad=\"50800\" dist=\"38100\" dir=\"2700000\">" +
    "<a:srgbClr val=\"000000\"><a:alpha val=\"50000\"/></a:srgbClr>" +
    "</a:innerShdw>"
  let el0 = parse_effect_list_inner(xml)
  let el1 = roundtrip_effect_list(xml)
  assert_true(el0 == el1)
}

///|
test "write_effect_list: outerShdw full attribute soup round-trips" {
  let xml = "<a:outerShdw blurRad=\"50800\" dist=\"38100\" dir=\"5400000\"" +
    " sx=\"110000\" sy=\"110000\" kx=\"600000\" ky=\"600000\"" +
    " algn=\"ctr\" rotWithShape=\"0\">" +
    "<a:schemeClr val=\"accent1\"/>" +
    "</a:outerShdw>"
  let el0 = parse_effect_list_inner(xml)
  let el1 = roundtrip_effect_list(xml)
  assert_true(el0 == el1)
}

///|
test "write_effect_list: prstShdw round-trips" {
  let xml = "<a:prstShdw prst=\"shdw18\" dist=\"38100\" dir=\"2700000\">" +
    "<a:srgbClr val=\"808080\"/>" +
    "</a:prstShdw>"
  let el0 = parse_effect_list_inner(xml)
  let el1 = roundtrip_effect_list(xml)
  assert_true(el0 == el1)
}

///|
test "write_effect_list: softEdge round-trips" {
  let xml = "<a:softEdge rad=\"31750\"/>"
  let el0 = parse_effect_list_inner(xml)
  let el1 = roundtrip_effect_list(xml)
  assert_true(el0 == el1)
}

///|
test "write_effect_list: reflection round-trips" {
  let xml = "<a:reflection blurRad=\"6350\" stA=\"50000\" stPos=\"0\"" +
    " endA=\"300\" endPos=\"50000\" dist=\"22987\" dir=\"5400000\"" +
    " sy=\"-100000\" algn=\"bl\" rotWithShape=\"0\"/>"
  let el0 = parse_effect_list_inner(xml)
  let el1 = roundtrip_effect_list(xml)
  assert_true(el0 == el1)
}

///|
test "write_effect_list: fillOverlay sibling preserved via extension" {
  let xml = "<a:fillOverlay blend=\"over\"><a:solidFill><a:srgbClr val=\"000000\"/></a:solidFill></a:fillOverlay>"
  let el0 = parse_effect_list_inner(xml)
  let el1 = roundtrip_effect_list(xml)
  assert_true(el0 == el1)
  assert_eq(el1.extension.length(), 1)
}

///|
test "write_effect_list: combined effects round-trip" {
  let xml = "<a:blur rad=\"63500\"/>" +
    "<a:glow rad=\"50800\"><a:srgbClr val=\"FFFF00\"/></a:glow>" +
    "<a:outerShdw blurRad=\"50800\" dist=\"38100\" dir=\"5400000\">" +
    "<a:srgbClr val=\"000000\"/>" +
    "</a:outerShdw>"
  let el0 = parse_effect_list_inner(xml)
  let el1 = roundtrip_effect_list(xml)
  assert_true(el0 == el1)
}
