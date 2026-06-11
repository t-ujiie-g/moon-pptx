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
/// Build a **cycle** diagram — boxes arranged evenly around a ring.
pub fn SmartArt::cycle(items : Array[String]) -> SmartArt {
  { kind: Cycle, nodes: items.map(Node::leaf) }
}

///|
/// Build a **pyramid** diagram — one level per string, widening toward the
/// base (first item is the apex).
pub fn SmartArt::pyramid(items : Array[String]) -> SmartArt {
  { kind: Pyramid, nodes: items.map(Node::leaf) }
}

///|
/// Build an **organisation chart** from a single root node and its (nested)
/// `children` — a top-down tree.
///
/// ```
/// let ceo = @smartart.Node::new("CEO", [
///   @smartart.Node::leaf("CTO"),
///   @smartart.Node::leaf("CFO"),
/// ])
/// let art = @smartart.SmartArt::org_chart(ceo)
/// ```
pub fn SmartArt::org_chart(root : Node) -> SmartArt {
  { kind: OrgChart, nodes: [root] }
}

///|
/// Build a **hierarchy** from one or more root nodes (a forest), each with
/// nested `children` — a layered top-down tree allowing several roots.
pub fn SmartArt::hierarchy(nodes : Array[Node]) -> SmartArt {
  { kind: Hierarchy, nodes }
}

///|
/// General constructor from explicit `Node`s (carries nested children for the
/// hierarchical families).
pub fn SmartArt::new(kind : SmartArtKind, nodes : Array[Node]) -> SmartArt {
  { kind, nodes }
}
