// @oxml SVG-blip builder tests.

///|
test "BlipFill::svg: fallback embed + svgBlip extension structure" {
  let bf = @oxml.BlipFill::svg("rId2", "rId3")
  // The raster fallback is the typed embed.
  assert_eq(bf.embed_id, "rId2")
  assert_eq(bf.link_id, "")
  // The captured <a:blip> carries r:embed=fallback + extLst→ext→svgBlip.
  assert_eq(bf.extension.length(), 1)
  let blip = bf.extension[0]
  assert_eq(blip.name.uri, @oxml.drawing_ns)
  assert_eq(blip.name.local_name, "blip")
  assert_eq(blip.attributes[0].1, "rId2")
  match blip.children[0] {
    Element(ext_lst) => {
      assert_eq(ext_lst.name.local_name, "extLst")
      match ext_lst.children[0] {
        Element(ext) => {
          assert_eq(ext.name.local_name, "ext")
          // The ext is keyed by the fixed SVG-blip GUID.
          assert_eq(ext.attributes[0].1, @oxml.svg_blip_ext_uri)
          match ext.children[0] {
            Element(sb) => {
              assert_eq(sb.name.uri, @oxml.svg_ns)
              assert_eq(sb.name.local_name, "svgBlip")
              assert_eq(sb.attributes[0].1, "rId3")
            }
            _ => fail("expected <asvg:svgBlip>")
          }
        }
        _ => fail("expected <a:ext>")
      }
    }
    _ => fail("expected <a:extLst>")
  }
}
