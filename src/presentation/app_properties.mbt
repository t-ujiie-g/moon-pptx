// Typed extended document properties (`docProps/app.xml`).
//
// The part's `CT_Properties` root is an `xsd:all` — order-free, each
// child at most once — mixing user-meaningful text fields (Company,
// Manager, …) with application-maintained statistics (word counts,
// the `vt:vector` TitlesOfParts, …) that we must not disturb. So
// unlike `docProps/core.xml`'s whole-part replace, editing here is a
// **DOM merge**: only the fields you set are replaced or appended;
// every other child of `<Properties>` is preserved verbatim.

///|
/// The user-meaningful text fields of `docProps/app.xml`. Every field
/// is `String?`: on read, `None` means the element is absent; on
/// write (`set_app_properties_mut`), `None` means "leave whatever the
/// part currently has".
pub(all) struct AppProperties {
  /// `<Company>`.
  company : String?
  /// `<Manager>`.
  manager : String?
  /// `<Application>` — the producing application's name.
  application : String?
  /// `<AppVersion>` — Office expects the `XX.YYYY` shape (e.g.
  /// `"16.0000"`).
  app_version : String?
} derive(Eq, Debug)

///|
/// An `AppProperties` with every field `None`. Start here and chain
/// the `with_*` builders, or read the current values via
/// `Presentation::app_properties`.
pub fn AppProperties::new() -> AppProperties {
  { company: None, manager: None, application: None, app_version: None }
}

///|
/// Set `<Company>`.
pub fn AppProperties::with_company(
  self : AppProperties,
  company : String,
) -> AppProperties {
  { ..self, company: Some(company) }
}

///|
/// Set `<Manager>`.
pub fn AppProperties::with_manager(
  self : AppProperties,
  manager : String,
) -> AppProperties {
  { ..self, manager: Some(manager) }
}

///|
/// Set `<Application>`.
pub fn AppProperties::with_application(
  self : AppProperties,
  application : String,
) -> AppProperties {
  { ..self, application: Some(application) }
}

///|
/// Set `<AppVersion>`.
pub fn AppProperties::with_app_version(
  self : AppProperties,
  app_version : String,
) -> AppProperties {
  { ..self, app_version: Some(app_version) }
}

