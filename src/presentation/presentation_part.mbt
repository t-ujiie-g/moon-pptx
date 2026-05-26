// `presentation.xml` typed model.
//
// `<p:presentation>` (`CT_Presentation`, ECMA-376 §19.2.1.26) is the
// main document part for every PPTX. We model what's needed to drive
// slide ordering + the immutable-build flow: master / notes-master /
// handout-master / slide ID lists, and the slide / notes coordinate
// spaces. Everything else (`<p:defaultTextStyle>`, `<p:custShowLst>`,
// `<p:photoAlbum>`, `<p:kinsoku>`, `<p:custDataLst>`, `<p:extLst>`,
// and per-presentation attributes like `saveSubsetFonts`) rides on
// `extension` per ADR-004 so it round-trips through parse / serialize
// even though we don't expose it as typed fields yet.

///|
/// One entry in `<p:sldMasterIdLst>` — a master ID + a rId pointing
/// to the slide-master part via `presentation.xml.rels`.
pub(all) struct SlideMasterIdRef {
  /// `id` attribute. Spec says `>= 2147483648`; we keep an `Int64`
  /// so the high bit is representable.
  id : Int64
  /// `r:id` — the relationship ID into `presentation.xml.rels`.
  r_id : String
} derive(Eq, Debug)

///|
/// One entry in `<p:sldIdLst>` — a slide ID + a rId pointing to the
/// slide part via `presentation.xml.rels`. Source order of these
/// entries is the actual on-screen slide order.
pub(all) struct SlideIdRef {
  /// `id` attribute. Spec says `>= 256 && <= 2147483647`.
  id : Int64
  /// `r:id` — the relationship ID into `presentation.xml.rels`.
  r_id : String
} derive(Eq, Debug)

///|
/// Slide-coordinate-space size with the spec's `type` enum baked in
/// (`screen4x3`, `screen16x9`, `widescreen`, `custom`, …). We keep
/// the type as a raw string because PowerPoint occasionally emits
/// custom enum values we'd otherwise have to enumerate.
pub(all) struct SlideSize {
  cx : @units.Emu
  cy : @units.Emu
  /// `type` attribute. Empty when the producer didn't emit one.
  size_type : String
} derive(Eq, Debug)

///|
/// Notes-coordinate-space size. Same `cx` / `cy` semantics as
/// `SlideSize` but no `type` attribute on the spec.
pub(all) struct NotesSize {
  cx : @units.Emu
  cy : @units.Emu
} derive(Eq, Debug)

