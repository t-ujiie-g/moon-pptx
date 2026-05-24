// Slide master / slide layout writers.
//
// Both root elements share a schema shape: `<p:cSld>` (full body
// captured into `extension` since the layout/master shape-tree parser
// isn't typed yet), `<p:clrMap>` / `<p:clrMapOvr>` (modeled), and a
// tail of unmodelled siblings (`<p:transition>` / `<p:timing>` /
// `<p:txStyles>` / `<p:hf>` / `<p:sldLayoutIdLst>` / `<p:extLst>`,
// plus foreign-namespace extensions). The schema enforces an element
// order: cSld first, then clrMap, then optional siblings.
//
// Reconstructing that order on write: the `extension` array preserves
// the source order of captured elements, so we just need to splice
// in the modeled `<p:clrMap>` (master) / `<p:clrMapOvr>` (layout) and
// `<p:sldLayoutIdLst>` (master) at the right place. Concretely:
//
//   1. Walk extension; emit `<p:cSld>` whenever we encounter it.
//   2. After cSld, emit the modeled `<p:clrMap>` / `<p:clrMapOvr>`.
//   3. For master, emit `<p:sldLayoutIdLst>`.
//   4. Continue emitting the rest of extension in source order.
//
// This produces a schema-valid serialisation whose round-trip through
// `::parse` is equal to the original value.

// --- SlideMaster ---

///|
/// Serialise a `SlideMaster` back to `slideMaster1.xml`-shaped bytes.
pub fn SlideMaster::serialize(
  self : SlideMaster,
) -> FixedArray[Byte] raise SlideMasterError {
  let xml = serialize_master_xml(self) catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
fn serialize_master_xml(m : SlideMaster) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("p", @oxml.presentation_ns)
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "sldMaster"))
  w.namespace_attr("p", @oxml.presentation_ns)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  let mut emitted_modeled = false
  for ext in m.extension {
    @oxml.write_xml_element(w, ctx, ext)
    // After `<p:cSld>` go the modeled bits.
    if !emitted_modeled &&
      ext.name.uri == @oxml.presentation_ns &&
      ext.name.local_name == "cSld" {
      write_clr_map(w, m.color_mapping)
      write_sld_layout_id_lst(w, m.layout_refs)
      emitted_modeled = true
    }
  }
  // Fallback: if no `<p:cSld>` was captured (malformed parse — shouldn't
  // happen on real input), still emit modeled children before closing
  // so the output remains schema-shaped.
  if !emitted_modeled {
    write_clr_map(w, m.color_mapping)
    write_sld_layout_id_lst(w, m.layout_refs)
  }
  w.end_element()
  w.to_string()
}

///|
fn write_clr_map(
  w : @xml.XmlWriter,
  cm : ColorMapping,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "clrMap"))
  w.attribute(@xml.QName::unqualified("bg1"), cm.bg1.to_xml())
  w.attribute(@xml.QName::unqualified("tx1"), cm.tx1.to_xml())
  w.attribute(@xml.QName::unqualified("bg2"), cm.bg2.to_xml())
  w.attribute(@xml.QName::unqualified("tx2"), cm.tx2.to_xml())
  w.attribute(@xml.QName::unqualified("accent1"), cm.accent1.to_xml())
  w.attribute(@xml.QName::unqualified("accent2"), cm.accent2.to_xml())
  w.attribute(@xml.QName::unqualified("accent3"), cm.accent3.to_xml())
  w.attribute(@xml.QName::unqualified("accent4"), cm.accent4.to_xml())
  w.attribute(@xml.QName::unqualified("accent5"), cm.accent5.to_xml())
  w.attribute(@xml.QName::unqualified("accent6"), cm.accent6.to_xml())
  w.attribute(@xml.QName::unqualified("hlink"), cm.hlink.to_xml())
  w.attribute(@xml.QName::unqualified("folHlink"), cm.fol_hlink.to_xml())
  w.end_element()
}

///|
fn write_sld_layout_id_lst(
  w : @xml.XmlWriter,
  refs : Array[SlideLayoutRef],
) -> Unit raise @xml.XmlError {
  if refs.length() == 0 {
    return
  }
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "sldLayoutIdLst"))
  for slr in refs {
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "sldLayoutId"))
    w.attribute(@xml.QName::unqualified("id"), slr.id.to_string())
    w.attribute(@xml.QName::new(@oxml.office_relationships_ns, "id"), slr.r_id)
    w.end_element()
  }
  w.end_element()
}

// --- SlideLayout ---

