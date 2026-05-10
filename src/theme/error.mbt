// Errors raised by the `theme` package.

///|
/// Errors raised while parsing or serialising a theme part.
///
/// The wrapped XML reader/writer error is flattened to a string description
/// at the boundary, the same convention `OpcError::ZipFailure` uses, so
/// callers don't have to mix two error types.
pub(all) suberror ThemeError {
  /// The underlying `xml::XmlError` from a reader/writer call. Payload is
  /// `(variant-name, descriptive message)`.
  XmlFailure(String, String)
  /// The parsed XML did not match the theme schema (unexpected element,
  /// missing required attribute, wrong namespace, …). Payload is a
  /// description.
  MalformedTheme(String)
} derive(Eq, Debug)

///|
/// Wrap an `xml::XmlError` as a `ThemeError::XmlFailure`. Used at every
/// call site that bridges the `@xml` and theme layers.
pub fn wrap_xml(e : @xml.XmlError) -> ThemeError {
  match e {
    Malformed(msg) => XmlFailure("Malformed", msg)
    MismatchedEndTag(name) => XmlFailure("MismatchedEndTag", name)
    UnexpectedEof => XmlFailure("UnexpectedEof", "")
    UnboundPrefix(prefix) => XmlFailure("UnboundPrefix", prefix)
    WriterMisuse(msg) => XmlFailure("WriterMisuse", msg)
  }
}

///|
pub impl Show for ThemeError with output(self, logger) {
  match self {
    XmlFailure(kind, msg) => {
      logger.write_string("XmlFailure(")
      logger.write_object(kind)
      logger.write_string(", ")
      logger.write_object(msg)
      logger.write_string(")")
    }
    MalformedTheme(s) => {
      logger.write_string("MalformedTheme(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}
