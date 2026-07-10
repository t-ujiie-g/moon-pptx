// SmartArt model.
//
// A `SmartArt` is a typed description of a diagram: a `SmartArtKind` (which
// built-in layout family it maps to) plus a list of top-level `Node`s. From
// it we synthesise the five DiagramML parts PowerPoint needs — data / layout /
// quickStyle / colors + a cached `<dsp:drawing>` (the laid-out shapes, so the
// diagram renders without a layout engine). See `parts.mbt`.
//
// All eight families ship: the *flat* ones (`List` / `Process` / `Cycle` /
// `Pyramid` / `Matrix`) lay out from the flat list of top-level nodes, and
// the *nesting* ones (`OrgChart` / `Hierarchy` / `Relationship`) consume
// `Node.children` — both in the data model and in the recursive / radial
// layout definitions (`hier_layouts.mbt`) PowerPoint lays out from.

///|
/// Which built-in SmartArt layout family a diagram maps to.
pub(all) enum SmartArtKind {
  /// Vertical list of rounded boxes (built-in layout `list1`).
  List
  /// Left-to-right sequence of boxes (built-in layout `process1`).
  Process
  /// Boxes arranged evenly around a ring (built-in layout `cycle1`).
  Cycle
  /// Stacked levels widening toward the base (built-in layout `pyramid1`).
  Pyramid
  /// Top-down organisation chart from a single root (built-in `orgChart1`).
  OrgChart
  /// Layered hierarchy from one or more roots (built-in `hierarchy1`).
  Hierarchy
  /// Items arranged in a roughly-square grid (built-in `matrix1`).
  Matrix
  /// A central hub with related items around it (built-in `radial1`).
  Relationship
} derive(Eq, Debug)

///|
/// Per-node colour overrides on top of the diagram's quick style. Absent
/// fields keep the styleLbl defaults (accent-1 boxes, light outlines). The
/// overrides go into both the data model (the point's `<dgm:spPr>` /
/// `<dgm:t>` run properties, which PowerPoint's layout engine applies on
/// re-layout) and the cached drawing (for viewers that don't re-lay-out).
pub(all) struct NodeStyle {
  /// Box fill colour.
  fill : @units.RgbColor?
  /// Box outline colour.
  line : @units.RgbColor?
  /// Text colour.
  text_color : @units.RgbColor?
} derive(Eq, Debug)

///|
/// A style overriding only the given aspects (omitted ones keep the
/// diagram's quick-style defaults).
pub fn NodeStyle::new(
  fill? : @units.RgbColor,
  line? : @units.RgbColor,
  text_color? : @units.RgbColor,
) -> NodeStyle {
  { fill, line, text_color }
}

///|
/// One node in a SmartArt diagram: its text plus any child nodes. For the
/// slice-1 linear families only the top-level nodes are laid out; children are
/// preserved in the data model for round-trip + future hierarchical layouts.
pub(all) struct Node {
  text : String
  children : Array[Node]
  /// Colour overrides for this node's box, or `None` for the quick-style
  /// defaults.
  style : NodeStyle?
} derive(Eq, Debug)

///|
/// A leaf node carrying just `text` (no children).
pub fn Node::leaf(text : String) -> Node {
  { text, children: [], style: None }
}

///|
/// A node with `text` and the given `children`.
pub fn Node::new(text : String, children : Array[Node]) -> Node {
  { text, children, style: None }
}

///|
/// This node with its box filled `rgb` (other style aspects unchanged).
pub fn Node::with_fill(self : Node, rgb : @units.RgbColor) -> Node {
  let s = self.style.unwrap_or(NodeStyle::new())
  { ..self, style: Some({ ..s, fill: Some(rgb) }) }
}

///|
/// This node with its box outlined `rgb` (other style aspects unchanged).
pub fn Node::with_line(self : Node, rgb : @units.RgbColor) -> Node {
  let s = self.style.unwrap_or(NodeStyle::new())
  { ..self, style: Some({ ..s, line: Some(rgb) }) }
}

///|
/// This node with its text coloured `rgb` (other style aspects unchanged).
pub fn Node::with_text_color(self : Node, rgb : @units.RgbColor) -> Node {
  let s = self.style.unwrap_or(NodeStyle::new())
  { ..self, style: Some({ ..s, text_color: Some(rgb) }) }
}

///|
/// A complete SmartArt diagram — a `kind` plus its top-level `nodes`.
pub(all) struct SmartArt {
  kind : SmartArtKind
  nodes : Array[Node]
} derive(Eq, Debug)
