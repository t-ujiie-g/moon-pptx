# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

The ADR-015 API-shape pass, in full. It is the only sanctioned break
between v0.6.0 and 1.0, and ADR-016 closes it — every release after this
one is additive-only again. Three things change shape: arguments get
labels, model records that nothing needs to build become read-only, and
the records that were only buildable by literal get builders first.

Migration is mechanical throughout, and nothing about the emitted files
changes: the same deck built the new way is byte-identical.

### Added

- **The `<a:effectLst>` records have builders.** `PictureUncropped::with_effects`
  has always taken an `@oxml.EffectList`, but there was no way to make one
  short of a record literal across eight fields — which is why nothing in
  the tree, examples included, ever passed that argument.
  - `EffectList::empty()` plus `with_blur` / `with_glow` /
    `with_inner_shadow` / `with_outer_shadow` / `with_preset_shadow` /
    `with_reflection` / `with_soft_edge`.
  - `Blur::new`, `Glow::new`, `SoftEdge::new`, `InnerShadow::new`,
    `PresetShadow::new` and `OuterShadow::new` take the attributes the
    schema requires. The optional tail — scale, skew, alignment,
    `rotWithShape` — rides on `OuterShadow::with_scale` / `with_skew` /
    `with_alignment` / `with_rotate_with_shape`.
  - `Reflection::default()` plus eleven `with_*` builders, since every one
    of its fourteen attributes is optional.
  - `AutoShape::with_effects`, which was missing next to the `with_fill` /
    `with_stroke` it belongs with.

  `examples/README.md` gains recipe 23, and the sample deck's hand-written
  effect literal now goes through them. Closes the effect half of
  `ROADMAP.md` §3.4 A1.
- **Shape ids can be allocated instead of guessed.** `<p:cNvPr id>` has to
  be unique within a slide, every shape builder takes one as a positional
  `Int`, and until now nothing in the library helped:
  - `Slide::with_shape_auto_id(shape)` appends with the id replaced by the
    next free one, so the same builder output can be added twice without
    colliding.
  - `Slide::next_shape_id()` returns that number for callers who would
    rather pass it to a builder themselves. It was already there as a
    private helper for the header/footer builders; it now also descends
    into groups, whose children share the slide's id space and could
    previously hand back an id already in use.
  - `Slide::duplicate_shape_ids()` reports the clashing ids on a slide,
    ascending, each once.
  - `Shape::with_id(id)` renumbers any typed shape variant; an `Unknown`
    shape carries no typed id and is returned unchanged.

  `duplicate_shape_ids` is a query rather than a `serialize` failure on
  purpose: a deck parsed from a third-party file can arrive with duplicates
  already in it, and refusing to write it back would cost the lossless
  round-trip (ADR-004). The library's own output is held to the stricter
  standard by a new Tier 1 integrity invariant (ADR-011) instead.

  Additive — the generated `.mbti` differ by 4 added lines with no
  removals. Closes `ROADMAP.md` §3.4 A3.

### Fixed

- **`README.md` no longer calls the chartEx families "creatable".** The
  comparison table claimed "16 standard + 9 chartEx = 25" buildable chart
  families, but `@chart_ex` exposes only `ChartEx::parse` and
  `serialize` — there is no typed builder, and the project's own test
  constructs a waterfall chart by writing `<cx:chartSpace>` XML by hand.
  What ships is real and still ahead of both competitors — lossless
  chartEx parsing, serialisation, and `add_chart_ex_mut` doing the OPC
  plumbing — so the table now says that instead. A typed builder is
  tracked as `ROADMAP.md` G11.

### Changed

- **`ChartEx`, `CommentList`, `CommentAuthorList`, `PresentationPart` and
  `Theme` are constructible again.** The pass below made them `pub` on the
  grounds that they had a constructor, but their only constructor is
  `parse` — so what actually went away was the ability to author one from
  scratch and `serialize` it, which is the whole point of a type that has
  a `serialize`. They are `pub(all)` again, and the rule is now explicit:
  a type with a public `serialize` is an authoring target and stays
  constructible. Nothing shipped in a release with them closed.
- **BREAKING: the eight effect records are read-only outside their
  package** — `EffectList`, `Blur`, `Glow`, `InnerShadow`, `OuterShadow`,
  `PresetShadow`, `Reflection`, `SoftEdge`. This is the flip side of the
  builders above: once a type can be constructed properly it no longer
  needs to be built by literal, so a new field on any of them is additive
  from here. Migration is the builder call the entry above describes.
