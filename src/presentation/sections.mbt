// Slide sections (the `<p14:sectionLst>` extension).
//
// PowerPoint's slide-panel sections live in `presentation.xml`'s
// `<p:extLst>`: a `<p:ext uri="{521415D9-…}">` holds a
// `<p14:sectionLst>` whose `<p14:section name="…" id="{GUID}">`
// entries each list their slides by `<p:sldIdLst>` id ([MS-PPTX]
// §2.3.1.25). Sections partition the deck in slide order: every slide
// belongs to exactly one section, so the typed model is a list of
// titled *break points* rather than free-form id sets — a `Section`
// names where a section starts, and it runs to the next section's
// start (the last one to the end of the deck).

///|
/// One slide section: its panel `title` and the 0-based index of its
/// first slide. Two sections may share a `start` — the earlier one is
/// then empty (PowerPoint allows slide-less sections).
pub(all) struct Section {
  title : String
  start : Int
} derive(Eq, Debug)

///|
/// Deterministic section id — sections need a `{GUID}`-shaped id, but
/// nothing keys off its value outside this file, so a counter-derived
/// one keeps builds reproducible (no RNG / clock in the library).
fn section_guid(idx : Int) -> String {
  let mut digits = (idx + 1).to_string()
  while digits.length() < 12 {
    digits = "0" + digits
  }
  "{00000000-0000-4000-8000-" + digits + "}"
}

///|
/// The `<p:ext uri="{521415D9-…}"><p14:sectionLst>…` subtree for
/// `sections` over the part's current slide list.
fn build_section_ext(
  pres : PresentationPart,
  sections : Array[Section],
) -> @xml.XmlElement {
  let n = pres.sld_ids.length()
  let section_nodes : Array[@xml.XmlNode] = []
  for i, sec in sections {
    let end = if i + 1 < sections.length() { sections[i + 1].start } else { n }
    let slide_nodes : Array[@xml.XmlNode] = []
    for j in sec.start..<end {
      slide_nodes.push(
        @xml.XmlNode::Element(
          @xml.XmlElement::new(
            @xml.QName::new(@oxml.powerpoint_2010_ns, "sldId"),
            [(@xml.QName::unqualified("id"), pres.sld_ids[j].id.to_string())],
            [],
          ),
        ),
      )
    }
    section_nodes.push(
      @xml.XmlNode::Element(
        @xml.XmlElement::new(
          @xml.QName::new(@oxml.powerpoint_2010_ns, "section"),
          [
            (@xml.QName::unqualified("name"), sec.title),
            (@xml.QName::unqualified("id"), section_guid(i)),
          ],
          [
            @xml.XmlNode::Element(
              @xml.XmlElement::new(
                @xml.QName::new(@oxml.powerpoint_2010_ns, "sldIdLst"),
                [],
                slide_nodes,
              ),
            ),
          ],
        ),
      ),
    )
  }
  @xml.XmlElement::new(
    @xml.QName::new(@oxml.presentation_ns, "ext"),
    [(@xml.QName::unqualified("uri"), @oxml.section_list_ext_uri)],
    [
      @xml.XmlNode::Element(
        @xml.XmlElement::new(
          @xml.QName::new(@oxml.powerpoint_2010_ns, "sectionLst"),
          [],
          section_nodes,
        ),
      ),
    ],
  )
}

///|
/// Whether `el` is a `<p:ext>` keyed by the section-list URI.
fn is_section_ext(el : @xml.XmlElement) -> Bool {
  if el.name.uri != @oxml.presentation_ns || el.name.local_name != "ext" {
    return false
  }
  for kv in el.attributes {
    if kv.0.local_name == "uri" && kv.1 == @oxml.section_list_ext_uri {
      return true
    }
  }
  false
}

