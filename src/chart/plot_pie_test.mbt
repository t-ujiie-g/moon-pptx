// Pie-chart parser / writer tests (Phase 7a3d).

///|
fn fixture_pie_chart_xml(body : String) -> FixedArray[Byte] {
  // Pie charts have no axes, so the plotArea need not carry catAx /
  // valAx. PowerPoint nevertheless tolerates them; we omit to keep
  // the fixture minimal.
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
test "PieChart: empty body parses successfully (no required children)" {
  let body = "<c:pieChart/>"
  let chart = @chart.Chart::parse(fixture_pie_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    PieChart(b) => {
      assert_true(b.vary_colors is None)
      assert_eq(b.series.length(), 0)
      assert_true(b.first_slice_ang is None)
    }
    _ => fail("expected PieChart plot")
  }
}

///|
test "PieChart: full field set" {
  let body = "<c:pieChart>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:firstSliceAng val=\"90\"/>" +
    "</c:pieChart>"
  let chart = @chart.Chart::parse(fixture_pie_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    PieChart(b) => {
      assert_eq(b.vary_colors.unwrap(), true)
      assert_eq(b.series.length(), 1)
      assert_eq(b.first_slice_ang.unwrap(), 90)
    }
    _ => fail("expected PieChart plot")
  }
}

///|
test "PieChart: parse → serialize → parse round-trip" {
  let body = "<c:pieChart>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/><c:order val=\"0\"/></c:ser>" +
    "<c:ser><c:idx val=\"1\"/><c:order val=\"1\"/></c:ser>" +
    "<c:firstSliceAng val=\"45\"/>" +
    "</c:pieChart>"
  let original = @chart.Chart::parse(fixture_pie_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}
