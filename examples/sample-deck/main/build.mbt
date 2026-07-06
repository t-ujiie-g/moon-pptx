// Sample deck — exercises (almost) the full moon-pptx public API
// from a downstream consumer's perspective.
//
// This module is **separate from the moon-pptx library itself**: it
// has its own `moon.mod.json` and depends on `t-ujiie-g/moon-pptx`
// just like any user would. It currently uses a path dep on `../..`
// so the deck can exercise the unreleased v0.5.2 features; switch back
// to a published `"version": "0.5.2"` dep once that version is on
// mooncakes. The library proper (in `src/`) is the published artefact
// and contains no demo / sample code.
//
// 24 slides covering every typed feature through v0.5.2 plus every chart
// family from v0.1. The deck also sets document core properties
// (v0.5.2 F2 — title / author / subject / keywords, visible in
// PowerPoint's File ▸ Info):
//
//   1.  Title — widescreen sizing, styled run, hyperlink, speaker notes.
//   2.  Table of contents — internal hyperlinks jumping to later slides.
//   3.  Text features — multi-paragraph + paragraph alignment + bullets.
//   4.  Shapes — rect / ellipse / round-rect + connector + group.
//   5.  Custom geometry — a hand-drawn star path.
//   6.  Picture — synthesized 16×16 BMP fed through add_picture_auto_mut
//       (image-size auto-detection + crop fluent builder).
//   7.  Tables — merged header + per-edge custom borders.
//   8–11. Charts — bar/line/pie, area/radar/doughnut, scatter/bubble,
//       3-D bar/stock/ofPie.
//   12. Slide background.            13. Combo + secondary-axis chart.
//   14. SVG image.                   15. In-place shape editing (map_shapes).
//   16. Embedded video + audio.      17. SmartArt org chart (v0.5 D1).
//   18. Animations (v0.5 D2).        19. YouTube / online video (v0.5 C5).
//   20. v0.5.2 fidelity — shape rotation/flip (F1), run highlight / kerning /
//       text outline / text effects (F3), shape hyperlinks (F5).
//   21. Master / template slide (footer / date / slide number).
//   22–23. Typed layout slides (v0.4 M1 compile-time placeholder schema).
//   24. Closing — hyperlink back to slide 1.
//
// Plus: a slide transition on every slide (v0.4 D3). Every position is
// expressed through `prs.pct_w` / `prs.pct_h` so switching slide sizes
// is a one-line change.
//
// Generate the `.pptx` artefact from the project root with:
//
//   mkdir -p out
//   moon run examples/sample-deck/main --target native | tail -1 | xxd -r -p > out/sample.pptx
//
// Then open `out/sample.pptx` in PowerPoint / Keynote / LibreOffice.

///|
/// Build the sample deck and return the serialised `.pptx` bytes.
pub fn build_sample_deck() -> FixedArray[Byte] raise @presentation.PptxError {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen)
  // v0.5.2 F2 — document core properties (shown in PowerPoint's File ▸ Info).
  prs.set_core_properties_mut(
    @presentation.CoreProperties::new()
    .with_title("moon-pptx feature sample deck")
    .with_author("moon-pptx")
    .with_subject("Library feature showcase")
    .with_keywords("pptx, moonbit, ooxml, sample")
    .with_category("Demo")
    .with_revision("2"),
  )
  // The layout-0 feature slides, in order. They are *all pre-added* before
  // any are filled, so the table-of-contents slide's forward "jump to
  // section" hyperlinks resolve against slides that already exist.
  let builders : Array[(@presentation.Presentation, Int) -> Unit raise @presentation.PptxError] = [
    sample_title_slide,
    sample_toc_slide,
    sample_text_slide,
    sample_shapes_slide,
    sample_custom_geom_slide,
    sample_picture_slide,
    sample_table_slide,
    sample_charts_1_slide,
    sample_charts_2_slide,
    sample_charts_3_slide,
    sample_charts_4_slide,
    sample_background_slide,
    sample_combo_chart_slide,
    sample_svg_slide,
    sample_edit_slide,
    sample_media_slide,
    sample_smartart_slide,
    sample_animation_slide,
    sample_online_video_slide,
    sample_v052_features_slide,
    sample_v06_features_slide,
  ]
  for _ in 0..<builders.length() {
    let _ = prs.add_slide_mut(0)
  }
  for i, f in builders {
    f(prs, i)
  }
  // The master/template demo adds its own slide on the layout it defines.
  sample_master_slide(prs)
  // Typed layout slides — the compile-time placeholder schema (M1). Adds its
  // own slides on synthesised layouts.
  sample_typed_layout_slides(prs)
  // Closing slide (links back to the title).
  let _ = prs.add_slide_mut(0)
  sample_closing_slide(prs, prs.slides().length() - 1)
  // Slide transitions (v0.4 D3) — cycle a few effects across every slide so
  // the deck animates on advance.
  let transitions = [
    @slide.Transition::fade(),
    @slide.Transition::push(@slide.TransitionSide::Left),
    @slide.Transition::wipe(@slide.TransitionSide::Up),
    @slide.Transition::cover(@slide.TransitionDirection::LeftDown),
  ]
  for i in 0..<prs.slides().length() {
    prs.update_slide_mut(
      i,
      prs.slides()[i].with_transition(transitions[i % transitions.length()]),
    )
  }
  prs.save()
}

