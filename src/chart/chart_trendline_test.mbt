// CT_Trendline typed parser / writer tests.

///|
fn fixture_trendline_in_bar(trendline_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:ser>" +
    "<c:idx val=\"0\"/>" +
    "<c:order val=\"0\"/>" +
    trendline_body +
    "</c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  fixture_bytes(xml)
}

///|
fn first_trendline(chart : @chart.Chart) -> Trendline {
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => b.series[0].trendlines[0]
    _ => abort("expected BarChart")
  }
}

///|
test "Trendline: minimal linear trendline lifts" {
  let body = "<c:trendline><c:trendlineType val=\"linear\"/></c:trendline>"
  let chart = @chart.Chart::parse(fixture_trendline_in_bar(body))
  let t = first_trendline(chart)
  assert_true(t.trendline_type is TrendlineLinear)
  assert_true(t.order is None)
  assert_true(t.period is None)
}

///|
test "Trendline: trendlineType every variant round-trips" {
  let cases = ["exp", "linear", "log", "movingAvg", "poly", "power"]
  for v in cases {
    let body = "<c:trendline><c:trendlineType val=\"" + v + "\"/></c:trendline>"
    let original = @chart.Chart::parse(fixture_trendline_in_bar(body))
    let bytes = original.serialize()
    let re_parsed = @chart.Chart::parse(bytes)
    assert_eq(re_parsed, original)
  }
}

///|
test "Trendline: polynomial with order" {
  let body = "<c:trendline>" +
    "<c:trendlineType val=\"poly\"/>" +
    "<c:order val=\"3\"/>" +
    "</c:trendline>"
  let chart = @chart.Chart::parse(fixture_trendline_in_bar(body))
  let t = first_trendline(chart)
  assert_true(t.trendline_type is TrendlinePoly)
  assert_eq(t.order.unwrap(), 3)
}

///|
test "Trendline: movingAvg with period" {
  let body = "<c:trendline>" +
    "<c:trendlineType val=\"movingAvg\"/>" +
    "<c:period val=\"5\"/>" +
    "</c:trendline>"
  let chart = @chart.Chart::parse(fixture_trendline_in_bar(body))
  let t = first_trendline(chart)
  assert_true(t.trendline_type is TrendlineMovingAvg)
  assert_eq(t.period.unwrap(), 5)
}

///|
test "Trendline: forward / backward / intercept as String?" {
  let body = "<c:trendline>" +
    "<c:trendlineType val=\"linear\"/>" +
    "<c:forward val=\"2.5\"/>" +
    "<c:backward val=\"1.5\"/>" +
    "<c:intercept val=\"0.0\"/>" +
    "</c:trendline>"
  let chart = @chart.Chart::parse(fixture_trendline_in_bar(body))
  let t = first_trendline(chart)
  assert_eq(t.forward.unwrap(), "2.5")
  assert_eq(t.backward.unwrap(), "1.5")
  assert_eq(t.intercept.unwrap(), "0.0")
}

///|
test "Trendline: dispRSqr and dispEq Bools lift" {
  let body = "<c:trendline>" +
    "<c:trendlineType val=\"linear\"/>" +
    "<c:dispRSqr val=\"1\"/>" +
    "<c:dispEq val=\"0\"/>" +
    "</c:trendline>"
  let chart = @chart.Chart::parse(fixture_trendline_in_bar(body))
  let t = first_trendline(chart)
  assert_eq(t.disp_r_sqr.unwrap(), true)
  assert_eq(t.disp_eq.unwrap(), false)
}

///|
test "Trendline: name text content round-trips" {
  let body = "<c:trendline>" +
    "<c:name>My Trend</c:name>" +
    "<c:trendlineType val=\"exp\"/>" +
    "</c:trendline>"
  let chart = @chart.Chart::parse(fixture_trendline_in_bar(body))
  let t = first_trendline(chart)
  assert_eq(t.name.unwrap(), "My Trend")
}

///|
test "Trendline: spPr and trendlineLbl subtrees captured" {
  let body = "<c:trendline>" +
    "<c:spPr/>" +
    "<c:trendlineType val=\"linear\"/>" +
    "<c:trendlineLbl><c:layout/></c:trendlineLbl>" +
    "</c:trendline>"
  let chart = @chart.Chart::parse(fixture_trendline_in_bar(body))
  let t = first_trendline(chart)
  assert_true(t.sp_pr is Some(_))
  assert_true(t.trendline_lbl is Some(_))
}

///|
test "Trendline: missing trendlineType raises Malformed" {
  let body = "<c:trendline><c:order val=\"2\"/></c:trendline>"
  let raised = try? @chart.Chart::parse(fixture_trendline_in_bar(body))
  match raised {
    Err(_) => ()
    Ok(_) => fail("expected Malformed for trendline without trendlineType")
  }
}

///|
test "Trendline: multiple trendlines per series" {
  let body = "<c:trendline><c:trendlineType val=\"linear\"/></c:trendline>" +
    "<c:trendline><c:trendlineType val=\"exp\"/></c:trendline>"
  let chart = @chart.Chart::parse(fixture_trendline_in_bar(body))
  let trends = match chart.chart.plot_area.plots[0] {
    BarChart(b) => b.series[0].trendlines
    _ => abort("expected BarChart")
  }
  assert_eq(trends.length(), 2)
  assert_true(trends[0].trendline_type is TrendlineLinear)
  assert_true(trends[1].trendline_type is TrendlineExp)
}

///|
test "Trendline: full body round-trips" {
  let body = "<c:trendline>" +
    "<c:name>Forecast</c:name>" +
    "<c:spPr/>" +
    "<c:trendlineType val=\"poly\"/>" +
    "<c:order val=\"3\"/>" +
    "<c:forward val=\"5\"/>" +
    "<c:backward val=\"0\"/>" +
    "<c:dispRSqr val=\"1\"/>" +
    "<c:dispEq val=\"1\"/>" +
    "</c:trendline>"
  let original = @chart.Chart::parse(fixture_trendline_in_bar(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Trendline: scatter series trendlines" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    "<c:scatterChart>" +
    "<c:scatterStyle val=\"smooth\"/>" +
    "<c:ser>" +
    "<c:idx val=\"0\"/>" +
    "<c:order val=\"0\"/>" +
    "<c:trendline><c:trendlineType val=\"linear\"/></c:trendline>" +
    "</c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:scatterChart>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(xml))
  let trends = match original.chart.plot_area.plots[0] {
    ScatterChart(s) => s.series[0].trendlines
    _ => abort("expected ScatterChart")
  }
  assert_eq(trends.length(), 1)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Trendline: bubble series trendlines" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    "<c:bubbleChart>" +
    "<c:ser>" +
    "<c:idx val=\"0\"/>" +
    "<c:order val=\"0\"/>" +
    "<c:trendline><c:trendlineType val=\"log\"/></c:trendline>" +
    "</c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:bubbleChart>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(xml))
  let trends = match original.chart.plot_area.plots[0] {
    BubbleChart(b) => b.series[0].trendlines
    _ => abort("expected BubbleChart")
  }
  assert_eq(trends.length(), 1)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}
