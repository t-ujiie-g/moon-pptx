// Errors raised by the `@presentation` façade.
//
// `PptxError` aggregates failures from every sub-package the façade
// touches. The pattern matches the per-package error types (`OpcError`,
// `ThemeError`, …): a stringly-described variant per source, plus a
// catch-all `Malformed` for façade-level invariants (e.g. presentation
// part missing). Errors flatten at the façade boundary so users see a
// single error type without losing which subsystem reported it.

///|
pub(all) suberror PptxError {
  /// `Package::open` / `Package::to_bytes` raised.
  OpcFailure(String)
  /// A theme part failed to parse.
  ThemeFailure(String)
  /// A slide master / slide layout part failed to parse.
  SlideMasterFailure(String)
  /// A slide part failed to parse.
  SlideFailure(String)
  /// A notes slide part failed to parse.
  NotesFailure(String)
  /// A comments / commentAuthors part failed to parse.
  CommentsFailure(String)
  /// A chart part (`/ppt/charts/chartN.xml`) failed to parse.
  ChartFailure(String)
  /// Façade-level invariant violated — e.g. the package has no
  /// `presentation.xml` part, or the required main-document
  /// relationship is missing.
  Malformed(String)
} derive(Eq, Debug)

///|
pub impl Show for PptxError with fn output(self, logger) {
  match self {
    OpcFailure(s) => {
      logger.write_string("OpcFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
    ThemeFailure(s) => {
      logger.write_string("ThemeFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
    SlideMasterFailure(s) => {
      logger.write_string("SlideMasterFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
    SlideFailure(s) => {
      logger.write_string("SlideFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
    NotesFailure(s) => {
      logger.write_string("NotesFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
    CommentsFailure(s) => {
      logger.write_string("CommentsFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
    ChartFailure(s) => {
      logger.write_string("ChartFailure(")
      logger.write_object(s)
      logger.write_string(")")
    }
    Malformed(s) => {
      logger.write_string("Malformed(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}
