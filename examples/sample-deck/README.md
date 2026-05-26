# moon-pptx — Sample deck

A 12-slide PowerPoint deck built end-to-end with
[`t-ujiie-g/moon-pptx`](https://mooncakes.io/docs/t-ujiie-g/moon-pptx).
Doubles as the canonical worked example and as a debugging helper for
PowerPoint Online compatibility verification.

## Layout

```
sample-deck/
├── moon.mod.json     ← separate MoonBit module
└── main/
    ├── moon.pkg.json ← is-main: true, imports moon-pptx sub-packages
    ├── build.mbt     ← deck builders (full deck + per-feature isolation)
    └── main.mbt      ← CLI entry: emits the deck bytes as hex
```

This module is **independent of the moon-pptx library itself**. It has
its own `moon.mod.json` and depends on the library exactly the way a
downstream consumer would. Inside the moon-pptx repo we use a path
dependency for dev convenience (no need to publish-and-pin between
local edits); once a new moon-pptx version is on mooncakes you can
switch to a version-pinned dep without changing the example source.

### Dev (path dep — default in this repo)

```json
"deps": {
  "t-ujiie-g/moon-pptx": { "path": "../.." }
}
```

### After publication (version-pinned dep)

```json
"deps": {
  "t-ujiie-g/moon-pptx": "0.2.0"
}
```

## Generate `sample.pptx`

From the moon-pptx project root:

```bash
mkdir -p out
moon -C examples/sample-deck run main --target native \
  | tail -1 | xxd -r -p > out/sample.pptx
```

Then open `out/sample.pptx` in PowerPoint / Keynote / LibreOffice.

The hex + `xxd -r -p` dance is required because MoonBit's `core` only
exposes `println(Show)` for I/O — emitting raw bytes without FFI
(per moon-pptx's "no FFI" policy) means encoding to hex first. The
calling shell decodes back to the binary `.pptx` payload.

## Bisecting PowerPoint Online repair issues

If PowerPoint Online flags the generated deck as "needs repair", flip
the `split_mode` flag near the top of `main.mbt` to `true` and re-run:

```bash
moon -C examples/sample-deck run main --target native | \
  awk '/^===FILE-/{ if(out)close(out); name=substr($0,9,length-11); out="out/split/"name".hex"; next }
       /^===END===/{ if(out)close(out); out=""; next }
       out { print > out }'
for f in out/split/*.hex; do
  base=$(basename "$f" .hex)
  xxd -r -p < "$f" > "out/split/${base}.pptx" && rm "$f"
done
```

This produces 11 per-feature `.pptx` files
(`00-title-only.pptx` … `10-closing.pptx`) so you can open each
individually and identify which feature combination triggers
PowerPoint's repair pass. The same technique drove the v0.2.0 repair
fixes (notes-master synthesis, chart axis required elements, ofPie
defaults, etc.).

## Slide list

| # | Slide | Features exercised |
|---|---|---|
| 1 | Title | Widescreen sizing, styled run, external hyperlink, speaker notes |
| 2 | Table of contents | Internal-slide hyperlinks (jump-to-slide via `ppaction://hlinksldjump`) |
| 3 | Text features | Multi-paragraph, alignment, AutoNum bullets |
| 4 | Shapes | rect / ellipse / round-rect + Connector + GroupShape |
| 5 | Custom geometry | Hand-drawn star path |
| 6 | Picture | Synthesized 16×16 BMP + image-size auto-detection + crop |
| 7 | Tables | Merged header + per-edge custom borders + cell fills |
| 8 | Charts I | Bar / line / pie grid |
| 9 | Charts II | Area / radar / doughnut grid |
| 10 | Charts III | Scatter + bubble (two value-axis families) |
| 11 | Charts IV | 3-D bar + stock + of-pie (extended axis + 3-D wrappers) |
| 12 | Closing | Back-link hyperlink + speaker notes |
