// Slide replacement API.
//
// `update_slide_mut(slide_index, new_slide)` writes the serialized
// bytes of a modified Slide back into the package at the same part
// the original lived in. Combined with the @slide builders
// (`Slide::with_shape`, `AutoShape::rect`, …) this gives a complete
// edit cycle:
//
//   let prs = Presentation::open(bytes)
//   let s = prs.slides()[0]
//   let s2 = s.with_shape(AutoShape(rect(...)))
//   prs.update_slide_mut(0, s2)
//   let new_bytes = prs.save()
//
// The slide is identified by its position in `Presentation::slides()`
// — which is `<p:sldIdLst>` order in well-formed PPTX. No rels or
// content-type updates are needed since the part already exists and
// keeps its identity.

///|
/// Replace the slide at `slide_index` (in `<p:sldIdLst>` order) with
/// the serialized bytes of `new_slide`. Raises `Malformed` if the
/// index is out of range.
pub fn Presentation::update_slide_mut(
  self : Presentation,
  slide_index : Int,
  new_slide : @slide.Slide,
) -> Unit raise PptxError {
  let parts = self.ordered_slide_parts()
  if slide_index < 0 || slide_index >= parts.length() {
    raise Malformed(
      "slide index " + slide_index.to_string() + " is out of range",
    )
  }
  let part = parts[slide_index]
  // Walk the slide and resolve any pending hyperlinks against the
  // part's `.rels` before serialisation. No-op for slides whose runs
  // carry no `hyperlink_target`.
  let resolved = self.resolve_slide_hyperlinks(part.name, new_slide)
  let bytes = resolved.serialize() catch {
    e => raise SlideFailure(e.to_string())
  }
  self.replace_part_bytes(part.name, bytes, @oxml.ct_slide)
}
