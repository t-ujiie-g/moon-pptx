// Node-tree flattening.
//
// The data model and the cached drawing both need every node in the diagram —
// not just the top-level ones — keyed by a stable id and tagged with its
// parent, sibling order, and depth. `flatten` does a pre-order walk producing
// that flat view; both writers consume it so their `modelId`s agree.
//
// A *flat* family (List / Process / Cycle / Pyramid) is just a depth-1 tree:
// every node is a child of the document with no children of its own, so the
// flattened list is exactly the top-level node list and the generated parts
// are byte-equivalent to the slice-1/2 output.

///|
/// One node in pre-order, with the structure both writers need.
priv struct FlatNode {
  /// Global pre-order index — the node's box index and the seed for its
  /// `modelId` / transition / connection ids.
  gidx : Int
  text : String
  /// Parent's `gidx`, or `None` when the node is a child of the document root.
  parent_gidx : Int?
  /// Position among its siblings (under the same parent / the document).
  sib_ord : Int
  /// Depth from the roots — `0` for a top-level node.
  depth : Int
  /// `gidx`s of this node's direct children (left-to-right).
  mut children_gidx : Array[Int]
}

///|
/// Pre-order flatten of the node forest. Returns one `FlatNode` per node in
/// the diagram, in pre-order (so leaves appear left-to-right and every child's
/// `gidx` is greater than its parent's).
fn flatten(nodes : Array[Node]) -> Array[FlatNode] {
  let out = []
  fn visit(node : Node, parent : Int?, sib_ord : Int, depth : Int) -> Int {
    let gidx = out.length()
    out.push({
      gidx,
      text: node.text,
      parent_gidx: parent,
      sib_ord,
      depth,
      children_gidx: [],
    })
    let child_ids = []
    for j, c in node.children {
      child_ids.push(visit(c, Some(gidx), j, depth + 1))
    }
    out[gidx].children_gidx = child_ids
    gidx
  }

  for j, root in nodes {
    visit(root, None, j, 0) |> ignore
  }
  out
}

///|
/// Whether a flat node is a leaf (no children) — used by the tree layout.
fn FlatNode::is_leaf(self : FlatNode) -> Bool {
  self.children_gidx.length() == 0
}