- **BREAKING: 7 more model records are read-only outside their package** —
  `ResolvedFonts`, `AnimStep`, `ChartSeries`, `BubbleSeries`,
  `ScatterSeries`, `PlaceholderDef`, `PlaceholderSpec`. Same reasoning as
  the 32 below: nothing needs to construct them, so a new field on any of
  them is now additive.
- **BREAKING: 32 model records are now read-only from outside their
  package** (`pub` rather than `pub(all)`). Their fields are still readable
  and matchable; what goes away is building one with a record literal or a
  `{ ..value, field: … }` spread. Every one of them keeps a full
  construction path — that was the condition for downgrading it — so the
  migration is to go through the constructor and `with_*` builders that
  already exist:

  ```moonbit
  // before — and still fine, this was always the recommended form
  let t = @slide.Transform::new(offset={ x, y }, extent={ cx, cy })

  // before — no longer compiles
  let t : @slide.Transform = { offset: …, extent: …, rotation: None, … }
  ```

  The point is what this buys: adding a field to a `pub(all) struct` breaks
  any downstream exhaustive record literal, which is why 0.8.0's
  `ParagraphProperties.rtl` was technically a breaking change. For these 32
  — `Presentation`, `ChartData`, `Transform`, `Transition`, `Timeline`,
  `SmartArt`, `Theme`, `CoreProperties`, `TableCellProperties`, `RgbColor`
  and the rest — a new field is now genuinely additive, which is what the
  1.0 freeze needs to be worth anything.

  Sanctioned by ADR-015. `ROADMAP.md` §3.4 A1 records the full audit,
  including the 47 types that stay `pub(all)` and the 77 that need a
  builder API before they can move.
- **BREAKING: identity, geometry and same-typed argument runs are now
  labelled**, across 24 public functions in `slide`, `presentation` and
  `smartart`. `id`, `name`, `x`, `y`, `cx`, `cy` take labels, as does every
  run of two or more consecutive parameters of the same type. What stays
  positional: the receiver, `slide_idx`, and a lone parameter its own type
  already distinguishes (the text of a `textbox`, the `Table` of an
  `of_table`, the `Chart` of an `add_chart_mut`).

  ```moonbit
  // before
  @slide.AutoShape::textbox(2, "Title", x, y, cx, cy, "Hello")
  prs.add_chart_mut(0, chart, x, y, cx, cy)

  // after
  @slide.AutoShape::textbox(id=2, name="Title", x~, y~, cx~, cy~, "Hello")
  prs.add_chart_mut(0, chart, x~, y~, cx~, cy~)
  ```

  The unit newtypes already made `Pt` vs `Emu` a compile error, but nothing
  stopped `x`↔`y` or `cx`↔`cy` — same type, silent swap, shape in the wrong
  place. The same hazard sat in `add_video_mut(video_bytes, poster_bytes)`,
  `add_audio_mut`, `add_svg_picture_mut`, `Picture::of_svg_image`'s two
  embed ids, `Picture::of_media`'s three rel ids, and
  `GraphicFrame::of_diagram_ref`'s four. `Table::of_rows(_, col_widths~)`
  and `TableRow::of_cells(_, height~)` were already labelled, so this also
  ends an inconsistency inside the library.

  Migration is mechanical: add the label names in call order. Behaviour,
  semantics and emitted bytes are unchanged — the same call produces the
  same file. Sanctioned by ADR-015, which amends ADR-012's additive-only
  clause for the §3.4 API-shape pass; closes `ROADMAP.md` §3.4 A2.
- **Legacy Wasm is actually tested in CI.** `README.md` § Compatibility,
  `ROADMAP.md` §0 and §2 all said the CI matrix covered four backends
  while `.github/workflows/ci.yml` ran three; the suite passes on
  `--target wasm`, so the matrix gained it rather than the docs losing a
  backend. See ADR-014, which supersedes the legacy-Wasm exclusion in
  ADR-002.
- **The README's Quickstart snippets are executed.**
  `src/integration/readme_test.mbt` mirrors all four blocks, in the same
  arrangement `src/integration/examples_test.mbt` already uses for
  `examples/README.md`. The blocks keep their `nocheck` marker: `moon
  0.1.20260827` collects no tests from `.mbt.md` files or `///` doc
  comments, so dropping it would advertise a check that does not run
  (tracked as `ROADMAP.md` H4).

