// Feature slides added on top of the original deck. Each fills one slide of
// the single sample deck (see `build.mbt`'s `build_sample_deck`), except
// `sample_master_slide`, which defines a reusable master/template and adds
// its own slide on the resulting layout.

///|
/// Slide backgrounds — paint a slide with a solid fill behind its content.
fn sample_background_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  prs.update_slide_mut(
    idx,
    prs.slides()[idx]
    .with_background(
      @oxml.SolidFill(@oxml.Color::srgb(@units.RgbColor::new(0xEA, 0xF1, 0xFB))),
    )
    .with_shape(@slide.AutoShape(heading(prs, 2, "Slide backgrounds")))
    .with_shape(
      @slide.AutoShape(
        @slide.AutoShape::textbox(
          3,
          "Note",
          prs.pct_w(8.0),
          prs.pct_h(40.0),
          prs.pct_w(84.0),
          prs.pct_h(15.0),
          "This slide has a solid light-blue background set with with_background().",
        ),
      ),
    ),
  )
}

///|
/// Combo charts — overlay a column series and a line series, with the line
/// plotted against its own (right-hand) value axis.
fn sample_combo_chart_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  prs.update_slide_mut(
    idx,
    prs.slides()[idx].with_shape(
      @slide.AutoShape(
        heading(prs, 2, "Combo charts, chart options & data validation"),
      ),
    ),
  )
  let revenue = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_category("Q4")
    .with_series("Revenue", [120.0, 180.0, 240.0, 310.0])
  let margin = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_category("Q4")
    .with_series("Margin %", [38.0, 41.0, 44.0, 47.0])
  // Validate the data (one value per category) before building. The data
  // is consistent here; a mismatch would raise. ChartError → PptxError.
  let revenue = revenue.validate() catch {
    e => raise @presentation.ChartFailure(e.to_string())
  }
  let margin = margin.validate() catch {
    e => raise @presentation.ChartFailure(e.to_string())
  }
  // Configure the chart with a sum-type option list.
  let combo = @chart.Chart::of_combo(
    @chart.ChartPlot::Bar(revenue),
    @chart.ChartPlot::Line(margin),
    secondary_axis=true,
  ).with_options([
    @chart.ChartOption::Title("Revenue vs. margin %"),
    @chart.ChartOption::Legend(@chart.LegendPos::LegendBottom),
    // `ctr` is valid for both bar and line plots; `outEnd` would be rejected
    // on the line plot (PowerPoint only allows ctr/l/r/t/b for line labels).
    @chart.ChartOption::DataLabels(@chart.DLblPos::DLblCenter),
  ])
  // The embedded data workbook makes PowerPoint's "Edit Data" open the
  // real rows (both series in one sheet) instead of a blank sheet.
  let edit_data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_category("Q4")
    .with_series("Revenue", [120.0, 180.0, 240.0, 310.0])
    .with_series("Margin %", [38.0, 41.0, 44.0, 47.0])
  prs.add_chart_mut(
    idx,
    combo,
    prs.pct_w(8.0),
    prs.pct_h(20.0),
    prs.pct_w(84.0),
    prs.pct_h(70.0),
    embed_data=edit_data,
  )
}

///|
/// SVG images — embed a vector graphic (with a raster fallback for older
/// viewers). Modern PowerPoint renders the crisp SVG.
fn sample_svg_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  prs.update_slide_mut(
    idx,
    prs.slides()[idx].with_shape(
      @slide.AutoShape(heading(prs, 2, "SVG images (with raster fallback)")),
    ),
  )
  prs.add_svg_picture_mut(
    idx,
    feature_svg(),
    sample_checkerboard_bmp(),
    prs.pct_w(34.0),
    prs.pct_h(24.0),
    prs.pct_w(32.0),
    prs.pct_h(64.0),
  )
}

