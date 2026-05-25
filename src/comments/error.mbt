// Errors raised by the `comments` package.

///|
/// Errors raised while parsing a comments-related part — either
/// `commentAuthors.xml` (`CommentAuthorList::parse`) or `commentsN.xml`
/// (`CommentList::parse`). Same flatten-at-the-boundary convention as
/// `OpcError::ZipFailure`, `ThemeError::XmlFailure`, etc.
pub(all) suberror CommentsError {
  XmlFailure(String, String)
  Malformed(String)
} derive(Eq, Debug)

///|
/// Lift an XML reader/writer error into a `CommentsError::XmlFailure`.
pub fn wrap_xml(e : @xml.XmlError) -> CommentsError {
  match e {
    Malformed(msg) => XmlFailure("Malformed", msg)
    MismatchedEndTag(name) => XmlFailure("MismatchedEndTag", name)
    UnexpectedEof => XmlFailure("UnexpectedEof", "")
    UnboundPrefix(prefix) => XmlFailure("UnboundPrefix", prefix)
    WriterMisuse(msg) => XmlFailure("WriterMisuse", msg)
  }
}

///|
pub impl Show for CommentsError with fn output(self, logger) {
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
