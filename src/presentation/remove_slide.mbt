// Slide deletion API (roadmap v0.3.1 E1).
//
// `remove_slide_mut(slide_index)` is the inverse of `add_slide_mut`: it
// unthreads a slide from every place the OPC package tracks it —
//
//   1. the `<p:sldId>` entry in `presentation.xml`'s `<p:sldIdLst>`,
//   2. the `Relationship` in `presentation.xml.rels` that pointed at it,
//   3. the `/ppt/slides/slideN.xml` part itself,
//   4. its `slideN.xml.rels` part, and
//   5. its `<Override>` in `[Content_Types].xml`.
//
// Shared structural parts (slide layout / master / theme) are *never*
// removed — they are referenced by other slides and by the package
// skeleton. Slide-private content reachable only through the removed
// slide (its notes slide, its images, its charts, its embedded media)
// is garbage-collected by reference counting against the remaining
// package graph: a candidate is dropped only when no surviving part's
// `.rels` still points at it. When a part's reference count is unknown
// or it is structural, the conservative choice is to keep it — an
// orphaned part bloats the file slightly but never trips a repair
// prompt, whereas deleting a still-referenced part does.
//
// Per ADR-003 the immutable counterpart is `without_slide(index) -> Self`.

///|
/// Remove the slide at `slide_index` (in `<p:sldIdLst>` / `slides()`
/// order) from the deck, mutating `self.pkg` in place. Call `save()`
/// afterwards to materialise the change.
///
/// Removes the slide part, its `.rels`, its `<p:sldId>` entry, the
/// `presentation.xml.rels` relationship, and its content-type
/// `Override`. Slide-private parts reachable only through this slide
/// (its notes slide, images, charts, media) are also removed once no
/// surviving slide references them; shared layout / master / theme
/// parts are always kept.
///
/// Raises `Malformed` if `slide_index` is out of range, or if the
/// package has no main-document relationship / parseable
/// `presentation.xml`.
pub fn Presentation::remove_slide_mut(
  self : Presentation,
  slide_index : Int,
) -> Unit raise PptxError {
  let parts = self.ordered_slide_parts()
  if slide_index < 0 || slide_index >= parts.length() {
    raise Malformed(
      "remove_slide_mut: slide index " +
      slide_index.to_string() +
      " is out of range (0.." +
      parts.length().to_string() +
      ")",
    )
  }
  let target_name = parts[slide_index].name

  // 1. Locate presentation.xml + its rels, and find the rId that
  //    points at the target slide.
  let pres_name = match self.main_document_part_name() {
    Some(n) => n
    None =>
      raise Malformed(
        "package has no main-document relationship; cannot remove slide",
      )
  }
  let pres = match self.presentation_part() {
    Some(p) => p
    None =>
      raise Malformed(
        "presentation.xml could not be parsed before remove_slide",
      )
  }
  let pres_rels = self.pkg.relationships_for(pres_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let mut target_rid : String? = None
  for s in pres.sld_ids {
    match pres_rels.by_id(s.r_id) {
      Some(rel) => {
        let tgt = @opc.resolve_target(pres_name, rel.target, rel.target_mode)
        if tgt == target_name {
          target_rid = Some(s.r_id)
          break
        }
      }
      None => ()
    }
  }
  let target_rid = match target_rid {
    Some(r) => r
    None =>
      raise Malformed(
        "remove_slide_mut: no <p:sldId> relationship resolves to " + target_name,
      )
  }

  // 2. Collect the slide's own internal relationship targets up front —
  //    these are the orphan-removal candidates once the slide is gone.
  let candidates = self.internal_rel_targets(target_name)

  // 3. Rewrite presentation.xml without the target's <p:sldId>.
  let kept_ids : Array[SlideIdRef] = []
  for s in pres.sld_ids {
    if s.r_id != target_rid {
      kept_ids.push(s)
    }
  }
  let new_pres = { ..pres, sld_ids: kept_ids }
  self.replace_part_bytes(
    pres_name,
    new_pres.serialize(),
    @oxml.ct_presentation,
  )

  // 4. Rewrite presentation.xml.rels without the target relationship.
  let kept_rels : Array[@opc.Relationship] = []
  for r in pres_rels.items {
    if r.id != target_rid {
      kept_rels.push(r)
    }
  }
  self.write_rels_for_part(pres_name, { ..pres_rels, items: kept_rels })

  // 5. Drop the slide part, its .rels, and its content-type Override.
  let _ = self.pkg.remove_part(target_name)
  let _ = self.pkg.remove_part(@opc.rels_path_for(target_name))
  self.pkg.set_content_types(
    self.pkg.content_types().without_override(target_name),
  )

  // 6. Garbage-collect slide-private parts that nothing references now.
  let referenced = self.all_internal_rel_targets()
  for cand in candidates {
    if referenced.contains(cand) {
      continue
    }
    match self.pkg.part_by_name(cand) {
      Some(p) =>
        if is_slide_private_content_type(p.content_type) {
          let _ = self.pkg.remove_part(cand)
          let _ = self.pkg.remove_part(@opc.rels_path_for(cand))
          self.pkg.set_content_types(
            self.pkg.content_types().without_override(cand),
          )
        }
      None => ()
    }
  }

  // 7. Flush the content-type catalog once.
  self.pkg.regenerate_content_types_part() catch {
    e => raise OpcFailure(e.to_string())
  }
}

///|
/// Immutable counterpart of `remove_slide_mut`. Returns a new
/// `Presentation` with the slide at `slide_index` removed; the original
/// is untouched (it owns its own cloned `@opc.Package`).
pub fn Presentation::without_slide(
  self : Presentation,
  slide_index : Int,
) -> Presentation raise PptxError {
  let cloned = self.clone()
  cloned.remove_slide_mut(slide_index)
  cloned
}

// --- helpers ---

///|
/// Resolve the absolute names of every *internal* relationship target
/// originating from `source_part`. External (hyperlink) targets are
/// skipped — they are URLs, not package parts.
fn Presentation::internal_rel_targets(
  self : Presentation,
  source_part : String,
) -> Array[String] raise PptxError {
  let out : Array[String] = []
  let rels = self.pkg.relationships_for(source_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  for r in rels.items {
    match r.target_mode {
      Internal => {
        let abs = @opc.resolve_target(source_part, r.target, r.target_mode)
        if !out.contains(abs) {
          out.push(abs)
        }
      }
      External => ()
    }
  }
  out
}

///|
/// Build the list of absolute part names that *any* surviving part
/// still references through its `.rels`. Used to decide whether an
/// orphan-removal candidate is safe to delete. `.rels` parts and
/// `[Content_Types].xml` are not relationship sources, so they are
/// skipped.
fn Presentation::all_internal_rel_targets(
  self : Presentation,
) -> Array[String] raise PptxError {
  let out : Array[String] = []
  for p in self.pkg.parts() {
    if p.name == @opc.content_types_part_name || is_rels_part(p.name) {
      continue
    }
    for tgt in self.internal_rel_targets(p.name) {
      if !out.contains(tgt) {
        out.push(tgt)
      }
    }
  }
  out
}

///|
/// Whether `name` is an OPC `.rels` part (`…/_rels/….rels`). Such parts
/// are relationship *containers*, not relationship sources.
fn is_rels_part(name : String) -> Bool {
  name.has_suffix(".rels")
}

///|
/// Whether a part with this content type is "slide-private" content
/// that may be garbage-collected when its only referencing slide is
/// removed. Structural parts (slide layout / master / theme / notes
/// master / presentation-level props) are deliberately excluded — they
/// are shared and removing them risks corrupting the package.
fn is_slide_private_content_type(content_type : String) -> Bool {
  content_type == @oxml.ct_notes_slide ||
  content_type == @oxml.ct_chart ||
  content_type == @oxml.ct_chart_ex ||
  content_type.has_prefix("image/") ||
  content_type.has_prefix("video/") ||
  content_type.has_prefix("audio/")
}
