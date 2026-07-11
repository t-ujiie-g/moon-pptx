// Tests for `Presentation::add_chart_mut` + `add_chart_ex_mut`.

///|
fn small_chart_data() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_series("Revenue", [100.0, 200.0])
}

///|
test "add_chart_mut: bar chart lands as /ppt/charts/chart1.xml" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let chart = @chart.Chart::of_bar(small_chart_data())
  prs.add_chart_mut(
    0,
    chart,
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    @units.Emu(6_858_000L),
    @units.Emu(4_572_000L),
  )
  let chart_part = prs.pkg.part_by_name("/ppt/charts/chart1.xml").unwrap()
  assert_eq(chart_part.content_type, @oxml.ct_chart)
  // Slide tree gains a GraphicFrame with ChartContent.
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 1)
  match slide.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        ChartContent(rid) => assert_eq(rid, "rId2")
        _ => fail("expected ChartContent")
      }
    _ => fail("expected GraphicFrame shape")
  }
}

///|
test "add_chart_mut: content_types gains Override for the chart part" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    @chart.Chart::of_pie(small_chart_data()),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  let cts = prs.pkg.content_types()
  let has_chart_override = cts.overrides
    .iter()
    .any(fn(kv) { kv.0 == "/ppt/charts/chart1.xml" && kv.1 == @oxml.ct_chart })
  assert_true(has_chart_override)
}

///|
test "add_chart_mut: second chart gets chart2 and a fresh rId" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    @chart.Chart::of_bar(small_chart_data()),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  prs.add_chart_mut(
    0,
    @chart.Chart::of_line(small_chart_data()),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(prs.pkg.part_by_name("/ppt/charts/chart1.xml") is Some(_))
  assert_true(prs.pkg.part_by_name("/ppt/charts/chart2.xml") is Some(_))
  let slide = prs.slides()[0]
  assert_eq(slide.shapes.length(), 2)
}

///|
test "add_chart_mut: round-trips through save → open" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    @chart.Chart::of_bar(small_chart_data()),
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    @units.Emu(6_858_000L),
    @units.Emu(4_572_000L),
  )
  let bytes = prs.save()
  let prs2 = @presentation.Presentation::open(bytes)
  assert_eq(prs2.charts().length(), 1)
  let slide = prs2.slides()[0]
  match slide.shapes[0] {
    GraphicFrame(gf) =>
      match gf.content {
        ChartContent(rid) => assert_eq(rid, "rId2")
        _ => fail("expected ChartContent")
      }
    _ => fail("expected GraphicFrame")
  }
}

///|
test "add_chart_mut: rejects out-of-range slide index" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  try
    prs.add_chart_mut(
      99,
      @chart.Chart::of_bar(small_chart_data()),
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(100L),
      @units.Emu(100L),
    )
  catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected Malformed")
  }
}

///|
/// Minimal spec-shaped `<cx:chartSpace>` (a waterfall) for the
/// `add_chart_ex_mut` direct test — mirrors the chart_ex parser fixture.
fn waterfall_chart_ex() -> @chart_ex.ChartEx raise {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
    "<cx:chartSpace xmlns:cx=\"http://schemas.microsoft.com/office/drawing/2014/chartex\">" +
    "<cx:chartData><cx:data id=\"0\">" +
    "<cx:strDim type=\"cat\"><cx:lvl ptCount=\"2\"><cx:pt idx=\"0\">A</cx:pt><cx:pt idx=\"1\">B</cx:pt></cx:lvl></cx:strDim>" +
    "<cx:numDim type=\"val\"><cx:lvl ptCount=\"2\" formatCode=\"General\"><cx:pt idx=\"0\">10</cx:pt><cx:pt idx=\"1\">20</cx:pt></cx:lvl></cx:numDim>" +
    "</cx:data></cx:chartData>" +
    "<cx:chart><cx:plotArea><cx:plotAreaRegion>" +
    "<cx:plotSurface/>" +
    "<cx:series layoutId=\"waterfall\" formatIdx=\"0\"><cx:dataId val=\"0\"/></cx:series>" +
    "</cx:plotAreaRegion></cx:plotArea></cx:chart>" +
    "</cx:chartSpace>"
  @chart_ex.ChartEx::parse(@oxml.string_to_bytes(xml))
}

///|
test "add_chart_ex_mut: chartEx part + rels + content type + reopen" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_ex_mut(
    0,
    waterfall_chart_ex(),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(5_000_000L),
    @units.Emu(3_000_000L),
  )
  // The chartEx part exists with its content-type override.
  assert_true(prs.pkg.part_by_name("/ppt/charts/chartEx1.xml") is Some(_))
  let ct = @oxml.bytes_to_string(
    prs.pkg.part_by_name("/[Content_Types].xml").unwrap().bytes,
  )
  assert_true(ct.find("chartex") is Some(_))
  // The slide references it and the deck survives save → reopen.
  let slide_xml = @oxml.bytes_to_string(
    prs.pkg.part_by_name("/ppt/slides/slide1.xml").unwrap().bytes,
  )
  assert_true(
    slide_xml.find("chartEx") is Some(_) ||
    slide_xml.find("graphicFrame") is Some(_),
  )
  let prs2 = @presentation.Presentation::open(prs.save())
  assert_eq(prs2.slides()[0].shapes.length(), 1)
}

