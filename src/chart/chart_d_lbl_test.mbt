// DLbl per-point override typed parser / writer tests.

///|
fn fixture_d_lbl_bar(d_lbls_body : String) -> FixedArray[Byte] {
  fixture_d_lbls_bar_chart_xml(d_lbls_body)
}

///|
fn first_d_lbl(chart : @chart.Chart) -> DLbl {
  let dl = unwrap_bar_d_lbls(chart)
  dl.d_lbl[0]
}

///|
test "DLbl: delete-choice variant lifts" {
  // <c:dLbl> with the EG_DLblChoice "delete" branch.
  let body = "<c:dLbls>" +
    "<c:dLbl>" +
    "<c:idx val=\"2\"/>" +
    "<c:delete val=\"1\"/>" +
    "</c:dLbl>" +
    "<c:showVal val=\"1\"/>" +
    "</c:dLbls>"
  let chart = @chart.Chart::parse(fixture_d_lbl_bar(body))
  let d = first_d_lbl(chart)
  assert_eq(d.idx, 2)
  assert_eq(d.delete.unwrap(), true)
  assert_true(d.show_val is None)
}

///|
test "DLbl: full styling-choice variant lifts" {
  let body = "<c:dLbls>" +
    "<c:dLbl>" +
    "<c:idx val=\"0\"/>" +
    "<c:numFmt formatCode=\"0.00\" sourceLinked=\"0\"/>" +
    "<c:dLblPos val=\"outEnd\"/>" +
    "<c:showLegendKey val=\"0\"/>" +
    "<c:showVal val=\"1\"/>" +
    "<c:showCatName val=\"1\"/>" +
    "<c:showSerName val=\"0\"/>" +
    "<c:showPercent val=\"0\"/>" +
    "<c:showBubbleSize val=\"0\"/>" +
    "<c:separator>: </c:separator>" +
    "</c:dLbl>" +
    "</c:dLbls>"
  let chart = @chart.Chart::parse(fixture_d_lbl_bar(body))
  let d = first_d_lbl(chart)
  assert_eq(d.idx, 0)
  assert_eq(d.num_fmt.unwrap().format_code, "0.00")
  assert_true(d.d_lbl_pos is Some(DLblOutEnd))
  assert_eq(d.show_val.unwrap(), true)
  assert_eq(d.show_cat_name.unwrap(), true)
  assert_eq(d.separator.unwrap(), ": ")
}

///|
test "DLbl: layout and tx captured" {
  let body = "<c:dLbls>" +
    "<c:dLbl>" +
    "<c:idx val=\"1\"/>" +
    "<c:layout/>" +
    "<c:tx><c:rich/></c:tx>" +
    "<c:showVal val=\"1\"/>" +
    "</c:dLbl>" +
    "</c:dLbls>"
  let chart = @chart.Chart::parse(fixture_d_lbl_bar(body))
  let d = first_d_lbl(chart)
  assert_true(d.layout is Some(_))
  assert_true(d.tx is Some(_))
}

///|
test "DLbl: missing idx raises Malformed" {
  let body = "<c:dLbls>" +
    "<c:dLbl><c:showVal val=\"1\"/></c:dLbl>" +
    "</c:dLbls>"
  let raised = try? @chart.Chart::parse(fixture_d_lbl_bar(body))
  match raised {
    Err(_) => ()
    Ok(_) => fail("expected Malformed for dLbl without idx")
  }
}

///|
test "DLbl: round-trip preserves both choice branches" {
  // Two dLbls — one delete-branch, one styling-branch.
  let body = "<c:dLbls>" +
    "<c:dLbl>" +
    "<c:idx val=\"0\"/>" +
    "<c:delete val=\"1\"/>" +
    "</c:dLbl>" +
    "<c:dLbl>" +
    "<c:idx val=\"3\"/>" +
    "<c:dLblPos val=\"ctr\"/>" +
    "<c:showVal val=\"1\"/>" +
    "</c:dLbl>" +
    "<c:showVal val=\"0\"/>" +
    "</c:dLbls>"
  let original = @chart.Chart::parse(fixture_d_lbl_bar(body))
  let dl = unwrap_bar_d_lbls(original)
  assert_eq(dl.d_lbl.length(), 2)
  assert_eq(dl.d_lbl[0].idx, 0)
  assert_eq(dl.d_lbl[0].delete.unwrap(), true)
  assert_eq(dl.d_lbl[1].idx, 3)
  assert_true(dl.d_lbl[1].d_lbl_pos is Some(DLblCenter))
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "DLbl: extLst rides on extension" {
  let body = "<c:dLbls>" +
    "<c:dLbl>" +
    "<c:idx val=\"0\"/>" +
    "<c:showVal val=\"1\"/>" +
    "<c:extLst><c:ext uri=\"{X}\"/></c:extLst>" +
    "</c:dLbl>" +
    "</c:dLbls>"
  let original = @chart.Chart::parse(fixture_d_lbl_bar(body))
  let d = first_d_lbl(original)
  assert_eq(d.extension.length(), 1)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}
