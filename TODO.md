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
- [ ] First commit pushed to `origin/main` (awaiting user authorization)

---

### Phase 1 — Foundations: units & XML *(in progress)*

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

### Phase 2 — OPC layer over fzip

DoD: read/write a PPTX (or any OPC package) at the part-and-relationship level.
You can `Package::open(bytes)`, list parts, pick `[Content_Types].xml`, write
back, and the result is openable in PowerPoint.

- [ ] `opc::Package` struct
  - [ ] `open(bytes : FixedArray[Byte]) -> Package raise OpcError`
  - [ ] `to_bytes() -> FixedArray[Byte]`
  - [ ] `parts() -> Array[Part]` and `part_by_name(name) -> Part?`
- [ ] `opc::Part`
  - [ ] `name : String` (PartName, starts with `/`)
  - [ ] `content_type : String`
  - [ ] `bytes : FixedArray[Byte]` and `text() : String`
- [ ] `opc::Relationship` and `opc::Relationships`
  - [ ] Relationship targets, types, IDs
  - [ ] Helper: traverse from main `presentation.xml` outward
- [ ] `opc::ContentTypes`
  - [ ] Default and Override entries
  - [ ] Auto-update on add/remove of parts
- [ ] Round-trip test: load a real `.pptx` from `test_fixtures/`, dump and reload,
      ensure all parts and rels survive byte-equal (modulo XML formatting).

---

### Phase 3 — Read path: parse OOXML to model

DoD: parse a non-trivial PPTX into our typed model (`Presentation`, `Slide`,
`Shape`, …) with **lossless preservation** of unknown XML chunks.

- [ ] Theme parser (`a:theme`)
- [ ] Slide master / layout parsers + inheritance resolver
- [ ] Slide parser: shapes, group shapes, connectors, pictures, tables, charts
- [ ] Text parser: paragraph, run, list style, font, hyperlink
- [ ] Fill / stroke / effect parsers
- [ ] Geometry parser (preset + custom)
- [ ] Chart XML parser (read all 13 types as data — creation comes later)
- [ ] Speaker notes, comments
- [ ] **Unknown-element preservation strategy** decided and implemented
      (recommend: every model node carries `extension : Array[XmlElement]`)
- [ ] End-to-end test: open 3+ real-world decks, dump model, no panics, no data loss

---

### Phase 4 — Write path: serialize model to OOXML

DoD: any model produced by Phase 3 reads can be re-serialized and reopened by
PowerPoint with no warnings or visual diffs.

- [ ] Per-element writers (mirror parsers from Phase 3)
- [ ] Auto-generation of `[Content_Types].xml` and rels from model
- [ ] Numeric ID assignment (shape IDs, rId, etc.) is deterministic
- [ ] Round-trip golden test: read sample, write back, byte-equal after canonical XML pass
- [ ] PowerPoint open verification: manual checklist for sample decks
- [ ] LibreOffice open verification (cross-implementation sanity)

---

### Phase 5 — Builder API: create from scratch

DoD: a user can produce a multi-slide deck with text, shapes, and pictures **without
ever touching XML**, starting from `Presentation::new()`.

- [ ] Embedded blank-template `.pptx` bytes (`template/blank.pptx`)
  - [ ] Choose minimal but valid template (one master, one layout, one slide)
  - [ ] Verify PowerPoint opens it with no warnings
- [ ] `Presentation::new() -> Presentation`
- [ ] `Presentation::open(bytes) -> Presentation raise PptxError`
- [ ] `Presentation::save() -> FixedArray[Byte]`
- [ ] `Presentation::slides() -> SlideCollection`
- [ ] Builder methods (immutable):
  - [ ] `slides.add(layout : SlideLayout) -> Slide`
  - [ ] `slide.with_shape(s : Shape) -> Slide`
  - [ ] `TextBox::new().with_text(...).with_font(...)`
  - [ ] `Rectangle::new().at(x,y).size(w,h).with_fill(...)`
  - [ ] `Picture::from_bytes(...)`, `Picture::from_path(...)` (Native only)
- [ ] Type-safe layout selection (placeholder schema as type parameter — stretch goal)
- [ ] Cookbook example: build a 5-slide pitch deck end-to-end

---

### Phase 6 — Tables

DoD: create, modify, and read tables matching python-pptx feature parity.

- [ ] Table builder: `Table::new(rows, cols).at(...).size(...)`
- [ ] Cell merging (grid_span, row_span)
- [ ] Cell text, fill, borders, margins
- [ ] Table styles
- [ ] Read existing tables losslessly

---

### Phase 7 — Charts (creation)

DoD: create `bar`, `line`, `pie` charts from data; read all 13 types losslessly.

- [ ] Phase 7a: read all 13 chart types into `ChartData` (already designed for in Phase 3)
- [ ] Phase 7b: write `bar`, `line`, `pie` from-scratch
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
- **Date**: 2026-05-10
- **Status**: Proposed
- **Context**: OOXML has many extension elements (Office variants, third-party). Dropping unknowns silently corrupts files for users.
- **Decision**: Every parsed model node carries an `extension : Array[XmlElement]` capturing children we did not recognize. Writers emit them back verbatim.
- **Consequences**: Slightly heavier model; full round-trip safety even for incomplete coverage.

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

| # | Question | Owner | Needed by |
|---|---|---|---|
| Q1 | Confirm Native backend works with all needed MoonBit core APIs (esp. Int64 for EMU) | — | end of Phase 0 |
| Q2 | XML reader: build our own minimal parser or look for a mooncakes XML lib? | — | start of Phase 1 |
| Q3 | How do we ship the embedded blank template (binary file vs hex literal in source)? | — | start of Phase 5 |
| Q4 | Which real-world `.pptx` files do we use as fixtures, given license/copyright concerns? | — | end of Phase 2 |
| Q5 | Chart embedded XLSX — do we generate it or treat as opaque cache? | — | start of Phase 7 |
| Q6 | How do we expose backend differences (Native file APIs vs Wasm-GC byte-only) cleanly? | — | start of Phase 5 |

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

(Detailed changelog: `CHANGELOG.md`, populated from Phase 9 onward.)