///|
/// Build a deck containing just the title slide plus one of the three
/// chart families from slide 11 (3-D bar / stock / of-pie). Used to
/// narrow down which family triggers PowerPoint Online's repair.
/// `chart_kind` picks the family:
///
///   0 — 3-D bar chart only
///   1 — stock chart only
///   2 — of-pie chart only
pub fn build_sample_chart_isolated(
  chart_kind : Int,
) -> FixedArray[Byte] raise @presentation.PptxError {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen)
  let _ = prs.add_slide_mut(0)
  sample_title_slide(prs, 0)
  let _ = prs.add_slide_mut(0)
  let head = heading(prs, 2, "Chart isolation test")
  prs.update_slide_mut(1, prs.slides()[1].with_shape(@slide.AutoShape(head)))
  let w = prs.pct_w(60.0)
  let h = prs.pct_h(75.0)
  let x = prs.pct_w(20.0)
  let y = prs.pct_h(18.0)
  match chart_kind {
    0 => {
      // 3-D bar.
      let data = @chart.ChartData::new()
        .with_category("Site A")
        .with_category("Site B")
        .with_category("Site C")
        .with_series("Orders", [120.0, 200.0, 150.0])
        .with_series("Errors", [10.0, 30.0, 15.0])
      prs.add_chart_mut(1, @chart.Chart::of_bar_3d(data), x, y, w, h)
    }
    1 => {
      // Stock (HLC).
      let data = @chart.ChartData::new()
        .with_category("Mon")
        .with_category("Tue")
        .with_category("Wed")
        .with_series("High", [105.0, 108.0, 112.0])
        .with_series("Low", [98.0, 100.0, 105.0])
        .with_series("Close", [102.0, 106.0, 110.0])
      prs.add_chart_mut(1, @chart.Chart::of_stock(data, kind=HLC), x, y, w, h)
    }
    _ => {
      // of-pie.
      let data = @chart.ChartData::new()
        .with_category("Direct")
        .with_category("Search")
        .with_category("Social")
        .with_category("Email")
        .with_category("Other")
        .with_series("Traffic", [38.0, 28.0, 15.0, 12.0, 7.0])
      prs.add_chart_mut(1, @chart.Chart::of_of_pie(data), x, y, w, h)
    }
  }
  prs.save()
}

///|
/// Build a focused two-slide test deck — the title slide plus exactly
/// **one** feature slide — for bisecting PowerPoint Online repair
/// triggers. `feature_idx` picks which feature slide:
///
///   0 — title only (no second slide)
///   1 — text features
///   2 — shapes (rect / ellipse / round_rect / connector / group)
///   3 — custom geometry (star path)
///   4 — picture with crop
///   5 — table with merged header + custom borders
///   6 — charts: bar / line / pie
///   7 — charts: area / radar / doughnut
///   8 — charts: scatter + bubble
///   9 — charts: 3-D bar + stock + of-pie
///   10 — slide background
///   11 — combo chart (secondary axis)
///   12 — SVG image
///   13 — editing existing shapes
///   14 — embedded video + audio
///   15 — master / template (footer / date / slide number)
///   16 — closing (with back-link hyperlink)
///
/// The TOC slide is intentionally excluded — its internal hyperlinks
/// would point at non-existent slides in a two-slide deck. The full
/// deck (`build_sample_deck`) exercises the TOC.
pub fn build_sample_isolated(
  feature_idx : Int,
) -> FixedArray[Byte] raise @presentation.PptxError {
  let prs = @presentation.Presentation::new()
  prs.set_slide_size_mut(Widescreen)
  let _ = prs.add_slide_mut(0)
  sample_title_slide(prs, 0)
  if feature_idx == 0 {
    return prs.save()
  }
  // The master/template feature adds its own slide on a defined layout.
  if feature_idx == 15 {
    sample_master_slide(prs)
    return prs.save()
  }
  let _ = prs.add_slide_mut(0)
  match feature_idx {
    1 => sample_text_slide(prs, 1)
    2 => sample_shapes_slide(prs, 1)
    3 => sample_custom_geom_slide(prs, 1)
    4 => sample_picture_slide(prs, 1)
    5 => sample_table_slide(prs, 1)
    6 => sample_charts_1_slide(prs, 1)
    7 => sample_charts_2_slide(prs, 1)
    8 => sample_charts_3_slide(prs, 1)
    9 => sample_charts_4_slide(prs, 1)
    10 => sample_background_slide(prs, 1)
    11 => sample_combo_chart_slide(prs, 1)
    12 => sample_svg_slide(prs, 1)
    13 => sample_edit_slide(prs, 1)
    14 => sample_media_slide(prs, 1)
    // 15 is the master/template feature — handled by the early return
    // above (it adds its own slide on a defined layout).
    16 => sample_smartart_slide(prs, 1)
    17 => sample_animation_slide(prs, 1)
    18 => sample_online_video_slide(prs, 1)
    19 => sample_v06_features_slide(prs, 1)
    _ => sample_closing_slide(prs, 1)
  }
  prs.save()
}

// --- shared helpers ---

