// Typed document core properties (`docProps/core.xml`).
//
// `docProps/core.xml` is the OPC core-properties part PowerPoint surfaces in
// File ▸ Info / the Properties dialog. CT_CoreProperties is a *closed* schema
// (an `<xsd:all>` of a fixed element set spread across the cp / dc / dcterms
// namespaces, with no extension wildcard), so every field is modelled typed
// and round-trips losslessly without an `extension` escape hatch.
//
// python-pptx exposes the same set via `prs.core_properties`; PptxGenJS
// surfaces `title` / `author` (= creator) / `subject` / `revision`.
// (`company` / `application` live in the separate, sequenced
// `docProps/app.xml` — a documented follow-up.)

///|
/// Document core properties (`docProps/core.xml`). Every field is `String?`
/// — `None` omits the element (PowerPoint shows it blank / inherits the
/// default). The date fields (`created` / `modified` / `last_printed`) are
/// W3CDTF timestamps, e.g. `"2026-06-16T09:30:00Z"`; `created` / `modified`
/// are emitted with the `xsi:type="dcterms:W3CDTF"` the schema requires.
pub(all) struct CoreProperties {
  /// `dc:title`.
  title : String?
  /// `dc:creator` — the document author.
  creator : String?
  /// `dc:subject`.
  subject : String?
  /// `cp:keywords`.
  keywords : String?
  /// `dc:description` — python-pptx calls this `comments`.
  description : String?
  /// `cp:category`.
  category : String?
  /// `cp:contentStatus` (e.g. `"Draft"` / `"Final"`).
  content_status : String?
  /// `dcterms:created` — W3CDTF timestamp.
  created : String?
  /// `dcterms:modified` — W3CDTF timestamp.
  modified : String?
  /// `cp:lastPrinted` — dateTime timestamp.
  last_printed : String?
  /// `cp:lastModifiedBy`.
  last_modified_by : String?
  /// `cp:revision`.
  revision : String?
  /// `dc:identifier`.
  identifier : String?
  /// `dc:language`.
  language : String?
  /// `cp:version`.
  version : String?
} derive(Eq, Debug)

///|
/// An empty `CoreProperties` — every field `None`. Start here and chain the
/// `with_*` builders, or read the current values via
/// `Presentation::core_properties`.
pub fn CoreProperties::new() -> CoreProperties {
  {
    title: None,
    creator: None,
    subject: None,
    keywords: None,
    description: None,
    category: None,
    content_status: None,
    created: None,
    modified: None,
    last_printed: None,
    last_modified_by: None,
    revision: None,
    identifier: None,
    language: None,
    version: None,
  }
}

///|
/// Set `dc:title`.
pub fn CoreProperties::with_title(
  self : CoreProperties,
  title : String,
) -> CoreProperties {
  { ..self, title: Some(title) }
}

///|
/// Set `dc:creator` (the author).
pub fn CoreProperties::with_creator(
  self : CoreProperties,
  creator : String,
) -> CoreProperties {
  { ..self, creator: Some(creator) }
}

///|
/// Set `dc:creator` — alias for `with_creator` matching the more common
/// "author" terminology (python-pptx `author`, PptxGenJS `author`).
pub fn CoreProperties::with_author(
  self : CoreProperties,
  author : String,
) -> CoreProperties {
  { ..self, creator: Some(author) }
}

///|
/// Set `dc:subject`.
pub fn CoreProperties::with_subject(
  self : CoreProperties,
  subject : String,
) -> CoreProperties {
  { ..self, subject: Some(subject) }
}

///|
/// Set `cp:keywords`.
pub fn CoreProperties::with_keywords(
  self : CoreProperties,
  keywords : String,
) -> CoreProperties {
  { ..self, keywords: Some(keywords) }
}

///|
/// Set `dc:description` (python-pptx `comments`).
pub fn CoreProperties::with_description(
  self : CoreProperties,
  description : String,
) -> CoreProperties {
  { ..self, description: Some(description) }
}

///|
/// Set `cp:category`.
pub fn CoreProperties::with_category(
  self : CoreProperties,
  category : String,
) -> CoreProperties {
  { ..self, category: Some(category) }
}

///|
/// Set `cp:contentStatus`.
pub fn CoreProperties::with_content_status(
  self : CoreProperties,
  content_status : String,
) -> CoreProperties {
  { ..self, content_status: Some(content_status) }
}

///|
/// Set `dcterms:created` (a W3CDTF timestamp, e.g.
/// `"2026-06-16T09:30:00Z"`).
pub fn CoreProperties::with_created(
  self : CoreProperties,
  created : String,
) -> CoreProperties {
  { ..self, created: Some(created) }
}

