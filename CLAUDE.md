# CLAUDE.md

This file is loaded automatically by [Claude Code](https://claude.com/claude-code)
as project context. It complements `AGENTS.md` (which is the tool-agnostic
contributor guide for any AI agent — Claude, Codex, Cursor, OpenCode, …).

> **Pointer:** the canonical project context that applies to every AI agent
> lives in `@AGENTS.md`. This file adds Claude-Code-specific guidance on top.

---

## 1. Single source of truth: ROADMAP.md

`ROADMAP.md` is the **single source of truth** for direction, open gaps, design
decisions (ADRs), open questions, and risks. It is **forward-looking** — what
already shipped lives in `CHANGELOG.md` and git history, not here. Before doing
any non-trivial work you MUST:

1. Read `ROADMAP.md` §3 (what is not done yet) and §4 (roadmap).
2. Confirm the task you're about to start is one of those open items.
3. If it isn't, stop and discuss scope before implementing — do not silently
   widen scope.

After completing work, **update the right file in the same change**:
- `ROADMAP.md` §3 / §4 — tick off or remove what you closed; add what you
  discovered.
- `CHANGELOG.md` — an entry for any user-visible change. This is where release
  history goes; do not keep a parallel changelog in `ROADMAP.md`.
- If you made an architectural decision, append an ADR (§6) — never rewrite an
  existing accepted ADR; supersede it with a new one.
- `README.md` § Comparison — refresh if the change adds a user-visible feature
  (ADR-013).

**Do not** create separate planning, decision, or analysis docs. Everything
goes into `ROADMAP.md` so the project keeps one canonical narrative.

---

## 2. Required Claude Code plugins

This project relies on the **MoonBit official skills** (orientation,
refactoring, agent-guide, spec-test workflows). They are distributed via the
Claude Code plugin marketplace.

**One-time setup per contributor:**

```text
1. Run `/plugin` in Claude Code.
2. "Add Marketplace" → enter:  moonbitlang/skills
3. Install the `moonbit-skills` plugin from that marketplace.
```

After installation, the `moonbit-orientation` skill (and friends) auto-engage
when working in `.mbt` files or asking MoonBit-specific questions. The
`moonbit-agent-guide` skill is also referenced in `AGENTS.md` (see the
`$moonbit-agent-guide` token there).

**Verify it's installed**: ask Claude "what MoonBit skills are loaded?" — it
should list at least `moonbit-orientation`.

If `/plugin` is unavailable in your Claude Code version, the same skills can
be cloned manually:

```bash
git clone --recurse-submodules https://github.com/moonbitlang/skills.git \
  ~/.claude/plugins/moonbit-skills
```

---

## 3. Workflow Claude should follow

### Before starting work
1. Read `ROADMAP.md` §3 / §4 and any open ADRs you're about to touch.
2. If the task is not an open roadmap item, stop and confirm with the user
   before broadening scope.
3. Use TaskCreate / TaskUpdate to track multi-step work.

### While working
- Run `moon check` after every meaningful edit. It's fast and catches most
  mistakes immediately.
- Prefer `moon ide doc <name>` over guessing API signatures (this is the
  `moonbit-orientation` skill's freshness gate).
- Edit existing files; do not create new files unless a `ROADMAP.md` item or
  the user explicitly asks.

### Before reporting a task complete
Run the full validation loop:

```bash
moon check --deny-warn   # typecheck
moon test --target all   # run tests on every backend
moon fmt                 # format
moon info                # regen .mbti
```

Note: **deprecation warnings appear under `moon test` / `moon build`, not
`moon check`.** A green `moon check --deny-warn` does not prove the tree is
warning-free — always run the tests too.

If `moon info` produced a diff in any `pkg.generated.mbti`, the public API
surface changed — review the diff and reflect it in `ROADMAP.md` if it affects
roadmap items.

---

## 4. Commands reference

| Purpose | Command |
|---|---|
| Type check | `moon check` |
| Build | `moon build` |
| Run all tests (default backend) | `moon test` |
| Run tests on every backend | `moon test --target all` |
| Run a single test by name | `moon test --filter "<glob>"` |
| Update snapshot tests | `moon test --update` |
| Format | `moon fmt` |
| Regenerate `.mbti` | `moon info` |
| Coverage | `moon test --enable-coverage && moon coverage report` |
| Add a dependency | `moon add <user>/<module>` |

CI (see `.github/workflows/ci.yml`) runs `check` + `fmt --check` + `info`
drift on `ubuntu-latest` and `macos-latest`, plus `test` against
`native` / `wasm-gc` / `js` targets.

---

## 5. Project-specific conventions

These are project-specific overrides on top of the generic MoonBit conventions
in `AGENTS.md`:

- **Buffer type**: always `FixedArray[Byte]` (matches `hustcer/fzip` and
  MoonBit core). Do not introduce parallel byte-array types.
- **Units**: never use bare `Int`/`Int64` for lengths or angles in public
  APIs. Use the newtypes from `units/`.
- **Errors**: subdomain suberrors (`OpcError`, `XmlError`, `PptxError`),
  never raw `String` failures. Match `hustcer/fzip`'s `FzipError` pattern.
- **Builders**: immutable. `slide.with_shape(s)` returns a new `Slide`. Use
  `_mut` suffix for the rare cases that need true mutation.
- **Lossless preservation**: every parsed model node carries an `extension :
  Array[XmlElement]` for unknown children — never drop unknown XML silently.
- **Backend portability**: no FFI. If a feature needs file I/O, expose it
  only through `bytes`-level APIs at the public surface; convenience helpers
  that touch the filesystem live behind backend gates.
- **Tests**: every public function gets at least one test; round-trip tests
  are mandatory at every layer (XML, OPC, OOXML, model).

See ADRs in `ROADMAP.md §6` for the rationale behind each convention.

---

## 6. What lives where

| File / dir | Purpose |
|---|---|
| `ROADMAP.md` | Direction, open gaps, ADRs, open questions, risks (source of truth) |
| `CLAUDE.md` | This file — Claude Code overlay on top of AGENTS.md |
| `AGENTS.md` | Tool-agnostic contributor + AI agent guide (MoonBit conventions) |
| `README.md` | User-facing entry point (symlink to `README.mbt.md`) |
| `README.mbt.md` | Canonical README; runnable as a doc test |
| `moon.mod` | Module manifest (deps, metadata) — TOML format |
| `src/*/moon.pkg` | Per-sub-package config (imports, test deps) |
| `src/<name>/` | Sub-packages: `units`, `xml`, `opc`, `oxml`, `theme`, `slide_master`, `slide`, `notes`, `comments`, `chart`, `chart_ex`, `smartart`, `presentation`, `integration` (tests) |
| `examples/README.md` | User-facing cookbook of focused recipes; each verified by `src/integration/examples_test.mbt` |
| `CHANGELOG.md` | Keep-a-Changelog release notes |
| `.githooks/pre-commit` | `moon fmt && moon check` (enable with `git config core.hooksPath .githooks`) |
| `.github/workflows/ci.yml` | CI: check / fmt / info drift / test matrix |
| `.mooncakes/` | Resolved dependency cache (gitignored) |
| `_build/` | Build output (gitignored) |

---

## 7. Refactoring checklist

When the user says "リファクタリング" / "refactor" / "tidy up" / "clean up",
walk through these five lenses **in order**, stopping to write a concrete
findings list **before** changing any code. The same lens applies whether
the trigger is a single file or the whole tree.

### 7.1 Constants management
- Are there magic numbers or repeated string literals that name a meaningful
  concept? Promote to a `pub let` constant in the most relevant package.
- Are domain conversion factors (EMU per inch, OOXML scale factors) defined
  exactly once and re-used everywhere?
- Hard-coded namespace URIs, file extensions, content types — extract to
  named constants in the package that owns the domain.

### 7.2 Duplicate / dead code
- Identical helper definitions in two files → consolidate to one location and
  re-export.
- Stub files left over from `moon new` (3-line comment-only `.mbt` files) —
  delete unless they hold actual API.
- Smoke / sanity tests whose purpose has been served by later integration
  tests — delete; do not keep "just in case".
- Unused imports in `moon.pkg` (look for `unused_package` warnings) — drop.
- Functions exported `pub` but called from nowhere — make private or delete.

### 7.3 File splitting
- A single `.mbt` file over ~500 lines is *a smell*, not a rule. Split only
  when there is a *logical* boundary (e.g. lexer state vs. token readers vs.
  name-resolution helpers), not just to hit a line count.
- Test files: one `_test.mbt` per source file is a good default; collapse
  only if the unified file stays small.
- Keep blackbox (`*_test.mbt`) and whitebox (`*_wbtest.mbt`) tests separate;
  do not co-mingle.

### 7.4 Test adequacy
- Every `pub fn` has at least one direct test (positive case).
- Every error path (`raise`, `Option None`) is covered by at least one test.
- Round-trip / property tests exist at any boundary that serialises data
  (XML reader↔writer, OPC pack↔unpack, OOXML parse↔serialise).
- Tests assert on values, not just shapes — `assert_eq` over `assert_true`
  where possible. `assert_true(x is Pattern(_))` is fine for error variants.
- A test that only re-runs the type checker (`let _ = …`) duplicates
  `moon check` and should be deleted.

### 7.5 Documentation freshness
- `ROADMAP.md` §3 reflects actual code state; `CHANGELOG.md` has an entry for
  the change you're making; `README.md` § Comparison is current.
- `README.mbt.md` feature list and comparison table match what actually
  ships.
- Public APIs have `///` doc comments; non-obvious *why* lines have inline
  comments.
- ADRs supersede rather than mutate: when a decision changes, append a new
  ADR and mark the old one Superseded.
- `pkg.generated.mbti` is regenerated (`moon info`) — diff shows the
  intended public-API change.

### 7.6 Comment hygiene
Comments must make sense to a reader who has never opened `ROADMAP.md` and
was not there when the code landed.

- **No roadmap/phase codes in code comments** — `roadmap F5`, `v0.6 D1-b`,
  `Phase 3h`, `ROADMAP.md §4` mean nothing later or to outsiders. Say the
  *thing* instead ("shape-level hyperlink", "the SmartArt layout
  definition"). ADR-nnn, ECMA-376 §, and issue #N references are fine —
  those are stable, findable records.
- **Delete comments the code already says** — a comment restating the next
  line, narrating what was changed, or justifying the change to a reviewer
  is noise once merged. History belongs in git / `CHANGELOG.md`, not in
  comments.
- **Keep comments that carry a constraint the code can't show** — spec
  rules ("`h` is required per ECMA-376"), non-obvious *why* ("PowerPoint
  needs `action=` to recognise the jump"), invariants, and deliberate
  deviations. Doc comments (`///`) on public APIs stay mandatory.
- **Never put comments between the members of a `struct` or `enum`.** The
  body stays a clean list of declarations. Per-field / per-variant
  documentation goes in the type's own doc comment as a bullet list —
  ``/// - `margin_left` (`marL`) — left margin in EMU.`` — which keeps it
  in `moon ide doc` output while leaving the declaration readable. This
  also applies to section markers inside long enums: name the groups in
  the type doc, not between the variants.
- **Keep comments short.** A doc comment should be proportionate to the
  thing it documents. When several fields share one mechanism, explain the
  mechanism once in a short paragraph instead of repeating it per field.
- When trimming an over-written comment, keep the informative core and cut
  the provenance framing.

### 7.7 Validation loop after refactoring
After changes, always run:

```bash
moon check --deny-warn
moon test --target all
moon fmt
moon info        # commit any .mbti diffs alongside code changes
```

Push only when all four are clean. CI repeats the same loop across the OS
matrix.

---

## 8. Things to avoid

- ❌ Creating "decision documents" or "planning documents" outside `ROADMAP.md`.
- ❌ Adding dependencies without an ADR in `ROADMAP.md §6`.
- ❌ Silently dropping unknown OOXML elements on read.
- ❌ Using `Int` for EMU values (overflows past ±2.1 billion EMU ≈ ±2300 inches).
- ❌ Introducing FFI without an ADR (see ADR-002).
- ❌ Skipping `moon fmt` / `moon info` before committing.
- ❌ Using `--no-verify` to bypass the pre-commit hook.

---

## 9. When in doubt

- For MoonBit language / API questions: rely on the `moonbit-orientation`
  skill's verification tiers — never present guessed APIs as facts. Use
  `moon ide doc` and the local `.mooncakes/` source as ground truth.
- For project direction: re-read `ROADMAP.md` §3 / §4. If still unclear, ask
  the user.
- For PPTX/OOXML semantics: consult ECMA-376 (the OOXML spec). Cite section
  numbers in commit messages or comments when implementing non-obvious parts.