///|
/// Standard heading shape positioned at the top of the slide.
/// Centralised so every slide carries the same look + feel.
fn heading(
  prs : @presentation.Presentation,
  id : Int,
  text : String,
) -> @slide.AutoShape {
  @slide.AutoShape::textbox(
    id,
    "Heading",
    prs.pct_w(5.0),
    prs.pct_h(3.0),
    prs.pct_w(90.0),
    prs.pct_h(10.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text(
      text,
      @slide.RunProperties::default()
      .with_font_size(@units.Pt(32.0))
      .with_bold()
      .with_color(@units.RgbColor::new(0x1F, 0x4E, 0x79)),
    ),
  )
}

// --- per-slide builders ---

///|
fn sample_title_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  // Title.
  let title_rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(44.0))
    .with_bold()
    .with_color(@units.RgbColor::new(0x1F, 0x4E, 0x79))
  let title = @slide.AutoShape::textbox(
    2,
    "Title",
    prs.pct_w(5.0),
    prs.pct_h(35.0),
    prs.pct_w(90.0),
    prs.pct_h(20.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text(
      "moon-pptx — feature sample deck", title_rp,
    ),
  )

  // Subtitle with an external hyperlink (A2).
  let link_rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(20.0))
    .with_italic()
    .with_color(@units.RgbColor::new(0x0B, 0x5C, 0xD2))
    .with_hyperlink(
      "https://mooncakes.io/docs/t-ujiie-g/moon-pptx",
      tooltip="Open the docs",
    )
  let subtitle = @slide.AutoShape::textbox(
    3,
    "Subtitle",
    prs.pct_w(5.0),
    prs.pct_h(58.0),
    prs.pct_w(90.0),
    prs.pct_h(10.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text(
      "Pure-MoonBit · type-safe builders · 25 chart families", link_rp,
    ),
  )
  let s = prs.slides()[idx]
    .with_shape(@slide.AutoShape(title))
    .with_shape(@slide.AutoShape(subtitle))
  prs.update_slide_mut(idx, s)

  // A3 — speaker notes on the title slide.
  prs.set_notes_mut(
    idx, "Open with the headline number. Click the subtitle link to demo the external-hyperlink path during the talk.",
  )
}

///|
/// Slide 2 — table of contents with internal hyperlinks (A2 internal).
fn sample_toc_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let head = heading(prs, 2, "What's inside")
  let s_head = prs.slides()[idx].with_shape(@slide.AutoShape(head))
  prs.update_slide_mut(idx, s_head)
  let entries : Array[(String, Int)] = [
    ("3 — Text features", 2),
    ("4 — Shapes + group + connector", 3),
    ("5 — Custom geometry", 4),
    ("6 — Picture with crop", 5),
    ("7 — Tables with custom borders", 6),
    ("8 — Charts: bar / line / pie", 7),
    ("9 — Charts: area / radar / doughnut", 8),
    ("10 — Charts: scatter + bubble", 9),
    ("11 — Charts: 3-D bar / stock / of-pie", 10),
  ]
  let s = prs.slides()[idx]
  let mut row = 0
  let row_h_pct = 7.5
  let mut next_id = 100
  let mut new_slide = s
  for entry in entries {
    let (label, target_idx) = entry
    let rp = @slide.RunProperties::default()
      .with_font_size(@units.Pt(18.0))
      .with_color(@units.RgbColor::new(0x0B, 0x5C, 0xD2))
      .with_hyperlink_to_slide(target_idx, tooltip="Jump to section")
    let line = @slide.AutoShape::textbox(
      next_id,
      "TocEntry" + row.to_string(),
      prs.pct_w(10.0),
      prs.pct_h(15.0 + row.to_double() * row_h_pct),
      prs.pct_w(80.0),
      prs.pct_h(row_h_pct),
      "",
    ).with_text_body(@slide.TextBody::of_styled_text(label, rp))
    new_slide = new_slide.with_shape(@slide.AutoShape(line))
    row = row + 1
    next_id = next_id + 1
  }
  prs.update_slide_mut(idx, new_slide)
}

///|
/// Slide 3 — text features: multi-paragraph + alignment + bullet list.
fn sample_text_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let head = heading(prs, 2, "Text features")
  let p1 = @slide.Paragraph::of_styled_text(
    "Run-level: bold + italic + colour + font + size.",
    @slide.RunProperties::default()
    .with_font_size(@units.Pt(20.0))
    .with_bold()
    .with_color(@units.RgbColor::new(0x1F, 0x4E, 0x79)),
  )
  let p2 = @slide.Paragraph::of_styled_text(
    "Centred paragraph alignment.",
    @slide.RunProperties::default()
    .with_font_size(@units.Pt(18.0))
    .with_italic(),
  ).with_alignment(@slide.TextAlignment::AlignCenter)
  let p3 = @slide.Paragraph::of_styled_text(
    "Right-aligned paragraph (Pt(16)).",
    @slide.RunProperties::default().with_font_size(@units.Pt(16.0)),
  ).with_alignment(@slide.TextAlignment::AlignRight)
  // Bullet list using AutoNum (1., 2., 3.) — exercises the bullet ADT.
  let bullet_rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(16.0))
    .with_color(@units.RgbColor::new(0x33, 0x33, 0x33))
  let bullet_pp : @slide.ParagraphProperties = {
    level: 0,
    alignment: None,
    margin_left: None,
    indent: None,
    line_spacing: None,
    space_before: None,
    space_after: None,
    bullet: Some(@slide.AutoNum(@slide.AutoNumType::ArabicPeriod, 1)),
    extension: [],
  }
  let b1 = @slide.Paragraph::of_styled_text(
    "Numbered list item one (arabicPeriod).", bullet_rp,
  ).with_properties(bullet_pp)
  let b2 = @slide.Paragraph::of_styled_text(
    "Numbered list item two.", bullet_rp,
  ).with_properties(bullet_pp)
  let b3 = @slide.Paragraph::of_styled_text(
    "Numbered list item three.", bullet_rp,
  ).with_properties(bullet_pp)
  let body = @slide.TextBody::of_paragraphs([p1, p2, p3, b1, b2, b3])
  let tb = @slide.AutoShape::textbox(
    3,
    "Body",
    prs.pct_w(5.0),
    prs.pct_h(18.0),
    prs.pct_w(90.0),
    prs.pct_h(75.0),
    "",
  ).with_text_body(body)
  let s = prs.slides()[idx]
    .with_shape(@slide.AutoShape(head))
    .with_shape(@slide.AutoShape(tb))
  prs.update_slide_mut(idx, s)
}