///|
/// Editing existing shapes — add three boxes, then recolour them all in one
/// pass with `map_shapes` (editing shapes already on the slide, not just
/// appending new ones).
fn sample_edit_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let y = prs.pct_h(45.0)
  let cy = prs.pct_h(32.0)
  let cx = prs.pct_w(22.0)
  let box_a = @slide.AutoShape::rect(10, "Box A", prs.pct_w(8.0), y, cx, cy)
  let box_b = @slide.AutoShape::rect(11, "Box B", prs.pct_w(39.0), y, cx, cy)
  let box_c = @slide.AutoShape::rect(12, "Box C", prs.pct_w(70.0), y, cx, cy)
  let green = @oxml.SolidFill(
    @oxml.Color::srgb(@units.RgbColor::new(0x70, 0xAD, 0x47)),
  )
  prs.update_slide_mut(
    idx,
    prs.slides()[idx]
    .with_shape(
      @slide.AutoShape(heading(prs, 2, "Editing shapes already on a slide")),
    )
    .with_shape(@slide.AutoShape(box_a))
    .with_shape(@slide.AutoShape(box_b))
    .with_shape(@slide.AutoShape(box_c))
    .map_shapes(fn(s) {
      // Recolour every box (id >= 10) green; leave the heading untouched.
      match s {
        @slide.AutoShape(a) =>
          if a.id >= 10 {
            @slide.AutoShape(a.with_fill(green))
          } else {
            s
          }
        _ => s
      }
    }),
  )
}

///|
/// Embedded audio & video — place a movie and a sound clip on the slide.
/// (The demo uses tiny placeholder media files, so they won't actually play;
/// the point is to show the embedding API + packaging.)
fn sample_media_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  prs.update_slide_mut(
    idx,
    prs.slides()[idx].with_shape(
      @slide.AutoShape(heading(prs, 2, "Embedded video & audio")),
    ),
  )
  prs.add_video_mut(
    idx,
    fake_mp4(),
    sample_checkerboard_bmp(),
    prs.pct_w(8.0),
    prs.pct_h(24.0),
    prs.pct_w(40.0),
    prs.pct_h(52.0),
  )
  prs.add_audio_mut(
    idx,
    fake_mp3(),
    sample_checkerboard_bmp(),
    prs.pct_w(54.0),
    prs.pct_h(24.0),
    prs.pct_w(38.0),
    prs.pct_h(52.0),
  )
}

///|
/// SmartArt — an org chart synthesised into the full five-part DiagramML
/// graphic. A *nesting* family on purpose: the recursive hierarchy layout
/// definition (hierRoot/hierChild + a named forEach re-invoked via `ref`)
/// makes PowerPoint lay out the whole tree, which a single-level definition
/// couldn't — this slide is the visual regression check for that. The CEO
/// node carries per-node colour overrides on top of the quick style.
fn sample_smartart_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  prs.update_slide_mut(
    idx,
    prs.slides()[idx].with_shape(
      @slide.AutoShape(heading(prs, 2, "SmartArt diagrams")),
    ),
  )
  let ceo_red = @units.RgbColor::new(0xC0, 0x3A, 0x2B)
  let white = @units.RgbColor::new(0xFF, 0xFF, 0xFF)
  let art = @smartart.SmartArt::org_chart(
    @smartart.Node::new("CEO", [
      @smartart.Node::new("CTO", [
        @smartart.Node::leaf("Platform"),
        @smartart.Node::leaf("Apps"),
      ]),
      @smartart.Node::new("CFO", [@smartart.Node::leaf("Controller")]),
    ])
    .with_fill(ceo_red)
    .with_text_color(white),
  )
  prs.add_smartart_mut(
    idx,
    art,
    prs.pct_w(8.0),
    prs.pct_h(20.0),
    prs.pct_w(84.0),
    prs.pct_h(68.0),
  )
}

