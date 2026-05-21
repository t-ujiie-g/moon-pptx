// Custom-geometry model — Phase 3h slice.
//
// Per ECMA-376 §20.1.9.8 (`CT_CustomGeometry2D`), a custom shape draws
// itself from an explicit list of path commands instead of selecting a
// named `<a:prstGeom>` preset. The body is:
//
//   <a:custGeom>
//     <a:avLst>     adjustable guide formulas (user-tunable)
//       <a:gd name="adj1" fmla="val 25000"/>
//     </a:avLst>
//     <a:gdLst>     computed guide formulas (read-only)
//       <a:gd name="x1" fmla="*/ w adj1 100000"/>
//     </a:gdLst>
//     <a:ahLst>…</a:ahLst>     adjustment handles (rare; preserved verbatim)
//     <a:cxnLst>               connection sites where connectors attach
//       <a:cxn ang="0"><a:pos x="0" y="0"/></a:cxn>
//     </a:cxnLst>
//     <a:rect l="0" t="0" r="w" b="h"/>     text-fit rectangle
//     <a:pathLst>
//       <a:path w="…" h="…" fill="norm" stroke="1" extrusionOk="0">
//         <a:moveTo><a:pt x="0"   y="0"/></a:moveTo>
//         <a:lnTo>  <a:pt x="100" y="0"/></a:lnTo>
//         <a:cubicBezTo>…</a:cubicBezTo>
//         <a:quadBezTo>…</a:quadBezTo>
//         <a:arcTo wR="…" hR="…" stAng="…" swAng="…"/>
//         <a:close/>
//       </a:path>
//     </a:pathLst>
//   </a:custGeom>
//
// Coordinates inside path commands are `ST_AdjCoordinate` — either a
// literal EMU integer or the name of a guide formula declared in
// `<a:gdLst>` / `<a:avLst>`. We expose both forms via `AdjCoordinate`
// so callers see the raw reference without us having to evaluate the
// guide-formula DSL (`*/`, `+- `, `pin`, `sin`, `cos`, …) ahead of time.
//
// Adjust handles (`<a:ahLst>`) are user-draggable knobs in PowerPoint's
// UI and have a deeply nested schema (`CT_XYAdjustHandle` vs
// `CT_PolarAdjustHandle`, each with min/max guide refs, etc.). Real-
// world files use them only inside Office-shipped preset families; for
// the rare custGeom that carries one, we preserve the subtree on
// `CustomGeometry.extension` per ADR-004 instead of typing it now.

///|
/// One coordinate inside a custom-geometry path point or rectangle bound.
///
/// `Literal(emu)` is the common case — a hard-coded EMU value, often `0`
/// or `w`/`h` resolved into a number by the producer.  `GuideRef(name)`
/// references a `<a:gd name="…"/>` formula declared in `gdLst` or
/// `avLst`; resolving the reference requires evaluating the OOXML
/// guide-formula DSL, which we defer to consumers (or a later phase).
pub(all) enum AdjCoordinate {
  /// A literal EMU value (`ST_Coordinate`).
  Literal(@units.Emu)
  /// A reference to a named guide formula (`ST_GeomGuideName`).
  GuideRef(String)
} derive(Eq, Debug)

///|
/// One angle attribute (`stAng` / `swAng` on `<a:arcTo>`, `ang` on
/// `<a:cxn>`). Same union shape as `AdjCoordinate` but with `Angle` as
/// the literal type — the spec calls this `ST_AdjAngle`.
pub(all) enum AdjAngle {
  Literal(@units.Angle)
  GuideRef(String)
} derive(Eq, Debug)

///|
/// One `<a:pt x="…" y="…"/>` point inside a path command. Both axes
/// independently use `ST_AdjCoordinate`.
pub(all) struct PathPoint {
  x : AdjCoordinate
  y : AdjCoordinate
} derive(Eq, Debug)

///|
/// One draw command inside `<a:path>`. Order matters — paths replay
/// commands in source order to build the outline.
///
/// `ArcTo`'s parameter order matches the XML attributes:
/// `wR` (x-radius), `hR` (y-radius), `stAng` (start angle), `swAng`
/// (sweep angle, signed — positive sweeps clockwise in DrawingML).
pub(all) enum PathCommand {
  /// `<a:moveTo>` — pen-up move to the listed point. Conventionally the
  /// first command of each `<a:path>`.
  MoveTo(PathPoint)
  /// `<a:lnTo>` — straight line to the listed point.
  LnTo(PathPoint)
  /// `<a:cubicBezTo>` — cubic Bézier with two control points and an end
  /// point, in that source order.
  CubicBezTo(PathPoint, PathPoint, PathPoint)
  /// `<a:quadBezTo>` — quadratic Bézier with one control point and an
  /// end point.
  QuadBezTo(PathPoint, PathPoint)
  /// `<a:arcTo>` — elliptical arc. `(wR, hR, stAng, swAng)`.
  ArcTo(AdjCoordinate, AdjCoordinate, AdjAngle, AdjAngle)
  /// `<a:close/>` — close the current subpath back to the last `MoveTo`.
  Close
} derive(Eq, Debug)

