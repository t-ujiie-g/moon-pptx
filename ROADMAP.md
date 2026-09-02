# moon-pptx — Roadmap & Architecture

> Pure-MoonBit library for reading, building, and writing PPTX (OOXML)
> presentations with a type-safe builder API. Published on
> [mooncakes.io](https://mooncakes.io/docs/t-ujiie-g/moon-pptx) as
> `t-ujiie-g/moon-pptx`.

This document is the **single source of truth** for development
direction, design decisions (ADRs), open questions, and risks. It is
**forward-looking**: what is already shipped lives in `CHANGELOG.md`
(release notes) and in git history — this file describes where the
project is going.

Two things deliberately live elsewhere:

| Looking for | Read |
|---|---|
| What each release changed | `CHANGELOG.md` |
| How moon-pptx compares to python-pptx / PptxGenJS | `README.md` § Comparison |

---

## 0. Project at a glance

| Item | Value |
|---|---|
| Module ID | `t-ujiie-g/moon-pptx` |
| Current version | `0.8.0` (2026-09-01 — RTL / bidi, `endParaRPr`, Asian-script fonts + theme font resolution; additive) |
| Release policy | **v1.0.0 ships when MoonBit itself reaches v1.0** (decided 2026-07-06 — see ADR-012). Additive-only; the one sanctioned exception, the ADR-015 API-shape pass, has run and is closed (ADR-016). The next release is `0.9.0` — it carries those breaks |
| Test suite | 1215 tests × 4 backends (Native / Wasm-GC / JS / Wasm), all green |
| License | Apache-2.0 |
| MoonBit toolchain | `moon 0.1.20260827` or newer (raised 2026-09-01 — the tree uses the `StringBuilder(size_hint=…)` constructor and `extend T with Show::{to_string}` declarations) |
| Primary backend | Native; CI matrix also runs `wasm-gc` / `js` / `wasm` |
| Buffer type | `FixedArray[Byte]` (matches `hustcer/fzip` + MoonBit core) |
| Required deps | `hustcer/fzip` (DEFLATE + ZIP, pure MoonBit) |
| Differentiator | All 16 standard chart families built from typed data (9 extended chartEx read / written / attached, no typed builder yet — G11); SmartArt build; animation DSL; lossless preservation; type-safe units; multi-backend |

**Feature-complete for the core mission.** The §1 vision goals are
delivered and the v0.6.0 breaking pass has spent the pre-1.0 breaking
budget, so everything from here to 1.0 is additive. What remains is
*quality and reach*, not breadth — see §3 for the honest gap list and §4
for the 1.0 gate.

---

## 1. Vision

Make moon-pptx **the most capable PPTX library in any language**, by:

1. **Matching python-pptx** on every read+build feature. ✅ delivered
2. **Matching PptxGenJS** on every generation feature. ✅ delivered
3. **Exceeding both** with features only MoonBit's type system can
   deliver: compile-time placeholder schema, ADT-driven exhaustive
   options, typed builder state machines. ✅ delivered
4. **Closing gaps neither library covers**: SmartArt builder, animation
   DSL, transition builder, lossless diff-write. ✅ delivered

The remaining vision work is *quality*, not breadth: verification depth
(Tier 3), text-shaping reach (RTL / bidi), and API stability for the 1.0
freeze.

### Design pillars
1. **Pure MoonBit, mooncakes-publishable** — no FFI; single source compiles to Native / Wasm-GC / JS / Wasm.
2. **Type-safe units** — `Emu`, `Pt`, `Inch`, `Cm`, `Angle`, `Percentage`, `RgbColor` are distinct types with explicit conversions.
3. **Immutable builders** — `slide.with_shape(s)` returns a new value; `_mut` for in-place edits of existing decks (ADR-003).
4. **ADT-driven model** — `Fill` / `Stroke` / `Effect` / `Shape` are enums; pattern match instead of attribute soup.
5. **Lossless round-trip** — unknown OOXML is preserved verbatim via `extension : Array[XmlElement]` (ADR-004).
6. **Verification over assertion** — "opens without a repair prompt" is a CI job, not a claim (ADR-011).

### Non-goals
- Drop-in Python or JS compatibility (no `python-pptx`-style import shims).
- Render to image / PDF / HTML — out-of-scope for this library; a separate companion can layer on top.
- Every legacy PPT (binary `.ppt`) feature.
- Macros / VBA execution; EMF / WMF rasterization (binary preserved on read, no creation).

---
## 2. Architecture

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
├── chart_ex/        Extended chartEx — waterfall, treemap, sunburst, funnel, boxWhisker, paretoLine, regionMap, clusteredColumn, histogram
├── smartart/        SmartArt (DiagramML) builder — typed SmartArt/Node model + five-part generation with cached dsp:drawing
├── presentation/    High-level Presentation façade — open / save / new + slide / picture / chart / SmartArt insertion
└── integration/     Test-only — synthetic fixtures + round-trip floor + cookbook compile-checks + OPC integrity
```

`examples/` has two complementary entry points:
- `examples/README.md` — cookbook of focused recipes (one feature per
  section), each verified by `src/integration/examples_test.mbt`.
- `examples/sample-deck/` — a standalone MoonBit module with its own
  `moon.mod`, depending on `t-ujiie-g/moon-pptx@<version>` exactly the
  way a downstream consumer would. Its `moon.work` lists `../..` as a
  workspace member, so in-repo development resolves the local library
  while the dependency line stays consumer-shaped.

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

## 3. What is *not* done yet

The feature matrix vs python-pptx and PptxGenJS lives in
`README.md` § Comparison. This section is the inverse: the honest list of
what moon-pptx still cannot do, so it is obvious what is worth picking up
next.

Legend: **❌** no support · **△** round-trips losslessly via `extension`
(ADR-004) but has no typed API.

### 3.1 Feature gaps

| # | Gap | State | Why it is open | Size |
|---|---|---|---|---|
| G3 | **WordArt / preset text warp** (`<a:prstTxWarp>`) | △ | Typed warp presets over the existing `bodyPr`; 40-odd preset names | M |
| G4 | **3-D shape effects** (`<a:scene3d>` camera/light, `<a:sp3d>` bevel/extrusion) | △ | Typed builder; large surface, low demand so far | M–L |
| G6 | **Equation editor** (Office Math, `<m:oMathPara>`) | △ | A whole second markup vocabulary; only worth it with a concrete consumer | L |
| G7 | **Form fields / ink** (`<p:contentPart>`) | △ | Same shape as G6 — niche, preserved losslessly today | M |
| G8 | **p14 extended slide transitions** | △ | Base `CT_SlideTransition` is typed; the Office 2010 extension set round-trips only | S–M |
| G9 | **Streaming write for huge decks** | ❌ | `save()` materialises the whole package. Needs an incremental write API in `hustcer/fzip` (likely an upstream PR). Gated on the §4.2 benchmarks | L |
| G10 | **Resource limits on untrusted input** | ❌ | `Package::open` hands the whole archive to `@fzip.unzip_sync` (`src/opc/package.mbt:30`) with no cap on part count or total uncompressed size, so a zip bomb exhausts memory before any moon-pptx code runs. Nothing is written to disk, so zip-slip does not apply. Wants opt-in ceilings surfaced as `OpcError`, which matters the moment anyone parses user-uploaded decks server-side | S–M |
| G11 | **Typed builder for the chartEx families** | △ | `@chart_ex` parses, round-trips and serialises the Microsoft 2016 set, and `Presentation::add_chart_ex_mut` does the OPC plumbing — but `ChartEx` exposes only `parse` / `serialize`, so *building* one means writing `<cx:chartSpace>` by hand. The project's own test does exactly that (`src/presentation/add_chart_test.mbt:135`). Until this closes, "creatable" is the wrong word for chartEx, and `README.md` says so. Wants `ChartExData` + `ChartEx::of_waterfall` / `of_treemap` / … mirroring `@chart`'s `ChartData` + `Chart::of_bar` | M–L |
| G12 | **Builders for the model records that have none** | ❌ | Around 50 `pub(all) struct` expose no constructor, no `with_*`, in most cases no `pub fn` at all — a record literal is the only way to build one. The chart internals are the bulk (`Trendline`, `ManualLayout`, `Layout`, `DLbl` / `DLbls`, `NumFmt`, `Scaling`, `AxisCore`, `ChartTitle`, `ChartLegend`, `PlotArea`, the fifteen `*Body` / `*SeriesCore` records), with `Pattern`, `TileSpec`, `FillRect`, `SysColor`, `ArrowEnd` and the `CustomGeometry` family alongside. Each one a caller has a real reason to construct — a trendline on a series, a manual legend layout — and giving it a builder is a feature in its own right, not API tidying. Overlaps G11: a `ChartExData` builder and a chart-internals builder are the same work. See ADR-016 for why the visibility side of this stopped where it did | L |

G1 (RTL / bidi text), G5 (`endParaRPr`) and G2 (Asian-script fonts) closed
in 0.8.0; the IDs are retired rather than reused so older references still
resolve. Of what is left, G8 is the smallest.

### 3.2 Verification gaps

| # | Gap | State |
|---|---|---|
| V1 | **Tier 3 (manual)** — PowerPoint 2019 / 2021 / 365 / Online open-without-warning pass; LibreOffice Impress + Keynote render parity | 🔴 not started for the 1.0 cycle (spot-checked in PowerPoint Web at v0.6.0) |
| V2 | **Benchmarks** — build / save / parse throughput at 10 / 100 / 1000 slides; peak RSS; comparison vs python-pptx + PptxGenJS | 🔴 not started |
| V3 | **LibreOffice-headless convert-to-pdf** as an optional second opinion in Tier 2 CI | 🟡 optional, unstarted |

Tiers 1 and 2 are automated and green (ADR-011): OPC structural
invariants run on every `moon test`, and the Open XML SDK validator runs
in CI over generated decks plus the 7-file real-world corpus.

### 3.3 Housekeeping

| # | Item | Note |
|---|---|---|
| H1 | Split `examples/sample-deck/main` into a library package + thin entrypoint | `moon check` warns that main packages will stop generating blackbox tests in a future MoonBit release; the deck's tests live in `main/showcase_test.mbt` |
| H2 | `XmlReader` over `StringView` instead of `Array[Char]` | `XmlReader::new` copies every part into `Array[Char]` (`src/xml/reader.mbt:83`), so peak memory, not just throughput, scales with part size — which makes this part of the same problem as G10, not only a V2 benchmark question. Blocked on wanting code-point (not UTF-16 code-unit) indexing |
| H3 | Five XML helpers (`skip_subtree`, `next_event`, `collect_subtree_unknown`, `optional_attr`, `require_attr`) are duplicated across six packages | `@oxml` exports public equivalents; each package keeps a copy so the helper raises *its* suberror instead of `XmlReadError`. Deduplicating means either giving up per-subdomain error typing or finding a generic-over-error formulation. Accepted for now — logged so it is not mistaken for an oversight |
| H4 | Fold `src/integration/readme_test.mbt` back into `README.mbt.md` | `moon 0.1.20260827` collects no tests from `.mbt.md` files or from `///` doc comments — verified with a deliberately failing probe in both a source package and the test-only package, and `--doc-index 0` reports `no test entry found`. So the `.mbt.md` extension currently buys nothing but the `readme` field in `moon.mod`, and the README's blocks stay `nocheck` with a mirrored test carrying the actual verification. Recheck when the toolchain (or the new TOML `moon.pkg` format) grows markdown/doc tests, then delete the mirror |
| H5 | Repository discoverability | No GitHub description, no topics, no Releases. `v0.8.0` already has a CHANGELOG entry that can be pasted into a release verbatim. Costs minutes and is the only thing standing between the module and anyone finding it |
| H6 | A rendered screenshot at the top of `README.md` | The comparison matrix runs ~40 rows without a single image of what the library actually emits. `tools/pptx-validate/gen-pptx.sh` already builds a showcase deck in CI — one rendered slide from it would do more work than the matrix |

---

## 4. Roadmap

**v1.0.0 ships when the MoonBit toolchain itself reaches v1.0**
(ADR-012). The one sanctioned break, ADR-015's API-shape pass, has run and
is closed (ADR-016); releases are additive-only again, so the version
number is the only thing waiting on MoonBit.

### 4.1 Next (unversioned, additive)

No dated cycle is committed. Work is pulled from §3 and §5 as demand
appears. The one item that had a deadline — ADR-015's API-shape pass — has
run and is closed (ADR-016), so nothing below is racing the 1.0 tag.
Suggested order, highest value first:

1. **Cut `0.9.0`** — the breaking pass is done and sitting in
   `[Unreleased]`. Releasing it is what lets consumers migrate once
   instead of tracking `main`.
2. **H5 / H6 reach** — description, topics, a GitHub Release, one
   screenshot. Minutes of work, and everything below is worth less while
   nobody can find the module.
3. **V2 benchmarks** — they gate the streaming-write decision (G9)
   and are required for the 1.0 gate anyway. Doing them early turns a
   guess into a number.
4. **G10 input limits** — small, and the difference between "a library
   that parses decks" and "a library you can point at uploads".
5. **H1 sample-deck split** — forced eventually by the toolchain; cheap
   to do before it becomes an error.
6. **G12 / G11 builders** — the largest remaining feature gap, and the
   only way the ~50 records ADR-016 froze as `pub(all)` ever become
   field-additive. Worth doing before 1.0 for that reason, but it is a
   feature design, not a deadline.
7. **G8 p14 extended transitions** — small, and the base transition model
   is already typed.
8. **A theme builder** (§5) — font resolution now reads the theme, but
   nothing can *write* one, so "make this whole deck Japanese" still means
   setting fonts run by run.

### 4.2 The v1.0.0 gate

DoD: MoonBit toolchain v1.0 is out; API surface frozen; verification
matrix fully green (Tier 3 included); benchmarks published.

🔴 **API stability review — final pass**
  - `pkg.generated.mbti` diff vs `0.9.0` must be additive only. The
    ADR-015 breaks are spent; ADR-016 closed that window.
  - The diff is not the whole test: a field added to a `pub(all) struct`
    reads as purely additive and still breaks exhaustive record literals
    downstream. The ~50 records G12 covers are the ones this applies to —
    confirm the list has not grown by reading the types, not the diff.
  - Anything still marked experimental is stabilised or cut.

🟡 **Verification matrix** (three-tier pyramid, ADR-011) — V1 / V3 in §3.2.

🔴 **Benchmarks** — V2 in §3.2. If large-deck numbers disappoint,
streaming write (G9) gets promoted onto the roadmap.

🔴 **CHANGELOG cleanup + 1.0 announcement** — final release notes; blog
post / mooncakes announcement. State plainly what the tag does *not*
promise: the `pub(all)` records G12 has not reached, and every
`pub(all) enum`, gain fields and variants only as breaking changes from
1.0 onward (ADR-016).

---
## 5. Open ideas (uncommitted)

Speculative — no commitment, tracked so they don't get lost. Concrete
*gaps* (things a competitor does, or that we round-trip but can't build)
live in §3 instead; this list is for ideas that would be genuinely new.

- **Theme builder DSL** — `Theme::default().with_accent_palette([...])` for tweakable presets
- **Master / layout cloning + edit** — `SlideLayout::clone().with_…`
- **`replace_slides` high-level helper** — convenience wrapping "clear + rebuild": keep the master/layout/theme, swap in generated slides in one call
- **Bullet-list typed parents** — enforce indent-depth at the type level
- **Compare two decks** — diff at the typed-model layer
- **Trait-based shape extensibility** — `trait CustomShape`, third-party `Shape::User(...)` variants
- **PDF export / HTML export** — a separate companion module consuming moon-pptx plus a rasterizer; explicitly out of scope for this library (§1 non-goals)

---
## 6. Architecture decision records (ADRs)


Append-only. Each decision gets a heading, date, status, context, decision, consequences.

### ADR-001: Use `hustcer/fzip` for ZIP/DEFLATE
- **Date**: 2026-05-10
- **Status**: Accepted
- **Context**: PPTX is a ZIP container. We need pure-MoonBit ZIP read/write.
- **Decision**: Depend on `hustcer/fzip`. Pure MoonBit, fflate-derived, 220+ tests, actively maintained, security-hardened. **Pinned at `0.8.2`** (bumped from the original `0.6.1` on 2026-06-16 — see `CHANGELOG.md`).
- **Consequences**: Saves 1–3 months of self-implementing DEFLATE. Bound to fzip's API and maintenance cadence — acceptable since fzip is shipping multiple releases per week and the API surface we use is small (`zip_sync` / `unzip_sync` / `str_to_u8` / `str_from_u8` / `FzipError`). The narrow surface kept the 0.6→0.8 bump non-breaking (every new parameter is optional).

### ADR-002: Native primary; Wasm-GC + JS verified in CI; LLVM and legacy Wasm excluded
- **Date**: 2026-05-10
- **Status**: Superseded by ADR-014 (legacy Wasm is now in the CI matrix)
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
- **Status**: **Superseded by ADR-013** (2026-09-01)
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
- **Status update (2026-07-06)**: B3 moved off the v1.0 gate to the v0.7.x additive cycle (shipped in v0.7.0) — it is a feature, not a stability item, so it should not block the 1.0 tag.
- **Status update (2026-07-11)**: B3 landed — `add_chart_mut(embed_data=data)` generates the embedded workbook and the `<c:externalData>` reference. The decision itself stands: inline literals remain the (only) render source; the xlsx is a pure Edit-Data UX add-on and stays opt-in.

### ADR-010: SmartArt = own `src/smartart/` package, build-only, cached-drawing render guarantee
- **Date**: 2026-06-11
- **Status**: Accepted (anchored in v0.5 D1 slice 1)
- **Context**: A SmartArt graphic is the most multi-part construct in OOXML: a `<p:graphicFrame>` whose `<dgm:relIds>` references four DiagramML parts (data / layout / quickStyle / colors), and — to render without re-running PowerPoint's layout engine — a fifth cached `<dsp:drawing>` part holding the laid-out shapes. Authoring a full `<dgm:layoutDef>` *layout algorithm* per family is large and hard to verify outside PowerPoint; neither python-pptx nor PptxGenJS attempts SmartArt creation at all.
- **Decision**: (1) **New `src/smartart/` package** (ADR-005 sub-package model) owns the typed `SmartArt` / `Node` model and emits the five part byte-blobs; the OPC orchestration (`Presentation::add_smartart_mut`) lives at the presentation layer like charts / media / SVG. (2) **Cached drawing is the render contract** — we compute box positions ourselves and emit a complete `<dsp:drawing>`, so the diagram renders even where the layout engine isn't run (PowerPoint < 2010, thumbnails); the layout/colors/quickStyle parts are minimal valid definitions consulted only on *edit*. (3) **Reuse the `OtherGraphic` round-trip path** for the graphicFrame body rather than a typed `GraphicFrameContent::DiagramContent` — a parsed SmartArt already round-trips that way (ADR-004), so building the `<dgm:relIds>` by hand needs no parser/writer change. (4) **Build-only** (like A6 media / D2 animations): a parsed `<dgm:relIds>` + diagram parts round-trip losslessly via `extension` / opaque OPC parts; the typed `SmartArt` is a deliberately lossy *build* model, not lifted on parse. (5) **Sliced delivery** — slice 1 ships the linear `List` / `Process` families; hierarchical families layer on the same model + five-part pipeline additively.
- **Consequences**: SmartArt is creatable in moon-pptx — a feature neither competitor offers — with zero parser/writer churn and lossless round-trip preserved. Adding a family is a new `SmartArtKind` + its drawing layout + (optionally) a richer data-model shape — no new parts or relationship plumbing.
- **Status update (2026-06-16, PowerPoint Web verification)**: decision (2)'s premise is **wrong for PowerPoint Web** — it re-lays-out SmartArt from the `layoutDef` on open and does **not** use the cached `<dsp:drawing>`. So the cached drawing is *not* a universal render contract; it helps only non-editing/older viewers. With our single-level `layoutDef forEach`, the 5 flat families render fully but the 3 nesting families render top-level only. This does **not** supersede the package/round-trip/build-only decisions — only the "render guarantee" claim. The robust fix (future ADR if adopted) is a recursive hierarchy `layoutDef`, making the `layoutDef` — not the cached drawing — the primary render path.
- **Status update (2026-07-06, D1-b)**: the robust fix landed — `hier_layouts.mbt` ships recursive hierRoot/hierChild layoutDefs for OrgChart / Hierarchy and a radial (`cycle` + `ctrShpMap="fNode"`) one for Relationship, making the `layoutDef` the primary render path for the nesting families; the cached drawing (now including parent→child connector lines) remains the fallback for non-editing viewers. See `CHANGELOG.md` (v0.6.0).

### ADR-011: Three-tier verification pyramid; automate "opens without repair"
- **Date**: 2026-06-20
- **Status**: Accepted
- **Context**: "Generated decks open in PowerPoint without a repair prompt" is a core promise (§0), but until now it was only ever checked by a human opening a deck. Multiple real bugs were caught that way, **late** — `define_master` master/layout id collisions + shared-theme repair (2026-05-30), foreign-namespace prefix scoping producing a dangling `rId` on a two-media slide (2026-05-30), invalid chart `dLblPos` blanking a slide (2026-06-07), SmartArt nesting render (2026-06-16). The whole class of "PowerPoint repair" triggers is mechanically detectable — it is schema violations (element order, required attrs, value types), OPC integrity (missing content types, dangling relationship targets, unresolved `r:id`s), and reference breakage — none of which needs a running PowerPoint to find. The synthetic `src/integration/` fixtures (Q4) deliberately omit per-part `.rels` (parser-floor scaffolds, not valid OPC packages), so they cannot serve as the "no-repair" evidence base.
- **Decision**: Adopt a **three-tier verification pyramid**, automating the bottom two:
  - **Tier 1 — in-repo MoonBit (every `moon test`, all backends, FFI-free)**: a structural-integrity checker over assembled packages (`src/integration/integrity_test.mbt`) asserting the OPC-integrity invariants — content-type coverage, every Internal relationship target resolves to a real part, every `r:`-namespaced attribute (`r:id`/`r:embed`/`r:link`/`r:dm`/…) resolves to a declared relationship. Run over the library's own **builder/save output** (the product that must be repair-clean), not the rels-incomplete synthetic fixtures. Test-only helper; **not** a public `Presentation::validate()` API (keeps library scope narrow — validation/templating is downstream consumers' role, e.g. `pptz`).
  - **Tier 2 — external validators (CI job, not on the backend matrix)**: `tools/pptx-validate/` runs Microsoft's `OpenXmlValidator` (DocumentFormat.OpenXml) over generated decks + any real-world fixtures in `test_fixtures/corpus/`; a clean run is a high-confidence proxy for "no repair" because the SDK enforces the same schema+semantic constraints PowerPoint does. A short `baseline.txt` absorbs documented false positives (e.g. Microsoft extensions the SDK's typed model predates) — never genuine errors. LibreOffice-headless convert-to-pdf is an optional second opinion (future).
  - **Tier 3 — real apps (release / manual)**: open in PowerPoint 2019/2021/365/Online + LibreOffice Impress + Keynote at the v1.0 verification gate. Ground truth, too heavy for per-PR CI.
