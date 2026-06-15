// Canonical OOXML relationship-type URIs + the `.rels` content type.
//
// These appear in `<Relationship Type="…">` attributes scattered
// across every `.rels` file in a PPTX, plus the `<Default
// Extension="rels"…>` entry in `[Content_Types].xml`. Defining them
// once here means parser, writer, builder, and test code reference
// the same strings — typos in one place can't silently break
// dispatch in another.
//
// Names follow the URL's last path segment with a `rt_` prefix
// ("relationship type") for the rel-type URIs.

///|
/// Content type for `.rels` parts (the OPC packaging-relationships
/// namespace). Used as a `Default Extension="rels"` in `[Content_
/// Types].xml` so every `.rels` file is routed automatically.
pub let rels_content_type : String = "application/vnd.openxmlformats-package.relationships+xml"

///|
/// `…/relationships/officeDocument` — package → main-document
/// (`ppt/presentation.xml`) rel. Lives in `/_rels/.rels`.
pub let rt_office_document : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"

///|
/// `…/relationships/slide` — presentation → slide rel.
pub let rt_slide : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide"

///|
/// `…/relationships/slideMaster` — presentation → slide-master OR
/// slide → slide-master rel.
pub let rt_slide_master : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster"

///|
/// `…/relationships/slideLayout` — slide-master → layout OR slide
/// → layout rel.
pub let rt_slide_layout : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout"

///|
/// `…/relationships/theme` — presentation → theme OR slide-master
/// → theme rel.
pub let rt_theme : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"

///|
/// `…/relationships/image` — slide → embedded image rel.
pub let rt_image : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"

///|
/// `…/relationships/chart` — slide → embedded chart part rel.
pub let rt_chart : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart"

///|
/// `…/2014/relationships/chartEx` — slide → embedded extended-chart
/// (Microsoft 2016 chartEx) rel. Distinct from `rt_chart`: chart
/// and chartEx parts use separate content types and rel types.
pub let rt_chart_ex : String = "http://schemas.microsoft.com/office/2014/relationships/chartEx"

///|
/// `…/relationships/notesSlide` — slide → notes-slide rel.
pub let rt_notes_slide : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide"

///|
/// `…/relationships/notesMaster` — presentation / notes-slide →
/// notes-master rel.
pub let rt_notes_master : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesMaster"

///|
/// `…/relationships/comments` — slide → comments-list rel.
pub let rt_comments : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments"

///|
/// `…/relationships/commentAuthors` — presentation → comment
/// authors-list rel.
pub let rt_comment_authors : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/commentAuthors"

///|
/// `…/relationships/presProps` — presentation → presentation-
/// properties part. Required per ECMA-376 Part 1 §13.3.6.
pub let rt_pres_props : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps"

///|
/// `…/relationships/viewProps` — presentation → view-properties
/// part. Required per ECMA-376 Part 1 §13.3.6.
pub let rt_view_props : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/viewProps"

///|
/// `…/relationships/tableStyles` — presentation → table-styles list.
/// Required when any slide carries a table.
pub let rt_table_styles : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/tableStyles"

///|
/// `…/metadata/core-properties` — package → core (Dublin Core)
/// metadata. Unusually for OOXML rels this type lives under the
/// `package-2006` namespace rather than `officeDocument-2006`.
pub let rt_core_properties : String = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"

///|
/// `…/relationships/extended-properties` — package → extended (app-
/// specific) metadata (`docProps/app.xml`).
pub let rt_extended_properties : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties"

///|
/// `…/relationships/hyperlink` — slide → external URL (used for
/// `<a:hlinkClick>` rel ids). The target is the URL itself; the
/// relationship's `TargetMode` is `External`.
pub let rt_hyperlink : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink"

///|
/// `<a:videoFile r:link>` target — the video media part. Roadmap A6.
pub let rt_video : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/video"

///|
/// `<a:audioFile r:link>` target — the audio media part. Roadmap A6.
pub let rt_audio : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/audio"

///|
/// `<p14:media r:embed>` target — the embedded media part (Office 2007+
/// extension; the same media part is also referenced by `rt_video` /
/// `rt_audio`). Roadmap A6.
pub let rt_media : String = "http://schemas.microsoft.com/office/2007/relationships/media"

///|
/// `<dgm:relIds r:dm>` target — a SmartArt data part
/// (`/ppt/diagrams/dataN.xml`). Slide → diagram data. Roadmap D1.
pub let rt_diagram_data : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramData"

///|
/// `<dgm:relIds r:lo>` target — a SmartArt layout part
/// (`/ppt/diagrams/layoutN.xml`). Slide → diagram layout. Roadmap D1.
pub let rt_diagram_layout : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramLayout"

///|
/// `<dgm:relIds r:qs>` target — a SmartArt quick-style part
/// (`/ppt/diagrams/quickStyleN.xml`). Slide → diagram quick style. Roadmap D1.
pub let rt_diagram_quick_style : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramQuickStyle"

///|
/// `<dgm:relIds r:cs>` target — a SmartArt colors part
/// (`/ppt/diagrams/colorsN.xml`). Slide → diagram colors. Roadmap D1.
pub let rt_diagram_colors : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramColors"

///|
/// `<dsp:dataModelExt relId>` target — the cached drawing part
/// (`/ppt/drawings/drawingN.xml`). Data part → its `<dsp:drawing>` (Office
/// 2007+ extension). Roadmap D1.
pub let rt_diagram_drawing : String = "http://schemas.microsoft.com/office/2007/relationships/diagramDrawing"
