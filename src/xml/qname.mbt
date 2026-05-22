// Qualified XML names.
//
// In XML, a qualified name is `(namespace URI, local name)`. The prefix
// (`a:` in `a:rect`) is a serialization detail decided by the in-scope
// namespace declarations — it is *not* part of the name's identity. Two
// elements with the same URI and local name are equal regardless of which
// prefix the source XML used.

///|
/// A qualified XML name (`namespace URI` + `local name`).
///
/// Use the empty string for `uri` to represent an unqualified name (i.e.
/// belonging to no namespace).
pub(all) struct QName {
  uri : String
  local_name : String
} derive(Eq, Hash, Debug)

///|
/// Construct a qualified name in `uri`.
pub fn QName::new(uri : String, local_name : String) -> QName {
  { uri, local_name }
}

///|
/// Construct an unqualified name (no namespace).
pub fn QName::unqualified(local_name : String) -> QName {
  { uri: "", local_name }
}

///|
/// `True` if this name is in a namespace (i.e. `uri` is non-empty).
pub fn QName::is_qualified(self : QName) -> Bool {
  self.uri.length() > 0
}

///|
pub impl Show for QName with fn output(self, logger) {
  if self.uri.length() == 0 {
    logger.write_string(self.local_name)
  } else {
    logger.write_string("{")
    logger.write_string(self.uri)
    logger.write_string("}")
    logger.write_string(self.local_name)
  }
}