///|
/// Slide 4 — shapes (rect / ellipse / round_rect), a free-floating
/// connector, and a grouped sub-graphic.
fn sample_shapes_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let head = heading(prs, 2, "Shapes + group + connector")
  let row_y = prs.pct_h(20.0)
  let row_h = prs.pct_h(20.0)
  let shape_w = prs.pct_w(20.0)
  let red = @units.RgbColor::new(0xE6, 0x4C, 0x4C)
  let blue = @units.RgbColor::new(0x4C, 0x8C, 0xE6)
  let green = @units.RgbColor::new(0x4C, 0xE6, 0x8C)
  let rect = @slide.AutoShape::rect(
    3,
    "Rect",
    prs.pct_w(7.0),
    row_y,
    shape_w,
    row_h,
  ).with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(red)))
  let ellipse = @slide.AutoShape::ellipse(
    4,
    "Ellipse",
    prs.pct_w(40.0),
    row_y,
    shape_w,
    row_h,
  ).with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(blue)))
  let round = @slide.AutoShape::round_rect(
    5,
    "RoundRect",
    prs.pct_w(73.0),
    row_y,
    shape_w,
    row_h,
  ).with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(green)))

  // A free-floating connector — straight line between two points.
  let line_stroke : @oxml.Stroke = {
    width: Some(@units.Emu(38_100L)), // 3 pt
    cap: None,
    compound: None,
    alignment: None,
    fill: Some(
      @oxml.Fill::SolidFill(
        @oxml.Color::srgb(@units.RgbColor::new(0x33, 0x33, 0x33)),
      ),
    ),
    dash: None,
    join: None,
    head_end: None,
    tail_end: Some({
      arrow_type: @oxml.ArrowType::ArrowTriangle,
      width: None,
      length: None,
    }),
    extension: [],
  }
  let connector : @slide.Connector = {
    id: 6,
    name: "FlowArrow",
    transform: Some(
      @slide.Transform::new(
        offset={ x: prs.pct_w(27.0), y: prs.pct_h(28.0) },
        extent={ cx: prs.pct_w(13.0), cy: @units.Emu(0L) },
      ),
    ),
    geometry: Some(
      @slide.Geometry::Preset(@slide.PresetShape::StraightConnector1, []),
    ),
    stroke: Some(line_stroke),
    effects: None,
    start: None,
    end: None,
    extension: [],
  }

  // A grouped sub-graphic: two rectangles + an ellipse nested inside a
  // <p:grpSp>. The child coordinate space is [0..10000, 0..10000].
  let group_w = prs.pct_w(40.0)
  let group_h = prs.pct_h(30.0)
  let child_rect_1 : @slide.AutoShape = {
    id: 21,
    name: "GroupedRect1",
    placeholder: None,
    transform: Some(
      @slide.Transform::new(
        offset={ x: @units.Emu(0L), y: @units.Emu(0L) },
        extent={ cx: @units.Emu(4000L), cy: @units.Emu(10000L) },
      ),
    ),
    geometry: Some(@slide.Geometry::Preset(@slide.PresetShape::Rect, [])),
    fill: Some(
      @oxml.Fill::SolidFill(
        @oxml.Color::srgb(@units.RgbColor::new(0xF5, 0xC2, 0x42)),
      ),
    ),
    stroke: None,
    effects: None,
    text_body: None,
    hyperlink: None,
    extension: [],
  }
  let child_rect_2 : @slide.AutoShape = {
    id: 22,
    name: "GroupedRect2",
    placeholder: None,
    transform: Some(
      @slide.Transform::new(
        offset={ x: @units.Emu(6000L), y: @units.Emu(0L) },
        extent={ cx: @units.Emu(4000L), cy: @units.Emu(10000L) },
      ),
    ),
    geometry: Some(@slide.Geometry::Preset(@slide.PresetShape::Rect, [])),
    fill: Some(
      @oxml.Fill::SolidFill(
        @oxml.Color::srgb(@units.RgbColor::new(0x42, 0xC2, 0xF5)),
      ),
    ),
    stroke: None,
    effects: None,
    text_body: None,
    hyperlink: None,
    extension: [],
  }
  let child_ellipse : @slide.AutoShape = {
    id: 23,
    name: "GroupedEllipse",
    placeholder: None,
    transform: Some(
      @slide.Transform::new(
        offset={ x: @units.Emu(2500L), y: @units.Emu(2500L) },
        extent={ cx: @units.Emu(5000L), cy: @units.Emu(5000L) },
      ),
    ),
    geometry: Some(@slide.Geometry::Preset(@slide.PresetShape::Ellipse, [])),
    fill: Some(
      @oxml.Fill::SolidFill(
        @oxml.Color::srgb(@units.RgbColor::new(0xF5, 0x42, 0x6C)),
      ),
    ),
    stroke: None,
    effects: None,
    text_body: None,
    hyperlink: None,
    extension: [],
  }
  let group : @slide.GroupShape = {
    id: 30,
    name: "DemoGroup",
    transform: Some(
      @slide.Transform::new(
        offset={ x: prs.pct_w(30.0), y: prs.pct_h(55.0) },
        extent={ cx: group_w, cy: group_h },
      ),
    ),
    child_offset: Some({ x: @units.Emu(0L), y: @units.Emu(0L) }),
    child_extent: Some({ cx: @units.Emu(10000L), cy: @units.Emu(10000L) }),
    children: [
      @slide.AutoShape(child_rect_1),
      @slide.AutoShape(child_rect_2),
      @slide.AutoShape(child_ellipse),
    ],
    extension: [],
  }
  let s = prs.slides()[idx]
    .with_shape(@slide.AutoShape(head))
    .with_shape(@slide.AutoShape(rect))
    .with_shape(@slide.AutoShape(ellipse))
    .with_shape(@slide.AutoShape(round))
    .with_shape(@slide.Connector(connector))
    .with_shape(@slide.Group(group))
  prs.update_slide_mut(idx, s)
}

