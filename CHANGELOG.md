# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-05-26

Initial public release. The library is feature-complete for the
common end-to-end PowerPoint authoring path: open / build / save
decks containing styled text, shapes, pictures, tables, and charts.

### Added

#### Foundations

- `@units` — type-safe distance / angle / colour primitives:
  `Emu` (Int64), `Pt`, `Inch`, `Cm`, `Angle`, `Percentage`,
  `RgbColor`, `HslColor`, `ThemeColor`, `ColorTransform`,
  `SchemeColor`.
- `@xml` — streaming namespace-aware XML reader + writer with full
  prefix resolution, entity decoding, and escape handling.
- `@opc` — Open Packaging Convention layer over
  [`hustcer/fzip`](https://mooncakes.io/docs/hustcer/fzip):
  `Package`, `Part`, `Relationship`, `ContentTypes`, lookup +
  builder API.

#### Read / write path

- Read parsers for theme (`a:theme`), slide master (`p:sldMaster`),
  slide layout (`p:sldLayout`), slide (`p:sld`), notes slide
  (`p:notes`), comment list (`p:cmLst`), and comment author list
  (`p:cmAuthorLst`).
- Write counterparts for all of the above with `parse → serialize →
  parse → Eq` round-trip property tested.
- Lossless preservation of unknown OOXML elements: every model node
  carries an `extension : Array[XmlElement]` for children the parser
  did not model, and writers emit them back verbatim.

#### Shapes and text

- `AutoShape`, `Picture`, `Connector`, `GroupShape` with full
  transform, geometry, fill, stroke, and effect support.
- 187-variant `PresetShape` enum (every `ST_ShapeType` value) and a
  typed `CustomGeometry` AST for `<a:custGeom>` path data.
- Typed `<p:graphicFrame>` covering `TableContent` plus
  pass-through for chart / SmartArt / OLE references.
- Text bodies (`TextBody`, `Paragraph`, `Run`, `Field`, `Break`)
  with the practical `<a:rPr>` and `<a:pPr>` surface — bold /
  italic / underline / fill / hyperlink on runs; alignment / level
  / indent / bullets on paragraphs; auto-fit / anchor / insets on
  bodies.
- `Fill`, `Stroke`, `EffectList` ADTs covering noFill / solid /
  gradient / pattern / blip fills, dash / cap / join / arrow strokes,
  and blur / glow / shadow / soft-edge / reflection effects.

#### Tables

- Typed `Table` / `TableRow` / `TableCell` model with cell merging
  (`grid_span`, `row_span`, `h_merge`, `v_merge`).
- Builders: `TableCell::of_text` / `merged_origin` /
  `h_merge_covered` / `v_merge_covered` / `hv_merge_covered`,
  `TableRow::of_cells`, `Table::of_rows` / `of_grid`,
  `GraphicFrame::of_table`.
- Typed `TableProperties` and `TableCellProperties` covering style
  flags, fills, margins, anchor, and the six cell-border kinds.

#### Charts

- Read + write coverage for all 16 standard chart families: bar,
  line, pie, area, radar, scatter, bubble, doughnut, stock,
  surface, ofPie, plus their 3-D variants.
- Read + write coverage for the Microsoft 2016 extended chartEx
  families (waterfall, treemap, sunburst, histogram, boxWhisker,
  funnel, paretoLine, regionMap, clusteredColumn).
- Typed bodies for every chart family plus shared sub-elements
  (`Axis`, `Scaling`, `ChartTitle`, `ChartLegend`, `DLbls`, `DLbl`,
  `Layout`, `ManualLayout`, `Trendline`, `NumFmt`).
- From-scratch builders for every standard family — `Chart::of_bar /
  of_line / of_pie / of_area / of_radar / of_scatter / of_bubble /
  of_doughnut / of_of_pie / of_bar_3d / of_line_3d / of_pie_3d /
  of_surface / of_surface_3d / of_stock`.
- Inline `<c:strLit>` / `<c:numLit>` data sources; existing
  `<c:externalData>` xlsx caches round-trip losslessly via
  `Chart.extension`.

#### High-level API

- `@presentation.Presentation` façade: `open(bytes)`, `save()`,
  `new()`.
- Typed accessors: `slides`, `themes`, `slide_masters`,
  `slide_layouts`, `notes_slides`, `comment_lists`, `comment_authors`,
  `charts`, `charts_ex`, `presentation_part`.
- Mutating builders: `add_slide_mut`, `update_slide_mut`,
  `add_picture_mut`, `add_chart_mut`, `add_chart_ex_mut`.
- Immutable builders: `clone`, `with_added_slide`,
  `with_slide_updated`.
- Fluent text + shape styling: `RunProperties::with_font_size /
  with_bold / with_italic / with_font / with_color`,
  `Paragraph::with_alignment / with_properties`,
  `TextBody::of_styled_text / of_paragraphs`,
  `AutoShape::with_fill / with_no_fill / with_stroke / with_no_stroke
  / with_text_body`.
- `Presentation::new()` emits every part ECMA-376 marks as required
  (`presProps.xml`, `viewProps.xml`, `tableStyles.xml`, docProps,
  the theme's `<a:fmtScheme>`), so generated decks open in PowerPoint
  Online without a repair prompt.

### Compatibility

- Native, Wasm-GC, JS, and Wasm targets all tested in CI.

[Unreleased]: https://github.com/t-ujiie-g/moon-pptx/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/t-ujiie-g/moon-pptx/releases/tag/v0.1.0
