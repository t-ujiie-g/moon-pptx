// ChartLegend typed parser / writer tests.

///|
fn fixture_legend_chart_xml(legend_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:a=\"" +
    drawing_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea/>" +
    legend_body +
    "</c:chart>" +
    "</c:chartSpace>"
  fixture_bytes(xml)
}

///|
test "ChartLegend: empty legend parses to empty body" {
  let chart = @chart.Chart::parse(fixture_legend_chart_xml("<c:legend/>"))
  let lg = chart.chart.legend.unwrap()
  assert_true(lg.legend_pos is None)
  assert_eq(lg.legend_entries.length(), 0)
  assert_true(lg.overlay is None)
}

///|
test "ChartLegend: legendPos every variant" {
  let cases = ["b", "tr", "l", "r", "t"]
  for v in cases {
    let body = "<c:legend>" + "<c:legendPos val=\"" + v + "\"/>" + "</c:legend>"
    let original = @chart.Chart::parse(fixture_legend_chart_xml(body))
    let bytes = original.serialize()
    let re_parsed = @chart.Chart::parse(bytes)
    assert_eq(re_parsed, original)
  }
}

///|
test "ChartLegend: typed values lift correctly" {
  let body = "<c:legend>" +
    "<c:legendPos val=\"r\"/>" +
    "<c:overlay val=\"0\"/>" +
    "</c:legend>"
  let chart = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let lg = chart.chart.legend.unwrap()
  assert_true(lg.legend_pos is Some(LegendRight))
  assert_eq(lg.overlay.unwrap(), false)
}

///|
test "ChartLegend: legendEntry collected with idx + delete" {
  let body = "<c:legend>" +
    "<c:legendPos val=\"b\"/>" +
    "<c:legendEntry>" +
    "<c:idx val=\"0\"/>" +
    "<c:delete val=\"1\"/>" +
    "</c:legendEntry>" +
    "<c:legendEntry>" +
    "<c:idx val=\"2\"/>" +
    "</c:legendEntry>" +
    "</c:legend>"
  let chart = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let lg = chart.chart.legend.unwrap()
  assert_eq(lg.legend_entries.length(), 2)
  assert_eq(lg.legend_entries[0].idx, 0)
  assert_eq(lg.legend_entries[0].delete.unwrap(), true)
  assert_eq(lg.legend_entries[1].idx, 2)
  assert_true(lg.legend_entries[1].delete is None)
}

///|
test "ChartLegend: legendEntry without idx raises Malformed" {
  let body = "<c:legend>" +
    "<c:legendEntry><c:delete val=\"1\"/></c:legendEntry>" +
    "</c:legend>"
  try @chart.Chart::parse(fixture_legend_chart_xml(body)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed for legendEntry without idx")
  }
}

///|
test "ChartLegend: layout / spPr / txPr captured" {
  let body = "<c:legend>" +
    "<c:legendPos val=\"r\"/>" +
    "<c:layout/>" +
    "<c:overlay val=\"0\"/>" +
    "<c:spPr/>" +
    "<c:txPr><a:bodyPr/></c:txPr>" +
    "</c:legend>"
  let original = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let lg = original.chart.legend.unwrap()
  assert_true(lg.layout is Some(_))
  assert_true(lg.sp_pr is Some(_))
  assert_true(lg.tx_pr is Some(_))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "ChartLegend: legendEntry txPr captured + round-trips" {
  let body = "<c:legend>" +
    "<c:legendEntry>" +
    "<c:idx val=\"1\"/>" +
    "<c:txPr><a:bodyPr/></c:txPr>" +
    "</c:legendEntry>" +
    "</c:legend>"
  let original = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let entry = original.chart.legend.unwrap().legend_entries[0]
  assert_true(entry.tx_pr is Some(_))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "ChartLegend: extLst rides on extension and round-trips" {
  let body = "<c:legend>" +
    "<c:legendPos val=\"b\"/>" +
    "<c:extLst><c:ext uri=\"{X}\"/></c:extLst>" +
    "</c:legend>"
  let original = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let lg = original.chart.legend.unwrap()
  assert_eq(lg.extension.length(), 1)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "ChartLegend: out-of-source-order children re-emit canonically" {
  // Parser tolerates any order; writer emits schema order.
  let body = "<c:legend>" +
    "<c:overlay val=\"1\"/>" +
    "<c:txPr><a:bodyPr/></c:txPr>" +
    "<c:legendPos val=\"t\"/>" +
    "<c:legendEntry><c:idx val=\"0\"/></c:legendEntry>" +
    "<c:layout/>" +
    "<c:spPr/>" +
    "</c:legend>"
  let original = @chart.Chart::parse(fixture_legend_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}
