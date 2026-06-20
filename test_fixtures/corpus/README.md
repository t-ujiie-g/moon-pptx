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

## Why files are not embedded as MoonBit tests

Reading these binaries from `moon test` is awkward: the library is FFI-free and
runs on four backends (JS / Wasm can't read the filesystem), so a real-file
round-trip test would have to embed each file's bytes in generated `.mbt`. That
is a worthwhile follow-up (it would prove the *reader* loses nothing on real
input — see TODO.md ADR-011), but the external validator already covers "these
real files validate," so the corpus lives here and is exercised through the
CI tool rather than the MoonBit test runner.
