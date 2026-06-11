// Unit tests for the `smartart` package (roadmap D1).

///|
/// Count non-overlapping occurrences of `needle` in `s`.
fn count_occurrences(s : String, needle : String) -> Int {
  let mut count = 0
  let mut rest = s
  while rest.find(needle) is Some(off) {
    count = count + 1
    rest = rest.view(start_offset=off + needle.length()).to_owned()
  }
  count
}

///|
test "list / process builders set kind + leaf nodes" {
  let l = @smartart.SmartArt::list(["A", "B", "C"])
  assert_true(l.kind == List)
  assert_eq(l.nodes.length(), 3)
  assert_eq(l.nodes[0].text, "A")
  assert_eq(l.nodes[0].children.length(), 0)
  let p = @smartart.SmartArt::process(["X"])
  assert_true(p.kind == Process)
  assert_eq(p.nodes.length(), 1)
}

///|
test "Node constructors + model equality" {
  let leaf = @smartart.Node::leaf("hi")
  assert_true(leaf == @smartart.Node::new("hi", []))
  let a = @smartart.SmartArt::list(["A", "B"])
  let b = @smartart.SmartArt::new(List, [
    @smartart.Node::leaf("A"),
    @smartart.Node::leaf("B"),
  ])
  assert_true(a == b)
}

///|
test "data_xml carries the node text, connections, and drawing ext" {
  let art = @smartart.SmartArt::list(["First", "Second"])
  let xml = @oxml.bytes_to_string(art.data_xml("rId7"))
  // Root + structure.
  assert_true(xml.find("<dgm:dataModel") is Some(_))
  assert_true(xml.find("type=\"doc\"") is Some(_))
  // One connection per node.
  assert_eq(count_occurrences(xml, "<dgm:cxn "), 2)
  // Node texts present.
  assert_true(xml.find("<a:t>First</a:t>") is Some(_))
  assert_true(xml.find("<a:t>Second</a:t>") is Some(_))
  // The dsp dataModelExt references the supplied drawing rel id.
  assert_true(xml.find("<dsp:dataModelExt relId=\"rId7\"") is Some(_))
}

///|
test "drawing_xml lays out one shape per node" {
  let art = @smartart.SmartArt::list(["A", "B", "C"])
  let xml = @oxml.bytes_to_string(
    art.drawing_xml(@units.Emu(6_000_000L), @units.Emu(3_000_000L)),
  )
  assert_true(xml.find("<dsp:drawing") is Some(_))
  assert_eq(count_occurrences(xml, "<dsp:sp "), 3)
  assert_true(xml.find("<a:t>B</a:t>") is Some(_))
  assert_true(xml.find("prst=\"roundRect\"") is Some(_))
}

///|
test "layout_xml direction differs List vs Process" {
  let list_xml = @oxml.bytes_to_string(
    @smartart.SmartArt::list(["A"]).layout_xml(),
  )
  assert_true(list_xml.find("val=\"fromT\"") is Some(_))
  let proc_xml = @oxml.bytes_to_string(
    @smartart.SmartArt::process(["A"]).layout_xml(),
  )
  assert_true(proc_xml.find("val=\"fromL\"") is Some(_))
}

///|
test "cycle / pyramid builders + layout algorithms" {
  let c = @smartart.SmartArt::cycle(["A", "B", "C", "D"])
  assert_true(c.kind == Cycle)
  assert_eq(c.nodes.length(), 4)
  let p = @smartart.SmartArt::pyramid(["Top", "Mid", "Base"])
  assert_true(p.kind == Pyramid)
  // Layout defs carry the right algorithm type.
  assert_true(
    @oxml.bytes_to_string(c.layout_xml()).find("type=\"cycle\"") is Some(_),
  )
  assert_true(
    @oxml.bytes_to_string(p.layout_xml()).find("type=\"pyra\"") is Some(_),
  )
}

///|
test "cycle / pyramid drawings lay out one box per node" {
  let c = @smartart.SmartArt::cycle(["A", "B", "C", "D"])
  let cxml = @oxml.bytes_to_string(
    c.drawing_xml(@units.Emu(5_000_000L), @units.Emu(5_000_000L)),
  )
  assert_eq(count_occurrences(cxml, "<dsp:sp "), 4)
  let p = @smartart.SmartArt::pyramid(["Top", "Mid", "Base"])
  let pxml = @oxml.bytes_to_string(
    p.drawing_xml(@units.Emu(5_000_000L), @units.Emu(3_000_000L)),
  )
  assert_eq(count_occurrences(pxml, "<dsp:sp "), 3)
  // All generated parts well-formed for the new families too.
  assert_well_formed(cxml)
  assert_well_formed(pxml)
  assert_well_formed(@oxml.bytes_to_string(c.data_xml("rId1")))
  assert_well_formed(@oxml.bytes_to_string(p.layout_xml()))
}

///|
test "colors + quickStyle parts are well-formed roots" {
  let art = @smartart.SmartArt::list(["A"])
  let colors = @oxml.bytes_to_string(art.colors_xml())
  assert_true(colors.find("<dgm:colorsDef") is Some(_))
  let qs = @oxml.bytes_to_string(art.quick_style_xml())
  assert_true(qs.find("<dgm:styleDef") is Some(_))
}

///|
/// Drain the streaming reader to completion — raises on malformed XML.
fn assert_well_formed(xml : String) -> Unit raise {
  let r = @xml.XmlReader::new(xml)
  while r.next() is Some(_) {

  }
}

///|
test "all generated parts are well-formed XML" {
  let art = @smartart.SmartArt::process(["Alpha", "Beta < Gamma"])
  assert_well_formed(@oxml.bytes_to_string(art.data_xml("rId1")))
  assert_well_formed(
    @oxml.bytes_to_string(art.drawing_xml(@units.Emu(100L), @units.Emu(100L))),
  )
  assert_well_formed(@oxml.bytes_to_string(art.layout_xml()))
  assert_well_formed(@oxml.bytes_to_string(art.colors_xml()))
  assert_well_formed(@oxml.bytes_to_string(art.quick_style_xml()))
}
