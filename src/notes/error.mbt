// Errors raised by the `notes` package.

///|
/// Errors raised while parsing a speaker-notes part.
///
/// `XmlFailure` flattens `@xml.XmlError` at the package boundary; `Malformed`
/// is the catch-all for schema violations (e.g. the root element is not
/// `<p:notes>`). `SlideFailure` re-wraps a `@slide.SlideError` raised by the
/// shared `Slide::parse_with_root` body — keeping the suberror chain
/// transparent so callers see exactly where parsing went wrong.
pub(all) suberror NotesError {
  XmlFailure(String, String)
  Malformed(String)
  SlideFailure(String)
} derive(Eq, Debug)

///|
pub impl Show for NotesError with output(self, logger) {
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
    SlideFailure(s) => {
      logger.write_string("SlideFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}
