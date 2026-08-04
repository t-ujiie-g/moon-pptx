// ChartEx parser / writer tests.

///|
let chart_ex_ns : String = "http://schemas.microsoft.com/office/drawing/2014/chartex"

///|
/// A minimal but spec-shaped `<cx:chartSpace>` for a waterfall
/// chart. The chart kind is determined by the `layoutId="…"`
/// attribute on `<cx:plotAreaRegion><cx:series>`, which lifts to
/// the typed `ChartExKind` enum.
fn typical_waterfall_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<cx:chartSpace xmlns:cx=\"" +
  chart_ex_ns +
  "\">" +
  "<cx:chartData>" +
  "<cx:data id=\"0\">" +
  "<cx:strDim type=\"cat\"><cx:lvl ptCount=\"3\"><cx:pt idx=\"0\">A</cx:pt><cx:pt idx=\"1\">B</cx:pt><cx:pt idx=\"2\">C</cx:pt></cx:lvl></cx:strDim>" +
  "<cx:numDim type=\"val\"><cx:lvl ptCount=\"3\" formatCode=\"General\"><cx:pt idx=\"0\">100</cx:pt><cx:pt idx=\"1\">200</cx:pt><cx:pt idx=\"2\">300</cx:pt></cx:lvl></cx:numDim>" +
  "</cx:data>" +
  "</cx:chartData>" +
  "<cx:chart>" +
  "<cx:plotArea>" +
  "<cx:plotAreaRegion>" +
  "<cx:plotSurface/>" +
  "<cx:series layoutId=\"waterfall\" formatIdx=\"0\">" +
  "<cx:dataLabels pos=\"outEnd\"/>" +
  "<cx:dataId val=\"0\"/>" +
  "</cx:series>" +
  "</cx:plotAreaRegion>" +
  "</cx:plotArea>" +
  "</cx:chart>" +
  "</cx:chartSpace>"
}

///|
test "ChartEx::parse: root recognised + chart body lifted" {
  let chart = @chart_ex.ChartEx::parse(
    @oxml.string_to_bytes(typical_waterfall_xml()),
  )
  // <cx:chartData> is captured as XmlElement, <cx:chart> is typed.
  assert_true(chart.chart_data is Some(_))
  // The waterfall fixture has exactly one plot-area region with one
  // typed series.
  let region = chart.chart.plot_area.plot_area_region
  assert_eq(region.series.length(), 1)
  assert_eq(region.series[0].layout_id, Waterfall)
}

///|
test "ChartEx::parse: layoutId discriminates chart kind" {
  // Same fixture shape but with `layoutId="sunburst"` to confirm
  // every spec'd kind dispatches correctly.
  let xml = "<?xml version=\"1.0\"?>" +
    "<cx:chartSpace xmlns:cx=\"" +
    chart_ex_ns +
    "\">" +
    "<cx:chart>" +
    "<cx:plotArea>" +
    "<cx:plotAreaRegion>" +
    "<cx:series layoutId=\"sunburst\"><cx:dataId val=\"0\"/></cx:series>" +
    "</cx:plotAreaRegion>" +
    "</cx:plotArea>" +
    "</cx:chart>" +
    "</cx:chartSpace>"
  let chart = @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml))
  assert_eq(
    chart.chart.plot_area.plot_area_region.series[0].layout_id,
    Sunburst,
  )
}

///|
test "ChartEx::parse: unknown layoutId routes to Other" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<cx:chartSpace xmlns:cx=\"" +
    chart_ex_ns +
    "\">" +
    "<cx:chart>" +
    "<cx:plotArea>" +
    "<cx:plotAreaRegion>" +
    "<cx:series layoutId=\"futurePlot2030\"><cx:dataId val=\"0\"/></cx:series>" +
    "</cx:plotAreaRegion>" +
    "</cx:plotArea>" +
    "</cx:chart>" +
    "</cx:chartSpace>"
  let chart = @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml))
  match chart.chart.plot_area.plot_area_region.series[0].layout_id {
    Other(name) => assert_eq(name, "futurePlot2030")
    _ => fail("expected Other(futurePlot2030)")
  }
}

///|
test "ChartEx::parse: series carry attribute payload" {
  // Series formatIdx / hidden / ownerIdx attributes lift to typed
  // fields; the rest of the body still rides as captured XmlElement.
  let xml = "<?xml version=\"1.0\"?>" +
    "<cx:chartSpace xmlns:cx=\"" +
    chart_ex_ns +
    "\">" +
    "<cx:chart>" +
    "<cx:plotArea>" +
    "<cx:plotAreaRegion>" +
    "<cx:series layoutId=\"waterfall\" formatIdx=\"3\" hidden=\"1\" ownerIdx=\"2\"><cx:dataId val=\"0\"/></cx:series>" +
    "</cx:plotAreaRegion>" +
    "</cx:plotArea>" +
    "</cx:chart>" +
    "</cx:chartSpace>"
  let chart = @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml))
  let s = chart.chart.plot_area.plot_area_region.series[0]
  assert_eq(s.format_idx.unwrap(), 3)
  assert_eq(s.hidden.unwrap(), true)
  assert_eq(s.owner_idx.unwrap(), 2)
}