///|
/// Slide 5 — a five-pointed star drawn via custom geometry path commands.
fn sample_custom_geom_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let head = heading(prs, 2, "Custom geometry (path commands)")

  // Five-pointed star in a 1000×1000 coordinate space. PowerPoint
  // scales the path to the shape's transform extent automatically.
  // Points are clockwise from the top.
  let star_path : @slide.Path = {
    w: @units.Emu(1000L),
    h: @units.Emu(1000L),
    fill: @slide.PathFillMode::PathFillNorm,
    stroke: true,
    extrusion_ok: false,
    commands: [
      @slide.PathCommand::MoveTo({
        x: @slide.AdjCoordinate::Literal(@units.Emu(500L)),
        y: @slide.AdjCoordinate::Literal(@units.Emu(50L)),
      }),
      @slide.PathCommand::LnTo({
        x: @slide.AdjCoordinate::Literal(@units.Emu(620L)),
        y: @slide.AdjCoordinate::Literal(@units.Emu(380L)),
      }),
      @slide.PathCommand::LnTo({
        x: @slide.AdjCoordinate::Literal(@units.Emu(975L)),
        y: @slide.AdjCoordinate::Literal(@units.Emu(380L)),
      }),
      @slide.PathCommand::LnTo({
        x: @slide.AdjCoordinate::Literal(@units.Emu(690L)),
        y: @slide.AdjCoordinate::Literal(@units.Emu(600L)),
      }),
      @slide.PathCommand::LnTo({
        x: @slide.AdjCoordinate::Literal(@units.Emu(800L)),
        y: @slide.AdjCoordinate::Literal(@units.Emu(950L)),
      }),
      @slide.PathCommand::LnTo({
        x: @slide.AdjCoordinate::Literal(@units.Emu(500L)),
        y: @slide.AdjCoordinate::Literal(@units.Emu(740L)),
      }),
      @slide.PathCommand::LnTo({
        x: @slide.AdjCoordinate::Literal(@units.Emu(200L)),
        y: @slide.AdjCoordinate::Literal(@units.Emu(950L)),
      }),
      @slide.PathCommand::LnTo({
        x: @slide.AdjCoordinate::Literal(@units.Emu(310L)),
        y: @slide.AdjCoordinate::Literal(@units.Emu(600L)),
      }),
      @slide.PathCommand::LnTo({
        x: @slide.AdjCoordinate::Literal(@units.Emu(25L)),
        y: @slide.AdjCoordinate::Literal(@units.Emu(380L)),
      }),
      @slide.PathCommand::LnTo({
        x: @slide.AdjCoordinate::Literal(@units.Emu(380L)),
        y: @slide.AdjCoordinate::Literal(@units.Emu(380L)),
      }),
      @slide.PathCommand::Close,
    ],
    extension: [],
  }
  let star_geom : @slide.CustomGeometry = {
    adjust_values: [],
    guides: [],
    connection_sites: [],
    rect: None,
    paths: [star_path],
    extension: [],
  }
  let star : @slide.AutoShape = {
    id: 3,
    name: "Star",
    placeholder: None,
    transform: Some(
      @slide.Transform::new(
        offset={ x: prs.pct_w(33.0), y: prs.pct_h(20.0) },
        extent={ cx: prs.pct_w(34.0), cy: prs.pct_h(70.0) },
      ),
    ),
    geometry: Some(@slide.Geometry::Custom(star_geom)),
    fill: Some(
      @oxml.Fill::SolidFill(
        @oxml.Color::srgb(@units.RgbColor::new(0xFF, 0xC8, 0x2A)),
      ),
    ),
    stroke: None,
    effects: None,
    text_body: None,
    hyperlink: None,
    extension: [],
  }
  let s = prs.slides()[idx]
    .with_shape(@slide.AutoShape(head))
    .with_shape(@slide.AutoShape(star))
  prs.update_slide_mut(idx, s)
}

