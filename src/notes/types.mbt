// Speaker-notes model.
//
// `<p:notes>` (notesSlideN.xml) shares the same `<p:cSld>` + `<p:clrMapOvr>`
// content model as `<p:sld>` per ECMA-376 §19.3.1.26 (`CT_NotesSlide`) vs
// §19.3.1.38 (`CT_Slide`): both wrap a `<p:cSld>` with a `<p:spTree>` and
// an optional `<p:clrMapOvr>`. We therefore re-use `@slide.Shape` for the
// shape list and `@slide_master.ClrMapOverride` for the colour-map
// override, and only the root element name differs at parse time.
//
// Conventional notes content is two placeholders — a slide-image
// placeholder and a body text placeholder for the notes paragraph — but
// the spec lets a notes slide contain any shapes. We don't try to
// special-case the "expected" layout; consumers can inspect `shapes` and
// match on the placeholder type if they care.

///|
/// A parsed speaker-notes slide. Structurally mirrors `@slide.Slide`:
/// the same name, shape list, colour-map override, and lossless
/// extension array.
pub(all) struct NotesSlide {
  /// `name` from `<p:cSld name="…">`. Empty if the attribute is absent.
  name : String
  /// Top-level shapes inside `<p:spTree>` in source order. By convention
  /// a notes slide carries a Slide Image placeholder (`ph type="sldImg"`)
  /// and a Body placeholder for the notes paragraph, but the spec allows
  /// any auto-shape / picture / connector / group / graphic-frame.
  shapes : Array[@slide.Shape]
  /// Per ECMA-376, `<p:notes>` may carry a `<p:clrMapOvr>` exactly like
  /// `<p:sld>` and `<p:sldLayout>` do. Re-uses the same enum so the
  /// inheritance resolver works uniformly.
  clr_map_override : @slide_master.ClrMapOverride
  /// Lossless preservation (ADR-004): unmodelled `<p:notes>` children
  /// (e.g. `<p:transition>` / `<p:timing>` are spec-forbidden but
  /// `<p:custDataLst>` / `<p:extLst>` are allowed), `<p:cSld>` children
  /// (`<p:bg>`, …), `<p:spTree>` siblings (root-group metadata,
  /// foreign-namespace extensions). Same shape as `Slide.extension`.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