///|
/// Set `dcterms:modified` (a W3CDTF timestamp).
pub fn CoreProperties::with_modified(
  self : CoreProperties,
  modified : String,
) -> CoreProperties {
  { ..self, modified: Some(modified) }
}

///|
/// Set `cp:lastPrinted` (a dateTime timestamp).
pub fn CoreProperties::with_last_printed(
  self : CoreProperties,
  last_printed : String,
) -> CoreProperties {
  { ..self, last_printed: Some(last_printed) }
}

///|
/// Set `cp:lastModifiedBy`.
pub fn CoreProperties::with_last_modified_by(
  self : CoreProperties,
  last_modified_by : String,
) -> CoreProperties {
  { ..self, last_modified_by: Some(last_modified_by) }
}

///|
/// Set `cp:revision`.
pub fn CoreProperties::with_revision(
  self : CoreProperties,
  revision : String,
) -> CoreProperties {
  { ..self, revision: Some(revision) }
}

///|
/// Set `dc:identifier`.
pub fn CoreProperties::with_identifier(
  self : CoreProperties,
  identifier : String,
) -> CoreProperties {
  { ..self, identifier: Some(identifier) }
}

///|
/// Set `dc:language`.
pub fn CoreProperties::with_language(
  self : CoreProperties,
  language : String,
) -> CoreProperties {
  { ..self, language: Some(language) }
}

///|
/// Set `cp:version`.
pub fn CoreProperties::with_version(
  self : CoreProperties,
  version : String,
) -> CoreProperties {
  { ..self, version: Some(version) }
}

///|
/// Serialise to a complete `docProps/core.xml` document string. Only the
/// `Some` fields are emitted; the `cp` / `dc` / `dcterms` / `xsi` prefixes
/// are declared on the root regardless (matching Office output).
pub fn CoreProperties::to_xml(
  self : CoreProperties,
) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("cp", @oxml.core_properties_ns)
  w.bind_namespace("dc", @oxml.dublin_core_ns)
  w.bind_namespace("dcterms", @oxml.dublin_core_terms_ns)
  w.bind_namespace("xsi", @oxml.xml_schema_instance_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.core_properties_ns, "coreProperties"))
  w.namespace_attr("cp", @oxml.core_properties_ns)
  w.namespace_attr("dc", @oxml.dublin_core_ns)
  w.namespace_attr("dcterms", @oxml.dublin_core_terms_ns)
  w.namespace_attr("xsi", @oxml.xml_schema_instance_ns)
  // Order is immaterial (CT_CoreProperties is an all-group); kept stable.
  write_text_el(w, @oxml.dublin_core_ns, "title", self.title)
  write_text_el(w, @oxml.dublin_core_ns, "subject", self.subject)
  write_text_el(w, @oxml.dublin_core_ns, "creator", self.creator)
  write_text_el(w, @oxml.core_properties_ns, "keywords", self.keywords)
  write_text_el(w, @oxml.dublin_core_ns, "description", self.description)
  write_text_el(
    w,
    @oxml.core_properties_ns,
    "lastModifiedBy",
    self.last_modified_by,
  )
  write_text_el(w, @oxml.core_properties_ns, "revision", self.revision)
  write_dcterms_date(w, "created", self.created)
  write_dcterms_date(w, "modified", self.modified)
  write_text_el(w, @oxml.core_properties_ns, "lastPrinted", self.last_printed)
  write_text_el(w, @oxml.core_properties_ns, "category", self.category)
  write_text_el(
    w,
    @oxml.core_properties_ns,
    "contentStatus",
    self.content_status,
  )
  write_text_el(w, @oxml.dublin_core_ns, "identifier", self.identifier)
  write_text_el(w, @oxml.dublin_core_ns, "language", self.language)
  write_text_el(w, @oxml.core_properties_ns, "version", self.version)
  w.end_element()
  w.to_string()
}

///|
/// Emit `<prefix:local>value</prefix:local>` when `value` is `Some`.
fn write_text_el(
  w : @xml.XmlWriter,
  uri : String,
  local_name : String,
  value : String?,
) -> Unit raise @xml.XmlError {
  match value {
    Some(v) => {
      w.start_element(@xml.QName::new(uri, local_name))
      w.text(v)
      w.end_element()
    }
    None => ()
  }
}

///|
/// Emit a `<dcterms:local xsi:type="dcterms:W3CDTF">value</dcterms:local>`
/// date element when `value` is `Some`.
fn write_dcterms_date(
  w : @xml.XmlWriter,
  local_name : String,
  value : String?,
) -> Unit raise @xml.XmlError {
  match value {
    Some(v) => {
      w.start_element(@xml.QName::new(@oxml.dublin_core_terms_ns, local_name))
      w.attribute(
        @xml.QName::new(@oxml.xml_schema_instance_ns, "type"),
        "dcterms:W3CDTF",
      )
      w.text(v)
      w.end_element()
    }
    None => ()
  }
}

