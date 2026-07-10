# Real-world `.pptx` corpus

Drop **license-clear** real-world `.pptx` files here. The CI `validate` job
(`tools/pptx-validate/`) runs Microsoft's Open XML SDK validator over every
`.pptx` in this directory on each PR, so any file added here is automatically
checked for the schema/semantic problems that make PowerPoint show a *repair*
prompt — both as a regression guard for the library and as a sanity check that
our validator baseline matches what real Office output looks like.

This realises the `test_fixtures/` slot referenced in `TODO.md §10` and is
**Tier 2** of the verification pyramid (ADR-011). The in-repo MoonBit
structural-integrity tests (`src/integration/integrity_test.mbt`, Tier 1) cover
the library's own builder output without needing any of these files.

## Licensing — only add files you may redistribute

Do **not** commit decks of unknown provenance. Good sources:

| Source | License | Notes |
|---|---|---|
| Apache POI `test-data/slideshow/*.pptx` | Apache-2.0 | Diverse real Office/LibreOffice output; redistributable. **Best first source.** |
| Files you create yourself in PowerPoint / Keynote / LibreOffice / Google Slides | yours | Capture each app's quirks; you own the license |
| ECMA-376 / Microsoft Open Specifications samples | per spec terms | Check terms before committing |
| CC0 / public-domain template galleries | CC0 | Verify the CC0 claim |

Record each file's origin + license in `SOURCES.md` (create it alongside the
files) so provenance stays auditable.

## Tier-1 embeds: some files also run inside `moon test`

The library is FFI-free and runs on four backends (JS / Wasm can't read the
filesystem), so `moon test` can't open these binaries directly. Instead, a few
of them are **embedded as generated MoonBit sources** — run
`python3 tools/embed-corpus/gen.py` (stdlib only) to regenerate
`src/integration/corpus_*_embed_test.mbt` from the `FILES` list in that
script. `src/integration/corpus_test.mbt` decodes the embeds and asserts
parse → serialise → re-parse **model equality** on every backend, proving the
*reader* loses nothing on real Office input (the SDK validator above only
proves the files are schema-valid). To embed another corpus file, add it to
`FILES`, regenerate, and commit the new `.mbt` — each entry costs ~1.4× its
size in committed source, so keep the embedded set small and diverse.
