// Surface-chart parser / writer tests (2-D + 3-D).

///|
fn fixture_surface_chart_xml(body : String) -> FixedArray[Byte] {
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
test "SurfaceChart: wireframe + ax_ids" {
  let body = "<c:surfaceChart>" +
    "<c:wireframe val=\"1\"/>" +
    "<c:ser><c:idx val=\"0\"/></c:ser>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "<c:axId val=\"3\"/>" +
    "</c:surfaceChart>"
  let chart = @chart.Chart::parse(fixture_surface_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    SurfaceChart(b) => {
      assert_eq(b.wireframe.unwrap(), true)
      assert_eq(b.series.length(), 1)
      assert_eq(b.ax_ids.length(), 3)
    }
    _ => fail("expected SurfaceChart plot")
  }
}

///|
test "SurfaceChart: round-trip" {
  let body = "<c:surfaceChart>" +
    "<c:wireframe val=\"0\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:surfaceChart>"
  let original = @chart.Chart::parse(fixture_surface_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Surface3DChart: three axIds" {
  let body = "<c:surface3DChart>" +
    "<c:wireframe val=\"1\"/>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "<c:axId val=\"3\"/>" +
    "</c:surface3DChart>"
  let chart = @chart.Chart::parse(fixture_surface_chart_xml(body))
  match chart.chart.plot_area.plots[0] {
    Surface3DChart(b) => {
      assert_eq(b.wireframe.unwrap(), true)
      assert_eq(b.ax_ids.length(), 3)
    }
    _ => fail("expected Surface3DChart plot")
  }
}

///|
test "Surface3DChart: round-trip" {
  let body = "<c:surface3DChart>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "<c:axId val=\"3\"/>" +
    "</c:surface3DChart>"
  let original = @chart.Chart::parse(fixture_surface_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}
