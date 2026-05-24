// Bar-chart parser / writer tests (Phase 7a3b).

///|
fn fixture_bar_chart_xml(body : String) -> FixedArray[Byte] {
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
test "BarChart: minimum (barDir + axIds) types correctly" {
  let body = "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>"
  let chart = @chart.Chart::parse(fixture_bar_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      assert_eq(b.bar_dir, Col)
      assert_true(b.grouping is None)
      assert_eq(b.ax_ids.length(), 2)
      assert_eq(b.ax_ids[0], 1)
      assert_eq(b.ax_ids[1], 2)
      assert_eq(b.series.length(), 0)
    }
    _ => fail("expected BarChart plot")
  }
}

///|
test "BarChart: full scalar field set" {
  let body = "<c:barChart>" +
    "<c:barDir val=\"bar\"/>" +
    "<c:grouping val=\"stacked\"/>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:gapWidth val=\"150\"/>" +
    "<c:overlap val=\"-25\"/>" +
    "<c:axId val=\"10\"/>" +
    "<c:axId val=\"20\"/>" +
    "</c:barChart>"
  let chart = @chart.Chart::parse(fixture_bar_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      assert_eq(b.bar_dir, Bar)
      assert_true(b.grouping is Some(Stacked))
      assert_eq(b.vary_colors.unwrap(), true)
      assert_eq(b.gap_width.unwrap(), 150)
      assert_eq(b.overlap.unwrap(), -25)
      assert_eq(b.ax_ids[0], 10)
      assert_eq(b.ax_ids[1], 20)
    }
    _ => fail("expected BarChart plot")
  }
}

///|
test "BarChart: missing <c:barDir> raises Malformed" {
  let body = "<c:barChart>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>"
  let bytes = fixture_bar_chart_xml(body)
  let raised = try? @chart.Chart::parse(bytes)
  match raised {
    Err(_) => ()
    Ok(_) => fail("expected Malformed for barChart without barDir")
  }
}

///|
test "BarChart: <c:ser> children captured verbatim until typed" {
  // A single series with a few inner children. The 7a3b slice doesn't
  // type CT_BarSer; only verifies the captured payload survives.
  let body = "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:ser>" +
    "<c:idx val=\"0\"/>" +
    "<c:order val=\"0\"/>" +
    "<c:tx><c:strRef><c:f>S1!$B$1</c:f></c:strRef></c:tx>" +
    "</c:ser>" +
    "<c:ser>" +
    "<c:idx val=\"1\"/>" +
    "<c:order val=\"1\"/>" +
    "</c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>"
  let chart = @chart.Chart::parse(fixture_bar_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => assert_eq(b.series.length(), 2)
    _ => fail("expected BarChart plot")
  }
}

///|
test "BarChart: parse → serialize → parse round-trip" {
  let body = "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:grouping val=\"clustered\"/>" +
    "<c:varyColors val=\"0\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:gapWidth val=\"150\"/>" +
    "<c:overlap val=\"100\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>"
  let original = @chart.Chart::parse(fixture_bar_chart_xml(body))
  let serialized = original.serialize()
  let re_parsed = @chart.Chart::parse(serialized)
  assert_eq(re_parsed, original)
}

///|
test "BarDir / BarGrouping enum round-trips" {
  // Direct enum check — every `to_xml` value must round-trip through
  // `from_xml` to the same value.
  for d in [@chart.BarDir::Bar, @chart.BarDir::Col] {
    assert_true(@chart.BarDir::from_xml(d.to_xml()) is Some(_))
    assert_eq(@chart.BarDir::from_xml(d.to_xml()).unwrap(), d)
  }
  for
    g in [
      @chart.BarGrouping::PercentStacked,
      @chart.BarGrouping::Clustered,
      @chart.BarGrouping::Standard,
      @chart.BarGrouping::Stacked,
    ] {
    assert_true(@chart.BarGrouping::from_xml(g.to_xml()) is Some(_))
    assert_eq(@chart.BarGrouping::from_xml(g.to_xml()).unwrap(), g)
  }
}
