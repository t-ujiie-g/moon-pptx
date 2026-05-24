// Slide XML writer (top-level + spTree dispatch).
//
// Mirrors `parser.mbt`. Each `write_*` helper opens its element, emits
// child content, and closes the matching EndElement. The slide-level
// `extension` array carries a mix of elements that need to be re-emitted
// at three different nesting levels (sld / cSld / spTree); we classify
// each captured element by its local-name and replay it under the right
// parent. Foreign-namespace extensions go to the sld level.

///|
/// Where in the sld → cSld → spTree nesting a captured extension
/// element belongs, based on its local-name. Drives the three-pass
/// replay in `write_slide_xml`.
priv enum ExtScope {
  ExtSpTree
  ExtCSld
  ExtSld
}

///|
/// Classify a captured extension element by its OOXML local name.
///
/// `<p:nvGrpSpPr>` / `<p:grpSpPr>` belong inside `<p:spTree>`;
/// `<p:bg>` / `<p:controls>` belong inside `<p:cSld>`; everything else
/// (`<p:transition>` / `<p:timing>` / `<p:custDataLst>` /
/// `<p:extLst>` + foreign-namespace siblings) attaches at the sld
/// level. Same applies for `<p:notes>` since they share the content
/// model.
fn classify_ext(el : @xml.XmlElement) -> ExtScope {
  if el.name.uri != @oxml.presentation_ns {
    return ExtSld
  }
  match el.name.local_name {
    "nvGrpSpPr" | "grpSpPr" => ExtSpTree
    "bg" | "controls" => ExtCSld
    _ => ExtSld
  }
}

///|
/// Serialise a `Slide` back to `slideN.xml`-shaped bytes.
pub fn Slide::serialize(self : Slide) -> FixedArray[Byte] raise SlideError {
  let xml = write_slide_xml(self, "sld") catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
/// Serialise with a non-default root local name — `<p:notes>` for
/// speaker-notes parts. Same content model as `<p:sld>`; the only
/// difference is the root element's local name.
pub fn Slide::serialize_with_root(
  self : Slide,
  root_local_name : String,
) -> FixedArray[Byte] raise SlideError {
  let xml = write_slide_xml(self, root_local_name) catch {
    e => raise wrap_xml(e)
  }
  @oxml.string_to_bytes(xml)
}

///|
fn write_slide_xml(
  s : Slide,
  root_local_name : String,
) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("p", @oxml.presentation_ns)
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.presentation_ns, root_local_name))
  w.namespace_attr("p", @oxml.presentation_ns)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  // <p:cSld>
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "cSld"))
  if s.name != "" {
    w.attribute(@xml.QName::unqualified("name"), s.name)
  }
  // cSld-level captured extensions (bg, controls).
  for ext in s.extension {
    if classify_ext(ext) is ExtCSld {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  // <p:spTree>
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "spTree"))
  // spTree-level captured extensions (nvGrpSpPr, grpSpPr) emit first
  // — they describe the implicit root group's metadata.
  for ext in s.extension {
    if classify_ext(ext) is ExtSpTree {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  // Shapes in source order.
  for shape in s.shapes {
    write_shape(w, ctx, shape)
  }
  w.end_element() // spTree
  w.end_element() // cSld
  // <p:clrMapOvr> — shared writer in @slide_master.
  @slide_master.write_clr_map_override(w, s.clr_map_override)
  // sld-level extensions (transition / timing / custDataLst / extLst
  // / foreign-namespace).
  for ext in s.extension {
    if classify_ext(ext) is ExtSld {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  w.end_element() // sld / notes
  w.to_string()
}
