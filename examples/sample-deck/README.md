# moon-pptx — Sample deck

A single PowerPoint deck built end-to-end with
[`t-ujiie-g/moon-pptx`](https://mooncakes.io/docs/t-ujiie-g/moon-pptx),
touring (almost) every feature: text, shapes, tables, the full chart
gallery, pictures, slide backgrounds, SVG images, embedded audio/video,
master slides with footer/date/slide-number, and in-place shape editing —
plus the v0.4 additions: typed layout slides (compile-time placeholder
schema), slide transitions, ADT-driven chart options, the typed picture
builder, and chart-data validation. Doubles as the canonical worked
example and as a debugging helper for PowerPoint Online compatibility
verification.

## Layout

```
sample-deck/
├── moon.mod.json     ← separate MoonBit module
└── main/
    ├── moon.pkg.json ← is-main: true, imports moon-pptx sub-packages
    ├── build.mbt     ← deck assembly + the original slide builders
    ├── showcase.mbt  ← the newer feature slides (background, SVG, media, …)
    └── main.mbt      ← CLI entry: emits the deck bytes as hex
```

This module is **independent of the moon-pptx library itself**. It
has its own `moon.mod.json`. While the next library version is still
unreleased it depends on the in-repo copy through a path dep:

```json
"deps": {
  "t-ujiie-g/moon-pptx": { "path": "../.." }
}
```

It serves as a worked-out example of "what a real consumer would
write" — the import shapes (`@presentation`, `@chart`, `@slide`, …)
are exactly what you'd use in your own project. Once the library is
published, a consumer swaps the path dep for a version:

```json
"deps": {
  "t-ujiie-g/moon-pptx": "0.4.0"
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

This produces one `.pptx` file per feature
(`00-title-only.pptx` … `16-closing.pptx`, plus a few chart
sub-isolations) so you can open each individually and identify which
feature triggers PowerPoint's repair pass. The same technique drove
the v0.2.0 repair fixes (notes-master synthesis, chart axis required
elements, ofPie defaults, etc.).

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
| 12 | Slide background | Solid-fill slide background |
| 13 | Combo chart | Columns + line on a secondary value axis |
| 14 | SVG image | Vector image with a raster fallback |
| 15 | Editing shapes | Recolour boxes already on the slide via `map_shapes` |
| 16 | Embedded media | A movie + a sound clip (placeholder media payloads) |
| 17 | Master / template | Defined master + footer, auto date, slide number |
| 18 | Closing | Back-link hyperlink + speaker notes |
