// Slide duplication API (roadmap v0.3.1 E3).
//
// `duplicate_slide_mut(slide_index)` deep-copies a slide part and threads
// the copy into the package exactly like `add_slide_mut` does for a blank
// slide: a new `/ppt/slides/slideN.xml` (verbatim copy of the source body),
// a fresh `slideN.xml.rels`, a `presentation.xml.rels` relationship, a new
// `<p:sldId>`, and a content-type `<Override>`. The duplicate is appended
// to the end of the deck; pair with `move_slide_mut` (E2) to position it.
//
// Q12 decision (shared media): the clone *re-references* the source slide's
// relationship targets rather than deep-copying each image / chart / media /
// notes part. The slide's `.rels` is slide-local, so the copy's `.rels`
// carries the same relative targets (both slides live in `/ppt/slides/`),
// the copied slide XML keeps its `rId` references valid unchanged, and the
// shared parts are kept alive by E1's reference-counted deletion. This is
// leaner and round-trip-safe; the trade-off is that editing a shared chart's
// data or the shared notes affects both slides. A deep-copy variant (fully
// independent parts) can land later if a consumer needs it.

///|
/// Duplicate the slide at `slide_index` (in `<p:sldIdLst>` / `slides()`
/// order), appending the copy to the end of the deck. Returns the new
/// slide's part name. Mutates `self.pkg` in place — call `save()` to
/// materialise.
///
/// The copy shares the source slide's referenced parts (layout, images,
/// charts, media, notes) by re-referencing them rather than deep-copying
/// — see the module note on Q12. Raises `Malformed` if `slide_index` is
/// out of range or the package has no parseable `presentation.xml`.
pub fn Presentation::duplicate_slide_mut(
  self : Presentation,
  slide_index : Int,
) -> String raise PptxError {
  let parts = self.ordered_slide_parts()
  if slide_index < 0 || slide_index >= parts.length() {
    raise Malformed(
      "duplicate_slide_mut: slide index " +
      slide_index.to_string() +
      " is out of range (0.." +
      parts.length().to_string() +
      ")",
    )
  }
  let source = parts[slide_index]
  let source_name = source.name

  // 1. Locate presentation.xml + its rels; compute new part name / rId.
  let pres_name = match self.main_document_part_name() {
    Some(n) => n
    None =>
      raise Malformed(
        "package has no main-document relationship; cannot duplicate slide",
      )
  }
  let new_slide_name = self.next_slide_part_name()
  let pres_rels = self.pkg.relationships_for(pres_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let new_slide_rid = next_unused_rid(pres_rels)

  // 2. Add the new slide part — a verbatim copy of the source body.
  let slide_part = @opc.Part::new(
    new_slide_name,
    @oxml.ct_slide,
    @opc.copy_bytes(source.bytes),
  ) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(slide_part) catch {
    e => raise OpcFailure(e.to_string())
  }

  // 3. Copy the source slide's .rels verbatim into the clone's .rels.
  //    Both slides live in `/ppt/slides/`, so the relative targets are
  //    identical and the copied slide XML's `rId` references stay valid.
  let source_rels = self.pkg.relationships_for(source_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let cloned_items : Array[@opc.Relationship] = []
  for r in source_rels.items {
    cloned_items.push(r)
  }
  let clone_rels = @opc.Relationships::{
    source: new_slide_name,
    items: cloned_items,
  }
  self.write_rels_for_part(new_slide_name, clone_rels)

  // 4. Thread the clone into presentation.xml (<p:sldId>), its rels, and
  //    [Content_Types].xml — same wiring as add_slide_mut.
  self.attach_slide_to_presentation(pres_name, new_slide_name, new_slide_rid)
  new_slide_name
}

///|
/// Immutable counterpart of `duplicate_slide_mut`. Returns the new
/// `Presentation` (with the appended duplicate) plus the new slide's
/// part name; the original is untouched.
pub fn Presentation::with_duplicated_slide(
  self : Presentation,
  slide_index : Int,
) -> (Presentation, String) raise PptxError {
  let cloned = self.clone()
  let new_name = cloned.duplicate_slide_mut(slide_index)
  (cloned, new_name)
}
