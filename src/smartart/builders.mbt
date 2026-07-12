// SmartArt builders.
//
// Ergonomic constructors that map a flat list of strings (or pre-built
// `Node`s) onto a diagram family: list / process / cycle / pyramid / matrix
// are flat, org_chart / hierarchy / relationship consume `Node` trees.

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
/// Build a **matrix** diagram — one box per string laid out in a
/// roughly-square grid (e.g. four items → a 2×2 quadrant matrix).
pub fn SmartArt::matrix(items : Array[String]) -> SmartArt {
  { kind: Matrix, nodes: items.map(Node::leaf) }
}

///|
/// Build a **relationship** diagram — a central hub (`center`) surrounded by
/// the `related` items (hub-and-spoke / radial). The hub is the root; the
/// related items (plus any existing children of `center`) become its spokes.
pub fn SmartArt::relationship(center : Node, related : Array[Node]) -> SmartArt {
  let hub = Node::new(center.text, [..center.children, ..related])
  { kind: Relationship, nodes: [hub] }
}

///|
/// General constructor from explicit `Node`s (carries nested children for the
/// hierarchical families).
pub fn SmartArt::new(kind : SmartArtKind, nodes : Array[Node]) -> SmartArt {
  { kind, nodes }
}
