// Radar-chart parser / writer tests.

///|
fn fixture_radar_chart_xml(body : String) -> FixedArray[Byte] {
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
test "RadarChart: radarStyle is required" {
  let body = "<c:radarChart>" +
    "<c:radarStyle val=\"filled\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:radarChart>"
  let chart = @chart.Chart::parse(fixture_radar_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    RadarChart(b) => {
      assert_eq(b.radar_style, Filled)
      assert_eq(b.ax_ids.length(), 2)
    }
    _ => fail("expected RadarChart plot")
  }
}

///|
test "RadarChart: missing radarStyle raises Malformed" {
  let body = "<c:radarChart>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:radarChart>"
  try @chart.Chart::parse(fixture_radar_chart_xml(body)) catch {
    _ => ()
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
test "RadarChart: round-trip" {
  let body = "<c:radarChart>" +
    "<c:radarStyle val=\"marker\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:radarChart>"
  let original = @chart.Chart::parse(fixture_radar_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "RadarStyle enum round-trips" {
  for
    s in [
      @chart.RadarStyle::Standard,
      @chart.RadarStyle::Marker,
      @chart.RadarStyle::Filled,
    ] {
    assert_eq(@chart.RadarStyle::from_xml(s.to_xml()).unwrap(), s)
  }
}

///|
test "BarShape enum round-trips" {
  // BarShape is exercised by Bar3DChart but the round-trip test for
  // the enum itself lives here next to RadarStyle's — both are small
  // tag-style enums and grouping them keeps the test file count down.
  for
    s in [
      @chart.BarShape::Box,
      @chart.BarShape::Cone,
      @chart.BarShape::ConeToMax,
      @chart.BarShape::Cylinder,
      @chart.BarShape::Pyramid,
      @chart.BarShape::PyramidToMax,
    ] {
    assert_eq(@chart.BarShape::from_xml(s.to_xml()).unwrap(), s)
  }
}
