// Of-pie chart parser / writer tests.

///|
fn fixture_ofpie_chart_xml(body : String) -> FixedArray[Byte] {
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
test "OfPieChart: pie-of-pie variant" {
  let body = "<c:ofPieChart>" +
    "<c:ofPieType val=\"pie\"/>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:gapWidth val=\"150\"/>" +
    "<c:splitType val=\"percent\"/>" +
    "<c:splitPos val=\"10\"/>" +
    "<c:secondPieSize val=\"75\"/>" +
    "</c:ofPieChart>"
  let chart = @chart.Chart::parse(fixture_ofpie_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    OfPieChart(b) => {
      assert_eq(b.of_pie_type, Pie)
      assert_true(b.split_type is Some(Percent))
      assert_eq(b.split_pos.unwrap(), "10")
      assert_eq(b.second_pie_size.unwrap(), 75)
    }
    _ => fail("expected OfPieChart plot")
  }
}

///|
test "OfPieChart: bar-of-pie + custSplit" {
  let body = "<c:ofPieChart>" +
    "<c:ofPieType val=\"bar\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:splitType val=\"cust\"/>" +
    "<c:custSplit><c:secondPiePt val=\"3\"/></c:custSplit>" +
    "<c:serLines/>" +
    "</c:ofPieChart>"
  let chart = @chart.Chart::parse(fixture_ofpie_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    OfPieChart(b) => {
      assert_eq(b.of_pie_type, Bar)
      assert_true(b.split_type is Some(Cust))
      assert_true(b.cust_split is Some(_))
      assert_eq(b.ser_lines.length(), 1)
    }
    _ => fail("expected OfPieChart plot")
  }
}

///|
test "OfPieChart: missing ofPieType raises Malformed" {
  let body = "<c:ofPieChart>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "</c:ofPieChart>"
  try @chart.Chart::parse(fixture_ofpie_chart_xml(body)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "OfPieChart: round-trip" {
  let body = "<c:ofPieChart>" +
    "<c:ofPieType val=\"bar\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:gapWidth val=\"150\"/>" +
    "<c:splitType val=\"auto\"/>" +
    "</c:ofPieChart>"
  let original = @chart.Chart::parse(fixture_ofpie_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "OfPieType + SplitType enums round-trip" {
  for t in [@chart.OfPieType::Pie, @chart.OfPieType::Bar] {
    assert_eq(@chart.OfPieType::from_xml(t.to_xml()).unwrap(), t)
  }
  for
    s in [
      @chart.SplitType::Auto,
      @chart.SplitType::Cust,
      @chart.SplitType::Percent,
      @chart.SplitType::Pos,
      @chart.SplitType::Val,
    ] {
    assert_eq(@chart.SplitType::from_xml(s.to_xml()).unwrap(), s)
  }
}
