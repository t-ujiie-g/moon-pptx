// Stock-chart parser / writer tests.

///|
fn fixture_stock_chart_xml(body : String) -> FixedArray[Byte] {
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
test "StockChart: HLC variant (three series)" {
  let body = "<c:stockChart>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:ser><c:idx val=\"1\"/></c:ser>" +
    "<c:ser><c:idx val=\"2\"/></c:ser>" +
    "<c:hiLowLines/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:stockChart>"
  let chart = @chart.Chart::parse(fixture_stock_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    StockChart(b) => {
      assert_eq(b.series.length(), 3)
      assert_true(b.hi_low_lines is Some(_))
      assert_eq(b.ax_ids.length(), 2)
    }
    _ => fail("expected StockChart plot")
  }
}

///|
test "StockChart: OHLC variant (four series) round-trips" {
  let body = "<c:stockChart>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:ser><c:idx val=\"1\"/></c:ser>" +
    "<c:ser><c:idx val=\"2\"/></c:ser>" +
    "<c:ser><c:idx val=\"3\"/></c:ser>" +
    "<c:upDownBars><c:gapWidth val=\"150\"/></c:upDownBars>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:stockChart>"
  let original = @chart.Chart::parse(fixture_stock_chart_xml(body))
  match original.chart.plot_area.plots[0] {
    StockChart(b) => {
      assert_eq(b.series.length(), 4)
      assert_true(b.up_down_bars is Some(_))
    }
    _ => fail("expected StockChart plot")
  }
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}
