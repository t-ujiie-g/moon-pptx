// Slide model.
//
// A `Slide` carries metadata, the layout's color-map override choice
// (reused from `@slide_master`), and a flat list of shapes. The
// `Shape` enum covers every spec'd shape kind: AutoShape, Picture,
// Connector, Group, GraphicFrame (table / chart / chartEx / OLE).
// `Unknown(XmlElement)` catches any unmodelled shape kind (mostly
// `<p:contentPart>`) so the shape tree survives a read → write
// round-trip verbatim per ADR-004.

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
/// Position + size, mirroring `<a:xfrm>`. `rotation` and `flip*` are
/// not modelled yet; they round-trip through the enclosing shape's
/// `extension` per ADR-004.
pub(all) struct Transform {
  offset : Point
  extent : Size
} derive(Eq, Debug)

///|
/// Placeholder metadata, lifted from `<p:nvPr><p:ph type="…" idx="…"/></p:nvPr>`.
/// Not every shape is a placeholder — `None` covers the common case of a
/// regular drawn shape.
///
/// `ph_type` is the OOXML `ST_PlaceholderType` value as a raw string;
/// typed-enum lift is deferred until a consumer needs typed
/// placeholder semantics, the same way `SlideLayoutType` was lifted.
pub(all) struct Placeholder {
  ph_type : String
  idx : Int
} derive(Eq, Debug)

///|
/// One shape in a `p:spTree`. Every spec'd shape kind has a typed
/// variant; `Unknown` catches anything unmodelled (mostly
/// `<p:contentPart>` extension shapes). Per ADR-004 the variant
/// carries the full captured element so unknown shapes survive a
/// read → write round-trip verbatim.
pub(all) enum Shape {
  AutoShape(AutoShape)
  Picture(Picture)
  Connector(Connector)
  Group(GroupShape)
  /// `<p:graphicFrame>` hosting a table / chart / chartEx / OLE
  /// payload. The `content` field discriminates among them; see
  /// `GraphicFrameContent`.
  GraphicFrame(GraphicFrame)
  /// The full XML subtree of an unmodelled shape kind. Typically
  /// `<p:contentPart>` extension shapes; new shape kinds start here
  /// and graduate to a typed variant when added.
  Unknown(@xml.XmlElement)
} derive(Eq, Debug)

///|
/// `<p:sp>` — auto-shape. Covers id, name, placeholder metadata,
/// transform, geometry, line stroke, effects, and the text body.
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
  /// `<a:solidFill>` / `<a:gradFill>` / `<a:pattFill>` / `<a:blipFill>`
  /// / `<a:noFill>` parsed off `<p:spPr>`. `None` means "inherit from
  /// the placeholder / theme defaults" — which, for non-placeholder
  /// shapes, renders as a fully transparent shape in PowerPoint /
  /// LibreOffice. Builders therefore default to `Some(SolidFill(…))`.
  fill : @oxml.Fill?
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
  /// section ordering is *not* — writers re-emit each captured
  /// element under its original parent based on the element's name.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
