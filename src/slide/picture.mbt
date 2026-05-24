// Picture (`p:pic`) shape model.
//
// Schema sketch (ECMA-376 §19.3.1.37):
//
//   <p:pic>
//     <p:nvPicPr>
//       <p:cNvPr id="…" name="…"/>
//       <p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>
//       <p:nvPr/>
//     </p:nvPicPr>
//     <p:blipFill>…</p:blipFill>
//     <p:spPr>
//       <a:xfrm>…</a:xfrm>
//       <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
//     </p:spPr>
//   </p:pic>
//
// `<p:blipFill>` shares its body shape with the DrawingML `<a:blipFill>`
// — same `<a:blip>` + optional `<a:srcRect>` + `<a:stretch>` / `<a:tile>`
// fill-mode child. We delegate to `@oxml.parse_fill` so blip handling
// is shared between picture shapes and shape-level fills.

///|
/// `<p:pic>` — picture shape. The picture-specific bits (blip embed /
/// link rIds, optional source-rectangle crop, stretch-vs-tile fill mode)
/// all live in `blip_fill`.
pub(all) struct Picture {
  id : Int
  name : String
  transform : Transform?
  geometry : Geometry?
  /// `<a:ln>` outline parsed off `<p:spPr>` — e.g. a border around the
  /// picture. `None` means the picture has no outline.
  stroke : @oxml.Stroke?
  /// `<a:effectLst>` parsed off `<p:spPr>` — shadow / glow / etc.
  effects : @oxml.EffectList?
  blip_fill : @oxml.BlipFill
  /// Lossless preservation (ADR-004): unmodelled `<p:pic>` siblings
  /// (`<p:style>`, `<p:extLst>`, …) captured verbatim.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