///|
test "ChartEx::parse: rejects <cx:series> without layoutId" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<cx:chartSpace xmlns:cx=\"" +
    chart_ex_ns +
    "\">" +
    "<cx:chart>" +
    "<cx:plotArea>" +
    "<cx:plotAreaRegion>" +
    "<cx:series><cx:dataId val=\"0\"/></cx:series>" +
    "</cx:plotAreaRegion>" +
    "</cx:plotArea>" +
    "</cx:chart>" +
    "</cx:chartSpace>"
  try @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed for series without layoutId")
  }
}

///|
test "ChartEx::parse: rejects <cx:chart> without <cx:plotArea>" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<cx:chartSpace xmlns:cx=\"" +
    chart_ex_ns +
    "\"><cx:chart/></cx:chartSpace>"
  try @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed for chart without plotArea")
  }
}

///|
test "ChartExKind enum round-trips through from_xml/to_xml" {
  for
    k in [
      @chart_ex.ChartExKind::BoxWhisker,
      @chart_ex.ChartExKind::ClusteredColumn,
      @chart_ex.ChartExKind::Funnel,
      @chart_ex.ChartExKind::ParetoLine,
      @chart_ex.ChartExKind::RegionMap,
      @chart_ex.ChartExKind::Sunburst,
      @chart_ex.ChartExKind::Treemap,
      @chart_ex.ChartExKind::Waterfall,
      @chart_ex.ChartExKind::Histogram,
    ] {
    assert_eq(@chart_ex.ChartExKind::from_xml(k.to_xml()), k)
  }
  // Other variants round-trip too.
  let unknown = @chart_ex.ChartExKind::Other("xyz")
  assert_eq(@chart_ex.ChartExKind::from_xml(unknown.to_xml()), unknown)
}

///|
test "ChartEx::parse: rejects standard <c:chartSpace> root" {
  // The standard chart namespace must not be accepted here — that's
  // for the @chart package, not @chart_ex.
  let standard_ns = "http://schemas.openxmlformats.org/drawingml/2006/chart"
  let xml = "<?xml version=\"1.0\"?><c:chartSpace xmlns:c=\"" +
    standard_ns +
    "\"/>"
  try @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed for standard chartSpace root")
  }
}

///|
test "ChartEx::parse: rejects non-chartSpace root" {
  let xml = "<?xml version=\"1.0\"?><cx:notChart xmlns:cx=\"" +
    chart_ex_ns +
    "\"/>"
  try @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed for non-chart root")
  }
}

///|
test "ChartEx::serialize: round-trips through parse → serialize → parse" {
  let original = @chart_ex.ChartEx::parse(
    @oxml.string_to_bytes(typical_waterfall_xml()),
  )
  let bytes = original.serialize()
  let re_parsed = @chart_ex.ChartEx::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "ChartEx::serialize: minimal chartSpace round-trips" {
  // Smallest schema-valid chartEx: one series in one
  // plot-area-region inside one chart.
  let xml = "<?xml version=\"1.0\"?><cx:chartSpace xmlns:cx=\"" +
    chart_ex_ns +
    "\">" +
    "<cx:chart><cx:plotArea><cx:plotAreaRegion>" +
    "<cx:series layoutId=\"waterfall\"/>" +
    "</cx:plotAreaRegion></cx:plotArea></cx:chart>" +
    "</cx:chartSpace>"
  let original = @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml))
  let bytes = original.serialize()
  let re_parsed = @chart_ex.ChartEx::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "ChartEx::serialize: foreign-namespace siblings survive" {
  let xml = "<?xml version=\"1.0\"?><cx:chartSpace xmlns:cx=\"" +
    chart_ex_ns +
    "\" xmlns:foo=\"http://example.com/foo\">" +
    "<cx:chart><cx:plotArea><cx:plotAreaRegion>" +
    "<cx:series layoutId=\"funnel\"/>" +
    "</cx:plotAreaRegion></cx:plotArea></cx:chart>" +
    "<foo:bar payload=\"42\"/>" +
    "</cx:chartSpace>"
  let original = @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml))
  let bytes = original.serialize()
  let re_parsed = @chart_ex.ChartEx::parse(bytes)
  assert_eq(re_parsed, original)
}
