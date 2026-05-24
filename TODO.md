# moon_pptx — Development TODO / Roadmap

> Pure-MoonBit library for reading, building, and writing PPTX (OOXML) presentations
> with a type-safe builder API. Targeting publication on [mooncakes.io](https://mooncakes.io).

This document is the **single source of truth** for development direction, phase
breakdown, design decisions, and open questions. Update it as the project evolves.
Living document — every PR that changes scope, design, or status should touch this file.

---

## 0. Project at a glance

| Item | Value |
|---|---|
| Module ID | `t-ujiie-g/moon_pptx` |
| License | Apache-2.0 |
| MoonBit toolchain | `moon 0.1.20260427` (or newer) |
| Primary backend | TBD (lean **Native**; verify Wasm-GC also builds for browser users) |
| Buffer type | `FixedArray[Byte]` (matches fzip / MoonBit core convention) |
| Required deps | `hustcer/fzip` (DEFLATE + ZIP, pure MoonBit) |
| Reference prior art | `python-pptx` (Python), `pptx-svg` (read+render PoC by same author) |
| Differentiator vs `python-pptx` | Type-safe units, ADT-based fills/effects, immutable builders, plus features python-pptx lacks (SmartArt build, animation builder) |

### Out of scope (initially)
- Macros / VBA execution
- EMF/WMF rasterization (binary preserved on read; no creation)
- Animation playback (data round-trip only in early phases; build API later)
- Native PDF export

---

## 1. Vision & non-goals

### Vision
A MoonBit-first PPTX library that lets you **build a complete `.pptx` from
scratch**, **modify existing decks safely**, and **read every detail** of an
arbitrary PPTX — all without depending on any non-MoonBit runtime.

### Design pillars
1. **Pure MoonBit, mooncakes-publishable** — no FFI to host runtimes; works on Native and Wasm-GC backends from a single codebase.
2. **Type-safe units** — `Emu` / `Pt` / `Inch` / `Cm` are distinct types; conversions are explicit.
3. **Immutable builder API** — `Slide::new().with_shape(...).with_text(...)`; builders return new values, not mutated ones.
4. **ADT-driven model** — `Fill`, `Stroke`, `Effect`, `Shape` are enums/sealed traits; pattern match instead of attribute soup.
5. **Round-trip preservation** — unknown OOXML is preserved verbatim on read→write; we never silently drop data.
6. **Beyond python-pptx where it matters** — SmartArt builder, animation builder, type-safe layout/placeholder schema.

### Non-goals
- Be a drop-in Python replacement (no Python bindings in scope).
- Render to image/PDF (use a separate companion lib if needed).
- Support every legacy PPT (binary `.ppt`) feature.

---

## 2. Architecture (target)

```
src/
├── units/        Emu, Pt, Inch, Cm, Color, RgbColor, ThemeColor, Percentage
├── xml/          Streaming XML reader + writer (escape, namespaces, qnames)
├── opc/          Open Packaging Convention layer:
│                 Package, Part, Relationship, ContentTypes
│                 → wraps fzip; PPTX-agnostic, reusable for DOCX/XLSX later
├── oxml/         Low-level OOXML AST (mirrors ECMA-376 element shapes)
│                 → readers/writers per element family
├── theme/        Theme, ColorScheme, FontScheme, FormatScheme
├── parts/        SlideMaster, SlideLayout, Slide, NotesSlide, Comments, Theme, ...
├── shapes/       AutoShape, TextBox, Picture, Table, Chart, Group, Connector
├── text/         Paragraph, Run, Font, ListStyle, Hyperlink
├── fill/         Fill ADT (Solid, Gradient, Pattern, Picture, None)
├── stroke/       Stroke (LineStyle, DashStyle, Cap/Join, Arrow)
├── effect/       Shadow, Glow, Reflection, Blur, SoftEdge
├── geometry/     PresetGeometry (~154 presets), CustomGeometry, Path commands
├── chart/        ChartData, Series, Axis builders (creation API)
├── smartart/     Layout types, node tree builder
├── animation/    Timeline, Trigger, Effect builders
├── presentation/ High-level: Presentation, SlideCollection, façade entrypoint
└── template/     Bytes-embedded minimal blank PPTX for `Presentation::new()`
tests/            Per-module tests (one *_test.mbt per src module)
test_fixtures/    Real-world PPTX samples (small) for read tests
examples/         Cookbook-style end-to-end builders
docs/             API design notes, OOXML reference cheatsheet
```

### Naming conventions
- Public types: `PascalCase`. Modules and functions: `snake_case`.
- Builders return `Self` (or new value of `Self` for immutable style).
- Conversions: `from_*` / `to_*`. Fallible parse: `parse_*` returning `?` or raising.
- Errors: subdomain-specific `*Error` suberrors; never raw `String` errors.

### Multi-backend strategy
- **Default target**: Native (CLI / library users).
- **Verify**: Wasm-GC builds without changes (no FFI, only fzip + core).
- Avoid: Wasm-1 (legacy), JS backend unless explicitly requested.
- CI matrix should run on at least Native + Wasm-GC.

---

## 3. Phase roadmap

Phases are sequential. Each phase has a **definition of done (DoD)** that must
be met before moving on. Mark items `[x]` as completed and link the merge commit.

### Phase 0 — Bootstrap *(complete)*

DoD: empty project builds, fzip is a verified dependency, baseline test passes,
TODO.md is the living roadmap.

- [x] `moon new` scaffold (`t-ujiie-g/moon_pptx`)
- [x] `moon.mod.json` populated (description, keywords, repo, license)
- [x] `hustcer/fzip` v0.6.1 added as dep
- [x] `moon check` / `moon build` / `moon test` clean
- [x] fzip round-trip smoke test (`fzip_smoke_test.mbt`)
- [x] TODO.md drafted (this file)
- [x] README.md skeleton with vision + status badge (`README.mbt.md`)
- [x] CI workflow (`.github/workflows/ci.yml`): check / fmt / info-drift on Ubuntu+macOS, plus test matrix across `native` / `wasm-gc` / `js`
- [x] Backend matrix decision recorded (see ADR-002: Accepted — Native primary, Wasm-GC and JS verified in CI; LLVM and legacy Wasm excluded)
- [x] CLAUDE.md (Claude Code overlay) and AGENTS.md (tool-agnostic) authored; both reference TODO.md as the source of truth
- [x] MoonBit official skills documented as required Claude Code plugin (`moonbitlang/skills` marketplace → `moonbit-skills`)
- [x] First commit pushed to `origin/main`

---

### Phase 1 — Foundations: units & XML *(complete)*

DoD: a developer can express any OOXML primitive value (units, colors, qnames)
in MoonBit, and serialize/parse arbitrary XML round-trip without data loss.

- [x] **Phase 1.1 — `units` package** *(complete)*
  - [x] `Emu` (Int64), `Pt`, `Inch`, `Cm` as `pub(all) struct Name(Inner)` newtypes
  - [x] Conversion table tested: 914_400 EMU = 1 inch = 72 pt = 2.54 cm
  - [x] `Percentage` exposed as `Double` percent-value; `to_ooxml()` / `from_ooxml()` round-trip the 1/1000-percent integer
  - [x] `Angle` exposed as `Double` degrees; `to_ooxml()` / `from_ooxml()` round-trip the 1/60_000-degree integer
  - [x] `Show` impls for `assert_eq` diagnostics (manual — `derive(Show)` is deprecated in current MoonBit)
  - [x] Tests pass on all four backends (`native` / `wasm-gc` / `js` / `wasm`)
- [x] **Phase 1.2 — `units` color types** *(complete)*
  - [x] `RgbColor` with `parse_hex` (accepts optional `#`, lowercase) and `to_hex` (uppercase, no `#`); raises `UnitsError::InvalidHexColor` for malformed input
  - [x] `HslColor` and lossless RGB↔HSL conversion (round-trip tested within ±1 channel for representative palette); hue auto-wraps for negatives
  - [x] `ThemeColor` enum: 17 slots (`bg1/2`, `tx1/2`, `dk1/2`, `lt1/2`, `accent1..6`, `hlink`, `folHlink`, `phClr`) — exceeds the planned 12 to cover master-level definitions and placeholder color
  - [x] `ColorTransform` ADT (`Tint`, `Shade`, `SatMod`, `LumMod`, `Alpha`) and `SchemeColor` immutable builder (`with_transform` returns a new value)
  - [x] `UnitsError` suberror introduced for the package
  - [x] 33 tests pass on all four backends

  Deferred (not blocking Phase 1): the long-tail OOXML color transforms (`hueMod`, `redMod`, `greenMod`, `blueMod`, `comp`, `inv`, `gamma`, `gray`, etc.). Add as needed when fill/effect parsers in Phase 3 surface them.
- [x] **Phase 1.3 — `xml` package** *(complete)*
  - [x] `QName` type (uri + local; prefix is a serialization-only concept, not part of identity)
  - [x] Streaming writer with namespace prefix binding, attribute and text escaping, auto-collapsing empty elements, CDATA, and typed misuse errors (`WriterMisuse`)
  - [x] Event-based reader yielding `StartElement` / `EndElement` / `Text` / `CData`; full namespace prefix resolution including the default-namespace-doesn't-apply-to-attributes rule; entity decoding (named + numeric); comments / PIs / `<?xml … ?>` skipped; tolerates real-world OOXML
  - [x] Round-trip test: parse → replay through writer → parse again, assert event sequences match (semantic round-trip — byte-equal isn't possible because prefixes are not preserved by event interface and there are multiple valid serialisations)
  - [x] ADR-008 records the event-vs-DOM decision

  75 tests pass on all four backends.

---

### Phase 2 — OPC layer over fzip *(complete)*

DoD: read/write a PPTX (or any OPC package) at the part-and-relationship level.
You can `Package::open(bytes)`, list parts, pick `[Content_Types].xml`, write
back, and the result is openable in PowerPoint.

- [x] **Phase 2a — `opc::Package` + `opc::Part`** *(complete)*
  - [x] `Package::open(bytes)` / `to_bytes()` / `parts()` / `part_by_name()` / `require_part()` / `add_part()` / `remove_part()`
  - [x] `Part { name, content_type, bytes }` + `text()` UTF-8 decoder + `Part::new` with name validation
  - [x] `OpcError` with `ZipFailure` / `MalformedPackage` / `PartNotFound`; `wrap_fzip` boundary
- [x] **Phase 2b — `opc::ContentTypes`** *(complete)*
  - [x] `ContentTypes::parse` / `serialize` for `[Content_Types].xml`
  - [x] `with_default` / `with_override` immutable builders
  - [x] `resolve(part_name)` applies OPC rules (Override > Default; case-insensitive on extension)
  - [x] `Package::open` requires `[Content_Types].xml` and auto-populates `Part.content_type`
  - [x] `Package::content_types()` / `set_content_types()` / `regenerate_content_types_part()`
- [x] **Phase 2c — `opc::Relationship` + `opc::Relationships`** *(complete)*
  - [x] `Relationship { id, rel_type, target, target_mode }` and `TargetMode { Internal | External }`
  - [x] `Relationships::parse` / `serialize` / `by_id` / `by_type` / `with_relationship` (rejects duplicate ids)
  - [x] `rels_path_for(source)` computes the `.rels` location
  - [x] `resolve_target(source, target, mode)` for relative / `..` / absolute / external resolution
  - [x] `Package::relationships_for(source)` returns empty when the rels part is absent
- [x] **Phase 2d — End-to-end .pptx round trip with hand-built fixture** *(complete)*
  - [x] Test helper that constructs a minimal valid `.pptx` shape (Content Types + package rels + presentation + presentation rels + slide + image) via fzip
  - [x] Open → mutate (add new slide + register Override + replace part bytes) → save → reopen, asserting parts, content types, and rels all survive

  117 tests pass on all four backends. **Phase 2 (OPC layer) closed.**

---

### Phase 3 — Read path: parse OOXML to model *(complete)*

DoD: parse a non-trivial PPTX into our typed model (`Presentation`, `Slide`,
`Shape`, …) with **lossless preservation** of unknown XML chunks.

- [x] **Phase 3a — Theme parser (`a:theme`)** *(complete)* — `src/theme/` sub-package: `Theme`, `ColorScheme` (12 slots: dk1/2 lt1/2 accent1..6 hlink folHlink), `ColorChoice` (`Srgb` + `Sys` w/ lastClr fallback), `FontScheme` w/ `FontCollection` (latin/ea/cs + per-script overrides). Strict on modelled elements, lenient via `skip_subtree` on the rest (`fmtScheme`, `objectDefaults`, …). 9 tests, all green × 4 backends.
- [x] **Phase 3b — Slide master / layout parsers + inheritance resolver** *(complete)* — `src/slide_master/` sub-package: `SlideMaster` (clrMap + sldLayoutIdLst), `SlideLayout` (27 layout types per `ST_SlideLayoutType`, `ClrMapOverride { MasterMapping | Override(ColorMapping) }`), and `effective_color_mapping` / `resolve_slide_color` / `lookup_theme_slot` resolvers that walk the theme ← master ← layout chain. Shared `src/oxml/` namespace constants extracted in the same commit. 26 new tests, 152 total × 4 backends.
- [x] **Phase 3c — Slide parser: shapes, group shapes, connectors, pictures, tables** *(complete)*
  - [x] **3c1**: `src/slide/` skeleton — `Slide`, `Shape { AutoShape | Unknown(String) }`, `AutoShape` (id/name/placeholder/transform via `<a:xfrm>`), `clrMapOvr` reuse from `@slide_master`. 10 tests, 162 total × 4 backends.
  - [x] **3c2**: `PresetShape` enum (187 `ST_ShapeType` variants) + `Geometry { Preset(PresetShape, Array[ShapeAdjustValue]) | Custom }`. Parses `<a:prstGeom prst="…">` + `<a:avLst>` adjustment formulas; `<a:custGeom>` recorded as `Custom` with path data deferred. 8 tests, 170 total × 4 backends.
  - [x] **3c3**: `Picture` struct (id/name/transform/geometry + `embed_id` / `link_id` from `<a:blip>` + `SrcRect` crop in 1000ths-of-percent). New `Shape::Picture` variant replaces the `Unknown("pic")` placeholder. `@units.Percentage` and `@units.Angle` now derive `Eq` (needed for crop-comparison tests). 8 tests, 178 total × 4 backends.
  - [x] **3c4**: `Connector` (`<p:cxnSp>`) with `ConnectionEnd { shape_id, idx }` for bound endpoints; `GroupShape` (`<p:grpSp>`) with recursive `children : Array[Shape]` and `<a:chOff>` / `<a:chExt>` child-coord-space fields. New `Shape::Connector` and `Shape::Group` variants; `Unknown` now only catches `graphicFrame` and `contentPart`. 8 tests, 186 total × 4 backends. **Phase 3c (slide parser) closed.**
- [x] **Phase 3d — Text parser: paragraph, run, list style, font, hyperlink** *(complete)*
  - [x] **3d1**: `TextBody` / `Paragraph` / `Run` / `Field` / `Break` skeleton; `plain_text()` convenience extractor; `AutoShape.text_body : Option<TextBody>`. RunProperties / ParagraphProperties currently carry only `lang` / `level` as placeholders; 3d2/3d3 fill them in. 10 tests, 196 total × 4 backends.
  - [x] **3d2**: `RunProperties` widened — `font_size : Pt?` / `bold` / `italic` / `underline : UnderlineKind?` / `strikethrough : StrikeKind?` / `baseline : Percentage?` / `caps : CapsKind?` / `latin` / `east_asian` / `complex_script` / `fill : RunFill?` (SolidRgb/SolidTheme) / `hyperlink_click`. Bool attr accepts `1/0/true/false`. Unknown enum values collapse to `None` (graceful). `@units.Pt/Inch/Cm` now derive Eq. 16 tests, 212 total × 4 backends.
  - [x] **3d3**: `ParagraphProperties` widened — `level` / `alignment : TextAlignment?` (7 variants) / `margin_left,indent : Emu?` / `line_spacing : Percentage?` / `space_before,space_after : Pt?` / `bullet : Bullet?`. `Bullet { BulNone | Char | AutoNum(AutoNumType, Int) | Picture }`. `AutoNumType` covers all 38 `ST_TextAutonumberScheme` values. 16 tests, 228 total × 4 backends.
  - [x] **3d4**: `BodyProperties` (rotation:Angle / vert / wrap / anchor (5 variants) / lIns-bIns / auto_fit:`AutoFit { NoAutoFit | NormAutoFit(fontScale, lnSpcReduction) | SpAutoFit }`) + `ListStyle { default_props, level_props : Array[..,9] }`. `TextBody` carries both alongside paragraphs. 12 tests, 240 total × 4 backends. **Phase 3d (text parser) closed.**
- [x] **Phase 3e — Fill / stroke / effect parsers** *(complete)*
  - [x] **3e1**: Unified `@oxml.Color { base : ColorBase, transforms : Array[ColorTransform] }` covering srgb/hsl/sys/scheme/preset/scrgb plus modifier children. `@theme.ColorChoice` and `@slide.RunFill` removed in favour of `@oxml.Color`. Shared `@oxml.parse_color_element` parser used by theme slots, run fills, and (future) gradient stops / shape fills. 14 new tests, 254 total × 4 backends.
  - [x] **3e2**: `@oxml.Fill { NoFill | SolidFill(Color) | GradientFill(Gradient) | PatternFill(Pattern) | BlipFillVariant(BlipFill) }`. `Gradient { stops, direction (Linear/PathRect/PathCircle/PathShape), rotate_with_shape?, flip? }`, `GradientStop { position, color }`, `Pattern { preset, fg, bg }`, `BlipFill { embed_id, link_id, src_rect?, fill_mode }`, `BlipFillMode { Stretch(FillRect?) | Tile(TileSpec) }`. `@slide.Picture` migrated — its `embed_id` / `link_id` / `src_rect` fields collapsed into a single `blip_fill : @oxml.BlipFill`. 14 new tests, 268 total × 4 backends.
  - [x] **3e3**: `@oxml.Stroke` (width, cap, compound, alignment, fill, dash, join, head_end, tail_end). Enums: `LineCap` (3) / `CompoundLine` (5) / `PenAlignment` (2) / `DashStyle` (11) / `LineJoin { Round | Bevel | Miter(Percentage?) }` / `ArrowType` (6) / `ArrowSize` (3). `parse_stroke` is the entry-point; reuses `@oxml.parse_fill` for the line fill child. Wired into `AutoShape` / `Picture` / `Connector` via `stroke : Stroke?`. 17 new tests, 285 total × 4 backends.
  - [x] **3e4**: `@oxml.EffectList` covers `<a:effectLst>` — `Blur` (rad/grow), `Glow` (rad+color), `InnerShadow` / `OuterShadow` / `PresetShadow` (blurRad+dist+dir+color, plus optional sx/sy/kx/ky/algn/rotWithShape on outerShdw), `SoftEdge` (rad), `Reflection` (full attribute soup). `RectAlignment` enum (9 values). `parse_effect_list` is the entry-point; reuses `@oxml.parse_color_element` for nested colour children. Wired into `AutoShape` / `Picture` / `Connector` via `effects : EffectList?`. `<a:effectDag>` and `<a:fillOverlay>` are recognised but skipped (not yet modelled). 18 new tests, 303 total × 4 backends. **Phase 3e (fill/stroke/effect) closed.**
- [x] **Phase 3f — Lossless preservation (ADR-004)** *(complete)*
  - [x] **3f1**: `@xml.XmlElement` / `@xml.XmlNode` ad-hoc DOM types + `@oxml.collect_subtree` capture helper. Mirrors the event stream (StartElement → Element node carrying children, plus Text and CData leaves). 12 new tests covering empty/single/nested/attribute/namespace/mixed/CData/post-capture-cursor cases. 317 total × 4 backends.
  - [x] **3f2**: Wired `extension : Array[@xml.XmlElement]` into `@slide.Slide`, `AutoShape`, `Picture`, `Connector`, `GroupShape`; replaced top-level `skip_subtree` call sites with `collect_subtree`. `Shape::Unknown(String)` → `Shape::Unknown(@xml.XmlElement)` so `<p:graphicFrame>` / `<p:contentPart>` round-trip the full subtree instead of just the local name. Captures cover unknown `<p:sld>` children (transition / timing / custDataLst / extLst), `<p:cSld>` children (bg, …), `<p:spTree>` root-group metadata (nvGrpSpPr / grpSpPr), foreign-namespace siblings, and per-shape `<p:style>` / `<p:extLst>`. 8 new tests, 325 total × 4 backends.
  - [x] **3f3**: Rolled out `extension` across the remaining model surface in four mechanical passes (a/b/c/d). a = `@theme` (Theme / ColorScheme / FontScheme / FontCollection); b = `@slide_master` (SlideMaster / SlideLayout — layout's `<p:cSld>` body is captured wholesale until the layout shape-tree parser exists); c = `@slide` text-side (TextBody / Paragraph / Run / Field / BodyProperties / ParagraphProperties / RunProperties / ListStyle), with `parse_break` now reading the rPr instead of dropping it; d = `@oxml` ADTs (Color tail modifiers like hueMod/redMod/comp/inv, plus Gradient / Pattern / BlipFill / Stroke / EffectList wholesale). 21 new tests, 346 total × 4 backends.
  - [x] **3f3e**: Threaded the surrounding shape's `extension` array through every helper inside `@slide.parser.mbt` that previously dropped unknowns — `parse_sp_pr`, `parse_grp_sp_pr`, `parse_nv_sp_pr`, `parse_nv_pr`, `parse_nv_cxn_sp_pr`, `parse_cxn_sp_locks`, `parse_xfrm`, `parse_group_xfrm`, `parse_prst_geom`, `parse_av_lst`, `parse_clr_map_ovr`. `<a:scene3d>` / `<a:sp3d>` / `<a:extLst>` / `<p:custDataLst>` / `<p:audioFile>` / `<a:spLocks>` / `<a:hlinkClick>` (inside `<p:cNvPr>`) and every foreign-namespace child of these helpers now lands on the parent shape's (or slide's) `extension`. `Geometry::Custom` widened from `Custom` to `Custom(@xml.XmlElement)` so the `<a:custGeom>` body (`<a:pathLst>`, `<a:gdLst>`, `<a:cxnLst>`, `<a:rect>`) round-trips verbatim until a typed custGeom parser arrives. Remaining `skip_subtree` call sites in the slide parser are all on spec-defined empty leaves (`<a:off>`, `<a:ext>`, `<a:chOff>`, `<a:chExt>`, `<a:gd>`, `<p:ph>`, `<a:stCxn>`, `<a:endCxn>`, `<a:masterClrMapping>`, `<a:overrideClrMapping>`). 8 new tests, 354 total × 4 backends. **Phase 3f closed.**
- [x] **Phase 3g — Speaker notes + Comments** *(complete)*
  - [x] **3g1**: `src/notes/` sub-package. `NotesSlide { name, shapes : Array[@slide.Shape], clr_map_override, extension }` mirrors `Slide`; `NotesSlide::parse(bytes)` delegates to `@slide.Slide::parse_with_root(bytes, "notes")` so shape-tree behaviour (placeholders, lossless-extension, etc.) stays in lockstep with regular slides. New `NotesError { XmlFailure | Malformed | SlideFailure }`. 8 new tests, 362 total × 4 backends.
  - [x] **3g2**: `src/comments/` — `CommentAuthorList::parse` reads `commentAuthors.xml`. `CommentAuthor { id, name, initials, last_idx, clr_idx, extension }` covers `CT_CommentAuthor`; top-level `<p:cmAuthorLst>` siblings and per-author `<p:extLst>` land on the respective `extension`. New `CommentsError { XmlFailure | Malformed }` with `wrap_xml` boundary.
  - [x] **3g3**: `src/comments/` — `CommentList::parse` reads `commentsN.xml`. `Comment { author_id, dt : String?, idx, pos : CommentPos { x : Emu, y : Emu }, text, extension }` covers `CT_Comment`; missing `<p:pos>` raises `Malformed`; nested elements inside `<p:text>` raise (spec violates). Entity references decode through the shared XML reader. 15 new tests covering 3g2+3g3 together, 377 total × 4 backends. **Phase 3g closed.**
- [x] **Phase 3h — Custom geometry typed AST** *(complete)* — `<a:custGeom>` lifts from the wholesale `XmlElement` capture into a typed `CustomGeometry { adjust_values, guides, connection_sites, rect, paths, extension }`. New types: `AdjCoordinate { Literal(Emu) | GuideRef(String) }`, `AdjAngle { Literal(Angle) | GuideRef(String) }`, `PathPoint { x, y }`, `PathCommand { MoveTo | LnTo | CubicBezTo | QuadBezTo | ArcTo | Close }`, `PathFillMode` (6 variants), `Path { w, h, fill, stroke, extrusion_ok, commands, extension }`, `GeomRect { l, t, r, b }`, `ConnectionSite { ang, pos, extension }`. `Geometry::Custom(@xml.XmlElement)` → `Geometry::Custom(CustomGeometry)`. Coordinate / angle attributes auto-disambiguate via integer parsing — non-numeric tokens become `GuideRef`. `<a:ahLst>` (adjust handles, rare and deeply nested) round-trip via `CustomGeometry.extension` per ADR-004 instead of being modelled today. 22 new tests, 399 total × 4 backends.
- [x] **Phase 3i — End-to-end deck round-trip test** *(complete)* — `src/integration/` test-only package builds three synthetic-but-realistic decks (`minimal_deck` / `rich_deck` / `notes_and_comments_deck`) that exercise every read-path parser. `build_pptx(main_part, parts)` helper auto-generates `[Content_Types].xml` and `_rels/.rels` so each fixture only lists its actual parts. `parse_everything(pkg)` dispatches each part to its parser by content type and returns the count tuple `(themes, masters, layouts, slides, notes, author_lists, comment_lists)`. Tests cover: no-panic floor across all three decks, shape kinds in the rich slide (AutoShape × 2 + Picture + Connector + Group + custGeom typed AST), notes paragraph text, comment-author cross-reference, and `Package.to_bytes` → reopen → re-parse equality on Slide / Theme / NotesSlide / CommentList values. Real-world `.pptx` fixtures remain out of scope per TODO Q4 (license). 14 new tests, 413 total × 4 backends. **Phase 3 closed.**
- [x] **Unknown-element preservation strategy** decided and implemented
      (every model node carries `extension : Array[XmlElement]` per ADR-004; see Phase 3f1–3f3e above; the only remaining lossy skips are spec-defined empty leaves where there's nothing to preserve).
- Chart XML parser: deferred to **Phase 7a** (`read all 13 chart types into ChartData`). Charts are large enough to deserve their own phase; the read path was always going to span Phase 3 and Phase 7a, and Phase 7a is where the work lands.

---

### Phase 4 — Write path: serialize model to OOXML *(in progress)*

DoD: any model produced by Phase 3 reads can be re-serialized and reopened by
PowerPoint with no warnings or visual diffs.

Per-element writers mirror the Phase 3 parsers and are sliced by package so
each slice can ship in isolation. The Phase 4 floor for every slice is the
round-trip property `parse → serialize → parse → Eq`; this catches any
silent data loss without requiring a stable canonical XML serialisation.

- [x] **Phase 4a — `@comments` writers** *(complete)* — `CommentAuthorList::serialize` and `CommentList::serialize` mirror their parsers. Shared `@oxml.WriteCtx` + `@oxml.write_xml_element` helper round-trips captured `extension` subtrees (including foreign-namespace siblings via on-the-fly `extN` prefixes). `@oxml.string_to_bytes` converts the writer output to part bytes. 11 new tests, 424 total × 4 backends.
- [x] **Phase 4b — `@theme` writer** *(complete)* — `Theme::serialize` mirrors the parser: `<a:theme>` → `<a:themeElements>` → `<a:clrScheme>` (all 12 slots in canonical order) + `<a:fontScheme>` (majorFont / minorFont with latin / ea / cs leaves + script overrides). Theme-level extensions (`fmtScheme` / `objectDefaults` / `extraClrSchemeLst` and foreign-namespace siblings) round-trip via `extension`. 6 new tests, 441 total × 4 backends.
- [x] **Phase 4c — `@oxml` shared writers** *(complete)*
  - [x] Color writer (`@oxml.write_color`) — six base kinds + five modeled transforms; long-tail modifiers ride on `Color.extension`. 11 tests.
  - [x] Fill writer (`@oxml.write_fill`) — all five variants (`NoFill` / `SolidFill` / `GradientFill` / `PatternFill` / `BlipFillVariant`). Gradient stops + Linear / PathRect / PathCircle / PathShape directions. BlipFill re-emits the captured `<a:blip>` subtree verbatim (so `<a:duotone>` / `<a:clrChange>` etc. round-trip even though they're not modeled). 9 tests.
  - [x] Stroke writer (`@oxml.write_stroke`) — every modeled attribute / child + `<a:round>` / `<a:bevel>` / `<a:miter>` joins + `<a:headEnd>` / `<a:tailEnd>` arrows. Reuses `write_fill` for line fills. 8 tests.
  - [x] EffectList writer (`@oxml.write_effect_list`) — blur / glow / innerShdw / outerShdw / prstShdw / reflection / softEdge plus `<a:fillOverlay>` preservation via `extension`. 9 tests.
- [x] **Phase 4d — `@slide_master` writers** *(complete)* — `SlideMaster::serialize` and `SlideLayout::serialize` mirror their parsers; the captured `<p:cSld>` body (extension) is re-emitted before the modeled `<p:clrMap>` / `<p:clrMapOvr>` to preserve the schema-required element order. `SlideLayoutType::to_xml` added as the inverse of `from_xml`. Layout's `cSld` name attribute is re-injected on write since the parser pulled it onto the typed field. 10 new tests, 451 total × 4 backends.
- [x] **Phase 4e — `@slide` + `@slide.CustomGeometry` writers** *(complete)* — `Slide::serialize` + `Slide::serialize_with_root` orchestrate the cSld / spTree / clrMapOvr structure. Captured extension elements classify by local-name into spTree-level (root-group metadata), cSld-level (bg / controls), and sld-level (transition / timing / custDataLst / extLst). Per-shape writer covers AutoShape + Picture + Connector + GroupShape + Unknown, re-using captured `<p:cNvPr>` / `<p:cNv*Pr>` / `<p:nvPr>` wrapper elements wholesale (the parser captures them verbatim, so synthesising would duplicate). Text writer covers TextBody / BodyProperties / ListStyle / Paragraph / Run / Field / Break with all modeled run/paragraph properties, plus bullet variants and the three AutoFit kinds. Custom geometry writer mirrors `parse_custom_geometry` — avLst / gdLst / cxnLst / rect / pathLst with the six PathCommand variants, AdjCoordinate / AdjAngle round-tripping literals or guide refs. 10 new tests, 488 total × 4 backends.
- [x] **Phase 4f — `@notes` writer** *(complete)* — `NotesSlide::serialize` delegates to `@slide.Slide::serialize_with_root("notes")` so the shape-tree replay logic stays in lockstep with the regular slide writer. 3 new tests, 491 total × 4 backends.
- [x] **Phase 4g — round-trip golden test** in `@integration` *(complete)* — `re_serialize_all(pkg)` walks every OOXML part by content type, runs `::parse(p.bytes).serialize()`, and replaces the part bytes via `remove_part` + `add_part`. `Package.to_bytes()` → reopen → re-parse yields equal model values across Theme / SlideMaster / SlideLayout / Slide / NotesSlide / CommentAuthorList / CommentList for all three fixtures. 5 new tests, 496 total × 4 backends. **Phase 4 (writer floor) closed for the modeled surface.**
- [ ] Auto-generation of `[Content_Types].xml` and rels from model (deferred to Phase 5)
- [ ] Numeric ID assignment (shape IDs, rId, etc.) is deterministic
- [ ] PowerPoint open verification: manual checklist for sample decks
- [ ] LibreOffice open verification (cross-implementation sanity)

---

### Phase 5 — Builder API: create from scratch *(substantially complete; immutable variants + open-verification pending)*

DoD: a user can produce a multi-slide deck with text, shapes, and pictures **without
ever touching XML**, starting from `Presentation::new()`.

Phase 5a–5e are merged: `Presentation::open / save / new`, typed accessors,
`add_slide_mut`, shape builders, `Slide::with_shape`, and `update_slide_mut`
together close the mutating builder loop and a cookbook example
demonstrates a five-slide pitch deck end-to-end. The remaining items
are the immutable builder variants (need `Package::clone`) and external
open-verification.

- [x] **Phase 5a — `Presentation` façade (open / save / typed accessors)** *(complete)* — `src/presentation/` sub-package: `Presentation::open(bytes)` wraps `@opc.Package::open` and re-wraps `OpcError` as `PptxError::OpcFailure`; `Presentation::save()` passes through `Package::to_bytes`. Typed accessors `slides() / themes() / slide_masters() / slide_layouts() / notes_slides() / comment_lists() / comment_authors()` walk parts by content type (lazy parse on demand). All seven sub-package errors flatten into `PptxError` via per-package `*Failure(String)` variants. 8 new tests, 504 total × 4 backends.
- [x] **Phase 5b1 — `presentation.xml` typed parser + writer + `<p:sldIdLst>`-driven ordering** *(complete)* — `PresentationPart { sld_master_ids : Array[SlideMasterIdRef], sld_ids : Array[SlideIdRef], notes_master_id : SlideIdRef?, handout_master_id : SlideIdRef?, sld_sz : SlideSize?, notes_sz : NotesSize?, extension }`. Parser + writer round-trip the modeled fields and replay every unmodelled child via ADR-004 extension. `Presentation::slides()` now resolves the slide parts in `<p:sldIdLst>` source order by joining sldId rIds against `presentation.xml.rels`. Fallback to package storage order only when the package has no main-document relationship at all (malformed but not fatal). New `Presentation::presentation_part()` exposes the typed metadata to callers. 4 new tests (parse, round-trip, sldIdLst-order vs storage-order, missing-rel fallback) — 508 total × 4 backends.
- [x] **Phase 5b2 — `Presentation::new()` blank deck** *(complete)* — `src/presentation/template.mbt` holds the canonical Office-default XML literals (one theme + one slide master + one Blank layout + zero slides) plus all `.rels` templates. `Presentation::new()` assembles them via `@opc.Package::new` + `add_part` + `regenerate_content_types_part`, then re-opens through `Presentation::open` so the returned value is identical-shaped to one obtained from `open(bytes)`. The XML-literal approach (vs constructing typed model values from scratch) sidesteps the writer's "use captured wrapper if present" path that requires an extension-populated `<p:cSld>` — typed-construction can come later if a builder needs it. 5 new tests, 513 total × 4 backends.
- Embedded blank-template `.pptx` bytes — *superseded* by Phase 5b2's programmatic templates; no binary blob lives in the source.
- [x] `Presentation::open(bytes) -> Presentation raise PptxError` *(Phase 5a)*
- [x] `Presentation::save() -> FixedArray[Byte]` *(Phase 5a)*
- [x] `Presentation::new() -> Presentation` *(Phase 5b2)*
- [x] `Presentation::slides() -> SlideCollection` — Phase 5a + 5b1: returns `Array[Slide]` in `<p:sldIdLst>` order; the `SlideCollection` abstraction is unnecessary since `Array[Slide]` covers the same surface.
- Builder methods:
  - [x] **Phase 5c — `add_slide_mut(layout_index) -> String`** *(complete)* — first mutation entry point. Plumbs a blank slide through every place the package tracks it: new `/ppt/slides/slideN.xml` part, sldId entry in `presentation.xml.sldIdLst`, rel in `presentation.xml.rels`, new `slideN.xml.rels` pointing back to the layout, and `<Override>` in `[Content_Types].xml`. Standard relative-path math (`relative_target`) handles the `<Relationship Target="…">` strings. ADR-003 explicitly allows `_mut` variants for deck-editing; the immutable `with_added_slide` lifts when `@opc.Package` gains a clone API. 7 new tests, 520 total × 4 backends.
  - [x] **Phase 5f — `Package::clone` + immutable builder variants** *(complete)* — `@opc.Package::clone() / Part::clone() / ContentTypes::clone()` deep-copy the package layer. `@presentation.Presentation::clone() / with_added_slide(layout_index~) / with_slide_updated(idx, new_slide)` are the ADR-003-compliant immutable counterparts of `add_slide_mut` / `update_slide_mut`. Both clone the package first, then run the same internal mutation, then return the new `Presentation`. 10 new tests, 545 total × 4 backends.
  - [x] **Phase 5d — shape builders + `Slide::with_shape` + `update_slide_mut`** *(complete)* — `AutoShape::rect / ellipse / round_rect / textbox` hand-friendly constructors plus `Slide::with_shape` (immutable, copies the shapes array). `Presentation::update_slide_mut(idx, new_slide)` re-serialises a modified slide and replaces the part bytes in place. End-to-end builder flow works: `Presentation::new()` → `add_slide_mut(0)` → `slides()[i].with_shape(AutoShape::textbox(...))` → `update_slide_mut(i, …)` → `save()`. Round-trip note: hand-built shapes start with an empty `extension` array, so the *first* serialize → parse cycle gains captured `<p:cNvPr>` / `<p:cNvSpPr>` / `<p:nvPr>` wrappers — subsequent cycles are `==`-stable. 11 new tests, 531 total × 4 backends.
  - [ ] `TextBox::new().with_text(...).with_font(...)` — fluent style on top of `AutoShape::textbox`; defer to Phase 5e or later.
  - [ ] `Rectangle::new().at(x,y).size(w,h).with_fill(...)` — fluent style on top of `AutoShape::rect`; same deferral.
  - [ ] `Picture::from_bytes(...)`, `Picture::from_path(...)` (Native only)
- [ ] Type-safe layout selection (placeholder schema as type parameter — stretch goal)
- [x] **Phase 5e — Cookbook 5-slide pitch deck** *(complete)* — `src/integration/cookbook_test.mbt` builds a five-slide pitch deck end-to-end via the public API (`Presentation::new` → `add_slide_mut` → `with_shape` + `AutoShape::textbox / rect / ellipse` → `update_slide_mut` → `save`). Slides cover Title / Problem / Solution / Demo / Closing with rectangles + ellipses + textboxes. Tests assert shape counts per slide, sldId monotonicity (256 + i), and the title slide carries the expected text. The body of `build_pitch_deck` doubles as documentation for the high-level builder flow. 4 new tests, 535 total × 4 backends.

---

### Phase 6 — Tables *(complete)*

DoD: create, modify, and read tables matching python-pptx feature parity.

- [x] **Phase 6a + 6b — typed graphic-frame + table parser + writer** *(complete)* — `<p:graphicFrame>` lifts from the previous `Shape::Unknown(XmlElement)` round-trip path into a typed `Shape::GraphicFrame(GraphicFrame { id, name, transform, content : GraphicFrameContent, extension })`. The `<a:graphicData uri="…">` URI discriminates between `TableContent(Table)` (for the table uri) and `OtherGraphic(uri, XmlElement)` (chart / SmartArt / OLE / anything else — kept verbatim until their own phases). `Table { properties (tblPr captured), grid : Array[Emu], rows, extension }`, `TableRow { height, cells, extension }`, `TableCell { grid_span, row_span, h_merge, v_merge, text_body, properties (tcPr captured), extension }`. Cell text bodies share the slide text writer via the new `write_text_body_with_wrapper(uri, local)` helper. Round-trip verified for plain tables, merged-cell flags, and chart-uri pass-through. 5 new tests, 550 total × 4 backends.
- [x] **Phase 6c — Table builder** *(complete)* — `TableCell::of_text / empty / merged_origin / h_merge_covered / v_merge_covered / hv_merge_covered` cover the standard cell-merge palette; `TableRow::of_cells(cells, height~)` and `Table::of_rows(rows, col_widths~) / of_grid(rows~, cols~, col_width~, row_height~)` build the surrounding structure. `GraphicFrame::of_table(id, name, x, y, cx, cy, table)` wraps it for use with `Slide::with_shape`. Builders synthesise an empty `<a:tblPr/>` + `<a:tcPr/>` on every value so PowerPoint sees the elements it expects without callers having to construct XmlElements. 8 new tests, 558 total × 4 backends.
- [x] Cell merging (grid_span, row_span) — covered by Phase 6c builders.
- [x] **Phase 6d — TableProperties + TableCellProperties typed** *(complete)* — `<a:tblPr>` and `<a:tcPr>` lift from captured `@xml.XmlElement` into typed records. `TableProperties { first_row / first_col / last_row / last_col / band_row / band_col / rtl, fill, table_style_id, extension }`; `TableCellProperties { margin_l / margin_r / margin_t / margin_b, anchor, anchor_ctr, vertical_text, border_left / right / top / bottom / tl_to_br / bl_to_tr, fill, extension }`. New `@oxml.write_stroke_with_local_name` lets the cell-border writer reuse the stroke writer for `<a:lnL>` / `<a:lnR>` / `<a:lnT>` / `<a:lnB>` / `<a:lnTlToBr>` / `<a:lnBlToTr>`. Fluent builder helpers on `TableCellProperties`: `with_margins / with_fill / with_anchor / with_border_all / with_border_*`. 7 new tests, 565 total × 4 backends.
- [x] Cell text, fill, borders, margins — Phase 6d.
- [x] Table styles — `tableStyleId` lifts in Phase 6d; inline `<a:tableStyle>` keeps round-tripping through `TableProperties.extension`.
- [x] Read existing tables losslessly *(Phase 6a)*

---

### Phase 7 — Charts (creation)

DoD: create `bar`, `line`, `pie` charts from data; read all 13 types losslessly.

- [x] **Phase 7a1 — `@chart` package skeleton + lossless capture** *(complete)* — `src/chart/` sub-package: `Chart::parse(bytes) / serialize()` reads/writes `<c:chartSpace>` with the entire body kept verbatim in `space_body : @xml.XmlElement` per ADR-004. New `ChartError { XmlFailure | Malformed }`. New `@oxml.chart_ns` namespace constant + `@oxml.ct_chart` content-type. `Shape::GraphicFrame`'s `GraphicFrameContent` gained a `ChartContent(rid : String)` variant — the chart-uri case now lifts to a typed slide-side rel id (the actual chart bytes live in the separate chart part) instead of riding through `OtherGraphic`. `Presentation::charts() -> Array[@chart.Chart]` accessor walks parts by content type. Integration test deck (`chart_deck`) carries a `/ppt/charts/chart1.xml` plus a slide that references it via `<c:chart r:id="rId2"/>`; round-trip verified through both `Chart::parse → serialize → parse` and end-to-end through `Package::to_bytes` + `re_serialize_all`. 10 new tests, 577 total × 4 backends.
- [x] **Phase 7a2 — type `<c:chart>` header + chartSpace scalar fields** *(complete)* — `Chart::space_body` opaque capture is gone. New `Chart { date1904 / lang / rounded_corners / style, chart : ChartBody, extension }` typed surface plus `ChartBody { title / auto_title_deleted / pivot_fmts / view3d / floor / side_wall / back_wall / plot_area / legend / plot_vis_only / disp_blanks_as / show_d_lbls_over_max / extension }`. Scalar / enum leaves (`autoTitleDeleted`, `plotVisOnly`, `dispBlanksAs`, `showDLblsOverMax`, plus the four chartSpace-level scalars) lift to typed fields; the substantial subtrees (`<c:title>`, `<c:plotArea>`, `<c:legend>`, the 3-D wrappers) keep capturing as `XmlElement?` until 7a3+. New `DisplayBlanksAs { Span | Gap | Zero }` enum with `from_xml` / `to_xml`. Parser raises `Malformed` on schema violations (missing `<c:chart>`, missing `<c:plotArea>`) per the comments-parser-style "spec-defined-required" treatment. Writer mirrors the schema element order (ECMA-376 §21.2.2.29 + §21.2.2.6). 4 new tests, 581 total × 4 backends.
- [x] **Phase 7a3a — type `<c:plotArea>` structure + plot/axis discrimination** *(complete)* — `ChartBody.plot_area` lifts from `XmlElement` into typed `PlotArea { layout, plots : Array[Plot], axes : Array[Axis], data_table, sp_pr, extension }`. `Plot` enum names every spec'd chart-family kind (16 variants: areaChart / area3DChart / lineChart / line3DChart / stockChart / radarChart / scatterChart / pieChart / pie3DChart / doughnutChart / barChart / bar3DChart / ofPieChart / surfaceChart / surface3DChart / bubbleChart); `Axis` enum names the 4 axis kinds (valAx / catAx / dateAx / serAx). Each variant currently wraps the captured `<XmlElement>` payload so the body round-trips losslessly even though no plot-family or axis body is itself typed yet. `Plot::local_name() / element()` and `Axis::local_name() / element()` accessors. Layout / dTable / spPr stay as `XmlElement?` until later 7a slices. Writer emits children in ECMA-376 §21.2.2.14 schema order. Combination charts (multiple plots in one plotArea) supported through `plots : Array`. 3 new tests, 583 total × 4 backends.
- [x] **Phase 7a3b — type `<c:barChart>` body** *(complete)* — `Plot::BarChart(@xml.XmlElement)` becomes `Plot::BarChart(BarChartBody)`. `BarChartBody { bar_dir, grouping, vary_colors, series, d_lbls, gap_width, overlap, ax_ids, extension }` types every CT_BarChart leaf except the still-substantial `<c:ser>` (`series : Array[@xml.XmlElement]`) and `<c:dLbls>`. New enums `BarDir { Bar | Col }` and `BarGrouping { PercentStacked | Clustered | Standard | Stacked }` with `from_xml` / `to_xml`. Parser raises `Malformed` if `<c:barDir>` is absent (schema-required). Writer dispatch (`write_plot`) handles `BarChart` typed-side and falls back to captured `XmlElement` for the other 15 variants. `Plot::element()` returns `Option[XmlElement]` (None for the now-typed `BarChart`). 6 new tests, 589 total × 4 backends.
- [ ] Phase 7a3c–d: type line / pie chart-family bodies — same pattern as 7a3b
- [ ] Phase 7a4: remaining 10 chart families (scatter / area / area3D / bar3D / line3D / pie3D / radar / bubble / doughnut / ofPie / stock / surface / surface3D)
- [ ] Phase 7b: write `bar`, `line`, `pie` from-scratch (builder API)
- [ ] Phase 7c: write `scatter`, `area`, `radar`, `bubble`
- [ ] Phase 7d: remaining types (`stock`, `surface`, `waterfall`, `treemap`, `sunburst`, `histogram`, `boxwhisker`, `funnel`)
- [ ] Series, categories, axes, legend, data labels, trendlines
- [ ] Embedded XLSX cache generation (charts reference an embedded spreadsheet)

---

### Phase 8 — Differentiators (beyond python-pptx)

DoD: at least two features that python-pptx does not offer in builder form.

- [ ] **SmartArt builder**: layout templates + node tree → DiagramML
- [ ] **Animation builder**: timeline DSL for entrance/emphasis/exit/motion
- [ ] **Compile-time placeholder schema**: `slide<TitleAndContent>().title("…").content("…")` with type errors if you set an unsupported placeholder
- [ ] **Streaming write** for huge decks (avoid materializing whole XML in memory)

---

### Phase 9 — Polish, docs, release

DoD: 1.0.0 publishable to mooncakes with stable API surface.

- [ ] API stability review (mark experimental APIs)
- [ ] mbti generated public API stable
- [ ] README with quickstart, examples, comparison vs python-pptx
- [ ] `examples/` covers common scenarios
- [ ] CHANGELOG.md following Keep-a-Changelog
- [ ] Tag `v1.0.0` and `moon publish`

---

## 4. Architecture decision records (ADRs)

Append-only. Each decision gets a heading, date, status, context, decision, consequences.

### ADR-001: Use `hustcer/fzip` for ZIP/DEFLATE
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: PPTX is a ZIP container. We need pure-MoonBit ZIP read/write.
- **Decision**: Depend on `hustcer/fzip` v0.6.1 (released 2026-05-09). Pure MoonBit, fflate-derived, 220+ tests, actively maintained, security-hardened.
- **Consequences**: Saves 1–3 months of self-implementing DEFLATE. Bound to fzip's API and maintenance cadence — acceptable since fzip is shipping multiple releases per week and the API surface we use is small.

### ADR-002: Native primary; Wasm-GC + JS verified in CI; LLVM and legacy Wasm excluded
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: "MoonBit-only library" rules out reliance on a JS host. Native gives us file I/O directly; Wasm-GC enables browser embedding; JS is a useful escape hatch. LLVM is nightly-only (per `moonbit-orientation` skill); legacy Wasm is superseded by Wasm-GC.
- **Decision**: Develop and test against Native first. CI matrix runs `moon test` against `native`, `wasm-gc`, and `js`. Avoid backend-specific features without abstraction. Phase-0 smoke test confirmed all three targets pass.
- **Consequences**: All file I/O goes through `bytes`-level APIs at the public surface; convenience helpers (`Presentation::open_path`) live behind backend gates. Any feature that cannot be expressed cross-backend requires an ADR before adoption.

### ADR-003: Immutable builders over mutable setters
- **Date**: 2026-05-10
- **Status**: Proposed
- **Context**: python-pptx uses mutable attribute setters. MoonBit idioms favor immutability and explicit transformation.
- **Decision**: Builders return new values: `slide.with_shape(s)` not `slide.add_shape(s)`. Where mutation is necessary (e.g., editing existing decks), provide `_mut` variants explicitly.
- **Consequences**: Slightly more allocation; clearer dataflow; safer with concurrency.

### ADR-004: Lossless preservation of unknown XML
- **Date**: 2026-05-10 (accepted 2026-05-21, end of Phase 3f)
- **Status**: Accepted
- **Context**: OOXML has many extension elements (Office variants, third-party). Dropping unknowns silently corrupts files for users.
- **Decision**: Every parsed model node carries an `extension : Array[XmlElement]` capturing children we did not recognize. Writers emit them back verbatim.
- **Consequences**: Slightly heavier model; full round-trip safety even for incomplete coverage. Rolled out across `@theme` / `@slide_master` / `@slide` / `@oxml` / `@notes` / `@comments` plus the custGeom AST in Phase 3f → 3i. The only remaining lossy skips are spec-defined empty leaves where there's nothing to preserve.

### ADR-005: Sub-packages under `src/<name>/`
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: fzip uses a single flat package; pptx-svg uses sub-packages. Surface area for moon_pptx (units, xml, opc, oxml, theme, parts, shapes, text, fill, stroke, effect, geometry, chart, smartart, animation, presentation) is much larger than a leaf compression library — flat scope would muddle namespaces.
- **Decision**: Set `"source": "src"` in `moon.mod.json`. Each subdomain lives at `src/<name>/` with its own `moon.pkg`. Users import as `@<name>` (e.g. `@units`, `@xml`).
- **Consequences**: One `moon.pkg` per sub-package and one `pkg.generated.mbti` per sub-package. Cross-package imports are explicit. Refactoring boundaries between phases is now low-cost: adding/removing a package is a directory move.

### ADR-006: TODO.md as single source of truth; no separate planning docs
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: AI-driven development can scatter intent across many auxiliary docs (plans, designs, reviews). This rots quickly.
- **Decision**: All roadmap, scope, ADRs, open questions, and risk tracking live in `TODO.md`. Tool-agnostic contributor guidance lives in `AGENTS.md`; Claude-specific overlay in `CLAUDE.md`. New planning, decision, or analysis files are not created — append to `TODO.md` instead.
- **Consequences**: One file to keep current. PRs that change scope must update `TODO.md` in the same change.

### ADR-008: XML reader is event-based; DOM is opt-in on top
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: OOXML files (especially slide masters, themes, and embedded chart XML) can be tens to hundreds of KB; a full DOM forces every parser to materialise the whole tree even when it only inspects a handful of elements. Event readers are also easier to make resilient against unknown elements (we can `skip_subtree` at any node).
- **Decision**: The `xml` package exposes a streaming `XmlReader::next() -> XmlEvent?` API with `StartElement` / `EndElement` / `Text` / `CData` events. Higher layers (OOXML AST in Phase 2+) build typed structures by consuming events. If a small DOM helper is needed for an element with many child kinds, build it locally on top of the event stream — never re-parse.
- **Consequences**: Parsers in higher layers carry more state machinery than DOM-based code, but stay memory-bounded and skip unknown subtrees cheaply. The `extension : Array[XmlElement]` lossless-preservation promise (ADR-004) is implemented by collecting events into a small ad-hoc DOM type at exactly the points where we need it.

### ADR-007: MoonBit official skills required for Claude Code workflow
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: Claude Code's behavior on MoonBit code improves dramatically when the official `moonbitlang/skills` plugin is loaded (orientation, agent-guide, refactoring, spec-test).
- **Decision**: Required Claude Code plugins are documented in `CLAUDE.md` and `AGENTS.md`. Contributors install via `/plugin` add marketplace `moonbitlang/skills` then install `moonbit-skills`.
- **Consequences**: Claude Code work without the plugin loaded is best-effort only. Contributors using other agents (Codex, OpenCode, Cursor) follow the install instructions in the upstream skills repo.

---

## 5. Open questions

Open:

| # | Question | Owner | Needed by |
|---|---|---|---|
| Q5 | Chart embedded XLSX — do we generate it or treat as opaque cache? | — | start of Phase 7 |
| Q6 | How do we expose backend differences (Native file APIs vs Wasm-GC byte-only) cleanly? | — | Phase 5 polish (when we add `Presentation::open_path` / `save_path`) |

Resolved:

- **Q1 (Native + Int64)** — resolved at Phase 1.1 (2026-05-10): `Emu = Int64` round-trips on `native` / `wasm-gc` / `wasm` / `js`.
- **Q2 (XML reader)** — resolved at Phase 1.3 (2026-05-10): self-implemented event-based reader (`src/xml/`) per ADR-008. No suitable mooncakes lib at the time.
- **Q3 (blank template shipping)** — resolved at Phase 5b2 (2026-05-23): no binary template ships; `Presentation::new()` assembles a blank deck programmatically from XML-literal templates in `src/presentation/template.mbt` plus the Phase 4 writers. Lets us tune the template by editing MoonBit instead of regenerating a `.pptx` and re-encoding bytes.
- **Q4 (real-world fixtures)** — resolved at Phase 3i (2026-05-21): synthetic-but-realistic fixtures hand-built in `src/integration/` cover the no-panic + round-trip floor without license concerns.

---

## 6. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| OOXML coverage explodes scope (chart, smartart, animation are huge specs) | High | High | Phase gating; release at Phase 5 (text/shapes/picture) as v0.5; charts later |
| MoonBit compiler/breaking changes | Medium | Medium | Pin moon version in CI; track changelogs |
| fzip breaking changes | Low | Low | Pin minor version; smoke test catches regressions early |
| PowerPoint vs LibreOffice rendering differences for our output | Medium | Medium | Manual verification matrix in Phases 4–5 |
| Performance: large decks trigger `Int` overflow in EMU math | Medium | High | Use `Int64` for EMU from day one (units phase) |
| API churn discourages early adopters | Medium | Medium | Mark APIs experimental until Phase 9; SemVer 0.x freely |

---

## 7. Workflow & conventions

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
- Reference TODO.md phase/section when applicable: `phase 1: add Emu newtype`.

### Testing
- Every public function has at least one test.
- Round-trip tests are mandatory at every layer (XML, OPC, OOXML, model).
- Real-world PPTX fixtures live in `test_fixtures/` (small, license-clear).

### Documentation
- Public APIs documented with `///` doc comments.
- Examples in `examples/` are runnable and tested.
- TODO.md is updated *in the same PR* as scope changes.

---

## 8. Comparison vs python-pptx (target end-state)

| Feature | python-pptx | moon_pptx target |
|---|---|---|
| Open / modify / save existing PPTX | ✅ | ✅ (Phase 4) |
| Create from scratch | ✅ | ✅ (Phase 5) |
| TextBox / AutoShape / Picture builders | ✅ | ✅ (Phase 5) |
| Tables | ✅ | ✅ (Phase 6) |
| Charts (build) | partial (~7 types) | ✅ all 13 types (Phase 7) |
| SmartArt | read-only | ✅ build (Phase 8) |
| Animations | read-only | ✅ build (Phase 8) |
| Type-safe units | ❌ | ✅ (Phase 1) |
| Immutable builders | ❌ | ✅ (Phase 5) |
| Lossless extension preservation | partial | ✅ (Phase 3) |
| Compile-time placeholder schema | ❌ | ✅ stretch (Phase 8) |
| Streaming write for huge decks | ❌ | ✅ stretch (Phase 8) |

---

## 9. Living changelog (high-level)

- **2026-05-10** — Project bootstrapped; fzip dependency wired up; smoke test green.
- **2026-05-10** — Phase 0 closed: README, CI matrix (Ubuntu+macOS × native/wasm-gc/js), CLAUDE.md, AGENTS.md, ADR-006 (TODO.md as single source of truth), ADR-007 (MoonBit skills required). ADR-002 accepted.
- **2026-05-10** — CI fix: added `moon update` step before `moon check` / `moon test`. First push surfaced "Failed to resolve registry dependency `hustcer/fzip`" because fresh runners have no registry index until `moon update` populates it. Fix verified locally by wiping `.mooncakes/` and reproducing.
- **2026-05-10** — Phase 1.1 done: `src/units/` sub-package with `Emu` / `Pt` / `Inch` / `Cm` / `Percentage` / `Angle`. ADR-005 accepted (sub-packages under `src/`). 18 tests pass on all four backends.
- **2026-05-10** — Phase 1.2 done: color types added to `src/units/` — `RgbColor` (hex parse/format), `HslColor` (RGB↔HSL conversion), `ThemeColor` enum (17 slots), `ColorTransform` ADT, `SchemeColor` immutable builder, `UnitsError` suberror. 33 tests pass on all four backends.
- **2026-05-10** — Phase 1.3 done (in three commits): `src/xml/` sub-package complete with `QName`, `XmlError`, namespace-aware streaming `XmlWriter`, and event-based `XmlReader` with full namespace + entity handling. ADR-008 records the event-vs-DOM decision. 75 tests pass on all four backends. **Phase 1 (Foundations) closed.**
- **2026-05-10** — Refactoring pass after Phase 1: deleted placeholder stubs (`cmd/main/`, root-package `moon_pptx.mbt` and its tests, `fzip_smoke_test.mbt`, `units_test.mbt` type-only smoke); stripped now-unused fzip import from root `moon.pkg`; refreshed README status table. Codified the 5-point refactoring checklist in `CLAUDE.md §7` so future "リファクタリング" requests apply the same lens. 73 tests still pass × 4 backends.
- **2026-05-11** — Phase 2 a/b/c done: `src/opc/` sub-package with `Package`, `Part`, `OpcError`, `ContentTypes` (Default/Override + resolution + auto-populate), `Relationships` (parse/serialize/lookup/builder + relative/`..`/external target resolution + `rels_path_for` helper). Total 110 tests on all four backends. Phase 2d (end-to-end .pptx fixture) remaining.
- **2026-05-11** — Phase 2d done: in-memory minimal-but-realistic `.pptx` fixture (6 parts, 2 rels files, Default + Override content-types, `..`-walking targets) exercises full open → mutate → save → reopen. **Phase 2 (OPC layer) closed.** 117 tests on all four backends.
- **2026-05-11** — Phase 3a done: `src/theme/` reads `a:theme` into typed `Theme` / `ColorScheme` / `FontScheme`. `skip_subtree` swallows unmodelled siblings (`fmtScheme` and friends) without losing parser state — lossless preservation of the skipped sections is on the docket once ADR-004 is implemented. 126 tests on all four backends.
- **2026-05-11** — Phase 3b done: `src/slide_master/` reads `p:sldMaster` and `p:sldLayout` into typed structs (`ColorMapping`, `SlideLayoutRef`, `ClrMapOverride`, `SlideLayoutType` with 27 spec values), and `inheritance.mbt` resolves theme ← master ← layout colour chains. Shared `src/oxml/` namespace constants extracted (used by theme + slide_master). 152 tests on all four backends.
- **2026-05-11** — Phase 3c1 done: `src/slide/` skeleton parses `<p:sld>` into typed `Slide` with shape list (AutoShape modelled with id/name/placeholder/transform; pic/cxnSp/grpSp/graphicFrame land as `Unknown(name)` placeholders for later 3c slices). 10 tests, 162 total × 4 backends.
- **2026-05-11** — Phase 3c2 done: `PresetShape` enum covers all 187 `ST_ShapeType` values with `from_xml` / `to_xml`; `Geometry` ADT and `ShapeAdjustValue` carry `<a:prstGeom>` adjustment formulas verbatim (formula language deferred). `<a:custGeom>` is recognised but its path data is intentionally opaque for now. 8 tests, 170 total × 4 backends.
- **2026-05-11** — Phase 3c3 done: `Picture` shape parsed from `<p:pic>` (id, name, transform, geometry, blip embed/link rIds, srcRect crop). `Shape::Picture` variant added, `Unknown("pic")` placeholder removed. `@units.Percentage` and `@units.Angle` gained `derive(Eq)` so structural comparison works in tests. 8 tests, 178 total × 4 backends.
- **2026-05-11** — Phase 3c4 done: `Connector` (`<p:cxnSp>`) with optional bound endpoints (`ConnectionEnd { shape_id, idx }`) and `GroupShape` (`<p:grpSp>`) with recursive `children : Array[Shape]` and the `<a:chOff>` / `<a:chExt>` child-coord-space fields. `Shape::Unknown` now only catches `graphicFrame` and `contentPart`. **Phase 3c (slide parser) closed.** 8 tests, 186 total × 4 backends.
- **2026-05-11** — Phase 3d1 done: `TextBody` / `Paragraph` / `Run` / `Field` / `Break` model + `plain_text()` extractor; `AutoShape.text_body` field. `RunProperties` carries `lang` placeholder, `ParagraphProperties` carries `level`; the rest of the run/paragraph property surface lands across 3d2–3d4. 10 tests, 196 total × 4 backends.
- **2026-05-11** — Phase 3d2 done: `RunProperties` now covers the practical `<a:rPr>` surface — font size (Pt) / bold / italic / underline / strikethrough / baseline (Percentage) / caps / latin+ea+cs typefaces / solid fill (RGB or theme) / hyperlink_click rId. Unknown enum values collapse to `None` gracefully. `@units.Pt/Inch/Cm` derive `Eq`. 16 tests, 212 total × 4 backends.
- **2026-05-11** — Phase 3d3 done: `ParagraphProperties` covers `<a:pPr>` — level / alignment (7-variant `TextAlignment`) / marL/indent (Emu, negatives for hanging indent) / lineSpacing (Percentage) / spaceBefore/After (Pt). `Bullet` ADT covers `<a:buNone>` / `<a:buChar>` / `<a:buAutoNum>` (38-variant `AutoNumType`) / `<a:buBlip>`. Unknown algn values collapse to `None`; unknown buAutoNum types raise `Malformed`. 16 tests, 228 total × 4 backends.
- **2026-05-11** — Phase 3d4 done: `BodyProperties` (rotation, vertical text, wrap, anchor, four insets, auto-fit ADT) + `ListStyle` (defPPr + 9-slot level array). `TextBody` carries both fields alongside paragraphs. **Phase 3d (text parser) closed.** 12 tests, 240 total × 4 backends.
- **2026-05-11** — Refactor pass between Phase 3d and 3e: extracted shared UTF-8 decoder to `@oxml.bytes_to_string` (collapsed 3 copies in theme/slide_master/slide); consolidated 9 per-test `_ascii` helpers + namespace literals into `src/slide/_shared_fixtures_test.mbt`; split 1574-line `src/slide/parser.mbt` along the shape/text boundary (parser.mbt 1031 lines + text_parser.mbt 506 lines); fixed stale Phase status row in README and dangling `, charts` typo in TODO.md. 240 tests still pass × 4 backends.
- **2026-05-12** — Phase 3e1 done: unified `@oxml.Color { base, transforms }` ADT lifts theme slots, run-level fill, and every future gradient stop / shape fill onto one parser path. Old `@theme.ColorChoice` and `@slide.RunFill` removed. `@oxml.parse_color_element` covers all six DrawingML colour elements (srgb/hsl/sys/scheme/prst/scrgb) plus the five modeled colour transforms (Tint/Shade/SatMod/LumMod/Alpha); long-tail modifiers (hueMod, redMod, comp, …) are accepted but currently dropped. `@units.HslColor` / `@units.ColorTransform` gained `derive(Eq)`. 14 new tests, 254 total × 4 backends.
- **2026-05-12** — Phase 3e2 done: full shape-level `@oxml.Fill` ADT (`NoFill` / `SolidFill` / `GradientFill` / `PatternFill` / `BlipFillVariant`) with supporting types (`Gradient`, `GradientStop`, `GradientDirection`, `Pattern`, `BlipFill`, `BlipFillMode { Stretch | Tile }`, `TileFlip`, `TileAlignment`, `TileSpec`, `FillRect`, `SrcRect`). `@oxml.parse_fill` is the entry-point. `@slide.Picture` migrated — its three picture-blip fields collapse into one `blip_fill : @oxml.BlipFill`; the slide-local `parse_blip_fill` / `extract_blip_rels` / `parse_src_rect_attrs` helpers are gone. 14 new tests, 268 total × 4 backends.
- **2026-05-12** — Phase 3e3 done: `@oxml.Stroke` covers `<a:ln>` — width / cap / compound / alignment / fill (reuses `@oxml.Fill`) / dash (`DashStyle` 11 presets) / join (Round/Bevel/Miter w/ optional limit) / head & tail arrows (`ArrowType` 6, `ArrowSize` 3). `parse_stroke` entry-point. Wired into `AutoShape` / `Picture` / `Connector` via `stroke : Stroke?`. 17 new tests, 285 total × 4 backends.
- **2026-05-12** — Phase 3e4 done: `@oxml.EffectList` covers `<a:effectLst>` — Blur, Glow, InnerShadow, OuterShadow, PresetShadow, SoftEdge, Reflection plus 9-value `RectAlignment` enum. `parse_effect_list` reuses `@oxml.parse_color_element` for nested colour children; unmodelled siblings (`fillOverlay`, `effectDag`) are skipped to keep parsing tolerant. Wired into `AutoShape` / `Picture` / `Connector` via `effects : EffectList?` on `<p:spPr>` (`parse_sp_pr` widened to 4-tuple). 18 new tests, 303 total × 4 backends. **Phase 3e (fill/stroke/effect) closed.**
- **2026-05-12** — Refactor pass after Phase 3e (safe set): extracted shared `@oxml.parse_signed_int` / `parse_signed_int64` to collapse six byte-identical signed-decimal parsers (color/fill/stroke/effect/slide/text_parser → ~180 LOC removed); collapsed 8 test-side namespace literals onto `@oxml.{drawing_ns, presentation_ns, office_relationships_ns}`; deleted 5 unused public builders (`EffectList::empty` / `Stroke::empty` / `FillRect::default` / `SrcRect::default` / `TileSpec::default`); fixed a stale header comment in `effect.mbt` (no run-level `<a:rPr>` wiring); added 2 missing negative tests (`innerShdw` without colour, `prstShdw` without `prst`). 305 tests × 4 backends. The bigger consolidation (`next_event` / `skip_subtree` / `require_attr` family across the 7 parsers) is deferred to a separate commit before Phase 4 starts.
- **2026-05-13** — Cross-parser refactor (`xml_helpers.mbt`): consolidated per-parser copies of `next_event` / `skip_subtree` / `require_attr` (+ family) into a single shared module under `@oxml`, raising the neutral `XmlReadError`. Color/fill/stroke/effect/slide/slide_master/theme parsers now delegate; each translates back into its own domain suberror at the use site. ~700 lines net change (-671 / +562).
- **2026-05-21** — Phase 3f1 done: `@xml.XmlElement` / `@xml.XmlNode` ad-hoc DOM types added alongside `XmlEvent`. New `@oxml.collect_subtree` helper consumes events into an `XmlElement` (used at the points where parsers previously called `skip_subtree`) so unknown OOXML chunks can round-trip per ADR-004. 12 new tests cover empty/attribute/nested/text/CDATA/mixed-content/namespace cases plus the post-capture cursor position. 317 tests × 4 backends.
- **2026-05-21** — Phase 3f2 done: `@slide.{Slide, AutoShape, Picture, Connector, GroupShape}` gained `extension : Array[@xml.XmlElement]` fields. Slide parser replaces top-level `skip_subtree` call sites with `collect_subtree_unknown` so `<p:transition>` / `<p:timing>` / `<p:custDataLst>` / `<p:extLst>` / `<p:bg>` / foreign-namespace siblings + the implicit-root-group metadata land on `Slide.extension`; `<p:style>` / `<p:extLst>` siblings of shape bodies land on each shape's own `extension`. `Shape::Unknown(String)` → `Shape::Unknown(@xml.XmlElement)` so `<p:graphicFrame>` (table / chart / SmartArt host) and `<p:contentPart>` round-trip the full subtree instead of just the local name. 8 new tests, 325 total × 4 backends.
- **2026-05-21** — Phase 3f3 done (a → d): rolled `extension : Array[@xml.XmlElement]` out across the remaining model surface. `@theme.{Theme, ColorScheme, FontScheme, FontCollection}` now keep `<a:fmtScheme>` / `<a:objectDefaults>` / `<a:extraClrSchemeLst>` / foreign-namespace children. `@slide_master.{SlideMaster, SlideLayout}` keep `<p:cSld>` (incl. layout's full shape tree) / `<p:txStyles>` / `<p:hf>` / `<p:transition>` / `<p:extLst>`. `@slide` text-side widens to TextBody / Paragraph / Run / Field / BodyProperties / ParagraphProperties / RunProperties / ListStyle; `parse_break` now actually parses the rPr instead of dropping it. `@oxml.Color` keeps unmodelled colour-modifier tail (`hueMod`, `redMod`, `comp`, `inv`, `gamma`, `gray`, …); `@oxml.{Gradient, Pattern, BlipFill, Stroke, EffectList}` keep unmodelled children (BlipFill captures the entire `<a:blip>` subtree so `<a:duotone>` / `<a:clrChange>` etc. round-trip; EffectList captures `<a:fillOverlay>`; Stroke captures `<a:custDash>` and `<a:extLst>`). The Phase 3 "Unknown-element preservation strategy" checkbox flips to done; one residual is helper-level skips inside `@slide.parser.mbt` (tracked as Phase 3f3e). 21 new tests, 346 total × 4 backends.
- **2026-05-21** — Phase 3f3e done: threaded each shape's `extension` array through the helper parsers (`parse_sp_pr` / `parse_grp_sp_pr` / `parse_nv_sp_pr` / `parse_nv_pr` / `parse_nv_cxn_sp_pr` / `parse_cxn_sp_locks` / `parse_xfrm` / `parse_group_xfrm` / `parse_prst_geom` / `parse_av_lst` / `parse_clr_map_ovr`). Result: every previously-dropped child inside an `<p:spPr>` / `<p:grpSpPr>` / `<p:nvSpPr>` / `<p:nvPicPr>` / `<p:nvCxnSpPr>` (`<a:scene3d>`, `<a:sp3d>`, `<a:extLst>`, `<a:hlinkClick>` inside `<p:cNvPr>`, `<a:spLocks>` inside `<p:cNvSpPr>`, `<p:custDataLst>` / `<p:audioFile>` inside `<p:nvPr>`, foreign-namespace siblings, and `<a:custGeom>`'s full body) round-trips on the surrounding shape's `extension`. `Geometry::Custom` widened to `Custom(@xml.XmlElement)` to carry the `<a:custGeom>` payload. The remaining `skip_subtree` calls in the slide parser are all on spec-empty leaf elements where there's nothing to preserve. 8 new tests, 354 total × 4 backends. **Phase 3f (lossless preservation) closed.**
- **2026-05-21** — Phase 3g1 done: `src/notes/` sub-package reads `<p:notes>`. `@slide` parser refactored so `Slide::parse_with_root(bytes, "notes")` (a new public entry alongside `Slide::parse`) re-uses the existing `<p:cSld>` / `<p:spTree>` / `<p:clrMapOvr>` walk for notes slides — shape-tree behaviour stays in lockstep automatically. `NotesSlide { name, shapes : Array[@slide.Shape], clr_map_override, extension }` is a thin wrapper struct so consumers pattern-match on the type, not a tag. `NotesError { XmlFailure | Malformed | SlideFailure }`. 8 new tests, 362 total × 4 backends.
- **2026-05-21** — Phase 3g2 + 3g3 done: `src/comments/` sub-package reads both comment parts. `CommentAuthorList::parse` reads `commentAuthors.xml` into `CommentAuthor { id, name, initials, last_idx, clr_idx, extension }`. `CommentList::parse` reads `commentsN.xml` into `Comment { author_id, dt : String?, idx, pos : CommentPos { x : Emu, y : Emu }, text, extension }` — `<p:pos>` is required (raises `Malformed` if absent), `dt` is optional (older PowerPoint omits it), nested elements inside `<p:text>` raise (spec violation), entity references decode through the shared reader. New `CommentsError { XmlFailure | Malformed }` with `wrap_xml` boundary. 15 new tests, 377 total × 4 backends. **Phase 3g (speaker notes + comments) closed.**
- **2026-05-21** — Phase 3h done: `<a:custGeom>` lifts into a typed `@slide.CustomGeometry` AST. `avLst` / `gdLst` reuse `ShapeAdjustValue`; `cxnLst` becomes `Array[ConnectionSite { ang : AdjAngle, pos : PathPoint, extension }]`; `<a:rect>` becomes `GeomRect { l, t, r, b : AdjCoordinate }`; `<a:pathLst>` becomes `Array[Path { w, h, fill : PathFillMode, stroke, extrusion_ok, commands, extension }]` with the six `PathCommand` variants (`MoveTo` / `LnTo` / `CubicBezTo` / `QuadBezTo` / `ArcTo` / `Close`). `AdjCoordinate` / `AdjAngle` auto-disambiguate literals from guide references at parse time via integer-parse-or-fall-back. `<a:ahLst>` (adjust handles — rare, deeply nested) preserved via `CustomGeometry.extension` per ADR-004 rather than typed today. `Geometry::Custom(@xml.XmlElement)` → `Geometry::Custom(CustomGeometry)` is a breaking enum change; the only call site is the slide parser's dispatch on `<a:custGeom>` and the one existing geometry test, both updated. 22 new tests, 399 total × 4 backends. **Phase 3h closed.**
- **2026-05-24** — Phase 7a3b done: `<c:barChart>` body lifts from captured `XmlElement` into typed `BarChartBody`. Scalar / enum / integer leaves typed (`barDir` / `grouping` / `varyColors` / `gapWidth` / `overlap` / `axId*`); `<c:ser>` (CT_BarSer) and `<c:dLbls>` stay as `XmlElement` until later slices. New enums `BarDir { Bar | Col }`, `BarGrouping { PercentStacked | Clustered | Standard | Stacked }`. Writer dispatch over `Plot` variants (`write_plot`) lets typed and captured variants coexist. `Plot::element()` is now `Option[XmlElement]` (None for the typed barChart variant). 6 new tests, 589 total × 4 backends.
- **2026-05-24** — Phase 7a3a done: `<c:plotArea>` body lifts from the captured `XmlElement` into typed `PlotArea { layout, plots, axes, data_table, sp_pr, extension }`. 16-variant `Plot` enum + 4-variant `Axis` enum discriminate the chart-family and axis children by their local name; bodies still ride as captured `XmlElement` per ADR-004 until later 7a slices. Combination charts (multiple plots in one `<c:plotArea>`) survive via `plots : Array[Plot]`. Writer follows ECMA-376 §21.2.2.14 schema order. 3 new tests, 583 total × 4 backends.
- **2026-05-24** — Phase 7a2 done: `<c:chart>` outer element + chartSpace-level scalar leaves lift from the wholesale `space_body` capture into typed fields on `Chart` + new `ChartBody` sub-struct. Scalar/enum-valued leaves typed: `date1904`, `lang`, `roundedCorners`, `style`, `autoTitleDeleted`, `plotVisOnly`, `dispBlanksAs` (enum `Span|Gap|Zero`), `showDLblsOverMax`. Substantial subtrees (`title` / `plotArea` / `legend` / `view3D` / `floor` / `sideWall` / `backWall` / `pivotFmts`) stay as captured `XmlElement?` per ADR-004 until 7a3+. Parser raises `Malformed` on missing `<c:chart>` or missing `<c:plotArea>` per ECMA-376 schema requirements (`CT_ChartSpace`, `CT_Chart`). Writer emits children in schema order. Adopted the codebase's `assert_true(x is None)` / `unwrap()` patterns for Option assertions (instead of `assert_eq(x, None)`) to dodge the new `core/debug` deprecation that fires when `assert_eq` invokes `Show` on container types. 4 new tests, 581 total × 4 backends.
- **2026-05-24** — Phase 7a1 done: `src/chart/` sub-package reads / writes `<c:chartSpace>` end-to-end with the entire body captured per ADR-004 (`Chart { space_body : XmlElement }`). New namespace + content-type constants (`@oxml.chart_ns`, `@oxml.ct_chart`). `GraphicFrameContent` gained `ChartContent(rid)` so the slide-side `<c:chart r:id="…"/>` no longer rides through `OtherGraphic`; the actual chart bytes are exposed via `Presentation::charts()`. End-to-end `chart_deck` integration fixture (`fixtures_test.mbt` plus new `chart_test.mbt`) covers slide-side reference + chart-part round-trip + `re_serialize_all` golden. 10 new tests, 577 total × 4 backends.
- **2026-05-23** — Doc + refactor sweep after Phase 6 closure. Promoted graphic-data URIs (`graphic_data_table_uri` plus new `graphic_data_chart_uri` / `graphic_data_diagram_uri`) into `@oxml/content_types.mbt` next to the existing `ct_*` / `rt_*` constants; dropped the local copies. Replaced the four duplicate helpers in `slide/graphic_frame_parser.mbt` (`bool_attr_opt` / `emu_attr_opt` / `lookup_attr` / second-copy attribute lookups) with their existing `@oxml` counterparts. Added a builder-side round-trip test for `TableCellProperties` confirming margins / anchor / fill come back unchanged after serialize → re-parse. README banner refreshed (Phase 6 closed) + new Tables snippet in Quickstart. 566 tests still pass × 4 backends; no semantic changes.
- **2026-05-23** — Phase 6d done: `<a:tblPr>` + `<a:tcPr>` lift from `@xml.XmlElement` capture into typed `TableProperties { first_row / first_col / last_row / last_col / band_row / band_col / rtl, fill, table_style_id, extension }` and `TableCellProperties { margin_{l,r,t,b}, anchor, anchor_ctr, vertical_text, border_{left,right,top,bottom,tl_to_br,bl_to_tr}, fill, extension }`. New `@oxml.write_stroke_with_local_name(w, ctx, s, local)` lets the cell-border writer reuse `@oxml.write_stroke` for the six `<a:ln{L,R,T,B,TlToBr,BlToTr}>` variants. `TableCellProperties::default / with_margins / with_fill / with_anchor / with_border_all / with_border_{left,right,top,bottom}` ergonomic builders. Round-trip verified for the full attribute soup. **Phase 6 (Tables) closed.** 7 new tests, 565 total × 4 backends.
- **2026-05-23** — Phase 6c done: table builders. `TableCell::of_text / empty / merged_origin / h_merge_covered / v_merge_covered / hv_merge_covered` cover the standard cell-merge palette. `TableRow::of_cells(cells, height~)` plus `Table::of_rows(rows, col_widths~) / of_grid(rows~, cols~, col_width~, row_height~)` build the surrounding structure. `GraphicFrame::of_table(id, name, x, y, cx, cy, table)` wraps it for `Slide::with_shape`. Empty `<a:tblPr/>` + `<a:tcPr/>` are synthesised so PowerPoint sees the elements it expects without callers ever touching `XmlElement`. 8 new tests, 558 total × 4 backends.
- **2026-05-23** — Phase 6a + 6b done: typed graphic-frame + table parser + writer. `<p:graphicFrame>` lifts from `Shape::Unknown(XmlElement)` into `Shape::GraphicFrame(GraphicFrame { id, name, transform, content : GraphicFrameContent { TableContent(Table) | OtherGraphic(String, XmlElement) }, extension })`. The `<a:graphicData uri="…">` URI routes: the table uri gets a typed `Table { properties, grid, rows : Array[TableRow { height, cells : Array[TableCell { grid_span, row_span, h_merge, v_merge, text_body, properties, extension }] }] }` body; everything else (chart / SmartArt / OLE) round-trips through `OtherGraphic`. Cell text-body writers share the slide text writer via the new `write_text_body_with_wrapper(uri, local)` helper. Round-trip verified for plain 2×2 tables, every merged-cell flag combination, and chart-uri pass-through. 5 new tests, 550 total × 4 backends.
- **2026-05-23** — Phase 5f done: ADR-003-compliant immutable builder variants. `@opc.Package::clone() / Part::clone() / ContentTypes::clone()` deep-copy the package layer (parts get fresh `FixedArray[Byte]` buffers; ContentTypes' defaults/overrides get fresh arrays). `@presentation.Presentation::clone() / with_added_slide(layout_index~) / with_slide_updated(idx, slide)` clone the package first, run the same internal mutation as their `_mut` counterparts, and return the new value. Closes Phase 5's main builder-API story. 10 new tests, 545 total × 4 backends.
- **2026-05-23** — Doc + refactor sweep after Phase 5e. Consolidated the `.rels` content-type string (was duplicated as `rels_content_type` in `add_slide.mbt` and `ct_relationships` in `template.mbt`) into `@opc.rels_content_type`; promoted the ten OOXML relationship-type URLs (`officeDocument` / `slide` / `slideMaster` / `slideLayout` / `theme` / `image` / `notesSlide` / `notesMaster` / `comments` / `commentAuthors`) to `@opc.rt_*` constants and replaced the eleven hardcoded sites. `template.mbt`'s four `.rels` literals now share one `relationships_doc` builder. README banner refreshed ("Phase 4 closed" → "Phase 5 substantially closed"); Quickstart rewritten to show the actual working API instead of the planned-future stub; phase-status table updated. Phase 5 status banner in TODO.md clarified. 535 tests still pass × 4 backends; no semantic changes.
- **2026-05-23** — Phase 5e done: cookbook example in `src/integration/cookbook_test.mbt` builds a five-slide pitch deck end-to-end (Title / Problem / Solution / Demo / Closing) using only public API. Helpers `add_centered_textbox` / `add_rect_at` / `add_ellipse_centered` show how to compose the typed shape builders into higher-level layout flows. EMU arithmetic stays in `Int64` until the builder boundary so users don't have to destructure the newtype repeatedly. Tests assert shape counts, sldId monotonicity, and title text round-trip. 4 new tests, 535 total × 4 backends.
- **2026-05-23** — Phase 5d done: shape builders (`AutoShape::rect / ellipse / round_rect / textbox` + `TextBody::of_text` + `Paragraph::of_text`) close the gap between typed model values and hand-friendly construction. `Slide::with_shape` returns a new `Slide` with the shape appended (copies the shapes array so the original is untouched). `Presentation::update_slide_mut(idx, new_slide)` re-serialises and replaces the slide's part bytes — closes the edit loop: `new() → add_slide_mut → with_shape → update_slide_mut → save()`. Caveat documented in the builder tests: hand-built shapes' first serialize → parse cycle adds captured `<p:cNvPr>` / `<p:cNvSpPr>` / `<p:nvPr>` wrappers to `extension`, so strict `==` only holds from the second cycle onwards. 11 new tests, 531 total × 4 backends.
- **2026-05-23** — Phase 5c done: first mutation entry point `add_slide_mut(layout_index) -> String` on `Presentation`. Appends a blank `/ppt/slides/slideN.xml` part (XML literal), threads it through `presentation.xml.sldIdLst` (next available sldId starting from 256), `presentation.xml.rels` (new rId), `slideN.xml.rels` (back-pointer to layout via `../slideLayouts/slideLayoutM.xml`), and `[Content_Types].xml` Override. The helper `relative_target` does the standard "common-prefix + ../ math" so cross-folder relationship paths come out canonical. Per ADR-003 the immutable `with_added_slide` is deferred until `@opc.Package` gains a clone API. 7 new tests, 520 total × 4 backends.
- **2026-05-23** — Phase 5b2 done: `Presentation::new()` assembles a minimal-but-valid blank PPTX from XML-literal templates (theme / slide master / Blank layout / presentation.xml + all .rels) and a generated `[Content_Types].xml`. The package is opened-and-re-wrapped so the resulting `Presentation` is structurally identical to one from `open(bytes)`. The XML-literal approach (rather than constructing typed model values from scratch) sidesteps the writer's reliance on captured `<p:cSld>` wrappers. 5 new tests, 513 total × 4 backends.
- **2026-05-23** — Phase 5b1 done: typed `presentation.xml` parser + writer in `@presentation`. New `PresentationPart` exposes `sld_master_ids` / `sld_ids` (drives ordering) / `notes_master_id` / `handout_master_id` / `sld_sz` / `notes_sz` + ADR-004 extension for everything else. `Presentation::slides()` now uses `<p:sldIdLst>` source order, falling back to package storage order only when there's no main-document relationship (malformed PPTX). New `Presentation::presentation_part()` exposes the typed metadata for builder consumers. 4 new tests, 508 total × 4 backends.
- **2026-05-23** — Phase 5a done: `src/presentation/` sub-package introduces the high-level `Presentation` façade. `Presentation::open(bytes)` / `save()` wrap an `@opc.Package`; typed accessors (`slides` / `themes` / `slide_masters` / `slide_layouts` / `notes_slides` / `comment_lists` / `comment_authors`) walk parts by content type and parse lazily. New `PptxError` aggregates each sub-package's failures via per-source `*Failure(String)` variants. Slide ordering follows package storage order — true `<p:sldIdLst>` order lifts in Phase 5b. The struct field is `pkg : @opc.Package` because `package` is a reserved MoonBit keyword. 8 new tests, 504 total × 4 backends.
- **2026-05-23** — Refactor pass after Phase 4: consolidated `write_clr_map_override` (was byte-identical in `@slide_master/writer.mbt` and `@slide/writer.mbt`) into a single public helper in `@slide_master`; extracted PPTX content-type strings into `@oxml/content_types.mbt` so Phase 4g fixtures and the upcoming `Presentation::new()` reference one set of constants; refreshed README phase-status banner ("Phase 3 closed" → "Phase 4 closed") and table (Phase 4 → Done, Phase 5 → Next). 496 tests still pass × 4 backends.
- **2026-05-23** — CI fix for moon 0.1.20260522: adopted the new `impl Trait for T with fn method(...)` keyword across every `Show` impl (~26 files), dropped explicit aliases from every `moon.pkg` import (`"path/foo" @foo` → `"path/foo"` auto-aliases from the last segment), and migrated `moon.mod.json` → `moon.mod` (TOML format). No semantic changes. Phase 4 commits 0daff60..7eb0b71 had been green locally but failed `moon fmt --check` on CI runners that picked up the newer toolchain.
- **2026-05-22** — Phase 4 closed: writer slices 4a (`@comments`) → 4b (`@theme`) → 4c (`@oxml` Color / Fill / Stroke / EffectList) → 4d (`@slide_master`) → 4e (`@slide` + `@slide.CustomGeometry`) → 4f (`@notes`) → 4g (end-to-end golden in `@integration`). Floor is `parse → serialize → parse → Eq`; verified across the three synthetic decks for Theme / SlideMaster / SlideLayout / Slide / NotesSlide / CommentAuthorList / CommentList. Key correctness fix during 4e: `<p:cNvPr>` / `<p:cNv*Pr>` are captured wholesale by the parser, so the writer re-emits the captured element instead of synthesising — synthesis would duplicate the wrapper in the round-tripped extension. 83 new tests across the phase, 413 → 496 total × 4 backends.
- **2026-05-21** — Phase 3i done: `src/integration/` test-only package adds the end-to-end deck round-trip floor. Three synthetic fixtures (`minimal_deck` / `rich_deck` / `notes_and_comments_deck`) hand-built from compositional XML helpers (`fixture_theme_xml` / `fixture_master_xml` / `fixture_layout_xml` / `fixture_simple_slide_xml` / `fixture_rich_slide_xml` / `fixture_notes_xml` / `fixture_authors_xml` / `fixture_comments_xml`) exercise every Phase 3 parser via `Package::open` → `parse_everything` (content-type dispatch). Real-world `.pptx` files remain out of scope per TODO Q4. `Package.to_bytes` → reopen → re-parse equality verified on Slide / Theme / NotesSlide / CommentList. New `moon.pkg` pattern: `import { … } for "test"` block scopes test-only deps so `moon check` doesn't flag them as unused. 14 new tests, 413 total × 4 backends. **Phase 3 (Read path) closed.**

(Detailed changelog: `CHANGELOG.md`, populated from Phase 9 onward.)