///|
/// Serialise a `SlideLayout` back to `slideLayoutN.xml`-shaped bytes.
pub fn SlideLayout::serialize(
  self : SlideLayout,
) -> FixedArray[Byte] raise SlideMasterError {
  let xml = serialize_layout_xml(self) catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
fn serialize_layout_xml(layout : SlideLayout) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("p", @oxml.presentation_ns)
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "sldLayout"))
  w.namespace_attr("p", @oxml.presentation_ns)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  // `type` defaults to `blank` when absent; only emit if non-default
  // OR if name is set (since name on cSld means a known layout).
  // The parser maps absent → Blank, so we emit the attribute whenever
  // layout_type isn't Blank (matches Office output).
  match layout.layout_type {
    Blank => () // omit attribute — round-trips back to Blank
    other => w.attribute(@xml.QName::unqualified("type"), other.to_xml())
  }
  // Same emit order as SlideMaster: cSld from extension, then modeled
  // clrMapOvr, then remaining extensions.
  let mut emitted_modeled = false
  for ext in layout.extension {
    if !emitted_modeled &&
      ext.name.uri == @oxml.presentation_ns &&
      ext.name.local_name == "cSld" {
      // Inject cSld with the layout name attribute, since the parser
      // pulls the name onto SlideLayout.name (not into extension).
      write_c_sld_from_extension(w, ctx, ext, layout.name)
      write_clr_map_override(w, layout.clr_map_override)
      emitted_modeled = true
    } else {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  // Fallback: no cSld captured — emit an empty cSld with the modeled
  // name + clrMapOvr so the result still parses.
  if !emitted_modeled {
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "cSld"))
    if layout.name != "" {
      w.attribute(@xml.QName::unqualified("name"), layout.name)
    }
    w.end_element()
    write_clr_map_override(w, layout.clr_map_override)
  }
  w.end_element()
  w.to_string()
}

///|
/// Re-emit a captured `<p:cSld>` subtree, but swap its `name` attribute
/// for the modeled `SlideLayout.name`. The parser pulls the attribute
/// out into `SlideLayout.name`, so the captured element's attribute
/// list never contains it — we need to re-inject it on write.
fn write_c_sld_from_extension(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  c_sld : @xml.XmlElement,
  name : String,
) -> Unit raise @xml.XmlError {
  w.start_element(c_sld.name)
  if name != "" {
    w.attribute(@xml.QName::unqualified("name"), name)
  }
  // Captured attributes (none today, but kept for forward-compat).
  for kv in c_sld.attributes {
    // Skip a captured `name` attribute if any — would duplicate.
    if !(kv.0.uri == "" && kv.0.local_name == "name") {
      w.attribute(kv.0, kv.1)
    }
  }
  for child in c_sld.children {
    match child {
      Element(c) => @oxml.write_xml_element(w, ctx, c)
      Text(s) => w.text(s)
      CData(s) => w.cdata(s)
    }
  }
  w.end_element()
}

///|
/// Emit a `<p:clrMapOvr>` wrapping either `<a:masterClrMapping/>` (the
/// inherit-from-master default) or `<a:overrideClrMapping bg1=… …/>`
/// (an explicit 12-slot override). Public because both the slide
/// layout writer and the slide writer in `@slide` use this — keeping
/// it here avoids the duplicated 28-line block we had through phase
/// 4d / 4e.
pub fn write_clr_map_override(
  w : @xml.XmlWriter,
  ovr : ClrMapOverride,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "clrMapOvr"))
  match ovr {
    MasterMapping => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "masterClrMapping"))
      w.end_element()
    }
    Override(cm) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "overrideClrMapping"))
      w.attribute(@xml.QName::unqualified("bg1"), cm.bg1.to_xml())
      w.attribute(@xml.QName::unqualified("tx1"), cm.tx1.to_xml())
      w.attribute(@xml.QName::unqualified("bg2"), cm.bg2.to_xml())
      w.attribute(@xml.QName::unqualified("tx2"), cm.tx2.to_xml())
      w.attribute(@xml.QName::unqualified("accent1"), cm.accent1.to_xml())
      w.attribute(@xml.QName::unqualified("accent2"), cm.accent2.to_xml())
      w.attribute(@xml.QName::unqualified("accent3"), cm.accent3.to_xml())
      w.attribute(@xml.QName::unqualified("accent4"), cm.accent4.to_xml())
      w.attribute(@xml.QName::unqualified("accent5"), cm.accent5.to_xml())
      w.attribute(@xml.QName::unqualified("accent6"), cm.accent6.to_xml())
      w.attribute(@xml.QName::unqualified("hlink"), cm.hlink.to_xml())
      w.attribute(@xml.QName::unqualified("folHlink"), cm.fol_hlink.to_xml())
      w.end_element()
    }
  }
  w.end_element()
}
