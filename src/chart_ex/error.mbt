// Errors raised by the `chart_ex` package.

///|
/// Errors raised while parsing an extended chart part
/// (`/ppt/charts/chartExN.xml`). Mirrors `ChartError` —
/// `XmlFailure` flattens `@xml.XmlError` at the package boundary;
/// `Malformed` is the catch-all for schema violations (e.g. the
/// root element is not `<cx:chartSpace>`).
pub(all) suberror ChartExError {
  XmlFailure(String, String)
  Malformed(String)
} derive(Eq, Debug)

///|
/// Lift an XML reader/writer error into a `ChartExError::XmlFailure`.
pub fn wrap_xml(e : @xml.XmlError) -> ChartExError {
  match e {
    Malformed(msg) => XmlFailure("Malformed", msg)
    MismatchedEndTag(name) => XmlFailure("MismatchedEndTag", name)
    UnexpectedEof => XmlFailure("UnexpectedEof", "")
    UnboundPrefix(prefix) => XmlFailure("UnboundPrefix", prefix)
    WriterMisuse(msg) => XmlFailure("WriterMisuse", msg)
  }
}

///|
pub impl Show for ChartExError with fn output(self, logger) {
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
