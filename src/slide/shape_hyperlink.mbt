// Shape-level hyperlink / click action (`<p:cNvPr><a:hlinkClick>`).
//
// A hyperlink on a *whole shape* lives on its `<p:cNvPr>` as an
// `<a:hlinkClick>` child. This mirrors the run-level model
// (`RunProperties::with_hyperlink`) exactly: the builder stores an
// **unresolved** `target` (a URL or a jump-to-slide index), and
// `Presentation::update_slide_mut` resolves it into a slide-rels `rId`
// (`click`) + the `action` attribute just before serialisation (shared
// resolver with run hyperlinks).
//
// Build-only, like media and animations: a *parsed* shape's
// `<a:hlinkClick>` round-trips losslessly through the captured `<p:cNvPr>`
// in `extension` (ADR-004), so the parser leaves `hyperlink = None`; the
// typed field is set only by the builders.

///|
/// A hyperlink attached to a whole shape (`<p:cNvPr><a:hlinkClick>`).
/// `target` is the unresolved destination set by the builder; `click` /
/// `action` are filled by the resolver (`update_slide_mut`).
pub(all) struct ShapeHyperlink {
  /// Unresolved destination set by `with_hyperlink` /
  /// `with_hyperlink_to_slide`. Cleared once resolved.
  target : HyperlinkTarget?
  /// Resolved relationship id emitted as `<a:hlinkClick r:id="…">`.
  click : String?
  /// Optional `action` attribute — `"ppaction://hlinksldjump"` for
  /// internal-slide jumps (set by the resolver), `None` for external URLs.
  action : String?
} derive(Eq, Debug)

///|
/// A shape hyperlink to an external URL (`https://`, `mailto:`, …).
/// Unresolved until `Presentation::update_slide_mut` allocates its rId.
pub fn ShapeHyperlink::external(url : String) -> ShapeHyperlink {
  { target: Some(ExternalUrl(url)), click: None, action: None }
}

///|
/// A shape hyperlink that jumps to another slide by zero-based index (as
/// in `Presentation::slides()`). Resolved to an `rt_slide` relationship +
/// `action="ppaction://hlinksldjump"`.
pub fn ShapeHyperlink::to_slide(slide_idx : Int) -> ShapeHyperlink {
  { target: Some(InternalSlide(slide_idx)), click: None, action: None }
}

///|
/// The resolved `<a:hlinkClick>` element to emit on `<p:cNvPr>`, or `None`
/// when the hyperlink is absent or not yet resolved (no `click` rId). Used
/// by the shape writer.
fn ShapeHyperlink::resolved_element(self : ShapeHyperlink) -> @xml.XmlElement? {
  match self.click {
    Some(rid) => {
      let attrs : Array[(@xml.QName, String)] = [
        (@xml.QName::new(@oxml.office_relationships_ns, "id"), rid),
      ]
      match self.action {
        Some(a) => attrs.push((@xml.QName::unqualified("action"), a))
        None => ()
      }
      Some(
        @xml.XmlElement::new(
          @xml.QName::new(@oxml.drawing_ns, "hlinkClick"),
          attrs,
          [],
        ),
      )
    }
    None => None
  }
}