///|
/// `<a:path>` fill behaviour (`ST_PathFillMode`). `norm` is the common
/// case — fill with the shape's fill style. The `lighten*` / `darken*`
/// variants tint the fill, used by some preset shapes for highlights /
/// shadows in stylised geometry.
pub(all) enum PathFillMode {
  /// `none` — do not fill this subpath. Used when a `<a:path>` is
  /// stroke-only.
  PathFillNone
  /// `norm` — fill with the shape's `<a:solidFill>` / etc.
  PathFillNorm
  /// `lighten`
  PathFillLighten
  /// `lightenLess`
  PathFillLightenLess
  /// `darken`
  PathFillDarken
  /// `darkenLess`
  PathFillDarkenLess
} derive(Eq, Debug)

///|
/// Parse the `fill` attribute on `<a:path>`. Unknown values fall back
/// to `PathFillNorm` — every Office release accepts that as the
/// effective default for absent or malformed `fill` attrs.
pub fn PathFillMode::from_xml(s : String) -> PathFillMode {
  match s {
    "none" => PathFillNone
    "norm" => PathFillNorm
    "lighten" => PathFillLighten
    "lightenLess" => PathFillLightenLess
    "darken" => PathFillDarken
    "darkenLess" => PathFillDarkenLess
    _ => PathFillNorm
  }
}

///|
/// Render a `PathFillMode` back to its `fill` attribute value.
pub fn PathFillMode::to_xml(self : PathFillMode) -> String {
  match self {
    PathFillNone => "none"
    PathFillNorm => "norm"
    PathFillLighten => "lighten"
    PathFillLightenLess => "lightenLess"
    PathFillDarken => "darken"
    PathFillDarkenLess => "darkenLess"
  }
}

///|
/// One `<a:path>` inside `<a:pathLst>`. `w` / `h` declare the coordinate
/// space this path uses — the producer designs path points relative to
/// `[0..w, 0..h]` and PowerPoint scales them to the shape's actual size
/// at render time. When the attributes are absent the spec uses `0`,
/// which effectively makes the path collapse to a point; we surface
/// that as an `@units.Emu(0L)` rather than `Option` since the spec
/// itself names a default.
pub(all) struct Path {
  /// `w` attribute (default `0`).
  w : @units.Emu
  /// `h` attribute (default `0`).
  h : @units.Emu
  /// `fill` attribute (default `norm`).
  fill : PathFillMode
  /// `stroke` attribute (default `true`).
  stroke : Bool
  /// `extrusionOk` attribute (default `true`).
  extrusion_ok : Bool
  /// Draw commands in source order.
  commands : Array[PathCommand]
  /// Lossless preservation (ADR-004): unmodelled `<a:path>` children
  /// — none defined by the spec today, but kept for forward-compat.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// `<a:rect>` — the text-fit rectangle inside a custom shape. Each
/// edge is an `ST_AdjCoordinate`, so corners can reference guide
/// formulas (`l="l"`, `t="t"`, `r="r"`, `b="b"` is the common case for
/// shapes that derive their rect from named guides).
pub(all) struct GeomRect {
  l : AdjCoordinate
  t : AdjCoordinate
  r : AdjCoordinate
  b : AdjCoordinate
} derive(Eq, Debug)

///|
/// `<a:cxn>` — one connection site on a custom shape. Connectors that
/// bind to this shape use the `idx` (the connection site's index in
/// source order inside `<a:cxnLst>`) to refer back to this site.
pub(all) struct ConnectionSite {
  /// `ang` attribute — the surface-normal angle at the site.
  ang : AdjAngle
  /// `<a:pos x="…" y="…"/>` child — site position in path coordinates.
  pos : PathPoint
  /// Lossless preservation (ADR-004): unmodelled children of `<a:cxn>`.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// A parsed `<a:custGeom>` body — the typed counterpart to the prior
/// `Geometry::Custom(@xml.XmlElement)` capture.
///
/// `adjust_values` come from `<a:avLst>` (user-tunable guides) and
/// `guides` come from `<a:gdLst>` (computed-from-adjustments guides);
/// the schema doesn't actually require this separation — `<a:gd>` looks
/// the same in both lists — but the two-list split matches how Office
/// classifies them, which downstream consumers (e.g. shape editors)
/// rely on.  Both reuse `ShapeAdjustValue` (`{ name, fmla }`).
pub(all) struct CustomGeometry {
  /// `<a:avLst>` — adjustable guides, user-tunable per shape instance.
  adjust_values : Array[ShapeAdjustValue]
  /// `<a:gdLst>` — derived guides, formulas referencing `avLst` and
  /// reserved names (`w`, `h`, `l`, `t`, `r`, `b`, …).
  guides : Array[ShapeAdjustValue]
  /// `<a:cxnLst>` — connection sites, ordered (the index is the join
  /// key from `<a:stCxn idx="…"/>` / `<a:endCxn idx="…"/>` on
  /// connectors).
  connection_sites : Array[ConnectionSite]
  /// `<a:rect>` — text-fit rectangle. Optional; absent means PowerPoint
  /// inscribes the rect at the path's bounding box.
  rect : GeomRect?
  /// `<a:pathLst>` — one or more paths.  Required by the spec; we keep
  /// it as `Array[Path]` so the typical single-path case carries no
  /// allocation overhead beyond the array.
  paths : Array[Path]
  /// Lossless preservation (ADR-004): `<a:ahLst>` (adjust handles —
  /// rare and deeply nested, deferred), `<a:extLst>`, and any
  /// foreign-namespace children of `<a:custGeom>`.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