///|
/// Parsed `<p:presentation>` part.
///
/// `sld_master_ids` is required to be non-empty in real PPTX (the
/// spec says `minOccurs="1"`), but we surface it as a plain array
/// rather than `Result` so callers can inspect malformed packages
/// without an extra error path.
pub(all) struct PresentationPart {
  /// `<p:sldMasterIdLst>` — at least one master in well-formed
  /// PPTX. Source order matches the document order.
  sld_master_ids : Array[SlideMasterIdRef]
  /// `<p:sldIdLst>` — actual slide order. Empty for decks with no
  /// slides (which is what `Presentation::new()` produces).
  sld_ids : Array[SlideIdRef]
  /// `<p:notesMasterIdLst>` — at most one notes master. Decks
  /// without speaker notes omit this entirely.
  notes_master_id : SlideIdRef?
  /// `<p:handoutMasterIdLst>` — at most one handout master.
  handout_master_id : SlideIdRef?
  /// `<p:sldSz>` — slide dimensions + size type. Real PPTX always
  /// emits this; `None` only happens on malformed input.
  sld_sz : SlideSize?
  /// `<p:notesSz>` — notes dimensions. Real PPTX always emits this
  /// too.
  notes_sz : NotesSize?
  /// Lossless preservation (ADR-004): every unmodelled child of
  /// `<p:presentation>` (`<p:defaultTextStyle>`, `<p:custShowLst>`,
  /// `<p:photoAlbum>`, `<p:kinsoku>`, `<p:custDataLst>`,
  /// `<p:extLst>`, foreign-namespace siblings) plus every
  /// unmodelled attribute on the root (captured as a special
  /// `<:root-attrs>` ad-hoc sentinel — see `parse_presentation`).
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

// --- parser ---

///|
/// Parse a `presentation.xml` part from raw bytes.
pub fn PresentationPart::parse(
  bytes : FixedArray[Byte],
) -> PresentationPart raise PptxError {
  let xml = @oxml.bytes_to_string(bytes) catch {
    e => raise Malformed(e.to_string())
  }
  parse_presentation_xml(xml)
}

///|
fn parse_presentation_xml(xml : String) -> PresentationPart raise PptxError {
  let r = @xml.XmlReader::new(xml)
  let event = next_event(r)
  let _ = match event {
    StartElement(name, _) =>
      if name.uri != @oxml.presentation_ns || name.local_name != "presentation" {
        raise Malformed("expected <p:presentation> root element")
      } else {
        ()
      }
    _ => raise Malformed("expected <p:presentation> root element")
  }
  // Root-level attributes (saveSubsetFonts, autoCompressPictures, …)
  // are not modeled today — we don't capture them either because the
  // most-frequent ones (saveSubsetFonts="0", autoCompressPictures="0")
  // have safe defaults that PowerPoint re-emits regardless. Add a
  // typed field when a real .pptx surfaces a need.
  let sld_master_ids : Array[SlideMasterIdRef] = []
  let sld_ids : Array[SlideIdRef] = []
  let mut notes_master_id : SlideIdRef? = None
  let mut handout_master_id : SlideIdRef? = None
  let mut sld_sz : SlideSize? = None
  let mut notes_sz : NotesSize? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "sldMasterIdLst" =>
              parse_id_list_into(r, sld_master_ids, "sldMasterId")
            "sldIdLst" => parse_slide_id_list_into(r, sld_ids)
            "notesMasterIdLst" =>
              notes_master_id = parse_single_id_list(r, "notesMasterId")
            "handoutMasterIdLst" =>
              handout_master_id = parse_single_id_list(r, "handoutMasterId")
            "sldSz" => {
              sld_sz = Some(parse_slide_size(attrs))
              skip_subtree(r)
            }
            "notesSz" => {
              notes_sz = Some(parse_notes_size(attrs))
              skip_subtree(r)
            }
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  {
    sld_master_ids,
    sld_ids,
    notes_master_id,
    handout_master_id,
    sld_sz,
    notes_sz,
    extension,
  }
}

///|
/// Parse `<p:sldMasterIdLst>` body — one or more `<p:sldMasterId>`.
/// The same shape works for any `id`+`r:id` list with one local
/// name, so we share it via the `expected_local` parameter.
fn parse_id_list_into(
  r : @xml.XmlReader,
  out : Array[SlideMasterIdRef],
  expected_local : String,
) -> Unit raise PptxError {
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.presentation_ns &&
          child.local_name == expected_local {
          let id_raw = require_attr(attrs, "id")
          let id = match @oxml.parse_signed_int64(id_raw) {
            Some(n) => n
            None => raise Malformed("sldMasterId id is not an integer")
          }
          let r_id = require_r_id(attrs)
          out.push({ id, r_id })
        }
        skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
}

///|
fn parse_slide_id_list_into(
  r : @xml.XmlReader,
  out : Array[SlideIdRef],
) -> Unit raise PptxError {
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.presentation_ns && child.local_name == "sldId" {
          let id_raw = require_attr(attrs, "id")
          let id = match @oxml.parse_signed_int64(id_raw) {
            Some(n) => n
            None => raise Malformed("sldId id is not an integer")
          }
          let r_id = require_r_id(attrs)
          out.push({ id, r_id })
        }
        skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
}

///|
fn parse_single_id_list(
  r : @xml.XmlReader,
  expected_local : String,
) -> SlideIdRef? raise PptxError {
  let mut out : SlideIdRef? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.presentation_ns &&
          child.local_name == expected_local {
          // `id` attribute is required on sldMasterId but not on
          // notesMasterId / handoutMasterId — those carry just
          // `r:id`. Treat absent id as 0.
          let id = match @oxml.optional_attr(attrs, "id") {
            Some(raw) =>
              match @oxml.parse_signed_int64(raw) {
                Some(n) => n
                None => raise Malformed("master id is not an integer")
              }
            None => 0L
          }
          let r_id = require_r_id(attrs)
          out = Some({ id, r_id })
        }
        skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
  out
}

///|
fn parse_slide_size(
  attrs : Array[(@xml.QName, String)],
) -> SlideSize raise PptxError {
  let cx_raw = require_attr(attrs, "cx")
  let cy_raw = require_attr(attrs, "cy")
  let cx = match @oxml.parse_signed_int64(cx_raw) {
    Some(n) => @units.Emu(n)
    None => raise Malformed("sldSz cx is not an integer")
  }
  let cy = match @oxml.parse_signed_int64(cy_raw) {
    Some(n) => @units.Emu(n)
    None => raise Malformed("sldSz cy is not an integer")
  }
  let size_type = match @oxml.optional_attr(attrs, "type") {
    Some(s) => s
    None => ""
  }
  { cx, cy, size_type }
}

///|
fn parse_notes_size(
  attrs : Array[(@xml.QName, String)],
) -> NotesSize raise PptxError {
  let cx_raw = require_attr(attrs, "cx")
  let cy_raw = require_attr(attrs, "cy")
  let cx = match @oxml.parse_signed_int64(cx_raw) {
    Some(n) => @units.Emu(n)
    None => raise Malformed("notesSz cx is not an integer")
  }
  let cy = match @oxml.parse_signed_int64(cy_raw) {
    Some(n) => @units.Emu(n)
    None => raise Malformed("notesSz cy is not an integer")
  }
  { cx, cy }
}

// --- writer ---

///|
/// Serialise a `PresentationPart` back to `presentation.xml` bytes.
pub fn PresentationPart::serialize(
  self : PresentationPart,
) -> FixedArray[Byte] raise PptxError {
  let xml = serialize_presentation_xml(self) catch {
    e => raise Malformed(e.to_string())
  }
  @oxml.string_to_bytes(xml)
}

///|
fn serialize_presentation_xml(
  p : PresentationPart,
) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  w.bind_namespace("p", @oxml.presentation_ns)
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "presentation"))
  w.namespace_attr("p", @oxml.presentation_ns)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  // Schema-canonical order: sldMasterIdLst → notesMasterIdLst →
  // handoutMasterIdLst → sldIdLst → sldSz → notesSz → extension.
  write_master_id_lst(w, p.sld_master_ids)
  match p.notes_master_id {
    Some(m) => write_master_choice(w, "notesMasterIdLst", "notesMasterId", m)
    None => ()
  }
  match p.handout_master_id {
    Some(m) =>
      write_master_choice(w, "handoutMasterIdLst", "handoutMasterId", m)
    None => ()
  }
  write_sld_id_lst(w, p.sld_ids)
  match p.sld_sz {
    Some(s) => write_slide_size(w, s)
    None => ()
  }
  match p.notes_sz {
    Some(s) => write_notes_size(w, s)
    None => ()
  }
  for ext in p.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
  w.to_string()
}

