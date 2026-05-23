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
