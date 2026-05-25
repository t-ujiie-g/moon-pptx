// CT_Layout / CT_ManualLayout typed parser / writer tests.

///|
fn fixture_layout_in_title(layout_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:title>" +
    layout_body +
    "</c:title>" +
    "<c:plotArea/>" +
    "</c:chart>" +
    "</c:chartSpace>"
  fixture_bytes(xml)
}

///|
test "Layout: empty <c:layout/> parses to empty body" {
  let chart = @chart.Chart::parse(fixture_layout_in_title("<c:layout/>"))
  let lay = chart.chart.title.unwrap().layout.unwrap()
  assert_true(lay.manual_layout is None)
  assert_eq(lay.extension.length(), 0)
}

///|
test "Layout: manualLayout with every leaf round-trips" {
  let body = "<c:layout>" +
    "<c:manualLayout>" +
    "<c:layoutTarget val=\"inner\"/>" +
    "<c:xMode val=\"edge\"/>" +
    "<c:yMode val=\"factor\"/>" +
    "<c:wMode val=\"edge\"/>" +
    "<c:hMode val=\"factor\"/>" +
    "<c:x val=\"0.1\"/>" +
    "<c:y val=\"0.2\"/>" +
    "<c:w val=\"0.5\"/>" +
    "<c:h val=\"0.4\"/>" +
    "</c:manualLayout>" +
    "</c:layout>"
  let original = @chart.Chart::parse(fixture_layout_in_title(body))
  let ml = original.chart.title.unwrap().layout.unwrap().manual_layout.unwrap()
  assert_true(ml.layout_target is Some(LayoutInner))
  assert_true(ml.x_mode is Some(LayoutEdge))
  assert_true(ml.y_mode is Some(LayoutFactor))
  assert_true(ml.w_mode is Some(LayoutEdge))
  assert_true(ml.h_mode is Some(LayoutFactor))
  assert_eq(ml.x.unwrap(), "0.1")
  assert_eq(ml.y.unwrap(), "0.2")
  assert_eq(ml.w.unwrap(), "0.5")
  assert_eq(ml.h.unwrap(), "0.4")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Layout: layoutTarget enum every variant" {
  for v in ["inner", "outer"] {
    let body = "<c:layout><c:manualLayout><c:layoutTarget val=\"" +
      v +
      "\"/></c:manualLayout></c:layout>"
    let original = @chart.Chart::parse(fixture_layout_in_title(body))
    let bytes = original.serialize()
    let re_parsed = @chart.Chart::parse(bytes)
    assert_eq(re_parsed, original)
  }
}

///|
test "Layout: layoutMode enum every variant" {
  for v in ["edge", "factor"] {
    let body = "<c:layout><c:manualLayout><c:xMode val=\"" +
      v +
      "\"/></c:manualLayout></c:layout>"
    let original = @chart.Chart::parse(fixture_layout_in_title(body))
    let bytes = original.serialize()
    let re_parsed = @chart.Chart::parse(bytes)
    assert_eq(re_parsed, original)
  }
}

///|
test "Layout: extLst rides on extension" {
  let body = "<c:layout>" +
    "<c:manualLayout><c:x val=\"0.3\"/></c:manualLayout>" +
    "<c:extLst><c:ext uri=\"{Z}\"/></c:extLst>" +
    "</c:layout>"
  let original = @chart.Chart::parse(fixture_layout_in_title(body))
  let lay = original.chart.title.unwrap().layout.unwrap()
  assert_eq(lay.extension.length(), 1)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Layout: plotArea-level layout lifts" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    "<c:layout>" +
    "<c:manualLayout>" +
    "<c:layoutTarget val=\"outer\"/>" +
    "<c:x val=\"0\"/>" +
    "<c:y val=\"0\"/>" +
    "</c:manualLayout>" +
    "</c:layout>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(xml))
  let lay = original.chart.plot_area.layout.unwrap()
  let ml = lay.manual_layout.unwrap()
  assert_true(ml.layout_target is Some(LayoutOuter))
  assert_eq(ml.x.unwrap(), "0")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Layout: legend-level layout lifts" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea/>" +
    "<c:legend>" +
    "<c:legendPos val=\"r\"/>" +
    "<c:layout>" +
    "<c:manualLayout>" +
    "<c:x val=\"0.8\"/>" +
    "<c:wMode val=\"factor\"/>" +
    "</c:manualLayout>" +
    "</c:layout>" +
    "</c:legend>" +
    "</c:chart>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(xml))
  let lay = original.chart.legend.unwrap().layout.unwrap()
  assert_eq(lay.manual_layout.unwrap().x.unwrap(), "0.8")
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Layout: per-data-point dLbl layout lifts" {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    "<c:dLbls>" +
    "<c:dLbl>" +
    "<c:idx val=\"0\"/>" +
    "<c:layout>" +
    "<c:manualLayout><c:y val=\"-0.05\"/></c:manualLayout>" +
    "</c:layout>" +
    "<c:showVal val=\"1\"/>" +
    "</c:dLbl>" +
    "</c:dLbls>" +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(xml))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Layout: no manualLayout, only extLst" {
  // <c:layout> with only <c:extLst> (no <c:manualLayout>) is
  // legal — round-trip should preserve this.
  let body = "<c:layout>" +
    "<c:extLst><c:ext uri=\"{abc}\"/></c:extLst>" +
    "</c:layout>"
  let original = @chart.Chart::parse(fixture_layout_in_title(body))
  let lay = original.chart.title.unwrap().layout.unwrap()
  assert_true(lay.manual_layout is None)
  assert_eq(lay.extension.length(), 1)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}
