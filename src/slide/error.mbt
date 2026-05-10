// Errors raised by the `slide` package.

///|
/// Errors raised while parsing a slide part.
///
/// Same flatten-at-the-boundary convention as `OpcError::ZipFailure`,
/// `ThemeError::XmlFailure`, and `SlideMasterError::XmlFailure`.
pub(all) suberror SlideError {
  XmlFailure(String, String)
  Malformed(String)
} derive(Eq, Debug)

///|
pub fn wrap_xml(e : @xml.XmlError) -> SlideError {
  match e {
    Malformed(msg) => XmlFailure("Malformed", msg)
    MismatchedEndTag(name) => XmlFailure("MismatchedEndTag", name)
    UnexpectedEof => XmlFailure("UnexpectedEof", "")
    UnboundPrefix(prefix) => XmlFailure("UnboundPrefix", prefix)
    WriterMisuse(msg) => XmlFailure("WriterMisuse", msg)
  }
}

///|
pub impl Show for SlideError with output(self, logger) {
  match self {
    XmlFailure(kind, msg) => {
      logger.write_string("XmlFailure(")
      logger.write_object(kind)
      logger.write_string(", ")
      logger.write_object(msg)
      logger.write_string(")")
    }
    Malformed(s) => {
      logger.write_string("Malformed(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}