///|
/// Parse a `docProps/core.xml` document string into `CoreProperties`.
/// Unrecognised children (none exist in the closed schema, but a tool could
/// emit something) are skipped.
fn parse_core_properties(xml : String) -> CoreProperties raise PptxError {
  let r = @xml.XmlReader::new(xml)
  match next_event(r) {
    StartElement(name, _) =>
      if name.uri != @oxml.core_properties_ns ||
        name.local_name != "coreProperties" {
        raise Malformed("expected <cp:coreProperties> root element")
      }
    _ => raise Malformed("expected <cp:coreProperties> root element")
  }
  let mut props = CoreProperties::new()
  while true {
    match next_event(r) {
      StartElement(child, _) => {
        let text = read_element_text(r)
        let value = Some(text)
        let cp = @oxml.core_properties_ns
        let dc = @oxml.dublin_core_ns
        let dcterms = @oxml.dublin_core_terms_ns
        props = match (child.uri, child.local_name) {
          (u, "title") if u == dc => { ..props, title: value }
          (u, "creator") if u == dc => { ..props, creator: value }
          (u, "subject") if u == dc => { ..props, subject: value }
          (u, "description") if u == dc => { ..props, description: value }
          (u, "identifier") if u == dc => { ..props, identifier: value }
          (u, "language") if u == dc => { ..props, language: value }
          (u, "keywords") if u == cp => { ..props, keywords: value }
          (u, "lastModifiedBy") if u == cp =>
            { ..props, last_modified_by: value }
          (u, "revision") if u == cp => { ..props, revision: value }
          (u, "lastPrinted") if u == cp => { ..props, last_printed: value }
          (u, "category") if u == cp => { ..props, category: value }
          (u, "contentStatus") if u == cp => { ..props, content_status: value }
          (u, "version") if u == cp => { ..props, version: value }
          (u, "created") if u == dcterms => { ..props, created: value }
          (u, "modified") if u == dcterms => { ..props, modified: value }
          // Unknown child — its text was already consumed; ignore.
          _ => props
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  props
}

///|
/// Accumulate the text content of the currently-open element, consuming
/// through its matching `EndElement`. Nested elements (out of spec here)
/// have their own text ignored.
fn read_element_text(r : @xml.XmlReader) -> String raise PptxError {
  let mut acc = ""
  let mut depth = 0
  while true {
    match next_event(r) {
      Text(s) => if depth == 0 { acc = acc + s }
      CData(s) => if depth == 0 { acc = acc + s }
      StartElement(_, _) => depth = depth + 1
      EndElement(_) => if depth == 0 { break } else { depth = depth - 1 }
    }
  }
  acc
}

// --- Presentation accessors ---

///|
/// Read the document's core properties from `docProps/core.xml`. Returns an
/// empty `CoreProperties` if the part is absent.
pub fn Presentation::core_properties(
  self : Presentation,
) -> CoreProperties raise PptxError {
  match self.pkg.part_by_name("/docProps/core.xml") {
    Some(p) => {
      let xml = @oxml.bytes_to_string(p.bytes) catch {
        e => raise OpcFailure(e.to_string())
      }
      parse_core_properties(xml)
    }
    None => CoreProperties::new()
  }
}

///|
/// Replace `docProps/core.xml` with `props` (mutating). This **replaces**
/// the whole property set rather than merging, so a field left `None` is
/// dropped. To preserve existing fields, start from the current values —
/// the read → edit → write-back idiom:
///
///   prs.set_core_properties_mut(
///     prs.core_properties().with_title("Q3 Review").with_author("Ada"),
///   )
pub fn Presentation::set_core_properties_mut(
  self : Presentation,
  props : CoreProperties,
) -> Unit raise PptxError {
  let xml = props.to_xml() catch { e => raise OpcFailure(e.to_string()) }
  let bytes = @oxml.string_to_bytes(xml)
  self.replace_part_bytes("/docProps/core.xml", bytes, @oxml.ct_core_properties)
}

///|
/// Immutable counterpart of `set_core_properties_mut` (ADR-003): returns a
/// new `Presentation` with the core properties replaced; the original is
/// untouched.
pub fn Presentation::with_core_properties(
  self : Presentation,
  props : CoreProperties,
) -> Presentation raise PptxError {
  let cloned = self.clone()
  cloned.set_core_properties_mut(props)
  cloned
}
