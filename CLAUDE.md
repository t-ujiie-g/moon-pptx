# CLAUDE.md

This file is loaded automatically by [Claude Code](https://claude.com/claude-code)
as project context. It complements `AGENTS.md` (which is the tool-agnostic
contributor guide for any AI agent — Claude, Codex, Cursor, OpenCode, …).

> **Pointer:** the canonical project context that applies to every AI agent
> lives in `@AGENTS.md`. This file adds Claude-Code-specific guidance on top.

---

## 1. Single source of truth: TODO.md

`TODO.md` is the **single source of truth** for direction, phase scope, design
decisions (ADRs), open questions, and risks. Before doing any non-trivial work
on this project you MUST:

1. Read the current Phase section in `TODO.md` (see `## 3. Phase roadmap`).
2. Confirm the task you're about to start is on the active phase's checklist.
3. If it isn't, stop and discuss scope before implementing — do not silently
   widen scope.

After completing work, **update `TODO.md` in the same change**:
- Tick off the relevant checkbox(es).
- If you discovered new work, add it to the appropriate phase (or create one
  if it spans multiple phases).
- If you made an architectural decision, append an ADR (section 4) — never
  rewrite an existing accepted ADR; supersede it with a new one.
- Update the "Living changelog" (section 9) for any user-visible change.

**Do not** create separate planning, decision, or analysis docs. Everything
goes into `TODO.md` so the project keeps one canonical narrative.

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
1. Read `TODO.md` (relevant phase) and any open ADRs you're about to touch.
2. If the task is not in the current phase, stop and confirm with the user
   before broadening scope.
3. Use TaskCreate / TaskUpdate to track multi-step work.

### While working
- Run `moon check` after every meaningful edit. It's fast and catches most
  mistakes immediately.
- Prefer `moon ide doc <name>` over guessing API signatures (this is the
  `moonbit-orientation` skill's freshness gate).
- Edit existing files; do not create new files unless a `TODO.md` task or
  the user explicitly asks.

### Before reporting a task complete
Run the full validation loop:

```bash
moon check       # typecheck
moon test        # run tests
moon fmt         # format
moon info        # regen .mbti
```

If `moon info` produced a diff in any `pkg.generated.mbti`, the public API
surface changed — review the diff and reflect it in `TODO.md` if it affects
roadmap items.

For changes that touch Wasm-GC- or Native-specific behavior, also run:

```bash
moon test --target all
```

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
  APIs. Use the newtypes from `units/` (Phase 1+).
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

See ADRs in `TODO.md §4` for the rationale behind each convention.

---

## 6. What lives where

| File / dir | Purpose |
|---|---|
| `TODO.md` | Roadmap, ADRs, open questions, risks (source of truth) |
| `CLAUDE.md` | This file — Claude Code overlay on top of AGENTS.md |
| `AGENTS.md` | Tool-agnostic contributor + AI agent guide (MoonBit conventions) |
| `README.md` | User-facing entry point (symlink to `README.mbt.md`) |
| `README.mbt.md` | Canonical README; runnable as a doc test |
| `moon.mod.json` | Module manifest (deps, metadata) |
| `moon.pkg` | Root package config (imports) |
| `moon_pptx.mbt` | Library entry source |
| `moon_pptx_test.mbt` | Blackbox tests (use `@moon_pptx`) |
| `moon_pptx_wbtest.mbt` | Whitebox tests (in-package) |
| `cmd/main/` | CLI entry point (development scratch) |
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
- `TODO.md` phase checkboxes reflect actual code state; the changelog has an
  entry for the change you're making.
- `README.mbt.md` status table is current (no Phase marked "🔜 Next" if it's
  already merged).
- Public APIs have `///` doc comments; non-obvious *why* lines have inline
  comments.
- ADRs supersede rather than mutate: when a decision changes, append a new
  ADR and mark the old one Superseded.
- `pkg.generated.mbti` is regenerated (`moon info`) — diff shows the
  intended public-API change.

### 7.6 Validation loop after refactoring
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

- ❌ Creating "decision documents" or "planning documents" outside `TODO.md`.
- ❌ Adding dependencies without an ADR in `TODO.md §4`.
- ❌ Silently dropping unknown OOXML elements on read.
- ❌ Using `Int` for EMU values (overflows past ±2.1 billion EMU ≈ ±2300 inches).
- ❌ Introducing FFI without a phase-level discussion.
- ❌ Skipping `moon fmt` / `moon info` before committing.
- ❌ Using `--no-verify` to bypass the pre-commit hook.

---

## 9. When in doubt

- For MoonBit language / API questions: rely on the `moonbit-orientation`
  skill's verification tiers — never present guessed APIs as facts. Use
  `moon ide doc` and the local `.mooncakes/` source as ground truth.
- For project direction: re-read the relevant `TODO.md` phase. If still
  unclear, ask the user.
- For PPTX/OOXML semantics: consult ECMA-376 (the OOXML spec). Cite section
  numbers in commit messages or comments when implementing non-obvious parts.
