// Slide insertion API.
//
// `add_slide_mut(layout_index)` is the first mutation entry point on
// `Presentation`. It threads a new slide into every place the OPC
// package tracks it: a new `/ppt/slides/slideN.xml` part with a
// blank body, a relationship in `presentation.xml.rels` pointing at
// it, an entry in the in-package `presentation.xml`'s `<p:sldIdLst>`,
// a new `slideN.xml.rels` linking the slide back to its layout, and
// an `<Override>` in `[Content_Types].xml`.
//
// Per ADR-003 the default builder style is immutable, but the deck-
// editing path explicitly allows `_mut` variants. We start with the
// mutating one because every immutable variant has to clone the
// underlying `@opc.Package` first; cloning isn't exposed yet, so
// landing it can come in a separate slice without holding up the
// insertion plumbing.

///|
/// Append a blank slide using the slide layout at the given index in
/// `slide_layouts()`. Returns the new slide's part name so callers
/// can chain further edits via `update_slide_mut` + shape builders.
///
/// Mutates `self.pkg` in place — call `save()` afterwards to
/// materialise the change as bytes. The slide is appended; finer-
/// grained insertion (`insert_slide_at`) lands when a builder needs
/// it.
pub fn Presentation::add_slide_mut(
  self : Presentation,
  layout_index : Int,
) -> String raise PptxError {
  // 1. Locate the main-document part name (presentation.xml).
  let pres_name = match self.main_document_part_name() {
    Some(n) => n
    None =>
      raise Malformed(
        "package has no main-document relationship; cannot add slide",
      )
  }
  // 2. Identify the layout part the new slide should link to.
  let layout_part_name = self.layout_part_name_at(layout_index)
  // 3. Compute the new slide's part name + rId based on existing
  //    parts and rels.
  let new_slide_name = self.next_slide_part_name()
  let pres_rels = self.pkg.relationships_for(pres_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let new_slide_rid = next_unused_rid(pres_rels)
  // 4. Add the new slide part with a blank body.
  let slide_part = @opc.Part::new(
    new_slide_name,
    @oxml.ct_slide,
    @oxml.string_to_bytes(blank_slide_xml),
  ) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(slide_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  // 5. Update presentation.xml.rels — append a Relationship to the
  //    new slide.
  let updated_pres_rels = pres_rels.with_relationship(@opc.Relationship::{
    id: new_slide_rid,
    rel_type: @opc.rt_slide,
    target: relative_target(pres_name, new_slide_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(pres_name, updated_pres_rels)
  // 6. Update presentation.xml — append <p:sldId> to <p:sldIdLst>.
  let pres = match self.presentation_part() {
    Some(p) => p
    None =>
      raise Malformed("presentation.xml could not be parsed before add_slide")
  }
  let next_id = next_slide_id(pres.sld_ids)
  pres.sld_ids.push({ id: next_id, r_id: new_slide_rid })
  let new_pres_bytes = pres.serialize()
  self.replace_part_bytes(pres_name, new_pres_bytes, @oxml.ct_presentation)
  // 7. Add slideN.xml.rels — link the slide back to its layout.
  let slide_rels_xml = build_slide_rels_xml(
    relative_target(new_slide_name, layout_part_name),
  )
  let slide_rels_name = @opc.rels_path_for(new_slide_name)
  let slide_rels_part = @opc.Part::new(
    slide_rels_name,
    @opc.rels_content_type,
    @oxml.string_to_bytes(slide_rels_xml),
  ) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(slide_rels_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  // 8. Update [Content_Types].xml — add Override for the new slide.
  let ct = self.pkg
    .content_types()
    .with_override(new_slide_name, @oxml.ct_slide)
  self.pkg.set_content_types(ct)
  self.pkg.regenerate_content_types_part() catch {
    e => raise OpcFailure(e.to_string())
  }
  new_slide_name
}

// --- helpers ---

///|
/// Body of a slide that just inherits its layout's master color
/// mapping. Same shape as `blank_slide_layout_xml` minus the `type`
/// attribute and with `<p:sld>` as the root.
let blank_slide_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<p:sld xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"" +
  " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/>" +
  "<a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
  "</p:spTree></p:cSld>" +
  "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>" +
  "</p:sld>"

///|
/// Build a slide's `.rels` XML pointing at the given layout target.
/// One rel only, with `Id="rId1"`.
fn build_slide_rels_xml(layout_target : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rId1\" Type=\"" +
  @opc.rt_slide_layout +
  "\" Target=\"" +
  layout_target +
  "\"/>" +
  "</Relationships>"
}

///|
/// Look up `/ppt/slideLayouts/slideLayoutN.xml` for `slide_layouts()[layout_index]`
/// by walking the package's parts in storage order. The same package
/// order the accessor exposes is reused here; a future builder API
/// may surface a typed `SlideLayoutRef` instead.
fn Presentation::layout_part_name_at(
  self : Presentation,
  layout_index : Int,
) -> String raise PptxError {
  let mut seen = 0
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_slide_layout {
      if seen == layout_index {
        return p.name
      }
      seen = seen + 1
    }
  }
  raise Malformed(
    "layout index " + layout_index.to_string() + " is out of range",
  )
}

///|
/// Generate the next slide part name. Scans the current package for
/// `/ppt/slides/slideN.xml` entries and picks the smallest N greater
/// than any existing one. Picking the smallest unused N would lead
/// to gap reuse and re-mix presentation order; the append rule
/// matches what PowerPoint does.
fn Presentation::next_slide_part_name(self : Presentation) -> String {
  let mut next = 1
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_slide {
      let n = extract_slide_index(p.name)
      if n >= next {
        next = n + 1
      }
    }
  }
  "/ppt/slides/slide" + next.to_string() + ".xml"
}

///|
/// Parse the integer N out of `/ppt/slides/slideN.xml`. Returns 0
/// if the name doesn't fit that shape (e.g. an unusual content-typed
/// slide part), which won't displace any real slide.
fn extract_slide_index(name : String) -> Int {
  let prefix = "/ppt/slides/slide"
  let suffix = ".xml"
  let total = name.length()
  let prefix_len = prefix.length()
  let suffix_len = suffix.length()
  if total <= prefix_len + suffix_len {
    return 0
  }
  // String slicing in MoonBit: substring via `op_get_view`
  let prefix_part = name.view(start_offset=0, end_offset=prefix_len)
  if prefix_part.to_owned() != prefix {
    return 0
  }
  let middle = name.view(start_offset=prefix_len, end_offset=total - suffix_len)
  let suffix_part = name.view(start_offset=total - suffix_len, end_offset=total)
  if suffix_part.to_owned() != suffix {
    return 0
  }
  // Parse the middle as an integer.
  match @oxml.parse_signed_int(middle.to_owned()) {
    Some(n) => n
    None => 0
  }
}

///|
/// Find the smallest `rIdN` not already used in `rels`. Same
/// approach as `next_slide_part_name` — append rather than reuse
/// gaps.
fn next_unused_rid(rels : @opc.Relationships) -> String {
  let mut max_seen = 0
  for r in rels.items {
    let n = extract_rid_index(r.id)
    if n > max_seen {
      max_seen = n
    }
  }
  "rId" + (max_seen + 1).to_string()
}

///|
fn extract_rid_index(rid : String) -> Int {
  let prefix = "rId"
  let total = rid.length()
  let prefix_len = prefix.length()
  if total <= prefix_len {
    return 0
  }
  let prefix_part = rid.view(start_offset=0, end_offset=prefix_len)
  if prefix_part.to_owned() != prefix {
    return 0
  }
  let tail = rid.view(start_offset=prefix_len, end_offset=total)
  match @oxml.parse_signed_int(tail.to_owned()) {
    Some(n) => n
    None => 0
  }
}

///|
/// Next slide `id` for `<p:sldId>`. The spec reserves `256..2^31`
/// for slide IDs (lower numbers are master IDs). Pick max(existing,
/// 255) + 1 so the result is always valid.
fn next_slide_id(existing : Array[SlideIdRef]) -> Int64 {
  let mut max_id : Int64 = 255L
  for s in existing {
    if s.id > max_id {
      max_id = s.id
    }
  }
  max_id + 1L
}

///|
/// Compute the `Target=` attribute string for a part-to-part
/// relationship via standard relative-path math:
///
///   1. Split both paths into components.
///   2. Find the longest common prefix.
///   3. Emit `../` for each non-common source component.
///   4. Append the non-common target components joined by `/`.
///
/// Example: `/ppt/slides/slide1.xml` → `/ppt/slideLayouts/slideLayout1.xml`
/// gives `../slideLayouts/slideLayout1.xml` (common = `ppt/`; one
/// step up from `slides/`; descend into `slideLayouts/slideLayout1
/// .xml`).
fn relative_target(source_part : String, target_part : String) -> String {
  let src_dir_comps = path_components(parent_dir(source_part))
  let tgt_comps = path_components(target_part)
  // Common prefix.
  let mut common = 0
  while common < src_dir_comps.length() &&
        common < tgt_comps.length() &&
        src_dir_comps[common] == tgt_comps[common] {
    common = common + 1
  }
  // Number of "../" hops.
  let ups = src_dir_comps.length() - common
  let mut out = ""
  let mut i = 0
  while i < ups {
    out = out + "../"
    i = i + 1
  }
  let mut j = common
  while j < tgt_comps.length() {
    if j > common {
      out = out + "/"
    }
    out = out + tgt_comps[j]
    j = j + 1
  }
  out
}

///|
fn parent_dir(part : String) -> String {
  let total = part.length()
  let mut i = total - 1
  while i > 0 {
    if part.view(start_offset=i, end_offset=i + 1).to_owned() == "/" {
      return part.view(start_offset=0, end_offset=i).to_owned()
    }
    i = i - 1
  }
  "/"
}

///|
/// Split an OPC-style path (`/ppt/slides/slide1.xml`) into its
/// non-empty components. Leading `/` is treated as a root marker and
/// produces no component.
fn path_components(path : String) -> Array[String] {
  let out : Array[String] = []
  let total = path.length()
  let mut start = 0
  // Skip the leading slash so the first component isn't empty.
  if total > 0 && path.view(start_offset=0, end_offset=1).to_owned() == "/" {
    start = 1
  }
  let mut i = start
  while i <= total {
    if i == total ||
      path.view(start_offset=i, end_offset=i + 1).to_owned() == "/" {
      if i > start {
        out.push(path.view(start_offset=start, end_offset=i).to_owned())
      }
      start = i + 1
    }
    i = i + 1
  }
  out
}

///|
/// Replace the bytes of a part already known to exist. Same trick as
/// the integration test's `replace_part_bytes` — `add_part` rejects
/// duplicates, so remove + re-add.
fn Presentation::replace_part_bytes(
  self : Presentation,
  name : String,
  bytes : FixedArray[Byte],
  content_type : String,
) -> Unit raise PptxError {
  let _ = self.pkg.remove_part(name)
  let part = @opc.Part::new(name, content_type, bytes) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(part) catch {
    e => raise OpcFailure(e.to_string())
  }
}

///|
/// Write a `Relationships` value into the package's `.rels` part for
/// `source_part`. Creates the part if it doesn't exist.
fn Presentation::write_rels_for_part(
  self : Presentation,
  source_part : String,
  rels : @opc.Relationships,
) -> Unit raise PptxError {
  let bytes = rels.serialize() catch { e => raise OpcFailure(e.to_string()) }
  let rels_name = @opc.rels_path_for(source_part)
  self.replace_part_bytes(rels_name, bytes, @opc.rels_content_type)
}
