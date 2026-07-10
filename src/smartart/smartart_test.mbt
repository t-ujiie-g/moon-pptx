// Unit tests for the `smartart` package.

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
test "org_chart data model: parent/child connections + all nodes drawn" {
  // CEO over CTO + CFO (CFO has one report) → 4 nodes total.
  let ceo = @smartart.Node::new("CEO", [
    @smartart.Node::leaf("CTO"),
    @smartart.Node::new("CFO", [@smartart.Node::leaf("Controller")]),
  ])
  let art = @smartart.SmartArt::org_chart(ceo)
  assert_true(art.kind == OrgChart)
  let data = @oxml.bytes_to_string(art.data_xml("rId1"))
  // One connection per node (every node has an incoming edge).
  assert_eq(count_occurrences(data, "<dgm:cxn "), 4)
  // Exactly one edge originates at the document root (the single CEO root);
  // the other three originate at a node (parent → child).
  assert_eq(count_occurrences(data, "srcId=\"0\""), 1)
  // Every node's text is present, including the nested ones.
  for label in ["CEO", "CTO", "CFO", "Controller"] {
    assert_true(data.find("<a:t>" + label + "</a:t>") is Some(_))
  }
  // The cached drawing lays out every node (not just the root) plus one
  // connector line per parent→child edge.
  let drawing = @oxml.bytes_to_string(
    art.drawing_xml(@units.Emu(8_000_000L), @units.Emu(5_000_000L)),
  )
  assert_eq(count_occurrences(drawing, "<dsp:sp "), 7)
  assert_eq(count_occurrences(drawing, "prst=\"line\""), 3)
  assert_eq(count_occurrences(drawing, "prst=\"roundRect\""), 4)
  assert_well_formed(data)
  assert_well_formed(drawing)
  assert_well_formed(@oxml.bytes_to_string(art.layout_xml()))
}

///|
test "hier layoutDef recurses + wires connectors" {
  let xml = @oxml.bytes_to_string(
    @smartart.SmartArt::org_chart(@smartart.Node::leaf("CEO")).layout_xml(),
  )
  // The recursive skeleton: hierRoot/hierChild composites and the named
  // forEach re-invoked by reference — the piece the single-level template
  // lacked (nesting families rendered top-level only).
  assert_eq(count_occurrences(xml, "type=\"hierRoot\""), 2)
  assert_true(xml.find("<dgm:forEach name=\"childForEach\"") is Some(_))
  assert_true(
    xml.find("<dgm:forEach name=\"recurseForEach\" ref=\"childForEach\"/>")
    is Some(_),
  )
  // Parent→child connectors ride the parTrans points.
  assert_true(xml.find("type=\"conn\"") is Some(_))
  assert_true(xml.find("ptType=\"parTrans\"") is Some(_))
  // Every text node names its styleLbl explicitly — PowerPoint Web
  // renders an absent styleLbl as black boxes (2026-07-06 finding).
  assert_true(xml.find("name=\"rootNode\" styleLbl=\"node0\"") is Some(_))
  assert_true(xml.find("name=\"childNode\" styleLbl=\"node1\"") is Some(_))
  // Org-chart identity + the org-chart UI variable.
  assert_true(xml.find("orgChart1") is Some(_))
  assert_true(xml.find("<dgm:orgChart val=\"1\"/>") is Some(_))
  assert_well_formed(xml)
  // Hierarchy shares the skeleton without the org-chart variable.
  let hxml = @oxml.bytes_to_string(
    @smartart.SmartArt::hierarchy([@smartart.Node::leaf("A")]).layout_xml(),
  )
  assert_true(hxml.find("hierarchy1") is Some(_))
  assert_true(hxml.find("<dgm:orgChart") is None)
  assert_true(hxml.find("ref=\"childForEach\"") is Some(_))
  assert_well_formed(hxml)
}

