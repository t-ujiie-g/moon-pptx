// Speaker-notes XML reader.
//
// `<p:notes>` has the same `<p:cSld>` + `<p:clrMapOvr>` content model as
// `<p:sld>` (see ECMA-376 §19.3.1.26 vs §19.3.1.38) and re-using the slide
// parser keeps shape-tree behaviour in lockstep — every shape type,
// placeholder rule, and lossless-preservation pass that `@slide` gains
// automatically applies to notes slides too. We delegate to
// `@slide.Slide::parse_with_root(bytes, "notes")` and copy the structural
// fields onto our own `NotesSlide` newtype so consumers can pattern-match
// on the type instead of having to inspect a string tag.

///|
/// Parse a speaker-notes part from raw XML bytes.
///
/// The root element must be `<p:notes>`; any other root raises
/// `SlideFailure` (because the underlying `@slide` parser sees the mismatch
/// first). Mis-flattening that into a notes-domain error would obscure the
/// original schema diagnostic.
pub fn NotesSlide::parse(
  bytes : FixedArray[Byte],
) -> NotesSlide raise NotesError {
  let s = @slide.Slide::parse_with_root(bytes, "notes") catch {
    e => raise SlideFailure(e.to_string())
  }
  {
    name: s.name,
    shapes: s.shapes,
    clr_map_override: s.clr_map_override,
    extension: s.extension,
  }
}
