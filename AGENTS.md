# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project: **`t-ujiie-g/moon_pptx`**, a
pure-MoonBit library for reading, building, and writing `.pptx` (OOXML) files.

Claude Code users: see also `CLAUDE.md` for the Claude-specific overlay.

## Source of truth

- `TODO.md` is the authoritative roadmap, phase plan, ADR log, and risk
  register. **Read the relevant phase before starting any non-trivial work**,
  and update `TODO.md` in the same change set as your code.
- Do not create separate planning / decision / analysis docs — append to
  `TODO.md` instead.

## Required skills

This project relies on the **MoonBit official skills**. Install via Claude
Code's `/plugin` (add marketplace `moonbitlang/skills`, then install
`moonbit-skills`). For other agents, follow the install instructions at
<https://github.com/moonbitlang/skills>.

## Project Structure

- MoonBit packages are organized per directory; each directory contains a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (ending in `_test.mbt`) and whitebox test files (ending in
  `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod.json` file listing module
  metadata.

## Coding convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in file called `deprecated.mbt` in each
  directory.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `moon test` to check tests pass. MoonBit supports snapshot testing; when
  changes affect outputs, run `moon test --update` to refresh snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. Use snapshot tests to record current
  behavior. For solid, well-defined results (e.g. scientific computations),
  prefer assertion tests. You can use `moon coverage analyze > uncovered.log` to
  see which parts of your code are not covered by tests.

- For changes touching backend-specific behavior, run `moon test --target all`
  to verify against `native`, `wasm-gc`, and `js`. CI runs the same matrix.

## Project-specific conventions

These overrides apply on top of the generic guidance above:

- Buffer type is always `FixedArray[Byte]` (matches `hustcer/fzip`).
- Length and angle units use the newtypes in `units/` (Phase 1+); never bare
  `Int`/`Int64` in public APIs.
- Errors use subdomain suberrors (`OpcError`, `XmlError`, `PptxError`); never
  raw `String` failures.
- Builders are immutable: `slide.with_shape(s)` returns a new `Slide`.
- Every parsed model node carries `extension : Array[XmlElement]` for unknown
  XML — never silently drop unknown elements.
- No FFI. The library must remain pure MoonBit so it builds on Native and
  Wasm-GC alike.

See `TODO.md §4 (ADRs)` for the rationale behind each convention.
