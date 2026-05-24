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
  let raised = try? prs.add_chart_mut(
    99,
    @chart.Chart::of_bar(small_chart_data()),
    @units.Emu(0L),
    @units.Emu(0L),
    @units.Emu(100L),
    @units.Emu(100L),
  )
  assert_true(raised is Err(@presentation.PptxError::Malformed(_)))
}
