// Errors raised by the `smartart` package.

///|
/// Errors raised while generating a SmartArt diagram's DiagramML parts.
///
/// `XmlFailure` flattens `@xml.XmlError` at the package boundary (a writer
/// misuse — should never happen for well-formed input); `Malformed` is the
/// catch-all for invalid diagram input (e.g. an empty node list). Same shape
/// as `ChartError` / `CommentsError`.
pub(all) suberror SmartArtError {
  XmlFailure(String, String)
  Malformed(String)
} derive(Eq, Debug)

///|
/// Lift an XML writer error into a `SmartArtError::XmlFailure`.
fn wrap_xml(e : @xml.XmlError) -> SmartArtError {
  match e {
    Malformed(msg) => XmlFailure("Malformed", msg)
    MismatchedEndTag(name) => XmlFailure("MismatchedEndTag", name)
    UnexpectedEof => XmlFailure("UnexpectedEof", "")
    UnboundPrefix(prefix) => XmlFailure("UnboundPrefix", prefix)
    WriterMisuse(msg) => XmlFailure("WriterMisuse", msg)
  }
}

///|
pub impl Show for SmartArtError with fn output(self, logger) {
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
