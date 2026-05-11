// Slide model — Phase 3c1 slice.
//
// This commit lands the structural skeleton: a `Slide` carries metadata,
// the layout's color-map override choice (reused from `@slide_master`), and
// a flat list of shapes. The shape enum is a closed ADT today with only
// the `AutoShape` variant filled in; later 3c slices add `Picture`,
// `GroupShape`, `Connector`, `GraphicFrame`. For now everything except
// auto-shapes parses to the `Unknown(local_name)` placeholder so the
// shape tree stays representable end-to-end.

///|
/// A 2D point in EMU coordinates. Both axes use `@units.Emu` so slide-
/// level arithmetic never silently truncates.
pub(all) struct Point {
  x : @units.Emu
  y : @units.Emu
} derive(Eq, Debug)

///|
/// A 2D size in EMU coordinates.
pub(all) struct Size {
  cx : @units.Emu
  cy : @units.Emu
} derive(Eq, Debug)

///|
/// Position + size, mirroring `<a:xfrm>`. `rotation` and `flip*` will be
/// added when Phase 3c starts honouring them; for the skeleton we keep the
/// shape simple.
pub(all) struct Transform {
  offset : Point
  extent : Size
} derive(Eq, Debug)

///|
/// Placeholder metadata, lifted from `<p:nvPr><p:ph type="…" idx="…"/></p:nvPr>`.
/// Not every shape is a placeholder — `None` covers the common case of a
/// regular drawn shape.
///
/// `ph_type` is the OOXML `ST_PlaceholderType` value as a raw string for
/// now; once Phase 3 needs typed placeholder semantics we'll lift it to an
/// enum the same way `SlideLayoutType` was lifted.
pub(all) struct Placeholder {
  ph_type : String
  idx : Int
} derive(Eq, Debug)

///|
/// One shape in a `p:spTree`. Variants are filled in across Phase 3c
/// commits; `Unknown` remains as the temporary catch-all for shape
/// kinds that are not yet modelled (`p:graphicFrame` for tables /
/// charts / SmartArt and `p:contentPart` for extensions).
pub(all) enum Shape {
  AutoShape(AutoShape)
  Picture(Picture)
  Connector(Connector)
  Group(GroupShape)
  /// Placeholder for an as-yet-unmodelled shape kind. Payload is the
  /// element's local name (`graphicFrame`, `contentPart`).
  Unknown(String)
} derive(Eq, Debug)

///|
/// `<p:sp>` — auto-shape. Phase 3c1 covers id, name, placeholder
/// metadata, and transform; Phase 3c2 adds `geometry`. Fill, stroke, text
/// body land in later 3c / 3d slices.
///
/// `geometry` is `Option` because some real-world PPTX places omit
/// `<a:prstGeom>` (e.g. when the shape inherits geometry from a layout
/// placeholder); we don't synthesise a default — `None` means "the part
/// did not specify".
pub(all) struct AutoShape {
  id : Int
  name : String
  placeholder : Placeholder?
  transform : Transform?
  geometry : Geometry?
} derive(Eq, Debug)

///|
/// A parsed slide.
pub(all) struct Slide {
  /// `name` from `<p:cSld name="…">`. Empty if the attribute is absent
  /// (which is the common case — slides are usually unnamed).
  name : String
  /// Top-level shapes inside `<p:spTree>` in source order. The root
  /// group's own metadata (`<p:nvGrpSpPr>` / `<p:grpSpPr>`) is consumed
  /// but not preserved here — it's nearly always trivial.
  shapes : Array[Shape]
  /// Per ECMA-376, slides may carry a `<p:clrMapOvr>` exactly like slide
  /// layouts do. Reuses the layout's enum so the inheritance resolver
  /// works uniformly.
  clr_map_override : @slide_master.ClrMapOverride
} derive(Eq, Debug)
