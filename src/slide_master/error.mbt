// Errors raised by the `slide_master` package.

///|
/// Errors raised while parsing a slide master or slide layout part.
///
/// Same flatten-at-the-boundary convention as `OpcError::ZipFailure` and
/// `ThemeError::XmlFailure`: the underlying `xml::XmlError` is reduced to
/// `(variant_name, message)` so callers can match on `SlideMasterError`
/// alone without dragging the XML error type in.
pub(all) suberror SlideMasterError {
  /// The underlying `xml::XmlError` from a reader call. Payload is
  /// `(variant_name, descriptive_message)`.
  XmlFailure(String, String)
  /// The parsed XML did not match the slide-master / slide-layout schema
  /// (unexpected element, missing required attribute, wrong namespace,
  /// unknown enum value, …).
  Malformed(String)
} derive(Eq, Debug)

///|
/// Wrap an `xml::XmlError` as a `SlideMasterError::XmlFailure`. Used at every
/// call site that bridges the `@xml` and slide-master layers.
pub fn wrap_xml(e : @xml.XmlError) -> SlideMasterError {
  match e {
    Malformed(msg) => XmlFailure("Malformed", msg)
    MismatchedEndTag(name) => XmlFailure("MismatchedEndTag", name)
    UnexpectedEof => XmlFailure("UnexpectedEof", "")
    UnboundPrefix(prefix) => XmlFailure("UnboundPrefix", prefix)
    WriterMisuse(msg) => XmlFailure("WriterMisuse", msg)
  }
}

///|
pub impl Show for SlideMasterError with fn output(self, logger) {
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