///|
/// Animations — a box flies in from the left on the first click,
/// then spins 360° for emphasis on the second. `save()` emits the full
/// canonical `<p:timing>` tree.
fn sample_animation_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let box = @slide.AutoShape::rect(
    30,
    "Animated box",
    prs.pct_w(30.0),
    prs.pct_h(36.0),
    prs.pct_w(40.0),
    prs.pct_h(28.0),
  ).with_text_body(
    @slide.TextBody::of_styled_text(
      "I fly in, then spin",
      @slide.RunProperties::default()
      .with_font_size(@units.Pt(20.0))
      .with_color(@units.RgbColor::new(0xFF, 0xFF, 0xFF)),
    ),
  )
  let timeline = @slide.Timeline::new()
    .on_click(Entrance(FlyIn(Left)), 30)
    .on_click(Emphasis(Spin(360)), 30)
  prs.update_slide_mut(
    idx,
    prs.slides()[idx]
    .with_shape(@slide.AutoShape(heading(prs, 2, "Animations")))
    .with_shape(@slide.AutoShape(box))
    .with_animations(timeline),
  )
}

///|
/// Online video — embed a YouTube clip by URL. No media bytes go in
/// the package: just the external video relationships plus a poster frame.
fn sample_online_video_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  prs.update_slide_mut(
    idx,
    prs.slides()[idx].with_shape(
      @slide.AutoShape(heading(prs, 2, "YouTube / online video")),
    ),
  )
  prs.add_youtube_video_mut(
    idx,
    "https://youtu.be/dQw4w9WgXcQ",
    sample_checkerboard_bmp(),
    prs.pct_w(20.0),
    prs.pct_h(20.0),
    prs.pct_w(60.0),
    prs.pct_h(64.0),
  )
}