## [0.8.0] — 2026-09-01

Closes three gaps from `ROADMAP.md` §3.1 — G1 (RTL / bidi), G5
(`endParaRPr`) and G2 (Asian-script fonts). Together they retire every
remaining row where python-pptx or PptxGenJS handled text moon-pptx did
not; what those libraries still have over moon-pptx is now ecosystem
maturity, WMF/EMF images, animated GIF, and PptxGenJS's browser-side
download helper.

Additive: the generated `.mbti` differ from 0.7.2 by 37 added lines with
no removals. See **Compatibility** below for the one way that can still
bite.

### Added

- **RTL / bidi paragraph direction** — `ParagraphProperties.rtl : Bool?`
  and `Paragraph::with_rtl(Bool)`, reading and writing the `rtl`
  attribute on `<a:pPr>`. `None` means "inherit from the list style /
  master" rather than left-to-right, matching OOXML's cascade. PowerPoint
  performs the bidi reordering itself, so runs stay in logical order.
  (gap G1)
- **Paragraph-mark properties** — `Paragraph.end_run_properties :
  RunProperties?` and `Paragraph::with_end_run_properties`, modelling
  `<a:endParaRPr>`. This is what an empty paragraph is styled by and what
  the next character typed at the end of a paragraph inherits, so a blank
  spacer paragraph can now be given a height without a dummy run.
  (gap G5)
- **Asian-script fonts, and font resolution through the theme.** (gap G2)
  - `RunProperties::with_east_asian_font` (`<a:ea>`) and
    `with_complex_script_font` (`<a:cs>`), plus
    `with_font_for_all_scripts` — the one-liner for "render this run in
    Meiryo whatever the script is". `with_font` only ever set the Latin
    slot, so CJK text silently kept the theme font.
  - `@theme.ThemeFontRef` models the six `typeface="+mn-lt"`-style theme
    references PowerPoint writes instead of a font name, and
    `FontScheme::resolve_typeface` follows one to the font it names. A
    parsed deck's `RunProperties.latin` is usually `"+mn-lt"`; until now
    that string was all a caller got.
  - `FontCollection::typeface_for_script` answers for an ISO-15924 tag
    (`"Jpan"`, `"Hans"`, `"Arab"`), preferring the theme's
    `<a:font script="…">` entry over the `ea` / `cs` slot — which is where
    Office themes actually keep the CJK faces, since they ship
    `<a:ea typeface=""/>`. `@theme.ScriptSlot::of_script` exposes the
    east-asian / complex / latin classification behind it.
  - `@slide.resolve_run_fonts` and `resolve_run_font_for_script` combine
    the two: what typeface does *this run* render *this script* with.
    Covers the run → theme step; list-style and master layers must be
    merged in first.

### Changed

- **`<a:endParaRPr>` no longer lands on `Paragraph.extension`.** It is
  parsed into the typed field above instead. Serialised output is
  unchanged — the element is still emitted last inside `<a:p>` per
  ECMA-376 — but code that reached into `extension` looking for it should
  read `end_run_properties` now. Builders leave the field `None`, so
  decks generated by moon-pptx are byte-identical to 0.7.2.

### Compatibility

- **New fields on `pub(all)` structs do not break `..spread` construction,
  but do break *exhaustive* record literals.** `ParagraphProperties` and
  `Paragraph` each gained a field, so
  `{ level: 0, alignment: None, … }` listing every field no longer
  compiles, while
  `{ ..ParagraphProperties::default(), bullet: Some(…) }` keeps working.
  The bundled sample deck hit exactly this and was switched to the spread
  form, which is the recommended shape for constructing any model record.
  Every `with_*` builder is unaffected.

## [0.7.2] — 2026-09-01

Maintenance: no API change, no behaviour change. The tree was swept for
the forms `moon 0.1.20260827` deprecated, and the project's documentation
was reorganised — `TODO.md` became a forward-looking `ROADMAP.md`, and the
comparison against python-pptx / PptxGenJS moved to `README.md`.

### Changed

