// Each test below mirrors a code block in `README.mbt.md` § Quickstart.
// The root README lives outside `source = "src"`, so `moon test` cannot
// compile its blocks in place — these tests are what keeps them honest.
// Change one, change the other.

///|
test "readme: build a one-slide deck from scratch" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let s = prs.slides()[0]
  let tb = @slide.AutoShape::textbox(
    2,
    "Title",
    @units.Emu(457_200L),
    @units.Emu(2_438_400L),
    @units.Emu(8_229_600L),
    @units.Emu(914_400L),
    "Hello, MoonBit",
  )
  prs.update_slide_mut(0, s.with_shape(@slide.AutoShape(tb)))
  let bytes : FixedArray[Byte] = prs.save()
  assert_eq(prs.slides()[0].shapes.length(), 1)
  assert_true(bytes.length() > 0)
}

///|
test "readme: tables" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let yellow = @units.RgbColor::parse_hex("FFFF00")
  let header_props = @slide.TableCellProperties::default()
    .with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(yellow)))
    .with_anchor(@slide.Anchor::AnchorCenter)
  let header = @slide.TableCell::merged_origin("Header", grid_span=2)
  let header = { ..header, properties: Some(header_props), }
  let row0 = @slide.TableRow::of_cells(
    [header, @slide.TableCell::h_merge_covered()],
    height=@units.Emu(457_200L),
  )
  let row1 = @slide.TableRow::of_cells(
    [@slide.TableCell::of_text("A2"), @slide.TableCell::of_text("B2")],
    height=@units.Emu(457_200L),
  )
  let t = @slide.Table::of_rows([row0, row1], col_widths=[
    @units.Emu(2_286_000L),
    @units.Emu(2_286_000L),
  ])
  let gf = @slide.GraphicFrame::of_table(
    10,
    "Summary",
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    @units.Emu(4_572_000L),
    @units.Emu(914_400L),
    t,
  )
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.GraphicFrame(gf)))
  let reopened = @presentation.Presentation::open(prs.save())
  let table = match reopened.slides()[0].shapes[0] {
    GraphicFrame(f) =>
      match f.content {
        TableContent(t) => t
        _ => abort("expected the table back")
      }
    _ => abort("expected a GraphicFrame")
  }
  assert_eq(table.rows.length(), 2)
  assert_eq(table.grid.length(), 2)
  assert_eq(table.rows[0].cells[0].grid_span, 2)
}

///|
test "readme: charts" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_category("Q4")
    .with_series("Revenue", [100.0, 200.0, 300.0, 250.0])
    .with_series("Cost", [60.0, 110.0, 180.0, 140.0])
  let chart = @chart.Chart::of_bar(data)
  prs.add_chart_mut(
    0,
    chart,
    @units.Emu(914_400L),
    @units.Emu(1_828_800L),
    @units.Emu(4_572_000L),
    @units.Emu(3_429_000L),
  )
  assert_eq(prs.slides()[0].shapes.length(), 1)
  // The alternate one-liners the README lists next to `of_bar`.
  let _ = @chart.Chart::of_line(data, grouping=Stacked)
  let _ = @chart.Chart::of_pie(data)
  let _ = @chart.Chart::of_doughnut(data, hole_size=60)
  assert_true(prs.save().length() > 0)
}

///|
test "readme: scatter and bubble" {
  let scatter = @chart.Chart::of_scatter(
    @chart.ScatterData::new().with_series("trend", [1.0, 2.0, 3.0], [
      10.0, 25.0, 32.0,
    ]),
  )
  let bubble = @chart.Chart::of_bubble(
    @chart.BubbleData::new().with_series(
      "growth",
      [1.0, 2.0, 3.0],
      [100.0, 200.0, 150.0],
      [10.0, 20.0, 30.0],
    ),
  )
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    scatter,
    @units.Emu(914_400L),
    @units.Emu(914_400L),
    @units.Emu(4_572_000L),
    @units.Emu(3_429_000L),
  )
  prs.add_chart_mut(
    0,
    bubble,
    @units.Emu(5_486_400L),
    @units.Emu(914_400L),
    @units.Emu(4_572_000L),
    @units.Emu(3_429_000L),
  )
  assert_eq(prs.slides()[0].shapes.length(), 2)
  assert_true(prs.save().length() > 0)
}