///|
/// Slide 6 — embed a picture, with the source size derived from the
/// image header and a fluent crop applied on top.
fn sample_picture_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let head = heading(prs, 2, "Picture — auto-size + crop")
  let s_head = prs.slides()[idx].with_shape(@slide.AutoShape(head))
  prs.update_slide_mut(idx, s_head)

  // Insert a synthesized 16 × 16 checkerboard BMP. The image-size
  // auto-detector pulls dimensions straight off the DIB header so we
  // don't pass cx / cy here — the picture renders at 16 × 16 pixels
  // ≈ 0.167" × 0.167" at 96 dpi.
  prs.add_picture_auto_mut(
    idx,
    sample_checkerboard_bmp(),
    prs.pct_w(8.0),
    prs.pct_h(20.0),
  )

  // Add a second picture with an explicit larger extent and a 15 % crop on
  // each edge — via the typed picture builder (v0.4 D4). The pipeline
  // builder → with_crop → build is compile-time-checked: cropping twice, or
  // applying effects after build, wouldn't compile.
  let cropped = @slide.Picture::builder(
      20,
      "CroppedChecker",
      "rId2", // rId2 is what `add_picture_auto_mut` allocated above.
      prs.pct_w(40.0),
      prs.pct_h(20.0),
      prs.pct_w(50.0),
      prs.pct_h(70.0),
    )
    .with_crop(
      left=@units.Percentage(15.0),
      right=@units.Percentage(15.0),
      top=@units.Percentage(15.0),
      bottom=@units.Percentage(15.0),
    )
    .build()
  prs.update_slide_mut(
    idx,
    prs.slides()[idx].with_shape(@slide.Picture(cropped)),
  )

  // Speaker notes describing what the slide demonstrates.
  prs.set_notes_mut(
    idx, "Left: original 16x16 BMP, size auto-derived from the header. Right: same image with a 15% crop on each edge — typed Picture::builder pipeline (D4).",
  )
}

///|
/// Slide 7 — tables: header row with merged cells + per-cell fluent
/// borders + cell fill.
fn sample_table_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let head = heading(prs, 2, "Tables — merged + custom borders")

  // Header cell with yellow fill + thick red borders on top & bottom.
  let red_stroke : @oxml.Stroke = {
    width: Some(@units.Emu(19_050L)), // 1.5 pt
    cap: None,
    compound: None,
    alignment: None,
    fill: Some(
      @oxml.Fill::SolidFill(
        @oxml.Color::srgb(@units.RgbColor::new(0xC0, 0x39, 0x2B)),
      ),
    ),
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
  let header_props = @slide.TableCellProperties::default()
    .with_fill(
      @oxml.Fill::SolidFill(
        @oxml.Color::srgb(@units.RgbColor::new(0xFE, 0xF2, 0x9C)),
      ),
    )
    .with_anchor(@slide.Anchor::AnchorCenter)
    .with_borders(top=red_stroke, bottom=red_stroke)

  // First row: merged header spanning all 3 columns.
  let header = @slide.TableCell::merged_origin(
    "Quarterly results (USD millions)",
    grid_span=3,
  )
  let header = { ..header, properties: Some(header_props) }
  let row_header = @slide.TableRow::of_cells(
    [
      header,
      @slide.TableCell::h_merge_covered(),
      @slide.TableCell::h_merge_covered(),
    ],
    height=@units.Emu(457_200L),
  )

  // Column header row.
  let col_header_rp = @slide.RunProperties::default().with_bold()
  let col_props = @slide.TableCellProperties::default()
    .with_fill(
      @oxml.Fill::SolidFill(
        @oxml.Color::srgb(@units.RgbColor::new(0xE6, 0xE6, 0xE6)),
      ),
    )
    .with_anchor(@slide.Anchor::AnchorCenter)
  let cell_region = {
    ..@slide.TableCell::of_text("Region"),
    text_body: Some(@slide.TextBody::of_styled_text("Region", col_header_rp)),
    properties: Some(col_props),
  }
  let cell_q1 = {
    ..@slide.TableCell::of_text("Q1"),
    text_body: Some(@slide.TextBody::of_styled_text("Q1", col_header_rp)),
    properties: Some(col_props),
  }
  let cell_q2 = {
    ..@slide.TableCell::of_text("Q2"),
    text_body: Some(@slide.TextBody::of_styled_text("Q2", col_header_rp)),
    properties: Some(col_props),
  }
  let col_row = @slide.TableRow::of_cells(
    [cell_region, cell_q1, cell_q2],
    height=@units.Emu(457_200L),
  )

  // Data rows.
  let r1 = @slide.TableRow::of_cells(
    [
      @slide.TableCell::of_text("North"),
      @slide.TableCell::of_text("120"),
      @slide.TableCell::of_text("180"),
    ],
    height=@units.Emu(457_200L),
  )
  let r2 = @slide.TableRow::of_cells(
    [
      @slide.TableCell::of_text("South"),
      @slide.TableCell::of_text("95"),
      @slide.TableCell::of_text("210"),
    ],
    height=@units.Emu(457_200L),
  )
  let col_w = prs.pct_w(20.0)
  let table = @slide.Table::of_rows([row_header, col_row, r1, r2], col_widths=[
    col_w, col_w, col_w,
  ])
  let frame = @slide.GraphicFrame::of_table(
    3,
    "RevenueTable",
    prs.pct_w(20.0),
    prs.pct_h(20.0),
    prs.pct_w(60.0),
    prs.pct_h(50.0),
    table,
  )
  let s = prs.slides()[idx]
    .with_shape(@slide.AutoShape(head))
    .with_shape(@slide.GraphicFrame(frame))
  prs.update_slide_mut(idx, s)
}