- **Deprecated forms removed for `moon 0.1.20260827`.** No public API
  change — `moon info` reports zero `.mbti` drift, and 1178 tests stay
  green on all four backends.
  - `StringBuilder::new(…)` → `StringBuilder(…)` (17 sites). `new` is now
    a deprecated alias of the `StringBuilder(size_hint? : Int)`
    constructor.
  - **Implicit trait-method promotion**, now deprecated, removed at 62
    call sites. Types whose `Show` comes from a `pub impl Show for T`
    block gained an `extend T with Show::{to_string}` declaration next to
    that impl — `XmlReadError`, `ColorError`, `FillError` — which keeps
    `.to_string()` working at every call site. `ImageFormat`'s single
    internal `.output(logger)` became `logger.write_object(…)`.
- **Reformatted by the current `moon fmt`**, which now emits a trailing
  comma inside single-line struct literals (`{ r, g, b }` →
  `{ r, g, b, }`). Formatting only, across 85 files.

### Documentation

- **`TODO.md` is now `ROADMAP.md`, and it is forward-looking.** The old
  file had grown to 976 lines of which roughly 60 % was history —
  per-cycle shipped-item detail, a completed-phases list, and a living
  changelog, all duplicating this file and git. `ROADMAP.md` keeps only
  direction, the open-gap list, ADRs, open questions, risks, and
  conventions (418 lines). Release history lives here; the record of how
  something was built lives in git. See ADR-013, which supersedes
  ADR-006.
- **The comparison against python-pptx and PptxGenJS moved to
  `README.md`**, refreshed against python-pptx 1.0.2 and PptxGenJS 4.0.1
  and brought up to date with 0.7.2 — the old matrix still said "0.5.3"
  and listed slide sections and table-style presets as unimplemented,
  two releases after both shipped. It now also states plainly where the
  other libraries are still ahead.
- **New `ROADMAP.md` §3 "What is *not* done yet"** — the gap list the
  project never had in one place: 9 feature gaps (G1–G9), 3 verification
  gaps (V1–V3), and 2 housekeeping items, each with a size estimate.
- `AGENTS.md`, `CLAUDE.md`, `examples/README.md`, the CI workflow, and
  the two fixture READMEs point at the new locations.

### Compatibility

- **Minimum toolchain raised to `moon 0.1.20260827`.** The tree now uses
  the `StringBuilder(…)` constructor form and `extend … with Show::{…}`
  declarations, neither of which the previous `0.1.20260729` floor has.
- Source-compatible for consumers: the public surface carries no
  declaration change from 0.7.1.

## [0.7.1] — 2026-08-05

A maintenance release: no API change, no behaviour change. The tree was
swept to current MoonBit idiom after the toolchain moved on, which
deleted a pile of hand-rolled string code the standard library now
covers.

### Changed

- **Internal modernisation to current MoonBit idiom.** No public API
  change — the regenerated `.mbti` differ from 0.7.0 only by a trailing
  blank line the newer `moon info` no longer emits, with no declaration
  added, removed, or altered. 1178 tests stay green on all four backends.
  - Hand-rolled string scanning replaced by the standard library:
    `String::contains` / `find` / `split` / view slicing (`s[a:b]`) and
    `StringView` patterns (`s is ['/', .. rest]`, `[.."xmlns:", ..]`)
    now cover what six copies of a naive substring search, five copies
    of a UTF-8 encoder, and four copies of an ASCII fixture encoder used
    to do. Those copies are gone; `@oxml.string_to_bytes` is the single
    encoder.
  - Deprecated forms removed: dot-syntax trait-method calls on
    multi-bound type parameters, `fn(x) { … }` lambdas (now `x => …`),
    `not(…)`, `Array::new()`, `String::from_array`, `.view(start_offset=…)`.
  - `.length() == 0` / `> 0` → `.is_empty()`; index-counting `while`
    loops → range and functional `for` loops.

### Compatibility

- **Minimum toolchain raised to `moon 0.1.20260729`.** The tree now uses
  `String::contains` / `find`, view slicing (`s[a:b]`), and `StringView`
  patterns, none of which the previous `0.1.20260522` floor has.
- Source-compatible for consumers: the public surface carries no
  declaration change from 0.7.0.

## [0.7.0] — 2026-07-12

The **additive parity + ergonomics** release — every item of the
v0.7.x cycle in one batch, all additive `.mbti`. The
headline: the three remaining shape kinds become clickable, tables get
PowerPoint's built-in style gallery by name, decks get sections and
full document properties, charts get an editable embedded data
workbook, and the common fills / SmartArt node colours get one-line
constructors.

### Added

