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
  // A built-in gallery style restyles the whole table by reference.
  let t = t.with_style(MediumStyle2Accent1)
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
  // The shape landed, the table has 2 rows, and the gallery style stuck.
  match prs.slides()[0].shapes[0] {
    GraphicFrame(g) =>
      match g.content {
        TableContent(t) => {
          assert_eq(t.rows.length(), 2)
          assert_eq(
            t.properties.unwrap().table_style_id.unwrap(),
            @slide.TableStylePreset::MediumStyle2Accent1.guid(),
          )
        }
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
  // embed_data generates the editable .xlsx workbook behind
  // PowerPoint's "Edit Data" button.
  prs.add_chart_mut(
    0,
    chart,
    prs.pct_w(10.0),
    prs.pct_h(15.0),
    prs.pct_w(80.0),
    prs.pct_h(70.0),
    embed_data=data,
  )
  assert_eq(prs.charts().length(), 1)
  assert_true(
    prs.pkg.part_by_name("/ppt/embeddings/Microsoft_Excel_Worksheet1.xlsx")
    is Some(_),
  )
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

///|
test "example 14: entrance animations" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // A shape to animate (shape id 2).
  let box = @slide.AutoShape::textbox(
    2,
    "Box",
    prs.pct_w(10.0),
    prs.pct_h(30.0),
    prs.pct_w(40.0),
    prs.pct_h(20.0),
    "Fly in!",
  )
  let slide = prs.slides()[0].with_shape(@slide.AutoShape(box))
  // A click-driven timeline: the box flies in from the left, then a second
  // click spins it for emphasis.
  let timeline = @slide.Timeline::new()
    .on_click(Entrance(FlyIn(Left)), 2)
    .on_click(Emphasis(Spin(360)), 2)
  let animated = slide.with_animations(timeline)
  assert_true(animated.timing is Some(_))
  prs.update_slide_mut(0, animated)
  // `save()` emits the full canonical `<p:timing>` tree.
  let _bytes = prs.save()
}

///|
test "example 15: SmartArt diagram" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // Per-node colour overrides ride on top of the diagram's quick style.
  let hot = @smartart.Node::leaf("Ship")
    .with_fill(@units.RgbColor::new(0xC0, 0x00, 0x00))
    .with_text_color(@units.RgbColor::new(0xFF, 0xFF, 0xFF))
  let art = @smartart.SmartArt::new(Process, [
    @smartart.Node::leaf("Plan"),
    @smartart.Node::leaf("Build"),
    hot,
  ])
  prs.add_smartart_mut(
    0,
    art,
    prs.pct_w(10.0),
    prs.pct_h(15.0),
    prs.pct_w(80.0),
    prs.pct_h(70.0),
  )
  // The tree families take nested Nodes; the recursive hierarchy layout
  // definition lays the whole tree out in PowerPoint (see
  // examples/README.md §15).
  let _ = prs.add_slide_mut(0)
  let ceo = @smartart.Node::new("CEO", [
    @smartart.Node::leaf("CTO"),
    @smartart.Node::new("CFO", [@smartart.Node::leaf("Controller")]),
  ])
  prs.add_smartart_mut(
    1,
    @smartart.SmartArt::org_chart(ceo),
    prs.pct_w(10.0),
    prs.pct_h(15.0),
    prs.pct_w(80.0),
    prs.pct_h(70.0),
  )
  // Each slide gains one graphic-frame shape; the DiagramML parts survive
  // a save → reopen round-trip.
  let saved = prs.save()
  let prs2 = @presentation.Presentation::open(saved)
  assert_eq(prs2.slides()[0].shapes.length(), 1)
  assert_eq(prs2.slides()[1].shapes.length(), 1)
  // The node's colour overrides reach the saved diagram data part.
  let data = @oxml.bytes_to_string(
    @opc.Package::open(saved).require_part("/ppt/diagrams/data1.xml").bytes,
  )
  assert_true(data.contains("<a:srgbClr val=\"C00000\""))
}

///|
test "example 16: YouTube / online video" {
  let prs = @presentation.Presentation::new()
  let _ = prs.add_slide_mut(0)
  // `add_youtube_video_mut` normalises the URL to the embeddable form and
  // wires the external video relationships; the caller supplies the preview
  // frame (here a tiny synthetic PNG stands in for a real poster image).
  prs.add_youtube_video_mut(
    0,
    "https://youtu.be/dQw4w9WgXcQ",
    minimal_png(),
    prs.pct_w(10.0),
    prs.pct_h(10.0),
    prs.pct_w(80.0),
    prs.pct_h(80.0),
  )
  assert_eq(prs.slides()[0].shapes.length(), 1)
  // `add_online_video_mut(slide, url, poster, …)` is the general form for any
  // streaming URL.
  let _bytes = prs.save()
}

///|
test "example 17: plot-type-aware chart validation" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [10.0, 20.0])
  // `outEnd` data labels are valid on a bar chart…
  let bar = @chart.Chart::of_bar(data).with_options([DataLabels(DLblOutEnd)])
  let _ = bar.validate()
  // …but invalid on a line chart — `validate` catches it before PowerPoint
  // would run its repair pass.
  let line = @chart.Chart::of_line(data).with_options([DataLabels(DLblOutEnd)])
  assert_eq(line.is_consistent(), false)
  try line.validate() |> ignore catch {
    _ => ()
  } noraise {
    _ => fail("expected validate to raise on an invalid label position")
  }
}

///|
test "example 18: slide sections" {
  let prs = @presentation.Presentation::new()
  for _ in 0..<4 {
    let _ = prs.add_slide_mut(0)
  }
  prs.set_sections_mut([
    { title: "Introduction", start: 0 },
    { title: "Content", start: 1 },
    { title: "Conclusion", start: 3 },
  ])
  prs.add_section_mut(title="Details", start=2)
  // Sections partition the deck in slide order and survive save → reopen.
  let reopened = @presentation.Presentation::open(prs.save())
  let sections = reopened.sections()
  assert_eq(sections.length(), 4)
  assert_true(sections[1] == { title: "Content", start: 1 })
  assert_true(sections[2] == { title: "Details", start: 2 })
  // Removal:
  prs.set_sections_mut([])
  assert_eq(prs.sections().length(), 0)
}

///|
/// A minimal valid PNG (signature + IHDR + IDAT + IEND) — enough for the image
/// detector; the cookbook's video poster stands in for a real frame.
fn minimal_png() -> FixedArray[Byte] {
  let raw : Array[Int] = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
    0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
    0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44,
    0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
    0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
    0x60, 0x82,
  ]
  let out = FixedArray::make(raw.length(), b'\x00')
  for i in 0..<raw.length() {
    out[i] = raw[i].to_byte()
  }
  out
}

///|
test "example 19: document properties (core + app)" {
  let prs = @presentation.Presentation::new()
  prs.set_core_properties_mut(
    prs.core_properties().with_title("Q3 Review").with_author("Ada"),
  )
  prs.set_app_properties_mut(
    @presentation.AppProperties::new()
    .with_company("ACME Corp")
    .with_manager("Grace"),
  )
  let reopened = @presentation.Presentation::open(prs.save())
  assert_eq(reopened.core_properties().title.unwrap(), "Q3 Review")
  assert_eq(reopened.core_properties().creator.unwrap(), "Ada")
  let app = reopened.app_properties()
  assert_eq(app.company.unwrap(), "ACME Corp")
  assert_eq(app.manager.unwrap(), "Grace")
  // The merge kept the template's own Application field.
  assert_eq(app.application.unwrap(), "moon-pptx")
}
