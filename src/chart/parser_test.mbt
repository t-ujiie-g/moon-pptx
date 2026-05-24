// Chart parser tests (Phase 7a1).

///|
let chart_ns : String = "http://schemas.openxmlformats.org/drawingml/2006/chart"

///|
let drawing_ns : String = "http://schemas.openxmlformats.org/drawingml/2006/main"

///|
let r_ns : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

///|
fn fixture_bytes(s : String) -> FixedArray[Byte] {
  let buf : Array[Int] = []
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      buf.push(cp)
    } else if cp < 0x800 {
      buf.push(0xC0 | (cp >> 6))
      buf.push(0x80 | (cp & 0x3F))
    } else if cp < 0x10000 {
      buf.push(0xE0 | (cp >> 12))
      buf.push(0x80 | ((cp >> 6) & 0x3F))
      buf.push(0x80 | (cp & 0x3F))
    } else {
      buf.push(0xF0 | (cp >> 18))
      buf.push(0x80 | ((cp >> 12) & 0x3F))
      buf.push(0x80 | ((cp >> 6) & 0x3F))
      buf.push(0x80 | (cp & 0x3F))
    }
  }
  let bytes = FixedArray::make(buf.length(), b'\x00')
  let mut i = 0
  while i < buf.length() {
    bytes[i] = buf[i].to_byte()
    i = i + 1
  }
  bytes
}

///|
/// Minimal but spec-shaped `<c:chartSpace>` body — one `<c:chart>` child
/// carrying an empty plotArea. Captures the structure we need for the
/// 7a1 round-trip floor; later 7a slices lift the inner pieces.
fn typical_chart_xml() -> String {
  "<?xml version=\"1.0\"?>" +
  "<c:chartSpace xmlns:c=\"" +
  chart_ns +
  "\" xmlns:a=\"" +
  drawing_ns +
  "\" xmlns:r=\"" +
  r_ns +
  "\">" +
  "<c:chart>" +
  "<c:plotArea>" +
  "<c:layout/>" +
  "<c:barChart>" +
  "<c:barDir val=\"col\"/>" +
  "<c:grouping val=\"clustered\"/>" +
  "</c:barChart>" +
  "</c:plotArea>" +
  "</c:chart>" +
  "</c:chartSpace>"
}

///|
test "Chart::parse: root recognised + plotArea captured" {
  let chart = @chart.Chart::parse(fixture_bytes(typical_chart_xml()))
  // <c:plotArea> is required and lifted directly to ChartBody.
  assert_eq(chart.chart.plot_area.name.uri, chart_ns)
  assert_eq(chart.chart.plot_area.name.local_name, "plotArea")
}

///|
test "Chart::parse: typed chart-body scalar fields (7a2)" {
  let chart = @chart.Chart::parse(fixture_bytes(typical_chart_xml()))
  // Our fixture has no `<c:autoTitleDeleted>` so this should be `None`.
  // Other 7a2 fields likewise.
  assert_true(chart.chart.auto_title_deleted is None)
  assert_true(chart.chart.plot_vis_only is None)
  assert_true(chart.chart.disp_blanks_as is None)
}

///|
test "Chart::parse: typed chart-body fields from rich fixture (7a2)" {
  // Build a chart that exercises every typed leaf the 7a2 slice lifts.
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:date1904 val=\"0\"/>" +
    "<c:lang val=\"en-US\"/>" +
    "<c:roundedCorners val=\"1\"/>" +
    "<c:style val=\"2\"/>" +
    "<c:chart>" +
    "<c:autoTitleDeleted val=\"1\"/>" +
    "<c:plotArea><c:layout/></c:plotArea>" +
    "<c:plotVisOnly val=\"1\"/>" +
    "<c:dispBlanksAs val=\"gap\"/>" +
    "<c:showDLblsOverMax val=\"0\"/>" +
    "</c:chart>" +
    "</c:chartSpace>"
  let chart = @chart.Chart::parse(fixture_bytes(xml))
  assert_eq(chart.date1904.unwrap(), false)
  assert_eq(chart.lang.unwrap(), "en-US")
  assert_eq(chart.rounded_corners.unwrap(), true)
  assert_eq(chart.style.unwrap(), 2)
  assert_eq(chart.chart.auto_title_deleted.unwrap(), true)
  assert_eq(chart.chart.plot_vis_only.unwrap(), true)
  assert_true(chart.chart.disp_blanks_as is Some(Gap))
  assert_eq(chart.chart.show_d_lbls_over_max.unwrap(), false)
}

///|
test "Chart::parse: rejects non-chart root" {
  let xml = "<?xml version=\"1.0\"?><c:notChart xmlns:c=\"" + chart_ns + "\"/>"
  let bytes = fixture_bytes(xml)
  let raised = try? @chart.Chart::parse(bytes)
  match raised {
    Err(_) => ()
    Ok(_) => fail("expected Malformed for non-chart root")
  }
}

///|
test "Chart::parse: rejects wrong namespace" {
  // local name matches but uri is wrong → Malformed.
  let xml = "<?xml version=\"1.0\"?><x:chartSpace xmlns:x=\"http://example.com/x\"/>"
  let bytes = fixture_bytes(xml)
  let raised = try? @chart.Chart::parse(bytes)
  match raised {
    Err(_) => ()
    Ok(_) => fail("expected Malformed for wrong-namespace root")
  }
}

///|
test "Chart::serialize: re-parse equals original (round-trip floor)" {
  let original = @chart.Chart::parse(fixture_bytes(typical_chart_xml()))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Chart::serialize: minimal chartSpace round-trips" {
  // Phase 7a2 raises on missing <c:chart> or missing <c:plotArea> per
  // the schema. This test confirms the absolute minimum valid chart
  // (just the required elements) survives parse → serialize → parse.
  let xml = "<?xml version=\"1.0\"?><c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart><c:plotArea/></c:chart>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(xml))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Chart::serialize: foreign-namespace extLst children survive" {
  let xml = "<?xml version=\"1.0\"?><c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\" xmlns:a=\"" +
    drawing_ns +
    "\">" +
    "<c:chart>" +
    "<c:autoTitleDeleted val=\"1\"/>" +
    "<c:plotArea><c:layout/></c:plotArea>" +
    "<c:extLst><c:ext uri=\"{ABC}\" xmlns:foo=\"http://example.com/foo\"><foo:bar/></c:ext></c:extLst>" +
    "</c:chart>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(xml))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Chart::parse: missing <c:chart> raises Malformed" {
  let xml = "<?xml version=\"1.0\"?><c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\"/>"
  let raised = try? @chart.Chart::parse(fixture_bytes(xml))
  match raised {
    Err(_) => ()
    Ok(_) => fail("expected Malformed for chartSpace without chart")
  }
}

///|
test "Chart::parse: missing <c:plotArea> raises Malformed" {
  let xml = "<?xml version=\"1.0\"?><c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\"><c:chart/></c:chartSpace>"
  let raised = try? @chart.Chart::parse(fixture_bytes(xml))
  match raised {
    Err(_) => ()
    Ok(_) => fail("expected Malformed for chart without plotArea")
  }
}