///|
fn write_master_id_lst(
  w : @xml.XmlWriter,
  ids : Array[SlideMasterIdRef],
) -> Unit raise @xml.XmlError {
  if ids.length() == 0 {
    return
  }
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "sldMasterIdLst"))
  for m in ids {
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "sldMasterId"))
    w.attribute(@xml.QName::unqualified("id"), m.id.to_string())
    w.attribute(@xml.QName::new(@oxml.office_relationships_ns, "id"), m.r_id)
    w.end_element()
  }
  w.end_element()
}

///|
fn write_sld_id_lst(
  w : @xml.XmlWriter,
  ids : Array[SlideIdRef],
) -> Unit raise @xml.XmlError {
  if ids.length() == 0 {
    return
  }
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "sldIdLst"))
  for s in ids {
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "sldId"))
    w.attribute(@xml.QName::unqualified("id"), s.id.to_string())
    w.attribute(@xml.QName::new(@oxml.office_relationships_ns, "id"), s.r_id)
    w.end_element()
  }
  w.end_element()
}

///|
fn write_master_choice(
  w : @xml.XmlWriter,
  wrapper_local : String,
  inner_local : String,
  id_ref : SlideIdRef,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, wrapper_local))
  w.start_element(@xml.QName::new(@oxml.presentation_ns, inner_local))
  // `<p:notesMasterId>` / `<p:handoutMasterId>` carry only `r:id` per
  // ECMA-376 §19.3.1.20 / §19.3.1.16 — the `id` attribute is defined
  // only on `<p:sldMasterId>` (CT_SlideMasterIdListEntry). Emitting
  // it on the wrong element gets silently stripped by PowerPoint
  // Online's loader and trips the repair banner.
  w.attribute(@xml.QName::new(@oxml.office_relationships_ns, "id"), id_ref.r_id)
  w.end_element()
  w.end_element()
}

///|
fn write_slide_size(
  w : @xml.XmlWriter,
  s : SlideSize,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "sldSz"))
  let @units.Emu(cx) = s.cx
  let @units.Emu(cy) = s.cy
  w.attribute(@xml.QName::unqualified("cx"), cx.to_string())
  w.attribute(@xml.QName::unqualified("cy"), cy.to_string())
  if s.size_type != "" {
    w.attribute(@xml.QName::unqualified("type"), s.size_type)
  }
  w.end_element()
}

///|
fn write_notes_size(
  w : @xml.XmlWriter,
  s : NotesSize,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "notesSz"))
  let @units.Emu(cx) = s.cx
  let @units.Emu(cy) = s.cy
  w.attribute(@xml.QName::unqualified("cx"), cx.to_string())
  w.attribute(@xml.QName::unqualified("cy"), cy.to_string())
  w.end_element()
}

// --- shared XML helpers ---

///|
fn next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise PptxError {
  let event = r.next() catch { e => raise Malformed(e.to_string()) }
  match event {
    Some(e) => e
    None => raise Malformed("unexpected end of input")
  }
}

///|
fn collect_subtree_unknown(
  r : @xml.XmlReader,
  name : @xml.QName,
  attrs : Array[(@xml.QName, String)],
) -> @xml.XmlElement raise PptxError {
  @oxml.collect_subtree(r, name, attrs) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
fn skip_subtree(r : @xml.XmlReader) -> Unit raise PptxError {
  @oxml.skip_subtree(r) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
fn require_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> String raise PptxError {
  match @oxml.optional_attr(attrs, name) {
    Some(v) => v
    None => raise Malformed("missing required attribute: " + name)
  }
}

///|
/// Look up the `r:id` attribute — namespaced under the office-
/// relationships namespace.
fn require_r_id(attrs : Array[(@xml.QName, String)]) -> String raise PptxError {
  for kv in attrs {
    if kv.0.uri == @oxml.office_relationships_ns && kv.0.local_name == "id" {
      return kv.1
    }
  }
  raise Malformed("missing required attribute: r:id")
}
