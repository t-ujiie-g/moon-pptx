# moon_pptx

[![CI](https://github.com/t-ujiie-g/moon-pptx/actions/workflows/ci.yml/badge.svg)](https://github.com/t-ujiie-g/moon-pptx/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

> **Status: pre-alpha (Phases 1–7 closed except for open-verification).**
> Read + write parsers and writers cover theme / slide master / slide
> layout / slide / notes slide / comments / tables / **charts** (both
> the standard 16 chart families and the Microsoft 2016 extended
> chartEx families — waterfall, treemap, sunburst, histogram,
> boxWhisker, funnel, paretoLine, regionMap, clusteredColumn), with
> `parse → serialize → parse → Eq` round-trip verified across
> synthetic decks. The high-level `Presentation` API supports `open`
> / `save` / `new` plus both mutating (`add_slide_mut`,
> `update_slide_mut`) and immutable (`with_added_slide`,
> `with_slide_updated`) builders. Chart-from-scratch builders cover
> all 16 standard families (`Chart::of_bar / of_line / of_pie /
> of_area / of_radar / of_scatter / of_bubble / of_doughnut /
> of_of_pie / of_bar_3d / of_line_3d / of_pie_3d / of_surface /
> of_surface_3d / of_stock`). Generated decks open cleanly in
> PowerPoint Online with no repair prompt; the bundled blank
> template now emits every part ECMA-376 marks as required
> (presProps / viewProps / tableStyles / docProps + the theme's
> mandatory fmtScheme). Outstanding: Phase 8 (SmartArt / animation
> differentiators) and beyond. See [TODO.md](TODO.md) for the
> phase-by-phase roadmap.

A pure-MoonBit library for reading, building, and writing PowerPoint
presentations (`.pptx` / OOXML), with a type-safe builder API.

## Vision

Where `python-pptx` succeeded, this project aims to **match its scope and go
further** while staying entirely within MoonBit:

- **Pure MoonBit** — works on Native and Wasm-GC backends with no FFI to
  host runtimes (depends only on `hustcer/fzip` for ZIP/DEFLATE).
- **Type-safe units** — `Emu`, `Pt`, `Inch`, `Cm`, `Color` are distinct types
  with explicit conversions; impossible to mix up.
- **Immutable builders** — `slide.with_shape(rect).with_text(tb)` returns a
  new value; no hidden mutation.
- **ADT-driven model** — `Fill`, `Stroke`, `Effect` are enums; pattern match
  instead of attribute soup.
- **Lossless round-trip** — unknown OOXML extensions are preserved verbatim.
- **Beyond `python-pptx`** — SmartArt builder, animation builder, all 13
  chart types as buildable, compile-time placeholder schema (planned).

See [TODO.md §8](TODO.md#8-comparison-vs-python-pptx-target-end-state) for the
full feature comparison.

## Project status

| Phase | Scope | Status |
|---|---|---|
| 0 | Bootstrap, deps, CI | ✅ Done |
| 1 | Units & XML | ✅ Done |
| 2 | OPC layer over fzip | ✅ Done |
| 3 | Read path | ✅ Done |
| 4 | Write path | ✅ Done |
| 5 | Builder API (create from scratch) | ✅ Done (PowerPoint Online verified) |
| 6 | Tables | ✅ Done |
| 7 | Charts (standard + chartEx, read/write/build) | ✅ Done |
| 8 | Differentiators (SmartArt, animation, …) | 🔜 Next |
| 9 | 1.0 release | ⏳ |

Detailed checklists per phase live in [TODO.md](TODO.md).

## Install

Once published to mooncakes:

```bash
moon add t-ujiie-g/moon_pptx
```

## Quickstart

Build a one-slide deck from scratch and serialise it to PPTX bytes:

```moonbit nocheck
// (Replace the import aliases with however your project pins them.)
let prs = @presentation.Presentation::new()

// Append a Blank-layout slide; index 0 is the layout from
// `Presentation::new()`'s built-in template.
let _ = prs.add_slide_mut(0)

// Add a text box to the new slide. EMU constants: 914_400 per
// inch, so 914_400 × 457_200 ≈ 1" × ½".
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

// Save returns the PPTX bytes.  Write them to disk however your
// backend supports — `@native.write_file` on Native, `Blob` on JS.
let bytes : FixedArray[Byte] = prs.save()
```

### Tables

Tables sit inside a `<p:graphicFrame>` shape. The builders cover the
common cases (empty grid, custom cell contents, merged cells, cell
fills / borders / margins) without any XmlElement surface area:

```moonbit nocheck
// 2×2 table with merged top row + a coloured first cell.
let yellow = @units.RgbColor::parse_hex("FFFF00")
let header_props = @slide.TableCellProperties::default()
  .with_fill(@oxml.Fill::SolidFill(@oxml.Color::srgb(yellow)))
  .with_anchor(@slide.Anchor::AnchorCenter)
let header = @slide.TableCell::merged_origin("Header", grid_span=2)
// Replace its default properties with the highlighted variant.
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

Build a chart from a data table and drop it into a chart part:

```moonbit nocheck
let data = @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_category("Q3")
  .with_category("Q4")
  .with_series("Revenue", [100.0, 200.0, 300.0, 250.0])
  .with_series("Cost", [60.0, 110.0, 180.0, 140.0])

// Pick a family — bar / line / pie / area / radar / doughnut / etc.
let chart = @chart.Chart::of_bar(data)
// or:  @chart.Chart::of_line(data, grouping=Stacked)
// or:  @chart.Chart::of_pie(data)
// or:  @chart.Chart::of_doughnut(data, hole_size=60)

// Serialize to chartN.xml bytes (you supply the OPC plumbing that
// wires the part into the package).
let chart_bytes : FixedArray[Byte] = chart.serialize()
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

For a richer end-to-end example see
[`src/integration/cookbook_test.mbt`](src/integration/cookbook_test.mbt)
— it builds a five-slide pitch deck via the same APIs and round-trips
through `save() → open()`.

## Development

| Command | Purpose |
|---|---|
| `moon check` | Type check (run after every edit) |
| `moon test` | Run all tests on default backend |
| `moon test --target all` | Run tests across `native` / `wasm-gc` / `js` |
| `moon fmt` | Format code |
| `moon info` | Regenerate `.mbti` (public API surface) |

The full development guide and AI-agent instructions live in
[CLAUDE.md](CLAUDE.md) and [AGENTS.md](AGENTS.md).

The roadmap and active workstream live in [TODO.md](TODO.md). Read it before
opening a PR that changes scope, design, or status.

## License

Apache-2.0. See [LICENSE](LICENSE).
