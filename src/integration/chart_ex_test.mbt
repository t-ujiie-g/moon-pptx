// Extended-chart (chartEx) end-to-end integration test.
//
// Builds a synthetic deck whose `<p:graphicFrame>` references a
// `chartExN.xml` part (the chartEx URI). Validates the full
// pipeline: Presentation::open → Presentation::charts_ex() finds
// the part, the slide-side rel id surfaces as
// `GraphicFrameContent::ChartExContent(rid)`, and the whole package
// survives Package::to_bytes round-trip.

///|
let ns_cx : String = "http://schemas.microsoft.com/office/drawing/2014/chartex"

///|
fn fixture_chart_ex_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<cx:chartSpace xmlns:cx=\"" +
  ns_cx +
  "\" xmlns:r=\"" +
  ns_r +
  "\">" +
  "<cx:chartData>" +
  "<cx:data id=\"0\">" +
  "<cx:numDim type=\"val\"><cx:lvl ptCount=\"3\"><cx:pt idx=\"0\">10</cx:pt><cx:pt idx=\"1\">20</cx:pt><cx:pt idx=\"2\">30</cx:pt></cx:lvl></cx:numDim>" +
  "</cx:data>" +
  "</cx:chartData>" +
  "<cx:chart>" +
  "<cx:plotArea>" +
  "<cx:plotAreaRegion>" +
  "<cx:series layoutId=\"sunburst\"><cx:dataId val=\"0\"/></cx:series>" +
  "</cx:plotAreaRegion>" +
  "</cx:plotArea>" +
  "</cx:chart>" +
  "</cx:chartSpace>"
}

///|
fn fixture_slide_with_chart_ex_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:sld xmlns:p=\"" +
  ns_p +
  "\" xmlns:a=\"" +
  ns_a +
  "\" xmlns:r=\"" +
  ns_r +
  "\" xmlns:cx=\"" +
  ns_cx +
  "\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  "<p:graphicFrame>" +
  "<p:nvGraphicFramePr><p:cNvPr id=\"2\" name=\"Sunburst\"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>" +
  "<p:xfrm><a:off x=\"914400\" y=\"914400\"/><a:ext cx=\"6858000\" cy=\"4572000\"/></p:xfrm>" +
  "<a:graphic><a:graphicData uri=\"" +
  ns_cx +
  "\"><cx:chart r:id=\"rId2\"/></a:graphicData></a:graphic>" +
  "</p:graphicFrame>" +
  "</p:spTree></p:cSld>" +
  "</p:sld>"
}

///|
fn fixture_chart_ex_slide_rels_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/>" +
  "<Relationship Id=\"rId2\" Type=\"http://schemas.microsoft.com/office/2014/relationships/chartEx\" Target=\"../charts/chartEx1.xml\"/>" +
  "</Relationships>"
}

///|
/// Build a PPTX whose slide carries a chartEx-bearing graphic frame.
fn chart_ex_deck() -> FixedArray[Byte] {
  let ct_rels = "application/vnd.openxmlformats-package.relationships+xml"
  let parts : Array[(String, String, String)] = [
    ("/ppt/presentation.xml", ct_presentation, fixture_presentation_xml()),
    ("/ppt/theme/theme1.xml", ct_theme, fixture_theme_xml()),
    (
      "/ppt/slideMasters/slideMaster1.xml",
      ct_slide_master,
      fixture_master_xml(),
    ),
    (
      "/ppt/slideLayouts/slideLayout1.xml",
      ct_slide_layout,
      fixture_layout_xml(),
    ),
    ("/ppt/slides/slide1.xml", ct_slide, fixture_slide_with_chart_ex_xml()),
    (
      "/ppt/slides/_rels/slide1.xml.rels",
      ct_rels,
      fixture_chart_ex_slide_rels_xml(),
    ),
    ("/ppt/charts/chartEx1.xml", @oxml.ct_chart_ex, fixture_chart_ex_xml()),
  ]
  build_pptx("/ppt/presentation.xml", parts)
}

// --- tests ---

///|
test "chartEx deck opens and Presentation::charts_ex() finds the part" {
  let prs = @presentation.Presentation::open(chart_ex_deck())
  let charts = prs.charts_ex()
  assert_eq(charts.length(), 1)
  let chart = charts[0]
  // The fixture is a sunburst — confirm the typed kind discriminator
  // came through.
  let series = chart.chart.plot_area.plot_area_region.series
  assert_eq(series.length(), 1)
  assert_eq(series[0].layout_id, Sunburst)
}

///|
test "Presentation::charts_ex distinct from Presentation::charts" {
  // Standard `charts()` should be empty when the deck only has
  // chartEx parts (and vice-versa).
  let prs = @presentation.Presentation::open(chart_ex_deck())
  assert_eq(prs.charts().length(), 0)
  assert_eq(prs.charts_ex().length(), 1)
}

///|
test "slide-side chartEx graphicFrame lifts to ChartExContent(rid)" {
  let pkg = @opc.Package::open(chart_ex_deck())
  let slide_parts = parts_of(pkg, ct_slide)
  assert_eq(slide_parts.length(), 1)
  let s = @slide.Slide::parse(slide_parts[0].bytes)
  assert_eq(s.shapes.length(), 1)
  match s.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        ChartExContent(rid) => assert_eq(rid, "rId2")
        _ => fail("expected ChartExContent")
      }
    _ => fail("expected GraphicFrame shape")
  }
}

///|
test "chartEx deck round-trips through Package::to_bytes" {
  let prs_in = @presentation.Presentation::open(chart_ex_deck())
  let bytes = prs_in.save()
  let prs_out = @presentation.Presentation::open(bytes)
  let charts_in = prs_in.charts_ex()
  let charts_out = prs_out.charts_ex()
  assert_eq(charts_in.length(), charts_out.length())
  assert_true(charts_in[0] == charts_out[0])
}

///|
test "slide-side ChartExContent survives re_serialize_all" {
  // Same defensive test as ChartContent has: confirm the typed
  // slide-side variant round-trips after a full re-serialise pass.
  let pkg_re = re_serialize_all(@opc.Package::open(chart_ex_deck()))
  let pkg_out = @opc.Package::open(pkg_re.to_bytes())
  let slide_parts = parts_of(pkg_out, ct_slide)
  let s = @slide.Slide::parse(slide_parts[0].bytes)
  match s.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        ChartExContent(rid) => assert_eq(rid, "rId2")
        _ => fail("expected ChartExContent post round-trip")
      }
    _ => fail("expected GraphicFrame shape post round-trip")
  }
}
