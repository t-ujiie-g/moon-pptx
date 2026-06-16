// SmartArt graphic-frame builder (roadmap D1).
//
// A SmartArt diagram on a slide is a `<p:graphicFrame>` whose
// `<a:graphicData uri="…/diagram">` carries a single `<dgm:relIds>` element —
// four relationship ids (data / layout / quickStyle / colors) pointing at the
// diagram parts. We reuse the existing `OtherGraphic` round-trip path (the
// same way a *parsed* SmartArt round-trips, ADR-004) rather than adding a new
// typed `GraphicFrameContent` variant: the writer already re-emits an
// `OtherGraphic`'s `<a:graphicData>` children verbatim, so building the
// `<dgm:relIds>` element by hand needs no parser/writer changes. The four
// relationships + the five OPC parts are wired by
// `@presentation.Presentation::add_smartart_mut`.

///|
/// Wrap a SmartArt diagram's four relationship ids in a `GraphicFrame`. `dm` /
/// `lo` / `qs` / `cs` are the slide's relationship ids pointing at the data /
/// layout / quickStyle / colors parts respectively. Pair with
/// `@presentation.Presentation::add_smartart_mut` for the full OPC plumbing.
pub fn GraphicFrame::of_diagram_ref(
  id : Int,
  name : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
  dm : String,
  lo : String,
  qs : String,
  cs : String,
) -> GraphicFrame {
  let rel_ids = @xml.XmlElement::new(
    @xml.QName::new(@oxml.diagram_ns, "relIds"),
    [
      (@xml.QName::new(@oxml.office_relationships_ns, "dm"), dm),
      (@xml.QName::new(@oxml.office_relationships_ns, "lo"), lo),
      (@xml.QName::new(@oxml.office_relationships_ns, "qs"), qs),
      (@xml.QName::new(@oxml.office_relationships_ns, "cs"), cs),
    ],
    [],
  )
  // The captured element stands in for the original `<a:graphicData>`; the
  // writer emits its children (the `<dgm:relIds>`) verbatim.
  let graphic_data = @xml.XmlElement::new(
    @xml.QName::new(@oxml.drawing_ns, "graphicData"),
    [],
    [Element(rel_ids)],
  )
  {
    id,
    name,
    transform: Some(Transform::new(offset={ x, y }, extent={ cx, cy })),
    content: OtherGraphic(@oxml.graphic_data_diagram_uri, graphic_data),
    extension: [],
  }
}
