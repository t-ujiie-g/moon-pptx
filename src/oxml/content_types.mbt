// Canonical PPTX content-type strings.
//
// These appear in `[Content_Types].xml` `<Override>` entries that route
// each part to its OOXML parser; the same strings also drive the
// content-type dispatch in `@integration.parse_everything`. Defining
// them once here means parser/writer round-trip tests, integration
// fixtures, and `Presentation::new()` can all reference the same
// constants — no risk of a typo in one place silently breaking
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

///|
/// `ppt/charts/chartExN.xml` — Microsoft-extended chart part for
/// the 2016-era families (waterfall / treemap / sunburst / histogram
/// / boxwhisker / funnel / paretoLine / regionMap / clusteredColumn).
pub let ct_chart_ex : String = "application/vnd.ms-office.chartex+xml"

///|
/// `ppt/presProps.xml` — presentation-level properties. Required
/// part per ECMA-376 Part 1 §13.3.6: every PresentationML package
/// must include this part referenced from the presentation's rels.
pub let ct_pres_props : String = "application/vnd.openxmlformats-officedocument.presentationml.presProps+xml"

///|
/// `ppt/viewProps.xml` — common view properties (zoom, scroll, last
/// view kind). Required part per ECMA-376 Part 1 §13.3.6.
pub let ct_view_props : String = "application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml"

///|
/// `ppt/tableStyles.xml` — drawing-ml table style list. Required
/// when any slide carries a table; minimal valid content is an
/// empty `<a:tblStyleLst def="…">` with the no-style default UUID.
pub let ct_table_styles : String = "application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml"

///|
/// `docProps/core.xml` — Dublin Core metadata (title / creator /
/// revision / created / modified). Package-level part, referenced
/// from `_rels/.rels`.
pub let ct_core_properties : String = "application/vnd.openxmlformats-package.core-properties+xml"

///|
/// `docProps/app.xml` — extended (application-specific) properties
/// (Application name, Slides count, Notes count, etc.). Package-
/// level part, referenced from `_rels/.rels`.
pub let ct_extended_properties : String = "application/vnd.openxmlformats-officedocument.extended-properties+xml"

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
/// `<a:graphicData uri="…">` value for embedded extended charts
/// (Microsoft 2014 chartex). Numerically identical to `chart_ex_ns`
/// but kept as a separate constant for parser dispatch clarity.
pub let graphic_data_chart_ex_uri : String = "http://schemas.microsoft.com/office/drawing/2014/chartex"

///|
/// `<a:graphicData uri="…">` value for embedded SmartArt diagrams.
pub let graphic_data_diagram_uri : String = "http://schemas.openxmlformats.org/drawingml/2006/diagram"