///|
/// Parse `docProps/app.xml` into its `<Properties>` DOM.
fn parse_app_root(bytes : FixedArray[Byte]) -> @xml.XmlElement raise PptxError {
  let xml = @oxml.bytes_to_string(bytes) catch {
    e => raise OpcFailure(e.to_string())
  }
  let r = @xml.XmlReader::new(xml)
  while true {
    match next_event(r) {
      StartElement(name, attrs) => {
        if name.uri != @oxml.extended_properties_ns ||
          name.local_name != "Properties" {
          raise Malformed("expected <Properties> root element in app.xml")
        }
        return @oxml.collect_subtree(r, name, attrs) catch {
          e => raise Malformed(e.to_string())
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  raise Malformed("app.xml has no root element")
}

///|
/// The concatenated text content of `el`.
fn element_text(el : @xml.XmlElement) -> String {
  let mut acc = ""
  for c in el.children {
    match c {
      Text(s) => acc = acc + s
      CData(s) => acc = acc + s
      Element(_) => ()
    }
  }
  acc
}

///|
/// Replace the text of the `<local_name>` child, or append the element
/// when absent (legal anywhere — the root is an `xsd:all`).
fn upsert_app_field(
  root : @xml.XmlElement,
  local_name : String,
  value : String,
) -> @xml.XmlElement {
  let replacement = @xml.XmlNode::Element(
    @xml.XmlElement::new(
      @xml.QName::new(@oxml.extended_properties_ns, local_name),
      [],
      [@xml.XmlNode::Text(value)],
    ),
  )
  let children : Array[@xml.XmlNode] = []
  let mut found = false
  for c in root.children {
    match c {
      Element(el) =>
        if el.name.uri == @oxml.extended_properties_ns &&
          el.name.local_name == local_name {
          children.push(replacement)
          found = true
        } else {
          children.push(c)
        }
      _ => children.push(c)
    }
  }
  if !found {
    children.push(replacement)
  }
  @xml.XmlElement::new(root.name, root.attributes, children)
}

///|
/// Serialise the `<Properties>` DOM back to part bytes, with the
/// extended-properties namespace as the default (what Office emits)
/// and `vt:` bound for the variant-type subtrees.
fn serialize_app_root(
  root : @xml.XmlElement,
) -> FixedArray[Byte] raise PptxError {
  let bytes = try {
    let w = @xml.XmlWriter::new()
    w.bind_namespace("", @oxml.extended_properties_ns)
    w.bind_namespace("vt", @oxml.doc_props_vtypes_ns)
    w.xml_declaration()
    w.start_element(root.name)
    w.default_namespace_attr(@oxml.extended_properties_ns)
    w.namespace_attr("vt", @oxml.doc_props_vtypes_ns)
    let ctx = @oxml.WriteCtx::with_well_known_prefixes()
    ctx.known_prefixes[@oxml.extended_properties_ns] = ""
    ctx.known_prefixes[@oxml.doc_props_vtypes_ns] = "vt"
    for c in root.children {
      match c {
        Element(el) => @oxml.write_xml_element(w, ctx, el)
        Text(s) => w.text(s)
        CData(s) => w.cdata(s)
      }
    }
    w.end_element()
    @oxml.string_to_bytes(w.to_string())
  } catch {
    e => raise OpcFailure(e.to_string())
  }
  bytes
}

// --- Presentation accessors ---

///|
/// Read the extended properties from `docProps/app.xml`. Every field
/// is `None` when the part is absent.
pub fn Presentation::app_properties(
  self : Presentation,
) -> AppProperties raise PptxError {
  let root = match self.pkg.part_by_name("/docProps/app.xml") {
    Some(p) => parse_app_root(p.bytes)
    None => return AppProperties::new()
  }
  let mut props = AppProperties::new()
  for el in child_elements(root) {
    if el.name.uri != @oxml.extended_properties_ns {
      continue
    }
    let value = Some(element_text(el))
    props = match el.name.local_name {
      "Company" => { ..props, company: value }
      "Manager" => { ..props, manager: value }
      "Application" => { ..props, application: value }
      "AppVersion" => { ..props, app_version: value }
      _ => props
    }
  }
  props
}

///|
/// Merge `props` into `docProps/app.xml` (mutating): each `Some`
/// field replaces its element (or appends it when absent); `None`
/// fields — and everything else in the part, word counts and
/// `TitlesOfParts` included — are left untouched. Creates the part
/// (and its package relationship) for packages that lack one.
pub fn Presentation::set_app_properties_mut(
  self : Presentation,
  props : AppProperties,
) -> Unit raise PptxError {
  let mut root = match self.pkg.part_by_name("/docProps/app.xml") {
    Some(p) => parse_app_root(p.bytes)
    None =>
      @xml.XmlElement::new(
        @xml.QName::new(@oxml.extended_properties_ns, "Properties"),
        [],
        [],
      )
  }
  match props.company {
    Some(v) => root = upsert_app_field(root, "Company", v)
    None => ()
  }
  match props.manager {
    Some(v) => root = upsert_app_field(root, "Manager", v)
    None => ()
  }
  match props.application {
    Some(v) => root = upsert_app_field(root, "Application", v)
    None => ()
  }
  match props.app_version {
    Some(v) => root = upsert_app_field(root, "AppVersion", v)
    None => ()
  }
  self.replace_part_bytes(
    "/docProps/app.xml",
    serialize_app_root(root),
    @oxml.ct_extended_properties,
  )
  // A package that never had the part also lacks its package-level
  // relationship — without it PowerPoint ignores the part entirely.
  let rels = self.pkg.relationships_for("/") catch {
    e => raise OpcFailure(e.to_string())
  }
  if rels.by_type(@opc.rt_extended_properties).length() == 0 {
    let updated = rels.with_relationship({
      id: next_unused_rid(rels),
      rel_type: @opc.rt_extended_properties,
      target: "docProps/app.xml",
      target_mode: Internal,
    }) catch {
      e => raise OpcFailure(e.to_string())
    }
    self.write_rels_for_part("/", updated)
  }
}

///|
/// Immutable counterpart of `set_app_properties_mut` (ADR-003):
/// returns a new `Presentation` with the merge applied; the original
/// is untouched.
pub fn Presentation::with_app_properties(
  self : Presentation,
  props : AppProperties,
) -> Presentation raise PptxError {
  let cloned = self.clone()
  cloned.set_app_properties_mut(props)
  cloned
}
