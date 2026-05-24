// Doughnut-chart parser / writer tests.

///|
fn fixture_doughnut_chart_xml(body : String) -> FixedArray[Byte] {
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
test "DoughnutChart: holeSize lifts" {
  let body = "<c:doughnutChart>" +
    "<c:varyColors val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:firstSliceAng val=\"0\"/>" +
    "<c:holeSize val=\"50\"/>" +
    "</c:doughnutChart>"
  let chart = @chart.Chart::parse(fixture_doughnut_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    DoughnutChart(b) => {
      assert_eq(b.hole_size.unwrap(), 50)
      assert_eq(b.first_slice_ang.unwrap(), 0)
    }
    _ => fail("expected DoughnutChart plot")
  }
}

///|
test "DoughnutChart: round-trip" {
  let body = "<c:doughnutChart>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:holeSize val=\"50\"/>" +
    "</c:doughnutChart>"
  let original = @chart.Chart::parse(fixture_doughnut_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}
