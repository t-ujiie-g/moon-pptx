// Picture (`p:pic`) shape model + parser.
//
// Schema sketch (ECMA-376 §19.3.1.37):
//
//   <p:pic>
//     <p:nvPicPr>
//       <p:cNvPr id="…" name="…"/>
//       <p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>
//       <p:nvPr/>
//     </p:nvPicPr>
//     <p:blipFill>
//       <a:blip r:embed="rId2" r:link="rId3" cstate="print">
//         <!-- color modifications, image effects -->
//       </a:blip>
//       <a:srcRect l="10000" t="20000" r="5000" b="5000"/>
//       <a:stretch><a:fillRect/></a:stretch>      <!-- OR <a:tile …/> -->
//     </p:blipFill>
//     <p:spPr>
//       <a:xfrm>…</a:xfrm>
//       <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
//     </p:spPr>
//   </p:pic>
//
// Phase 3c3 scope: id, name, the rId(s) the blip references, the source-
// rectangle crop, and reuses the existing `Transform` + `Geometry` from
// `<p:spPr>`. Stretch-vs-tile fill mode and image-effect children are
// skipped via `skip_subtree` until later phases need them.

///|
/// Image source rectangle / crop, in 1000ths of a percent of the source
/// image dimensions. All four sides default to `Percentage(0.0)` if the
/// `<a:srcRect>` element omits them. Negative values are legal per spec
/// and indicate cropping outward (the image extends beyond the box).
pub(all) struct SrcRect {
  left : @units.Percentage
  top : @units.Percentage
  right : @units.Percentage
  bottom : @units.Percentage
} derive(Eq, Debug)

///|
/// `<p:pic>` — picture shape.
///
/// `embed_id` and `link_id` are the `r:embed` and `r:link` values from
/// `<a:blip>`. At least one is required by the spec (and we enforce that
/// at parse time); both may coexist when the picture is embedded with a
/// fallback link.
pub(all) struct Picture {
  id : Int
  name : String
  transform : Transform?
  geometry : Geometry?
  embed_id : String
  link_id : String
  src_rect : SrcRect?
} derive(Eq, Debug)
