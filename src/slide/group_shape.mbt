// Group shape (`p:grpSp`) model — recursive.
//
// A group shape carries its own non-visual props + group-shape props (with
// the standard `<a:xfrm>` plus `<a:chOff>` / `<a:chExt>` defining the
// child coordinate space), then nests an arbitrary mix of shape kinds
// inside — including more group shapes.
//
//   <p:grpSp>
//     <p:nvGrpSpPr>
//       <p:cNvPr id="10" name="Group 1"/>
//       <p:cNvGrpSpPr/>
//       <p:nvPr/>
//     </p:nvGrpSpPr>
//     <p:grpSpPr>
//       <a:xfrm>
//         <a:off x="…" y="…"/>
//         <a:ext cx="…" cy="…"/>
//         <a:chOff x="0" y="0"/>
//         <a:chExt cx="…" cy="…"/>
//       </a:xfrm>
//     </p:grpSpPr>
//     <p:sp/> | <p:pic/> | <p:cxnSp/> | <p:grpSp/> | <p:graphicFrame/>
//   </p:grpSp>

///|
/// `<p:grpSp>` — recursive container.
///
/// `transform` is the group's own placement (`<a:off>` + `<a:ext>`).
/// `child_offset` and `child_extent` together describe the local
/// coordinate space children are positioned in (`<a:chOff>` + `<a:chExt>`);
/// applying them is the renderer's job, not the parser's.
pub(all) struct GroupShape {
  id : Int
  name : String
  transform : Transform?
  child_offset : Point?
  child_extent : Size?
  children : Array[Shape]
  /// Lossless preservation (ADR-004): unmodelled `<p:grpSp>` siblings
  /// (foreign-namespace extensions, future shape kinds, …) captured
  /// verbatim.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)
