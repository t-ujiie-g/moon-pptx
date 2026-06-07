// Each test below mirrors a recipe in `examples/README.md`. Keep them
// in lockstep — if you change one, update the other so the docs stay
// honest.

///|
test "example 1: title slide with styled text" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(44.0))
    .with_bold()
    .with_color(@units.RgbColor::new(0x1F, 0x4E, 0x79))
  let body = @slide.TextBody::of_styled_text("Hello, MoonBit", rp)
  let title = @slide.AutoShape::textbox(
    2,
    "Title",
    prs.pct_w(10.0),
    prs.pct_h(40.0),
    prs.pct_w(80.0),
    prs.pct_h(20.0),
    "",
  ).with_text_body(body)
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(title)))
  let _bytes = prs.save()
  assert_eq(prs.slides()[0].shapes.length(), 1)
}

///|
test "example 2: widescreen slide-size" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen)
  let sz = prs.presentation_part().unwrap().sld_sz.unwrap()
  assert_eq(sz.cx, @units.Emu(12_192_000L))
  // pct_w now resolves against the widescreen width.
  assert_eq(prs.pct_w(100.0), @units.Emu(12_192_000L))
}

///|
test "example 3: external + internal hyperlinks" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let _ = prs.add_slide_mut(0)
  let link = @slide.RunProperties::default()
    .with_font_size(@units.Pt(20.0))
    .with_color(@units.RgbColor::new(0x0B, 0x5C, 0xD2))
    .with_hyperlink("https://moonbitlang.com", tooltip="docs")
  let jump = @slide.RunProperties::default().with_hyperlink_to_slide(1)
  let tb1 = @slide.TextBody::of_styled_text("moonbitlang.com", link)
  let tb2 = @slide.TextBody::of_styled_text("→ next slide", jump)
  let box1 = @slide.AutoShape::textbox(
    2,
    "ExtLink",
    prs.pct_w(10.0),
    prs.pct_h(20.0),
    prs.pct_w(80.0),
    prs.pct_h(15.0),
    "",
  ).with_text_body(tb1)
  let box2 = @slide.AutoShape::textbox(
    3,
    "IntLink",
    prs.pct_w(10.0),
    prs.pct_h(50.0),
    prs.pct_w(80.0),
    prs.pct_h(15.0),
    "",
  ).with_text_body(tb2)
  let s = prs.slides()[0]
    .with_shape(@slide.AutoShape(box1))
    .with_shape(@slide.AutoShape(box2))
  prs.update_slide_mut(0, s)
  // External + internal hyperlink rels each landed once.
  let mut ext_count = 0
  let mut int_count = 0
  for p in prs.pkg.parts() {
    if p.name.has_prefix("/ppt/slides/") && p.name.has_suffix(".xml") {
      let rels = prs.pkg.relationships_for(p.name)
      ext_count = ext_count + rels.by_type(@opc.rt_hyperlink).length()
      int_count = int_count + rels.by_type(@opc.rt_slide).length()
    }
  }
  assert_eq(ext_count, 1)
  assert_eq(int_count, 1)
}

///|
test "example 4: speaker notes" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.set_notes_mut(
    0, "Remember to thank the team — XML-special chars like <&> are escaped automatically.",
  )
  assert_eq(prs.notes_slides().length(), 1)
  match prs.notes_slides()[0].shapes[0] {
    AutoShape(a) =>
      assert_eq(
        a.text_body.unwrap().paragraphs[0].plain_text(),
        "Remember to thank the team — XML-special chars like <&> are escaped automatically.",
      )
    _ => fail("expected notes AutoShape")
  }
}

///|
test "example 6: tables with merged cells and styled borders" {
  let red = @units.RgbColor::parse_hex("FF0000")
  let red_stroke : @oxml.Stroke = {
    width: Some(@units.Emu(12_700L)),
    cap: None,
    compound: None,
    alignment: None,
    fill: Some(@oxml.Fill::SolidFill(@oxml.Color::srgb(red))),
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
  let yellow = @units.RgbColor::parse_hex("FFFF00")
  let header_props = @slide.TableCellProperties::default()
    .with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(yellow)))
    .with_anchor(@slide.Anchor::AnchorCenter)
    .with_borders(top=red_stroke, bottom=red_stroke)
  let header = @slide.TableCell::merged_origin("Quarter results", grid_span=2)
  let header = { ..header, properties: Some(header_props) }
  let row0 = @slide.TableRow::of_cells(
    [header, @slide.TableCell::h_merge_covered()],
    height=@units.Emu(457_200L),
  )
  let row1 = @slide.TableRow::of_cells(
    [@slide.TableCell::of_text("Q1"), @slide.TableCell::of_text("Q2")],
    height=@units.Emu(457_200L),
  )
  let t = @slide.Table::of_rows([row0, row1], col_widths=[
    @units.Emu(2_286_000L),
    @units.Emu(2_286_000L),
  ])
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  let gf = @slide.GraphicFrame::of_table(
    10,
    "Summary",
    prs.pct_w(10.0),
    prs.pct_h(20.0),
    prs.pct_w(60.0),
    prs.pct_h(50.0),
    t,
  )
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.GraphicFrame(gf)))
  // The shape landed and the table has 2 rows.
  match prs.slides()[0].shapes[0] {
    GraphicFrame(g) =>
      match g.content {
        TableContent(t) => assert_eq(t.rows.length(), 2)
        _ => fail("expected TableContent")
      }
    _ => fail("expected GraphicFrame")
  }
}

