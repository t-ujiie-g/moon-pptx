// Ad-hoc XML DOM for lossless preservation of unknown subtrees.
//
// `XmlReader` is event-based by design (ADR-008). For most parsing paths we
// only need to recognise the elements we model and skip the rest cheaply.
// But ADR-004 promises that unknown OOXML chunks survive read → write
// verbatim, which means at the skip points we instead want to *capture* the
// subtree as a small DOM and stash it on the surrounding model node.
//
// `XmlElement` / `XmlNode` are that capture format. They mirror the event
// stream exactly: an element has a qualified name, attributes in source
// order, and children that are either nested elements, text, or CDATA. No
// schema interpretation; no defaults; no normalisation. The intent is that
// `XmlElement -> XmlWriter` later in Phase 4 produces semantically
// equivalent XML, even when the original element kind has no typed parser.

///|
/// A single XML element captured into an ad-hoc DOM. Attributes are in
/// source order; their values are already entity-decoded (matching what
/// `XmlReader` emits in `StartElement`).
pub(all) struct XmlElement {
  name : QName
  attributes : Array[(QName, String)]
  children : Array[XmlNode]
} derive(Eq, Debug)

///|
/// One child of an `XmlElement`. The four reader events
/// (`StartElement`/`EndElement`/`Text`/`CData`) compress to three node
/// kinds — `EndElement` is implicit in the parent boundary.
pub(all) enum XmlNode {
  Element(XmlElement)
  Text(String)
  CData(String)
} derive(Eq, Debug)

///|
/// Convenience constructor. Intended for tests / hand-built fixtures; real
/// readers build `XmlElement` via the `collect_subtree` helper.
pub fn XmlElement::new(
  name : QName,
  attributes : Array[(QName, String)],
  children : Array[XmlNode],
) -> XmlElement {
  { name, attributes, children }
}

///|
pub impl Show for XmlElement with fn output(self, logger) {
  logger.write_string("XmlElement(")
  logger.write_object(self.name)
  logger.write_string(", attrs=")
  logger.write_object(self.attributes.length())
  logger.write_string(", children=")
  logger.write_object(self.children.length())
  logger.write_string(")")
}

///|
pub impl Show for XmlNode with fn output(self, logger) {
  match self {
    Element(e) => logger.write_object(e)
    Text(s) => {
      logger.write_string("Text(")
      logger.write_object(s)
      logger.write_string(")")
    }
    CData(s) => {
      logger.write_string("CData(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}
