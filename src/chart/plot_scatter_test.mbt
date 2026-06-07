// Scatter-chart parser / writer tests.

///|
fn fixture_scatter_chart_xml(body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    body +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  fixture_bytes(xml)
}

///|
test "ScatterChart: scatterStyle is required" {
  let body = "<c:scatterChart>" +
    "<c:scatterStyle val=\"lineMarker\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:scatterChart>"
  let chart = @chart.Chart::parse(fixture_scatter_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    ScatterChart(b) => {
      assert_eq(b.scatter_style, LineMarker)
      assert_eq(b.series.length(), 1)
      assert_eq(b.ax_ids.length(), 2)
    }
    _ => fail("expected ScatterChart plot")
  }
}

///|
test "ScatterChart: missing scatterStyle raises Malformed" {
  let body = "<c:scatterChart>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:scatterChart>"
  try @chart.Chart::parse(fixture_scatter_chart_xml(body)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "ScatterChart: round-trip" {
  let body = "<c:scatterChart>" +
    "<c:scatterStyle val=\"smooth\"/>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:scatterChart>"
  let original = @chart.Chart::parse(fixture_scatter_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "ScatterStyle enum round-trips" {
  for
    s in [
      @chart.ScatterStyle::Line,
      @chart.ScatterStyle::LineMarker,
      @chart.ScatterStyle::Marker,
      @chart.ScatterStyle::None_,
      @chart.ScatterStyle::Smooth,
      @chart.ScatterStyle::SmoothMarker,
    ] {
    assert_eq(@chart.ScatterStyle::from_xml(s.to_xml()).unwrap(), s)
  }
}
