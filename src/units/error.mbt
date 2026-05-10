// Errors raised by the `units` package.

///|
/// Errors raised by the `units` package — primarily by parsers (hex colors,
/// OOXML scheme color names) where input may be malformed.
pub(all) suberror UnitsError {
  /// The hex color string was not exactly six hex digits (after stripping an
  /// optional leading `#`). The payload is the offending input.
  InvalidHexColor(String)
  /// The OOXML scheme color value (e.g. `accent1`, `bg1`) was not recognised.
  /// The payload is the offending input.
  UnknownSchemeColor(String)
} derive(Eq, Debug)

///|
pub impl Show for UnitsError with output(self, logger) {
  match self {
    InvalidHexColor(s) => {
      logger.write_string("InvalidHexColor(")
      logger.write_object(s)
      logger.write_string(")")
    }
    UnknownSchemeColor(s) => {
      logger.write_string("UnknownSchemeColor(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}
