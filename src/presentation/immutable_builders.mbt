// Immutable builder variants — Phase 5f.
//
// Per ADR-003 the default builder style is `with_*` returning a new
// value. The mutating `add_slide_mut` / `update_slide_mut` exist
// because they let users edit an opened deck in place — sometimes
// the right shape for batch edits. The immutable wrappers below
// close the ADR-003 story for the create-from-scratch / one-shot
// flow:
//
//   let prs = Presentation::new()
//   let (prs, _new_slide_name) = prs.with_added_slide(layout_index=0)
//   let s = prs.slides()[0]
//   let tb = AutoShape::textbox(2, "T", 0, 0, 914400, 457200, "Hi")
//   let prs = prs.with_slide_updated(0, s.with_shape(AutoShape(tb)))
//   let bytes = prs.save()
//
// All three operations clone the underlying `@opc.Package` first
// (via `Package::clone`) and then run the same internal mutation
// the `_mut` form would. That's not the cheapest possible
// implementation — a copy-on-write package or persistent map would
// avoid the up-front allocation — but it's the simplest, and Phase
// 5f's contract isn't performance, it's "ADR-003 compliance for
// builder users". Profile-and-tune later if needed.

///|
/// Deep-clone a `Presentation`. The clone owns its own
/// `@opc.Package`, so subsequent mutation of either side doesn't
/// reach the other. Used internally by the immutable builders
/// below; exposed publicly because users occasionally want a
/// snapshot before a destructive edit.
pub fn Presentation::clone(self : Presentation) -> Presentation {
  { pkg: self.pkg.clone() }
}

///|
/// Immutable counterpart of `add_slide_mut`. Returns a tuple of the
/// new `Presentation` (containing the appended slide) and the part
/// name of the new slide so callers can chain `with_slide_updated`
/// without first looking the new slide up by index.
///
/// `layout_index` is the position in `slide_layouts()`; out-of-range
/// raises `Malformed`.
pub fn Presentation::with_added_slide(
  self : Presentation,
  layout_index~ : Int,
) -> (Presentation, String) raise PptxError {
  let cloned = self.clone()
  let new_name = cloned.add_slide_mut(layout_index)
  (cloned, new_name)
}

///|
/// Immutable counterpart of `update_slide_mut`. Returns a new
/// `Presentation` whose slide at `slide_index` has been replaced
/// with the serialised bytes of `new_slide`. The original is
/// untouched.
pub fn Presentation::with_slide_updated(
  self : Presentation,
  slide_index : Int,
  new_slide : @slide.Slide,
) -> Presentation raise PptxError {
  let cloned = self.clone()
  cloned.update_slide_mut(slide_index, new_slide)
  cloned
}