- **Shape hyperlinks on `Connector` / `GroupShape` / `GraphicFrame`**
  (`with_hyperlink(url~)` / `with_hyperlink_to_slide(slide_idx~)`) —
  all five shape kinds are now clickable. A `GroupShape` resolves its
  own hyperlink *and* its children's.
- **`TableStylePreset`** — all 74 built-in PowerPoint table styles by
  their gallery names (`MediumStyle2Accent1`, …), GUIDs extracted from
  MS-OE376 §5.1.6.10. `Table::with_style(preset, first_row~, band_row~)`
  applies one to a whole table (flags default to PowerPoint's
  insert-table behaviour); `TableStylePreset::guid()` and
  `TableProperties::with_style` for finer control.
- **Slide sections** — `Section { title, start }` +
  `Presentation::set_sections_mut` / `add_section_mut` / `sections()` /
  `with_sections` over the `<p14:sectionLst>` extension ([MS-PPTX]
  §2.3.1.25). Sections partition the deck in slide order; `[]` removes
  them; other `<p:extLst>` content is preserved.
- **app.xml document properties** — `AppProperties { company / manager
  / application / app_version }` + `Presentation::app_properties()` /
  `set_app_properties_mut` / `with_app_properties`. A DOM *merge*:
  only the fields you set change; the app-maintained statistics and
  `vt:vector` parts are preserved verbatim.
- **Embedded chart-data workbooks** — opt-in
  `add_chart_mut(…, embed_data=chart_data)` generates a minimal valid
  `.xlsx` mirroring the data and wires `<c:externalData>`, so
  PowerPoint's "Edit Data" opens the real rows. Charts still render
  from inline literals (ADR-009); the workbook is a pure UX add-on.
- **Fill convenience constructors** — `Fill::solid(rgb)`,
  `Fill::linear_gradient(from, to, via?, angle?)` (≥ 2 stops enforced
  by the signature; `via` colours spaced evenly; defaults to the 90°
  scaled form PowerPoint emits), `Fill::pattern(preset, fg~, bg~)`.
- **SmartArt per-node colours** — `NodeStyle { fill / line /
  text_color }` + merging builders `Node::with_fill` / `with_line` /
  `with_text_color`. Overrides are written to both the data model
  (kept on re-layout) and the cached drawing (non-editing viewers).
- New public constants: `@oxml.section_list_ext_uri` /
  `extended_properties_ns` / `doc_props_vtypes_ns` / `ct_xlsx_sheet`,
  `@opc.rt_package`.

### Compatibility note (not breaking for builder users)

- Four `pub(all)` structs gained an optional field: `hyperlink :
  ShapeHyperlink?` on `Connector` / `GroupShape` / `GraphicFrame`, and
  `style : NodeStyle?` on `@smartart.Node`. Code constructing these
  via **struct literals** must add the field (`hyperlink: None` /
  `style: None`); construction through the builders (`of_*` /
  `Node::leaf` / `Node::new`, …) is unaffected.

### Development

- Tier-1 reader-losslessness: three real Office files are embedded as
  base64 test sources, so `moon test` proves parse → serialise →
  re-parse model equality on every backend without file I/O
  (ADR-011). All three passed first try.
- New standing refactor lens (CLAUDE.md §7.6): no roadmap/phase codes
  in code comments; ~150 sites swept across the tree.
- Sample deck grows to 26 slides (v0.7 features slide + sections /
  app properties / embedded workbook / per-node SmartArt colours woven
  in) and now builds via a committed `moon.work`, replacing the CI
  dep-flip. Cookbook gains recipes 18 (sections) and 19 (document
  properties), plus embed_data / table-style / SmartArt-colour
  extensions to existing ones.
- 1131 → 1178 library tests × 4 backends (Native / Wasm-GC / JS /
  Wasm), all green.

## [0.6.0] — 2026-07-06

The **pre-1.0 breaking pass**. This release deliberately spends the
project's breaking-change budget in one batch: the
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

[Unreleased]: https://github.com/t-ujiie-g/moon-pptx/compare/v0.7.1...HEAD
[0.7.1]: https://github.com/t-ujiie-g/moon-pptx/compare/v0.7.0...v0.7.1
[0.5.1]: https://github.com/t-ujiie-g/moon-pptx/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/t-ujiie-g/moon-pptx/releases/tag/v0.5.0
[0.1.0]: https://github.com/t-ujiie-g/moon-pptx/releases/tag/v0.1.0
