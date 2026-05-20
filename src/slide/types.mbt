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
/// commits; `Unknown` remains as the catch-all for shape kinds that are
/// not yet modelled (`p:graphicFrame` for tables / charts / SmartArt and
/// `p:contentPart` for extensions). Per ADR-004 the variant carries the
/// full captured element so unknown shapes survive a read → write
/// round-trip verbatim.
pub(all) enum Shape {
  AutoShape(AutoShape)
  Picture(Picture)
  Connector(Connector)
  Group(GroupShape)
  /// The full XML subtree of an unmodelled shape kind. The element's
  /// local name (`graphicFrame`, `contentPart`, …) is reachable via
  /// `el.name.local_name`.
  Unknown(@xml.XmlElement)
} derive(Eq, Debug)

///|
/// `<p:sp>` — auto-shape. Phase 3c1 covers id, name, placeholder
/// metadata, and transform; Phase 3c2 adds `geometry`; Phase 3d1 adds
/// `text_body`. Fill, stroke, and run/paragraph formatting land in later
/// 3d / 3e slices.
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
  /// `<a:ln>` outline parsed off `<p:spPr>`. `None` means "inherit
  /// from the placeholder / theme defaults".
  stroke : @oxml.Stroke?
  /// `<a:effectLst>` parsed off `<p:spPr>` — shadow / glow / etc.
  effects : @oxml.EffectList?
  text_body : TextBody?
  /// Lossless preservation (ADR-004): unmodelled `<p:sp>` siblings
  /// (`<p:style>`, `<p:extLst>`, foreign-namespace extensions, …)
  /// captured verbatim for round-trip writers.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// A parsed slide.
pub(all) struct Slide {
  /// `name` from `<p:cSld name="…">`. Empty if the attribute is absent
  /// (which is the common case — slides are usually unnamed).
  name : String
  /// Top-level shapes inside `<p:spTree>` in source order. The root
  /// group's own metadata (`<p:nvGrpSpPr>` / `<p:grpSpPr>`) is captured
  /// into `extension` for round-trip preservation.
  shapes : Array[Shape]
  /// Per ECMA-376, slides may carry a `<p:clrMapOvr>` exactly like slide
  /// layouts do. Reuses the layout's enum so the inheritance resolver
  /// works uniformly.
  clr_map_override : @slide_master.ClrMapOverride
  /// Lossless preservation (ADR-004): unmodelled `<p:sld>` children
  /// (`<p:transition>`, `<p:timing>`, `<p:custDataLst>`, `<p:extLst>`),
  /// unmodelled `<p:cSld>` children (`<p:bg>`, …), and unmodelled
  /// `<p:spTree>` siblings (root group metadata, foreign-namespace
  /// extensions). Source order is preserved within the array; cross-
  /// section ordering is *not* — Phase 4 writers re-emit each captured
  /// element under its original parent based on the element's name.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
