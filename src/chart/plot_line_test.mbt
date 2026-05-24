// Line-chart parser / writer tests (Phase 7a3c).

///|
fn fixture_line_chart_xml(body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    body +
    "<c:catAx><c:axId val=\"1\"/></c:catAx>" +
    "<c:valAx><c:axId val=\"2\"/></c:valAx>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  fixture_bytes(xml)
}

///|
test "LineChart: minimum (grouping + axIds) types correctly" {
  let body = "<c:lineChart>" +
    "<c:grouping val=\"standard\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>"
  let chart = @chart.Chart::parse(fixture_line_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    LineChart(b) => {
      assert_eq(b.grouping, Standard)
      assert_eq(b.ax_ids.length(), 2)
      assert_eq(b.ax_ids[0], 1)
      assert_eq(b.ax_ids[1], 2)
    }
    _ => fail("expected LineChart plot")
  }
}

///|
test "LineChart: marker + smooth round-trip" {
  let body = "<c:lineChart>" +
    "<c:grouping val=\"stacked\"/>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:marker val=\"1\"/>" +
    "<c:smooth val=\"0\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>"
  let chart = @chart.Chart::parse(fixture_line_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    LineChart(b) => {
      assert_eq(b.grouping, Stacked)
      assert_eq(b.vary_colors.unwrap(), true)
      assert_eq(b.marker.unwrap(), true)
      assert_eq(b.smooth.unwrap(), false)
      assert_eq(b.series.length(), 1)
    }
    _ => fail("expected LineChart plot")
  }
}

///|
test "LineChart: dropLines / hiLowLines / upDownBars round-trip via capture" {
  let body = "<c:lineChart>" +
    "<c:grouping val=\"standard\"/>" +
    "<c:dropLines/>" +
    "<c:hiLowLines/>" +
    "<c:upDownBars><c:gapWidth val=\"150\"/></c:upDownBars>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>"
  let original = @chart.Chart::parse(fixture_line_chart_xml(body))
  match original.chart.plot_area.plots[0] {
    LineChart(b) => {
      assert_true(b.drop_lines is Some(_))
      assert_true(b.hi_low_lines is Some(_))
      assert_true(b.up_down_bars is Some(_))
    }
    _ => fail("expected LineChart plot")
  }
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "LineChart: missing <c:grouping> raises Malformed" {
  let body = "<c:lineChart>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>"
  let bytes = fixture_line_chart_xml(body)
  let raised = try? @chart.Chart::parse(bytes)
  match raised {
    Err(_) => ()
    Ok(_) => fail("expected Malformed for lineChart without grouping")
  }
}

///|
test "LineChart: combined with BarChart in one plotArea" {
  // Combination chart — a typed BarChart and a typed LineChart side
  // by side. Verifies the parser handles the heterogeneous plot list.
  let body = "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>" +
    "<c:lineChart>" +
    "<c:grouping val=\"standard\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>"
  let chart = @chart.Chart::parse(fixture_line_chart_xml(body))
  assert_eq(chart.chart.plot_area.plots.length(), 2)
  assert_true(chart.chart.plot_area.plots[0] is BarChart(_))
  assert_true(chart.chart.plot_area.plots[1] is LineChart(_))
}

///|
test "Grouping enum round-trips" {
  for
    g in [
      @chart.Grouping::Standard,
      @chart.Grouping::Stacked,
      @chart.Grouping::PercentStacked,
    ] {
    assert_true(@chart.Grouping::from_xml(g.to_xml()) is Some(_))
    assert_eq(@chart.Grouping::from_xml(g.to_xml()).unwrap(), g)
  }
}
