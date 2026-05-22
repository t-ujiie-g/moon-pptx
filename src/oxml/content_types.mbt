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
