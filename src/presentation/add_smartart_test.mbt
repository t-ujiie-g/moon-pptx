// Tests for `Presentation::add_smartart_mut` (roadmap D1).

///|
/// Find the `<dgm:relIds>` element inside a SmartArt graphicFrame's captured
/// `<a:graphicData>` body, then read one `r:*` attribute by local name.
fn rel_ids_attr(captured : @xml.XmlElement, lname : String) -> String? {
  for child in captured.children {
    match child {
      Element(e) =>
        if e.name.local_name == "relIds" {
          for kv in e.attributes {
            if kv.0.local_name == lname {
              return Some(kv.1)
            }
          }
        }
      _ => ()
    }
  }
  None
}

///|
test "add_smartart_mut: wires five diagram parts with content types" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let art = @smartart.SmartArt::list(["Plan", "Build", "Ship"])
  prs.add_smartart_mut(
    0,
    art,
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    @units.Emu(6_858_000L),
    @units.Emu(4_572_000L),
  )
  // Five parts with the right content types.
  let cases = [
    ("/ppt/diagrams/data1.xml", @oxml.ct_diagram_data),
    ("/ppt/diagrams/layout1.xml", @oxml.ct_diagram_layout),
    ("/ppt/diagrams/quickStyle1.xml", @oxml.ct_diagram_style),
    ("/ppt/diagrams/colors1.xml", @oxml.ct_diagram_colors),
    ("/ppt/drawings/drawing1.xml", @oxml.ct_diagram_drawing),
  ]
  for c in cases {
    let part = prs.pkg.part_by_name(c.0).unwrap()
    assert_eq(part.content_type, c.1)
    // Each part is registered as an Override.
    assert_true(
      prs.pkg.content_types().overrides
      .iter()
      .any(fn(kv) { kv.0 == c.0 && kv.1 == c.1 }),
    )
  }
}

///|
test "add_smartart_mut: graphicFrame carries the four diagram relIds" {
  let prs = @presentation.Presentation::new()
  let slide_name = prs.add_slide_mut(0)
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::process(["A", "B"]),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(6_000_000L),
    @units.Emu(2_000_000L),
  )
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 1)
  let captured = match slide.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        OtherGraphic(uri, el) => {
          assert_eq(uri, @oxml.graphic_data_diagram_uri)
          el
        }
        _ => fail("expected OtherGraphic (SmartArt) content")
      }
    _ => fail("expected GraphicFrame")
  }
  // The four relIds reference real slide relationships.
  let rels = prs.pkg.relationships_for(slide_name)
  for lname in ["dm", "lo", "qs", "cs"] {
    let rid = rel_ids_attr(captured, lname).unwrap()
    assert_true(rels.by_id(rid) is Some(_))
  }
  // dm points at the data part, cs at the colors part.
  let dm = rel_ids_attr(captured, "dm").unwrap()
  assert_eq(rels.by_id(dm).unwrap().rel_type, @opc.rt_diagram_data)
  let cs = rel_ids_attr(captured, "cs").unwrap()
  assert_eq(rels.by_id(cs).unwrap().rel_type, @opc.rt_diagram_colors)
}

///|
test "add_smartart_mut: data part references the cached drawing" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::list(["One"]),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  // The data part's rels point at the drawing via the diagramDrawing rel.
  let data_rels = prs.pkg.relationships_for("/ppt/diagrams/data1.xml")
  let drawing_rel = data_rels.items
    .iter()
    .find_first(fn(r) { r.rel_type == @opc.rt_diagram_drawing })
    .unwrap()
  assert_true(drawing_rel.target.contains("drawing1.xml"))
  // And the data model records that relId inside <dsp:dataModelExt>.
  let data_part = prs.pkg.part_by_name("/ppt/diagrams/data1.xml").unwrap()
  let xml = @oxml.bytes_to_string(data_part.bytes)
  assert_true(xml.find("dataModelExt") is Some(_))
  assert_true(xml.find("relId=\"" + drawing_rel.id + "\"") is Some(_))
}

///|
test "add_smartart_mut: survives save -> reopen" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::list(["Plan", "Build", "Ship"]),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(6_000_000L),
    @units.Emu(4_000_000L),
  )
  let prs2 = @presentation.Presentation::open(prs.save())
  // All five parts survive.
  for
    name in [
      "/ppt/diagrams/data1.xml", "/ppt/diagrams/layout1.xml", "/ppt/diagrams/quickStyle1.xml",
      "/ppt/diagrams/colors1.xml", "/ppt/drawings/drawing1.xml",
    ] {
    assert_true(prs2.pkg.part_by_name(name) is Some(_))
  }
  // The graphicFrame survives as SmartArt content.
  let slide = prs2.slides()[0]
  assert_eq(slide.shapes.length(), 1)
  match slide.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        OtherGraphic(uri, _) => assert_eq(uri, @oxml.graphic_data_diagram_uri)
        _ => fail("expected OtherGraphic after reopen")
      }
    _ => fail("expected GraphicFrame after reopen")
  }
}

///|
test "add_smartart_mut: escapes node text in data + drawing parts" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::list(["A < B & C"]),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let data = prs.pkg.part_by_name("/ppt/diagrams/data1.xml").unwrap()
  let xml = @oxml.bytes_to_string(data.bytes)
  assert_true(xml.find("A &lt; B &amp; C") is Some(_))
  // The raw unescaped form must not appear as element text.
  assert_true(xml.find("A < B & C") is None)
}

///|
test "add_smartart_mut: second diagram gets index 2 across all parts" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::list(["x"]),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  prs.add_smartart_mut(
    0,
    @smartart.SmartArt::process(["y"]),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(prs.pkg.part_by_name("/ppt/diagrams/data2.xml") is Some(_))
  assert_true(prs.pkg.part_by_name("/ppt/drawings/drawing2.xml") is Some(_))
  assert_eq(prs.slides()[0].shapes.length(), 2)
}

///|
test "add_smartart_mut: cycle + pyramid wire end-to-end and reopen" {
  for
    art in [
      @smartart.SmartArt::cycle(["A", "B", "C"]),
      @smartart.SmartArt::pyramid(["Top", "Mid", "Base"]),
    ] {
    let prs = @presentation.Presentation::new()
    let _ = prs.add_slide_mut(0)
    prs.add_smartart_mut(
      0,
      art,
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(5_000_000L),
      @units.Emu(3_000_000L),
    )
    let prs2 = @presentation.Presentation::open(prs.save())
    assert_true(prs2.pkg.part_by_name("/ppt/diagrams/data1.xml") is Some(_))
    assert_true(prs2.pkg.part_by_name("/ppt/drawings/drawing1.xml") is Some(_))
    assert_eq(prs2.slides()[0].shapes.length(), 1)
  }
}

///|
test "add_smartart_mut: empty diagram raises Malformed" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  try
    prs.add_smartart_mut(
      0,
      @smartart.SmartArt::list([]),
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(100L),
      @units.Emu(100L),
    )
  catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}