// --- embedded data workbook (embed_data) ---

///|
fn add_bar_with_embed(prs : @presentation.Presentation) -> Unit raise {
  prs.add_chart_mut(
    0,
    @chart.Chart::of_bar(small_chart_data()),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
    embed_data=small_chart_data(),
  )
}

///|
test "add_chart_mut embed_data: chart gains externalData + workbook part" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  add_bar_with_embed(prs)
  // The chart XML references the workbook, autoUpdate off.
  let chart_xml = @oxml.bytes_to_string(
    prs.pkg.require_part("/ppt/charts/chart1.xml").bytes,
  )
  assert_true(
    chart_xml.contains(
      "<c:externalData r:id=\"rId1\"><c:autoUpdate val=\"0\"/></c:externalData>",
    ),
  )
  // Its rels resolve rId1 to the embedded package.
  let rels = prs.pkg.relationships_for("/ppt/charts/chart1.xml")
  let rel = rels.by_id("rId1").unwrap()
  assert_eq(rel.rel_type, @opc.rt_package)
  assert_eq(rel.target, "../embeddings/Microsoft_Excel_Worksheet1.xlsx")
  // The part exists with the xlsx content type and a Default entry.
  let emb = prs.pkg
    .part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    .unwrap()
  assert_eq(emb.content_type, @oxml.ct_xlsx_sheet)
  let has_default = prs.pkg.content_types().defaults
    .iter()
    .any(fn(kv) { kv.0 == "xlsx" && kv.1 == @oxml.ct_xlsx_sheet })
  assert_true(has_default)
}

///|
test "add_chart_mut embed_data: the workbook is a valid OPC package with the data" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  add_bar_with_embed(prs)
  let emb = prs.pkg
    .part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    .unwrap()
  let xlsx = @opc.Package::open(emb.bytes)
  // Root rels reach the workbook; workbook rels reach the sheet.
  let wb_rel = xlsx.relationships_for("/").by_id("rId1").unwrap()
  assert_eq(wb_rel.target, "xl/workbook.xml")
  let sheet_rel = xlsx
    .relationships_for("/xl/workbook.xml")
    .by_id("rId1")
    .unwrap()
  assert_eq(sheet_rel.target, "worksheets/sheet1.xml")
  // The sheet mirrors the ChartData layout.
  let sheet = @oxml.bytes_to_string(
    xlsx.require_part("/xl/worksheets/sheet1.xml").bytes,
  )
  assert_true(
    sheet.contains("<c r=\"B1\" t=\"inlineStr\"><is><t>Revenue</t></is></c>"),
  )
  assert_true(
    sheet.contains("<c r=\"A2\" t=\"inlineStr\"><is><t>Q1</t></is></c>"),
  )
  assert_true(sheet.contains("<c r=\"B3\"><v>200</v></c>"))
}

///|
test "add_chart_mut embed_data: survives save -> reopen, rides extension" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  add_bar_with_embed(prs)
  let reopened = @presentation.Presentation::open(prs.save())
  // The workbook part is still there…
  assert_true(
    reopened.pkg.part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    is Some(_),
  )
  // …and the parsed chart carries <c:externalData> in its extension
  // (ADR-004), so a second embed attempt is rejected.
  let chart = @chart.Chart::parse(
    reopened.pkg.require_part("/ppt/charts/chart1.xml").bytes,
  )
  let mut found = false
  for ext in chart.extension {
    if ext.name.local_name == "externalData" {
      found = true
    }
  }
  assert_true(found)
  let _ = reopened.add_slide_mut(0)
  try
    reopened.add_chart_mut(
      1,
      chart,
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(100L),
      @units.Emu(100L),
      embed_data=small_chart_data(),
    )
  catch {
    @presentation.PptxError::Malformed(_) => ()
    _ => fail("expected Malformed for a chart that already has externalData")
  } noraise {
    _ => fail("expected Malformed for a chart that already has externalData")
  }
}

///|
test "add_chart_mut embed_data: two embedded charts get separate workbooks" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  add_bar_with_embed(prs)
  add_bar_with_embed(prs)
  assert_true(
    prs.pkg.part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    is Some(_),
  )
  assert_true(
    prs.pkg.part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet2.xlsx")
    is Some(_),
  )
  assert_eq(
    prs.pkg.relationships_for("/ppt/charts/chart2.xml").by_id("rId1").unwrap().target,
    "../embeddings/Microsoft_Excel_Worksheet2.xlsx",
  )
}

///|
test "add_chart_mut without embed_data: no workbook, no externalData" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    @chart.Chart::of_bar(small_chart_data()),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(
    prs.pkg.part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    is None,
  )
  let chart_xml = @oxml.bytes_to_string(
    prs.pkg.require_part("/ppt/charts/chart1.xml").bytes,
  )
  assert_true(!chart_xml.contains("externalData"))
}