///|
/// v0.6 features — non-solid *text* fills (the run fill is the full
/// `@oxml.Fill` ADT — gradient / pattern shown here) and paragraph spacing
/// (`TextSpacing { Percent | Points }` on line height + space
/// before/after). The recursive SmartArt layout is on the SmartArt slide.
fn sample_v06_features_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let navy = @units.RgbColor::new(0x1F, 0x4E, 0x79)
  let teal = @units.RgbColor::new(0x2C, 0x9C, 0x9C)
  let mut s = prs.slides()[idx].with_shape(
    @slide.AutoShape(heading(prs, 2, "v0.6 — text fills & paragraph spacing")),
  )

  // Gradient text fill: navy → teal, top-to-bottom.
  let gradient : @oxml.Fill = @oxml.Fill::GradientFill({
    stops: [
      { position: @units.Percentage(0.0), color: @oxml.Color::srgb(navy) },
      { position: @units.Percentage(100.0), color: @oxml.Color::srgb(teal) },
    ],
    direction: Linear(@units.Angle(90.0), true),
    rotate_with_shape: None,
    flip: None,
    extension: [],
  })
  let grad_box = @slide.AutoShape::textbox(
    10,
    "GradientText",
    prs.pct_w(6.0),
    prs.pct_h(20.0),
    prs.pct_w(88.0),
    prs.pct_h(12.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text(
      "Gradient text fill (with_text_fill)",
      @slide.RunProperties::default()
      .with_font_size(@units.Pt(36.0))
      .with_bold()
      .with_text_fill(gradient),
    ),
  )

  // Pattern text fill: light down-diagonal, navy on white.
  let pattern : @oxml.Fill = @oxml.Fill::PatternFill({
    preset: "ltDnDiag",
    fg: @oxml.Color::srgb(navy),
    bg: @oxml.Color::srgb(@units.RgbColor::new(0xFF, 0xFF, 0xFF)),
    extension: [],
  })
  let patt_box = @slide.AutoShape::textbox(
    11,
    "PatternText",
    prs.pct_w(6.0),
    prs.pct_h(33.0),
    prs.pct_w(88.0),
    prs.pct_h(11.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text(
      "Pattern text fill (ltDnDiag)",
      @slide.RunProperties::default()
      .with_font_size(@units.Pt(32.0))
      .with_bold()
      .with_text_fill(pattern),
    ),
  )
  s = s
    .with_shape(@slide.AutoShape(grad_box))
    .with_shape(@slide.AutoShape(patt_box))

  // Paragraph spacing: percent + absolute line height, space-before.
  let body_rp = @slide.RunProperties::default().with_font_size(@units.Pt(16.0))
  let spacing_paras = [
    @slide.Paragraph::of_styled_text(
      "Paragraph spacing — this first paragraph wraps onto several lines at 150 % line height, so the extra leading between the wrapped lines is visible.",
      body_rp,
    ).with_line_spacing(Percent(@units.Percentage(150.0))),
    @slide.Paragraph::of_styled_text(
      "This paragraph carries an 18 pt space-before (the gap above it is spacing, not an empty paragraph).",
      body_rp,
    ).with_space_before(Points(@units.Pt(18.0))),
    @slide.Paragraph::of_styled_text(
      "And this one uses an absolute 28 pt line height (spcPts) — fixed leading regardless of font size, also wrapping across lines to show it.",
      body_rp,
    )
    .with_line_spacing(Points(@units.Pt(28.0)))
    .with_space_before(Points(@units.Pt(18.0))),
  ]
  let spacing_box = @slide.AutoShape::textbox(
    12,
    "SpacingDemo",
    prs.pct_w(6.0),
    prs.pct_h(48.0),
    prs.pct_w(88.0),
    prs.pct_h(44.0),
    "",
  ).with_text_body(@slide.TextBody::of_paragraphs(spacing_paras))
  s = s.with_shape(@slide.AutoShape(spacing_box))
  prs.update_slide_mut(idx, s)
}

///|
/// v0.5.2 features — fidelity & fine-grained formatting: shape rotation /
/// flip, run-level highlight / kerning / text outline / text effects, and
/// shape-level hyperlinks.
fn sample_v052_features_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let navy = @units.RgbColor::new(0x1F, 0x4E, 0x79)
  let teal = @units.RgbColor::new(0x2C, 0x9C, 0x9C)
  let white = @units.RgbColor::new(0xFF, 0xFF, 0xFF)
  let mut s = prs.slides()[idx].with_shape(
    @slide.AutoShape(heading(prs, 2, "v0.5.2 — fidelity & formatting")),
  )

  // A rectangle rotated 25° and a right-arrow flipped to point left.
  let rotated = @slide.AutoShape::rect(
      10,
      "Rotated",
      prs.pct_w(6.0),
      prs.pct_h(22.0),
      prs.pct_w(15.0),
      prs.pct_h(14.0),
    )
    .with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(navy)))
    .with_rotation(@units.Angle(25.0))
  let flipped = @slide.AutoShape::of_preset(
      11,
      "FlippedArrow",
      @slide.PresetShape::RightArrow,
      prs.pct_w(25.0),
      prs.pct_h(22.0),
      prs.pct_w(15.0),
      prs.pct_h(14.0),
    )
    .with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(teal)))
    .with_flip(h=true)
  s = s
    .with_shape(@slide.AutoShape(rotated))
    .with_shape(@slide.AutoShape(flipped))

  // Highlight + kerning in one run.
  let hl_box = @slide.AutoShape::textbox(
    12,
    "Highlight",
    prs.pct_w(44.0),
    prs.pct_h(22.0),
    prs.pct_w(52.0),
    prs.pct_h(8.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text(
      "Highlighted + kerned text",
      @slide.RunProperties::default()
      .with_font_size(@units.Pt(20.0))
      .with_kerning(@units.Pt(10.0))
      .with_highlight(@units.RgbColor::new(0xFF, 0xF1, 0x76)),
    ),
  )
  // Text outline (white glyphs with a navy outline).
  let outline_stroke : @oxml.Stroke = {
    width: Some(@units.Emu(9525L)), // 0.75 pt
    cap: None,
    compound: None,
    alignment: None,
    fill: Some(@oxml.Fill::SolidFill(@oxml.Color::srgb(navy))),
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
  let outline_box = @slide.AutoShape::textbox(
    13,
    "Outlined",
    prs.pct_w(44.0),
    prs.pct_h(32.0),
    prs.pct_w(52.0),
    prs.pct_h(10.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text(
      "Outlined heading",
      @slide.RunProperties::default()
      .with_font_size(@units.Pt(30.0))
      .with_bold()
      .with_color(white)
      .with_text_outline(outline_stroke),
    ),
  )
  // Text effects (a soft glow).
  let glow_fx : @oxml.EffectList = {
    blur: None,
    glow: Some({
      rad: @units.Emu(63500L),
      color: @oxml.Color::srgb(@units.RgbColor::new(0x4C, 0x8C, 0xE6)),
    }),
    inner_shadow: None,
    outer_shadow: None,
    preset_shadow: None,
    reflection: None,
    soft_edge: None,
    extension: [],
  }
  let glow_box = @slide.AutoShape::textbox(
    14,
    "Glow",
    prs.pct_w(44.0),
    prs.pct_h(44.0),
    prs.pct_w(52.0),
    prs.pct_h(10.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text(
      "Glowing text effect",
      @slide.RunProperties::default()
      .with_font_size(@units.Pt(28.0))
      .with_bold()
      .with_color(navy)
      .with_text_effects(glow_fx),
    ),
  )
  s = s
    .with_shape(@slide.AutoShape(hl_box))
    .with_shape(@slide.AutoShape(outline_box))
    .with_shape(@slide.AutoShape(glow_box))

  // Clickable shapes: one opens a URL, one jumps back to the title.
  let label_rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(16.0))
    .with_bold()
    .with_color(white)
  let docs_btn = @slide.AutoShape::round_rect(
      15,
      "DocsButton",
      prs.pct_w(6.0),
      prs.pct_h(74.0),
      prs.pct_w(30.0),
      prs.pct_h(12.0),
    )
    .with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(navy)))
    .with_text_body(@slide.TextBody::of_styled_text("Open docs ↗", label_rp))
    .with_hyperlink(url="https://mooncakes.io/docs/t-ujiie-g/moon-pptx")
  let back_btn = @slide.AutoShape::round_rect(
      16,
      "BackButton",
      prs.pct_w(40.0),
      prs.pct_h(74.0),
      prs.pct_w(30.0),
      prs.pct_h(12.0),
    )
    .with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(teal)))
    .with_text_body(@slide.TextBody::of_styled_text("Back to title", label_rp))
    .with_hyperlink_to_slide(slide_idx=0)
  s = s
    .with_shape(@slide.AutoShape(docs_btn))
    .with_shape(@slide.AutoShape(back_btn))
  prs.update_slide_mut(idx, s)
}