- **Consequences**: The two bug classes that historically required a human now fail CI on the PR that introduces them. The external validator is the first non-MoonBit toolchain in the repo (a small C#/.NET project, isolated under `tools/`, only on the `validate` CI job — does not touch the published library or its FFI-free guarantee). Real-world corpus files need license-clear sourcing (Apache POI's Apache-2.0 `.pptx` test data is the lead) and human curation, so the corpus directory ships with sourcing docs and is populated incrementally; the CI job validates whatever is present. The Tier-1 follow-up — embedding real files' bytes as generated `.mbt` to prove the *reader* is lossless on real input across all backends — landed in v0.7.0.

---

### ADR-012: v1.0.0 is gated on MoonBit reaching v1.0
- **Date**: 2026-07-06
- **Status**: Accepted; the additive-only clause is amended by ADR-015
- **Context**: The library hit feature-completeness for its core mission well before the language did. Tagging `1.0.0` on a pre-1.0 toolchain would promise an API stability we cannot honour, since a compiler or stdlib break can force our hand at any time.
- **Decision**: `v1.0.0` ships when the MoonBit toolchain itself reaches v1.0. The pre-1.0 breaking budget was spent in one deliberate pass (v0.6.0); every release after it is additive-only, so the 1.0 tag is a formality whenever the toolchain lands.
- **Consequences**: The 1.0 date is externally controlled and may sit open a long time — accepted, because consumers get additive-only guarantees *now* rather than at 1.0. Features keep shipping as 0.x meanwhile. Open question Q13 (what counts as "MoonBit v1.0") is unresolved.

### ADR-013: ROADMAP.md is forward-looking; history lives in CHANGELOG.md
- **Date**: 2026-09-01
- **Status**: Accepted (supersedes ADR-006)
- **Context**: ADR-006 made `TODO.md` the one canonical narrative, which was right while the project was being built but produced a 976-line file that was ~60 % history: a per-cycle shipped-item record, a completed-phases list, and a 138-line living changelog, all duplicating `CHANGELOG.md` and git. Newcomers could not tell current direction from settled past, and the file's own feature matrix had drifted two releases stale because it was buried where no user would read it.
- **Decision**: The file is renamed `ROADMAP.md` and holds only forward-looking material — direction, open gaps, ADRs, open questions, risks, conventions. Release history lives in `CHANGELOG.md`; the narrative record of *how* something was built lives in git history. The feature comparison vs python-pptx / PptxGenJS moves to `README.md`, where its actual audience is. ADR-006's core rule survives intact: **no new planning, decision, or analysis files** — this is still one document, just a smaller one.
- **Consequences**: Contributors update `ROADMAP.md` for scope and decisions, and `CHANGELOG.md` for what shipped, instead of writing both plus a living-changelog entry. `AGENTS.md` and `CLAUDE.md` point at the new name. The pre-rename history is recoverable with `git log -- TODO.md` (151 commits; deleted paths keep their history) or `git show v0.7.1:TODO.md` for the last full copy. Note `--follow` does *not* bridge the two files — the rewrite was too large for git's rename detection. Risk: the comparison table in `README.md` must be refreshed at each feature release or it drifts again — mitigated by adding it to the release checklist (§9).

### ADR-014: Legacy Wasm joins the CI matrix
- **Date**: 2026-09-02
- **Status**: Accepted (supersedes the legacy-Wasm exclusion in ADR-002)
- **Context**: ADR-002 excluded legacy Wasm as superseded by Wasm-GC, but §0, §2 and `README.md` § Compatibility all claimed four backends were tested in CI while `.github/workflows/ci.yml` ran three. For a project whose stated principle is that verification outranks claims, that gap had to close in one direction or the other. `moon test --target wasm` passes the full suite locally with no backend-specific code.
- **Decision**: Add `wasm` to the `test` matrix. The claim in the docs becomes true rather than being walked back, at the cost of two extra CI jobs.
- **Consequences**: Legacy Wasm is now a supported backend that a regression can block a PR on. If it later diverges enough to cost more than it proves, dropping it means a superseding ADR *and* the same edit to §0, §2 and the README table — the three places that must stay in lockstep with the matrix.

### ADR-015: One more breaking pass before 1.0, scoped to API shape
- **Date**: 2026-09-02
- **Status**: Accepted (amends the additive-only clause of ADR-012)
- **Context**: ADR-012 declared the pre-1.0 breaking budget spent at v0.6.0 and every later release additive-only. §3.4 is the class of problem that promise cannot accommodate: argument shape and type visibility that 1.0 would freeze permanently. A2 — four consecutive `@units.Emu` where `x`↔`y` swaps compile silently — has no additive fix; a parallel labelled constructor beside every positional one would double the surface being frozen. ADR-012's own reasoning cuts this way: the 1.0 date is externally controlled, so an additive-only promise held until an unknown date is worth less than the API being right when the freeze lands.
- **Decision**: One further breaking pass, scoped to §3.4 (argument labelling and `pub(all)` visibility) and nothing else, lands before 1.0 in the `0.9.x` line. Behaviour, semantics and emitted file bytes do not change — a caller who updates the call sites gets byte-identical output. Every breaking change ships with a CHANGELOG migration note precise enough to apply mechanically. Additive-only resumes once §3.4 closes, and if MoonBit reaches 1.0 while §3.4 is open, §3.4 finishes first.
- **Consequences**: Consumers pinned to `0.8.x` face one mechanical migration instead of living with the shape permanently. The §4.2 stability gate now has something to check against — "additive since the last 0.x" is no longer the whole test, since ADR-015 sanctions a known set of breaks and nothing outside it.

### ADR-016: The API-shape pass is closed; the remaining records stay `pub(all)`
- **Date**: 2026-09-03
- **Status**: Accepted (closes the pass ADR-015 opened)
- **Context**: ADR-015 sanctioned one breaking pass for API shape and said additive-only resumes when it closes. It has run: arguments are labelled (A2), shape ids are allocated rather than guessed (A3), and 39 model records plus the eight `<a:effectLst>` records dropped to `pub`. What is left is around 50 records with no construction path at all — the chart internals and a handful elsewhere. Giving those a builder is designing a feature (an API for adding a trendline, for placing a legend by hand), not tidying an API, and it overlaps G11. Keeping a breaking budget open while that gets designed would leave the window open indefinitely, which is the opposite of what ADR-015 was for.
- **Decision**: The pass is closed, and §3.4 — the section ADR-015 names — is retired with it, since ADR-013 keeps this file forward-looking and the passes themselves are in `CHANGELOG.md`. Every release from here is additive-only again, including 1.0. The remaining `pub(all)` records are tracked as **G12** — a builder gap, not a visibility gap. If a builder lands for one of them before 1.0, its visibility drops in the same change; after 1.0 it keeps the visibility it has.
- **Consequences**: Those ~50 records are frozen as `pub(all)` at 1.0, so adding a field to any of them stays a breaking change forever — the cost of leaving them constructible, and the reason G12 is worth doing before the tag rather than after. Two rules the pass produced are worth keeping: a type with a public `serialize` is an **authoring target** and stays constructible whatever else it exposes; and a visibility sweep must be checked against `examples/sample-deck`, the only in-repo code that consumes the public API as a downstream module (`CLAUDE.md` §3).

  The 93 `pub(all) enum` declarations were never in scope, because nothing can be done about them. Adding a variant breaks exhaustive matches downstream, and that breakage is on the *matching* side, which plain `pub` still allows — so visibility is not the lever. `moon 0.1.20260827` has no `#non_exhaustive` equivalent either (`#non_exhaustive`, `#open` and `#extensible` are all rejected as `unknown attribute`), and the enums used as builder inputs — `Anchor`, `PresetShape`, `ThemeColor` — must stay `pub(all)` regardless, since callers construct their variants. So 1.0 freezes the variant lists as they are: a new shape preset, fill kind or transition kind is a breaking change from the tag onward. Worth stating in the 1.0 announcement rather than discovering later.

---

## 7. Open questions


Open:

| # | Question | Owner | Needed by |
|---|---|---|---|
| Q6 | How to expose backend differences (Native file I/O vs Wasm-GC byte-only) cleanly? | — | if/when `Presentation::open_path` / `save_path` ship (no committed version) |
| Q13 | v1.0 gate: what counts as "MoonBit v1.0"? (a stable-toolchain announcement vs a literal `1.0.0` version tag) | — | when MoonBit announces its 1.0 plan |

Resolved:

- **Q8 (SmartArt: which layouts ship first)** — resolved by D1 slices 1–4 (2026-06-12): all eight families shipped in v0.5.0, flat families first (list / process, then cycle / pyramid / matrix), hierarchical ones (org-chart / hierarchy / relationship) on the generalised tree data model. See ADR-010.
- **Q9 (Animation DSL: reuse custGeom AST for motion paths?)** — resolved at D2 slice 3 (2026-06-09): **no** — `<p:animMotion>` uses 0..1 slide-fraction coordinates while `CustomGeometry::PathCommand` carries EMU/guide shape-space coordinates, so a dedicated fractional `MotionPath` keeps each model in its own units.

- **Q7 (M1 compile-time placeholder schema: per-layout-type vs phantom param)** — resolved at M1 (2026-06-07): **hybrid**. One generic `LayoutSlide[L]` builder (accessors defined once, gated by capability traits `fn[L : HasTitle] …`) + ergonomic per-layout named constructors (`add_title_slide_mut` etc., no caller turbofish). A `/tmp` prototype confirmed phantom-param + capability-trait method-gating enforces at compile time in MoonBit; a bare phantom param trips `unused_type_variable` / `struct_never_constructed` under `--deny-warn`, so the marker is carried as a value field (`marker : L`) and capability traits are methods on it, with `pub impl`s so blackbox tests/consumers can dispatch them. See `CHANGELOG.md` (v0.4.0).
- **Q12 (E3 clone media-dedupe)** — resolved at E3 (2026-06-01): the clone *re-references* the source slide's parts (layout / images / charts / media / notes) rather than deep-copying them. Slide `.rels` is slide-local and both slides live in `/ppt/slides/`, so identical relative targets keep the copied slide XML's `rId` references valid, and shared parts stay alive via E1's reference-counted deletion. A fully-independent deep-copy variant is deferred until a consumer needs per-clone editing.

- **Q10 (D6 untouched-part detection)** — resolved at D6 (2026-05-29): neither hashing nor dirty-tracking is needed. The OPC layer retains each part's *source bytes* and only `_mut` operations replace them, so `save()` re-emits untouched parts verbatim by construction. See ADR-004 and `CHANGELOG.md` (v0.3.0).
- **Q11 (B4 shape-edit identity handle)** — resolved at B4 (2026-05-29): id-based (`with_shape_by_id`) + `map_shapes` are primary; index helpers (`with_shape_at` / `with_shape_mapped` / `without_shape`) are thin conveniences. A missing id or out-of-range index raises `SlideError`; `map_shapes` is the non-raising best-effort path. Discovered+fixed the captured-`<p:cNvPr>` shadowing of typed `name`/`id` (see B4 writer-fix note).

- **Q1 (Native + Int64)** — resolved at Phase 1.1 (2026-05-10): `Emu = Int64` round-trips on `native` / `wasm-gc` / `wasm` / `js`.
- **Q2 (XML reader)** — resolved at Phase 1.3 (2026-05-10): self-implemented event-based reader (`src/xml/`) per ADR-008. No suitable mooncakes lib at the time.
- **Q3 (blank template shipping)** — resolved at Phase 5b2 (2026-05-23): no binary template ships; `Presentation::new()` assembles a blank deck programmatically from XML-literal templates plus the Phase 4 writers.
- **Q4 (real-world fixtures)** — resolved at Phase 3i (2026-05-21): synthetic-but-realistic fixtures in `src/integration/` cover the no-panic + round-trip floor without license concerns.
- **Q5 (Chart embedded XLSX)** — resolved at Phase 7 closure (2026-05-25): builders emit inline `<c:strLit>` / `<c:numLit>` data only; xlsx caches are preserved on round-trip but not generated. See ADR-009.

---

## 8. Risks & mitigations


| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| MoonBit v1.0 timing is external — our 1.0 gate could sit open for a long time | Unknown | Low | Spend the breaking budget now (v0.6.0) and keep every later release additive-only, so 1.0 is a tag whenever the toolchain lands; keep shipping features as 0.7.x meanwhile |
| MoonBit compiler / toolchain breaking changes pre-1.0 (e.g. the 2026-06 `moon.mod` TOML manifest migration) | Medium | Medium | Pin moon version in CI; track changelogs via the `moonbit-orientation` skill; absorb migrations promptly on `main` |
| fzip breaking changes | Low | Low | Pin minor version (`0.8.2`); smoke test catches regressions early |
| PowerPoint vs LibreOffice vs Keynote rendering differences | Medium | Medium | Tier 3 verification matrix at the v1.0 gate (§4.2); Tiers 1–2 already automated (ADR-011) |
| API churn discourages early adopters | Low (was Medium) | Medium | Breaking changes are batched into the one v0.6.0 pass; experimental APIs marked in doc-comments; freeze at 1.0 |
| Performance: large decks → slow build / save | Medium | High | v1.0 benchmarks (§4.2); streaming write (G9, §3.1) promoted only if the numbers demand it |
| Browser bundle size for Wasm-GC | Low | Medium | Track post-v0.3 once chart sub-package is heaviest |

---

## 9. Workflow & conventions

### Development loop
```
moon check --deny-warn   # type check (fast)
moon test --target all   # run all tests, every backend
moon fmt                 # format
moon info                # regenerate pkg.generated.mbti
```

Run all four before committing; CI enforces them. Note that **deprecation
warnings surface under `moon test` / `moon build`, not `moon check`** —
a green `moon check --deny-warn` is not evidence the tree is warning-free.

### Model records
- Construct model records by spreading a constructor —
  `{ ..ParagraphProperties::default(), bullet: Some(…) }` — never by
  listing every field. Adding a field to a `pub(all)` struct is additive
  in the generated `.mbti`, but it *does* break exhaustive record
  literals at consumer sites, so the spread form is what keeps the
  additive-only promise real. Use it in examples and docs too: they are
  what consumers copy.

### Commit style
- Imperative subject line, ≤72 chars.
- Body explains *why*, not *what*.
- Keep formatter-only churn in its own commit so the substantive diff stays reviewable.

### Testing
- Every public function has at least one test.
- Round-trip tests are mandatory at every layer (XML, OPC, OOXML, model).
- Synthetic-but-realistic fixtures live in `src/integration/`; real-world `.pptx` files live in `test_fixtures/` when licensed.

### Documentation
- Public APIs documented with `///` doc comments — coverage stays at 100 %.
- Examples in `examples/` are runnable and round-trip-tested.
- `ROADMAP.md` is updated *in the same PR* as any scope or decision change.
- ADRs are append-only: supersede with a new one, never rewrite an accepted decision.

### Release process
1. Land all items for the target version on `main`.
2. `moon fmt && moon check --deny-warn && moon test --target all && moon info` clean.
3. Update `CHANGELOG.md` with the new version section.
4. Bump the version in `moon.mod`, plus the dependency examples in
   `examples/sample-deck/moon.mod` and `examples/sample-deck/README.md`.
5. **Refresh the comparison table in `README.md`** if the release added
   any user-visible feature (ADR-013 consequence — this is the table's
   only guard against drifting stale).
6. Update §0 and §3 here if the release changed the gap list.
7. Tag `v0.X.Y` on `main`.
8. `moon publish` — confirms 202 Accepted (the trailing `Error: failed` line is benign for `--dry-run`).
9. Verify the new docs render on mooncakes.io.
