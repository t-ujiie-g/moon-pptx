# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] — 2026-06-01

Deck-level slide editing: this release adds the slide **delete**,
**reorder**, and **duplicate** operations that were missing from the
otherwise add-only / replace-only build API. Together with the
shape-level editing from 0.3.0, a deck can now be arranged entirely
programmatically.

### Added

- **Slide deletion** — `Presentation::remove_slide_mut(slide_index)`
  (mutating) and `Presentation::without_slide(slide_index)` (immutable)
  remove a slide and unthread it everywhere the package tracks it: the
  `<p:sldIdLst>` entry, the `presentation.xml.rels` relationship, the
  slide part, its `.rels`, and its `[Content_Types]` override. This is
  the inverse of `add_slide_mut`. Slide-private parts reachable only
  through the removed slide (its notes slide, images, charts, embedded
  media) are garbage-collected; shared slide layout / master / theme
  parts are always kept. Enables the "trim a template down to just the
  slides you generated" flow. (roadmap E1)
- **Slide reordering** — `Presentation::move_slide_mut(from, to)`
  (mutating) and `Presentation::with_slide_moved(from, to)` (immutable)
  relocate a slide to a new position. `to` is the destination index in
  the resulting order; `from == to` is a no-op. Reordering only rewrites
  `<p:sldIdLst>` — slide part names are unchanged. (roadmap E2)
