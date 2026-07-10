// Tests for SVG picture support.

///|
/// Build a one-shape slide holding `pic`, so we can serialise it and check
/// the SVG blip round-trips through the writer (which must auto-declare the
/// `asvg` namespace for the synthesised `<asvg:svgBlip>`).
fn slide_of_picture(pic : @slide.Picture) -> @slide.Slide {
  {
    name: "",
    background: None,
    shapes: [Picture(pic)],
    clr_map_override: @slide_master.ClrMapOverride::MasterMapping,
    transition: None,
    timing: None,
    extension: [],
  }
}

///|
test "Picture::of_svg_image wires fallback embed + svgBlip extension" {
  let pic = @slide.Picture::of_svg_image(
    5,
    "Logo",
    "rId2", // raster fallback
    "rId3", // svg
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
  )
  // The blip embeds the raster fallback…
  assert_eq(pic.blip_fill.embed_id, "rId2")
  // …and the captured <a:blip> carries the svgBlip extension referencing
  // the SVG relationship.
  assert_eq(pic.blip_fill.extension.length(), 1)
  let blip = pic.blip_fill.extension[0]
  assert_eq(blip.name.local_name, "blip")
  // blip → extLst → ext → svgBlip
  let svg_blip = match blip.children[0] {
    Element(ext_lst) =>
      match ext_lst.children[0] {
        Element(ext) =>
          match ext.children[0] {
            Element(sb) => sb
            _ => fail("expected <asvg:svgBlip>")
          }
        _ => fail("expected <a:ext>")
      }
    _ => fail("expected <a:extLst>")
  }
  assert_eq(svg_blip.name.local_name, "svgBlip")
  assert_eq(svg_blip.name.uri, @oxml.svg_ns)
  assert_eq(svg_blip.attributes[0].1, "rId3")
}

///|
test "SVG blip serialises with the svg namespace and round-trips" {
  let pic = @slide.Picture::of_svg_image(
    7,
    "Logo",
    "rId2",
    "rId3",
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let slide = slide_of_picture(pic)
  let xml = @oxml.bytes_to_string(slide.serialize())
  // The serialised XML must carry the svgBlip and declare the SVG ns.
  assert_true(char_index_of(xml, "svgBlip") >= 0)
  assert_true(char_index_of(xml, @oxml.svg_ns) >= 0)
  // And it re-parses with the SVG extension intact.
  let reparsed = @slide.Slide::parse(slide.serialize())
  match reparsed.shapes[0] {
    Picture(p) => {
      assert_eq(p.blip_fill.embed_id, "rId2")
      assert_true(p.blip_fill == pic.blip_fill)
    }
    _ => fail("expected Picture shape")
  }
}