///|
test "example 7: bar chart from data" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_category("Q4")
    .with_series("Revenue", [100.0, 200.0, 300.0, 250.0])
    .with_series("Cost", [60.0, 110.0, 180.0, 140.0])
  let chart = @chart.Chart::of_bar(data)
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    chart,
    prs.pct_w(10.0),
    prs.pct_h(15.0),
    prs.pct_w(80.0),
    prs.pct_h(70.0),
  )
  assert_eq(prs.charts().length(), 1)
}

///|
test "example 8: 3-slide pitch deck with widescreen + notes + chart + link" {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen)
  let _ = prs.add_slide_mut(0)
  let title_rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(44.0))
    .with_bold()
    .with_color(@units.RgbColor::new(0x1F, 0x4E, 0x79))
  let title = @slide.AutoShape::textbox(
    2,
    "Title",
    prs.pct_w(10.0),
    prs.pct_h(40.0),
    prs.pct_w(80.0),
    prs.pct_h(20.0),
    "",
  ).with_text_body(@slide.TextBody::of_styled_text("Q4 results", title_rp))
  prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(title)))
  prs.set_notes_mut(0, "Open with the headline number.")
  let _ = prs.add_slide_mut(0)
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_category("Q4")
    .with_series("Revenue", [100.0, 200.0, 300.0, 450.0])
  prs.add_chart_mut(
    1,
    @chart.Chart::of_bar(data),
    prs.pct_w(10.0),
    prs.pct_h(15.0),
    prs.pct_w(80.0),
    prs.pct_h(70.0),
  )
  let _ = prs.add_slide_mut(0)
  let link_rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(20.0))
    .with_hyperlink_to_slide(0, tooltip="back to title")
  let closing = @slide.AutoShape::textbox(
    2,
    "Closing",
    prs.pct_w(10.0),
    prs.pct_h(40.0),
    prs.pct_w(80.0),
    prs.pct_h(15.0),
    "",
  ).with_text_body(@slide.TextBody::of_styled_text("← back", link_rp))
  prs.update_slide_mut(2, prs.slides()[2].with_shape(@slide.AutoShape(closing)))
  let bytes = prs.save()
  // Reopen — round-trip survives.
  let prs2 = @presentation.Presentation::open(bytes)
  assert_eq(prs2.slides().length(), 3)
  assert_eq(prs2.charts().length(), 1)
  assert_eq(prs2.notes_slides().length(), 1)
}

///|
test "example 9: typed layout slides (compile-time placeholder schema)" {
  let prs = @presentation.Presentation::new()
  // Each constructor returns a handle that only exposes the layout's
  // placeholders. `.subtitle(...)` exists on a title slide; calling it on
  // a title-and-content handle would not compile.
  let _ = prs
    .add_title_slide_mut()
    .title("Quarterly Review")
    .subtitle("FY2026 · Q3")
    .finish_mut()
  let _ = prs
    .add_title_content_slide_mut()
    .title("Agenda")
    .body("Results · Outlook · Q&A")
    .finish_mut()
  let prs2 = @presentation.Presentation::open(prs.save())
  assert_eq(prs2.slides().length(), 2)
  assert_true(prs2.slides()[0].title() is Some(_))
  assert_true(prs2.slides()[1].body() is Some(_))
}

///|
test "example 10: slide transitions" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // A fade that also auto-advances after 3 seconds.
  let s = prs.slides()[0].with_transition(
    @slide.Transition::fade().with_advance_after(3000),
  )
  prs.update_slide_mut(0, s)
  let prs2 = @presentation.Presentation::open(prs.save())
  assert_true(prs2.slides()[0].transition is Some(_))
}

///|
test "example 11: ADT-driven chart options" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [100.0, 200.0])
  let chart = @chart.Chart::of_bar(data).with_options([
    Title("Revenue"),
    Legend(LegendBottom),
    DataLabels(DLblOutEnd),
  ])
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  prs.add_chart_mut(
    0,
    chart,
    prs.pct_w(10.0),
    prs.pct_h(15.0),
    prs.pct_w(80.0),
    prs.pct_h(70.0),
  )
  assert_eq(prs.charts().length(), 1)
  assert_true(prs.charts()[0].chart.title is Some(_))
}

///|
test "example 12: typed picture builder pipeline" {
  let outline : @oxml.Stroke = {
    width: Some(@units.Emu(12_700L)),
    cap: None,
    compound: None,
    alignment: None,
    fill: None,
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
  // builder → crop → effects → build. Cropping twice would not compile.
  let pic = @slide.Picture::builder(
      5,
      "Logo",
      "rId2",
      @units.Emu(0L),
      @units.Emu(0L),
      @units.Emu(914_400L),
      @units.Emu(914_400L),
    )
    .with_crop(left=@units.Percentage(10.0), right=@units.Percentage(10.0))
    .with_effects(outline~)
    .build()
  assert_true(pic.blip_fill.src_rect is Some(_))
  assert_true(pic.stroke is Some(_))
}

///|
test "example 13: chart-data validation" {
  // A consistent table validates and composes straight into a builder.
  let good = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [10.0, 20.0])
  let _ = @chart.Chart::of_bar(good.validate())
  // A series with the wrong number of values is caught.
  let bad = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [10.0])
  assert_eq(bad.is_consistent(), false)
  try bad.validate() |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected validate to raise on a mismatched series")
  }
}
