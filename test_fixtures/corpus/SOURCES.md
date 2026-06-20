# Corpus provenance

Every `.pptx` here is from the **Apache POI** project's `test-data/slideshow/`
directory, which is licensed **Apache-2.0** (redistributable). Files were
selected to be real-world, schema-valid, and diverse in features; intentionally
broken / fuzzer crash-case files were excluded.

- **Upstream**: https://github.com/apache/poi
- **Path**: `test-data/slideshow/`
- **Pinned commit**: `aa268199243921dd0d9e1dc8d96cc06331280c94`
- **License**: Apache License 2.0 — https://www.apache.org/licenses/LICENSE-2.0
- **Retrieved**: 2026-06-20

Permalink template (replace `<name>`):
`https://github.com/apache/poi/blob/aa268199243921dd0d9e1dc8d96cc06331280c94/test-data/slideshow/<name>`

| File | Why it's here |
|---|---|
| `testPPT.pptx` | Baseline presentation (theme + master + layout + slides) |
| `table_test.pptx` | Tables |
| `shapes.pptx` | AutoShapes / preset + custom geometry |
| `with_japanese.pptx` | Non-ASCII / CJK text + fonts |
| `layouts.pptx` | Multiple slide layouts + masters |
| `SmartArt.pptx` | SmartArt (DiagramML) graphic |
| `sample.pptx` | General mixed content |

## Excluded (and why)

- `bar-chart.pptx` — real POI file but the SDK validator (and ECMA-376) reject
  its chart `c:axId`/`c:crossAx` `val` of `-1884097184` (negative used where
  `UInt32` is required — an Office round-trip quirk in the source file, not a
  moon-pptx issue). Kept out so the corpus gates CI green; revisit if we want a
  real-chart fixture (baseline the quirk or pick a clean chart file).
- `clusterfuzz-*` / `*Fuzzer*` and several `bug<NNNNN>.pptx` — deliberately
  malformed inputs POI uses to test broken-file handling; not valid corpus.

## Adding more

Validate any candidate locally before committing so CI stays green:

```bash
dotnet run --project ../../tools/pptx-validate -- <file.pptx> \
  --baseline ../../tools/pptx-validate/baseline.txt
```

Record the source + license + commit of each new file in this table.
