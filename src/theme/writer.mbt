// Theme XML writer.
//
// Mirrors `parser.mbt`. Each `serialize_*` helper writes onto an
// `@xml.XmlWriter` positioned just after the parent's StartElement and
// emits this element + its children + the matching EndElement.
//
// Extension preservation per ADR-004: every captured `extension` array
// is replayed via `@oxml.write_xml_element`. The slot-level
// `<a:clrScheme>` ordering matches `parse_color_scheme`'s output order
// (dk1 → lt1 → dk2 → lt2 → accent1..6 → hlink → folHlink), which is
// the order PowerPoint emits.

///|
/// Serialise a `Theme` back to `theme1.xml`-shaped bytes.
pub fn Theme::serialize(self : Theme) -> FixedArray[Byte] raise ThemeError {
  let xml = serialize_theme_xml(self) catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
fn serialize_theme_xml(t : Theme) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("a", @oxml.drawing_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "theme"))
  w.namespace_attr("a", @oxml.drawing_ns)
  if t.name != "" {
    w.attribute(@xml.QName::unqualified("name"), t.name)
  }
  write_theme_elements(w, ctx, t)
  // Theme-level extensions: <a:objectDefaults>, <a:extraClrSchemeLst>,
  // any captured `<a:fmtScheme>`, foreign-namespace, etc.
  for ext in t.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
  w.to_string()
}

///|
fn write_theme_elements(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  t : Theme,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "themeElements"))
  write_color_scheme(w, ctx, t.color_scheme)
  write_font_scheme(w, ctx, t.font_scheme)
  w.end_element()
}

///|
fn write_color_scheme(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  cs : ColorScheme,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "clrScheme"))
  if cs.name != "" {
    w.attribute(@xml.QName::unqualified("name"), cs.name)
  }
  // Emit slots in canonical order (matches Office output).
  write_slot(w, ctx, "dk1", cs.dk1)
  write_slot(w, ctx, "lt1", cs.lt1)
  write_slot(w, ctx, "dk2", cs.dk2)
  write_slot(w, ctx, "lt2", cs.lt2)
  write_slot(w, ctx, "accent1", cs.accent1)
  write_slot(w, ctx, "accent2", cs.accent2)
  write_slot(w, ctx, "accent3", cs.accent3)
  write_slot(w, ctx, "accent4", cs.accent4)
  write_slot(w, ctx, "accent5", cs.accent5)
  write_slot(w, ctx, "accent6", cs.accent6)
  write_slot(w, ctx, "hlink", cs.hlink)
  write_slot(w, ctx, "folHlink", cs.fol_hlink)
  // ColorScheme-level extensions (rare — only foreign-namespace siblings).
  for ext in cs.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// One slot wrapper element (`<a:dk1>` / `<a:accent1>` / …) containing
/// exactly one colour child.
fn write_slot(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  slot_name : String,
  c : @oxml.Color,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, slot_name))
  @oxml.write_color(w, ctx, c)
  w.end_element()
}

///|
fn write_font_scheme(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  fs : FontScheme,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "fontScheme"))
  if fs.name != "" {
    w.attribute(@xml.QName::unqualified("name"), fs.name)
  }
  write_font_collection(w, ctx, "majorFont", fs.major_font)
  write_font_collection(w, ctx, "minorFont", fs.minor_font)
  for ext in fs.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_font_collection(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  wrapper_local : String,
  fc : FontCollection,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, wrapper_local))
  write_typeface_leaf(w, "latin", fc.latin)
  write_typeface_leaf(w, "ea", fc.ea)
  write_typeface_leaf(w, "cs", fc.cs)
  for sf in fc.scripts {
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "font"))
    w.attribute(@xml.QName::unqualified("script"), sf.script)
    w.attribute(@xml.QName::unqualified("typeface"), sf.typeface)
    w.end_element()
  }
  for ext in fc.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit `<a:{name} typeface="…"/>` — the latin/ea/cs leaves of a
/// `FontCollection`. The empty typeface is the spec's "no typeface
/// override" sentinel; we still emit the element with an empty value
/// because dropping it would change `<a:ea typeface=""/>` into nothing
/// and break round-trip equality.
fn write_typeface_leaf(
  w : @xml.XmlWriter,
  name : String,
  typeface : String,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, name))
  w.attribute(@xml.QName::unqualified("typeface"), typeface)
  w.end_element()
}