- **Slide duplication** — `Presentation::duplicate_slide_mut(slide_index)`
  (returns the new slide's part name) and
  `Presentation::with_duplicated_slide(slide_index)` (immutable) append a
  copy of an existing slide. The copy re-references the source slide's
  layout, images, charts, media, and notes (it does not deep-copy them),
  so editing a shared chart's data or notes affects both slides. The
  natural building block for "duplicate this template slide, then fill
  it" generation. (roadmap E3)
- **`@opc.ContentTypes::without_override(part_name)`** — companion to
  `with_override`, used when a part is removed from the package.

## [0.3.0] — 2026-05-30

### Added (toward v0.3.0)

- **Lossless diff-write** — editing a deck and calling `save()` now
  re-emits every *untouched* part byte-for-byte (preserving the exact
  formatting of a real-world Office file on the parts you didn't change);
  only the parts you mutate are re-serialised. This is inherent in how
  parts retain their source bytes — no new API. (roadmap D6)
- **Programmatic slide masters (`define_master`)** —
  `Presentation::define_master(MasterDefinition)` synthesises a slide
  master plus a dependent layout (placeholders, optional footer / date /
  slide-number placeholders, background) and registers them, returning
  the new master's index. Build the definition with
  `MasterDefinition::new(name)` and `with_placeholder` /
  `with_background` / `with_footer` / `with_slide_number` / `with_date`.
  (roadmap C1)
- **Slide footer / date / number placeholders** —
  `Slide::with_footer(text)`, `Slide::with_slide_number(visible)`, and
  `Slide::with_date(Auto | Fixed(text))` add the slide-level
  placeholders PowerPoint fills (slide-number and auto-date use live
  fields). These render against a master that declares the matching
  placeholders — e.g. one built with `define_master`. (roadmap A8)
- **Audio / video embedding** — `Presentation::add_video_mut(slide_idx,
  video_bytes, poster_bytes, …)` and `add_audio_mut(…)` embed a media
  clip with a poster frame. Formats are detected from magic bytes
  (`@oxml.detect_media_format`): MP4 / MOV / AVI / WMV for video, MP3 /
  WAV / AIFF / M4A for audio. The clip is modelled as a typed
  `Picture.media` (`MediaInfo`) and serialises the standard
  `<a:videoFile>` / `<a:audioFile>` + `<p14:media>` references plus a
  `ppaction://media` hyperlink. The caller supplies the poster image.
  (roadmap A6)
- **Combo charts + secondary axis** — `Chart::of_combo(primary,
  secondary, secondary_axis?=false)` overlays two plots (e.g. columns +
  a line) on a shared category axis, where each plot is a
  `ChartPlot { Bar | Line | Area }(ChartData)`. Passing
  `secondary_axis=true` gives the secondary plot its own value axis
  (drawn on the right) plus a hidden secondary category axis — the
  standard PowerPoint secondary-axis layout. (roadmap C3)
- **Pinpoint shape editing** — edit an *existing* shape in place instead
  of only appending. New `Shape::id()` / `Shape::name()` accessors, and
  immutable `Slide` builders `map_shapes`, `with_shape_at`,
  `with_shape_mapped`, `with_shape_by_id`, `without_shape`,
  `without_shape_by_id`. At the presentation level,
  `Presentation::map_slide_shapes_mut` and
  `Presentation::update_shape_by_id_mut` locate a shape, transform it, and
  write the slide back in one call. Editing a shape's `name` / `id` now
  persists through serialisation (previously a captured `<p:cNvPr>`
  shadowed the typed fields). (roadmap B4)
- **SVG image support** — `Presentation::add_svg_picture_mut(slide_idx,
  svg_bytes, fallback_bytes, x, y, cx, cy)` inserts an SVG picture with a
  raster (PNG / JPEG / …) fallback for viewers that don't understand SVG.
  The blip embeds the fallback and carries an `<asvg:svgBlip>` extension
  (Office 2016+) pointing at the embedded SVG part. Lower-level builders:
  `@slide.Picture::of_svg_image` and `@oxml.BlipFill::svg`. The caller
  supplies the fallback image (no built-in SVG rasteriser). (roadmap C4)
- **Typed slide background** — `<p:cSld><p:bg>` is now a typed
  `Slide.background` field instead of round-tripping through
  `extension`. New `Background` enum covers both `<p:bgPr>` (an
  explicit fill, via `Properties(BackgroundProperties)`) and
  `<p:bgRef>` (a theme style-matrix reference, via
  `StyleReference(idx, color)`). Builders: `Slide::with_background(fill)`,
  `Slide::with_background_ref(idx, color)`, and
  `Slide::without_background()`. The background reuses `@oxml.Fill`, and
  unmodelled fill forms (e.g. `<a:grpFill>`) round-trip losslessly.
  (roadmap A7)
- **Placeholder named accessors** — `Slide::title()` (matches `Title`
  and `CtrTitle`), `Slide::body()`, `Slide::placeholder(kind)`, and
  `Slide::placeholders()` for inspecting placeholder shapes on a parsed
  slide. New typed `PlaceholderType` enum (the 16 `ST_PlaceholderType`
  values plus `Other(String)` for forward compatibility) with
  `from_xml` / `to_xml`, and `Placeholder::kind()` deriving it from the
  raw `ph_type`. The raw string field is preserved so an absent `type`
  attribute round-trips losslessly. (roadmap B1)

## [0.2.0] — 2026-05-27

### Added (toward v0.2.0)

- **Image-size auto-detection** — new `@oxml.detect_image_format` /
  `@oxml.detect_image_dimensions` for PNG / JPEG / GIF / BMP / TIFF
  headers + DPI metadata, plus `Presentation::add_picture_auto_mut`
  that auto-derives `(cx, cy)` from the image bytes.
- **Hyperlink builder** — `RunProperties::with_hyperlink(url, tooltip~)`
  for external URLs and `with_hyperlink_to_slide(slide_idx, tooltip~)`
  for internal jumps. `Presentation::update_slide_mut` resolves the
  target into a slide-rels rId at serialisation time. New
  `HyperlinkTarget` enum and `@opc.rt_hyperlink` constant.
- **Speaker notes builder** — `Presentation::set_notes_mut(slide_idx,
  text)` synthesises `/ppt/notesSlides/notesSlideN.xml` with a body
  placeholder carrying the text. Repeated calls replace the existing
  notes in place; the underlying notesSlide is reused.
- **Picture cropping** — `Picture::with_crop(left~, top~, right~,
  bottom~ : @units.Percentage)` wraps `<a:srcRect>`. Calls are
  idempotent; a second `with_crop` replaces rather than merging.
- **Slide-size selector** — `SlideSizeKind { ScreenFourByThree |
  ScreenSixteenByNine | ScreenSixteenByTen | Widescreen | Letter |
  A4 | ThirtyFiveMm | Banner | Custom(cx, cy) }` plus
  `Presentation::set_slide_size_mut(kind)` that updates
  `presentation.xml`'s `<p:sldSz>`.
- **Table cell border fluency** — `TableCellProperties::with_borders(
  left?, right?, top?, bottom?)` selectively replaces per-edge
  borders without disturbing the rest.
- **Percentage / relative positioning** — `Presentation::pct_w(percent)`
  and `pct_h(percent)` return EMU values relative to the deck's
  current slide size; `slide_w` / `slide_h` expose the full extents.
- **Cookbook examples** — new `examples/README.md` with 8 runnable
  recipes (title slides / widescreen / hyperlinks / notes / images /
  tables / charts / pitch deck). Each recipe is verified by
  `src/integration/examples_test.mbt`.
- **Standalone sample-deck consumer module** — new
  `examples/sample-deck/` is a separate MoonBit module that depends
  on `t-ujiie-g/moon-pptx` exactly the way a downstream user would.
  Builds a 12-slide demonstration deck exercising every typed
  feature. Generate the artefact with
  `moon -C examples/sample-deck run main --target native | tail -1 | xxd -r -p > out/sample.pptx`.
  Compile-time `split_mode` flag emits per-feature isolation files
  for debugging PowerPoint Online compatibility regressions.

### Fixed (PowerPoint Online compatibility)

Eight schema-and-canonicalisation issues that caused PowerPoint Online
to flag generated decks as "needs repair" — even when the file was
spec-valid per ECMA-376. All discovered through round-trip comparisons
against the version PowerPoint emits after its repair pass:

- **notesSlide / Slide `<p:spTree>` defaults** — synthesise the
  required `<p:nvGrpSpPr>` + `<p:grpSpPr>` (with zero-valued `<a:xfrm>`)
  when the typed model carries no captured wrapper.
- **Notes-master synthesis** — `Presentation::set_notes_mut` now
  creates a `/ppt/notesMasters/notesMaster1.xml` part on first use
  (PowerPoint refuses a notesSlide that isn't backed by a master),
  registers it in `<p:notesMasterIdLst>`, and adds a `theme2.xml`
  duplicate (sharing `theme1.xml` triggers repair).
- **`<p:notesMasterId>` attribute fix** — CT_NotesMasterIdListEntry
  defines only `r:id`, not the `id` attribute we previously emitted
  (the latter is only valid on CT_SlideMasterIdListEntry). The
  writer now omits `id` for notesMasterId / handoutMasterId.
- **`<p:sldSz>` `type="custom"` omission** — PowerPoint's
  canonicalisation drops the `type` attribute entirely for non-preset
  dimensions rather than setting it to `"custom"`. `SlideSizeKind`
  now returns `""` (omitted) for `Widescreen` and `Custom(_, _)`.
- **Slide-master `<p:bg>`** — the bundled blank master now carries
  the standard `<p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef>`.
- **Custom-geometry defaults** — `<a:custGeom>` writers always emit
  `<a:ahLst/>`, `<a:cxnLst/>`, and `<a:rect>` (defaults to zero
  bounds), matching PowerPoint's normalised output.
- **Internal-slide hyperlink action** — runs created via
  `with_hyperlink_to_slide` now emit
  `<a:hlinkClick action="ppaction://hlinksldjump" r:id="…"/>` so
  PowerPoint recognises the rId as a slide jump (without `action`
  the link was silently rewritten to a no-op).
- **Chart axis required elements** — `simple_axis_core` now sets
  `<c:crosses val="autoZero"/>` on every axis kind and appends
  `<c:crossBetween val="between"/>` to valAx via the extension
  channel (both schema-required per ECMA-376 §21.2.2.6 / §21.2.2.182).
- **3-D chart wrappers** — `Chart::of_bar_3d` / `of_line_3d` /
  `of_pie_3d` / `of_surface` / `of_surface_3d` now populate
  `<c:view3D>`, `<c:floor>`, `<c:sideWall>`, `<c:backWall>` with
  PowerPoint's default rotation + zero-thickness walls. Plus all
  chart families gain `<c:autoTitleDeleted val="1"/>` when no
  title is set.
- **`<c:ofPieChart>` defaults** — `Chart::of_of_pie` now omits the
  default `<c:splitType val="auto"/>` (PowerPoint repairs it away)
  and emits explicit `<c:gapWidth val="100"/>` + `<c:secondPieSize
  val="75"/>` schema defaults.

### Deferred

- **Slide number / footer / date placeholders (A8)** — the per-slide
  visibility flags are cheap but they only render usefully when the
  master defines matching placeholder shapes. Bundled into v0.3
  alongside the high-level `define_master` API (C1).
- **Standalone consumer-example repo (external)** — the
  `examples/sample-deck/` module in this repo uses a path dep on the
  parent during in-repo development. A *fully external* example repo
  (depending on the published library via mooncakes, without any
  shared filesystem) can come post-v0.2.0 if there's demand.

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
