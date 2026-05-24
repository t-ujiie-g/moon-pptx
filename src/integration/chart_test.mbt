// Chart end-to-end integration test (Phase 7a1).
//
// Builds a synthetic deck that carries a `<p:graphicFrame>` referencing
// a chart part (`/ppt/charts/chart1.xml`), validates that:
//
//   1. `Presentation::open` succeeds.
//   2. `Presentation::charts()` finds and parses the chart part.
//   3. The slide's graphic-frame shape lifts to `ChartContent(rid)` and
//      the rid resolves to the chart part via the slide's `.rels`.
//   4. `Package::to_bytes` → reopen → re-parse yields an equal chart.

///|
let ns_c : String = "http://schemas.openxmlformats.org/drawingml/2006/chart"

///|
fn fixture_chart_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<c:chartSpace xmlns:c=\"" +
  ns_c +
  "\" xmlns:a=\"" +
  ns_a +
  "\" xmlns:r=\"" +
  ns_r +
  "\">" +
  "<c:chart>" +
  "<c:autoTitleDeleted val=\"1\"/>" +
  "<c:plotArea>" +
  "<c:layout/>" +
  "<c:barChart>" +
  "<c:barDir val=\"col\"/>" +
  "<c:grouping val=\"clustered\"/>" +
  "<c:varyColors val=\"0\"/>" +
  "<c:ser>" +
  "<c:idx val=\"0\"/>" +
  "<c:order val=\"0\"/>" +
  "<c:tx><c:strRef><c:f>Sheet1!$B$1</c:f></c:strRef></c:tx>" +
  "<c:cat><c:strRef><c:f>Sheet1!$A$2:$A$4</c:f></c:strRef></c:cat>" +
  "<c:val><c:numRef><c:f>Sheet1!$B$2:$B$4</c:f></c:numRef></c:val>" +
  "</c:ser>" +
  "<c:axId val=\"1\"/>" +
  "<c:axId val=\"2\"/>" +
  "</c:barChart>" +
  "<c:catAx><c:axId val=\"1\"/></c:catAx>" +
  "<c:valAx><c:axId val=\"2\"/></c:valAx>" +
  "</c:plotArea>" +
  "<c:plotVisOnly val=\"1\"/>" +
  "<c:dispBlanksAs val=\"gap\"/>" +
  "</c:chart>" +
  "</c:chartSpace>"
}

///|
fn fixture_slide_with_chart_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<p:sld xmlns:p=\"" +
  ns_p +
  "\" xmlns:a=\"" +
  ns_a +
  "\" xmlns:r=\"" +
  ns_r +
  "\" xmlns:c=\"" +
  ns_c +
  "\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr/>" +
  "<p:graphicFrame>" +
  "<p:nvGraphicFramePr><p:cNvPr id=\"2\" name=\"Chart 1\"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>" +
  "<p:xfrm><a:off x=\"914400\" y=\"914400\"/><a:ext cx=\"6858000\" cy=\"4572000\"/></p:xfrm>" +
  "<a:graphic><a:graphicData uri=\"" +
  ns_c +
  "\"><c:chart r:id=\"rId2\"/></a:graphicData></a:graphic>" +
  "</p:graphicFrame>" +
  "</p:spTree></p:cSld>" +
  "</p:sld>"
}

///|
/// `.rels` for the chart-carrying slide: points to the layout (rId1)
/// and the chart part (rId2).
fn fixture_chart_slide_rels_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/>" +
  "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>" +
  "</Relationships>"
}

///|
/// Build a PPTX with one chart-bearing slide. We need the slide `.rels`
/// part too because chart resolution goes through the rId.
fn chart_deck() -> FixedArray[Byte] {
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
    ("/ppt/slides/slide1.xml", ct_slide, fixture_slide_with_chart_xml()),
    (
      "/ppt/slides/_rels/slide1.xml.rels",
      ct_rels,
      fixture_chart_slide_rels_xml(),
    ),
    ("/ppt/charts/chart1.xml", @oxml.ct_chart, fixture_chart_xml()),
  ]
  build_pptx("/ppt/presentation.xml", parts)
}

// --- tests ---

///|
test "Phase 7a1: chart deck opens and Presentation::charts() finds the part" {
  let prs = @presentation.Presentation::open(chart_deck())
  let charts = prs.charts()
  assert_eq(charts.length(), 1)
  let chart = charts[0]
  // Phase 7a3a: plotArea body is typed; the fixture's chart is a bar
  // chart, so check for the expected plot kind.
  assert_eq(chart.chart.plot_area.plots.length(), 1)
  assert_eq(chart.chart.plot_area.plots[0].local_name(), "barChart")
}

///|
test "Phase 7a1: slide-side chart graphicFrame lifts to ChartContent(rid)" {
  // Read the slide directly by content type — this fixture's
  // presentation.xml has no <p:sldIdLst>, so Presentation::slides()
  // can't resolve them by relationship. The shape-tree behaviour is
  // what we're testing here, not slide-ordering.
  let pkg = @opc.Package::open(chart_deck())
  let slide_parts = parts_of(pkg, ct_slide)
  assert_eq(slide_parts.length(), 1)
  let s = @slide.Slide::parse(slide_parts[0].bytes)
  assert_eq(s.shapes.length(), 1)
  match s.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        ChartContent(rid) => assert_eq(rid, "rId2")
        _ => fail("expected ChartContent")
      }
    _ => fail("expected GraphicFrame shape")
  }
}

///|
test "Phase 7a1: chart deck round-trips through Package::to_bytes" {
  let prs_in = @presentation.Presentation::open(chart_deck())
  let bytes = prs_in.save()
  let prs_out = @presentation.Presentation::open(bytes)
  let charts_in = prs_in.charts()
  let charts_out = prs_out.charts()
  assert_eq(charts_in.length(), charts_out.length())
  assert_true(charts_in[0] == charts_out[0])
}

///|
test "Phase 7a1: slide-side ChartContent survives re_serialize_all" {
  // The slide-side `<c:chart r:id=…/>` reference also needs to round-trip,
  // since Phase 7a1 swapped `OtherGraphic(uri, captured)` for the
  // typed `ChartContent(rid)` variant.
  let pkg_re = re_serialize_all(@opc.Package::open(chart_deck()))
  let pkg_out = @opc.Package::open(pkg_re.to_bytes())
  let slide_parts = parts_of(pkg_out, ct_slide)
  let s = @slide.Slide::parse(slide_parts[0].bytes)
  match s.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        ChartContent(rid) => assert_eq(rid, "rId2")
        _ => fail("expected ChartContent post round-trip")
      }
    _ => fail("expected GraphicFrame shape post round-trip")
  }
}

///|
test "Phase 7a1: chart_deck re_serialize_all preserves Chart" {
  // The strongest Phase-4-style invariant for the chart layer:
  // parse → serialize → reopen → re-parse must produce an equal Chart.
  let pkg_in = @opc.Package::open(chart_deck())
  let pkg_re = re_serialize_all(@opc.Package::open(chart_deck()))
  let pkg_out = @opc.Package::open(pkg_re.to_bytes())
  let parts_in = parts_of(pkg_in, @oxml.ct_chart)
  let parts_out = parts_of(pkg_out, @oxml.ct_chart)
  assert_eq(parts_in.length(), 1)
  assert_eq(parts_out.length(), 1)
  let c_in = @chart.Chart::parse(parts_in[0].bytes)
  let c_out = @chart.Chart::parse(parts_out[0].bytes)
  assert_true(c_in == c_out)
}
