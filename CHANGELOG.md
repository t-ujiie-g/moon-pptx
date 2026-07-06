# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] — 2026-07-06

The **pre-1.0 breaking pass**. This release deliberately spends the
project's breaking-change budget in one batch (see TODO.md §4.1): the
run-fill and paragraph-spacing models widen to their full ADTs, and 33
accidentally-public internals leave the API surface. Every release from
here to 1.0 is intended to be **additive-only** — v1.0.0 itself ships
when the MoonBit toolchain reaches v1.0. Also in this release: SmartArt
tree families now lay out **fully** in PowerPoint (children,
grandchildren and connector lines), verified visually in PowerPoint Web.

### Breaking

- **`RunProperties.fill` widens from `@oxml.Color?` to `@oxml.Fill?`.**
  Gradient / pattern / picture / noFill *text* fills are now typed
  instead of riding the lossless-preservation escape hatch.
  `with_color(rgb)` keeps its signature (it now builds a `SolidFill`).
  *Migration*: code that matched or set `fill` as a colour wraps it —
  `fill: Some(color)` → `fill: Some(SolidFill(color))`.
- **Paragraph spacing widens to a shared `TextSpacing` ADT.**
  `ParagraphProperties.line_spacing` / `space_before` / `space_after`
  are now `TextSpacing? { Percent(Percentage) | Points(Pt) }`
  (the spec's `CT_TextSpacing` choice), so both the percent and the
  absolute-points forms round-trip and are settable.
  *Migration*: `line_spacing: Some(pct)` → `Some(Percent(pct))`;
  `space_before: Some(pt)` → `Some(Points(pt))`.
- **33 internal helpers removed from the public API** (verified unused
  by the downstream consumer pptz 0.7.0): the per-package `wrap_xml`
  error helpers + `@opc.wrap_fzip`, `@oxml.enum_attr_opt` /
  `require_angle` / `require_emu` / `require_pct`, the 20 `@chart`
  per-element `parse_*` / `write_*` internals, and
  `@slide.anim_default_duration_ms`; `@oxml.parse_percent_value` was
  dead and is deleted.

### Added

- **`RunProperties::with_text_fill(@oxml.Fill)`** — gradient / pattern /
  picture text fills as a one-call builder (`with_color` remains the
  solid shorthand).
- **`Paragraph::with_line_spacing` / `with_space_before` /
  `with_space_after`** — fluent paragraph-spacing builders over the new
  `TextSpacing` ADT.

### Fixed

- **SmartArt tree families (`org_chart` / `hierarchy` / `relationship`)
  now lay out fully in PowerPoint.** PowerPoint re-lays-out SmartArt
  from the layout definition on open, and the old single-level
  definition drew only the top level. The tree families now ship a
  recursive `hierRoot`/`hierChild` layout definition (with parent→child
  connectors) distilled from a real Office-emitted `orgChart1` part, and
  `relationship` a `radial1`-style hub-and-spoke one; the cached drawing
  also gains connector lines for non-editing viewers. Node style labels
  are named explicitly — PowerPoint Web rendered unlabelled boxes black.
  Verified in PowerPoint Web: all three levels + connectors render.
- **Paragraph spacing was never parsed from real files.** The parser
  read spacing off `<a:pPr>` *attributes* that don't exist in OOXML, so
  Office's `<a:lnSpc>` / `<a:spcBef>` / `<a:spcAft>` children were never
  typed (they round-tripped losslessly, but setting the typed field on a
  parsed paragraph could double-emit). The child-element form is now
  parsed; a spacing wrapper with no `spcPct`/`spcPts` choice raises.
- **A colour-less `<a:solidFill/>` on a run now raises** instead of
  being silently dropped, matching the strict shape-fill path (the
  colour child is required by ECMA-376).

### Development

- API stability review pass 1 complete: all 1017 public declarations
  audited; every deliberately-public API now has a direct blackbox test.
  1131 tests × 4 backends (Native / Wasm-GC / JS / Wasm).
- Sample deck grows to 25 slides with a v0.6 features slide (gradient /
  pattern text fills + paragraph spacing); the SmartArt slide is an org
  chart again and doubles as the rendering regression check.

## [0.5.3] — 2026-06-20

Bug-fix release. Adds an automated verification pyramid (in-repo structural
checks + an Open XML SDK validator in CI), which immediately caught a real
media-serialisation bug — now fixed. No public API change; code written against
0.5.2 keeps compiling.

### Fixed

- **Embedded media now serialises as valid OOXML.** `<a:videoFile>` /
  `<a:audioFile>` and the `<p14:media>` `<p:extLst>` were written as direct
  children of `<p:pic>` instead of inside `<p:nvPr>`, which violates
  `CT_Picture` and made PowerPoint offer to repair decks containing audio,
  video, or online video (`add_audio_mut` / `add_video_mut` /
  `add_online_video_mut`). The shape-extension classifier only recognised the
  media reference under the PresentationML namespace, but those elements are
  DrawingML-namespaced, so a parsed-then-re-serialised media picture misplaced
  them. They are now emitted inside `<p:nvPr>` in the schema-required order.
  ([#11](https://github.com/t-ujiie-g/moon-pptx/issues/11))

### Added

- **Verification tooling (development / CI, not part of the published library).**
  A three-tier "opens without a repair prompt" verification pyramid: in-repo
  MoonBit OPC structural-integrity checks over builder output (all backends),
  plus a `tools/pptx-validate/` .NET job running Microsoft's `OpenXmlValidator`
  over the generated showcase deck and a license-clear real-world corpus
  (`test_fixtures/corpus/`, Apache POI) on every PR. This is what surfaced the
  media bug above.

## [0.5.2] — 2026-06-17

Fidelity & fine-grained formatting: typed builders for everyday PowerPoint
formatting that previously only round-tripped through the lossless-preservation
escape hatch. Every change is additive — code written against 0.5.1 keeps
compiling.

### Added

- **Shape rotation & flip** — `Transform.rotation : @units.Angle?` /
  `flip_h` / `flip_v`, with `AutoShape` / `Picture` / `GroupShape`
  `with_rotation(angle)` / `with_flip(h~, v~)` and a `Transform::new`
  constructor. Reads/writes `<a:xfrm rot/flipH/flipV>` on shapes, groups,
  and graphic frames (previously dropped on parse). (roadmap F1)
- **Document core properties** — typed `CoreProperties` (the full closed
  `docProps/core.xml` set: title / creator / subject / keywords /
  description / category / contentStatus / created / modified / lastPrinted
  / lastModifiedBy / revision / identifier / language / version) with
  fluent `with_*` builders (`with_author` aliases `with_creator`),
  `Presentation::core_properties()` reader + `set_core_properties_mut` +
  immutable `with_core_properties`. Replaces the hard-coded template
  creator. (roadmap F2)
- **Run-level rich text formatting** — `RunProperties` gains `kerning`
  (`with_kerning`, the `kern` attribute), `highlight` (`with_highlight`,
  `<a:highlight>`), `outline` (`with_text_outline`, `<a:ln>`), and
  `text_effects` (`with_text_effects`, `<a:effectLst>` — glow / shadow /
  reflection / soft-edge). The `@oxml` shadow parsers are now lenient on
  the ECMA-376-optional `blurRad` / `dist` / `dir` (default 0) so minimal
  effect lists parse rather than failing. (roadmap F3)
- **Shape-level hyperlinks** — `AutoShape` / `Picture`
  `with_hyperlink(url~)` / `with_hyperlink_to_slide(slide_idx~)` attach a
  click action to a whole shape (`<p:cNvPr><a:hlinkClick>`), resolved to a
  slide-rels relationship by `update_slide_mut` (shared pipeline with
  run-level hyperlinks). (roadmap F5)

### Changed

- **Dependency**: `hustcer/fzip` bumped `0.6.1` → `0.8.2` (non-breaking —
  every new parameter is optional).

## [0.5.1] — 2026-06-16

Patch release: typed character spacing on text runs. Additive — code written
against 0.5.0 keeps compiling.

### Added

- **Character spacing on text runs** — `RunProperties::with_character_spacing(pt)`
  and a new `RunProperties.character_spacing : @units.Pt?` field map to the
  DrawingML `<a:rPr spc="…">` attribute (`ST_TextPoint`, 1/100 of a point; may
  be negative to tighten). Parsed and serialised losslessly, so existing decks
  with `spc` round-trip without loss, and run properties without spacing are
  unchanged. (issue #7)

## [0.5.0] — 2026-06-16

Animation & SmartArt release: two headline builders no other PPTX library
offers — a typed animation DSL and a SmartArt (DiagramML) builder — plus
online video and stricter chart validation. Every change is additive — code
written against 0.4.x keeps compiling.

### Added

- **SmartArt builder** (⭐) — `Presentation::add_smartart_mut(slide_idx,
  smartart, x, y, cx, cy)` synthesises the full five-part DiagramML graphic
  (data / layout / quickStyle / colors + a cached `<dsp:drawing>`) and drops
  it on the slide. The new `@smartart` package builds all eight families:
  `SmartArt::list` / `process` / `cycle` / `pyramid` / `matrix(items)`,
  `org_chart(root)` / `hierarchy(nodes)`, and
  `relationship(center, related)`, over a typed `SmartArt` / `Node` model.
  python-pptx can only *identify* SmartArt; PptxGenJS can't touch it at all.
  (roadmap D1)
- **Animation DSL** (⭐) — `Slide::with_animations(Timeline)` /
  `without_animations()` emit a full canonical `<p:timing>` tree.
  `Timeline::new().on_click / with_previous / after_previous(effect,
  shape_id, paragraph?, duration_ms?)` builds an ordered step list over
  `AnimEffect`: `Entrance` / `Exit` (a shared `VisualEffect` — `Appear` /
  `Fade` / `FlyIn(dir)` / `Wipe(dir)` / `Blinds` / `RandomBars` / `Dissolve`
  / `Wedge` / `Wheel(n)`), `Emphasis` (`Spin` / `GrowShrink` /
  `ChangeFillColor`), and `Motion(MotionPath)` for a custom path, plus
  by-paragraph text builds. (roadmap D2)
- **YouTube / online video** — `Presentation::add_online_video_mut(slide_idx,
  video_url, poster, x, y, cx, cy)` embeds any streaming-video URL via an
  external relationship (no media bytes in the package); `add_youtube_video_mut`
  normalises a `watch?v=` / `youtu.be/` / `/embed/` / `/shorts/` URL to the
  embeddable form first. The caller supplies the preview frame. (roadmap C5)
- **Plot-type-aware chart validation** — `Chart::validate()` (and non-raising
  `Chart::is_consistent()`) rejects a `<c:dLblPos>` data-label position the
  chart's plot family doesn't allow (e.g. `outEnd` on a line chart), catching
  a PowerPoint repair-banner trigger before the file is written. Complements
  0.4.0's data-shape `ChartData::validate`. (roadmap D8)

### Known limitations

- **SmartArt nesting families render top-level only in PowerPoint.**
  PowerPoint re-lays-out SmartArt from the layout definition on open (it does
  not use the cached drawing), and this release ships a single-level layout
  definition. So the five **flat** families (list / process / cycle / pyramid
  / matrix) render every node, but the three **nesting** families (org_chart /
  hierarchy / relationship) build and are recognised as SmartArt with the
  correct data model yet draw only their top-level node(s). A recursive
  hierarchy layout definition is planned for a future release.

## [0.4.0] — 2026-06-07

MoonBit-differentiator release: features that lean on the type system to
catch mistakes at compile time, plus richer typed builders for
transitions, charts, and pictures. Every change is additive — code
written against 0.3.x keeps compiling.

### Added

- **Compile-time placeholder schema** (⭐) — typed layout handles make a
  slide layout's placeholder set part of its type. `Presentation::`
  `add_title_slide_mut` / `add_title_content_slide_mut` /
  `add_section_header_slide_mut` / `add_title_only_slide_mut` /
  `add_blank_typed_slide_mut` return a `LayoutSlide[L]` whose
  `title` / `subtitle` / `body` accessors are gated by capability traits —
  accessing a placeholder the layout doesn't have (e.g. `.body()` on a
  title slide) is a **compile error**, not a runtime check. `finish_mut()`
  commits the built slide. Each constructor resolves an existing
  `<p:sldLayout>` of the right type or synthesises one (wiring it into the
  master). The index-based `add_slide_mut(layout_index)` is unchanged.
  No other PPTX library — in any language — offers this. (roadmap M1)
- **ADT-driven chart options** — `Chart::with_options(Array[ChartOption])`
  folds a sum-type option list into the chart model:
  `Title` / `TitleDeleted` / `Legend` / `LegendHidden` / `DataLabels` /
  `DataLabelsHidden` / `DataTable` / `Style` / `RoundedCorners` /
  `PlotVisibleOnly` / `DisplayBlanks`. The option handling is exhaustive,
  so a new option that isn't handled is a compiler error. (roadmap M2)
- **Typed slide transitions** — `Slide::with_transition(Transition)` /
  `without_transition()`. `Transition` covers the base CT_SlideTransition
  effects (`fade` / `cut` / `push` / `wipe` / `cover` / `pull` / `split` /
  `blinds` / `checker` / `comb` / `randomBar` / `strips` / `wheel` /
  `zoom` / `circle` / `diamond` / `dissolve` / `newsflash` / `plus` /
  `random` / `wedge`) with typed direction/orientation enums, plus
  `with_speed` / `with_on_click` / `with_advance_after` timing.
  `<p:transition>` is lifted into a typed `Slide.transition` field.
  (roadmap D3)
- **Typed picture builder state machine** — `Picture::builder(...)` opens a
  compile-time-checked pipeline: `.with_crop(...)` → `.with_effects(...)` →
  `.build()`. Cropping twice, or applying effects after `build`, is a type
  error. The flat `Picture::of_image` / `with_crop` stay as the
  unconstrained path. (roadmap D4)
- **Chart-data validation** — `ChartData::validate()` (and
  `ScatterData` / `BubbleData` counterparts) raises `Malformed` when a
  series' value count doesn't match the category count, returning `self`
  so it composes (`Chart::of_bar(data.validate())`); non-raising
  `is_consistent()` for a boolean check. The `with_series` builders stay
  lenient (pad/truncate) by default. (roadmap D7)
- **`Slide::with_placeholder(kind, idx, text?)`** — a generic typed
  placeholder builder (generalises `with_footer` / `with_date` /
  `with_slide_number`); the building block behind the typed layout handles.

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

[Unreleased]: https://github.com/t-ujiie-g/moon-pptx/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/t-ujiie-g/moon-pptx/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/t-ujiie-g/moon-pptx/releases/tag/v0.5.0
[0.1.0]: https://github.com/t-ujiie-g/moon-pptx/releases/tag/v0.1.0
