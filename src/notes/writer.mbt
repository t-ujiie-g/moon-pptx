// Speaker-notes XML writer — Phase 4f slice.
//
// Mirror of `parser.mbt`: `NotesSlide::serialize` delegates to the
// shared `@slide.Slide::serialize_with_root(bytes, "notes")` so the
// shape-tree / clrMapOvr / extension replay logic stays in lockstep
// with the regular slide writer.

///|
/// Serialise a `NotesSlide` back to `notesSlideN.xml`-shaped bytes.
pub fn NotesSlide::serialize(
  self : NotesSlide,
) -> FixedArray[Byte] raise NotesError {
  // The shared slide writer takes a `@slide.Slide`; re-pack our fields
  // into one and delegate.
  let s : @slide.Slide = {
    name: self.name,
    shapes: self.shapes,
    clr_map_override: self.clr_map_override,
    extension: self.extension,
  }
  s.serialize_with_root("notes") catch {
    e => raise SlideFailure(e.to_string())
  }
}
