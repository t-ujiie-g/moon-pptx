# moon-pptx

[![CI](https://github.com/t-ujiie-g/moon-pptx/actions/workflows/ci.yml/badge.svg)](https://github.com/t-ujiie-g/moon-pptx/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

A pure-MoonBit library for reading, building, and writing PowerPoint
presentations (`.pptx` / OOXML). Type-safe units, immutable builders,
lossless round-trip of unknown XML — and no FFI, so it runs on every
MoonBit backend.

## Features

- **Read and write** `.pptx` packages end-to-end — themes, masters,
  layouts, slides, notes, comments — without ever materialising XML by
  hand.
- **Builder API** for creating decks from scratch: text boxes, shapes,
  pictures, tables, and charts via `Presentation::new() →
  add_slide_mut → with_shape → save`.
- **All 16 standard chart families** plus the Microsoft 2016 extended
  chartEx families (waterfall, treemap, sunburst, histogram,
  boxWhisker, funnel, paretoLine, regionMap, clusteredColumn).
- **Type-safe units** — `Emu`, `Pt`, `Inch`, `Cm`, `Angle`,
  `Percentage`, `RgbColor`, `ThemeColor` are distinct types; the
  compiler stops you from mixing them.
- **Immutable builders** — `slide.with_shape(s)` returns a new value;
  `_mut` variants exist where editing existing decks is the natural
  shape.
- **Lossless round-trip** — unknown OOXML extensions are preserved
  verbatim on read → write, so files survive parsers that don't know
  every Microsoft extension element.
- **Pure MoonBit** — depends only on
  [`hustcer/fzip`](https://mooncakes.io/docs/hustcer/fzip) for
  ZIP/DEFLATE. No FFI, works on Native / Wasm-GC / JS / Wasm.

See [Comparison with python-pptx and PptxGenJS](#comparison-with-python-pptx-and-pptxgenjs)
for a feature-by-feature matrix, including the places those libraries
are still ahead.

## Install

```bash
moon add t-ujiie-g/moon-pptx
```

## Quickstart

### Build a one-slide deck from scratch

```moonbit nocheck
let prs = @presentation.Presentation::new()

// Append a slide using the built-in Blank layout at index 0.
let _ = prs.add_slide_mut(0)

// Drop a title text box onto the new slide.
let s = prs.slides()[0]
let tb = @slide.AutoShape::textbox(
  2, "Title",
  @units.Emu(457_200L),    // x = ½" margin
  @units.Emu(2_438_400L),  // y ≈ 2.7" from top
  @units.Emu(8_229_600L),  // width = slide width − 2× margin
  @units.Emu(914_400L),    // height = 1"
  "Hello, MoonBit",
)
prs.update_slide_mut(0, s.with_shape(@slide.AutoShape(tb)))

// `save()` returns PPTX bytes — write them with whatever I/O your
// backend supports.
let bytes : FixedArray[Byte] = prs.save()
```

### Tables

Tables live inside `<p:graphicFrame>` shapes. The builders cover the
common cases (empty grid, custom cell contents, merged cells, cell
fills / borders / margins) without touching XML.

```moonbit nocheck
let yellow = @units.RgbColor::parse_hex("FFFF00")
let header_props = @slide.TableCellProperties::default()
  .with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(yellow)))
  .with_anchor(@slide.Anchor::AnchorCenter)
let header = @slide.TableCell::merged_origin("Header", grid_span=2)
let header = { ..header, properties: Some(header_props) }

let row0 = @slide.TableRow::of_cells(
  [header, @slide.TableCell::h_merge_covered()],
  height=@units.Emu(457_200L),
)
let row1 = @slide.TableRow::of_cells(
  [
    @slide.TableCell::of_text("A2"),
    @slide.TableCell::of_text("B2"),
  ],
  height=@units.Emu(457_200L),
)
let t = @slide.Table::of_rows(
  [row0, row1],
  col_widths=[@units.Emu(2_286_000L), @units.Emu(2_286_000L)],
)
let gf = @slide.GraphicFrame::of_table(
  10, "Summary",
  @units.Emu(914_400L), @units.Emu(914_400L),
  @units.Emu(4_572_000L), @units.Emu(914_400L),
  t,
)
prs.update_slide_mut(0, prs.slides()[0].with_shape(@slide.GraphicFrame(gf)))
```

### Charts

Build a chart from a data table, then drop it onto a slide:

```moonbit nocheck
let data = @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_category("Q3")
  .with_category("Q4")
  .with_series("Revenue", [100.0, 200.0, 300.0, 250.0])
  .with_series("Cost",    [60.0,  110.0, 180.0, 140.0])

// Pick a family: bar / line / pie / area / radar / doughnut / …
let chart = @chart.Chart::of_bar(data)
// or:  @chart.Chart::of_line(data, grouping=Stacked)
// or:  @chart.Chart::of_pie(data)
// or:  @chart.Chart::of_doughnut(data, hole_size=60)

prs.add_chart_mut(
  0, chart,
  @units.Emu(914_400L), @units.Emu(1_828_800L),
  @units.Emu(4_572_000L), @units.Emu(3_429_000L),
)
```

Scatter and bubble charts use dedicated XY / XYS data types:

```moonbit nocheck
let scatter = @chart.Chart::of_scatter(
  @chart.ScatterData::new()
    .with_series("trend", [1.0, 2.0, 3.0], [10.0, 25.0, 32.0]),
)

let bubble = @chart.Chart::of_bubble(
  @chart.BubbleData::new().with_series(
    "growth",
    [1.0, 2.0, 3.0],
    [100.0, 200.0, 150.0],
    [10.0, 20.0, 30.0],
  ),
)
```

## Sub-packages

The library is split into focused sub-packages. Import what you need;
the default last-segment aliases (`@units`, `@chart`, …) usually
suffice.

| Package | What it covers |
|---|---|
| `@presentation` | High-level `Presentation` façade — `open` / `save` / `new`, slide / chart / picture / SVG / audio / video / online-video (`add_online_video_mut` / `add_youtube_video_mut`) / SmartArt (`add_smartart_mut`) insertion, typed layout slides (`add_title_slide_mut` / … — compile-time placeholder schema), slide delete / reorder / duplicate, slide sections (`set_sections_mut` / `add_section_mut`), `define_master`, document properties — core + app.xml (`core_properties` / `set_core_properties_mut`, `app_properties` / `set_app_properties_mut`), embedded chart-data workbooks (`add_chart_mut(embed_data=…)` — PowerPoint's "Edit Data" opens real rows), pinpoint shape editing, immutable + mutating builders |
| `@slide` | Slide model: `AutoShape`, `Picture` (incl. SVG + media; typed `Picture::builder` pipeline), `Connector`, `GroupShape`, `Table` (incl. the 74 built-in gallery styles by name — `Table::with_style(MediumStyle2Accent1)`), `GraphicFrame`, text bodies (run-level rich formatting: character spacing / kerning / highlight / text outline / text effects / full `@oxml.Fill` text fills via `with_text_fill`), custom geometry, shape rotation / flip (`with_rotation` / `with_flip`), shape hyperlinks (`with_hyperlink` / `with_hyperlink_to_slide`), typed background, typed slide transitions, animations (`with_animations` + `Timeline` — entrance / exit / emphasis / motion / fly-in / by-paragraph text builds), placeholder accessors, footer / date / slide-number |
| `@chart` | Standard 16 chart families with from-scratch builders (`Chart::of_bar` / `of_line` / `of_pie` / `of_scatter` / `of_bubble` / `of_combo` / …) plus combo + secondary-axis, ADT options (`Chart::with_options`), and validation — data shape (`ChartData::validate`) + plot-type-aware data-label positions (`Chart::validate`) |
| `@chart_ex` | Microsoft 2016 extended charts (waterfall, treemap, sunburst, …); read + write, lossless round-trip |
| `@smartart` | SmartArt (DiagramML) builder — `SmartArt::list` / `process` / `cycle` / `pyramid` / `org_chart` / `hierarchy` / `matrix` / `relationship`; emits the five-part DiagramML graphic (data / layout / quickStyle / colors + cached `dsp:drawing` with connector lines); the tree families carry recursive hierRoot/hierChild (and radial) layout definitions so PowerPoint lays out the whole tree; per-node colour overrides (`Node::with_fill` / `with_line` / `with_text_color`) |
| `@theme`, `@slide_master`, `@notes`, `@comments` | Theme / master / layout / speaker-notes / comments parsers and writers |
| `@opc` | Open Packaging Convention layer (parts, content types, relationships) — usable for DOCX/XLSX too |
| `@oxml` | Shared OOXML AST (`Color`, `Fill`, `Stroke`, `EffectList`, …) |
| `@xml` | Streaming namespace-aware XML reader + writer |
| `@units` | `Emu`, `Pt`, `Inch`, `Cm`, `Angle`, `Percentage`, `RgbColor`, `HslColor`, `ThemeColor` |

## Examples

Two entry points live under [`examples/`](examples/):

- [`examples/README.md`](examples/README.md) — cookbook of focused
  recipes (title slides, widescreen sizing, hyperlinks, speaker
  notes, picture cropping, tables with custom borders, charts from
  data, a complete pitch deck end-to-end).
- [`examples/sample-deck/`](examples/sample-deck/) — a standalone
  MoonBit module that depends on moon-pptx exactly the way a
  downstream consumer would. It builds a 26-slide demonstration
  deck exercising every typed feature. Run it via
  `moon -C examples/sample-deck run main --target native | tail -1 | xxd -r -p > out/sample.pptx`.

## Comparison with python-pptx and PptxGenJS

Compared against **python-pptx 1.0.2** and **PptxGenJS 4.0.1** (checked
2026-09-01). moon-pptx column reflects the current `main`.

Legend: ✅ supported · △ partial, XML-level, or preserved-but-not-buildable · ❌ not supported

### At a glance

| | python-pptx | PptxGenJS | moon-pptx |
|---|---|---|---|
| Read existing `.pptx` | ✅ | ❌ generator only | ✅ lossless |
| Write `.pptx` | ✅ | ✅ | ✅ |
| Runs on | Python | JS (Node + browser) | Native · Wasm-GC · JS · Wasm |
| Chart families creatable | 8 plot families | 10 | **16 standard + 9 chartEx = 25** |
| SmartArt | △ identify only | ❌ | ✅ build, all 8 families |
| Animations / transitions | △ raw XML | ❌ | ✅ typed DSL |
| Unknown-XML preservation | △ partial | n/a | ✅ every node (ADR-004) |
| Units | raw int | raw number | distinct types, checked at compile time |

### Where moon-pptx goes further

1. **Chart coverage** — 25 buildable families. waterfall, treemap,
   sunburst, funnel, boxWhisker, paretoLine, regionMap, histogram and
   clusteredColumn (the Microsoft 2016 `chartEx` set) are not creatable
   in either competitor. python-pptx's `XL_CHART_TYPE` lists surface /
   stock / of-pie, but they have no plot implementation behind them.
2. **Lossless preservation** — every model node carries
   `extension : Array[XmlElement]`, so third-party files round-trip with
   zero data loss even through features moon-pptx doesn't model.
3. **Type-safe units** — confusing `Emu` with `Pt` fails to compile.
   Integer/float dimensions elsewhere invite silent unit-mix bugs.
4. **Exhaustive ADT matching** — a new shape / fill / stroke / chart
   option the writer hasn't handled is a compile error, not a silently
   dropped element.
5. **Multi-backend from one source** — server (Native), browser
   (Wasm-GC), Node (JS). Neither competitor spans this.
6. **SmartArt creation** — all eight families emit a full five-part
   DiagramML graphic; the nesting families ship recursive
   hierRoot/hierChild layout definitions, so PowerPoint lays out the
   whole tree with connectors. python-pptx can only *identify* SmartArt;
   PptxGenJS cannot touch it.
7. **Compile-time placeholder schema** — `LayoutSlide[L]` makes accessing
   a placeholder the layout doesn't have a compile error.
8. **Immutable + `_mut` duality** — pure transforms when you want them,
   in-place edits when you don't.

### Where the others go further

Kept deliberately honest — these are the reasons to pick something else:

| Gap | Who has it | Status here |
|---|---|---|
| Ecosystem maturity — tutorials, StackOverflow answers, years of production use | both | moon-pptx is young; the surrounding MoonBit ecosystem is younger still |
| WMF / EMF images | python-pptx | △ preserved on read, not creatable |
| Animated GIF | PptxGenJS | △ embeds as a normal image |
| Browser-side "download this deck" one-liner | PptxGenJS | you get bytes; wiring the download is yours |

### Feature matrix

Rows where all three are equivalent (text bodies, runs, paragraphs, bold
/ italic / size / colour, tables, pictures, speaker notes, …) are
omitted — assume parity unless listed.

**Slides, masters, layouts**

| Feature | python-pptx | PptxGenJS | moon-pptx |
|---|---|---|---|
| Slide delete / reorder / duplicate | ✅ / △ / △ | ❌ generator only | ✅ / ✅ / ✅ |
| `defineSlideMaster`-style high-level API | △ low-level | ✅ | ✅ `define_master` |
| Compile-time placeholder schema | ❌ | ❌ | ✅ `LayoutSlide[L]` |
| Slide sections | △ | ✅ | ✅ typed `Section` |
| Headers / footers / slide number | ✅ | ✅ | ✅ |

**Shapes and text**

| Feature | python-pptx | PptxGenJS | moon-pptx |
|---|---|---|---|
| AutoShape preset geometry | ✅ | ✅ | ✅ 187 variants |
| Custom geometry (`<a:custGeom>`) | △ XML | △ | ✅ typed AST |
| Rotation / flip | ✅ | ✅ | ✅ |
| Shape-level hyperlink | ✅ | ✅ | ✅ all 5 shape kinds |
| SVG pictures | ❌ | ✅ | ✅ |
| Character spacing / kerning | ✅ / △ | ✅ / △ | ✅ / ✅ |
| Text highlight / outline / glow / shadow | ❌ / △ / ❌ / ❌ | ✅ | ✅ |
| Non-solid text fill (gradient / pattern) | △ | △ | ✅ full `Fill` ADT |
| Paragraph-mark properties (`<a:endParaRPr>`) | △ | ❌ | ✅ typed `end_run_properties` |
| Line spacing, absolute + percent | ✅ | ✅ | ✅ `TextSpacing` ADT |
| RTL / bidi paragraph direction | △ | ✅ | ✅ `with_rtl` |
| East Asian / complex-script fonts (`<a:ea>` / `<a:cs>`) | △ | ✅ | ✅ typed + `with_font_for_all_scripts` |
| Resolve a run's font through the theme (`+mn-lt`, `script="Jpan"`) | ❌ | ❌ | ✅ `resolve_run_font_for_script` |
| WordArt / preset text warp | ❌ | △ | △ preserved only |
| 3-D bevel / scene3d | △ | △ | △ preserved only |

**Charts**

| Feature | python-pptx | PptxGenJS | moon-pptx |
|---|---|---|---|
| Bar / line / pie / scatter / bubble / area / radar / doughnut | ✅ | ✅ | ✅ |
| Stock / surface / of-pie | △ enum only | ❌ | ✅ |
| 3-D bar / line / pie / area | ✅ | △ bar3d / bubble3d | ✅ |
| Extended chartEx (waterfall, treemap, sunburst, funnel, boxWhisker, paretoLine, regionMap, histogram, clusteredColumn) | ❌ | ❌ | ✅ |
| Combo chart + secondary axis | △ | ✅ | ✅ |
| Trendlines | ✅ | ❌ | ✅ |
| Data labels with per-point overrides | ✅ | ✅ | ✅ |
| Embedded xlsx data cache (PowerPoint "Edit Data") | ✅ | ❌ | ✅ opt-in `embed_data` |

**Multimedia, navigation, advanced**

| Feature | python-pptx | PptxGenJS | moon-pptx |
|---|---|---|---|
| Audio / video embed | ✅ | ✅ | ✅ |
| YouTube / URL video | ❌ | ✅ | ✅ |
| Comments | ✅ | ❌ | ✅ read + write |
| Animations | △ raw XML | ❌ | ✅ typed `Timeline` |
| Slide transitions | △ raw XML | ❌ | ✅ typed |
| SmartArt build | ❌ | ❌ | ✅ all 8 families |
| Percentage / relative positioning | ❌ | ✅ | ✅ |
| Document properties (core + app) | ✅ | ✅ | ✅ typed, both parts |
| Table style by gallery ID | ✅ | ✅ | ✅ 74 built-in styles by name |
| Lossless diff-write (untouched parts byte-identical) | ❌ | n/a | ✅ inherent in `save()` |
| Streaming write for huge decks | ❌ | ❌ | ❌ |

## Compatibility

| Backend | Status |
|---|---|
| Native | Tested in CI |
| Wasm-GC | Tested in CI |
| JS | Tested in CI |
| Wasm (legacy) | Tested in CI |

Generated decks are verified to open without a repair prompt in
PowerPoint Online; the bundled blank template emits every part
ECMA-376 marks as required.

## License

Apache-2.0. See [LICENSE](LICENSE).
