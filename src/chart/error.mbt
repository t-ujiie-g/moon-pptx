// Errors raised by the `chart` package.

///|
/// Errors raised while parsing a chart part (`/ppt/charts/chartN.xml`).
///
/// `XmlFailure` flattens `@xml.XmlError` at the package boundary; `Malformed`
/// is the catch-all for schema violations (e.g. the root element is not
/// `<c:chartSpace>`). Same shape as `CommentsError` / `NotesError`.
pub(all) suberror ChartError {
  XmlFailure(String, String)
  Malformed(String)
} derive(Eq, Debug)

///|
/// Lift an XML reader/writer error into a `ChartError::XmlFailure`.
fn wrap_xml(e : @xml.XmlError) -> ChartError {
  match e {
    Malformed(msg) => XmlFailure("Malformed", msg)
    MismatchedEndTag(name) => XmlFailure("MismatchedEndTag", name)
    UnexpectedEof => XmlFailure("UnexpectedEof", "")
    UnboundPrefix(prefix) => XmlFailure("UnboundPrefix", prefix)
    WriterMisuse(msg) => XmlFailure("WriterMisuse", msg)
  }
}

///|
pub impl Show for ChartError with fn output(self, logger) {
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
