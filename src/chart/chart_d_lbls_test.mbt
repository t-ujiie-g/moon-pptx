// DLbls typed parser / writer tests.

///|
fn fixture_d_lbls_bar_chart_xml(d_lbls_body : String) -> FixedArray[Byte] {
  let xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    "<c:barChart>" +
    "<c:barDir val=\"col\"/>" +
    d_lbls_body +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:barChart>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  fixture_bytes(xml)
}

///|
fn unwrap_bar_d_lbls(chart : @chart.Chart) -> DLbls {
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => b.d_lbls.unwrap()
    _ => abort("expected BarChart")
  }
}

///|
test "DLbls: empty dLbls parses to empty body" {
  let chart = @chart.Chart::parse(fixture_d_lbls_bar_chart_xml("<c:dLbls/>"))
  let dl = unwrap_bar_d_lbls(chart)
  assert_true(dl.d_lbl_pos is None)
  assert_true(dl.show_val is None)
  assert_eq(dl.d_lbl.length(), 0)
}

///|
test "DLbls: typed scalar / Bool leaves lift" {
  let body = "<c:dLbls>" +
    "<c:dLblPos val=\"ctr\"/>" +
    "<c:showLegendKey val=\"0\"/>" +
    "<c:showVal val=\"1\"/>" +
    "<c:showCatName val=\"0\"/>" +
    "<c:showSerName val=\"1\"/>" +
    "<c:showPercent val=\"0\"/>" +
    "<c:showBubbleSize val=\"0\"/>" +
    "</c:dLbls>"
  let chart = @chart.Chart::parse(fixture_d_lbls_bar_chart_xml(body))
  let dl = unwrap_bar_d_lbls(chart)
  assert_true(dl.d_lbl_pos is Some(DLblCenter))
  assert_eq(dl.show_legend_key.unwrap(), false)
  assert_eq(dl.show_val.unwrap(), true)
  assert_eq(dl.show_cat_name.unwrap(), false)
  assert_eq(dl.show_ser_name.unwrap(), true)
  assert_eq(dl.show_percent.unwrap(), false)
  assert_eq(dl.show_bubble_size.unwrap(), false)
}

///|
test "DLbls: dLblPos every variant round-trips" {
  let cases = [
    "bestFit", "b", "ctr", "inBase", "inEnd", "l", "outEnd", "r", "t",
  ]
  for v in cases {
    let body = "<c:dLbls><c:dLblPos val=\"" + v + "\"/></c:dLbls>"
    let original = @chart.Chart::parse(fixture_d_lbls_bar_chart_xml(body))
    let bytes = original.serialize()
    let re_parsed = @chart.Chart::parse(bytes)
    assert_eq(re_parsed, original)
  }
}

///|
test "DLbls: numFmt lifts to typed NumFmt" {
  let body = "<c:dLbls>" +
    "<c:numFmt formatCode=\"0.00%\" sourceLinked=\"0\"/>" +
    "<c:showVal val=\"1\"/>" +
    "</c:dLbls>"
  let chart = @chart.Chart::parse(fixture_d_lbls_bar_chart_xml(body))
  let dl = unwrap_bar_d_lbls(chart)
  assert_eq(dl.num_fmt.unwrap().format_code, "0.00%")
  assert_eq(dl.num_fmt.unwrap().source_linked.unwrap(), false)
}

///|
test "DLbls: separator text content round-trips" {
  let body = "<c:dLbls>" + "<c:separator>; </c:separator>" + "</c:dLbls>"
  let chart = @chart.Chart::parse(fixture_d_lbls_bar_chart_xml(body))
  let dl = unwrap_bar_d_lbls(chart)
  assert_eq(dl.separator.unwrap(), "; ")
}

///|
test "DLbls: per-data-point <c:dLbl> overrides captured" {
  let body = "<c:dLbls>" +
    "<c:dLbl><c:idx val=\"0\"/><c:showVal val=\"1\"/></c:dLbl>" +
    "<c:dLbl><c:idx val=\"2\"/><c:showCatName val=\"1\"/></c:dLbl>" +
    "<c:showVal val=\"0\"/>" +
    "</c:dLbls>"
  let chart = @chart.Chart::parse(fixture_d_lbls_bar_chart_xml(body))
  let dl = unwrap_bar_d_lbls(chart)
  assert_eq(dl.d_lbl.length(), 2)
}

///|
test "DLbls: full body round-trips" {
  let body = "<c:dLbls>" +
    "<c:dLbl><c:idx val=\"0\"/><c:showVal val=\"1\"/></c:dLbl>" +
    "<c:numFmt formatCode=\"General\" sourceLinked=\"1\"/>" +
    "<c:dLblPos val=\"outEnd\"/>" +
    "<c:showLegendKey val=\"0\"/>" +
    "<c:showVal val=\"1\"/>" +
    "<c:showCatName val=\"0\"/>" +
    "<c:showSerName val=\"0\"/>" +
    "<c:showPercent val=\"0\"/>" +
    "<c:showBubbleSize val=\"0\"/>" +
    "<c:separator>, </c:separator>" +
    "</c:dLbls>"
  let original = @chart.Chart::parse(fixture_d_lbls_bar_chart_xml(body))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "DLbls: extLst rides on extension" {
  let body = "<c:dLbls>" +
    "<c:showVal val=\"1\"/>" +
    "<c:extLst><c:ext uri=\"{X}\"/></c:extLst>" +
    "</c:dLbls>"
  let original = @chart.Chart::parse(fixture_d_lbls_bar_chart_xml(body))
  let dl = unwrap_bar_d_lbls(original)
  assert_eq(dl.extension.length(), 1)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "DLbls: pie-only showLeaderLines rides on extension" {
  let body = "<c:dLbls>" +
    "<c:showVal val=\"0\"/>" +
    "<c:showCatName val=\"1\"/>" +
    "<c:showLeaderLines val=\"1\"/>" +
    "</c:dLbls>"
  let pie_xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    "<c:pieChart>" +
    body +
    "</c:pieChart>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(pie_xml))
  let dl = match original.chart.plot_area.plots[0] {
    PieChart(p) => p.d_lbls.unwrap()
    _ => abort("expected PieChart")
  }
  // showLeaderLines is not in CT_DLbls's typed leaves — it rides
  // on extension per ADR-004.
  assert_eq(dl.extension.length(), 1)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "DLbls: dLbls survives across multiple plot families" {
  // Exercise the typed dLbls on three different plot families to
  // confirm the migration is consistent.
  let line_body = "<c:dLbls><c:showVal val=\"1\"/></c:dLbls>"
  let line_xml = "<?xml version=\"1.0\"?>" +
    "<c:chartSpace xmlns:c=\"" +
    chart_ns +
    "\">" +
    "<c:chart>" +
    "<c:plotArea>" +
    "<c:lineChart>" +
    "<c:grouping val=\"standard\"/>" +
    line_body +
    "<c:axId val=\"1\"/>" +
    "<c:axId val=\"2\"/>" +
    "</c:lineChart>" +
    "</c:plotArea>" +
    "</c:chart>" +
    "</c:chartSpace>"
  let original = @chart.Chart::parse(fixture_bytes(line_xml))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}