///|
/// Master slides & templates — define a reusable master (title + body
/// placeholders, plus footer / date / slide-number placeholders), then add a
/// slide on its layout that fills in the footer, an auto-updating date, and
/// the slide number. Adds its own slide (it lives on the new layout).
fn sample_master_slide(
  prs : @presentation.Presentation,
) -> Unit raise @presentation.PptxError {
  let master = @presentation.MasterDefinition::new("Sample Template")
    .with_placeholder(
      @slide.PlaceholderType::Title,
      tf(838200L, 365125L, 10515600L, 1325563L),
      default_text="Title",
    )
    .with_placeholder(
      @slide.PlaceholderType::Body,
      tf(838200L, 1825625L, 10515600L, 4351338L),
      default_text="Body",
    )
    .with_footer("moon-pptx sample")
    .with_slide_number(true)
    .with_date(true)
  let _ = prs.define_master(master)
  let layout_index = prs.slide_layouts().length() - 1
  let _ = prs.add_slide_mut(layout_index)
  let idx = prs.slides().length() - 1
  prs.update_slide_mut(
    idx,
    prs.slides()[idx]
    .with_shape(
      @slide.AutoShape(
        heading(prs, 2, "Master slides, footer, date & slide number"),
      ),
    )
    .with_footer("moon-pptx sample deck")
    .with_date(@slide.DateMode::Auto)
    .with_slide_number(true),
  )
}

