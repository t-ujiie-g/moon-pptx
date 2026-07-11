# moon-pptx — Sample deck

A single PowerPoint deck built end-to-end with
[`t-ujiie-g/moon-pptx`](https://mooncakes.io/docs/t-ujiie-g/moon-pptx),
touring (almost) every feature: text, shapes, tables, the full chart
gallery, pictures, slide backgrounds, SVG images, embedded audio/video,
master slides with footer/date/slide-number, in-place shape editing,
typed layout slides (compile-time placeholder schema), slide
transitions, ADT-driven chart options, the typed picture builder,
chart-data validation, SmartArt diagrams (with per-node colours),
animations, YouTube / online video, gradient & pattern text fills,
paragraph spacing, gallery table styles, fill convenience constructors,
slide sections, core + app document properties, and an embedded
chart-data workbook behind PowerPoint's "Edit Data". Doubles as the
canonical worked example and as a debugging helper for PowerPoint Online
compatibility verification.

## Layout

```
sample-deck/
├── moon.mod          ← separate MoonBit module (published-version dep)
├── moon.work         ← workspace: in-repo builds use the repo source
└── main/
    ├── moon.pkg      ← is-main: true, imports moon-pptx sub-packages
    ├── build.mbt     ← deck assembly + the original slide builders
    ├── showcase.mbt  ← the newer feature slides (background, SVG, media, …)
    └── main.mbt      ← CLI entry: emits the deck bytes as hex
```

This module is **independent of the moon-pptx library itself**. It has
its own `moon.mod` and depends on the **published** library version —
exactly what a real consumer writes:

```toml
import {
  "t-ujiie-g/moon-pptx@0.6.0",
}
```

So it doubles as a worked-out example of "what a real consumer would
write" — the import shapes (`@presentation`, `@chart`, `@slide`,
`@smartart`, …) are exactly what you'd use in your own project.

> **Inside this repo**, the committed `moon.work` workspace overrides
> that dependency to the repo source, so `moon check` / `moon test` /
> the CI validator always build the deck against the current tree —
> which is how the deck can showcase features before they're
> published. Copy the module out of the repo (without `moon.work`) and
> it builds against the published version like any consumer project.

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
(`00-title-only.pptx` … `21-closing.pptx`, plus a few chart
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
| 13 | Combo chart | Columns + line on a secondary value axis, plus the embedded data workbook — "Edit Data" opens the real rows |
| 14 | SVG image | Vector image with a raster fallback |
| 15 | Editing shapes | Recolour boxes already on the slide via `map_shapes` |
| 16 | Embedded media | A movie + a sound clip (placeholder media payloads) |
| 17 | SmartArt | Org chart synthesised into the five-part DiagramML graphic; the whole tree lays out via the recursive layoutDef; the CEO node carries per-node colour overrides |
| 18 | Animations | Fly-in entrance + spin emphasis on click (`with_animations` / `Timeline`) |
| 19 | Online video | YouTube clip embedded by URL (`add_youtube_video_mut`) |
| 20 | v0.5.2 features | Shape rotation / flip, run highlight + kerning + outline + glow, shape-level hyperlinks |
| 21 | v0.6 features | Gradient + pattern **text fills** (`with_text_fill`) and paragraph spacing — 150 % / absolute 28 pt line height, 18 pt space-before (`TextSpacing`) |
| 22 | v0.7 features | A gallery-styled table (`Table::with_style(MediumStyle2Accent1)`) + the `Fill::solid` / `linear_gradient` / `pattern` convenience constructors |
| 23 | Master / template | Defined master + footer, auto date, slide number |
| 24–25 | Typed layouts | Compile-time placeholder schema (`add_section_header_slide_mut` / `add_title_content_slide_mut`) |
| 26 | Closing | Back-link hyperlink + speaker notes |

Plus, deck-wide: a slide transition on every slide, named **slide
sections** grouping the deck in the slide panel (`set_sections_mut`),
and **document properties** in both parts of File ▸ Info — core.xml
(title / author / …) and app.xml (company / manager,
`set_app_properties_mut`).
