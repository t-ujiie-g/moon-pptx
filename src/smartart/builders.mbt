// SmartArt builders (roadmap D1).
//
// Ergonomic constructors that map a flat list of strings (or pre-built
// `Node`s) onto a diagram family. The hierarchical families (org_chart /
// hierarchy / cycle / pyramid / matrix / relationship) named in the roadmap
// land in later slices on the same model.

///|
/// Build a vertical **list** diagram from one box per string.
///
/// ```
/// let art = @smartart.SmartArt::list(["Plan", "Build", "Ship"])
/// ```
pub fn SmartArt::list(items : Array[String]) -> SmartArt {
  { kind: List, nodes: items.map(Node::leaf) }
}

///|
/// Build a left-to-right **process** diagram from one box per string.
pub fn SmartArt::process(items : Array[String]) -> SmartArt {
  { kind: Process, nodes: items.map(Node::leaf) }
}

///|
/// General constructor from explicit `Node`s (for callers that want to carry
/// child nodes through the data model ahead of the hierarchical layouts).
pub fn SmartArt::new(kind : SmartArtKind, nodes : Array[Node]) -> SmartArt {
  { kind, nodes }
}