///|
/// Replace the deck's sections. `sections` partitions the slides in
/// order: each entry starts at its (0-based) `start` slide and runs to
/// the next entry's `start`, the last to the end of the deck — so the
/// first entry must start at 0 and starts must be non-decreasing
/// (equal starts make the earlier section empty). An empty array
/// removes all sections. Other `<p:extLst>` content is preserved.
pub fn Presentation::set_sections_mut(
  self : Presentation,
  sections : Array[Section],
) -> Unit raise PptxError {
  let pres_name = match self.main_document_part_name() {
    Some(nm) => nm
    None =>
      raise Malformed(
        "package has no main-document relationship; cannot set sections",
      )
  }
  let pres = match self.presentation_part() {
    Some(p) => p
    None =>
      raise Malformed(
        "presentation.xml could not be parsed before set_sections",
      )
  }
  let n = pres.sld_ids.length()
  if sections.length() > 0 {
    if sections[0].start != 0 {
      raise Malformed(
        "set_sections_mut: the first section must start at slide 0 — sections cover every slide",
      )
    }
    let mut prev = 0
    for sec in sections {
      if sec.start < 0 || sec.start > n {
        raise Malformed(
          "set_sections_mut: section start " +
          sec.start.to_string() +
          " is out of range (deck has " +
          n.to_string() +
          " slides)",
        )
      }
      if sec.start < prev {
        raise Malformed(
          "set_sections_mut: section starts must be in slide order (non-decreasing)",
        )
      }
      prev = sec.start
    }
  }
  // Rebuild the extension array: strip any existing section ext (and
  // extLst wrappers left empty by that), then splice the new one into
  // the presentation's <p:extLst>, creating it when absent.
  let new_extension : Array[@xml.XmlElement] = []
  let mut placed = sections.length() == 0
  for el in pres.extension {
    if el.name.uri == @oxml.presentation_ns && el.name.local_name == "extLst" {
      let kept : Array[@xml.XmlNode] = []
      for child in el.children {
        match child {
          Element(inner) => if !is_section_ext(inner) { kept.push(child) }
          _ => kept.push(child)
        }
      }
      if !placed {
        kept.push(@xml.XmlNode::Element(build_section_ext(pres, sections)))
        placed = true
      }
      if kept.length() > 0 {
        new_extension.push(@xml.XmlElement::new(el.name, el.attributes, kept))
      }
    } else {
      new_extension.push(el)
    }
  }
  if !placed {
    new_extension.push(
      @xml.XmlElement::new(
        @xml.QName::new(@oxml.presentation_ns, "extLst"),
        [],
        [@xml.XmlNode::Element(build_section_ext(pres, sections))],
      ),
    )
  }
  let new_pres = { ..pres, extension: new_extension }
  self.replace_part_bytes(
    pres_name,
    new_pres.serialize(),
    @oxml.ct_presentation,
  )
}

///|
/// Add one section, keeping the existing ones. Equivalent to reading
/// `sections()`, inserting a `Section` at its slide-order position,
/// and calling `set_sections_mut` — so the combined list must still
/// satisfy its partition rules (a first-ever section must start at 0).
pub fn Presentation::add_section_mut(
  self : Presentation,
  title~ : String,
  start~ : Int,
) -> Unit raise PptxError {
  let current = self.sections()
  let mut at = current.length()
  for i, sec in current {
    if sec.start > start {
      at = i
      break
    }
  }
  current.insert(at, { title, start })
  self.set_sections_mut(current)
}

///|
/// The element children of `el`, dropping text / CData nodes.
fn child_elements(el : @xml.XmlElement) -> Array[@xml.XmlElement] {
  let out : Array[@xml.XmlElement] = []
  for c in el.children {
    match c {
      Element(e) => out.push(e)
      _ => ()
    }
  }
  out
}

///|
/// Whether `el` is a p14 element with the given local name.
fn is_p14(el : @xml.XmlElement, local_name : String) -> Bool {
  el.name.uri == @oxml.powerpoint_2010_ns && el.name.local_name == local_name
}

///|
/// The deck's sections, in slide order — empty when the presentation
/// has none. Starts are derived from each section's slide count, so a
/// slide-less section shares its successor's start.
pub fn Presentation::sections(
  self : Presentation,
) -> Array[Section] raise PptxError {
  let pres = match self.presentation_part() {
    Some(p) => p
    None => return []
  }
  let out : Array[Section] = []
  let mut start = 0
  for el in pres.extension {
    if el.name.uri != @oxml.presentation_ns || el.name.local_name != "extLst" {
      continue
    }
    for ext in child_elements(el) {
      if !is_section_ext(ext) {
        continue
      }
      for lst in child_elements(ext) {
        if !is_p14(lst, "sectionLst") {
          continue
        }
        for sec in child_elements(lst) {
          if !is_p14(sec, "section") {
            continue
          }
          let mut title = ""
          for kv in sec.attributes {
            if kv.0.local_name == "name" {
              title = kv.1
            }
          }
          let mut count = 0
          for ids in child_elements(sec) {
            if is_p14(ids, "sldIdLst") {
              for id_el in child_elements(ids) {
                if is_p14(id_el, "sldId") {
                  count = count + 1
                }
              }
            }
          }
          out.push({ title, start })
          start = start + count
        }
      }
    }
  }
  out
}

///|
/// Immutable counterpart of `set_sections_mut` — returns a new
/// `Presentation` with the given sections; the original is untouched.
pub fn Presentation::with_sections(
  self : Presentation,
  sections : Array[Section],
) -> Presentation raise PptxError {
  let cloned = self.clone()
  cloned.set_sections_mut(sections)
  cloned
}