///|
/// Typed layout slides — the compile-time placeholder schema. Each
/// constructor returns a handle that only exposes the placeholders its layout
/// has, so `.subtitle()` / `.body()` calls that don't fit the layout are
/// compile errors. These add their own slides (on synthesised layouts).
fn sample_typed_layout_slides(
  prs : @presentation.Presentation,
) -> Unit raise @presentation.PptxError {
  // A section header (title + body), built through the typed handle.
  let _ = prs
    .add_section_header_slide_mut()
    .title("Typed layouts")
    .body("These slides use the compile-time placeholder schema.")
    .finish_mut()
  // A title-and-content slide — `.body()` is available only because this
  // layout has a body placeholder; calling it on a title-only handle would
  // not compile.
  let _ = prs
    .add_title_content_slide_mut()
    .title("Compile-time placeholder safety")
    .body(
      "Accessing a placeholder the layout lacks is a compile error, not a runtime check — no other PPTX library offers this.",
    )
    .finish_mut()
}

///|
/// v0.7 features — a gallery-styled table (`TableStylePreset`, no
/// hand-styled cells) and the fill convenience constructors
/// (`Fill::solid` / `linear_gradient` / `pattern`). The deck-level v0.7
/// features live elsewhere: slide sections (the groups in the slide
/// panel), app.xml document properties (File ▸ Info), the combo chart's
/// embedded data workbook ("Edit Data"), and the SmartArt slide's
/// per-node colours.
fn sample_v07_features_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let navy = @units.RgbColor::new(0x1F, 0x4E, 0x79)
  let teal = @units.RgbColor::new(0x2C, 0x9C, 0x9C)
  let white = @units.RgbColor::new(0xFF, 0xFF, 0xFF)
  let mut s = prs.slides()[idx].with_shape(
    @slide.AutoShape(heading(prs, 2, "v0.7 — table styles & fill shortcuts")),
  )

  // A gallery-styled table: one call applies PowerPoint's built-in
  // "Medium Style 2 - Accent 1" (header emphasis + row banding included).
  let cells = [
    ["Region", "Q1", "Q2"],
    ["East", "120", "180"],
    ["West", "95", "140"],
    ["North", "60", "88"],
  ]
  let rows = cells.map(fn(row) {
    @slide.TableRow::of_cells(
      row.map(@slide.TableCell::of_text),
      height=prs.pct_h(9.0),
    )
  })
  let table = @slide.Table::of_rows(rows, col_widths=[
    prs.pct_w(14.0),
    prs.pct_w(14.0),
    prs.pct_w(14.0),
  ]).with_style(MediumStyle2Accent1)
  let gf = @slide.GraphicFrame::of_table(
    10,
    "StyledTable",
    prs.pct_w(6.0),
    prs.pct_h(22.0),
    prs.pct_w(42.0),
    prs.pct_h(36.0),
    table,
  )
  s = s.with_shape(@slide.GraphicFrame(gf))

  // The fill convenience constructors — one-liners for the common
  // solid / two-colour-gradient / preset-pattern fills.
  let y = prs.pct_h(24.0)
  let cx = prs.pct_w(13.0)
  let cy = prs.pct_h(30.0)
  let solid_box = @slide.AutoShape::round_rect(
      11,
      "SolidFill",
      prs.pct_w(52.0),
      y,
      cx,
      cy,
    )
    .with_fill(@oxml.Fill::solid(navy))
    .with_text_body(
      @slide.TextBody::of_styled_text(
        "solid",
        @slide.RunProperties::default().with_color(white),
      ),
    )
  let grad_box = @slide.AutoShape::round_rect(
      12,
      "GradientFill",
      prs.pct_w(67.0),
      y,
      cx,
      cy,
    )
    .with_fill(@oxml.Fill::linear_gradient(navy, teal, via=[white]))
    .with_text_body(
      @slide.TextBody::of_styled_text(
        "linear_gradient",
        @slide.RunProperties::default().with_color(white),
      ),
    )
  let patt_box = @slide.AutoShape::round_rect(
      13,
      "PatternFill",
      prs.pct_w(82.0),
      y,
      cx,
      cy,
    )
    .with_fill(@oxml.Fill::pattern("ltUpDiag", fg=teal, bg=white))
    .with_text_body(
      @slide.TextBody::of_styled_text(
        "pattern",
        @slide.RunProperties::default().with_color(navy),
      ),
    )
  s = s
    .with_shape(@slide.AutoShape(solid_box))
    .with_shape(@slide.AutoShape(grad_box))
    .with_shape(@slide.AutoShape(patt_box))

  // Point at the v0.7 features that live on other slides / deck level.
  let note = @slide.AutoShape::textbox(
    14,
    "Note",
    prs.pct_w(6.0),
    prs.pct_h(66.0),
    prs.pct_w(88.0),
    prs.pct_h(26.0),
    "Also in this deck from v0.7: slide sections (see the groups in the slide panel), company / manager document properties (File ▸ Info), an embedded data workbook behind the combo chart's Edit Data button, and the red CEO node on the SmartArt slide.",
  )
  s = s.with_shape(@slide.AutoShape(note))
  prs.update_slide_mut(idx, s)
}

