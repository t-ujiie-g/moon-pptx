// Pinpoint shape editing at the presentation level (roadmap v0.3 B4).
//
// These close the find → edit → write-back loop in one call: they fetch the
// slide at `slide_idx`, apply a shape transform via the `@slide` edit
// builders, and persist the result through `update_slide_mut` (which also
// resolves any pending hyperlinks and rewrites the part bytes). Untouched
// shapes round-trip losslessly because the whole slide is re-serialised from
// its parsed model.

///|
/// Apply `f` to every shape on the slide at `slide_idx` and write the slide
/// back. `f` returning its argument unchanged is an identity passthrough, so
/// this is the best-effort targeted-edit entry point (match the shapes you
/// care about, return the rest as-is). Raises `Malformed` if `slide_idx` is
/// out of range.
pub fn Presentation::map_slide_shapes_mut(
  self : Presentation,
  slide_idx : Int,
  f : (@slide.Shape) -> @slide.Shape,
) -> Unit raise PptxError {
  let slide = self.parse_slide_part_at(slide_idx)
  self.update_slide_mut(slide_idx, slide.map_shapes(f))
}

///|
/// Transform the shape whose id is `id` on the slide at `slide_idx` with `f`,
/// and write the slide back. Raises `Malformed` if `slide_idx` is out of
/// range or no shape on that slide has the given id.
pub fn Presentation::update_shape_by_id_mut(
  self : Presentation,
  slide_idx : Int,
  id : Int,
  f : (@slide.Shape) -> @slide.Shape,
) -> Unit raise PptxError {
  let slide = self.parse_slide_part_at(slide_idx)
  let updated = slide.with_shape_by_id(id, f) catch {
    e => raise SlideFailure(e.to_string())
  }
  self.update_slide_mut(slide_idx, updated)
}

///|
/// Parse the slide part at `slide_idx` (in `<p:sldIdLst>` order) into a typed
/// `@slide.Slide`. Raises `Malformed` on a bad index, `SlideFailure` if the
/// part doesn't parse.
fn Presentation::parse_slide_part_at(
  self : Presentation,
  slide_idx : Int,
) -> @slide.Slide raise PptxError {
  let parts = self.ordered_slide_parts()
  if slide_idx < 0 || slide_idx >= parts.length() {
    raise Malformed("slide index " + slide_idx.to_string() + " is out of range")
  }
  @slide.Slide::parse(parts[slide_idx].bytes) catch {
    e => raise SlideFailure(e.to_string())
  }
}
