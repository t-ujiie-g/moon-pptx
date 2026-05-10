// Errors raised by the `xml` package.

///|
/// Errors raised while reading or writing XML.
///
/// The reader produces `Malformed*` variants; the writer produces
/// `WriterMisuse` for API-contract violations (e.g. `attribute()` after the
/// element body has started).
pub(all) suberror XmlError {
  /// The reader encountered a syntactic error. Payload is a human-readable
  /// description of the problem.
  Malformed(String)
  /// An end tag did not match the corresponding start tag.
  MismatchedEndTag(String)
  /// Input ended before the document was complete.
  UnexpectedEof
  /// A namespace prefix was used without a binding being in scope.
  UnboundPrefix(String)
  /// The writer was called in an invalid order (e.g. `attribute()` after the
  /// element body has started). Payload is a description of the misuse.
  WriterMisuse(String)
} derive(Eq, Debug)

///|
pub impl Show for XmlError with output(self, logger) {
  match self {
    Malformed(s) => {
      logger.write_string("Malformed(")
      logger.write_object(s)
      logger.write_string(")")
    }
    MismatchedEndTag(s) => {
      logger.write_string("MismatchedEndTag(")
      logger.write_object(s)
      logger.write_string(")")
    }
    UnexpectedEof => logger.write_string("UnexpectedEof")
    UnboundPrefix(s) => {
      logger.write_string("UnboundPrefix(")
      logger.write_object(s)
      logger.write_string(")")
    }
    WriterMisuse(s) => {
      logger.write_string("WriterMisuse(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}