///|
test "drawing connector geometry: bounding box + flipH" {
  // Root centred over two children in a wide frame: the left child's
  // connector runs down-left (flipH), the right child's down-right (no
  // flip). Both span from the parent box's bottom centre to the child's
  // top centre, so their exts are equal and non-degenerate.
  let art = @smartart.SmartArt::org_chart(
    @smartart.Node::new("Root", [
      @smartart.Node::leaf("L"),
      @smartart.Node::leaf("R"),
    ]),
  )
  let xml = @oxml.bytes_to_string(
    art.drawing_xml(@units.Emu(8_000_000L), @units.Emu(4_000_000L)),
  )
  assert_eq(count_occurrences(xml, "prst=\"line\""), 2)
  assert_eq(count_occurrences(xml, "flipH=\"1\""), 1)
}

///|
test "radial layoutDef pins the hub and rings the spokes" {
  let xml = @oxml.bytes_to_string(
    @smartart.SmartArt::relationship(@smartart.Node::leaf("Core"), [
      @smartart.Node::leaf("A"),
    ]).layout_xml(),
  )
  // cycle + ctrShpMap="fNode" = hub-and-spoke; conn lines per parTrans.
  assert_true(xml.find("type=\"cycle\"") is Some(_))
  assert_true(xml.find("val=\"fNode\"") is Some(_))
  assert_true(xml.find("type=\"conn\"") is Some(_))
  assert_true(xml.find("radial1") is Some(_))
  assert_well_formed(xml)
}

///|
test "hierarchy forest: two roots both connect to the document" {
  let art = @smartart.SmartArt::hierarchy([
    @smartart.Node::new("A", [@smartart.Node::leaf("A1")]),
    @smartart.Node::new("B", [@smartart.Node::leaf("B1")]),
  ])
  assert_true(art.kind == Hierarchy)
  let data = @oxml.bytes_to_string(art.data_xml("rId1"))
  assert_eq(count_occurrences(data, "<dgm:cxn "), 4)
  // Two roots → two edges from the document root.
  assert_eq(count_occurrences(data, "srcId=\"0\""), 2)
  assert_true(
    @oxml.bytes_to_string(art.layout_xml()).find("hierarchy1") is Some(_),
  )
}

///|
test "matrix grid + relationship hub layouts" {
  // Matrix: four items → 2×2 grid, four boxes.
  let m = @smartart.SmartArt::matrix(["Q1", "Q2", "Q3", "Q4"])
  assert_true(m.kind == Matrix)
  let mxml = @oxml.bytes_to_string(
    m.drawing_xml(@units.Emu(5_000_000L), @units.Emu(5_000_000L)),
  )
  assert_eq(count_occurrences(mxml, "<dsp:sp "), 4)
  assert_true(@oxml.bytes_to_string(m.layout_xml()).find("matrix1") is Some(_))
  // Relationship: hub + 3 spokes → 4 nodes; the spokes connect to the hub.
  let r = @smartart.SmartArt::relationship(@smartart.Node::leaf("Core"), [
    @smartart.Node::leaf("People"),
    @smartart.Node::leaf("Process"),
    @smartart.Node::leaf("Tools"),
  ])
  assert_true(r.kind == Relationship)
  let rdata = @oxml.bytes_to_string(r.data_xml("rId1"))
  assert_eq(count_occurrences(rdata, "<dgm:cxn "), 4)
  // One edge from the doc (the hub), three from the hub node (the spokes).
  assert_eq(count_occurrences(rdata, "srcId=\"0\""), 1)
  let rxml = @oxml.bytes_to_string(
    r.drawing_xml(@units.Emu(5_000_000L), @units.Emu(5_000_000L)),
  )
  // Four boxes + three hub→spoke connector lines.
  assert_eq(count_occurrences(rxml, "<dsp:sp "), 7)
  assert_eq(count_occurrences(rxml, "prst=\"line\""), 3)
  // All parts well-formed for both families.
  assert_well_formed(mxml)
  assert_well_formed(rdata)
  assert_well_formed(rxml)
  assert_well_formed(@oxml.bytes_to_string(r.layout_xml()))
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
