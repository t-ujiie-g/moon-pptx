// Slide reordering API.
//
// PowerPoint keys on-screen slide order off `presentation.xml`'s
// `<p:sldIdLst>`, *not* off slide part names — `slide3.xml` can appear
// first if its `<p:sldId>` comes first. So reordering is a pure permute
// of the `sld_ids` array + re-serialise: no part renaming, no rels
// churn, no content-type touch. This pairs with slide deletion and
// duplication to give full programmatic deck arrangement.

///|
/// Move the slide at `from` to position `to` (both in `<p:sldIdLst>` /
/// `slides()` order), mutating `self.pkg` in place. `to` is the index
/// the slide should occupy in the resulting order, so
/// `move_slide_mut(0, last)` sends the first slide to the end.
///
/// Only rewrites `presentation.xml` (the `<p:sldIdLst>` order); the
/// slide parts, their `.rels`, and content types are untouched. Raises
/// `Malformed` if either index is out of range, or the package has no
/// parseable `presentation.xml`.
pub fn Presentation::move_slide_mut(
  self : Presentation,
  from : Int,
  to : Int,
) -> Unit raise PptxError {
  let parts = self.ordered_slide_parts()
  let n = parts.length()
  if from < 0 || from >= n {
    raise Malformed(
      "move_slide_mut: from index " +
      from.to_string() +
      " is out of range (0.." +
      n.to_string() +
      ")",
    )
  }
  if to < 0 || to >= n {
    raise Malformed(
      "move_slide_mut: to index " +
      to.to_string() +
      " is out of range (0.." +
      n.to_string() +
      ")",
    )
  }
  if from == to {
    return
  }
  let pres_name = match self.main_document_part_name() {
    Some(nm) => nm
    None =>
      raise Malformed(
        "package has no main-document relationship; cannot move slide",
      )
  }
  let pres = match self.presentation_part() {
    Some(p) => p
    None =>
      raise Malformed("presentation.xml could not be parsed before move_slide")
  }
  // `ordered_slide_parts` walks `pres.sld_ids` in order, so index i in
  // `parts` is index i in `pres.sld_ids`. Permute the id list: drop the
  // entry at `from`, then splice it back at `to`.
  let moved = pres.sld_ids[from]
  let reordered : Array[SlideIdRef] = []
  for i, s in pres.sld_ids {
    if i != from {
      reordered.push(s)
    }
  }
  reordered.insert(to, moved)
  let new_pres = { ..pres, sld_ids: reordered }
  self.replace_part_bytes(
    pres_name,
    new_pres.serialize(),
    @oxml.ct_presentation,
  )
}

///|
/// Immutable counterpart of `move_slide_mut`. Returns a new
/// `Presentation` whose slide order has the slide at `from` relocated to
/// `to`; the original is untouched.
pub fn Presentation::with_slide_moved(
  self : Presentation,
  from : Int,
  to : Int,
) -> Presentation raise PptxError {
  let cloned = self.clone()
  cloned.move_slide_mut(from, to)
  cloned
}