///|
/// Slide 8 — bar / line / pie in a 3-up grid.
fn sample_charts_1_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let head = heading(prs, 2, "Charts — bar · line · pie")
  prs.update_slide_mut(
    idx,
    prs.slides()[idx].with_shape(@slide.AutoShape(head)),
  )
  let cat_data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_category("Q4")
    .with_series("Revenue", [120.0, 180.0, 240.0, 310.0])
    .with_series("Costs", [80.0, 110.0, 150.0, 190.0])
  let line_data = @chart.ChartData::new()
    .with_category("Jan")
    .with_category("Feb")
    .with_category("Mar")
    .with_category("Apr")
    .with_category("May")
    .with_series("Visitors", [100.0, 150.0, 200.0, 280.0, 350.0])
  let pie_data = @chart.ChartData::new()
    .with_category("MoonBit")
    .with_category("Rust")
    .with_category("Go")
    .with_category("Other")
    .with_series("Mind share", [45.0, 30.0, 15.0, 10.0])
  three_chart_grid(
    prs,
    idx,
    @chart.Chart::of_bar(cat_data),
    @chart.Chart::of_line(line_data),
    @chart.Chart::of_pie(pie_data),
  )
}

///|
/// Slide 9 — area / radar / doughnut in a 3-up grid.
fn sample_charts_2_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let head = heading(prs, 2, "Charts — area · radar · doughnut")
  prs.update_slide_mut(
    idx,
    prs.slides()[idx].with_shape(@slide.AutoShape(head)),
  )
  let area_data = @chart.ChartData::new()
    .with_category("Mon")
    .with_category("Tue")
    .with_category("Wed")
    .with_category("Thu")
    .with_category("Fri")
    .with_series("Hits", [40.0, 55.0, 70.0, 85.0, 60.0])
  let radar_data = @chart.ChartData::new()
    .with_category("Speed")
    .with_category("Power")
    .with_category("Range")
    .with_category("Comfort")
    .with_category("Price")
    .with_series("Car A", [80.0, 90.0, 70.0, 60.0, 50.0])
    .with_series("Car B", [60.0, 70.0, 90.0, 80.0, 70.0])
  let doughnut_data = @chart.ChartData::new()
    .with_category("Engineering")
    .with_category("Marketing")
    .with_category("Ops")
    .with_category("R&D")
    .with_series("Budget", [40.0, 25.0, 15.0, 20.0])
  three_chart_grid(
    prs,
    idx,
    @chart.Chart::of_area(area_data),
    @chart.Chart::of_radar(radar_data),
    @chart.Chart::of_doughnut(doughnut_data, hole_size=55),
  )
}

///|
/// Slide 10 — scatter + bubble (the two value-axis families) in a 2-up grid.
fn sample_charts_3_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let head = heading(prs, 2, "Charts — scatter + bubble")
  prs.update_slide_mut(
    idx,
    prs.slides()[idx].with_shape(@slide.AutoShape(head)),
  )
  let scatter_data = @chart.ScatterData::new().with_series(
    "Correlation",
    [1.0, 2.0, 3.0, 4.0, 5.0],
    [2.0, 3.5, 5.0, 5.5, 7.0],
  )
  let scatter = @chart.Chart::of_scatter(
    scatter_data,
    scatter_style=@chart.ScatterStyle::Marker,
  )
  let bubble_data = @chart.BubbleData::new().with_series(
    "Markets",
    [1.0, 2.0, 3.0, 4.0],
    [2.0, 4.0, 6.0, 3.5],
    [10.0, 20.0, 30.0, 15.0],
  )
  let bubble = @chart.Chart::of_bubble(bubble_data)
  let chart_w = prs.pct_w(40.0)
  let chart_h = prs.pct_h(75.0)
  let y = prs.pct_h(18.0)
  prs.add_chart_mut(idx, scatter, prs.pct_w(7.0), y, chart_w, chart_h)
  prs.add_chart_mut(idx, bubble, prs.pct_w(53.0), y, chart_w, chart_h)
}

///|
/// Slide 11 — 3-D bar + stock + of-pie in a 3-up grid.
fn sample_charts_4_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let head = heading(prs, 2, "Charts — 3-D bar · stock · of-pie")
  prs.update_slide_mut(
    idx,
    prs.slides()[idx].with_shape(@slide.AutoShape(head)),
  )
  let bar3d_data = @chart.ChartData::new()
    .with_category("Site A")
    .with_category("Site B")
    .with_category("Site C")
    .with_series("Orders", [120.0, 200.0, 150.0])
    .with_series("Errors", [10.0, 30.0, 15.0])
  let stock_data = @chart.ChartData::new()
    .with_category("Mon")
    .with_category("Tue")
    .with_category("Wed")
    .with_series("High", [105.0, 108.0, 112.0])
    .with_series("Low", [98.0, 100.0, 105.0])
    .with_series("Close", [102.0, 106.0, 110.0])
  let ofpie_data = @chart.ChartData::new()
    .with_category("Direct")
    .with_category("Search")
    .with_category("Social")
    .with_category("Email")
    .with_category("Other")
    .with_series("Traffic", [38.0, 28.0, 15.0, 12.0, 7.0])
  three_chart_grid(
    prs,
    idx,
    @chart.Chart::of_bar_3d(bar3d_data),
    @chart.Chart::of_stock(stock_data, kind=HLC),
    @chart.Chart::of_of_pie(ofpie_data),
  )
}

