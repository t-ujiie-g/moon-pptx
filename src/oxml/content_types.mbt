// Canonical PPTX content-type strings.
//
// These appear in `[Content_Types].xml` `<Override>` entries that route
// each part to its OOXML parser; the same strings also drive the
// content-type dispatch in `@integration.parse_everything`. Defining
// them once here means parser/writer round-trip tests, Phase 4g
// fixtures, and Phase 5's `Presentation::new()` can all reference the
// same constants — no risk of a typo in one place silently breaking
// dispatch elsewhere.
//
// Names follow the ECMA-376 "MIME-style" identifiers from
// §13.2.3.1 (PresentationML content types) and §20.1 (DrawingML),
// abbreviated to `ct_<kind>` for ergonomic reuse.

///|
/// `ppt/presentation.xml` — the main document part of every PPTX
/// package.
pub let ct_presentation : String = "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"

///|
/// `ppt/theme/themeN.xml` — drawing-ml theme part.
pub let ct_theme : String = "application/vnd.openxmlformats-officedocument.theme+xml"

///|
/// `ppt/slideMasters/slideMasterN.xml` — slide master part.
pub let ct_slide_master : String = "application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"

///|
/// `ppt/slideLayouts/slideLayoutN.xml` — slide layout part.
pub let ct_slide_layout : String = "application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"

///|
/// `ppt/slides/slideN.xml` — slide part.
pub let ct_slide : String = "application/vnd.openxmlformats-officedocument.presentationml.slide+xml"

///|
/// `ppt/notesSlides/notesSlideN.xml` — speaker-notes slide part.
pub let ct_notes_slide : String = "application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml"

///|
/// `ppt/notesMasters/notesMasterN.xml` — notes master part (when
/// present; PowerPoint sometimes ships decks without one).
pub let ct_notes_master : String = "application/vnd.openxmlformats-officedocument.presentationml.notesMaster+xml"

///|
/// `ppt/commentAuthors.xml` — author list for review comments.
pub let ct_comment_authors : String = "application/vnd.openxmlformats-officedocument.presentationml.commentAuthors+xml"

///|
/// `ppt/comments/commentN.xml` — per-slide review comment list.
pub let ct_comments : String = "application/vnd.openxmlformats-officedocument.presentationml.comments+xml"

///|
/// `ppt/charts/chartN.xml` — drawing-ml chart part.
pub let ct_chart : String = "application/vnd.openxmlformats-officedocument.drawingml.chart+xml"

// --- <a:graphicData uri="…"> values ---
//
// `<p:graphicFrame>` hosts foreign-namespace content through
// `<a:graphic><a:graphicData uri="…">`. The URI discriminates the
// payload kind: tables, charts, SmartArt, OLE-embedded content. We
// centralise the URIs here so parser dispatch + writer emission +
// future builders all reference the same strings.

///|
/// `<a:graphicData uri="…">` value for embedded tables.
pub let graphic_data_table_uri : String = "http://schemas.openxmlformats.org/drawingml/2006/table"

///|
/// `<a:graphicData uri="…">` value for embedded charts.
pub let graphic_data_chart_uri : String = "http://schemas.openxmlformats.org/drawingml/2006/chart"

///|
/// `<a:graphicData uri="…">` value for embedded SmartArt diagrams.
pub let graphic_data_diagram_uri : String = "http://schemas.openxmlformats.org/drawingml/2006/diagram"
