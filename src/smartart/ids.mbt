// Deterministic model-id generation (roadmap D1).
//
// DiagramML points and connections are keyed by `ST_ModelId` — a union of
// xsd:int and a GUID. PowerPoint emits GUIDs; we synthesise stable GUID-shaped
// ids from a (category, index) pair so every point / connection / transition
// gets a unique, reproducible id (reproducibility keeps round-trip + golden
// tests deterministic). The data model and the cached drawing reference the
// same node ids, so they must agree — both call `node_id`.

///|
let hex_digits : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
]

///|
/// Lowercase-free zero-padded hex of `n` to `width` digits.
fn hex_pad(n : Int, width : Int) -> String {
  let chars = Array::make(width, '0')
  let mut v = n
  for i = width - 1; i >= 0; i = i - 1 {
    chars[i] = hex_digits[v % 16]
    v = v / 16
  }
  String::from_array(chars)
}

///|
/// A GUID-shaped id `{CCCCCCCC-0000-0000-0000-IIIIIIIIIIII}` from a category
/// tag and an index. Distinct categories never collide.
fn guid(category : Int, index : Int) -> String {
  "{" + hex_pad(category, 8) + "-0000-0000-0000-" + hex_pad(index, 12) + "}"
}

///|
/// The document (root) point's model id — conventionally the literal `"0"`.
let doc_id : String = "0"

///|
/// Model id of the i-th top-level node point.
fn node_id(i : Int) -> String {
  guid(0x10, i)
}

///|
/// Model id of the i-th node's parent-transition point.
fn par_trans_id(i : Int) -> String {
  guid(0x20, i)
}

///|
/// Model id of the i-th node's sibling-transition point.
fn sib_trans_id(i : Int) -> String {
  guid(0x30, i)
}

///|
/// Model id of the doc→node connection for the i-th node.
fn cxn_id(i : Int) -> String {
  guid(0x40, i)
}
