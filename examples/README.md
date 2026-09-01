# moon-pptx — Examples

This directory holds two complementary entry points for learning
moon-pptx:

| Where | What | When to use |
|---|---|---|
| [`README.md`](README.md) (this file) | Cookbook of focused recipes, one feature per section | Quick reference / copy-paste templates |
| [`sample-deck/`](sample-deck/) | Standalone MoonBit module — a 26-slide deck built end-to-end, exercising every typed feature | "Show me a real consumer project" / regenerate `sample.pptx` for verification |

`sample-deck/` is its own MoonBit module (`moon.mod`) and depends
on `t-ujiie-g/moon-pptx` exactly the way a downstream consumer would.
The recipes below use the same import shape (`@presentation.*`,
`@chart.*`, …) so they're copy-pastable into a project that
`moon add`s the library.

Each cookbook recipe below is verified by a matching test in
[`src/integration/examples_test.mbt`](../src/integration/examples_test.mbt)
so the code on this page stays in lockstep with the library.

For the full API reference, see the [main README](../README.mbt.md)
and the [mooncakes docs](https://mooncakes.io/docs/t-ujiie-g/moon-pptx).

> All paths and sizes below use `@units.Emu` for type safety — confusing
> Emu with Pt is a compile error. Use `prs.pct_w(N)` / `prs.pct_h(N)`
> for percent-of-slide positioning, or hard-code EMU values
> (914_400 EMU = 1 inch).

---

## 1. A title slide with styled text

```moonbit
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)

let rp = @slide.RunProperties::default()
  .with_font_size(@units.Pt(44.0))
  .with_bold()
  .with_color(@units.RgbColor::new(0x1F, 0x4E, 0x79))
let body = @slide.TextBody::of_styled_text("Hello, MoonBit", rp)

let title = @slide.AutoShape::textbox(
  id=2, name="Title",
  x=prs.pct_w(10.0), y=prs.pct_h(40.0),
  cx=prs.pct_w(80.0), cy=prs.pct_h(20.0),
  "",
).with_text_body(body)

prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(title)))
let _bytes = prs.save()
```

`prs.pct_w(10.0)` returns 10 % of the slide's current width as an
`@units.Emu`. The default slide size is 10 in × 7.5 in (4:3); switch
to widescreen with `prs.set_slide_size_mut(Widescreen)` for 13.33 in
× 7.5 in.

---

## 2. Switch to 16:9 widescreen

```moonbit
let prs = @presentation.Presentation::new()
prs.set_slide_size_mut(Widescreen)
// Subsequent `pct_w` / `pct_h` calls now resolve against 12_192_000 × 6_858_000 EMU.
```

Available presets: `ScreenFourByThree`, `ScreenSixteenByNine`,
`ScreenSixteenByTen`, `Widescreen`, `Letter`, `A4`, `ThirtyFiveMm`,
`Banner`. For anything else, use `Custom(cx_emu, cy_emu)`.

---

## 3. Hyperlinks (external URL + internal slide jump)

```moonbit
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)
let _ = prs.add_slide_mut(0)  // a second slide to link to

// External URL with a tooltip.
let link = @slide.RunProperties::default()
  .with_font_size(@units.Pt(20.0))
  .with_color(@units.RgbColor::new(0x0B, 0x5C, 0xD2))
  .with_hyperlink("https://moonbitlang.com", tooltip="docs")

// Internal jump to slide 1 (zero-based).
let jump = @slide.RunProperties::default()
  .with_hyperlink_to_slide(1)

let tb1 = @slide.TextBody::of_styled_text("moonbitlang.com", link)
let tb2 = @slide.TextBody::of_styled_text("→ next slide", jump)

let box1 = @slide.AutoShape::textbox(
  id=2, name="ExtLink",
  x=prs.pct_w(10.0), y=prs.pct_h(20.0),
  cx=prs.pct_w(80.0), cy=prs.pct_h(15.0),
  "",
).with_text_body(tb1)

let box2 = @slide.AutoShape::textbox(
  id=3, name="IntLink",
  x=prs.pct_w(10.0), y=prs.pct_h(50.0),
  cx=prs.pct_w(80.0), cy=prs.pct_h(15.0),
  "",
).with_text_body(tb2)

let s = prs.slides()[0]
  .with_shape(@slide.AutoShape(box1))
  .with_shape(@slide.AutoShape(box2))
prs.update_slide_mut(0, s)
```

`update_slide_mut` does all the OPC plumbing: allocates rIds, registers
relationships (external `TargetMode::External` + `rt_hyperlink`, internal
`Internal` + `rt_slide`), and rewrites `<a:hlinkClick>` with the
final rId.

---

## 4. Speaker notes

```moonbit
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)
prs.set_notes_mut(0, "Remember to thank the team — XML-special chars like <&> are escaped automatically.")
```

First call creates `/ppt/notesSlides/notesSlide1.xml`, registers the
content type, and adds the slide → notesSlide relationship. Subsequent
calls on the same slide replace the notes content in place.

---

## 5. Images with auto-derived size + cropping

```moonbit nocheck
// Read your image bytes via whatever I/O your backend supports.
let png_bytes : FixedArray[Byte] = read_my_image_file()

let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)

// `add_picture_auto_mut` parses the PNG / JPEG / GIF / BMP / TIFF
// header + DPI metadata and computes (cx, cy) for you.
prs.add_picture_auto_mut(
  0, png_bytes,
  x=prs.pct_w(10.0), y=prs.pct_h(10.0),
)

// To crop inside the image, fluently:
let pic = @slide.Picture::of_image(
  id=10, name="Cropped", "rId2",
  x=prs.pct_w(50.0), y=prs.pct_h(10.0),
  cx=prs.pct_w(40.0), cy=prs.pct_h(80.0),
).with_crop(
  left=@units.Percentage(10.0),
  right=@units.Percentage(10.0),
)
```

For exact sizing, fall back to the explicit `add_picture_mut(slide_idx,
bytes, x=x, y=y, cx=cx, cy=cy)` overload.

---

## 6. Tables with merged cells and styled borders

```moonbit
let red = @units.RgbColor::parse_hex("FF0000")
let red_stroke : @oxml.Stroke = {
  width: Some(@units.Emu(12_700L)), cap: None, compound: None,
  alignment: None, fill: Some(@oxml.Fill::SolidFill(@oxml.Color::srgb(red))),
  dash: None, join: None, head_end: None, tail_end: None, extension: [],
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

let t = @slide.Table::of_rows(
  [row0, row1],
  col_widths=[@units.Emu(2_286_000L), @units.Emu(2_286_000L)],
)

let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)
let gf = @slide.GraphicFrame::of_table(
  id=10, name="Summary",
  x=prs.pct_w(10.0), y=prs.pct_h(20.0),
  cx=prs.pct_w(60.0), cy=prs.pct_h(50.0),
  t,
)
prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.GraphicFrame(gf)))
```

`with_borders` is a fluent helper — pass `None` (default) for any edge
you want to leave untouched.

To restyle the whole table, apply one of PowerPoint's 74 built-in
gallery styles by name instead of hand-styling cells —
`Table::with_style` sets the style reference plus the header-emphasis
and row-banding flags (both default on, as PowerPoint does):

```moonbit
let styled = t.with_style(MediumStyle2Accent1) // the insert-table default
let plain = t.with_style(LightStyle1, first_row=false, band_row=false)
```

---

## 7. A bar chart from a data table

```moonbit
let data = @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_category("Q3")
  .with_category("Q4")
  .with_series("Revenue", [100.0, 200.0, 300.0, 250.0])
  .with_series("Cost",    [60.0,  110.0, 180.0, 140.0])

let chart = @chart.Chart::of_bar(data)
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)

prs.add_chart_mut(
  0, chart,
  x=prs.pct_w(10.0), y=prs.pct_h(15.0),
  cx=prs.pct_w(80.0), cy=prs.pct_h(70.0),
)
```

Swap `Chart::of_bar` for any of the 16 standard families
(`of_line`, `of_pie`, `of_area`, `of_radar`, `of_doughnut`,
`of_scatter`, `of_bubble`, `of_stock`, `of_surface`,
`of_surface_3d`, `of_bar_3d`, `of_line_3d`, `of_pie_3d`,
`of_of_pie`) — or the 9 extended chartEx families.

To make PowerPoint's "Edit Data" button open the real rows in Excel
(instead of a blank sheet), pass the chart's data again as
`embed_data` — an editable `.xlsx` workbook mirroring it is generated
and embedded alongside the chart:

```moonbit
prs.add_chart_mut(
  0, chart,
  x=prs.pct_w(10.0), y=prs.pct_h(15.0),
  cx=prs.pct_w(80.0), cy=prs.pct_h(70.0),
  embed_data=data,
)
```

---

## 8. A complete 3-slide pitch deck

```moonbit
let prs = @presentation.Presentation::new()
prs.set_slide_size_mut(Widescreen)

// --- Slide 1: title ---
let _ = prs.add_slide_mut(0)
let title_rp = @slide.RunProperties::default()
  .with_font_size(@units.Pt(44.0))
  .with_bold()
  .with_color(@units.RgbColor::new(0x1F, 0x4E, 0x79))
let title = @slide.AutoShape::textbox(
  id=2, name="Title",
  x=prs.pct_w(10.0), y=prs.pct_h(40.0),
  cx=prs.pct_w(80.0), cy=prs.pct_h(20.0),
  "",
).with_text_body(@slide.TextBody::of_styled_text("Q4 results", title_rp))
prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(title)))
prs.set_notes_mut(0, "Open with the headline number.")

// --- Slide 2: chart ---
let _ = prs.add_slide_mut(0)
let data = @chart.ChartData::new()
  .with_category("Q1").with_category("Q2").with_category("Q3").with_category("Q4")
  .with_series("Revenue", [100.0, 200.0, 300.0, 450.0])
prs.add_chart_mut(
  1, @chart.Chart::of_bar(data),
  x=prs.pct_w(10.0), y=prs.pct_h(15.0),
  cx=prs.pct_w(80.0), cy=prs.pct_h(70.0),
)

// --- Slide 3: closing with link to slide 1 ---
let _ = prs.add_slide_mut(0)
let link_rp = @slide.RunProperties::default()
  .with_font_size(@units.Pt(20.0))
  .with_hyperlink_to_slide(0, tooltip="back to title")
let closing = @slide.AutoShape::textbox(
  id=2, name="Closing",
  x=prs.pct_w(10.0), y=prs.pct_h(40.0),
  cx=prs.pct_w(80.0), cy=prs.pct_h(15.0),
  "",
).with_text_body(@slide.TextBody::of_styled_text("← back", link_rp))
prs.update_slide_mut(2, prs.slides()[2].with_shape(@slide.AutoShape(closing)))

let bytes = prs.save()
// Save `bytes` to a file via whatever I/O your backend offers.
```

---

## 9. Typed layout slides (compile-time placeholder schema)

Each typed constructor returns a handle that only exposes the placeholders
its layout actually has — so a typo like `.body()` on a title slide is a
**compile error**, not a silently-dropped shape.

```moonbit
let prs = @presentation.Presentation::new()

let _ = prs.add_title_slide_mut()
  .title("Quarterly Review")
  .subtitle("FY2026 · Q3")    // only a title slide has a subtitle
  .finish_mut()

let _ = prs.add_title_content_slide_mut()
  .title("Agenda")
  .body("Results · Outlook · Q&A")
  .finish_mut()
```

Constructors: `add_title_slide_mut` (title + subtitle),
`add_title_content_slide_mut` (title + body),
`add_section_header_slide_mut` (title + body), `add_title_only_slide_mut`
(title), `add_blank_typed_slide_mut` (no placeholders). Each resolves or
synthesises the matching `<p:sldLayout>`. The index-based
`add_slide_mut(layout_index)` still works for full control.

---

## 10. Slide transitions

```moonbit
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)

// A fade that also auto-advances after 3 seconds.
let s = prs.slides()[0].with_transition(
  @slide.Transition::fade().with_advance_after(3000),
)
prs.update_slide_mut(0, s)
```

Other effects: `Transition::push(Right)`, `wipe(Up)`, `cover(LeftDown)`,
`split(Vertical, In)`, `cut`, `zoom(In)`, `dissolve`, plus the rest of the
base set via `Transition::of_kind(...)`. Tune timing with `with_speed`,
`with_on_click`, and `with_advance_after`.

---

## 11. ADT-driven chart options

```moonbit
let data = @chart.ChartData::new()
  .with_category("Q1").with_category("Q2")
  .with_series("Revenue", [100.0, 200.0])

let chart = @chart.Chart::of_bar(data).with_options([
  Title("Revenue"),
  Legend(LegendBottom),
  DataLabels(DLblOutEnd),
])
```

`ChartOption` also covers `TitleDeleted`, `LegendHidden`,
`DataLabelsHidden`, `DataTable(true)`, `Style(n)`, `RoundedCorners(b)`,
`PlotVisibleOnly(b)`, and `DisplayBlanks(...)`.

---

## 12. Typed picture builder pipeline

The crop-then-effects pipeline is enforced by the type system: cropping
twice, or applying effects after `build()`, won't compile.

```moonbit
let pic = @slide.Picture::builder(
    id=5, name="Logo", "rId2",
    x=@units.Emu(0L), y=@units.Emu(0L),
    cx=@units.Emu(914_400L), cy=@units.Emu(914_400L),
  )
  .with_crop(left=@units.Percentage(10.0), right=@units.Percentage(10.0))
  .with_effects(outline=my_stroke)
  .build()
```

`Picture::of_image` / `with_crop` remain as the unconstrained flat path.

---

## 13. Chart-data validation

`with_series` is lenient by default (short rows are zero-padded). Call
`validate()` for a strict check that a series has exactly one value per
category — it returns the data so it composes straight into a builder:

```moonbit
let data = @chart.ChartData::new()
  .with_category("Q1").with_category("Q2")
  .with_series("Revenue", [10.0, 20.0])

let chart = @chart.Chart::of_bar(data.validate())   // raises Malformed on a mismatch
```

Use the non-raising `data.is_consistent()` for a boolean check.
`ScatterData` and `BubbleData` have matching `validate` / `is_consistent`.

---

## 14. Animations (entrance / emphasis / exit / motion)

Build a `Timeline` of steps that target shapes by id, then attach it to
the slide. `save()` emits the full canonical `<p:timing>` tree.

```moonbit
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)

// A shape to animate (shape id 2).
let box = @slide.AutoShape::textbox(
  id=2, name="Box",
  x=prs.pct_w(10.0), y=prs.pct_h(30.0), cx=prs.pct_w(40.0), cy=prs.pct_h(20.0),
  "Fly in!",
)
let slide = prs.slides()[0].with_shape(@slide.AutoShape(box))

// First click: fly in from the left. Second click: spin 360° for emphasis.
let timeline = @slide.Timeline::new()
  .on_click(Entrance(FlyIn(Left)), 2)
  .on_click(Emphasis(Spin(360)), 2)
prs.update_slide_mut(0, slide.with_animations(timeline))
```

`AnimEffect` covers `Entrance` / `Exit` (over a shared `VisualEffect`:
`Appear` / `Fade` / `FlyIn(dir)` / `Wipe(dir)` / `Blinds` / `Wheel(n)` /
…), `Emphasis` (`Spin` / `GrowShrink` / `ChangeFillColor`), and
`Motion(MotionPath)` for a custom path. Start each step with
`on_click` / `with_previous` / `after_previous`, and pass `paragraph=N`
to build a text body one paragraph at a time.

---

## 15. SmartArt diagrams

`add_smartart_mut` synthesises the full five-part DiagramML graphic
(data / layout / quickStyle / colors + a cached drawing) and drops it on
the slide.

```moonbit
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)

let art = @smartart.SmartArt::process(["Plan", "Build", "Ship"])
prs.add_smartart_mut(
  0, art,
  x=prs.pct_w(10.0), y=prs.pct_h(15.0), cx=prs.pct_w(80.0), cy=prs.pct_h(70.0),
)
```

All eight families build and render: the flat `SmartArt::list` /
`process` / `cycle` / `pyramid` / `matrix(items)`, the tree
`org_chart(root)` / `hierarchy(nodes)`, and
`relationship(center, related)` (hub-and-spoke). The tree families take
nested `Node`s:

```moonbit
let ceo = @smartart.Node::new("CEO", [
  @smartart.Node::leaf("CTO"),
  @smartart.Node::new("CFO", [@smartart.Node::leaf("Controller")]),
])
prs.add_smartart_mut(
  0, @smartart.SmartArt::org_chart(ceo),
  x=prs.pct_w(10.0), y=prs.pct_h(15.0), cx=prs.pct_w(80.0), cy=prs.pct_h(70.0),
)
```

PowerPoint lays SmartArt out from the layout definition on open; the
nesting families ship a recursive `hierRoot`/`hierChild` definition (and
`relationship` a radial one), so the whole tree lays out — children,
connector lines and all.

Individual nodes take colour overrides on top of the diagram's quick
style — box fill, outline, and text colour, each optional:

```moonbit
let hot = @smartart.Node::leaf("Ship")
  .with_fill(@units.RgbColor::new(0xC0, 0x00, 0x00))
  .with_text_color(@units.RgbColor::new(0xFF, 0xFF, 0xFF))
let art = @smartart.SmartArt::new(Process, [
  @smartart.Node::leaf("Plan"),
  @smartart.Node::leaf("Build"),
  hot,
])
```

The overrides land in both the diagram data model (what PowerPoint's
layout engine applies) and the cached drawing (what non-editing viewers
show), so the colours hold everywhere.

---

## 16. YouTube / online video

Embed a streaming video by URL — no media bytes in the deck, just the
external relationship plus a caller-supplied preview frame.

```moonbit nocheck
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)

// Read a poster image via whatever I/O your backend supports.
let poster : FixedArray[Byte] = read_my_image_file()

// Any YouTube share/watch/embed/shorts URL is normalised to the embed form.
prs.add_youtube_video_mut(
  0, "https://youtu.be/dQw4w9WgXcQ", poster,
  x=prs.pct_w(10.0), y=prs.pct_h(10.0), cx=prs.pct_w(80.0), cy=prs.pct_h(80.0),
)
```

For any other streaming URL, use the general
`add_online_video_mut(slide_idx, video_url, poster, x=x, y=y, cx=cx, cy=cy)`.

---

## 17. Plot-type-aware chart validation

Beyond the data-shape check in §13, `Chart::validate()` rejects data-label
positions a chart's plot family doesn't allow — catching a repair-banner
trigger before PowerPoint sees the file.

```moonbit
let data = @chart.ChartData::new()
  .with_category("Q1").with_category("Q2")
  .with_series("Revenue", [10.0, 20.0])

// `outEnd` labels are valid on a bar chart…
let _ = @chart.Chart::of_bar(data).with_options([DataLabels(DLblOutEnd)]).validate()

// …but invalid on a line chart (line labels allow only ctr / l / r / t / b).
let line = @chart.Chart::of_line(data).with_options([DataLabels(DLblOutEnd)])
assert_eq(line.is_consistent(), false)   // and `line.validate()` raises Malformed
```

---

## 18. Slide sections

Sections group slides in PowerPoint's slide panel. Each `Section`
names where it starts; it runs to the next section's start, the last
to the end of the deck — so the list partitions every slide, which is
what PowerPoint expects.

```moonbit
let prs = @presentation.Presentation::new()
for _ in 0..<4 {
  let _ = prs.add_slide_mut(0)
}
prs.set_sections_mut([
  { title: "Introduction", start: 0 },
  { title: "Content", start: 1 },
  { title: "Conclusion", start: 3 },
])

// Or grow them one at a time (kept in slide order automatically):
prs.add_section_mut(title="Details", start=2)

// Read back / remove:
let sections = prs.sections()      // -> Array[Section]
prs.set_sections_mut([])           // removes all sections
```

The first section must start at slide 0 and starts must be
non-decreasing (two equal starts make the earlier section empty —
PowerPoint allows slide-less sections). `with_sections` is the
immutable counterpart.

---

## 19. Document properties (core + app)

Two parts back File ▸ Info: `docProps/core.xml` (title, author, dates —
whole-part replace, so start from the current values) and
`docProps/app.xml` (company, manager, application — a merge that leaves
the app-maintained statistics untouched).

```moonbit
let prs = @presentation.Presentation::new()

prs.set_core_properties_mut(
  prs.core_properties().with_title("Q3 Review").with_author("Ada"),
)

prs.set_app_properties_mut(
  @presentation.AppProperties::new()
    .with_company("ACME Corp")
    .with_manager("Grace"),
)
```

`app_properties()` reads the current values back; fields left unset by
the merge — and everything else in app.xml, word counts and
`TitlesOfParts` included — are preserved as-is.

---

## 20. Right-to-left text and paragraph-mark formatting

`with_rtl(true)` sets the `rtl` attribute on the paragraph, which is what
Arabic, Hebrew, and Persian layouts need. Keep the runs in *logical*
order — PowerPoint does the bidi reordering when it renders.

```moonbit
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)

let rp = @slide.RunProperties::default().with_font_size(@units.Pt(28.0))
let para = @slide.Paragraph::of_styled_text("مرحبا بالعالم", rp).with_rtl(true)

// `end_run_properties` styles the paragraph mark itself: it is what an
// empty paragraph is sized by, and what the next character typed at the
// end of the paragraph inherits. Here it gives a blank spacer paragraph
// a real height without needing a dummy run.
let spacer = @slide.Paragraph::of_text("").with_end_run_properties(
  @slide.RunProperties::default().with_font_size(@units.Pt(12.0)),
)

let body = @slide.TextBody::of_paragraphs([para, spacer])
let shape = @slide.AutoShape::textbox(
  id=2, name="Arabic",
  x=prs.pct_w(10.0), y=prs.pct_h(30.0),
  cx=prs.pct_w(80.0), cy=prs.pct_h(25.0),
  "",
).with_text_body(body)

prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(shape)))
let _bytes = prs.save()
```

Direction is per paragraph, so a single text box can mix an RTL heading
with LTR body text. Leaving `with_rtl` off is not the same as
`with_rtl(false)`: unset inherits direction from the list style and
master, while `false` pins the paragraph to left-to-right.

---

## 21. Japanese / CJK text and font resolution

`with_font` only sets the Latin slot (`<a:latin>`), so CJK characters keep
whatever the theme picks for them — which in an Office theme is usually
nothing. Set all three script slots instead:

```moonbit
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)

let rp = @slide.RunProperties::default()
  .with_font_size(@units.Pt(28.0))
  .with_font_for_all_scripts("Meiryo")   // <a:latin> + <a:ea> + <a:cs>

let body = @slide.TextBody::of_styled_text("日本語のテキスト", rp)
let shape = @slide.AutoShape::textbox(
  id=2, name="JP",
  x=prs.pct_w(10.0), y=prs.pct_h(30.0),
  cx=prs.pct_w(80.0), cy=prs.pct_h(25.0),
  "",
).with_text_body(body)

prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.AutoShape(shape)))
let _bytes = prs.save()
```

Use `with_east_asian_font` / `with_complex_script_font` when the scripts
should differ — Latin in Calibri, Japanese in Meiryo.

### Reading a font back

A run in an existing deck usually does *not* name its font: PowerPoint
writes theme references, and CJK faces live in the theme's per-script list
rather than on the run. So ask the resolver, not the field:

```moonbit nocheck
let scheme = prs.themes()[0].font_scheme

// `rp.latin` here is the literal string "+mn-lt", not a font.
@slide.resolve_run_fonts(rp, scheme).latin        // -> "Calibri"

// What Japanese text in this run actually renders with. Prefers the
// theme's <a:font script="Jpan"> entry, because Office themes ship
// <a:ea typeface=""/> and keep the real face there.
@slide.resolve_run_font_for_script(rp, scheme, "Jpan")   // -> "ＭＳ Ｐゴシック"
```

Pass `major=true` for heading text, which resolves against `<a:majorFont>`.
The script argument is an ISO-15924 tag — `"Jpan"`, `"Hans"`, `"Hant"`,
`"Hang"`, `"Arab"`, `"Thai"`, and so on.

## 22. Shape ids without keeping a counter

Every shape builder takes an explicit `<p:cNvPr id>`, and two shapes sharing
one on the same slide is something PowerPoint may offer to repair the file
over. `with_shape_auto_id` renumbers the shape as it appends, so nothing has
to track the next free id:

```moonbit
let prs = @presentation.Presentation::new()
let _ = prs.add_slide_mut(0)

let box = @slide.AutoShape::textbox(
  id=1, name="Box",                                  // this id is discarded
  x=prs.pct_w(10.0), y=prs.pct_h(20.0),
  cx=prs.pct_w(35.0), cy=prs.pct_h(20.0),
  "left",
)

// Appended twice from the same builder — each copy gets its own id.
let slide = prs.slides()[0]
  .with_shape_auto_id(@slide.AutoShape(box))
  .with_shape_auto_id(@slide.AutoShape(box))
prs.update_slide_mut(0, slide)

assert_eq(slide.duplicate_shape_ids().length(), 0)
let _bytes = prs.save()
```

`next_shape_id()` hands out the same number if you would rather pass it to a
builder yourself, and `duplicate_shape_ids()` reports the clashes on a slide
you did not build — it returns them instead of raising, because a deck
parsed from a third-party file can arrive with duplicates and must still
round-trip unchanged.

---

## Where to next?

- [README.md](../README.md#comparison-with-python-pptx-and-pptxgenjs) — full feature comparison vs python-pptx + PptxGenJS.
- [ROADMAP.md](../ROADMAP.md) — direction, open gaps, and architecture decisions.
- [CHANGELOG.md](../CHANGELOG.md) — what changed in this version.
- [main README](../README.mbt.md) — sub-package overview + install instructions.