// --- synthetic assets for the SVG / media demos ---

///|
/// A `Transform` (offset + extent) in EMU, for master placeholder rects.
fn tf(x : Int64, y : Int64, cx : Int64, cy : Int64) -> @slide.Transform {
  @slide.Transform::new(offset={ x: @units.Emu(x), y: @units.Emu(y) }, extent={
    cx: @units.Emu(cx),
    cy: @units.Emu(cy),
  })
}

///|
fn ascii_bytes(s : String) -> FixedArray[Byte] {
  let out = FixedArray::make(s.length(), b'\x00')
  let mut i = 0
  for c in s {
    out[i] = c.to_int().to_byte()
    i = i + 1
  }
  out
}

///|
fn bytes_from_ints(raw : Array[Int]) -> FixedArray[Byte] {
  let out = FixedArray::make(raw.length(), b'\x00')
  let mut i = 0
  while i < raw.length() {
    out[i] = raw[i].to_byte()
    i = i + 1
  }
  out
}

///|
/// A small standalone SVG: a blue disc labelled "SVG" on a light field.
fn feature_svg() -> FixedArray[Byte] {
  ascii_bytes(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"240\" height=\"240\" viewBox=\"0 0 240 240\">" +
    "<rect width=\"240\" height=\"240\" fill=\"#EAF1FB\"/>" +
    "<circle cx=\"120\" cy=\"120\" r=\"92\" fill=\"#5B9BD5\"/>" +
    "<text x=\"120\" y=\"134\" font-family=\"sans-serif\" font-size=\"40\" text-anchor=\"middle\" fill=\"#FFFFFF\">SVG</text>" +
    "</svg>",
  )
}

///|
/// Minimal MP4 (ISO-BMFF `ftyp` box, `isom` brand) → detected as video/mp4.
fn fake_mp4() -> FixedArray[Byte] {
  bytes_from_ints([
    0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D, 0x00,
    0x00, 0x02, 0x00,
  ])
}

///|
/// Minimal MP3 (`ID3` tag header) → detected as audio/mpeg.
fn fake_mp3() -> FixedArray[Byte] {
  bytes_from_ints([0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
}
