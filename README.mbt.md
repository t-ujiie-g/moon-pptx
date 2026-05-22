# moon_pptx

[![CI](https://github.com/t-ujiie-g/moon-pptx/actions/workflows/ci.yml/badge.svg)](https://github.com/t-ujiie-g/moon-pptx/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

> **Status: pre-alpha (Phase 4 closed).** Read- and write-path parsers
> + writers are in for theme / slide master / slide layout / slide /
> notes slide / comments, with `parse → serialize → parse → Eq`
> round-trip verified across three synthetic decks. High-level
> `Presentation` builder API does not exist yet — see
> [TODO.md](TODO.md) for the phase-by-phase roadmap.

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
| 5 | Builder API (create from scratch) | 🔜 Next |
| 6 | Tables | ⏳ |
| 7 | Charts | ⏳ |
| 8 | Differentiators (SmartArt, animation, …) | ⏳ |
| 9 | 1.0 release | ⏳ |

Detailed checklists per phase live in [TODO.md](TODO.md).

## Install

Once published to mooncakes:

```bash
moon add t-ujiie-g/moon_pptx
```

## Quickstart (planned API — does not work yet)

```moonbit nocheck
///|
let prs = @moon_pptx.Presentation::new()

///|
let slide = prs
  .slides()
  .add(@moon_pptx.SlideLayout::title_and_content())
  .with_title("Hello, MoonBit")
  .with_body("This deck was built without touching XML.")

///|
let bytes = prs.save()
```

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
