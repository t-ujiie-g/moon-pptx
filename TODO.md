# moon-pptx — Roadmap & Architecture

> Pure-MoonBit library for reading, building, and writing PPTX (OOXML)
> presentations with a type-safe builder API. Published on
> [mooncakes.io](https://mooncakes.io/docs/t-ujiie-g/moon-pptx) as
> `t-ujiie-g/moon-pptx`.

This document is the **single source of truth** for development
direction, version planning, design decisions (ADRs), open questions,
and risks. Living document — every PR that changes scope, design, or
status touches this file.

---

## 0. Project at a glance

| Item | Value |
|---|---|
| Module ID | `t-ujiie-g/moon-pptx` |
| Current version | `0.5.2` (release prep 2026-06-17); `0.5.1` tagged |
| License | Apache-2.0 |
| MoonBit toolchain | `moon 0.1.20260522` or newer |
| Primary backend | Native; CI matrix also runs `wasm-gc` / `js` / `wasm` |
| Buffer type | `FixedArray[Byte]` (matches `hustcer/fzip` + MoonBit core) |
| Required deps | `hustcer/fzip` (DEFLATE + ZIP, pure MoonBit) |
| Reference prior art | `python-pptx` (Python), `PptxGenJS` (JS/TS) |
| Differentiator | All 16 standard chart families + 9 extended chartEx; lossless preservation; type-safe units; immutable + `_mut` builders; multi-backend |

### What v0.1.0 delivers
- Read + write parsers / writers for: theme, slide master, slide layout, slide, notes slide, comment-author list, comment list, all 16 standard chart families, all 9 extended chartEx families.
- Builder API: `Presentation::new` → `add_slide_mut` / `add_picture_mut` / `add_chart_mut` / `add_chart_ex_mut` → `update_slide_mut` → `save()`.
- Fluent text + shape styling, table builders with cell merging + borders, custom geometry AST, lossless preservation of unknown OOXML (ADR-004).
- Generated decks open in PowerPoint Online without repair prompts; the bundled blank template emits every part ECMA-376 marks as required.
- 795 tests × 4 backends (Native / Wasm-GC / JS / Wasm); 100 % public-API doc coverage.

### What it does not yet do
See **§3** (feature comparison vs python-pptx + PptxGenJS) and **§4**
(version-driven roadmap to close every meaningful gap).

### Out of scope (initially)
- Macros / VBA execution
- EMF / WMF rasterization (binary preserved on read; no creation)
- Native PDF export (separate companion library if/when needed)
- Legacy binary `.ppt` files

---

## 1. Vision

Make moon-pptx **the most capable PPTX library in any language**, by:

1. **Matching python-pptx** on every read+build feature (v0.2–v0.3).
2. **Matching PptxGenJS** on every generation feature (v0.2–v0.3).
3. **Exceeding both** with features only MoonBit's type system can deliver (v0.4+):
   compile-time placeholder schema, ADT-driven exhaustive options,
   typed builder state machines.
4. **Closing gaps neither library covers**: SmartArt builder, animation DSL,
   transition builder, lossless diff-write (v0.4–v0.5).

### Design pillars (anchored from v0.1.0)
1. **Pure MoonBit, mooncakes-publishable** — no FFI; single source compiles to Native / Wasm-GC / JS / Wasm.
2. **Type-safe units** — `Emu`, `Pt`, `Inch`, `Cm`, `Angle`, `Percentage`, `RgbColor` are distinct types with explicit conversions.
3. **Immutable builders** — `slide.with_shape(s)` returns a new value; `_mut` for in-place edits of existing decks (ADR-003).
4. **ADT-driven model** — `Fill` / `Stroke` / `Effect` / `Shape` are enums; pattern match instead of attribute soup.
5. **Lossless round-trip** — unknown OOXML is preserved verbatim via `extension : Array[XmlElement]` (ADR-004).
6. **Beyond python-pptx and PptxGenJS** — extended chart families today; SmartArt + animation + compile-time placeholder schema tomorrow.

### Non-goals
- Drop-in Python or JS compatibility (no `python-pptx`-style import shims).
- Render to image / PDF / HTML — out-of-scope for this library; a separate companion can layer on top.
- Every legacy PPT (binary `.ppt`) feature.

---

## 2. Architecture (current as of v0.1.0)

```
src/
├── units/           Emu, Pt, Inch, Cm, Angle, Percentage, RgbColor, HslColor, ThemeColor, ColorTransform
├── xml/             Streaming namespace-aware XML reader + writer + ad-hoc DOM (XmlElement)
├── opc/             Open Packaging Convention layer over fzip — Package, Part, Relationship, ContentTypes
├── oxml/            Shared OOXML AST + helpers — Color, Fill, Stroke, EffectList, content-types, namespaces
├── theme/           Theme, ColorScheme, FontScheme, FontCollection
├── slide_master/    SlideMaster, SlideLayout, inheritance resolver (theme ← master ← layout)
├── slide/           Slide, AutoShape, Picture, Connector, GroupShape, Table, GraphicFrame, TextBody, CustomGeometry
├── notes/           NotesSlide
├── comments/        CommentAuthorList, CommentList
├── chart/           Standard 16 chart families + axis / title / legend / dLbls / dLbl / layout / trendline / series
├── chart_ex/        Extended chartEx families — waterfall, treemap, sunburst, funnel, boxWhisker, paretoLine, regionMap, clusteredColumn, histogram
├── smartart/        SmartArt (DiagramML) builder — typed SmartArt/Node model + five-part (data/layout/quickStyle/colors + cached dsp:drawing) generation (D1)
├── presentation/    High-level Presentation façade — open / save / new + slide / picture / chart / SmartArt insertion + immutable variants
└── integration/     Test-only — synthetic-deck fixtures + parse / re-serialise round-trip floor + cookbook compile-checks
```

`examples/` contains two complementary user-facing entry points:
- `examples/README.md` — cookbook of focused recipes (one feature per
  section), verified by `src/integration/examples_test.mbt`.
- `examples/sample-deck/` — standalone MoonBit module with its own
  `moon.mod.json`, depending on `t-ujiie-g/moon-pptx` via a path dep
  (`{ "path": "../.." }`) for in-repo development. After publication
  of a new library version, downstream consumers can switch to a
  `"version": "0.x"` dep without changing the example source.

### Naming conventions
- Public types: `PascalCase`. Modules and functions: `snake_case`.
- Builders return `Self` (or a new value of `Self` for immutable style).
- Conversions: `from_*` / `to_*`. Fallible parse: `parse_*` returning `?` or raising.
- Errors: subdomain-specific `*Error` suberrors; never raw `String` errors.
- Buffer type: always `FixedArray[Byte]`.

### Multi-backend strategy
- **Default**: Native (CLI / library users).
- **CI matrix**: Native + Wasm-GC + JS + Wasm — every commit.
- No FFI. File I/O lives at `bytes`-level public APIs; convenience helpers (e.g. `Presentation::open_path`) live behind backend gates.

---

## 3. Feature comparison vs python-pptx + PptxGenJS

This matrix is the basis for the roadmap in **§4**. Legend:
✅ supported · ⏳ planned (cite version) · △ partial / extension-only · ❌ not supported.

### 3.1 Core I/O and modelling

| Feature | python-pptx | PptxGenJS | moon-pptx 0.1.0 | Target |
|---|---|---|---|---|
| Read existing `.pptx` | ✅ | ❌ generator only | ✅ lossless | — |
| Write `.pptx` | ✅ | ✅ | ✅ | — |
| Lossless preservation of unknown XML | △ partial | — | ✅ ADR-004 | — |
| Round-trip property tests | ❌ | ❌ | ✅ at every layer | — |
| Multi-backend (Native + Browser + Node) | ❌ Python only | △ JS only | ✅ 4 backends | — |
| Type-safe units (Emu / Pt / Inch / Cm) | ❌ raw int | ❌ raw number | ✅ newtypes | — |
| Immutable builders | ❌ | ❌ | ✅ + opt-in `_mut` | — |
| Edit an *existing* shape in place (update / replace / map / remove) | ✅ `shape.text=`, `.left=` | ❌ generator only | ✅ B4 (`map_shapes` / `with_shape_by_id` / `with_shape_at` / `without_shape*` + `Presentation::map_slide_shapes_mut` / `update_shape_by_id_mut`) | — |
| Read accessors to *locate* shapes (placeholders / title / body) | ✅ | △ | ✅ B1 (`title`/`body`/`placeholder`/`placeholders`) | — |
| ADT pattern-match on shapes / fills / strokes | ❌ | △ TS unions | ✅ enums | — |
| Structural equality (`derive(Eq)`) | ❌ | ❌ | ✅ all model nodes | — |

### 3.2 Slides, masters, layouts

| Feature | python-pptx | PptxGenJS | moon-pptx 0.1.0 | Target |
|---|---|---|---|---|
| Slide build from scratch | ✅ | ✅ | ✅ | — |
| Slide-size selector (4:3 / 16:9 / 16:10 / …) | ✅ | ✅ | △ extension-only | ⏳ v0.2 (A5) |
| Slide deletion (remove a slide + its private parts) | ✅ `del slides[i]` | ❌ generator only | ✅ E1 (`remove_slide_mut` / `without_slide`) | — |
| Slide reordering | △ XML | △ | ✅ E2 (`move_slide_mut` / `with_slide_moved`) | — |
| Slide duplication / clone | △ `copy.deepcopy` hacks | ✅ `addSlide` from template | ✅ E3 (`duplicate_slide_mut` / `with_duplicated_slide`) | — |
| Slide background per slide | ✅ | ✅ color + transparency | ✅ typed `Slide.background` (`with_background` / `with_background_ref`) | — |
| `defineSlideMaster` style high-level API | △ low-level | ✅ | ✅ `Presentation::define_master(MasterDefinition)` | — |
| Layout selection by name | ✅ | ✅ | ✅ M1 typed constructors resolve/synthesise the layout by type (`add_title_slide_mut` / …) + `add_slide_mut` by index | — |
| Placeholder named accessors (`slide.title`) | ✅ | △ | ✅ `title`/`body`/`placeholder`/`placeholders` + typed `PlaceholderType` | — |
| Compile-time placeholder schema | ❌ | ❌ | ✅ M1 `LayoutSlide[L]` — wrong placeholder access is a compile error ⭐ | — |
| Headers / footers / slide number | ✅ | ✅ chained M/L/S | ✅ `Slide::with_footer`/`with_slide_number`/`with_date` + master-side via `define_master` | — |
| Sections | △ | △ | △ extension-only | future |

### 3.3 Shapes and text

| Feature | python-pptx | PptxGenJS | moon-pptx 0.1.0 | Target |
|---|---|---|---|---|
| AutoShape (preset geometry) | ✅ | ✅ | ✅ 187 `PresetShape` variants | — |
| Custom geometry (`<a:custGeom>`) | △ XML | △ | ✅ typed AST (Phase 3h) | — |
| Shape rotation (`rot`) / flip (`flipH`/`flipV`) | ✅ `shape.rotation` | ✅ `rotate`/`flipH/V` | ✅ typed `Transform.rotation`/`flip_h`/`flip_v` + `with_rotation`/`with_flip` (0.6 F1) | — |
| Shape-level hyperlink / click action (`<a:hlinkClick>` on `cNvPr`) | ✅ `click_action` | ✅ shape `hyperlink` | ✅ `with_hyperlink`/`with_hyperlink_to_slide` (AutoShape + Picture, 0.6 F5) | — |
| Picture (PNG / JPEG / GIF / BMP / TIFF) | ✅ + WMF | ✅ + SVG + animated GIF | ✅ | — |
| Picture: auto-detect EMU size from header | ✅ via PIL | ✅ | ❌ | ⏳ v0.2 (A1) |
| Picture: cropping fluent builder | ✅ | ✅ | △ model has SrcRect | ⏳ v0.2 (A4) |
| Picture: SVG (`asvg:svgBlip`) | ❌ | ✅ | ✅ `add_svg_picture_mut` + `Picture::of_svg_image` | — |
| Connector (`<p:cxnSp>`) | ✅ | △ | ✅ | — |
| Group shape (`<p:grpSp>`) | ✅ | △ | ✅ | — |
| Text bodies + paragraphs + runs | ✅ | ✅ | ✅ | — |
| Run-level: bold / italic / size / color / font | ✅ | ✅ | ✅ | — |
| Run-level: underline / strikethrough / caps / baseline | ✅ | ✅ | ✅ | — |
| Run-level: character spacing (`spc`) | ✅ | ✅ | ✅ `with_character_spacing` (0.5.1, issue #7) | — |
| Run-level: kerning (`kern` min size) | △ | △ | ✅ `with_kerning` (0.6 F3) | — |
| Run-level: text highlight (`<a:highlight>`) | ❌ | ✅ `highlight` | ✅ `with_highlight` (0.6 F3) | — |
| Run-level: text outline (`<a:ln>`) | △ | ✅ `outline` | ✅ `with_text_outline` (0.6 F3) | — |
| Run-level: text glow / shadow effects (`<a:effectLst>`) | ❌ | ✅ `glow`/`shadow` | ✅ `with_text_effects` (0.6 F3) | — |
| Run-level: non-solid text fill (gradient/pattern) | △ | △ | △ extension-only (solid fill ✅) | ⏳ v0.6 (F3 follow-up) |
| Paragraph: align / indent / margin / bullets | ✅ | ✅ | ✅ typed `ParagraphProperties` | — |
| Paragraph: line-spacing absolute (`spcPts`) + space %-form (`spcPct`) | ✅ | ✅ | △ percent line-spacing + point space only | ⏳ v0.6 (F4) |
| Hyperlinks (run-level) | ✅ | ✅ | △ parser only | ⏳ v0.2 (A2) |
| Bullets / numbered lists | ✅ | ✅ | ✅ 38-variant `AutoNumType` | — |
| RTL / bidi text | △ | ✅ | ❌ | future |
| Asian-script font fallback | △ | ✅ | △ `complex_script` field | future |
| Text autofit (none / norm / shape) | ✅ | ✅ | ✅ 3-variant `AutoFit` | — |

### 3.4 Tables

| Feature | python-pptx | PptxGenJS | moon-pptx 0.1.0 | Target |
|---|---|---|---|---|
| Table build (rows × cols) | ✅ | ✅ | ✅ `Table::of_rows / of_grid` | — |
| Cell merging (`grid_span`, `row_span`) | △ partial | ✅ | ✅ 6-helper palette | — |
| Cell fill | ✅ | ✅ | ✅ via `TableCellProperties` | — |
| Cell borders (per edge) | ✅ | ✅ | ✅ 6 border kinds (lnL / lnR / lnT / lnB / TlToBr / BlToTr) | — |
| Cell margins | ✅ | ✅ | ✅ | — |
| Cell vertical anchor | ✅ | ✅ | ✅ 5-variant `Anchor` | — |
| Cell border fluent helpers (`with_border_left` etc.) | △ | △ | ✅ | — |
| Table style by ID (`<a:tblPr styleId>`) | ✅ | ✅ | △ field, no preset library | future |

### 3.5 Charts

| Feature | python-pptx | PptxGenJS | moon-pptx 0.1.0 | Target |
|---|---|---|---|---|
| Bar / line / pie | ✅ | ✅ | ✅ | — |
| Scatter / bubble | ✅ | ✅ | ✅ | — |
| Area / radar / doughnut | ✅ | ✅ | ✅ | — |
| Stock / surface / ofPie | △ | ❌ | ✅ | — |
| 3-D bar / line / pie / area | ✅ | ✅ (bar3d / bubble3d) | ✅ | — |
| Extended chartEx (waterfall / treemap / sunburst / funnel / boxWhisker / paretoLine / regionMap / clusteredColumn / histogram) | ❌ | ❌ | ✅ read+write round-trip | — |
| Total chart families creatable | ~13 | 10 | **16 standard + 9 chartEx = 25** | — |
| Combo chart (bar + line) | △ | ✅ | ✅ `Chart::of_combo` (`ChartPlot { Bar \| Line \| Area }`) | — |
| Secondary axis | △ | ✅ | ✅ `of_combo(…, secondary_axis=true)` | — |
| Trendlines | ✅ | ❌ | ✅ typed `Trendline` (Phase 7m) | — |
| Multi-series | ✅ | ✅ | ✅ | — |
| Axis title / chart title | ✅ | ✅ | ✅ typed `ChartTitle` | — |
| Legend positioning | ✅ | ✅ 5 positions | ✅ typed `ChartLegend` | — |
| Data labels (per-point overrides) | ✅ | ✅ | ✅ typed `DLbls` + `DLbl` | — |
| Embedded xlsx data-cache generation | ✅ | ❌ | ❌ (ADR-009: inline `<c:strLit>` instead) | ⏳ v1.0 (B3) |
| Existing xlsx cache pass-through | ✅ | n/a | ✅ via OPC opaque part | — |

### 3.6 Multimedia, navigation, advanced

| Feature | python-pptx | PptxGenJS | moon-pptx 0.1.0 | Target |
|---|---|---|---|---|
| Audio embed (mp3 / wav) | ✅ | ✅ | ✅ `add_audio_mut` (mp3 / wav / aiff / m4a) | — |
| Video embed (mp4 / mov / m4v) | ✅ `add_movie()` | ✅ | ✅ `add_video_mut` (mp4 / mov / avi / wmv) | — |
| YouTube / URL video embed | ❌ | ✅ | ✅ C5 (`add_online_video_mut` / `add_youtube_video_mut`) | — |
| Speaker notes | ✅ read+write | ✅ `addNotes()` | ✅ read+write, ⏳ ergonomic builder | ⏳ v0.2 (A3) |
| Comments | ✅ | ❌ | ✅ read+write | — |
| Animations | △ XML-level | ❌ | ✅ D2 entrance/exit/emphasis/motion-path/fly-in + by-paragraph text builds (`Slide::with_animations` + `Timeline`) ⭐ | — |
| Transitions (slide-to-slide) | △ XML-level | ❌ | ✅ D3 (typed `Slide.transition`; base CT_SlideTransition — p14 extended transitions round-trip via extension) | — |
| SmartArt build | ❌ identification only | ❌ | ✅ D1 (`add_smartart_mut` — all 8 families build; the 5 flat families render fully in PowerPoint, the 3 nesting families render top-level only pending a recursive layoutDef) ⭐ | ⏳ recursive hierarchy layoutDef |
| Percentage / relative positioning helpers | ❌ | ✅ `x: "5%"` | ❌ | ⏳ v0.2 (C2) |
| Streaming write for huge decks | ❌ | ❌ | ❌ | ⏳ v1.0 (D5) |
| Lossless diff-write (untouched parts = byte-identical) | ❌ | n/a | ✅ inherent in `save()` (parts retain source bytes) | — |
| Document properties (creator, title, subject, keywords, …) | ✅ `core_properties` | ✅ `author`/`title`/… | ✅ typed `CoreProperties` (15-field closed core.xml) + `set_core_properties_mut`/`core_properties` (0.6 F2); app.xml `company`/`application` ⏳ follow-up | — |
| Slide sections (`<p:sldSectionLst>`) | △ | ✅ `addSection` | △ extension-only | open idea (§5) |
| WordArt / preset text warp (`<a:prstTxWarp>`) | ❌ | △ | △ extension-only | open idea (§5) |
| 3-D shape (bevel / `<a:scene3d>` / `<a:sp3d>`) | △ | △ | △ extension-only | open idea (§5) |
| Equation editor (`<m:oMathPara>`) | ❌ | ❌ | △ extension-only | future |

### 3.7 Where moon-pptx already wins

1. **Chart families** — 25 buildable types vs python-pptx ~13 and PptxGenJS 10. waterfall / treemap / sunburst / funnel / boxWhisker / paretoLine / regionMap are not creatable in either competitor.
2. **Lossless preservation** — every model node carries `extension : Array[XmlElement]`; third-party PPTX files round-trip with zero data loss. Neither competitor does this comprehensively.
3. **Type-safe units** — confusing Emu with Pt fails to compile. Other libraries' integer/float dimensions invite silent unit-mix bugs.
4. **ADT-driven exhaustive matching** — adding a new shape / fill / stroke kind that the writer hasn't handled is a compiler warning, not a silent dropped element. The same property drives the `Chart::with_options(Array[ChartOption])` builder (v0.4 M2): forgetting to handle a new chart option or plot family is a compile error.
5. **Multi-backend** — single source compiles to Native (CLI / server), Wasm-GC (browser), JS (Node), Wasm. Neither python-pptx nor PptxGenJS spans this range.
6. **Immutable + `_mut` duality** — pure-functional transforms (`prs → prs'`) when you want them; in-place edits when you don't (ADR-003).
7. **`derive(Eq, Show)`** — structural equality + debug printing free for every model type; round-trip property tests are `assert_eq` one-liners.
8. **SmartArt creation** (v0.5 D1) — all eight families (list / process / cycle / pyramid / org-chart / hierarchy / matrix / relationship) build a full five-part DiagramML graphic; the five flat families render fully in PowerPoint, the three nesting families render their top level only pending a recursive layoutDef (PowerPoint re-lays-out from the layout definition rather than the cached drawing). python-pptx can only *identify* SmartArt; PptxGenJS can't touch it at all. Plus the typed animation DSL (D2) and slide transitions (D3) neither competitor exposes above the XML level.

---

## 4. Roadmap

Version-driven from v0.1.0 onward. Each version has a **definition of
done (DoD)**. Status legend: 🔴 not started · 🟡 in progress · 🟢 done.

### 4.1 v0.2.0 — "Daily usability"

DoD: a user can build everything python-pptx supports today without
dropping to XML, and the API ergonomics match.

Status (2026-05-26): 7 of 8 items landed on `main` (A1 / A2 / A3 / A4
/ A5 / B2 / C2 + examples). A8 (slide number / footer / date
placeholders) deferred — needs master-side placeholder schema work
that is more naturally bundled with C1 (`define_master`) in v0.3.
Eight PowerPoint Online repair-banner triggers also fixed during
v0.2 polish — every chart family + the bundled blank deck now opens
without a repair prompt. **Ready to tag v0.2.0** once API stability
review (§4.5 v1.0 item, advanced) confirms no breaking changes vs
0.1.0.

🟢 **A1 — Image-size auto-detection from PNG / JPEG / GIF / BMP / TIFF headers**
  - New `@oxml.detect_image_dimensions(bytes) -> (cx_emu, cy_emu)?`
  - `Presentation::add_picture_mut(slide_idx, bytes, x, y)` overload (no cx/cy required) — auto-derives from header + DPI metadata
  - Test fixtures: one per format

🟢 **A2 — Hyperlink builder**
  - `RunProperties::with_hyperlink(url~, tooltip~ : String?)` — wires `<a:hlinkClick>`
  - Auto-allocate slide-level rId; register relationship as `TargetMode::External`
  - Internal: `RunProperties::with_hyperlink_to_slide(slide_idx)` for jump-to-slide actions

🟢 **A3 — Speaker notes builder**
  - `Presentation::set_notes_mut(slide_idx, "text")` — creates / updates `/ppt/notesSlides/notesSlideN.xml`
  - Auto-register notes master + Override content type if missing
  - Fluent: `Slide::with_notes(text)` (returns new Slide with the linked notes slide)

🟢 **A4 — Picture crop fluent builder**
  - `Picture::with_crop(l~, t~, r~, b~ : @units.Percentage)` — wraps `SrcRect`
  - Crop is idempotent at the value level (replaces, not merges)

🟢 **A5 — Slide size selector**
  - `Presentation::set_slide_size_mut(SlideSize)` where `SlideSize { ScreenFourByThree | ScreenSixteenByNine | ScreenSixteenByTen | Letter | Legal | A4 | …}`
  - Maps to ECMA-376's 17 `ST_SlideSizeType` values
  - Updates `presentation.xml` `<p:sldSz>` + recomputes any `pct_of_slide_w` helpers

🟢 **A8 — Slide number / header / footer / date** *(landed 2026-05-29 with C1)*
  - `Slide::with_slide_number(visible : Bool)`, `Slide::with_footer("text")`, `Slide::with_date(DateMode { Auto | Fixed(String) })` — append slide-level `dt`/`ftr`/`sldNum` placeholder shapes (idempotent: re-calling replaces). Number/auto-date use `<a:fld>` fields (`slidenum`/`datetime1`); footer/fixed-date use literal text. No `<a:xfrm>` so position inherits from the master placeholder
  - Master-side declaration is `MasterDefinition.slide_number` / `footer_text` / `date` on `define_master` (C1) — that's where the placeholders that make these render are declared

🟢 **B2 — Table cell border fluent builders (extended)**
  - `TableCell::with_borders(left~, right~, top~, bottom~ : Stroke?)` — convenience over the existing 6 `with_border_*`
  - Per-border `Stroke` reuses `@oxml.Stroke`

🟢 **C2 — Percentage / relative positioning**
  - `@units.pct_of_slide_w(prs, 5.0) -> Emu`, `@units.pct_of_slide_h(prs, 5.0) -> Emu`
  - `@units.Pct(5.0)` newtype + `Pct::resolve_w(prs)` / `Pct::resolve_h(prs)`
  - README quickstart switches to percentage-based positions for readability

🟢 **Docs + examples**
  - `examples/README.md` with 8 cookbook recipes (title slide / widescreen / hyperlinks / notes / images / tables / charts / pitch deck).
  - Each recipe verified by `src/integration/examples_test.mbt`.
  - Main README links to `examples/`.

---

### 4.2 v0.3.0 — "Multimedia + Layout"

DoD: every feature PptxGenJS covers is expressible; slide masters can
be defined programmatically end-to-end.

Status (2026-05-30): **all items landed on `main`** — A6, A7, A8, B1, B4
(added from external review), C1, C3, C4, D6. 914 tests × 4 backends.
**Ready to tag v0.3.0** pending an API-stability pass (no breaking
changes vs 0.2.0 — every change this cycle was additive `.mbti` except
the necessary `Slide.background` / `Picture.media` struct-field additions,
which 0.x SemVer permits).

🟢 **A6 — Audio / video embedding** *(landed 2026-05-29)*
  - `Presentation::add_video_mut(slide_idx, video_bytes, poster_bytes, x, y, cx, cy)` + `add_audio_mut(...)` — wire the media part + poster part, three relationships (`image` poster, `video`/`audio` link, `media` embed), content-type defaults, and the shape
  - Magic-byte detection in `@oxml.detect_media_format`: mp4 / mov / avi / wmv (video) + mp3 / wav / aiff / m4a (audio), with `content_type` / `extension` / `is_video`
  - **Modelled as `Picture.media : MediaInfo?` (not a new `Shape::Media`)** — a media clip *is* a `<p:pic>`, so reusing `Picture` (poster `blipFill` + `spPr` transform) avoids a parallel shape kind. `MediaInfo { kind : MediaKind, link_id, embed_id }`; builder `@slide.Picture::of_media`. The writer emits `<a:videoFile>`/`<a:audioFile>` + `<p:extLst><p14:media>` inside `<p:nvPr>` and a `ppaction://media` `<a:hlinkClick>` on `<p:cNvPr>` (threaded through `write_nv_wrapper` / `write_cnvpr`; `write_xml_element` auto-declares `p14`)
  - **No parser changes**: existing decks' `<a:videoFile>` / `<p14:media>` already round-trip via `Picture.extension` (ADR-004), so the parser leaves `media = None` and built media re-parses to the same lossless XML (verified by stable re-serialisation). New `@oxml.powerpoint_2010_ns` / `media_ext_uri` + `@opc.rt_video` / `rt_audio` / `rt_media`
  - Caller supplies the poster frame (no built-in video thumbnailer — consistent with C4's SVG fallback; out of scope per §0)
  - *Deviation from the original sketch (`Shape::Media`) noted above; typed reading of existing media references can be a later lift if a consumer needs it.*

🟢 **A7 — Slide background typed builder** *(landed 2026-05-29)*
  - New typed `Background` enum — `Properties(BackgroundProperties)` for `<p:bgPr>` (fill + `shadeToTitle` + effects + `extension`) and `StyleReference(idx, Color)` for `<p:bgRef>`. Reuses `@oxml.Fill` rather than a parallel `BgFill` enum (the roadmap's `BgFill { Solid|Gradient|Picture|NoFill }` is a subset of `@oxml.Fill`; no parallel types per conventions). `BackgroundProperties.fill` is `Option` (like `AutoShape.fill`) so the rare `<a:grpFill>` round-trips via `extension`
  - `Slide::with_background(@oxml.Fill)`, `Slide::with_background_ref(idx, Color)`, `Slide::without_background()` (immutable, ADR-003) + `BackgroundProperties::of_fill`
  - Lifts `<p:cSld>`'s `<p:bg>` from extension-only to the typed `Slide.background` field (parser + writer); writer emits `<p:bg>` before `<p:spTree>` per CT_CommonSlideData order

🟢 **C1 — `define_master` high-level API** *(landed 2026-05-29)*
  - `Presentation::define_master(MasterDefinition) -> Int` (returns the new master index); `MasterDefinition::new(name)` + `with_placeholder` / `with_background` / `with_footer` / `with_slide_number` / `with_date` builders
  - `MasterDefinition { name, background : @slide.Background?, placeholders : Array[PlaceholderDef], slide_number : Bool, footer_text : String?, date : Bool }` (reuses A7 `Background` instead of a fresh `BgFill`; added `date` for A8 pairing). `PlaceholderDef { kind : @slide.PlaceholderType, position : @slide.Transform, default_text : String? }` (reuses B1 `PlaceholderType` + the existing `Transform` rather than a new `Rect`)
  - Synthesises `<p:sldMaster>` + one dependent blank `<p:sldLayout>`, wires parts / rels (master→layout+theme, layout→master, presentation→master) / content-types / `<p:sldMasterIdLst>`. Reuses the package's first theme part; defaults the master `<p:bg>` to the standard `bgRef` when none given (a master with no bg trips PowerPoint's repair banner)
  - **Implementation note**: the master `<p:cSld>` (bg + placeholder shapes) is produced by serialising a throwaway typed `@slide.Slide` (reuses the slide writer's shape emission + XML escaping) and extracting `<p:cSld>…</p:cSld>`, then re-wrapping as a master (`<p:clrMap>` + `<p:sldLayoutIdLst>`). Verified end-to-end by save→reopen + adding a slide on the new layout

🟢 **C3 — Combo chart + secondary axis builder** *(landed 2026-05-29)*
  - `Chart::of_combo(primary : ChartPlot, secondary : ChartPlot, secondary_axis? : Bool = false)` where `ChartPlot { Bar(ChartData) | Line(ChartData) | Area(ChartData) }` — overlays two plots on a shared `catAx`/`valAx` pair
  - Reuses the existing `PlotArea` multi-plot capability (two `Plot`s in `plots`)
  - With `secondary_axis=true` the secondary plot binds to its own axis pair (ids 3/4): a `valAx` drawn on the right crossing at `Max`, plus a `delete=true` secondary `catAx` as its crossing partner — the standard Office 4-axis structure
  - Secondary plot's series `idx`/`order` are offset past the primary's (via `synthesize_series_from`) so indices stay unique chart-wide (a duplicate idx trips PowerPoint's repair prompt); round-trip verified by `assert_eq(reparsed, original)`

🟢 **C4 — SVG image support** *(landed 2026-05-29)*
  - `Presentation::add_svg_picture_mut(slide_idx, svg_bytes, fallback_bytes, x, y, cx, cy)` — adds the SVG + a raster fallback part, two `rt_image` rels, `image/svg+xml` + fallback content-type Defaults, and the picture shape. (The slide-package `Picture` can't manage OPC parts, so the full pipeline lives at the presentation level rather than on a `Picture::of_svg` as the roadmap sketched; the low-level shape builder is `@slide.Picture::of_svg_image(id, name, png_embed_id, svg_embed_id, …)`.)
  - `@oxml.BlipFill::svg(png_embed_id, svg_embed_id)` builds `<a:blip r:embed=fallback>` carrying `<a:extLst><a:ext uri="{96DAC541…}"><asvg:svgBlip r:embed=svg/></a:ext></a:extLst>` (the Office 2016+ extension). New `@oxml.svg_ns` / `svg_blip_ext_uri` / `ct_svg` constants. The synthesised blip rides in `BlipFill.extension` exactly as a parsed SVG picture would, so the writer emits it verbatim and `write_xml_element` auto-declares the SVG namespace
  - Caller supplies the raster fallback (no built-in SVG rasteriser — out of scope per §0); the fallback is shown by PowerPoint < 2016 and thumbnails

🟢 **B1 — Placeholder named accessors** *(landed 2026-05-29)*
  - `Slide::placeholders() -> Array[(PlaceholderType, Shape)]`
  - `Slide::title() -> Shape?` (matches `Title`/`CtrTitle`), `Slide::body() -> Shape?`, `Slide::placeholder(kind) -> Shape?`
  - New typed `PlaceholderType` enum (16 `ST_PlaceholderType` values + `Other(String)` forward-compat) with `from_xml`/`to_xml`; `Placeholder::kind()` derives it from the raw `ph_type`. The raw `ph_type : String` field is left untouched so an absent `type` attribute (the common body/content case) stays lossless — the typed lift is a non-raising accessor, not a struct field (unlike `SlideLayoutType`, whose root `type` is effectively always present)

🟢 **B4 — Pinpoint shape editing** *(landed 2026-05-29; surfaced by external review)*
  - **Gap**: the mutation API is append-only (`Slide::with_shape`) + whole-slide replace (`update_slide_mut`). Editing an *existing* shape (retitle, move, recolour) means manually rebuilding the `shapes` array and reconstructing the `Slide` via its `pub(all)` struct — doable but unergonomic, and the B1 accessors return shape *values* with no write-back path (no index/identity handle). python-pptx does this in one line (`shape.text = …`).
  - **Identity handle** (see open question Q11): shapes carry a unique-per-slide `id`. Add `Shape::id() -> Int?` and `Shape::name() -> String?` so callers can locate a shape without index fragility. (`Unknown` has no id → `None`.)
  - **Slide-level** (immutable, ADR-003):
    - `Slide::map_shapes(f : (Shape) -> Shape) -> Slide` — transform every shape (bulk recolour / reposition)
    - `Slide::with_shape_at(index : Int, shape : Shape) -> Slide` and `Slide::with_shape_mapped(index, f) -> Slide` — replace / transform by position
    - `Slide::with_shape_by_id(id : Int, f : (Shape) -> Shape) -> Slide` — transform the shape with that id (primary, index-stable)
    - `Slide::without_shape(index) -> Slide` / `without_shape_by_id(id)` — remove
  - **Presentation-level** (`_mut`, closes the find→edit→write-back loop in one call): `Presentation::map_slide_shapes_mut(slide_idx, f)` and `Presentation::update_shape_by_id_mut(slide_idx, id, f)`
  - **DoD**: open a real deck → locate a shape via B1 accessor or id → change its text / transform / fill → save, all without touching the `shapes` array by hand or dropping to XML. Round-trip + lossless preservation of untouched shapes must hold.
  - **Shipped as designed** with `Shape::id()` / `Shape::name()` accessors (the index/id handles). **Q11 resolved**: id-based + `map_shapes` are primary, index helpers are thin conveniences, and a missing id / out-of-range index raises `SlideError` (mirroring `update_slide_mut`) — `map_shapes` is the non-raising best-effort path.
  - **Writer fix (important)**: parsed shapes capture `<p:cNvPr>` wholesale into `extension`, which previously *shadowed* the typed `name`/`id` on write — so editing those fields silently didn't persist. `write_cnvpr` now re-emits the captured `<p:cNvPr>` but overrides its `id`/`name` attribute *values* with the typed fields (preserving order + `descr`/`title`/`hlinkClick` children). Byte-identical for unmodified shapes (all golden round-trip tests unchanged); edited values now flow through. Pairs with B1 — together they make moon-pptx a first-class *editor*, not just a reader+builder.

🟢 **D6 — Lossless diff-write** *(landed 2026-05-29 — delivered by `save()`, no new API)*
  - **Finding**: the property is already inherent in the architecture. The OPC layer stores each part's *source bytes* (raw ZIP-entry bytes from `Package::open`), and only `_mut` operations replace a part's bytes; `save()` (= `Package::to_bytes`) re-zips the stored bytes. So untouched parts are re-emitted verbatim and mutated parts carry the writer's output — exactly the D6 contract — **with no dirty-tracking or hashing** (Q10 resolved: retention-by-construction).
  - The separate `save_diff(original_bytes)` API from the original sketch was deemed **redundant**: a truly general version (per-part typed-model comparison to undo *cosmetic* re-serialisation of a semantically-unchanged but explicitly re-written part) needs per-part-type parse+compare for marginal benefit, since the dominant open→edit→save flow already preserves Office's exact bytes on every untouched part. Not added; can revisit if a concrete consumer needs the cosmetic-undo case.
  - Locked in by `src/presentation/diff_write_test.mbt`: editing one slide leaves every other part (sibling slide, theme, master, layout, `presentation.xml`, presProps) byte-for-byte identical, and a pure open→save preserves every part incl. `[Content_Types].xml`.

---

### 4.2.1 v0.3.1 — "Deck editing: arrange"

Status (2026-06-01): **all three items landed on `main`** (E1 + E2 + E3).
939 tests × 4 backends. **Ready to tag v0.3.1** — every change is
additive `.mbti` (no breaking change vs 0.3.0).

DoD: a consumer can fully *arrange* a deck programmatically — delete,
reorder, and duplicate slides — and save a clean package that opens in
PowerPoint without a repair prompt. This closes the deck-level editing
story that pairs with B4's shape-level editing. Surfaced by an external
Skill built on this library: the build API was append-only + whole-slide
replace, with no way to *delete*, *reorder*, or *clone* a slide (only
`Slide::without_shape*` removed shapes within a slide). That blocked the
"trim a template down to exactly the slides I generated" / `replaceSlides`
flow and "duplicate this template slide, then fill it" generation.

🟢 **E1 — Slide deletion** *(landed 2026-06-01)*
  - `Presentation::remove_slide_mut(slide_index)` — mutating; the inverse of `add_slide_mut`. Unthreads the slide everywhere the OPC package tracks it: the `<p:sldId>` in `<p:sldIdLst>`, the `presentation.xml.rels` relationship, the `/ppt/slides/slideN.xml` part, its `slideN.xml.rels`, and its `[Content_Types]` `<Override>`.
  - `Presentation::without_slide(slide_index) -> Self` — immutable counterpart (ADR-003), clones the package then removes.
  - **Orphan garbage-collection**: slide-private parts reachable *only* through the removed slide (its notes slide, images, charts, embedded media) are removed once no surviving part's `.rels` references them (reference counting over the remaining package graph). Shared structural parts (slide **layout / master / theme / notes master**) are *never* removed — matches the external reviewer's "孤児だけ消す / 迷うなら消さない" guidance: an orphaned part only bloats the file, but deleting a still-referenced one corrupts it. Removable types are whitelisted (`ct_notes_slide` / `ct_chart` / `ct_chart_ex` / `image/*` / `video/*` / `audio/*`).
  - New `@opc.ContentTypes::without_override(part_name)` companion to `with_override` (no-op for `Default`-typed parts like images).
  - **DoD met**: middle-slide deletion + clear-all-slides ("replaceSlides") both round-trip via save→reopen; layout/master/theme survive; a slide-private image is collected while an image referenced by a surviving slide is kept. 8 new tests; additive `.mbti` (`remove_slide_mut` / `without_slide` / `without_override`).

🟢 **E2 — Slide reordering** *(landed 2026-06-01)*
  - `Presentation::move_slide_mut(from : Int, to : Int)` + immutable `with_slide_moved(from, to) -> Self`. `to` is the destination index in the resulting order; `from == to` is a no-op.
  - Pure `<p:sldIdLst>` reordering — PowerPoint keys on-screen order off `sldIdLst`, not part names, so this is a cheap array-permute on `sld_ids` + re-serialise of `presentation.xml`. No part renaming, no rels / content-type churn (verified: parts keep their names across save→reopen). 7 new tests.

🟢 **E3 — Slide duplication / clone** *(landed 2026-06-01)*
  - `Presentation::duplicate_slide_mut(slide_index) -> String` (returns the new part name; appended to the end) + immutable `with_duplicated_slide(slide_index) -> (Self, String)`.
  - Copies the slide body verbatim and wires the clone like `add_slide_mut` (new part + `.rels` + `<p:sldId>` + presentation rel + content-type override).
  - **Q12 resolved**: the clone **re-references** the source's parts (layout / images / charts / media / notes) rather than deep-copying them. The slide `.rels` is slide-local and both slides live in `/ppt/slides/`, so the copy's `.rels` carries identical relative targets, the copied slide XML keeps its `rId` references valid unchanged, and shared parts stay alive via E1's reference-counted deletion. Leaner + round-trip-safe; trade-off is that editing a shared chart's data / notes affects both slides — a fully-independent deep-copy variant can land later if a consumer needs it. 6 new tests, incl. an E1+E3 integration (a clone keeps a shared image alive when the original slide is removed).

---

### 4.3 v0.4.0 — "MoonBit differentiators"

DoD: two headline features land that no other PPTX library — in any
language — offers.

Status (2026-06-07): **all v0.4.0 items landed on `main`** — D3 (transition
builder), M2 (ADT chart options), D4 (typed picture builder), D7 (chart-data
validation), and **M1 (compile-time placeholder schema, the ⭐ headline)**.
993 tests × 4 backends. **Ready to tag v0.4.0** pending an API-stability pass
(every change this cycle was additive `.mbti`).

🟢 **M1 — Compile-time placeholder schema** ⭐ *(landed 2026-06-07; Q7 resolved)*
  - Typed layout handle `LayoutSlide[L]` with per-layout named constructors `Presentation::add_title_slide_mut` / `add_title_content_slide_mut` / `add_section_header_slide_mut` / `add_title_only_slide_mut` / `add_blank_typed_slide_mut`, returning `LayoutSlide[TitleSlide]` / `[TitleAndContent]` / `[SectionHeader]` / `[TitleOnly]` / `[BlankSlide]`. Placeholder accessors `title` / `subtitle` / `body` are gated by capability traits (`HasTitle` / `HasSubtitle` / `HasBody`) — **accessing a placeholder the layout doesn't have is a compile error** (e.g. `.body()` on a title slide; `.subtitle()` on title-and-content). `finish_mut()` commits the built slide. Legacy `add_slide_mut(layout_index)` is unchanged.
  - **Q7 resolved → hybrid**: one generic `LayoutSlide[L]` builder (each accessor defined once, gated by `fn[L : HasTitle] …`) + ergonomic per-layout named constructors (no caller turbofish). The marker types (`TitleSlide` etc.) are carried as a value field (`marker : L`) rather than a bare phantom — a pure phantom param trips `unused_type_variable` / `struct_never_constructed` under `--deny-warn`; capability traits use methods on that marker, and impls are `pub impl` so blackbox tests/consumers see them.
  - **Layout binding → (i) resolve/synthesise by type**: each named constructor calls `ensure_layout_of_type` (`ensure_layout.mbt`), which finds an existing `<p:sldLayout type=…>` or synthesises one — declaring the layout's placeholders and wiring it into the first master's `<p:sldLayoutIdLst>` + rels + content types (reuses the `define_master` cSld synthesis; `wrap_slide_layout_xml` generalised to take the layout type). Synthesis is idempotent — two slides of the same type share one layout. Built on a new `@slide.Slide::with_placeholder(kind, idx, text?)` primitive (M1-1).
  - **Scope (documented)**: ships TitleSlide / TitleAndContent / SectionHeader / TitleOnly / Blank (unambiguous placeholder sets). TwoContent / Comparison / ContentWithCaption / PictureWithCaption (multi-body + caption layouts) are a follow-up; the capability-trait design extends to them additively (new marker + trait impls). Content uses typed `body` placeholders (`type="body"`) for self-consistency between synthesised layout and slide. The compile-time guarantee is the differentiator no other PPTX library offers.
  - 14 new tests (per-layout title/subtitle/body round-trips + reopen, layout synthesised + idempotent, blank = no placeholders, mixed deck) + 4 for the `with_placeholder` primitive; additive `.mbti`. 975 → 993 × 4 backends.

🟢 **M2 — ADT-driven chart options** *(landed 2026-06-07)*
  - `Chart::with_options(opts : Array[ChartOption]) -> Chart` (immutable, ADR-003) folds a sum-type option list into the chart's already-typed model — `src/chart/chart_options.mbt`, no parser/writer changes (the existing writer serialises the fields the options populate).
  - `ChartOption { Title(String) | TitleDeleted | Legend(LegendPos) | LegendHidden | DataLabels(DLblPos) | DataLabelsHidden | DataTable(Bool) | Style(Int) | RoundedCorners(Bool) | PlotVisibleOnly(Bool) | DisplayBlanks(DisplayBlanksAs) }`. `Title` synthesises the `<c:title><c:tx><c:rich>` DrawingML body; `Legend` preserves any existing per-entry overrides; `DataLabels` sets value labels at the position; `DataTable` synthesises `<c:dTable>`.
  - **Headline property — compile-time exhaustiveness**: the private `apply_chart_option` matches every `ChartOption` and `plot_with_d_lbls` matches all 16 `Plot` families (the two surface families, which have no `<c:dLbls>`, are explicit no-ops). Adding a new option or a new plot family without handling it is a *compile error*, not a silently-dropped feature — the differentiator the sketch called for (sharpened from "writer warning" to a total builder match, since the writer was already exhaustive).
  - **Deferred (documented like A6/A7/C4/D3)**: `Trendline(series_idx, …)` and `SecondaryAxis(series_idx)` target deep per-series / per-axis nesting (and secondary-axis restructuring is already done at construction time by `of_combo`); a number-format option waits until it can name its target (value axis vs. data labels) — the typed `NumFmt` already exists for that lift.
  - 14 new tests (per-option set + round-trip, title-text serialisation, data-labels across bar/pie, surface no-op, multi-option compose, immutability); additive `.mbti` (`Chart::with_options` + `ChartOption`). 955 → 968 × 4 backends.

🟢 **D3 — Transition builder** *(landed 2026-06-07)*
  - `Slide::with_transition(Transition)` / `without_transition()` (immutable, ADR-003). `<p:transition>` (CT_SlideTransition) lifts out of `Slide.extension` into a typed `Slide.transition : Transition?` field, exactly mirroring how A7 lifted `<p:bg>`.
  - **Model**: `Transition { kind : TransitionKind, speed, advance_on_click, advance_after : Int?, extension }` where `TransitionKind` is the 22-variant choice child of CT_SlideTransition (`Fade(thruBlk) | Cut(thruBlk) | Push(TransitionSide) | Wipe(TransitionSide) | Cover/Pull(TransitionDirection) | Split(orient, dir) | Blinds/Checker/Comb/RandomBar(TransitionOrientation) | Strips(TransitionCorner) | Wheel(spokes) | Zoom(TransitionInOut) | Circle | Diamond | Dissolve | Newsflash | Plus | Random | Wedge | NoEffect`). Direction/orientation sub-enums (`TransitionSide` l/u/r/d, `TransitionDirection` 8-way, `TransitionOrientation` horz/vert, `TransitionInOut` in/out, `TransitionCorner` 4-corner) each carry `from_xml`/`to_xml`. Convenience constructors `Transition::fade/cut/push/wipe/cover/split/zoom/dissolve/none` + the general `of_kind`; timing builders `with_speed` / `with_on_click` / `with_advance_after` / `without_advance_after`.
  - **Deviations from the sketch** (documented like A6/A7/C4): (1) **speed, not ms duration** — base CT_SlideTransition's timing is `spd` (slow/med/fast), not a millisecond `with_duration`. `with_advance_after(ms)` maps to the `advTm` attribute (auto-advance), `with_on_click` to `advClick`. (2) **base ST only** — the "39 variants" count includes PowerPoint-2010 `p14:` extended transitions (reveal, vortex, ferris, …) and the `p14:dur` ms duration, which are wrapped in `<mc:AlternateContent>`; those still round-trip losslessly via `Transition.extension` / `Slide.extension` (ADR-004) but are not yet typed. `Reveal` is therefore deferred (it is p14-only). A future lift can add the `p14` layer + ms duration if a consumer needs it.
  - **Writer**: emits `<p:transition>` after `<p:clrMapOvr>` and before the sld-level extension replay (`<p:timing>`), per CT_Slide ordering. Default attributes (`spd="fast"`, `advClick="1"`) and a default `spokes="4"` are omitted (they re-parse to the same model). `<p:sndAc>` / `<p:extLst>` children ride on `Transition.extension`.
  - 14 new tests (per-kind round-trip, attribute decode + default fallback, builder defaults, canonical-omission, `<p:sndAc>` preservation); two pre-existing extension tests updated for the lift. Additive `.mbti` (plus the `Slide.transition` struct field, like A7's `background`). 940 → 955 × 4 backends.

🟢 **D7 — Chart-data validation** *(landed 2026-06-07; compile-time lift deferred)*
  - `ChartData::validate(self) -> ChartData raise ChartError` checks that every series carries exactly one value per category, returning `self` for fluent composition (`Chart::of_bar(data.validate())`) and raising `Malformed` (naming the offending series + counts) on mismatch. Companions `ScatterData::validate` (X/Y lengths) and `BubbleData::validate` (X/Y/size lengths), plus non-raising `is_consistent() -> Bool` on all three. — `src/chart/chart_validation.mbt`.
  - **Deviation from the sketch**: validation is a standalone `validate()` gate, *not* baked into `with_series`. Making `with_series` raise would force categories-before-series ordering and break the infallible fluent chains used throughout the cookbook; a separate gate is order-independent and non-breaking, and the lenient pad/truncate builders stay the default (validate is opt-in, called at the build boundary).
  - **Compile-time lift still deferred** (as the roadmap notes): the phantom-type-parameter approach to make a length mismatch a *compile* error waits on MoonBit's const-generics-like features. This slice delivers the runtime gate.
  - 7 new tests (consistent passes + composes into `of_bar`; under/over-long values, scatter X/Y, bubble X/Y/size mismatches raise; empty data is consistent). Additive `.mbti`. 975 → 982 × 4 backends.

🟢 **D4 — Typed picture builder state machine** *(landed 2026-06-07)*
  - `Picture::builder(id, name, embed_id, x, y, cx, cy) -> PictureUncropped` opens a compile-time-enforced pipeline; `.with_crop(...)` → `PictureCropped`, `.with_effects(outline?, effects?)` → `PictureFinal`, `.build()` → `Picture` (the flat type). `build()` is available at every stage (crop + effects are both optional). — `src/slide/picture_builder.mbt`.
  - **Type-state enforcement**: each stage exposes only its valid operations, so a second `.with_crop` (cropping twice) or `.with_effects` after `.build` is a *type error*. The three state types are opaque (`pub struct` with package-private fields, like `@opc.Package` / `@xml.XmlReader`); callers move through them only via the methods. Three concrete state types (over a phantom type-parameter) — guaranteed to dispatch correctly and matching the roadmap's named types.
  - **Deviation from the sketch**: the entry point is a new `Picture::builder(...)`, not a re-typed `Picture::of_image` — the latter's `-> Picture` return is load-bearing for existing callers and `add_picture_mut`. The flat `Picture::of_image` / `with_crop` stay as the unconstrained path.
  - 7 new tests (per-stage build, crop sets srcRect, effects set outline/effectLst, omitted fields stay unset, crop+effects, slide round-trip); additive `.mbti`. 968 → 975 × 4 backends.

---

### 4.4 v0.5.0 — "Animation & SmartArt"

DoD: SmartArt and animation builders land; together with v0.4
differentiators, moon-pptx becomes demonstrably the most capable
PPTX library available.

Status (2026-06-12): **all v0.5.0 items landed on `feature/v0_5`** —
D2 (animation DSL ⭐), D8 (chart-option validation), C5 (YouTube / URL
video embed), and **D1 (SmartArt builder ⭐ — all eight families across
slices 1–4, with the full five-part DiagramML + cached drawing)**.
1062 tests × 4 backends. **Ready to tag v0.5.0** pending an API-stability
pass (every change this cycle was additive `.mbti`, plus the
`Slide.timing` struct field for D2 and the `PptxError::SmartArtFailure`
variant for D1, which 0.x SemVer permits).

🟢 **D2 — Animation DSL** ⭐ headline feature *(slices 1–5 — entrance/exit + emphasis + motion paths + fly-in + text builds — landed 2026-06-09)*
  - `Timeline { triggers : Array[Trigger] }`, `Trigger { kind : TriggerKind, effects : Array[Effect] }`
  - `TriggerKind { OnClick | AfterPrevious | WithPrevious | Time(Pt) }`
  - `Effect { Entrance(EntranceEffect, target_shape_id) | Emphasis(EmphasisEffect, _) | Exit(ExitEffect, _) | MotionPath(custom_path) }`
  - ~30 standard effects (Appear / Fade / FlyIn / Wipe / Zoom / Rotate / Pulse / GrowShrink / Teeter / Spin / …)
  - Custom motion paths reuse Phase 3h's `CustomGeometry::PathCommand` (`MoveTo` / `LnTo` / `CubicBezTo` / etc.)
  - Emits `<p:timing>` body that was previously round-tripped through `Slide.extension`
  - **Shipped (slice 1 — entrance + exit)**: `Slide.timing : Timeline?` (the typed form of `<p:timing>`, mirroring D3's `<p:transition>` lift) + `Slide::with_animations` / `without_animations`. `Timeline::new().on_click(eff, id) / .with_previous(...) / .after_previous(...)` builds an ordered step list (`src/slide/animation.mbt`); `animation_writer.mbt` synthesises the full canonical main-sequence tree (tmRoot → seq → mainSeq → per-group `<p:par>` → per-effect behaviours) as an `@xml.XmlElement` DOM emitted through `@oxml.write_xml_element`. `AnimEffect { Entrance(VisualEffect) | Exit(VisualEffect) }`; one shared `VisualEffect { Appear | Fade | Wipe(dir) | Blinds(orient) | RandomBars(orient) | Dissolve | Wedge | Wheel(spokes) }` drives both classes (entrance plays the `<p:animEffect>` filter `in` + reveals via `<p:set>` on `style.visibility`; exit plays it `out` + hides). `preset_id` / `filter` are exhaustive over `VisualEffect` (a new effect without metadata is a compile error). Start modes map to the standard `clickEffect` / `afterEffect` / `withEffect` node types + click/auto trigger delays.
  - **Deviations (documented like A6/A7/C4/D3)**: (1) **Build-only**, like A6 media — the typed timeline is emitted by the writer; on *parse* an existing `<p:timing>` round-trips losslessly through `Slide.extension` (ADR-004) and `timing` stays `None`, so a built timeline re-serialises *stably* rather than round-tripping to an equal model. `with_animations` strips any captured `<p:timing>` from `extension` so the writer never double-emits. (2) `presetSubtype="0"` (the per-direction UI hint is cosmetic — PowerPoint renders from the `filter` regardless); precise subtypes are a follow-up. (3) No `<p:bldLst>` yet (optional; the timing tree alone animates).
  - **Shipped (slice 2 — emphasis)**: `AnimEffect::Emphasis(EmphasisEffect)` over `EmphasisEffect { Spin(degrees) | GrowShrink(percent) | ChangeFillColor(@units.RgbColor) }` — in-place effects on an already-visible shape (no `<p:set>` visibility toggle). The writer emits `presetClass="emph"` + the dedicated behaviour element: Spin → `<p:animRot by="degrees*60000">` on the `r` attribute, GrowShrink → `<p:animScale>` with `<p:by x/y>` in 1000ths of a percent, ChangeFillColor → `<p:animClr clrSpc="rgb">` with `<p:to><a:srgbClr>`. `EmphasisEffect::preset_id` is exhaustive (compile-error on a new unclassified emphasis). 5 new tests, additive `.mbti` (`EmphasisEffect` + the `Emphasis` variant). 1018 → 1023 × 4 backends.
  - **Shipped (slice 3 — motion paths)**: `AnimEffect::Motion(MotionPath)` — a custom path the shape travels along (`<p:animMotion>`). `MotionPath::new().move_to / line_to / curve_to / close` (immutable, ADR-003) builds an ordered `MotionCommand` list in `0..1` slide-fraction `MotionPoint`s; `MotionPath::line(dx, dy)` is the one-segment convenience; `to_path_string` renders the `<p:animMotion path="…">` mini-language (`M`/`L`/`C`/`Z`, terminated by `E`). The writer emits `presetClass="path"` + `<p:animMotion origin="layout" pathEditMode="relative">` with `ppt_x`/`ppt_y` in the `<p:attrNameLst>`. **Deviation from the sketch** (documented like D4/C4): the roadmap suggested reusing Phase 3h's `CustomGeometry::PathCommand`, but its `PathPoint` carries EMU / guide coordinates (`<a:path>` shape space) while `<p:animMotion>` uses slide fractions — a different coordinate space, so a dedicated fractional `MotionPath` keeps each model in its own units. 4 new tests, additive `.mbti`. 1023 → 1027 × 4 backends.
  - **Shipped (slice 4 — fly in / fly out)**: `VisualEffect::FlyIn(AnimDirection)` (in the shared entrance/exit enum, so `Entrance(FlyIn(Left))` flies in from the left and `Exit(FlyIn(Left))` flies out to it). Instead of an `<p:animEffect>` filter it emits a positional `<p:anim calcmode="lin" valueType="num">` on `ppt_x` / `ppt_y` with a `<p:tavLst>` moving between an off-slide value (`0-#ppt_w/2` / `1+#ppt_w/2` / `0-#ppt_h/2` / `1+#ppt_h/2`, per PowerPoint's fly convention) and the shape's home (`#ppt_x` / `#ppt_y`), paired with the visibility `<p:set>`. New `VisualEffect::fly_direction` classifier, orthogonal to `filter` (the writer picks fly-anim / filter-effect / bare-set). 4 new tests, additive `.mbti`. 1027 → 1031 × 4 backends.
  - **Shipped (slice 5 — by-paragraph text builds)**: `AnimStep.paragraph : Int?` (set via the new optional `paragraph?` arg on `on_click` / `with_previous` / `after_previous`) targets one text paragraph — the `<p:spTgt>` carries `<p:txEl><p:pRg st=… end=…>` and the shape is declared a by-paragraph build with a `<p:bldP spid grpId build="p"/>` in a `<p:bldLst>` (CT_SlideTiming order: `tnLst`, `bldLst`). Each by-paragraph shape gets a distinct build-group id (1, 2, …) shared between its paragraph effects' `grpId` and its `<p:bldP>`; whole-shape effects stay in group 0. 3 new tests, additive `.mbti` (the `paragraph` field + the optional builder arg). 1031 → 1034 × 4 backends.
  - **Closed out (not implemented, with rationale)**: typed *parsing* of an existing `<p:timing>` into `Timeline` is intentionally **not** attempted — the high-level `Timeline` is a deliberately lossy build model (it cannot represent every PowerPoint timing tree), and the lossless read path already exists via `Slide.extension` (ADR-004). A lossy best-effort parse would risk silently dropping detail; the build-only design (slice 1) is the right boundary. Also deferred as cosmetic-only: precise per-direction `presetSubtype` UI hints (`presetSubtype="0"` renders correctly from the behaviour). **D2 is complete**: all four effect classes (entrance / exit / emphasis / motion) + fly-in + text builds emit a full canonical `<p:timing>`, the DoD ("emits the `<p:timing>` body previously round-tripped through `Slide.extension`"). Slice 1: 12 new tests, additive `.mbti` (+ the `Slide.timing` struct field, like D3's `transition`); 1006 → 1018 × 4 backends.

🟢 **D1 — SmartArt builder** ⭐ headline feature *(slices 1–4 — all eight families: list / process / cycle / pyramid / org-chart / hierarchy / matrix / relationship — landed 2026-06-12)*
  - `SmartArt::org_chart(root : Node)`, `SmartArt::hierarchy(nodes)`, `SmartArt::cycle(nodes)`, `SmartArt::process(nodes)`, `SmartArt::list(items)`, `SmartArt::pyramid(levels)`, `SmartArt::matrix(rows × cols)`, `SmartArt::relationship(...)`
  - `Node { text : String, children : Array[Node], style : NodeStyle? }`
  - Emits `/ppt/diagrams/dataN.xml` + `layoutN.xml` + `colorsN.xml` + `quickStyleN.xml` (DiagramML)
  - Cached graphic-frame fallback rendering for PowerPoint < 2010
  - **Shipped (slice 1 — linear families `List` + `Process`)**: new `src/smartart/` package + `Presentation::add_smartart_mut(slide_idx, smartart, x, y, cx, cy)`. `SmartArt::list(items)` / `process(items)` build a flat box-per-string diagram (general `SmartArt::new(kind, nodes)` + `Node::leaf` / `new` carry children ahead of the hierarchical layouts). `add_smartart_mut` synthesises the **five** DiagramML parts and wires them: `/ppt/diagrams/{data,layout,quickStyle,colors}N.xml` referenced from the slide via a `<dgm:relIds r:dm/r:lo/r:qs/r:cs>` inside a `<p:graphicFrame>`, plus `/ppt/drawings/drawingN.xml` (the cached `<dsp:drawing>`) referenced from the data part's own `.rels` and recorded in the data model via `<dsp:dataModelExt relId=…>`. New constants (`@oxml.ct_diagram_data/layout/style/colors/drawing`, `diagram_ns` / `diagram_drawing_ns` / `diagram_data_model_ext_uri`, `@opc.rt_diagram_data/layout/quick_style/colors/drawing`) + `PptxError::SmartArtFailure`. See **ADR-010**.
  - **Cached drawing = render guarantee**: the data + drawing parts are generated with `@xml.XmlWriter` (correct escaping); the static layout / colors / quickStyle parts are template strings (like the blank-deck template). The `<dsp:drawing>` holds boxes we lay out ourselves (List stacks top-to-bottom, Process left-to-right within the frame extent), so the diagram renders without a layout engine — the roadmap's "cached graphic-frame fallback".
  - **Deviations (documented like A6/C4/D2)**: (1) **`add_smartart_mut`, not `Slide::with_smartart`** — OPC part management lives at the presentation layer (as for charts / media / SVG). (2) **Reuses the `OtherGraphic` round-trip path** for the graphicFrame body (the `<dgm:relIds>` is built by hand as the captured `<a:graphicData>` child) rather than adding a typed `GraphicFrameContent::DiagramContent` — that's exactly how a *parsed* SmartArt already round-trips (ADR-004), so no parser/writer changes. (3) **Build-only** (like A6 / D2): a parsed SmartArt round-trips losslessly via `extension`; the typed `SmartArt` is a build model, not lifted on parse. (4) **Slice 1 = flat linear** — `Node.children` is preserved in the model but slice-1 layouts emit only top-level nodes; the hierarchical families (org-chart / hierarchy / cycle / pyramid / matrix / relationship) are later slices on the same model + part pipeline. (5) **PowerPoint live-verification deferred** to the sample-deck pass (verified here by save→reopen round-trip + XML well-formedness of all five parts across 4 backends), consistent with how prior features (define_master, media) had a follow-up PowerPoint-verification fix.
  - 13 new tests (7 presentation: five parts + content types, four relIds resolve, data→drawing rel + `dsp:dataModelExt`, save→reopen, text escaping, index-2 second diagram, empty raises; 6 smartart: builders, model Eq, data/drawing/layout content, all-parts-well-formed). Additive `.mbti` (+ `PptxError::SmartArtFailure`). 1040 → 1054 × 4 backends.
  - **Shipped (slice 2 — `Cycle` + `Pyramid`)**: two more *flat* families on the same five-part pipeline — `SmartArt::cycle(items)` (boxes evenly around a ring, computed with `@math.sin`/`cos`) and `SmartArt::pyramid(items)` (centred bands widening apex→base). The data model is byte-for-byte the slice-1 flat structure (only `doc_prset_ids` adds the `cycle1` / `pyramid1` built-in ids); `layout_xml` swaps the root `<dgm:alg>` (`cycle` / `pyra` vs `lin`); only the cached `<dsp:drawing>` layout differs (radial / stacked). Adding a flat family is now just a `SmartArtKind` variant + a `layout_boxes` case + a `layout_meta` row (all three are exhaustive matches → the compiler enumerates the work). 5 new tests (cycle/pyramid builders + alg type, drawings lay out N boxes + well-formed, end-to-end wire + reopen). Additive `.mbti`. 1054 → 1057 × 4 backends.
  - **Shipped (slice 3 — `OrgChart` + `Hierarchy`, the first *hierarchical* families)**: `SmartArt::org_chart(root : Node)` (single-root tree) and `SmartArt::hierarchy(nodes)` (forest), both consuming `Node.children`. New `tree.mbt` `flatten` does a pre-order walk → one `FlatNode` per node (gidx / parent / sib-order / depth / children); **the data writer is generalised over it** — every node becomes a point and every node's incoming edge a `parOf` connection whose `srcId` is the parent node (or the doc root for a top-level node). A flat family is a depth-1 tree, so the generalised writer is *byte-equivalent* on List/Process/Cycle/Pyramid (existing tests unchanged). The cached `<dsp:drawing>` uses a tidy tree layout (`tree_layout`): leaves take successive horizontal slots, each parent is centred over the average of its children's slots, depth → vertical level. **Deviation (documented)**: the cached drawing draws *boxes only* — parent→child **connector lines** are not yet emitted (the hierarchy is fully encoded in the data model; PowerPoint draws connectors on its first re-layout/edit). 3 new tests (org-chart parent/child cxns + all nodes drawn, hierarchy forest's two doc edges, presentation end-to-end + reopen). Additive `.mbti`. 1057 → 1060 × 4 backends.
  - **Shipped (slice 4 — `Matrix` + `Relationship`, D1 complete)**: `SmartArt::matrix(items)` lays the items in a roughly-square grid (cols = ⌈√n⌉; four items → a 2×2 quadrant matrix) — a flat family reusing the slice-1 data model + a new grid case in `layout_boxes`. `SmartArt::relationship(center : Node, related : Array[Node])` is a hub-and-spoke: the hub (`center`) is the root and `related` become its children (spokes), so it reuses the slice-3 tree data model; a new `radial_layout` centres the hub and spreads the spokes on a ring. Both add a `doc_prset_ids` + `layout_meta` row (built-ins `matrix1` / `radial1`). **All eight roadmap families now build.** 4 new tests (matrix grid + relationship hub box counts, relationship hub/spoke cxns, presentation end-to-end + reopen for both). Additive `.mbti`. 1060 → 1062 × 4 backends.
  - **PowerPoint-verification correction (2026-06-16)**: opening the deck in PowerPoint Web showed PowerPoint **re-lays-out SmartArt from the `layoutDef`, not the cached `<dsp:drawing>`** (so the cached drawing only helps non-editing viewers, if at all). Our `layoutDef` `forEach` is single-level, so the **5 flat families render fully** but the **3 nesting families (org_chart / hierarchy / relationship) render top-level only** — the data model is correct + recognised as SmartArt (full hierarchy in the text pane), but children don't draw. The "render guarantee" framing above is therefore accurate only for the flat families on PowerPoint Web. See the 2026-06-16 changelog entry + §9 risk.
  - **Follow-ups**: **(priority)** a recursive hierarchy `layoutDef` (`hierRoot`/`hierChild` composite + nested `forEach`) so PowerPoint lays out the nesting families; parent→child **connector lines**; per-node styling (`Node.style`).

🟢 **C5 — YouTube / URL video embed** *(landed 2026-06-11)*
  - `Presentation::add_online_video_mut(slide_idx, video_url, poster_bytes, x, y, cx, cy)` — embeds any web/streaming video URL; `add_youtube_video_mut(slide_idx, youtube_url, poster_bytes, …)` is the convenience that normalises a YouTube `watch?v=` / `youtu.be/` / `/embed/` / `/shorts/` URL to the embeddable `https://www.youtube.com/embed/<id>` form PowerPoint stores.
  - **Reuses A6 plumbing exactly**: an online video is the *same* `<p:pic>` as an embedded clip (`Picture::of_media`, `Video` kind) — `<a:videoFile r:link>` + `<p14:media r:embed>` — but both media relationships are `TargetMode=External` pointing at the URL, so **no `/ppt/media/mediaN.*` part** is created (only the poster image part + its `rt_image` Internal rel). `src/presentation/add_online_video.mbt`.
  - **Deviation from the sketch** (documented like A6/C4): (1) entry point is a presentation-level `add_online_video_mut`, not `Slide::with_youtube_video` — OPC part management (the poster) lives at the presentation layer, exactly as C4's SVG and A6's media do. (2) **Caller supplies the preview frame** (required `poster_bytes`, gated through `detect_image_format`) — no built-in thumbnailer / network fetch (out of scope per §0), matching A6's "caller supplies the poster" and C4's "caller supplies the raster fallback". URL normalisation handles the four common YouTube shapes via a private `youtube_embed_url`; an unrecognised URL raises `Malformed`.
  - 6 new tests (external video/media rels + no media part, save→reopen with the external rel intact, YouTube URL normalisation across all four shapes, rejects a no-id URL, rejects empty URL + bad poster). Additive `.mbti` (`add_online_video_mut` + `add_youtube_video_mut`). 1034 → 1040 × 4 backends.

🟢 **D8 — Plot-type-aware chart-option validation** *(runtime gate landed 2026-06-09; compile-time lift deferred)*
  - **Motivation**: surfaced verifying the v0.4 sample deck in PowerPoint. `Chart::with_options(DataLabels(pos))` (M2) currently emits *any* `ST_DLblPos` value the caller passes, without checking it against the chart's plot type(s). PowerPoint then rejects the file and runs its repair pass — e.g. `outEnd` is valid on `barChart`/`pieChart` but **invalid on `lineChart`/`scatterChart`/`radarChart`** (those allow only `ctr`/`l`/`r`/`t`/`b`). The library faithfully emits the request (same philosophy as the lenient `with_series`), so an invalid combo isn't caught until PowerPoint opens it.
  - **Goal**: catch the mismatch *before* it reaches PowerPoint, leaning on the type system where possible.
    - Runtime first: a `Chart::validate() -> Chart raise ChartError` (pairs with D7's `ChartData::validate`) that walks each plot's `d_lbls.d_lbl_pos` and rejects positions invalid for that plot family (bar-clustered vs bar-stacked vs line/scatter/radar vs pie/doughnut). Also a non-raising `is_consistent()`.
    - Investigate a *compile-time* lift: a per-plot-family `DataLabelPosition` (e.g. `LinePos` / `BarPos` / `PiePos`) so `with_options` on a typed chart can only accept positions its plots allow — making the invalid combo a compile error (the M1/D4-style differentiator). Feasibility TBD; the runtime gate ships regardless.
  - **Scope note**: extends to other position/enum-vs-plot-type constraints if more surface during verification (e.g. `crossBetween` only on `valAx`). Keep it to `dLblPos` first.
  - **Shipped (runtime gate)**: `Chart::validate(self) -> Chart raise ChartError` + non-raising `Chart::is_consistent(self) -> Bool` in `src/chart/chart_validation.mbt`, alongside D7's data-shape `validate`. The plot-vs-position table is one private `valid_d_lbl_positions(plot)` — **exhaustive over `Plot`**, so a newly-added plot family that is not classified is a compile error. The authoritative rule is **MS-OI29500**: bar/column **clustered** allows `ctr`/`inBase`/`inEnd`/`outEnd`; **stacked**/`percentStacked` drop `outEnd`; **line/scatter/radar** allow `ctr`/`l`/`r`/`t`/`b`; **pie**/`ofPie` allow `bestFit`/`ctr`/`inEnd`/`outEnd`; and **`area*` / `*3D` / `doughnut` / `stock` / `bubble` / `surface*` permit no explicit `<c:dLblPos>` at all** (empty allowed-set → any position present is rejected). `validate` walks both the plot-level `<c:dLblPos>` and each per-point `<c:dLbl>` override, raising `Malformed` naming the plot family + the offending position. **Simplification (documented)**: radar is treated leniently (the marker set) rather than special-casing filled-radar (which forbids any position), to avoid false positives. The compile-time per-family-position lift remains deferred (feasibility TBD). 7 new tests, additive `.mbti` (`Chart::validate` + `Chart::is_consistent`).

---

### 4.4.1 v0.6.0 — "Fidelity & fine-grained formatting"

DoD: every common per-shape / per-run / per-deck formatting knob that
PowerPoint exposes (and that python-pptx **or** PptxGenJS surfaces) has
a typed builder — no dropping to XML for everyday formatting. Surfaced
by a **2026-06-16 feature audit** (§11 changelog) against python-pptx +
PptxGenJS, in the same spirit as the v0.5.1 character-spacing lift
(issue #7): the items below all *round-trip losslessly today* via
`extension` (ADR-004) but have no typed surface, so a builder consumer
can't set them.

Status (2026-06-17): **Shipping as `0.5.2`** — F1 (rotation/flip), F2 (core
properties), F3 kerning + highlight + outline + effects, and F5 (shape
hyperlinks, AutoShape + Picture) all landed and are being released together
as **v0.5.2** (the work was scoped under "v0.6.0" but ships as a 0.5.x
feature release — every change was additive `.mbti`). **Remaining (carry
forward):** F3 non-solid text fill + F4 paragraph spacing — both *breaking*
ADT-widenings, batched into a deliberate pre-1.0 pass (§5); plus the F2
app.xml + F5 Group/GraphicFrame/Connector additive follow-ups (§5).
Priority order F1 → F2 → F3 → F4 → F5.

🟢 **F1 — Shape rotation & flip** *(landed 2026-06-16)*
  - **Gap (was)**: `@slide.Transform` modelled only `offset` + `extent`; worse than the audit assumed — `<a:xfrm>`'s own `rot`/`flipH`/`flipV` attributes were **silently dropped** on parse (the `<a:xfrm>` start-element attrs were never read), not even round-tripped via `extension`. python-pptx `shape.rotation`; PptxGenJS `rotate` / `flipH` / `flipV`.
  - **Shipped**: lifted to typed `Transform.rotation : @units.Angle?` + `flip_h : Bool` / `flip_v : Bool` (mirroring A7's `<p:bg>` / D3's `<p:transition>` lifts). `Transform::new(offset~, extent~, rotation?, flip_h?, flip_v?)` constructor (the existing struct-literal sites migrated to it) + `Transform::with_rotation` / `with_flip`. Parser reads `rot`/`flipH`/`flipV` off **all three** xfrm paths — `<p:sp>` (`parse_xfrm`), `<p:grpSp>` (`parse_group_xfrm`), and the graphicFrame `<p:xfrm>` (reuses `parse_xfrm`). Writer emits them via a shared `write_xfrm_orientation_attrs`, **omitting defaults** (`rot="0"` / unset flips) so unmodified shapes stay byte-identical.
  - Shape-level builders `AutoShape::with_rotation(Angle)` / `with_flip(h~, v~)` + the same on `Picture` and `GroupShape` (each maps over its `transform` Option — a no-op on an inheriting placeholder with no explicit xfrm). GraphicFrame parses/writes the attrs for losslessness but gets no convenience builder (PowerPoint ignores `rot` on chart/table frames — documented).
  - 8 new tests (parse rot/flipH/flipV; absent → unrotated/un-flipped; `Transform::new` + builder unit; AutoShape emit-attrs + default-omission + round-trip; Picture round-trip; GroupShape builder; graphicFrame `<p:xfrm>` lossless round-trip). Additive `.mbti` (+ the three `Transform` fields, like A7's `background` / D3's `transition`). 1072 → 1080 × 4 backends.

🟢 **F2 — Document core properties** *(landed 2026-06-16; app.xml company/application deferred)*
  - **Gap (was)**: `docProps/core.xml` was a fixed template with a hard-coded `<dc:creator>moon-pptx</dc:creator>`; no API to set title / author / subject / keywords / dates. python-pptx `prs.core_properties.{…}`; PptxGenJS `author` / `title` / `subject` / `company` / `revision`.
  - **Shipped**: typed `CoreProperties` over `docProps/core.xml` — the **full closed CT_CoreProperties set** (15 fields: `title` / `creator` / `subject` / `keywords` / `description` / `category` / `content_status` / `created` / `modified` / `last_printed` / `last_modified_by` / `revision` / `identifier` / `language` / `version`), all `String?`. Because CT_CoreProperties is an `<xsd:all>` of a fixed element set with **no extension wildcard**, modelling every field makes it lossless with no `extension` escape hatch. Fluent `with_*` builders (+ `with_author` alias for `creator`); `to_xml()` emits only `Some` fields with the `cp`/`dc`/`dcterms`/`xsi` prefixes (dates carry `xsi:type="dcterms:W3CDTF"`). `Presentation::core_properties()` reader (parses the part, empty if absent) + `set_core_properties_mut` (mutating, **replaces** the whole set) + `with_core_properties` (immutable, ADR-003). Read→edit→write (`prs.core_properties().with_title(…)`) preserves untouched fields. New `@oxml` namespace constants (`core_properties_ns` / `dublin_core_ns` / `dublin_core_terms_ns` / `xml_schema_instance_ns`). `src/presentation/core_properties.mbt`.
  - **Deviation from the sketch (documented like A6/C4)**: scoped to **core.xml**. `docProps/app.xml` `company` / `application` are **deferred to a follow-up** — app.xml is `CT_Properties`, an *ordered sequence* with many fields we don't model (Slides count, TitlesOfParts, …); a lossless edit of two fields needs an order-preserving, default-namespace-aware DOM round-trip (our `write_xml_element` re-prefixes the default namespace), a separate lift. core.xml alone is full python-pptx `core_properties` parity. The `_mut` naming matches the established setter convention (`set_notes_mut` / `set_slide_size_mut`), not the sketch's bare `set_core_properties`.
  - 9 new tests (blank-template read; set→read all-15 round-trip; read→edit→write preserves untouched + survives save→open; immutable `with_core_properties`; `with_author` alias; `to_xml` prefixes/`xsi:type`/None-omission; empty `new()`; XML-escaping round-trip). Additive `.mbti`. 1081 → 1089 × 4 backends.

🟡 **F3 — Run-level rich formatting (highlight / kerning / text outline / text fill / text effects)**
  - **Gap**: `RunProperties` covers size / bold / italic / underline / strike / caps / baseline / spc / colour(solid) / fonts / hyperlink, but these competitor-supported knobs are extension-only: `<a:highlight>` (PptxGenJS `highlight`), `kern` attribute (minimum kerning), `<a:ln>` text outline (PptxGenJS `outline`), non-solid text fill (gradient/pattern — `fill` is `@oxml.Color?`, narrower than the shape-level `@oxml.Fill` ADT), and `<a:effectLst>` text glow/shadow (PptxGenJS `glow` / `shadow`).
  - 🟢 **Slice 1 — kerning + highlight** *(landed 2026-06-16)*: typed `RunProperties.kerning : @units.Pt?` (the `kern` attribute, 1/100 pt non-negative, encoded exactly like `sz`/`spc`) + `RunProperties.highlight : @oxml.Color?` (`<a:highlight>`, reusing `parse_solid_fill` + `write_color` — the same lenient mechanism as the existing run `solidFill`). Builders `with_kerning(Pt)` / `with_highlight(RgbColor)`; writer emits `kern` among the attributes and `<a:highlight>` after the fill child per the CT_TextCharacterProperties sequence; both added to `needs_r_pr`. 6 new tests, additive `.mbti`. 1089 → 1095 × 4 backends.
  - 🟢 **Slice 2 — text outline (`<a:ln>`) + text effects (`<a:effectLst>`)** *(landed 2026-06-16)*: typed `RunProperties.outline : @oxml.Stroke?` (`<a:ln>`, reusing `@oxml.parse_stroke`/`write_stroke`) + `text_effects : @oxml.EffectList?` (`<a:effectLst>`, reusing `@oxml.parse_effect_list`/`write_effect_list`). Builders `with_text_outline(Stroke)` / `with_text_effects(EffectList)`; writer emits `<a:ln>` before the fill child and `<a:effectLst>` after it (sequence order). **Unblocked by making the `@oxml` shadow parsers lift-safe**: `parse_blur`/`parse_glow`/`parse_inner_shadow`/`parse_outer_shadow`/`parse_preset_shadow` now default the ECMA-376-optional coordinates (`blurRad`/`dist`/`rad`) and `dir` to 0 (new `emu_attr_or_zero` / `angle_attr_or_zero` helpers) instead of raising `require_*` — so a minimal `<a:outerShdw blurRad="…"/>` parses rather than failing the whole slide. Byte-identical for shapes that already carried the attrs (the writer always emits them); strictly enables previously-unparseable minimal forms. `parse_stroke` was already lenient; the shadow color child stays required (ECMA `EG_ColorChoice minOccurs=1`, as the shape path already enforced). 7 new tests (run outline/effects parse + round-trip; minimal-shadow lift-safety), 1 effect test updated (blur missing rad → 0), 2 ADR-004 tests updated for the lift. Additive `.mbti` (the two run fields); the `@oxml` change is internal. 1095 → 1100 × 4 backends.
  - 🔴 **Follow-up — non-solid text fill**: widen `fill : @oxml.Color?` toward the `@oxml.Fill` ADT (gradient/pattern), the breaking field-type change the doc-comment already flags as "a future expansion point".

🔴 **F4 — Paragraph spacing completeness**
  - **Gap**: `ParagraphProperties.line_spacing` models only the **percent** form (`<a:lnSpc><a:spcPct>`); the spec's absolute form (`<a:lnSpc><a:spcPts>`) is dropped to inheritance (the field doc-comment says "we only model the percent form"). `space_before` / `space_after` model only the **points** form (`<a:spcPts>`), not the percent form (`<a:spcPct>`).
  - Widen `line_spacing` to an ADT (`LineSpacing { Percent(Percentage) | Points(Pt) }`) and `space_before` / `space_after` likewise — so both forms round-trip and are settable. python-pptx `paragraph.line_spacing` accepts both a multiple and a Length; PptxGenJS `lineSpacing` / `lineSpacingMultiple`.

🟢 **F5 — Shape-level hyperlink / click action** *(landed 2026-06-17; AutoShape + Picture)*
  - **Gap (was)**: run-level hyperlinks shipped in A2, but a hyperlink/action on a **whole shape** (`<p:cNvPr><a:hlinkClick>`) was captured in the `<p:cNvPr>` extension only — no typed builder. python-pptx `shape.click_action.hyperlink`; PptxGenJS shape `hyperlink`.
  - **Shipped**: new typed `@slide.ShapeHyperlink { target, click, action }` (reuses A2's `HyperlinkTarget` — `ExternalUrl` / `InternalSlide`) on a build-only `hyperlink : ShapeHyperlink?` field added to `AutoShape` + `Picture`. Builders `with_hyperlink(url~)` / `with_hyperlink_to_slide(slide_idx~)` on both. **Resolution reuses A2's pipeline**: the `update_slide_mut` resolver (`resolve_hyperlinks.mbt`) now shares one `allocate_hyperlink(target) -> (rId, action)` between run and shape hyperlinks, walks each shape's own `hyperlink`, allocates the slide-rels rId (`rt_hyperlink` External URL / `rt_slide` + `action="ppaction://hlinksldjump"` jump), and clears the target. The writer threads the resolved `ShapeHyperlink` through `write_nv_wrapper` → `write_cnvpr`, which injects the `<a:hlinkClick>` as the first `<p:cNvPr>` child (CT_NonVisualDrawingProps order), replacing any captured one. **Build-only** (like A6 media): a parsed shape's `<a:hlinkClick>` still round-trips losslessly via the captured `<p:cNvPr>` in `extension` (ADR-004), so the parser leaves `hyperlink = None` — no parser change.
  - **Scope (documented)**: ships `AutoShape` + `Picture` (the shapes users hyperlink — buttons + clickable images). `GroupShape` / `GraphicFrame` / `Connector` hyperlinks pass `None` to the writer and still round-trip their parsed `<a:hlinkClick>` via `extension`; a typed builder for them is an additive follow-up. 6 new tests (external URL rel + `<a:hlinkClick>` rId on cNvPr; slide-jump `rt_slide` + ppaction; Picture hyperlink; save→reopen; no-hyperlink negative). Additive `.mbti` (`ShapeHyperlink` + the two fields + four builders). 1100 → 1105 × 4 backends.

**Deferred / open-ideas (logged in §5, lower demand — all round-trip losslessly today):** WordArt preset text warp (`<a:prstTxWarp>`), 3-D shape bevel (`<a:scene3d>` / `<a:sp3d>`), slide **sections** typed API (`<p:sldSectionLst>` — PptxGenJS `addSection`), table-style **preset library** (`<a:tblPr><a:tableStyleId>` — the field exists, no named presets), gradient/pattern **fill convenience constructors** (the `@oxml.Fill` ADT is buildable but verbose), and `<a:endParaRPr>` typed modelling (currently rides `Paragraph.extension`).

---

### 4.5 v1.0.0 — "Stable"

DoD: API surface frozen; LibreOffice + Keynote verified; benchmarks
published; xlsx cache generation as opt-in.

🔴 **API stability review**
  - Every `pub` declaration audited; mark experimental items in their doc-comment if any remain
  - `pkg.generated.mbti` diff vs v0.5 must be additive only (no breaking changes)

🔴 **B3 — Chart embedded xlsx cache generation** (long-tail)
  - Minimal SpreadsheetML writer (CT_Workbook + CT_Worksheet + CT_SharedStrings)
  - `Chart::of_bar(data, embed_xlsx~ = true)` etc.
  - Resolves the "degraded Edit Data UX" called out in ADR-009

🔴 **D5 — Streaming write for huge decks**
  - `Presentation::save_streaming(emit : (FixedArray[Byte]) -> Unit)` — incremental emission per part
  - Crucial for 1000+ slide decks generated server-side without materialising the whole `.pptx` in memory
  - Requires fzip's incremental write API (may need upstream PR)

🟡 **Verification matrix** (three-tier pyramid, ADR-011)
  - 🟢 **Tier 1 (in-repo, automated)** — `src/integration/integrity_test.mbt`: OPC structural-integrity invariants (content-type coverage, relationship-target resolution, `r:id` resolution) over builder/save output; runs on every backend in `moon test`
  - 🟡 **Tier 2 (CI, automated)** — `tools/pptx-validate/` Open XML SDK validator job over generated decks + `test_fixtures/corpus/`; ⏳ populate the corpus with license-clear real-world `.pptx` (Apache POI Apache-2.0 lead) and tune `baseline.txt` from the first run; ⏳ optional LibreOffice-headless second opinion
  - 🔴 **Tier 3 (release, manual)** — PowerPoint 2019 / 2021 / 365 / Online: open every example without warnings; LibreOffice Impress 7.x and 24.x render parity; Keynote (current macOS) render parity; document platform-specific quirks (e.g. SmartArt fallback paths)

🔴 **Benchmarks**
  - Throughput: slides/sec for build + save + parse on representative decks (10 / 100 / 1000 slides)
  - Memory: peak RSS for typical 100-slide deck
  - Comparison table vs python-pptx + PptxGenJS on the same fixtures

🔴 **CHANGELOG cleanup + 1.0 announcement**
  - Final release notes; blog post / mooncakes announcement

---

## 5. Open ideas (uncommitted)

Not on the dated roadmap yet — tracked here so they don't get lost:

- **Theme builder DSL** — `Theme::default().with_accent_palette([...])` for tweakable presets
- **Bullet-list typed parents** — enforce indent-depth at type level
- **`replace_slides` high-level helper** — convenience wrapping E1 (clear) + `add_slide_mut` (rebuild) so the common "keep the master/layout/theme, swap in my generated slides" flow is one call; could live in the library or stay a Skill-side recipe built on E1
- *(Slide reordering / duplication landed in v0.3.1 as **E2** / **E3** — see §4.2.1)*
- **Master / layout cloning + edit** — `SlideLayout::clone().with_…`
- **Equation editor** (Office Math, `<m:oMathPara>`) — read + write
- **Form fields / ink** (`<p:contentPart>`) — read + write
- **Compare two decks** — diff at the typed-model layer
- **PDF export** — separate companion crate (would consume moon-pptx + a rasterizer)
- **HTML export** — same
- **Trait-based shape extensibility** — `trait CustomShape`, third-party `Shape::User(...)` variants
- **Real-world fixture library** — license-clear small `.pptx` files for regression testing. *Infra landed 2026-06-20 (ADR-011): `test_fixtures/corpus/` + CI Open XML SDK validation; awaiting curated Apache-POI/self-authored files.*
- **Tier-1 reader-losslessness on real input** (ADR-011 follow-up) — embed a few real-world `.pptx` files' bytes as generated `.mbt` so a `moon test` (all backends) can assert `parse → serialise → parse` model-equality on real Office output, proving the *reader* drops nothing (the synthetic fixtures can't, and the external validator only proves the file is schema-valid, not that *we* preserved it). Needs a tiny binary→`.mbt` embed generator
- *(From the 2026-06-16 feature audit — deferred out of v0.6.0 F1–F5; all round-trip losslessly via `extension` today)*:
  - **Document app properties** (`docProps/app.xml` `company` / `application`) — the F2 follow-up. Needs an order-preserving, default-namespace-aware DOM round-trip of `CT_Properties` (a sequence with many unmodelled fields: Slides count, TitlesOfParts, HeadingPairs, …) so the two fields can be set without disturbing the rest; `write_xml_element` re-prefixes the default namespace, so a small dedicated app.xml editor is needed
  - **Run-level non-solid text fill** (the F3 follow-up) — widen `RunProperties.fill : @oxml.Color?` toward the `@oxml.Fill` ADT (gradient/pattern). **Breaking** field-type change (the project's first), so batch it with F4 into a deliberate pre-1.0 ADT-widening pass
  - **Paragraph spacing completeness** (F4) — `line_spacing` percent→ADT + absolute `<a:spcPts>`, `space_before`/`space_after` add the percent form. Same breaking ADT-widening nature as the F3 fill lift → batch the two together
  - **Shape hyperlinks on Group / GraphicFrame / Connector** (the F5 follow-up) — `with_hyperlink` for the remaining shape kinds (F5 shipped AutoShape + Picture). Their parsed `<a:hlinkClick>` already round-trips via `extension`; the typed field + writer threading extends additively
  - **Slide sections** (`<p:sldSectionLst>` in `presentation` extLst) — typed `Section { title, slide_ids }` + `add_section`; PptxGenJS `addSection`
  - **WordArt / preset text warp** (`<a:bodyPr><a:prstTxWarp>`) — typed warp presets
  - **3-D shape effects** (`<a:scene3d>` camera/light + `<a:sp3d>` bevel/extrusion) — typed builder
  - **Table-style preset library** — named `<a:tblPr><a:tableStyleId>` presets (the GUID field round-trips; no named-constant library yet)
  - **Gradient / pattern fill convenience constructors** — the `@oxml.Fill` ADT is buildable but verbose; add `Fill::linear_gradient(...)` / `Fill::pattern(...)` ergonomic builders
  - **`<a:endParaRPr>` typed modelling** — currently rides `Paragraph.extension`

---

## 6. Completed work (v0.1.0)

Phases 0–7 closed pre-publication. Per-slice detail lives in §10
(Living changelog).

| Phase | Scope | Status |
|---|---|---|
| 0 | Bootstrap, deps, CI | 🟢 |
| 1 | Units + XML foundations | 🟢 |
| 2 | OPC layer over fzip | 🟢 |
| 3 | Read path — theme / master / slide / text / fill+stroke+effect / notes / comments / custGeom + integration round-trip + lossless preservation (ADR-004) | 🟢 |
| 4 | Write path — writers for every modelled element + golden round-trip | 🟢 |
| 5 | Builder API — `Presentation::new`, `add_slide_mut`, `with_shape`, `add_picture_mut`, `add_chart_mut`, fluent text + shape styling, immutable variants | 🟢 |
| 6 | Tables — graphic-frame + table builders + cell properties + cell merging | 🟢 |
| 7 | Charts — 16 standard families + 9 extended chartEx, read / write / build all of them | 🟢 |
| **v0.1.0 release** | Pure-MoonBit publication to mooncakes.io as `t-ujiie-g/moon-pptx` | 🟢 |

Final v0.1.0 metrics: 795 tests × 4 backends, 100 % public-API doc
coverage, generated decks open in PowerPoint Online without repair.

---

## 7. Architecture decision records (ADRs)

Append-only. Each decision gets a heading, date, status, context, decision, consequences.

### ADR-001: Use `hustcer/fzip` for ZIP/DEFLATE
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: PPTX is a ZIP container. We need pure-MoonBit ZIP read/write.
- **Decision**: Depend on `hustcer/fzip`. Pure MoonBit, fflate-derived, 220+ tests, actively maintained, security-hardened. **Pinned at `0.8.2`** (bumped from the original `0.6.1` on 2026-06-16 — see §11).
- **Consequences**: Saves 1–3 months of self-implementing DEFLATE. Bound to fzip's API and maintenance cadence — acceptable since fzip is shipping multiple releases per week and the API surface we use is small (`zip_sync` / `unzip_sync` / `str_to_u8` / `str_from_u8` / `FzipError`). The narrow surface kept the 0.6→0.8 bump non-breaking (every new parameter is optional).

### ADR-002: Native primary; Wasm-GC + JS verified in CI; LLVM and legacy Wasm excluded
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: "MoonBit-only library" rules out reliance on a JS host. Native gives us file I/O directly; Wasm-GC enables browser embedding; JS is a useful escape hatch. LLVM is nightly-only (per `moonbit-orientation` skill); legacy Wasm is superseded by Wasm-GC.
- **Decision**: Develop and test against Native first. CI matrix runs `moon test` against `native`, `wasm-gc`, and `js`. Avoid backend-specific features without abstraction. Phase-0 smoke test confirmed all three targets pass.
- **Consequences**: All file I/O goes through `bytes`-level APIs at the public surface; convenience helpers (`Presentation::open_path`) live behind backend gates. Any feature that cannot be expressed cross-backend requires an ADR before adoption.

### ADR-003: Immutable builders over mutable setters
- **Date**: 2026-05-10
- **Status**: Accepted (anchored in v0.1.0)
- **Context**: python-pptx uses mutable attribute setters. MoonBit idioms favor immutability and explicit transformation.
- **Decision**: Builders return new values: `slide.with_shape(s)` not `slide.add_shape(s)`. Where mutation is necessary (e.g., editing existing decks), provide `_mut` variants explicitly.
- **Consequences**: Slightly more allocation; clearer dataflow; safer with concurrency. Honoured across `Presentation` (`with_added_slide` + `add_slide_mut`), `Slide::with_shape`, `AutoShape::with_*`, all of `@chart` builders.

### ADR-004: Lossless preservation of unknown XML
- **Date**: 2026-05-10 (accepted 2026-05-21, end of Phase 3f)
- **Status**: Accepted
- **Context**: OOXML has many extension elements (Office variants, third-party). Dropping unknowns silently corrupts files for users.
- **Decision**: Every parsed model node carries an `extension : Array[XmlElement]` capturing children we did not recognize. Writers emit them back verbatim.
- **Consequences**: Slightly heavier model; full round-trip safety even for incomplete coverage. Rolled out across `@theme` / `@slide_master` / `@slide` / `@oxml` / `@notes` / `@comments` plus the custGeom AST in Phase 3f → 3i. The only remaining lossy skips are spec-defined empty leaves where there's nothing to preserve.

### ADR-005: Sub-packages under `src/<name>/`
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: fzip uses a single flat package; pptx-svg uses sub-packages. Surface area for moon-pptx (units, xml, opc, oxml, theme, parts, shapes, text, fill, stroke, effect, geometry, chart, smartart, animation, presentation) is much larger than a leaf compression library — flat scope would muddle namespaces.
- **Decision**: Set `"source": "src"` in `moon.mod`. Each subdomain lives at `src/<name>/` with its own `moon.pkg`. Users import as `@<name>` (e.g. `@units`, `@xml`).
- **Consequences**: One `moon.pkg` per sub-package and one `pkg.generated.mbti` per sub-package. Cross-package imports are explicit. Refactoring boundaries between phases is now low-cost: adding/removing a package is a directory move.

### ADR-006: TODO.md as single source of truth; no separate planning docs
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: AI-driven development can scatter intent across many auxiliary docs (plans, designs, reviews). This rots quickly.
- **Decision**: All roadmap, scope, ADRs, open questions, and risk tracking live in `TODO.md`. Tool-agnostic contributor guidance lives in `AGENTS.md`; Claude-specific overlay in `CLAUDE.md`. New planning, decision, or analysis files are not created — append to `TODO.md` instead.
- **Consequences**: One file to keep current. PRs that change scope must update `TODO.md` in the same change.

### ADR-007: MoonBit official skills required for Claude Code workflow
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: Claude Code's behavior on MoonBit code improves dramatically when the official `moonbitlang/skills` plugin is loaded (orientation, agent-guide, refactoring, spec-test).
- **Decision**: Required Claude Code plugins are documented in `CLAUDE.md` and `AGENTS.md`. Contributors install via `/plugin` add marketplace `moonbitlang/skills` then install `moonbit-skills`.
- **Consequences**: Claude Code work without the plugin loaded is best-effort only. Contributors using other agents (Codex, OpenCode, Cursor) follow the install instructions in the upstream skills repo.

### ADR-008: XML reader is event-based; DOM is opt-in on top
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: OOXML files (especially slide masters, themes, and embedded chart XML) can be tens to hundreds of KB; a full DOM forces every parser to materialise the whole tree even when it only inspects a handful of elements. Event readers are also easier to make resilient against unknown elements (we can `skip_subtree` at any node).
- **Decision**: The `xml` package exposes a streaming `XmlReader::next() -> XmlEvent?` API with `StartElement` / `EndElement` / `Text` / `CData` events. Higher layers (OOXML AST in Phase 2+) build typed structures by consuming events. If a small DOM helper is needed for an element with many child kinds, build it locally on top of the event stream — never re-parse.
- **Consequences**: Parsers in higher layers carry more state machinery than DOM-based code, but stay memory-bounded and skip unknown subtrees cheaply. The `extension : Array[XmlElement]` lossless-preservation promise (ADR-004) is implemented by collecting events into a small ad-hoc DOM type at exactly the points where we need it.

### ADR-009: Defer embedded XLSX cache generation; preserve existing ones via OPC
- **Date**: 2026-05-25
- **Status**: Accepted
- **Context**: Real-world `.pptx` files emitted by Microsoft Office store chart data as a `<c:externalData r:id="…"/>` reference to an embedded `.xlsx` part (a complete SpreadsheetML package containing the chart's source rows and columns). PowerPoint's "Edit Data" button opens that xlsx in Excel. The ECMA-376 schema permits an alternative inline form (`<c:strLit>` / `<c:numLit>` directly inside `<c:cat>` / `<c:val>` / `<c:xVal>` / `<c:yVal>` / `<c:bubbleSize>`); both PowerPoint and LibreOffice render charts correctly from inline literals without an xlsx part.
- **Decision**: From-scratch chart builders (`Chart::of_bar` etc.) emit inline `<c:strLit>` / `<c:numLit>` data sources only. We do not generate xlsx caches in v0.1.0. Existing `<c:externalData>` references in parsed charts round-trip losslessly via `Chart.extension` (ADR-004); the referenced xlsx part rides through `@opc.Package` as an opaque part keyed by content type (no SpreadsheetML parsing). python-pptx (the de-facto Python PPTX library) takes the same approach for the same reasons.
- **Consequences**: Builder-produced charts render correctly in PowerPoint / LibreOffice but PowerPoint's "Edit Data" UX is slightly degraded. v1.0 reopens this as item **B3** with an opt-in `embed_xlsx~ = true` builder flag.

### ADR-010: SmartArt = own `src/smartart/` package, build-only, cached-drawing render guarantee
- **Date**: 2026-06-11
- **Status**: Accepted (anchored in v0.5 D1 slice 1)
- **Context**: A SmartArt graphic is the most multi-part construct in OOXML: a `<p:graphicFrame>` whose `<dgm:relIds>` references four DiagramML parts (data / layout / quickStyle / colors), and — to render without re-running PowerPoint's layout engine — a fifth cached `<dsp:drawing>` part holding the laid-out shapes. Authoring a full `<dgm:layoutDef>` *layout algorithm* per family is large and hard to verify outside PowerPoint; neither python-pptx nor PptxGenJS attempts SmartArt creation at all.
- **Decision**: (1) **New `src/smartart/` package** (ADR-005 sub-package model) owns the typed `SmartArt` / `Node` model and emits the five part byte-blobs; the OPC orchestration (`Presentation::add_smartart_mut`) lives at the presentation layer like charts / media / SVG. (2) **Cached drawing is the render contract** — we compute box positions ourselves and emit a complete `<dsp:drawing>`, so the diagram renders even where the layout engine isn't run (PowerPoint < 2010, thumbnails); the layout/colors/quickStyle parts are minimal valid definitions consulted only on *edit*. (3) **Reuse the `OtherGraphic` round-trip path** for the graphicFrame body rather than a typed `GraphicFrameContent::DiagramContent` — a parsed SmartArt already round-trips that way (ADR-004), so building the `<dgm:relIds>` by hand needs no parser/writer change. (4) **Build-only** (like A6 media / D2 animations): a parsed `<dgm:relIds>` + diagram parts round-trip losslessly via `extension` / opaque OPC parts; the typed `SmartArt` is a deliberately lossy *build* model, not lifted on parse. (5) **Sliced delivery** — slice 1 ships the linear `List` / `Process` families; hierarchical families layer on the same model + five-part pipeline additively.
- **Consequences**: SmartArt is creatable in moon-pptx — a feature neither competitor offers — with zero parser/writer churn and lossless round-trip preserved. Adding a family is a new `SmartArtKind` + its drawing layout + (optionally) a richer data-model shape — no new parts or relationship plumbing.
- **Status update (2026-06-16, PowerPoint Web verification)**: decision (2)'s premise is **wrong for PowerPoint Web** — it re-lays-out SmartArt from the `layoutDef` on open and does **not** use the cached `<dsp:drawing>`. So the cached drawing is *not* a universal render contract; it helps only non-editing/older viewers. With our single-level `layoutDef forEach`, the 5 flat families render fully but the 3 nesting families render top-level only. This does **not** supersede the package/round-trip/build-only decisions — only the "render guarantee" claim. The robust fix (future ADR if adopted) is a recursive hierarchy `layoutDef`, making the `layoutDef` — not the cached drawing — the primary render path.

### ADR-011: Three-tier verification pyramid; automate "opens without repair"
- **Date**: 2026-06-20
- **Status**: Accepted
- **Context**: "Generated decks open in PowerPoint without a repair prompt" is a core promise (§0), but until now it was only ever checked by a human opening a deck. Multiple real bugs were caught that way, **late** — `define_master` master/layout id collisions + shared-theme repair (2026-05-30), foreign-namespace prefix scoping producing a dangling `rId` on a two-media slide (2026-05-30), invalid chart `dLblPos` blanking a slide (2026-06-07), SmartArt nesting render (2026-06-16). The whole class of "PowerPoint repair" triggers is mechanically detectable — it is schema violations (element order, required attrs, value types), OPC integrity (missing content types, dangling relationship targets, unresolved `r:id`s), and reference breakage — none of which needs a running PowerPoint to find. The synthetic `src/integration/` fixtures (Q4) deliberately omit per-part `.rels` (parser-floor scaffolds, not valid OPC packages), so they cannot serve as the "no-repair" evidence base.
- **Decision**: Adopt a **three-tier verification pyramid**, automating the bottom two:
  - **Tier 1 — in-repo MoonBit (every `moon test`, all backends, FFI-free)**: a structural-integrity checker over assembled packages (`src/integration/integrity_test.mbt`) asserting the OPC-integrity invariants — content-type coverage, every Internal relationship target resolves to a real part, every `r:`-namespaced attribute (`r:id`/`r:embed`/`r:link`/`r:dm`/…) resolves to a declared relationship. Run over the library's own **builder/save output** (the product that must be repair-clean), not the rels-incomplete synthetic fixtures. Test-only helper; **not** a public `Presentation::validate()` API (keeps library scope narrow — validation/templating is downstream consumers' role, e.g. `pptz`).
  - **Tier 2 — external validators (CI job, not on the backend matrix)**: `tools/pptx-validate/` runs Microsoft's `OpenXmlValidator` (DocumentFormat.OpenXml) over generated decks + any real-world fixtures in `test_fixtures/corpus/`; a clean run is a high-confidence proxy for "no repair" because the SDK enforces the same schema+semantic constraints PowerPoint does. A short `baseline.txt` absorbs documented false positives (e.g. Microsoft extensions the SDK's typed model predates) — never genuine errors. LibreOffice-headless convert-to-pdf is an optional second opinion (future).
  - **Tier 3 — real apps (release / manual)**: open in PowerPoint 2019/2021/365/Online + LibreOffice Impress + Keynote at the v1.0 verification gate. Ground truth, too heavy for per-PR CI.
- **Consequences**: The two bug classes that historically required a human now fail CI on the PR that introduces them. The external validator is the first non-MoonBit toolchain in the repo (a small C#/.NET project, isolated under `tools/`, only on the `validate` CI job — does not touch the published library or its FFI-free guarantee). Real-world corpus files need license-clear sourcing (Apache POI's Apache-2.0 `.pptx` test data is the lead) and human curation, so the corpus directory ships with sourcing docs and is populated incrementally; the CI job validates whatever is present. A future Tier-1 follow-up — embedding a few real files' bytes as generated `.mbt` to prove the *reader* is lossless on real input across all backends — is logged in §5.

---

## 8. Open questions

Open:

| # | Question | Owner | Needed by |
|---|---|---|---|
| Q6 | How to expose backend differences (Native file I/O vs Wasm-GC byte-only) cleanly? | — | v0.2 polish (when adding `Presentation::open_path` / `save_path`) |
| Q8 | SmartArt: which DiagramML layouts ship in v0.5 first? (org-chart + hierarchy + cycle + process are top candidates) | — | v0.5 scoping |
| Q9 | Animation DSL: support custom motion paths via custGeom AST reuse in v0.5, or defer to v0.6? | — | v0.5 scoping |
Resolved:

- **Q7 (M1 compile-time placeholder schema: per-layout-type vs phantom param)** — resolved at M1 (2026-06-07): **hybrid**. One generic `LayoutSlide[L]` builder (accessors defined once, gated by capability traits `fn[L : HasTitle] …`) + ergonomic per-layout named constructors (`add_title_slide_mut` etc., no caller turbofish). A `/tmp` prototype confirmed phantom-param + capability-trait method-gating enforces at compile time in MoonBit; a bare phantom param trips `unused_type_variable` / `struct_never_constructed` under `--deny-warn`, so the marker is carried as a value field (`marker : L`) and capability traits are methods on it, with `pub impl`s so blackbox tests/consumers can dispatch them. See M1 (§4.3).
- **Q12 (E3 clone media-dedupe)** — resolved at E3 (2026-06-01): the clone *re-references* the source slide's parts (layout / images / charts / media / notes) rather than deep-copying them. Slide `.rels` is slide-local and both slides live in `/ppt/slides/`, so identical relative targets keep the copied slide XML's `rId` references valid, and shared parts stay alive via E1's reference-counted deletion. A fully-independent deep-copy variant is deferred until a consumer needs per-clone editing.

- **Q10 (D6 untouched-part detection)** — resolved at D6 (2026-05-29): neither hashing nor dirty-tracking is needed. The OPC layer retains each part's *source bytes* and only `_mut` operations replace them, so `save()` re-emits untouched parts verbatim by construction. See D6 (§4.2).
- **Q11 (B4 shape-edit identity handle)** — resolved at B4 (2026-05-29): id-based (`with_shape_by_id`) + `map_shapes` are primary; index helpers (`with_shape_at` / `with_shape_mapped` / `without_shape`) are thin conveniences. A missing id or out-of-range index raises `SlideError`; `map_shapes` is the non-raising best-effort path. Discovered+fixed the captured-`<p:cNvPr>` shadowing of typed `name`/`id` (see B4 writer-fix note).

- **Q1 (Native + Int64)** — resolved at Phase 1.1 (2026-05-10): `Emu = Int64` round-trips on `native` / `wasm-gc` / `wasm` / `js`.
- **Q2 (XML reader)** — resolved at Phase 1.3 (2026-05-10): self-implemented event-based reader (`src/xml/`) per ADR-008. No suitable mooncakes lib at the time.
- **Q3 (blank template shipping)** — resolved at Phase 5b2 (2026-05-23): no binary template ships; `Presentation::new()` assembles a blank deck programmatically from XML-literal templates plus the Phase 4 writers.
- **Q4 (real-world fixtures)** — resolved at Phase 3i (2026-05-21): synthetic-but-realistic fixtures in `src/integration/` cover the no-panic + round-trip floor without license concerns.
- **Q5 (Chart embedded XLSX)** — resolved at Phase 7 closure (2026-05-25): builders emit inline `<c:strLit>` / `<c:numLit>` data only; xlsx caches are preserved on round-trip but not generated. See ADR-009.

---

## 9. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| SmartArt + animation spec scope is huge — could blow up v0.5 | High | High | Ship subset first (4 SmartArt layouts; 10 animation effects); broaden in v0.6+ |
| SmartArt nesting families render top-level only in PowerPoint (re-lays-out from our single-level `layoutDef`, ignores the cached drawing) | Confirmed (2026-06-16) | Medium | Flat families render fully (use them in examples); add a recursive hierarchy `layoutDef` so org_chart / hierarchy / relationship lay out — until then they build + are recognised but draw only the top level |
| Compile-time placeholder schema (M1) explodes type-system complexity | Medium | High | Prototype in a branch first; ship behind explicit opt-in API (`add_slide_typed`) so legacy `add_slide_mut` stays available |
| MoonBit compiler / toolchain breaking changes | Medium | Medium | Pin moon version in CI; track changelogs via the `moonbit-orientation` skill |
| fzip breaking changes | Low | Low | Pin minor version; smoke test catches regressions early |
| PowerPoint vs LibreOffice vs Keynote rendering differences | Medium | Medium | v1.0 explicit verification matrix |
| API churn discourages early adopters | Medium | Medium | Mark experimental APIs in doc-comments; SemVer 0.x freely; freeze at 1.0 |
| Performance: large decks → slow build / save | Medium | High | v1.0 benchmarks + streaming write (D5) for the worst case |
| Browser bundle size for Wasm-GC | Low | Medium | Track post-v0.3 once chart sub-package is heaviest |

---

## 10. Workflow & conventions

### Development loop
```
moon check    # type check (fast)
moon test     # run all tests
moon fmt      # format
moon info     # regenerate pkg.generated.mbti
```

Run all four before committing. CI enforces them.

### Commit style
- Imperative subject line, ≤72 chars.
- Body explains *why*, not *what*.
- Reference the roadmap version or item when applicable: `v0.2 A1: add image-size auto-detect`.

### Testing
- Every public function has at least one test.
- Round-trip tests are mandatory at every layer (XML, OPC, OOXML, model).
- Synthetic-but-realistic fixtures live in `src/integration/`; real-world `.pptx` files live in `test_fixtures/` when licensed.

### Documentation
- Public APIs documented with `///` doc comments — coverage stays at 100 %.
- Examples in `examples/` are runnable and round-trip-tested.
- This TODO.md is updated *in the same PR* as scope changes.

### Release process (post-v0.1.0)
1. Land all items for the target version on `main`.
2. `moon fmt && moon check --deny-warn && moon test --target all && moon info` clean.
3. Update CHANGELOG.md with the new version section.
4. Bump `moon.mod` version.
5. Tag `v0.X.0` on `main`.
6. `moon publish` — confirms 202 Accepted (the trailing `Error: failed` line is benign for `--dry-run`).
7. Verify the new docs render on mooncakes.io.

---

## 11. Living changelog (high-level)

- **2026-06-20** — **Verification pyramid landed (ADR-011): automate "opens without repair".** Until now the core "no PowerPoint repair prompt" promise was only checked by a human opening a deck — and several bugs (define_master id collisions, dangling-`rId` from namespace-prefix scoping, invalid chart `dLblPos`) were caught that way, late. Now automated in two tiers. **Tier 1 (in-repo, all backends)**: `src/integration/integrity_test.mbt` — a structural-integrity checker over assembled packages asserting the OPC repair-trigger invariants (content-type coverage, every Internal relationship target resolves to a real part, every `r:`-namespaced attribute `r:id`/`r:embed`/`r:link`/`r:dm` resolves to a declared relationship), run over the library's **builder/save output** (minimal deck, a picture+chart deck where real `r:embed`/chart rels live, and an open→save→reopen round-trip). It is a test-only helper, **not** a public `Presentation::validate()` (keeps library scope narrow — validation/templating stays downstream, e.g. `pptz`). Writing it immediately surfaced that the synthetic `build_pptx` fixtures intentionally omit per-part `.rels` (so they're parser scaffolds, not valid OPC packages) — hence the tests assert on builder output, not fixtures. **Tier 2 (CI job)**: new `tools/pptx-validate/` — a small .NET project running Microsoft's `OpenXmlValidator` (the same schema+semantic checks PowerPoint runs on open) over the generated showcase deck + any files in `test_fixtures/corpus/`, with a commented `baseline.txt` for documented false positives; wired as a `validate` job in `.github/workflows/ci.yml` (generate deck → setup .NET → validate). `test_fixtures/corpus/` ships sourcing+licensing docs (Apache POI Apache-2.0 lead) for incremental real-world-file curation. **Tier 3** (real PowerPoint/LibreOffice/Keynote) stays the manual v1.0 release gate. 3 new MoonBit tests (1105 → 1108 × 4 backends); no library `.mbti` change (test-only + out-of-tree tooling). §4.5 verification matrix updated (Tier 1 🟢 / Tier 2 🟡 / Tier 3 🔴); §5 gains the corpus-infra note + a reader-losslessness follow-up. **Validated end-to-end against the local .NET 10 SDK (runtime roll-forward from the net8.0 build), which immediately earned its keep — see the BUG-MEDIA finding below.**
- **2026-06-20 — BUG (open, [issue #11](https://github.com/t-ujiie-g/moon-pptx/issues/11), found by the new validator): media `<a:videoFile>`/`<a:audioFile>` emitted as a direct child of `<p:pic>` instead of inside `<p:nvPr>`.** The Open XML SDK validator flagged `Sch_InvalidElementContentExpectingComplex` on every media slide of the showcase deck (slide16 audio+video, slide19 online video). Confirmed real (not a false positive) on freshly-generated output: `<p:nvPr/>` is emitted empty and `<a:videoFile r:link>` + the `<p:extLst><p14:media>` sit as siblings of `<p:pic>`, which `CT_Picture` does not permit (the media `EG_Media` group belongs in `CT_ApplicationNonVisualDrawingProps` = `<p:nvPr>`). **Root cause**: `Picture::of_media` sets a typed `media: Some` that *would* serialise correctly inside `<p:nvPr>`, but the build pipeline round-trips the slide through the parser, which captures `<a:videoFile>` into `extension` (media is build-only, not lifted on parse); on re-serialise `classify_shape_ext` (`src/slide/shape_writer.mbt:54`) matches `"audioFile"|"videoFile"` only under the `presentation_ns` guard, but those tags are in the **drawingml** namespace (`<a:videoFile>`), so they fall through to `ShapeExtBody` and are written as `<p:pic>` children. The previous "media reopens" regression test only checked our own parser round-trip, never schema validity — exactly the gap this validator closes. **Fix sketch**: classify drawingml-ns `videoFile`/`audioFile` as `ShapeExtNvPrChild`, and route the media `<p:extLst>` (the one carrying `<p14:media>`) into `<p:nvPr>` too (a plain body-level `<p:extLst>` must stay body-level, so distinguish by the `media_ext_uri`). Affects audio / video / online-video. One SDK false positive is separately baselined (SmartArt `DiagramDataPart→DiagramPersistLayoutPart` cached-drawing relationship — legitimate per MS-ODRAWXML).
- **2026-06-17** — **v0.6 F5 landed: shape-level hyperlinks (AutoShape + Picture).** A hyperlink / click action on a whole shape (`<p:cNvPr><a:hlinkClick>`), the run-level A2 builder's shape-level counterpart. New typed `@slide.ShapeHyperlink { target, click, action }` (reuses A2's `HyperlinkTarget`) on a build-only `hyperlink` field on `AutoShape` + `Picture`; builders `with_hyperlink(url~)` / `with_hyperlink_to_slide(slide_idx~)`. Resolution **shares A2's pipeline**: the `update_slide_mut` resolver extracts one `allocate_hyperlink(target) -> (rId, action)` used by both run and shape hyperlinks, walks each shape's own hyperlink, and registers the slide-rels rel (`rt_hyperlink` External / `rt_slide` + `ppaction://hlinksldjump` jump). The writer threads the resolved hyperlink through `write_nv_wrapper` → `write_cnvpr`, injecting `<a:hlinkClick>` as the first `<p:cNvPr>` child (replacing any captured one). Build-only (parsed shape hyperlinks round-trip via the captured `<p:cNvPr>` in `extension`, ADR-004 — no parser change). **Scoped to AutoShape + Picture**; Group/GraphicFrame/Connector still round-trip via `extension` (typed builder is an additive §5 follow-up). 6 new tests, additive `.mbti` (`ShapeHyperlink` + 2 fields + 4 builders). 1100 → 1105 × 4 backends. §3.3 row → ✅; §4.4.1 F5 → 🟢. **Closes the v0.5.2 feature set.**
- **2026-06-16** — **Dependency bump: `hustcer/fzip` 0.6.1 → 0.8.2.** The only runtime dependency, three minor versions stale (0.6.1 → 0.6.3 → 0.7.0 → 0.8.2). Despite the 0.x minor bumps (which SemVer permits to break), the upgrade was **non-breaking** for us: the entire API surface we use is `zip_sync` / `unzip_sync` / `str_to_u8` / `str_from_u8` / `FzipError`, and every new parameter 0.8.2 added (`opts?` / `latin1?` / `offset?` / `len?`) is optional, so our one-positional-arg call sites are unchanged. Verified by `moon check --deny-warn` + `moon test --target all` (1100 × 4 backends, all green — including the backend-sensitive zip/unzip round-trips). Updated `moon.mod` pin + ADR-001's version reference. (`examples/sample-deck` keeps the published-version dep until the next library publish.) No source or `.mbti` change.
- **2026-06-16** — **v0.6 F3 slice 2 landed: run-level text outline + text effects (+ lift-safe shadow parsers).** Two more typed `RunProperties` fields: `outline : @oxml.Stroke?` (`<a:ln>`, reusing `@oxml.parse_stroke`/`write_stroke`) and `text_effects : @oxml.EffectList?` (`<a:effectLst>`, reusing `@oxml.parse_effect_list`/`write_effect_list`), with builders `with_text_outline` / `with_text_effects`. The writer emits `<a:ln>` before the fill child and `<a:effectLst>` after it (CT_TextCharacterProperties order). **Unblocker**: the slice-1 deferral was that the shape-level shadow parsers `require_*` `blurRad`/`dist`/`dir` (raising when absent) though ECMA-376 defaults them to 0 — so a run's minimal `<a:outerShdw blurRad="…"/>` (which previously round-tripped via `extension`) would fail the whole slide once routed through the typed parser. Fixed by making `parse_blur`/`parse_glow`/`parse_inner_shadow`/`parse_outer_shadow`/`parse_preset_shadow` default those optional coordinates/angle to 0 (`emu_attr_or_zero`/`angle_attr_or_zero`) instead of raising; byte-identical for shapes that already carry the attrs (the writer always emits them), strictly enabling previously-unparseable minimal forms. The shadow **color** child stays required (ECMA `EG_ColorChoice minOccurs=1`, matching the existing shape path). 7 new run tests + 1 effect lift-safety test; 1 effect test + 2 ADR-004 tests updated for the lift. Additive `.mbti` (two run fields); `@oxml` change is internal. 1095 → 1100 × 4 backends. §3.3 outline/effects rows → ✅; only non-solid text fill remains in F3.
- **2026-06-16** — **v0.6 F3 slice 1 landed: run-level kerning + highlight.** Two new typed `RunProperties` fields lifted out of `extension`: `kerning : @units.Pt?` (the `kern` attribute — minimum kerning size, 1/100 pt, encoded exactly like `sz`/`spc`) and `highlight : @oxml.Color?` (`<a:highlight>`, reusing the run `solidFill` path `parse_solid_fill`/`write_color`). Builders `with_kerning` / `with_highlight`; the writer emits `kern` among the rPr attributes and `<a:highlight>` after the fill child (CT_TextCharacterProperties sequence order); both added to `needs_r_pr`. **Scoped to the two clean lifts**: text outline (`<a:ln>`) and text effects (`<a:effectLst>`) are deferred — they reuse the strict shape-level `@oxml.parse_stroke`/`parse_effect_list` (which raise when `OuterShadow`'s spec-optional `dist`/`dir`/`blurRad` are absent), so routing run effects through them would regress robustness on minimal-but-valid input that currently round-trips via `extension`; the lift waits on making those parsers default-instead-of-raise (a separate change). Non-solid text fill (the breaking `@oxml.Fill` widening) likewise deferred. 6 new tests, additive `.mbti`. 1089 → 1095 × 4 backends. §3.3 kerning/highlight rows → ✅; §4.4.1 F3 → 🟡.
- **2026-06-16** — **v0.6 F2 landed: document core properties.** Typed `CoreProperties` over `docProps/core.xml`, replacing the fixed `<dc:creator>moon-pptx</dc:creator>` template. Models the **full closed CT_CoreProperties set** (15 `String?` fields — title/creator/subject/keywords/description/category/contentStatus/created/modified/lastPrinted/lastModifiedBy/revision/identifier/language/version); since the schema is an `<xsd:all>` with no extension wildcard, modelling every field is fully lossless. Fluent `with_*` (+ `with_author` alias), `to_xml()` (emits only `Some` fields, `xsi:type="dcterms:W3CDTF"` on dates), `Presentation::core_properties()` reader + `set_core_properties_mut` (replaces the set) + immutable `with_core_properties`; the read→edit→write idiom (`prs.core_properties().with_title(…)`) preserves untouched fields. New `@oxml` namespace constants (cp/dc/dcterms/xsi). **Scoped to core.xml** = full python-pptx `core_properties` parity; `docProps/app.xml` company/application deferred (the ordered, partly-unmodelled CT_Properties needs a default-ns-aware DOM round-trip — logged in §5). `src/presentation/core_properties.mbt`. 9 new tests, additive `.mbti`. 1081 → 1089 × 4 backends. §3.6 matrix row → ✅; §4.4.1 F2 → 🟢.
- **2026-06-16** — **Whole-tree refactor sweep (CLAUDE.md §7).** Five-lens pass over the full source (not just the F1 area), prompted by a broad refactoring review. **One actionable finding (dedup)**: the `<a:off>` / `<a:ext>` / `<a:chOff>` / `<a:chExt>` EMU-leaf emission was copied across the three `<a:xfrm>` / `<p:xfrm>` writers (`write_xfrm`, `write_group_xfrm`, `write_pml_xfrm`) → extracted two shared `@slide` helpers `write_emu_point(w, local_name, Point)` / `write_emu_size(w, local_name, Size)`; all three writers now delegate. Byte-identical output (every golden round-trip test unchanged across 4 backends). The rest of the tree was already clean from prior sweeps: no TODO/FIXME markers, no `moon new` stub files, `--deny-warn` clean (no dead/unused code), domain constants centralised (`@units.ooxml_per_degree`, EMU factors; namespaces / content-types / rel-types named in `@oxml` / `@opc`), and the largest files (`parser.mbt` 1309 L, `chart/builders.mbt` 1197 L) are cohesive and were reviewed/left in earlier sweeps — no logical split worth the churn. Round-trip coverage is complete at every layer (1081 tests). No `.mbti` change (internal only); 1081 × 4 backends.
- **2026-06-16** — **Post-F1 refactor + doc sweep (CLAUDE.md §7).** Five-lens pass over the rotation/flip work. (1) **Dedup**: the three-line orientation-attribute decode (`rot`/`flipH`/`flipV`) was duplicated in `parse_xfrm` and `parse_group_xfrm` → extracted a shared `parse_xfrm_orientation(attrs) -> (Angle?, Bool, Bool)`, the single source for all three xfrm paths. The six per-type builder one-liners (`with_rotation`/`with_flip` × AutoShape/Picture/GroupShape) are idiomatic immutable builders (same shape as `with_fill`/`with_stroke`) — left as-is. (2) **Test adequacy**: the group-shape *writer* orientation path (`write_group_xfrm`) was only unit-tested (the builder test didn't serialise) → added a rotated-group serialize→reparse round-trip (asserts the emitted `rot`/`flipH` and the reparsed model). (3) **Docs**: README `@slide` sub-package row now lists shape rotation / flip (`with_rotation` / `with_flip`), matching how prior sweeps kept it current. Constants lens: no action — OOXML attribute names are inlined everywhere (cf. `parse_transition`'s `spd`/`advClick`), so extracting them would be inconsistent. File-split lens: no action (`parser.mbt` 1298 L is cohesive, reviewed in prior sweeps). No `.mbti` change (internal + test + doc only); 1080 → 1081 × 4 backends.
- **2026-06-16** — **v0.6 F1 landed: shape rotation & flip.** The first v0.6.0 fidelity item, the audit's highest-priority gap. `<a:xfrm>`'s `rot` / `flipH` / `flipV` were **silently dropped** on parse (the xfrm start-element attributes were never read — not even round-tripped via `extension`, contrary to the audit's assumption); now lifted to typed `@slide.Transform.rotation : @units.Angle?` + `flip_h` / `flip_v : Bool` (mirroring A7's `<p:bg>` / D3's `<p:transition>` lifts). New `Transform::new(offset~, extent~, rotation?, flip_h?, flip_v?)` (existing literal sites migrated to it) + `Transform::with_rotation` / `with_flip`, and shape-level `AutoShape` / `Picture` / `GroupShape` `with_rotation` / `with_flip` (each maps over its `transform` Option). Parser reads the attrs off all three xfrm paths (`<p:sp>` / `<p:grpSp>` / graphicFrame `<p:xfrm>`); writer emits via a shared `write_xfrm_orientation_attrs` that **omits defaults** so unmodified shapes stay byte-identical. GraphicFrame parses/writes for losslessness but has no convenience builder (PowerPoint ignores `rot` on chart/table frames). 8 new tests, additive `.mbti` (+ the three `Transform` fields). 1072 → 1080 × 4 backends. Matrix row §3.3 flips to ✅; §4.4.1 F1 → 🟢.
- **2026-06-16** — **Feature audit vs python-pptx + PptxGenJS → new v0.6.0 "Fidelity & fine-grained formatting" roadmap (§4.4.1).** A full pass over the public model (`RunProperties` / `ParagraphProperties` / `Transform` / `AutoShape` / `docProps`) against both reference libraries, prompted by the v0.5.1 character-spacing gap (issue #7) — looking for more knobs that competitors expose but moon-pptx only round-trips through `extension`. **Found six actionable gaps, none previously tracked as roadmap items**, all the same shape as the `spc` lift (lossless today, no typed surface): **F1 shape rotation/flip** (`Transform` has *no* `rot`/`flipH`/`flipV` — the highest-impact gap; python-pptx `shape.rotation`, PptxGenJS `rotate`/`flipH/V`), **F2 document core/app properties** (`docProps/core.xml` is a fixed template with a hard-coded `<dc:creator>moon-pptx</dc:creator>`; no `set_core_properties`), **F3 run-level highlight / kerning / text-outline / non-solid text-fill / text-effects** (all extension-only per the `RunProperties.extension` doc-comment), **F4 paragraph line-spacing absolute form + space %-form** (only percent line-spacing + point spacing modelled today), **F5 shape-level hyperlink / click action** (run-level shipped in A2; whole-shape `<a:hlinkClick>` is extension-only). Logged as v0.6.0 F1–F5 with priority order + DoD; lower-demand finds (slide sections, WordArt text warp, 3-D shape bevel, table-style presets, gradient/pattern fill convenience builders, `<a:endParaRPr>`) added to §5 open ideas; §3 feature matrix rows added/retargeted to match. Confirmed **not** gaps (already typed): shape shadow/glow/reflection/soft-edge effects (`@oxml.EffectList`), gradient/pattern/picture *shape* fills (`@oxml.Fill`), autofit, bullets/numbering, all 25 chart families. Docs-only change; no library `.mbti` change. **Current version stays 0.5.1.**
- **2026-06-16** — **v0.5.1: character spacing on text runs (issue #7).** `RunProperties::with_character_spacing(@units.Pt)` + a new `RunProperties.character_spacing : @units.Pt?` field map to the DrawingML `<a:rPr spc="…">` attribute (`ST_TextPoint` — 1/100 pt, may be negative to tighten). Parsed (`parse_character_spacing_attr`) and written exactly like `sz`/`font_size` (same encoding; `parse_signed_int` + the `*100` write already handle negatives), and added to `needs_r_pr`. Closes a downstream gap reported by `pptz` (a TOML→PPTX generator) whose `letter_spacing` style had no typed target. 5 new tests (parse 1/100-pt → Pt, negative tightening, absent = `None`/unchanged, parse→serialize→parse round-trip, builder emits `spc` + round-trips). Additive `.mbti` (new field + `with_character_spacing`, like prior `Slide.transition`/`background` field additions). 1067 → 1072 × 4 backends.
- **2026-06-16** — **PowerPoint verification of the v0.5 sample deck — SmartArt hierarchical-render finding.** Opening the generated deck in PowerPoint for the web surfaced that **PowerPoint re-lays-out SmartArt from the layout definition on open and does *not* use our cached `<dsp:drawing>`** — contrary to ADR-010's "cached drawing is the render contract" assumption (which holds, at best, only for non-editing/older viewers, not PowerPoint Web). Consequence: our `layoutDef`'s `forEach axis="ch" ptType="node"` walks only the document's direct children (one level), so the **flat** families (list / process / cycle / pyramid / matrix — all nodes depth-1) render every node, but the **nesting** families (org_chart / hierarchy / relationship) collapse to their top-level node(s) — the data model is correct and recognised as SmartArt (the text pane shows the full hierarchy), but children don't render. **Corrected the over-claim**: §3.6 / §3.7 / the D1 notes now distinguish "build + render (flat)" from "build + recognised, top-level render only (nesting, pending a recursive layoutDef)". Examples switched to a flat family so the showcase renders correctly (sample-deck slide 17 → `cycle`; cookbook §15 → `process` + a rendering note). **Follow-up (logged as D1 risk)**: a recursive hierarchy `layoutDef` (`hierRoot`/`hierChild` composite with a nested `forEach`) so PowerPoint lays nesting families out — the robust fix, independent of whether the cached drawing is ever honoured. *(Online video slide 19 shows its poster image, not a player — that is PowerPoint **Web**'s media limitation, same as the embedded-media slide; the markup is the correct online-video form and plays in desktop PowerPoint.)* Examples + docs only; no library `.mbti` change.
- **2026-06-16** — **Examples updated for the v0.5 release (cookbook + sample deck).** So every v0.5 feature is demonstrable/verifiable: (1) **Cookbook** (`examples/README.md`) gains four recipes — §14 animations (`Timeline` + `with_animations`), §15 SmartArt (`add_smartart_mut`), §16 YouTube / online video (`add_youtube_video_mut` / `add_online_video_mut`), §17 plot-type-aware chart validation (`Chart::validate`) — each mirrored by a matching test in `src/integration/examples_test.mbt` (1063 → 1067). (2) **Sample deck** (`examples/sample-deck`) grows from 20 to 23 slides with SmartArt org-chart, animation, and online-video slides (+ the split-mode isolation cases); its `moon.mod.json` dep is switched from the published `0.4.0` to a `{ "path": "../.." }` path dep so the deck builds against the unreleased v0.5 source (the in-repo dev pattern — switches back to `"0.5.0"` post-publication). Generates a valid 23-slide `.pptx` that round-trips on reopen (sample-deck tests green). README slide-count / feature references freshened. No library `.mbti` change.
- **2026-06-12** — **Post-D1 refactor + doc sweep (CLAUDE.md §7).** Five-lens pass over the `smartart` package. (1) **Constants / dedup**: the per-kind `(layout uniqueId, category)` mapping lived twice — `data_writer.doc_prset_ids` (the doc point's gallery hints) and `static_parts.layout_meta` (the layout part's id) — now a single `kind_layout_id` in a new `common.mbt`, so they can't drift; the `urn:…/layout/` prefix and the built-in quickStyle (`simple1`) / colors (`accent1_2`) uniqueIds + categories (each previously written 2×) are now named constants; the text-run emitter (`<a:r>`/`<a:endParaRPr>`) duplicated between the data model's `<dgm:t>` and the drawing's `<dsp:txBody>` is one shared `write_run_or_endpara`. All output byte-equivalent (the substring/well-formed tests are unchanged). (2) **Test adequacy**: added an `add_smartart_mut` out-of-range `slide_idx` test (parity with the other `add_*_mut`). (3) **Docs**: README sub-package table gains a `@smartart` row and the `@presentation` row now lists online-video + SmartArt insertion; §3.7 "where moon-pptx wins" gains a SmartArt-creation point. File-split / dead-code lenses found nothing actionable (all `smartart` files < 370 L, cohesive). No `.mbti` change (internal + test + doc only); 1062 → 1063 × 4 backends.
- **2026-06-12** — **v0.5 D1 complete: SmartArt matrix + relationship families (all eight families ship). v0.5.0 feature-complete.** `SmartArt::matrix(items)` lays items in a roughly-square grid (cols = ⌈√n⌉; four → 2×2) — a flat family reusing the slice-1 data model + a grid case in `layout_boxes`. `SmartArt::relationship(center, related)` is hub-and-spoke: the hub is the root and `related` its children (spokes), reusing the slice-3 tree data model; a new `radial_layout` centres the hub and rings the spokes. Both add a `doc_prset_ids` + `layout_meta` row (`matrix1` / `radial1`). With this, **all eight roadmap SmartArt families build** (list / process / cycle / pyramid / org-chart / hierarchy / matrix / relationship) — a feature no other PPTX library offers. Documented additive follow-ups: parent→child connector lines in the cached drawing, per-node styling, sample-deck PowerPoint verification. 4 new tests; additive `.mbti`. 1060 → 1062 × 4 backends. **This was the last open v0.5.0 item — the cycle is feature-complete (D2 / D8 / C5 / D1 all landed).**
- **2026-06-12** — **v0.5 D1 slice 3 landed: SmartArt org-chart + hierarchy (first hierarchical families).** `SmartArt::org_chart(root : Node)` (single-root tree) and `SmartArt::hierarchy(nodes)` (forest) consume `Node.children`. New `tree.mbt` `flatten` pre-order-walks the forest into `FlatNode`s (gidx / parent / sibling-order / depth / children), and **the data writer is generalised over it**: every node becomes a `<dgm:pt>` and every node's incoming edge a `parOf` `<dgm:cxn>` whose `srcId` is its parent node (or the doc root for a top-level node). A flat family is a depth-1 tree, so the generalised writer stays *byte-equivalent* on List/Process/Cycle/Pyramid (their tests are unchanged). The cached `<dsp:drawing>` gets a tidy tree layout (`tree_layout`): leaves take successive horizontal slots, each parent is centred over the average of its children's slots, depth → vertical level. **Deviation (documented)**: the cached drawing is boxes-only — parent→child **connector lines** aren't emitted yet (the hierarchy is fully in the data model; PowerPoint draws connectors on its first re-layout/edit). 3 new tests (org-chart parent/child cxns + all four nodes drawn, hierarchy forest = two doc edges, presentation end-to-end + reopen). Additive `.mbti`. 1057 → 1060 × 4 backends. **Remaining D1**: `Matrix` (2×2) + `Relationship` families.
- **2026-06-11** — **v0.5 D1 slice 2 landed: SmartArt cycle + pyramid families.** Two more *flat* families on the slice-1 five-part pipeline: `SmartArt::cycle(items)` (boxes evenly around a ring, positions via `@math.sin`/`cos`) and `SmartArt::pyramid(items)` (centred bands widening apex→base). The DiagramML data model is byte-for-byte the slice-1 flat structure (`doc_prset_ids` just adds the `cycle1` / `pyramid1` built-in layout ids); `layout_xml` swaps the root `<dgm:alg>` (`cycle` / `pyra` vs slice-1 `lin`); only the cached `<dsp:drawing>` layout is new (radial / stacked). Because `SmartArtKind` is matched exhaustively in `layout_meta` / `layout_boxes` / `doc_prset_ids`, adding a flat family is a compiler-guided three-spot change. 5 new tests (builders + alg type, N-box drawings + well-formed, end-to-end wire + reopen for both). Additive `.mbti`. 1054 → 1057 × 4 backends. **Remaining D1**: hierarchical families (org-chart / hierarchy / matrix / relationship) — need `Node.children` emitted as parent/child connections + a tree/grid drawing layout.
- **2026-06-11** — **v0.5 D1 slice 1 landed: SmartArt builder ⭐ (linear families).** SmartArt — creatable in *no* other PPTX library — lands its first slice: a new `src/smartart/` package + `Presentation::add_smartart_mut(slide_idx, smartart, x, y, cx, cy)`. `SmartArt::list(items)` / `process(items)` build a flat box-per-string diagram (general `SmartArt::new` + `Node::leaf`/`new` carry children for the future hierarchical layouts). `add_smartart_mut` synthesises the **five** DiagramML parts and wires them: the slide references `/ppt/diagrams/{data,layout,quickStyle,colors}N.xml` via a `<dgm:relIds r:dm/r:lo/r:qs/r:cs>` inside a `<p:graphicFrame>`, and the data part references `/ppt/drawings/drawingN.xml` (the cached `<dsp:drawing>`) from its own `.rels`, recorded via `<dsp:dataModelExt relId=…>`. The cached drawing holds boxes we lay out ourselves (List top-to-bottom, Process left-to-right within the frame extent) so the diagram renders without a layout engine — the roadmap's "cached graphic-frame fallback". Data + drawing parts use `@xml.XmlWriter` (escaping); layout/colors/quickStyle are template strings (like the blank deck). **Deviations (ADR-010, documented like A6/C4/D2)**: presentation-level `add_smartart_mut` (not `Slide::with_smartart`); reuses the `OtherGraphic` round-trip path for the graphicFrame body (no typed `DiagramContent`, no parser/writer change — exactly how a parsed SmartArt round-trips per ADR-004); build-only (parsed SmartArt round-trips via `extension`); slice 1 = flat linear, children preserved-but-not-emitted; live-PowerPoint verification deferred to the sample-deck pass (verified here by save→reopen + XML well-formedness of all five parts × 4 backends). New constants (`@oxml.ct_diagram_*` / `diagram_ns` / `diagram_drawing_ns` / `diagram_data_model_ext_uri`, `@opc.rt_diagram_*`) + `PptxError::SmartArtFailure`. 13 new tests, additive `.mbti`. 1040 → 1054 × 4 backends. **Remaining D1**: hierarchical families (org-chart / hierarchy / cycle / pyramid / matrix / relationship).
- **2026-06-11** — **v0.5 C5 landed: YouTube / URL video embed.** `Presentation::add_online_video_mut(slide_idx, video_url, poster_bytes, x, y, cx, cy)` embeds any web/streaming video URL; `add_youtube_video_mut(...)` normalises a YouTube `watch?v=` / `youtu.be/` / `/embed/` / `/shorts/` link to the embeddable `https://www.youtube.com/embed/<id>` form first (private `youtube_embed_url`). An online video is the *same* `<p:pic>` as an embedded clip (reuses A6's `Picture::of_media`, `Video` kind, `<a:videoFile r:link>` + `<p14:media r:embed>`), but both media relationships are `TargetMode=External` pointing at the URL, so **no `/ppt/media/mediaN.*` part** is created — only the poster image part + its Internal `rt_image` rel. `src/presentation/add_online_video.mbt`. **Deviations (documented like A6/C4)**: entry point is a presentation-level `add_online_video_mut` (not `Slide::with_youtube_video` — OPC part management lives at the presentation layer, as for C4 SVG / A6 media); the preview frame is caller-supplied (required `poster_bytes`, gated through `detect_image_format`) — no built-in thumbnailer / network fetch (out of scope per §0); an unrecognised YouTube URL raises `Malformed`. 6 new tests, additive `.mbti` (`add_online_video_mut` + `add_youtube_video_mut`). 1034 → 1040 × 4 backends. **v0.5.0 now has only D1 (SmartArt) left.**
- **2026-06-09** — **Post-D2/D8 refactor + doc sweep (CLAUDE.md §7).** Five-lens pass over the freshly-landed animation + chart-validation work. (1) **Constants**: `animation_writer.mbt` emitted `<p:animRot by="…">` with a raw `60000`, duplicating the existing `@units.ooxml_per_degree` domain constant — now reused (so the angle factor lives in one place); the two remaining animation-domain magic numbers were named — `anim_scale_per_percent` (1000ths-of-a-percent for `<p:animScale><p:by>`) and `anim_time_end` (`<p:tav tm>` normalised end `100000`). (2) **Test adequacy**: `AnimDirection::to_filter` / `AnimOrientation::to_filter` were public but only covered indirectly via `VisualEffect::filter` — added a direct test (§7.4). (3) **Docs**: the README `@slide` row now lists animations (`with_animations` / `Timeline`) and the `@chart` row lists the plot-type-aware `Chart::validate` (D8) alongside `ChartData::validate`. Dead-code / file-split / duplicate lenses found nothing actionable (`animation.mbt` 462 L and `animation_writer.mbt` 486 L are cohesive and under the ~500 smell line; the slide/chart substring test helpers are cross-package and not shareable in MoonBit). No `.mbti` change (internal + test + doc only); 1034 → 1035 × 4 backends.
- **2026-06-09** — **v0.5 D2 complete: fly-in + by-paragraph text builds ⭐ (D2 done).** Two final slices close the animation DSL. **Slice 4 (fly in / out)**: `VisualEffect::FlyIn(AnimDirection)` in the shared entrance/exit enum — `Entrance(FlyIn(Left))` flies in from the left, `Exit(FlyIn(Down))` flies out downward. It emits a positional `<p:anim>` on `ppt_x`/`ppt_y` with a `<p:tavLst>` between an off-slide value (`0-#ppt_w/2` etc., per PowerPoint's fly convention) and the shape's home (`#ppt_x`), paired with the visibility set; new `fly_direction` classifier (orthogonal to `filter`). **Slice 5 (text builds)**: an effect can target one paragraph via the optional `paragraph?` arg on `on_click`/`with_previous`/`after_previous` (`AnimStep.paragraph`) — the `<p:spTgt>` carries `<p:txEl><p:pRg>` and the shape is declared a by-paragraph build with `<p:bldP build="p">` in a `<p:bldLst>`, each shape getting a build-group id shared between its paragraph effects' `grpId` and its `<p:bldP>` (whole-shape effects stay in group 0). **Typed parsing of `<p:timing>` is intentionally not implemented** — `Timeline` is a deliberately lossy build model and the lossless read path is `extension` (ADR-004); the build-only design is the right boundary. D2 now emits a full canonical `<p:timing>` for all four effect classes + fly-in + text builds, meeting the DoD. 7 new tests, additive `.mbti` (`FlyIn` variant, `fly_direction`, `AnimStep.paragraph` + the optional builder arg). 1027 → 1034 × 4 backends.
- **2026-06-09** — **v0.5 D2 slice 3 landed: motion-path animations ⭐.** `AnimEffect::Motion(MotionPath)` — a custom route a shape travels along (`<p:animMotion>`). `MotionPath::new().move_to / line_to / curve_to / close` (immutable, ADR-003) builds an ordered `MotionCommand` list in `0..1` slide-fraction `MotionPoint`s; `MotionPath::line(dx, dy)` is the one-segment convenience; `to_path_string` renders the path mini-language (`M`/`L`/`C`/`Z`, ending with the `E` marker PowerPoint always appends). The writer emits `presetClass="path"` + `<p:animMotion origin="layout" pathEditMode="relative">` with `ppt_x`/`ppt_y` in the `<p:attrNameLst>`. **Deviation from the roadmap sketch** (documented like D4/C4): the roadmap suggested reusing Phase 3h's `CustomGeometry::PathCommand`, but its `PathPoint` carries EMU / guide coordinates (`<a:path>` shape space) while `<p:animMotion>` uses `0..1` slide fractions — a different coordinate space, so a dedicated fractional `MotionPath` keeps each model in its own units. Same build-only deviation as slices 1–2 (re-serialises stably via `extension`). 4 new tests, additive `.mbti` (`MotionPath` / `MotionPoint` / `MotionCommand` + the `Motion` variant). 1023 → 1027 × 4 backends. **Remaining D2 (slice 4+)**: Fly-In positional `<p:anim>`, per-paragraph text builds, typed `<p:timing>` parsing.
- **2026-06-09** — **v0.5 D2 slice 2 landed: emphasis animations ⭐.** Completes the `Entrance / Emphasis / Exit` triad. `AnimEffect::Emphasis(EmphasisEffect)` over `EmphasisEffect { Spin(degrees) | GrowShrink(percent) | ChangeFillColor(@units.RgbColor) }` — in-place effects on an already-visible shape, so no `<p:set>` visibility toggle. The writer (`animation_writer.mbt`) emits `presetClass="emph"` + the dedicated DrawingML behaviour: Spin → `<p:animRot by="degrees*60000">` on the `r` attribute, GrowShrink → `<p:animScale>` with `<p:by x/y>` in 1000ths of a percent, ChangeFillColor → `<p:animClr clrSpc="rgb">` with `<p:to><a:srgbClr>` (the colour rides the drawing namespace, auto-declared by `write_xml_element`). `EmphasisEffect::preset_id` is exhaustive (a new emphasis without metadata is a compile error). Same build-only deviation as slice 1 (round-trips stably via `extension`). 5 new tests, additive `.mbti` (`EmphasisEffect` + the `Emphasis` variant). 1018 → 1023 × 4 backends. **Remaining D2 (slice 3+)**: motion paths, Fly-In positional `<p:anim>`, text builds, typed `<p:timing>` parsing.
- **2026-06-09** — **v0.5 D2 slice 1 landed: animation DSL (entrance + exit) ⭐.** `<p:timing>` — one of the deepest, most boilerplate-heavy parts of the format — lifts from `Slide.extension` into a typed `Slide.timing : Timeline?` (mirroring D3's `<p:transition>` lift) with `Slide::with_animations` / `without_animations` builders. `Timeline::new().on_click(eff, shape_id) / .with_previous(...) / .after_previous(...)` builds an ordered step list (`src/slide/animation.mbt`); `animation_writer.mbt` synthesises the full canonical click-driven main sequence (tmRoot → seq → mainSeq → per-group `<p:par>` → per-effect `<p:set>`/`<p:animEffect>` behaviours) as an `@xml.XmlElement` DOM through `@oxml.write_xml_element`. `AnimEffect { Entrance(VisualEffect) | Exit(VisualEffect) }` over one shared `VisualEffect { Appear | Fade | Wipe(dir) | Blinds(orient) | RandomBars(orient) | Dissolve | Wedge | Wheel(spokes) }` — entrance plays the DrawingML `<p:animEffect>` filter `in` and reveals the shape via a `<p:set>` on `style.visibility`; exit plays it `out` and hides it. `VisualEffect::preset_id` / `filter` are exhaustive (a new effect without metadata is a compile error). Start modes map to the standard `clickEffect` / `afterEffect` / `withEffect` node types. **Deviations (documented like A6/A7/C4/D3)**: build-only (like A6 media) — emitted by the writer, but a parsed `<p:timing>` still round-trips losslessly via `extension` and `timing` stays `None` (so a built timeline re-serialises *stably*, not to an equal model); `with_animations` strips a captured `<p:timing>` so the writer never double-emits; `presetSubtype="0"` (cosmetic, filter-driven render); no `<p:bldLst>` yet. **Deferred to slice 2+ (additive)**: emphasis, motion paths (reusing `CustomGeometry::PathCommand`), Fly-In positional `<p:anim>`, per-paragraph text builds, and typed *parsing* of `<p:timing>` into `Timeline`. 12 new tests, additive `.mbti` (+ the `Slide.timing` field, like D3's `transition`). 1006 → 1018 × 4 backends.
- **2026-06-09** — **v0.5 D8 landed: plot-type-aware chart-option validation (runtime gate).** `Chart::validate(self) -> Chart raise ChartError` + non-raising `Chart::is_consistent(self) -> Bool` (`src/chart/chart_validation.mbt`, alongside D7's data-shape gate) catch a `<c:dLblPos>` that PowerPoint would reject *before* it reaches PowerPoint's repair pass — the issue surfaced verifying the v0.4 sample deck (`DataLabels(DLblOutEnd)` via M2 is valid on a `barChart` but **not** a `lineChart`). The plot-vs-position table is one private `valid_d_lbl_positions(plot)`, **exhaustive over `Plot`** (a new plot family that isn't classified is a compile error), encoding the authoritative **MS-OI29500** rule: bar/column **clustered** → `ctr`/`inBase`/`inEnd`/`outEnd`, **stacked**/`percentStacked` drop `outEnd`, **line/scatter/radar** → `ctr`/`l`/`r`/`t`/`b`, **pie**/`ofPie` → `bestFit`/`ctr`/`inEnd`/`outEnd`, and **`area*` / `*3D` / `doughnut` / `stock` / `bubble` / `surface*` permit no explicit position at all** (empty set → any present position rejected). `validate` walks both the plot-level `<c:dLblPos>` and each per-point `<c:dLbl>` override, raising `Malformed` naming the plot family + offending position. **Simplification (documented)**: radar is treated leniently (marker set) rather than special-casing filled-radar, to avoid false positives; the **compile-time** per-family-position lift stays deferred (feasibility TBD). Validation is opt-in at the build boundary (like D7), so arbitrary parsed decks still round-trip untouched. 7 new tests, additive `.mbti` (`Chart::validate` + `Chart::is_consistent`). **First v0.5.0 item landed.**
- **2026-06-07** — **Fixes from PowerPoint verification of the sample deck.** Opening the v0.4 sample deck in PowerPoint surfaced a repair prompt + a blank slide 13. Two causes: (1) **deck example** — the combo-chart slide applied `DataLabels(DLblOutEnd)` via M2, but `outEnd` is invalid on a `lineChart` (line labels only allow `ctr`/`l`/`r`/`t`/`b`), so PowerPoint repaired the chart and blanked the slide; changed the demo to `DLblCenter` (valid for both bar and line). (2) **M1 library bug** — `ensure_layout_of_type` picked the target master via "first slide-master in package order", but `replace_part_bytes` (remove + re-add) reorders parts, so after attaching one synthesised layout the *next* call drifted to a different master — splitting the two typed layouts across masters. Fixed by selecting the main master by lowest `slideMasterN` index (stable under reordering). Regression test added (define_master + two typed layouts → both land on the main master). No `.mbti` change; 998 → 999 × 4 backends.
- **2026-06-07** — **v0.4 M1 landed: compile-time placeholder schema (⭐ headline).** Typed layout handle `LayoutSlide[L]` + per-layout named constructors (`Presentation::add_title_slide_mut` / `add_title_content_slide_mut` / `add_section_header_slide_mut` / `add_title_only_slide_mut` / `add_blank_typed_slide_mut`). Placeholder accessors `title` / `subtitle` / `body` are gated by capability traits (`HasTitle` / `HasSubtitle` / `HasBody`), so accessing a placeholder the layout doesn't have is a **compile error** — the differentiator no other PPTX library offers. `finish_mut()` commits; legacy `add_slide_mut(layout_index)` unchanged. **Q7 resolved (hybrid)**: one generic builder (accessors once, trait-gated) + ergonomic named constructors; the marker is carried as a value field (`marker : L`) rather than a bare phantom, which would trip `unused_type_variable` / `struct_never_constructed` under `--deny-warn`; `pub impl`s make the capability impls visible to blackbox tests/consumers. **Layout binding (i)**: each constructor calls `ensure_layout_of_type`, which resolves an existing `<p:sldLayout type=…>` or synthesises one (declaring its placeholders, wiring it into the first master's `<p:sldLayoutIdLst>` + rels + content types via the reused `define_master` cSld synthesis), idempotently. Built on a new `@slide.Slide::with_placeholder(kind, idx, text?)` primitive. Ships TitleSlide / TitleAndContent / SectionHeader / TitleOnly / Blank; multi-body/caption layouts are an additive follow-up. 18 new tests, 975 → 993 × 4 backends; additive `.mbti`. **All v0.4.0 items now landed.**
- **2026-06-07** — **v0.4 refactor + doc sweep (CLAUDE.md §7).** Post-D3/M2/D4/D7 cleanup across the five lenses. (1) Constants: the `<p:wheel spokes>` schema default `4` was a magic number duplicated in the transition parser (`unwrap_or(4)`) and writer (`!= 4`); promoted to a single `transition_default_spokes` constant so the read/write defaults can't drift. (2) Dedup: `chart_validation.mbt`'s `validate` / `is_consistent` shared a per-type length-check predicate — extracted one private `first_misaligned_series` per `ChartData` / `ScatterData` / `BubbleData` as the single source of truth (the two public methods now consume it). (3) Tests: added a direct `from_xml ∘ to_xml` identity test covering every value of the six transition direction/speed enums (previously only exercised indirectly via round-trip). (4) Docs: freshened the README sub-package table — `@slide` now lists typed transitions + the `Picture::builder` pipeline, `@chart` lists `with_options` + `ChartData::validate`. No `.mbti` change (internal/test/doc only); 982 → 983 × 4 backends.
- **2026-06-07** — **v0.4 D7 landed: chart-data validation (runtime gate).** `ChartData::validate(self) -> ChartData raise ChartError` checks every series has one value per category and returns `self` for fluent composition (`Chart::of_bar(data.validate())`), raising `Malformed` (naming the series + counts) on mismatch; `ScatterData::validate` (X/Y) and `BubbleData::validate` (X/Y/size) cover the XY families, with non-raising `is_consistent() -> Bool` on all three (`src/chart/chart_validation.mbt`). **Deviation**: the validation is a standalone opt-in gate, not baked into `with_series` — making `with_series` raise would force categories-before-series ordering and break the infallible fluent chains in the cookbook, so the lenient pad/truncate builders stay the default and `validate()` is the explicit strict boundary. The phantom-type **compile-time** lift remains deferred (per the roadmap) until MoonBit const-generics stabilise. 7 new tests, 975 → 982 × 4 backends; additive `.mbti`.
- **2026-06-07** — **v0.4 D4 landed: typed picture builder state machine.** `Picture::builder(...) -> PictureUncropped` opens a compile-time-enforced image pipeline: `.with_crop(...) -> PictureCropped` (croppable at most once) → `.with_effects(outline?, effects?) -> PictureFinal` (effects at most once, after any crop) → `.build() -> Picture` (the flat type; `build()` available at every stage). The three state types are opaque (`pub struct` with package-private fields), so cropping twice or applying effects after build is a *type error*, not a runtime surprise — the v0.4 "MoonBit differentiator" applied to images, alongside the unconstrained flat `Picture::of_image` / `with_crop`. New file `src/slide/picture_builder.mbt`; entry point is a new `Picture::builder` rather than re-typing `of_image` (whose `-> Picture` return is load-bearing). 7 new tests, 968 → 975 × 4 backends; additive `.mbti`.
- **2026-06-07** — **v0.4 M2 landed: ADT-driven chart options.** `Chart::with_options(Array[ChartOption]) -> Chart` (immutable, ADR-003) folds a sum-type option list into the chart's already-typed model — a pure builder facade in `src/chart/chart_options.mbt` with no parser/writer changes (the existing writer already serialises the populated fields). `ChartOption { Title(String) | TitleDeleted | Legend(LegendPos) | LegendHidden | DataLabels(DLblPos) | DataLabelsHidden | DataTable(Bool) | Style(Int) | RoundedCorners(Bool) | PlotVisibleOnly(Bool) | DisplayBlanks(DisplayBlanksAs) }`; `Title` synthesises the `<c:title><c:tx><c:rich>` DrawingML body, `DataTable` synthesises `<c:dTable>`, `Legend` preserves existing per-entry overrides. **Headline differentiator — compile-time exhaustiveness**: `apply_chart_option` matches every option and `plot_with_d_lbls` matches all 16 `Plot` families (surface families are explicit no-ops, having no `<c:dLbls>`), so forgetting to handle a new option or plot family is a compile error. Sharpened from the sketch's "writer warning" to a total builder match since the writer was already exhaustive. Deferred (documented): `Trendline(series_idx)` / `SecondaryAxis(series_idx)` (deep per-series/axis nesting; secondary axis is an `of_combo` construction-time concern) and a target-qualified number-format option. 14 new tests, 955 → 968 × 4 backends; additive `.mbti`.
- **2026-06-07** — **v0.4 D3 landed: slide transition builder.** `<p:transition>` (CT_SlideTransition) lifts out of `Slide.extension` into a typed `Slide.transition : Transition?` field (mirroring A7's `<p:bg>` lift), with `Slide::with_transition` / `without_transition` immutable builders. `TransitionKind` models the 22-variant base-schema choice child (fade/cut/push/wipe/cover/pull/split/blinds/checker/comb/randomBar/strips/wheel/zoom/circle/diamond/dissolve/newsflash/plus/random/wedge + `NoEffect`), with direction/orientation sub-enums (`TransitionSide`, `TransitionDirection`, `TransitionOrientation`, `TransitionInOut`, `TransitionCorner`) each carrying `from_xml`/`to_xml`. Convenience constructors (`Transition::fade/cut/push/wipe/cover/split/zoom/dissolve/none` + `of_kind`) and timing builders (`with_speed` → `spd`, `with_on_click` → `advClick`, `with_advance_after(ms)` → `advTm`). Writer emits `<p:transition>` after `<p:clrMapOvr>` per CT_Slide order, omitting default attributes (they re-parse identically); `<p:sndAc>`/`<p:extLst>` round-trip via `Transition.extension` (ADR-004). **Scope deviations from the roadmap sketch (documented like A6/A7/C4)**: speed is the base `spd` (slow/med/fast), not a millisecond `with_duration`; PowerPoint-2010 `p14:` extended transitions (reveal, vortex, …) + `p14:dur` are not yet typed but round-trip losslessly via extension, so `Reveal` is deferred. 14 new tests, two pre-existing extension tests updated for the lift; 940 → 955 × 4 backends, additive `.mbti` (+ the `Slide.transition` field, like A7's `background`).
- **2026-06-07** — **Deprecation sweep: `try?` → `try … catch … noraise`.** Migrated all 109 deprecated `try?` uses (1 in `presentation/positioning.mbt`, 108 across 47 `*_test.mbt`) to the recommended `try … catch … noraise` form — not the mechanical `Ok`/`Err` wrap. Test assertions that checked a specific raised error variant became `catch { Variant(_) => () ; _ => fail } noraise { _ => fail }`; the source site degrades to a default via `catch { _ => None }`. No behaviour or `.mbti` change; `moon check --deny-warn` clean. 940 × 4 backends.
- **2026-06-01** — **v0.3.1 refactor + doc sweep (CLAUDE.md §7).** Extracted the slide-attach tail shared by `add_slide_mut` and `duplicate_slide_mut` — append `<p:sldId>` + register the `presentation.xml.rels` rel + add the `[Content_Types]` Override — into a private `Presentation::attach_slide_to_presentation` helper (≈25 duplicated lines removed; no `.mbti` change, it's `pub`-less). Added a notesSlide-orphan GC regression test (the riskiest orphan, carrying a back-ref to its slide). Freshened the README `@presentation` capability line with slide delete / reorder / duplicate. 939 → 940 × 4 backends.
- **2026-06-01** — **v0.3.1 landed: full deck arrangement (E1 + E2 + E3).** Closes the append-only gap surfaced by an external Skill consumer — the build API could add / replace / shape-edit slides but never delete, reorder, or clone one. **E1 deletion**: `remove_slide_mut(idx)` (mutating) + `without_slide(idx)` (immutable, ADR-003), the inverse of `add_slide_mut`, unthreading the slide from `<p:sldIdLst>`, `presentation.xml.rels`, the slide part, its `.rels`, and its `[Content_Types]` `<Override>`. Slide-private parts (notes / images / charts / media) reachable only through the removed slide are reference-count garbage-collected against the remaining package graph; shared layout / master / theme / notes-master parts are always kept (whitelisted removable content types; conservative "孤児だけ消す" policy). New `@opc.ContentTypes::without_override` companion to `with_override`. Enables the `replaceSlides` flow. **E2 reordering**: `move_slide_mut(from, to)` + `with_slide_moved` — pure `<p:sldIdLst>` permute (PowerPoint keys order off `sldIdLst`, not part names), no part renaming / rels churn. **E3 duplication**: `duplicate_slide_mut(idx) -> String` + `with_duplicated_slide` — copies the slide body verbatim and re-references the source's parts (Q12 resolved: lean re-reference over deep-copy, round-trip-safe via E1's refcounting); the building block for "duplicate this template slide, then fill it". Feature-matrix rows for deletion / reordering / duplication all flip to ✅; §5 open-ideas reordering/duplication entries promoted into the shipped E2/E3. 21 new tests, 918 → 939 × 4 backends; additive `.mbti` throughout.
- **2026-05-30** — **Bug fix: `define_master` repair triggers + footer geometry.** Verifying the sample deck in PowerPoint surfaced three issues on the master/template slide, each confirmed by diffing PowerPoint's own repaired output. (1) **Shared theme**: the new master shared `theme1` with the original master — PowerPoint repairs that (the lesson `add_notes` already learned for the notes master). Fixed by giving each defined master its own theme part (a copy of an existing theme). (2) **ID collision**: master ids and layout ids share one id space (`>= 2147483648`); the new master's id (`max master id + 1 = 2147483649`) collided with `slideMaster1`'s existing *layout* id (`2147483649`) → repair. Fixed by basing new master/layout ids on the max over *both* the presentation's `sldMasterId`s and every master's `sldLayoutId`s (`next id = 2147483650/2147483651`, matching PowerPoint's repair). (3) **Footer rendered as a vertical strip**: the generated layout was blank, so slide-level footer / date / slide-number placeholders had no layout placeholder to inherit position from. Fixed by having the generated layout repeat the master's placeholders (with positions). Four regression tests added (dedicated theme; layout placeholders; no id collision). 918 tests × 4 backends; no `.mbti` change.
- **2026-05-30** — **Bug fix: foreign-namespace prefix scoping in `write_xml_element` + examples expanded to v0.3.** Found while extending the sample deck: two media objects on one slide each emit a `<p14:media>`, but `WriteCtx` recorded the auto-bound `extN` prefix document-wide, so the second use referenced an out-of-scope prefix → invalid XML → PowerPoint repair. Fixed by scoping foreign-namespace bindings to the subtree that declares them (forget them after the element closes, so a disjoint sibling re-declares); well-known `a`/`p`/`r` persist. Byte-identical for single-use cases (SVG etc.), only changes the previously-broken multi-use case. Regression test added (video + audio on one slide reopens). The standalone `examples/sample-deck` now builds against the in-repo path dep and the single `sample.pptx` deck grew to 18 slides covering the v0.3 features (slide background, combo + secondary-axis chart, SVG image, in-place shape editing, embedded audio/video, and a `define_master` template slide with footer / auto-date / slide number) — described in user-facing terms, with the per-feature split mode extended to match. 915 tests × 4 backends.
- **2026-05-30** — **Pre-release refactor sweep (CLAUDE.md §7).** Consolidated six near-identical part-name scanners — `extract_image_index` / `extract_chart_index` / `extract_slide_index` / `extract_notes_index` plus an inline scan in `next_media_part_name` — into the single shared `Presentation::max_part_index(prefix)` (already used by `define_master`); the five `next_*_part_name` helpers now derive from it (the chart one maxes over both `chart` and `chartEx` prefixes to keep their shared numbering). ~110 lines of duplicated parsing removed; no behaviour change (914 tests × 4 backends still green, `.mbti` unchanged). Also freshened the README sub-package table for the v0.3 capabilities (SVG / media / `define_master` / shape editing / background / placeholder accessors) and added a cross-reference comment for the shared dt/ftr/sldNum placeholder-idx convention. Large files (`chart/builders.mbt` 1197 L, `shape_writer.mbt` 721 L) reviewed and left as-is — cohesive, no logical split worth the churn pre-release.
- **2026-05-30** — **v0.3 D6 closed: lossless diff-write (delivered by `save()`, no new API).** Investigation showed the property is inherent: the OPC layer stores each part's raw source bytes and only `_mut` operations replace them, so `save()` re-emits untouched parts verbatim and mutated parts carry the writer's output — the exact D6 contract, with no dirty-tracking/hashing (Q10 resolved). The sketched `save_diff(original_bytes)` API was judged redundant (a general version needs per-part-type model comparison for marginal cosmetic-undo benefit). Locked in with `src/presentation/diff_write_test.mbt` (editing one slide leaves all sibling parts byte-identical; pure open→save preserves every part incl. `[Content_Types].xml`). 2 new tests, 912 → 914 × 4 backends; no `.mbti` change. **All v0.3.0 roadmap items now landed.**
- **2026-05-29** — **v0.3 C1 + A8 landed: `define_master` + header/footer/date placeholders.** `Presentation::define_master(MasterDefinition) -> Int` synthesises a `<p:sldMaster>` + one dependent blank `<p:sldLayout>` and wires them into the package (parts, rels — master→layout+theme, layout→master, presentation→master —, content-types, `<p:sldMasterIdLst>`), returning the new master index. `MasterDefinition` (+ `::new` / `with_*` builders) reuses A7 `Background` and B1 `PlaceholderType`; `PlaceholderDef` reuses the existing `Transform` for positions. The master `cSld` (bg + placeholder shapes, plus optional footer/date/slide-number placeholders) is built by serialising a throwaway typed `@slide.Slide` and extracting `<p:cSld>` — reusing the slide writer's escaping/shape emission — then re-wrapped with `<p:clrMap>` + `<p:sldLayoutIdLst>`; the master bg defaults to the standard `bgRef` when unset. A8 slide side: `@slide.Slide::with_slide_number(Bool)` / `with_footer(String)` / `with_date(DateMode{Auto|Fixed})` append idempotent slide-level `sldNum`/`ftr`/`dt` placeholders (fields for number/auto-date). Verified by save→reopen of the 2-master deck and adding a slide on the synthesised layout. 11 new tests, 902 → 912 (×4 backends). **All v0.3.0 scope except D6 (lossless diff-write) now landed.**
- **2026-05-29** — **v0.3 A6 landed: audio / video embedding.** `Presentation::add_video_mut` / `add_audio_mut` embed a media clip + caller-supplied poster image: they add the media part + poster part, three slide relationships (`image` poster, `video`/`audio` link, `media` embed — the last two to the same media part), content-type Defaults, and the shape. New `@oxml.detect_media_format` (mp4/mov/avi/wmv + mp3/wav/aiff/m4a magic bytes) with `content_type`/`extension`/`is_video`. Modelled as a typed `Picture.media : MediaInfo?` rather than the roadmap's `Shape::Media` — a media clip *is* a `<p:pic>`, so reusing `Picture` (poster `blipFill` + transform) avoids a parallel shape kind; builder `@slide.Picture::of_media`. The writer (threaded through `write_nv_wrapper`/`write_cnvpr`) emits `<a:videoFile>`/`<a:audioFile>` + `<p:extLst><p14:media>` inside `<p:nvPr>` and a `ppaction://media` hyperlink on `<p:cNvPr>`, using `write_xml_element` to auto-declare the new `@oxml.powerpoint_2010_ns`. No parser changes — existing media refs round-trip via `Picture.extension` (ADR-004), so `media` is `None` on parse and built media re-serialises identically. New `@oxml.media_ext_uri` + `@opc.rt_video`/`rt_audio`/`rt_media`. 13 new tests, 889 → 902 total × 4 backends.
- **2026-05-29** — **v0.3 C3 landed: combo charts + secondary axis.** New `@chart.ChartPlot { Bar \| Line \| Area }(ChartData)` enum and `Chart::of_combo(primary, secondary, secondary_axis?=false)`. Overlays two plots on a shared `catAx`/`valAx` pair; with `secondary_axis=true` it threads the standard Office 4-axis structure — primary cat(1)/val(2) plus a secondary `valAx`(4) drawn on the right crossing at `Max` and a `delete=true` secondary `catAx`(3) as its crossing partner — and binds the secondary plot to ids 3/4. Secondary series `idx`/`order` are offset past the primary's (new `synthesize_series_from`) so indices are unique chart-wide (avoids PowerPoint's repair prompt). Reuses the existing `PlotArea` multi-plot model + `simple_axis_core` (overridden via struct spread for the right/Max/delete axes). 5 new tests incl. round-trip equality, 884 → 889 total × 4 backends.
- **2026-05-29** — **v0.3 B4 landed: pinpoint shape editing.** Closes the editing-ergonomics gap from the external review. New `@slide.Shape::id()` / `name()` accessors (identity handles; `Unknown` → `None`) + immutable `Slide` edit builders: `map_shapes`, `with_shape_at`, `with_shape_mapped`, `with_shape_by_id` (primary, index-stable), `without_shape`, `without_shape_by_id` — lookups that miss raise `SlideError`, `map_shapes` is the non-raising best-effort path. Presentation-level `map_slide_shapes_mut` / `update_shape_by_id_mut` close the find→edit→write-back loop in one call. **Writer fix**: parsed shapes capture `<p:cNvPr>` wholesale into `extension`, which had been shadowing the typed `name`/`id` on write (so renames silently didn't persist); `write_cnvpr` now overrides the captured element's `id`/`name` attribute *values* with the typed fields while preserving order + `descr`/`title`/`hlinkClick` — byte-identical for unmodified shapes (golden tests unchanged), edits now flow through. Q11 resolved. 13 new tests, 872 → 884 total × 4 backends.
- **2026-05-29** — **Roadmap: added B4 (pinpoint shape editing) to v0.3 from external review.** A review noted that while the core is structurally faithful (lossless round-trip, real OOXML model) and template reuse is first-class (`slide_layouts()` / `slide_masters()` / `themes()` + `add_*_mut` / `update_slide_mut`), the mutation model is append-only + whole-slide-replace: there is no public helper to overwrite an *existing* shape (`update_shape` / `replace_shape` / `map_shapes`). Confirmed against the public `.mbti`. Logged as v0.3 item **B4** (§4.2) with a feature-matrix row (§3.1) and design question **Q11** (§8). Not yet implemented — planning only.
- **2026-05-29** — **v0.3 C4 landed: SVG image support.** `Presentation::add_svg_picture_mut(slide_idx, svg_bytes, fallback_bytes, x, y, cx, cy)` inserts an SVG picture with a raster fallback — wiring the SVG part (`image/svg+xml`) + the fallback raster part, two `rt_image` relationships, the content-type Defaults, and the `Picture` shape. The blip embeds the fallback (`r:embed`) and carries an `<asvg:svgBlip>` pointing at the SVG inside `<a:blip><a:extLst><a:ext uri="{96DAC541-7B7A-43D3-8B79-37D633B846F1}">`. New `@oxml.BlipFill::svg(png_embed_id, svg_embed_id)` builds that blip into `BlipFill.extension` (exactly how a parsed SVG picture round-trips, so the writer emits it verbatim and `write_xml_element` auto-declares the new `@oxml.svg_ns`); plus `@oxml.svg_blip_ext_uri` / `ct_svg` constants and the slide-level `@slide.Picture::of_svg_image`. The full OPC pipeline lives at the presentation level (the `slide` package can't manage parts), a slight deviation from the roadmap's `Picture::of_svg` sketch. No built-in SVG rasteriser — the caller supplies the fallback (rasterisation is out of scope per §0). Refactored `add_picture_mut`'s content-type block into a shared `ensure_default_content_type` helper. 6 new tests, 866 → 872 total × 4 backends.
- **2026-05-29** — **v0.3 A7 landed: typed slide background.** `<p:cSld><p:bg>` lifts from `extension`-only into a typed `Slide.background : Background?` field. `Background` models both forms: `Properties(BackgroundProperties)` for `<p:bgPr>` (fill + `shadeToTitle` + `effectLst` + ADR-004 `extension`) and `StyleReference(idx, @oxml.Color)` for `<p:bgRef>`. Reuses `@oxml.Fill` instead of inventing a parallel `BgFill` enum, and makes `BackgroundProperties.fill` an `Option` (mirroring `AutoShape.fill`) so the unmodelled `<a:grpFill>` form round-trips via `extension` rather than dropping. Builders `Slide::with_background` / `with_background_ref` / `without_background` (+ `BackgroundProperties::of_fill`). Parser handles `<p:bg>` in `parse_c_sld` (no longer captured into `extension`; `classify_ext` drops `"bg"`); writer emits `<p:bg>` first inside `<p:cSld>` per CT_CommonSlideData order. The old ADR-004 extension test for `<p:bg>` was repurposed to assert the typed field. One struct-literal site in `@notes` updated for the new field. 11 new tests, 855 → 866 total × 4 backends.
- **2026-05-29** — **v0.3 B1 landed: placeholder named accessors.** New typed `@slide.PlaceholderType` enum (16 `ST_PlaceholderType` values + `Other(String)` forward-compat, mirroring `@chart_ex.ChartExKind::Other`) with `from_xml`/`to_xml`, plus `Placeholder::kind()` and four `Slide` accessors — `placeholders()`, `title()` (matches `Title`/`CtrTitle`), `body()`, `placeholder(kind)`. Design choice: the raw `Placeholder.ph_type : String` field is **kept as-is** rather than lifted to the enum, because a body/content placeholder commonly omits the `type` attribute (preserved as `""` and round-tripped by omission); collapsing that into a non-optional enum would have broken lossless round-trip (ADR-004). So the typed view is a total, non-raising accessor on top of the raw string — different from how `SlideLayoutType` was lifted (its root `type` is effectively always present, so a lossy absent→`Blank` default was acceptable there). Purely additive `.mbti` diff. 10 new tests, 845 → 855 total × 4 backends.
- **2026-05-26** — **`examples/sample-deck/` reinstated as a standalone consumer module.** The 12-slide demo deck builder (previously deleted from `src/sample/` because library-internal demo code doesn't represent post-`moon add` consumer usage) is back, but now lives as a separate MoonBit module under `examples/sample-deck/` with its own `moon.mod.json` and a path dep on `../..`. From the consumer-side the import shape (`@presentation`, `@chart`, …) is identical to what a `moon add t-ujiie-g/moon-pptx` user would write, so the example doubles as a worked-out usage template. Bisection mode (per-feature isolation files for PowerPoint Online repair debugging) lives behind a compile-time `split_mode` flag in `main.mbt`. Switching to a version dep after v0.2.0 publication is a one-line edit (path → `"0.2.0"`). Path-dep verified via JSON moon.mod.json — the TOML moon.mod format isn't accepting `{ path = ".." }` syntax yet, so this module keeps the JSON form.
- **2026-05-26** — **PowerPoint Online repair-banner fixes + sample-deck removal.** Round-trip diffs against PowerPoint's auto-repaired output surfaced eight schema-and-canonicalisation issues triggering the "needs repair" banner even when the file was spec-valid: (1) `<p:notesMasterId>` was emitting the schema-undefined `id` attribute (only valid on `<p:sldMasterId>`); (2) `<p:sldSz type="custom"/>` should drop the `type` attribute entirely for non-preset dimensions; (3) `<c:ofPieChart>` should omit `<c:splitType val="auto"/>` (PowerPoint repairs it away) and emit explicit `<c:gapWidth>=100` + `<c:secondPieSize>=75` defaults; (4) chart axes need `<c:crosses val="autoZero"/>` (every axis kind) + `<c:crossBetween val="between"/>` (valAx) per spec; (5) 3-D chart builders (`of_bar_3d` / `of_line_3d` / `of_pie_3d` / `of_surface` / `of_surface_3d`) need `<c:view3D>` + `<c:floor>` / `<c:sideWall>` / `<c:backWall>` populated; (6) `<a:custGeom>` should always emit empty `<a:ahLst/>`, `<a:cxnLst/>`, and a default zero-bound `<a:rect>`; (7) the bundled `Presentation::new()` slide-master needs `<p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg>`; (8) internal-slide hyperlinks need `action="ppaction://hlinksldjump"` on `<a:hlinkClick>` plus the rt_slide rel — without it PowerPoint silently rewrites the link to a no-op. Also `notesSlide` and `Slide` writers now synthesise the required `<p:nvGrpSpPr>` + `<p:grpSpPr>` (with zero-valued `<a:xfrm>`) when no captured wrapper exists; `set_notes_mut` auto-synthesises `/ppt/notesMasters/notesMaster1.xml` + a duplicated `theme2.xml` on first call. **`src/sample/` and `src/cmd_sample/` removed** — library-internal demo code doesn't represent post-`moon add` consumer usage; a standalone consumer-example repo is planned for after v0.2.0. The cookbook in `examples/README.md` (verified by `src/integration/examples_test.mbt`) replaces it. 846 tests × 4 backends green (851 → 846 = sample_deck_test.mbt's 13 tests removed, 8 repair fix tests + 5 notes-master tests added throughout).
- **2026-05-26** — **v0.2 batch landed on `main` (7 of 8 items)**: A1 (image-size auto-detection via PNG/JPEG/GIF/BMP/TIFF header parsing in `@oxml.detect_image_dimensions` + `Presentation::add_picture_auto_mut`), A2 (hyperlink builder — new `HyperlinkTarget` enum + `RunProperties::with_hyperlink` / `with_hyperlink_to_slide` + a resolver that allocates slide-rels rIds at `update_slide_mut` time + `rt_hyperlink` constant), A3 (`Presentation::set_notes_mut(slide_idx, text)` with body-placeholder synthesis + auto-Override registration), A4 (`Picture::with_crop(left~, top~, right~, bottom~ : Percentage)`), A5 (`SlideSizeKind` enum + `Presentation::set_slide_size_mut` covering 4:3 / 16:9 / 16:10 / widescreen / Letter / A4 / 35mm / banner / custom), B2 (`TableCellProperties::with_borders` per-edge fluent), C2 (`Presentation::pct_w` / `pct_h` / `slide_w` / `slide_h` percent-of-slide positioning). Plus an `examples/README.md` with 8 cookbook recipes verified by `src/integration/examples_test.mbt`. **A8 (slide number / footer / date placeholders) deferred** — the per-slide flags are cheap, but they only render usefully when the master defines matching placeholders, so the work is bundled with v0.3 C1 (`define_master`). 56 new tests (795 → 851 total × 4 backends).
- **2026-05-26** — **v0.1.0 published to mooncakes.io as `t-ujiie-g/moon-pptx`.** Module renamed from `moon_pptx` to `moon-pptx` to match the repo and align with the hyphen-naming convention common on mooncakes; sub-package import aliases (`@units`, `@chart`, …) and every public API unchanged. README rewritten for an OSS audience (drops pre-alpha banner and phase table; adds sub-package map + compatibility matrix). CHANGELOG.md created. Public-API doc coverage 82 % → 100 % across 116 source files. 795 tests × 4 backends green. `moon publish --dry-run` returned 202 Accepted before tagging.
- **2026-05-25** — Sample-deck builder + integration tests + CLI binary. New `src/sample/build.mbt` exposes `pub fn build_sample_deck()` — an 8-slide deck exercising every typed feature delivered through Phase 7 (styled title, shapes with custom fills, multi-paragraph text, 3×3 table, bar / line / pie / scatter / bubble charts). New `src/integration/sample_deck_test.mbt` carries 10 structural-validation tests (slide count, shape kinds, chart count, text content, round-trip stability). New `src/cmd_sample/main.mbt` is an `is-main` binary that emits the deck bytes as a single hex string on stdout — `moon run src/cmd_sample --target native | tail -1 | xxd -r -p > out/sample.pptx` produces a `.pptx` openable in PowerPoint / Keynote / LibreOffice. The hex+xxd dance is forced by the "no FFI" policy (CLAUDE.md §8) — MoonBit's `core` only exposes `println(Show)` for I/O. `out/` and `*.pptx` are gitignored. 795 total tests × 4 backends.
- **2026-05-25** — **PowerPoint "needs repair" prompt eliminated for `Presentation::new()`.** Building a real sample deck and opening it in PowerPoint Online surfaced two distinct ECMA-376 violations in the bundled template, both fixed in `src/presentation/template.mbt`. (1) Five OPC parts that §13.3.6 marks as required were absent: `/ppt/presProps.xml` (CT_PresentationProperties), `/ppt/viewProps.xml` (CT_CommonViewProperties), `/ppt/tableStyles.xml` (CT_TableStyleList — required when slides carry tables), `/docProps/core.xml` (Dublin Core metadata), `/docProps/app.xml` (extended properties). New content-type constants in `@oxml/content_types.mbt` (ct_pres_props / ct_view_props / ct_table_styles / ct_core_properties / ct_extended_properties) and relationship-type constants in `@opc/relationship_types.mbt` (rt_pres_props / rt_view_props / rt_table_styles / rt_core_properties / rt_extended_properties). (2) The theme was missing `<a:fmtScheme>` (CT_StyleMatrix) — §20.1.6.10's CT_BaseStyles makes all three of clrScheme / fontScheme / fmtScheme mandatory (`minOccurs="1"`), and *this* was the actual PowerPoint repair trigger. Added the canonical 3-entry "subtle / moderate / intense" Office trio across fillStyleLst / lnStyleLst (6350 / 12700 / 19050 EMU) / effectStyleLst / bgFillStyleLst, all using the `phClr` placeholder. Theme reference also moved out of `presentation.xml.rels` (slideMaster.xml.rels owns it now — the Office convention); slides now claim rIds from rId5 onward (next-available after master + presProps + viewProps + tableStyles). `add_slide_mut`'s next-rId walk picks this up automatically. Verified by opening the generated deck in PowerPoint Online — no repair banner. 795 tests still pass × 4 backends.
- **2026-05-25** — **Phase 7 (Charts) closed.** Remaining "embedded XLSX cache generation" item resolved via ADR-009: builders emit inline `<c:strLit>` / `<c:numLit>` data sources (same approach as python-pptx); existing `<c:externalData>` references round-trip losslessly via `Chart.extension` and the referenced xlsx part rides through `@opc.Package` as an opaque part. 3 new round-trip tests for `<c:externalData>` preservation. Open Q5 ("generate or treat as opaque cache?") resolved. 785 total tests × 4 backends.
- **2026-05-25** — Typed `<c:trendline>` body (CT_Trendline) across all three series-core flavours (`ChartSeriesCore`, `ScatterSeriesCore`, `BubbleSeriesCore`). New `trendlines : Array[Trendline]` field replaces the captured `<c:trendline>` payload that previously rode on `extension`. 13 new tests, 782 total × 4 backends.
- **2026-05-25** — Typed `<c:layout>` body (CT_Layout + CT_ManualLayout) across the four call sites that previously captured it as XmlElement. 9 new tests, 769 total × 4 backends.
- **2026-05-25** — Typed `<c:dLbl>` per-data-point overrides (CT_DLbl). 6 new tests, 760 total × 4 backends.
- **2026-05-25** — Typed `<c:dLbls>` data-labels body (CT_DLbls) across all 14 chart families that emit it. 10 new tests, 754 total × 4 backends.
- **2026-05-25** — Typed `<c:legend>` body (CT_Legend). 9 new tests, 744 total × 4 backends.
- **2026-05-25** — Typed `<c:title>` body (CT_Title) for both chart-level and per-axis titles. 8 new tests, 735 total × 4 backends.
- **2026-05-25** — Typed `Axis` (CT_AxBase shared core + commonly-used optional fields). 16 new tests, 727 total × 4 backends.
- **2026-05-25** — Typed chart-series cores land across every standard chart family. 711 tests × 4 backends.
- **2026-05-25** — `Presentation::add_chart_mut / add_chart_ex_mut` close the loop on chart support. 5 new tests, 711 total × 4 backends.
- **2026-05-25** — `Presentation::add_picture_mut` lands the image-insertion API. 7 new tests, 706 total × 4 backends.
- **2026-05-25** — Fluent text + shape styling builders. 7 new tests, 699 total × 4 backends.
- **2026-05-25** — `AutoShape` gains a typed `fill : @oxml.Fill?` field — `AutoShape::rect` / `ellipse` / `round_rect` default to a visible light-grey fill (#DDE3EE) + 1pt dark outline (#445566). 692 tests pass × 4 backends.
- **2026-05-24** — Post-Phase-7 refactor + doc sweep. Stripped "Phase XX" provenance markers from source comments (~156 references across 107 files). Split `src/chart/parser.mbt` + `writer.mbt` along the plot-family boundary. 692 tests pass × 4 backends.
- **2026-05-24** — Phase 7e done (7e1 + 7e2 combined): `src/chart_ex/` sub-package covers the Microsoft 2014 extended chart families (waterfall, treemap, sunburst, histogram, boxWhisker, funnel, paretoLine, regionMap, clusteredColumn). `ChartExKind` discriminator with 9 variants + `Other(String)` for forward compatibility. **Phase 7 closes for the modelled surface.** 13 new tests, 692 total × 4 backends.
- **2026-05-24** — Phase 7d done: eight more from-scratch builders complete the standard-schema chart-builder set — doughnut / ofPie / 3-D bar / 3-D line / 3-D pie / surface / surface3D / stock. 16 new tests, 675 total × 4 backends.
- **2026-05-24** — Phase 7c done: four builders — area / radar / scatter / bubble. 10 new tests, 659 total × 4 backends.
- **2026-05-24** — Phase 7b done: chart-from-scratch builders (`Chart::of_bar / of_line / of_pie`) with inline `<c:strLit>` + `<c:numLit>` data sources. 15 new tests, 649 total × 4 backends.
- **2026-05-24** — Phase 7a3f done: scatter / bubble / stock / surface / surface3D / ofPie bodies typed. All 16 standard plot kinds now typed. 18 new tests, 634 total × 4 backends.
- **2026-05-24** — Phase 7a3e done: 7 more chart family bodies typed (area / area3D / bar3D / line3D / pie3D / doughnut / radar). 10 new tests, 608 total × 4 backends.
- **2026-05-24** — Phase 7a3c + 7a3d done: lineChart and pieChart bodies typed. 9 new tests, 598 total × 4 backends.
- **2026-05-24** — Phase 7a3b done: barChart body typed. 6 new tests, 589 total × 4 backends.
- **2026-05-24** — Phase 7a3a done: plotArea typed structure + plot/axis enum discriminator. 3 new tests, 583 total × 4 backends.
- **2026-05-24** — Phase 7a2 done: `<c:chart>` outer element + chartSpace scalar fields typed. 4 new tests, 581 total × 4 backends.
- **2026-05-24** — Phase 7a1 done: `src/chart/` sub-package reads / writes `<c:chartSpace>` with ADR-004 lossless capture. 10 new tests, 577 total × 4 backends.
- **2026-05-23** — Doc + refactor sweep after Phase 6 closure. Promoted graphic-data URIs and four duplicate helpers into `@oxml`. 566 tests pass × 4 backends.
- **2026-05-23** — Phase 6d done: `TableProperties` + `TableCellProperties` lifted from XmlElement to typed records. **Phase 6 closes.** 7 new tests, 565 total × 4 backends.
- **2026-05-23** — Phase 6c done: table builders. `TableCell::of_text` / `merged_origin` / merge-covered helpers, `TableRow::of_cells`, `Table::of_rows` / `of_grid`, `GraphicFrame::of_table`. 8 new tests, 558 total × 4 backends.
- **2026-05-23** — Phase 6a + 6b done: typed graphic-frame + table parser + writer. `<p:graphicFrame>` lifts from `Shape::Unknown` into `Shape::GraphicFrame`. 5 new tests, 550 total × 4 backends.
- **2026-05-23** — Phase 5f done: ADR-003-compliant immutable builders (`Presentation::clone / with_added_slide / with_slide_updated`). 10 new tests, 545 total × 4 backends.
- **2026-05-23** — Doc + refactor sweep after Phase 5e. Consolidated relationship-type constants into `@opc`. 535 tests pass × 4 backends.
- **2026-05-23** — Phase 5e done: cookbook five-slide pitch deck builder in `src/integration/`. 4 new tests, 535 total × 4 backends.
- **2026-05-23** — Phase 5d done: shape builders (`AutoShape::rect / ellipse / round_rect / textbox`) + `Slide::with_shape` + `Presentation::update_slide_mut`. 11 new tests, 531 total × 4 backends.
- **2026-05-23** — Phase 5c done: `Presentation::add_slide_mut(layout_index)` — first mutation entry point. 7 new tests, 520 total × 4 backends.
- **2026-05-23** — Phase 5b2 done: `Presentation::new()` assembles a blank deck from XML-literal templates. 5 new tests, 513 total × 4 backends.
- **2026-05-23** — Phase 5b1 done: typed `presentation.xml` parser + writer + sldIdLst-driven slide ordering. 4 new tests, 508 total × 4 backends.
- **2026-05-23** — Phase 5a done: `src/presentation/` façade — `Presentation::open / save` + typed accessors. 8 new tests, 504 total × 4 backends.
- **2026-05-23** — Refactor pass after Phase 4. 496 tests pass × 4 backends.
- **2026-05-22** — Phase 4 closed: writer slices 4a (`@comments`) → 4b (`@theme`) → 4c (`@oxml` Color / Fill / Stroke / EffectList) → 4d (`@slide_master`) → 4e (`@slide` + custom geometry) → 4f (`@notes`) → 4g (end-to-end golden in `@integration`). 83 new tests across the phase, 413 → 496 total × 4 backends.
- **2026-05-21** — Phase 3i done: `src/integration/` test-only package adds end-to-end deck round-trip floor. 14 new tests, 413 total × 4 backends. **Phase 3 closes.**
- **2026-05-21** — Phase 3h done: typed `CustomGeometry` AST for `<a:custGeom>`. 22 new tests, 399 total × 4 backends.
- **2026-05-21** — Phase 3g done (3g1 + 3g2 + 3g3): notes slides + comment author list + comment list. 23 new tests across the phase, 377 total × 4 backends.
- **2026-05-21** — Phase 3f closed: lossless preservation (ADR-004) rolled out across the entire model surface. 41 new tests across 3f1 → 3f3e, 354 total × 4 backends.
- **2026-05-13** — Cross-parser refactor — `xml_helpers.mbt` consolidates per-parser `next_event` / `skip_subtree` / `require_attr` into `@oxml`. ~700 lines net change. 305 tests pass × 4 backends.
- **2026-05-12** — Phase 3e closed: fill / stroke / effect parsers (3e1 → 3e4). 49 new tests, 303 total × 4 backends.
- **2026-05-11** — Phase 3d closed: text parser (3d1 → 3d4). 54 new tests, 240 total × 4 backends.
- **2026-05-11** — Phase 3c closed: slide parser (3c1 → 3c4) covering shape / group / connector / picture. 34 new tests, 186 total × 4 backends.
- **2026-05-11** — Phase 3b done: slide master + layout parsers + inheritance resolver. 26 new tests, 152 total × 4 backends.
- **2026-05-11** — Phase 3a done: theme parser. 9 new tests, 126 total × 4 backends.
- **2026-05-11** — Phase 2 closed: OPC layer (a + b + c + d). 110 → 117 tests pass × 4 backends.
- **2026-05-10** — Phase 1 closed: foundations (units 1.1 / colors 1.2 / xml 1.3). 75 tests pass × 4 backends.
- **2026-05-10** — Phase 0 closed: README, CI matrix, CLAUDE.md, AGENTS.md, ADR-006, ADR-007. ADR-002 accepted.
- **2026-05-10** — Project bootstrapped; fzip dependency wired up; smoke test green.

(Pre-v0.1.0 detailed per-slice notes: see git history at commit `b5fc76d` and earlier. From v0.2 onward the public-facing CHANGELOG.md is canonical; this changelog stays as engineering-level detail.)