///|
/// Slide 12 — closing slide with a back-to-title hyperlink + notes.
fn sample_closing_slide(
  prs : @presentation.Presentation,
  idx : Int,
) -> Unit raise @presentation.PptxError {
  let heading_rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(40.0))
    .with_bold()
    .with_color(@units.RgbColor::new(0x1F, 0x4E, 0x79))
  let heading_box = @slide.AutoShape::textbox(
    2,
    "Heading",
    prs.pct_w(5.0),
    prs.pct_h(30.0),
    prs.pct_w(90.0),
    prs.pct_h(20.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text("Thanks — try it yourself", heading_rp),
  )
  let body_rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(20.0))
    .with_color(@units.RgbColor::new(0x55, 0x55, 0x55))
  let body = @slide.AutoShape::textbox(
    3,
    "Body",
    prs.pct_w(5.0),
    prs.pct_h(55.0),
    prs.pct_w(90.0),
    prs.pct_h(15.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text(
      "moon-pptx generated this deck — 12 slides, (almost) every typed feature exercised.",
      body_rp,
    ),
  )
  // Hyperlink back to slide 0 (title).
  let back_rp = @slide.RunProperties::default()
    .with_font_size(@units.Pt(18.0))
    .with_color(@units.RgbColor::new(0x0B, 0x5C, 0xD2))
    .with_italic()
    .with_hyperlink_to_slide(0, tooltip="Back to title")
  let back = @slide.AutoShape::textbox(
    4,
    "BackLink",
    prs.pct_w(5.0),
    prs.pct_h(78.0),
    prs.pct_w(90.0),
    prs.pct_h(8.0),
    "",
  ).with_text_body(
    @slide.TextBody::of_styled_text("← Back to title slide", back_rp),
  )
  let s = prs.slides()[idx]
    .with_shape(@slide.AutoShape(heading_box))
    .with_shape(@slide.AutoShape(body))
    .with_shape(@slide.AutoShape(back))
  prs.update_slide_mut(idx, s)
  prs.set_notes_mut(
    idx, "Use the back-link to demo internal hyperlinks during Q&A.",
  )
}

// --- chart-grid helper ---

///|
/// Drop three charts side-by-side beneath the heading. Slide-width is
/// split as 5 % margin · chart · 2.5 % gap · chart · 2.5 % gap · chart
/// · 5 % margin. Each chart occupies 28.3 % of the slide width.
fn three_chart_grid(
  prs : @presentation.Presentation,
  idx : Int,
  a : @chart.Chart,
  b : @chart.Chart,
  c : @chart.Chart,
) -> Unit raise @presentation.PptxError {
  let w = prs.pct_w(28.33)
  let h = prs.pct_h(75.0)
  let y = prs.pct_h(18.0)
  prs.add_chart_mut(idx, a, prs.pct_w(5.0), y, w, h)
  prs.add_chart_mut(idx, b, prs.pct_w(35.83), y, w, h)
  prs.add_chart_mut(idx, c, prs.pct_w(66.66), y, w, h)
}

// --- synthesized image ---

///|
/// Build a 16 × 16 24-bpp BMP carrying a 4 × 4 checkerboard pattern
/// (red and dark-blue squares). Total file size: 14 (file header) +
/// 40 (BITMAPINFOHEADER) + 16 × 48 (pixel data, BGR triples, 4-byte
/// row alignment is automatic at this width) = 822 bytes.
///
/// We keep the image small enough to embed verbatim in the source
/// rather than shipping a binary fixture — the "no FFI" policy means
/// we can't read it off disk inside the build function.
fn sample_checkerboard_bmp() -> FixedArray[Byte] {
  let width = 16
  let height = 16
  let row_bytes = width * 3
  let pixel_data_size = row_bytes * height
  let total = 14 + 40 + pixel_data_size
  let out = FixedArray::make(total, b'\x00')
  // File header.
  out[0] = b'B'
  out[1] = b'M'
  write_u32_le(out, 2, total)
  // bytes 6–9 reserved = 0
  write_u32_le(out, 10, 54) // pixel data offset
  // DIB header (BITMAPINFOHEADER).
  write_u32_le(out, 14, 40) // header size
  write_u32_le(out, 18, width)
  write_u32_le(out, 22, height)
  out[26] = b'\x01' // planes = 1
  out[28] = b'\x18' // bpp = 24
  // compression / image size / ppm / colors-used left as zeros.
  // Pixel data — BMP rows are bottom-up.
  let red_b = b'\x4C'
  let red_g = b'\x4C'
  let red_r = b'\xE6'
  let blue_b = b'\xE6'
  let blue_g = b'\x8C'
  let blue_r = b'\x4C'
  let square = 4 // 4×4 squares makes a 4×4 visible board on a 16×16 image
  for row in 0..<height {
    for col in 0..<width {
      // (row / square + col / square) parity picks the colour.
      let parity = (row / square + col / square) % 2
      let off = 54 + row * row_bytes + col * 3
      if parity == 0 {
        out[off] = red_b
        out[off + 1] = red_g
        out[off + 2] = red_r
      } else {
        out[off] = blue_b
        out[off + 1] = blue_g
        out[off + 2] = blue_r
      }
    }
  }
  out
}

///|
fn write_u32_le(buf : FixedArray[Byte], offset : Int, value : Int) -> Unit {
  buf[offset] = (value & 0xFF).to_byte()
  buf[offset + 1] = ((value >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((value >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((value >> 24) & 0xFF).to_byte()
}
