// Programmatic slide-master definition (roadmap v0.3 C1 + A8 master side).
//
// `define_master` synthesises a new `<p:sldMaster>` + one dependent
// `<p:sldLayout>` and wires them into the package (parts, rels, content
// types, `<p:sldMasterIdLst>`). The master's `<p:cSld>` (background +
// placeholder shapes) is produced by serialising a throwaway `@slide.Slide`
// — that reuses the slide writer's shape emission + XML escaping — then
// extracted and re-wrapped as a master (which differs only by `<p:clrMap>`
// vs `<p:clrMapOvr>` and the trailing `<p:sldLayoutIdLst>`).

///|
/// One placeholder declared on a master (roadmap C1). `kind` is the
/// `ST_PlaceholderType`; `position` is its rectangle on the master;
/// `default_text` is prompt text shown until a slide overrides it.
pub(all) struct PlaceholderDef {
  kind : @slide.PlaceholderType
  position : @slide.Transform
  default_text : String?
}

///|
/// A high-level master definition (roadmap C1). Build with
/// `MasterDefinition::new` then the `with_*` helpers, or as a struct literal.
pub(all) struct MasterDefinition {
  name : String
  background : @slide.Background?
  placeholders : Array[PlaceholderDef]
  /// Declare a slide-number (`sldNum`) placeholder on the master.
  slide_number : Bool
  /// Declare a footer (`ftr`) placeholder carrying this text, if `Some`.
  footer_text : String?
  /// Declare a date (`dt`) placeholder on the master (pairs with
  /// `@slide.Slide::with_date`).
  date : Bool
}

///|
/// A `MasterDefinition` with the given name and no placeholders / footer /
/// date / slide number / background. Use the `with_*` helpers to fill it in.
pub fn MasterDefinition::new(name : String) -> MasterDefinition {
  {
    name,
    background: None,
    placeholders: [],
    slide_number: false,
    footer_text: None,
    date: false,
  }
}

///|
/// Append a placeholder declaration.
pub fn MasterDefinition::with_placeholder(
  self : MasterDefinition,
  kind : @slide.PlaceholderType,
  position : @slide.Transform,
  default_text? : String,
) -> MasterDefinition {
  let phs : Array[PlaceholderDef] = []
  for p in self.placeholders {
    phs.push(p)
  }
  phs.push({ kind, position, default_text })
  { ..self, placeholders: phs }
}

///|
/// Set the master background.
pub fn MasterDefinition::with_background(
  self : MasterDefinition,
  bg : @slide.Background,
) -> MasterDefinition {
  { ..self, background: Some(bg) }
}

///|
/// Declare a slide-number placeholder on the master.
pub fn MasterDefinition::with_slide_number(
  self : MasterDefinition,
  visible : Bool,
) -> MasterDefinition {
  { ..self, slide_number: visible }
}

///|
/// Declare a footer placeholder carrying `text`.
pub fn MasterDefinition::with_footer(
  self : MasterDefinition,
  text : String,
) -> MasterDefinition {
  { ..self, footer_text: Some(text) }
}

///|
/// Declare a date placeholder on the master.
pub fn MasterDefinition::with_date(
  self : MasterDefinition,
  visible : Bool,
) -> MasterDefinition {
  { ..self, date: visible }
}

// --- the builder ---

///|
/// Synthesise a slide master (plus one blank dependent layout) from `def`
/// and register it in the package. Returns the new master's index in
/// `slide_masters()`.
///
/// The master carries `def`'s placeholders (plus optional footer / date /
/// slide-number placeholders); the dependent layout repeats them so a
/// `Presentation::add_slide_mut` against that layout inherits their geometry.
/// The new master gets its own theme part (a copy of an existing theme) —
/// two masters sharing one theme trips PowerPoint's repair prompt.
pub fn Presentation::define_master(
  self : Presentation,
  def : MasterDefinition,
) -> Int raise PptxError {
  let pres_name = match self.main_document_part_name() {
    Some(n) => n
    None => raise Malformed("package has no main-document relationship")
  }
  // 1. Allocate part names + ids.
  let master_name = self.next_master_part_name()
  let layout_name = self.next_layout_part_name()
  // Each slide master needs its *own* theme part — PowerPoint flags a deck
  // where two masters share one theme as needing repair (same lesson as the
  // notes master). Duplicate an existing theme into a fresh part.
  let theme_name = "/ppt/theme/theme" +
    (self.max_part_index("/ppt/theme/theme") + 1).to_string() +
    ".xml"
  let src_theme = find_theme_part_name(self.pkg)
  let src_theme_bytes = self.pkg.require_part(src_theme) catch {
    e => raise OpcFailure(e.to_string())
  }
  let theme_part = @opc.Part::new(
    theme_name,
    @oxml.ct_theme,
    src_theme_bytes.bytes,
  ) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(theme_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  let pres = match self.presentation_part() {
    Some(p) => p
    None => raise Malformed("presentation.xml could not be parsed")
  }
  // Master ids and layout ids share one id space (>= 2147483648); PowerPoint
  // repairs a deck that reuses a value. Pick ids above *every* existing
  // master id (presentation) AND layout id (each master's sldLayoutIdLst).
  let mut id_base = 2147483647L
  for r in pres.sld_master_ids {
    if r.id > id_base {
      id_base = r.id
    }
  }
  let layout_max = self.max_slide_layout_id()
  if layout_max > id_base {
    id_base = layout_max
  }
  let master_id = id_base + 1L
  let layout_id = id_base + 2L
  // 2. Build the master + layout cSld (background + placeholder shapes) via a
  //    throwaway slide. The layout carries the *same* placeholders so a slide
  //    on it inherits their geometry (a blank layout leaves slide-level
  //    footer / date / number placeholders unpositioned).
  let master_xml = wrap_slide_master_xml(
    build_placeholder_csld(def, with_bg=true),
    layout_id,
  )
  let layout_xml = wrap_slide_layout_xml(
    build_placeholder_csld(def, with_bg=false),
  )
  // 3. Add the master + layout parts.
  self.add_xml_part(master_name, @oxml.ct_slide_master, master_xml)
  self.add_xml_part(layout_name, @oxml.ct_slide_layout, layout_xml)
  // 4. Rels: master → layout + its own theme; layout → master.
  self.write_rels_for_part(
    master_name,
    parsed_rels(master_name, [
      ("rId1", @opc.rt_slide_layout, relative_target(master_name, layout_name)),
      ("rId2", @opc.rt_theme, relative_target(master_name, theme_name)),
    ]),
  )
  self.write_rels_for_part(
    layout_name,
    parsed_rels(layout_name, [
      ("rId1", @opc.rt_slide_master, relative_target(layout_name, master_name)),
    ]),
  )
  // 5. presentation.xml.rels — point at the new master.
  let pres_rels = self.pkg.relationships_for(pres_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let master_rid = next_unused_rid(pres_rels)
  let updated = pres_rels.with_relationship(@opc.Relationship::{
    id: master_rid,
    rel_type: @opc.rt_slide_master,
    target: relative_target(pres_name, master_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(pres_name, updated)
  // 6. presentation.xml — push a <p:sldMasterId>.
  pres.sld_master_ids.push({ id: master_id, r_id: master_rid })
  self.replace_part_bytes(pres_name, pres.serialize(), @oxml.ct_presentation)
  // 7. Content types.
  let ct = self.pkg
    .content_types()
    .with_override(master_name, @oxml.ct_slide_master)
    .with_override(layout_name, @oxml.ct_slide_layout)
    .with_override(theme_name, @oxml.ct_theme)
  self.pkg.set_content_types(ct)
  self.pkg.regenerate_content_types_part() catch {
    e => raise OpcFailure(e.to_string())
  }
  pres.sld_master_ids.length() - 1
}

// --- master cSld synthesis ---

///|
/// Build the placeholder shapes into a throwaway `@slide.Slide`, serialise
/// it, and extract the `<p:cSld>…</p:cSld>` for re-wrapping as a master or a
/// layout. `with_bg` adds the background (only the master carries one; the
/// layout inherits it).
fn build_placeholder_csld(
  def : MasterDefinition,
  with_bg~ : Bool,
) -> String raise PptxError {
  let shapes : Array[@slide.Shape] = []
  let mut sid = 2
  for i, p in def.placeholders {
    let body : @slide.TextBody? = match p.default_text {
      Some(t) => Some(@slide.TextBody::of_text(t))
      None => None
    }
    shapes.push(
      AutoShape(master_placeholder(sid, p.kind.to_xml(), i, p.position, body)),
    )
    sid = sid + 1
  }
  // Footer / date / slide-number placeholders along the bottom band. The
  // idx values (dt=10, ftr=11, sldNum=12) match the slide-side convention in
  // `@slide`'s `with_date` / `with_footer` / `with_slide_number` so the
  // slide placeholders inherit position from these master ones.
  match def.footer_text {
    Some(text) => {
      shapes.push(
        AutoShape(
          master_placeholder(
            sid,
            "ftr",
            11,
            hf_rect(3124200L),
            Some(@slide.TextBody::of_text(text)),
          ),
        ),
      )
      sid = sid + 1
    }
    None => ()
  }
  if def.date {
    shapes.push(
      AutoShape(master_placeholder(sid, "dt", 10, hf_rect(457200L), None)),
    )
    sid = sid + 1
  }
  if def.slide_number {
    shapes.push(
      AutoShape(master_placeholder(sid, "sldNum", 12, hf_rect(6553200L), None)),
    )
    sid = sid + 1
  }
  // A slide master without a `<p:bg>` trips PowerPoint's repair banner, so
  // the master defaults to the standard theme background reference when none
  // is given; the layout omits the background entirely (it inherits it).
  let background : @slide.Background? = if with_bg {
    match def.background {
      Some(b) => Some(b)
      None =>
        Some(StyleReference(1001, @oxml.Color::scheme(@units.ThemeColor::Bg1)))
    }
  } else {
    None
  }
  let slide : @slide.Slide = {
    name: "",
    background,
    shapes,
    clr_map_override: @slide_master.ClrMapOverride::MasterMapping,
    transition: None,
    timing: None,
    extension: [],
  }
  let xml = @oxml.bytes_to_string(slide.serialize()) catch {
    e => raise SlideFailure(e.to_string())
  }
  extract_csld(xml)
}

///|
/// A bottom-band header/footer rectangle at horizontal offset `x` (EMU),
/// sized like PowerPoint's default master hf placeholders.
fn hf_rect(x : Int64) -> @slide.Transform {
  @slide.Transform::new(offset={ x: @units.Emu(x), y: @units.Emu(6356350L) }, extent={
    cx: @units.Emu(2438400L),
    cy: @units.Emu(365125L),
  })
}

///|
/// Build a master placeholder `<p:sp>` value with a typed transform.
fn master_placeholder(
  id : Int,
  ph_type : String,
  idx : Int,
  position : @slide.Transform,
  body : @slide.TextBody?,
) -> @slide.AutoShape {
  {
    id,
    name: ph_type + " placeholder",
    placeholder: Some({ ph_type, idx }),
    transform: Some(position),
    geometry: None,
    fill: None,
    stroke: None,
    effects: None,
    text_body: body,
    hyperlink: None,
    extension: [],
  }
}

// --- XML wrappers ---

///|
/// Standard 12-slot colour map (matches the blank template).
let master_clr_map : String = "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
  " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\"" +
  " accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\"" +
  " hlink=\"hlink\" folHlink=\"folHlink\"/>"

///|
/// Wrap an extracted `<p:cSld>` as a `<p:sldMaster>` referencing the layout
/// `layout_id` (which `slideMaster.xml.rels`'s `rId1` resolves).
fn wrap_slide_master_xml(csld : String, layout_id : Int64) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<p:sldMaster xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
  " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
  csld +
  master_clr_map +
  "<p:sldLayoutIdLst><p:sldLayoutId id=\"" +
  layout_id.to_string() +
  "\" r:id=\"rId1\"/></p:sldLayoutIdLst>" +
  "</p:sldMaster>"
}

///|
/// Wrap an extracted `<p:cSld>` (carrying the placeholder shapes) as a
/// `type="blank"` `<p:sldLayout>` inheriting the master. The shared
/// placeholders give slides on this layout an inheritance source for their
/// title / body / footer / date / slide-number geometry.
fn wrap_slide_layout_xml(
  csld : String,
  layout_type? : String = "blank",
) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<p:sldLayout xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"" +
  " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" type=\"" +
  layout_type +
  "\">" +
  csld +
  "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>" +
  "</p:sldLayout>"
}

// --- string + OPC helpers ---

///|
/// Extract `<p:cSld>…</p:cSld>` (inclusive) from serialised slide XML.
fn extract_csld(slide_xml : String) -> String {
  let start = str_index(slide_xml, "<p:cSld", 0)
  let close = "</p:cSld>"
  let end = str_index(slide_xml, close, start)
  slide_xml.view(start_offset=start, end_offset=end + close.length()).to_owned()
}

///|
/// Index of `needle` in `hay` at or after `from` (character offsets), or a
/// negative number if absent. Only used on writer-produced XML where the
/// markers are guaranteed present.
fn str_index(hay : String, needle : String, from : Int) -> Int {
  let hn = hay.length()
  let nn = needle.length()
  let mut i = from
  while i + nn <= hn {
    let mut j = 0
    while j < nn && hay[i + j] == needle[j] {
      j = j + 1
    }
    if j == nn {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Add an OOXML string part to the package.
fn Presentation::add_xml_part(
  self : Presentation,
  name : String,
  content_type : String,
  xml : String,
) -> Unit raise PptxError {
  let part = @opc.Part::new(name, content_type, @oxml.string_to_bytes(xml)) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(part) catch {
    e => raise OpcFailure(e.to_string())
  }
}

///|
/// Build a `Relationships` value from `(id, type, target)` triples.
fn parsed_rels(
  source : String,
  triples : Array[(String, String, String)],
) -> @opc.Relationships raise PptxError {
  let mut rels = @opc.Relationships::new(source)
  for t in triples {
    rels = rels.with_relationship(@opc.Relationship::{
      id: t.0,
      rel_type: t.1,
      target: t.2,
      target_mode: Internal,
    }) catch {
      e => raise OpcFailure(e.to_string())
    }
  }
  rels
}

///|
/// `/ppt/slideMasters/slideMasterN.xml` with the next free N.
fn Presentation::next_master_part_name(self : Presentation) -> String {
  "/ppt/slideMasters/slideMaster" +
  (self.max_part_index("/ppt/slideMasters/slideMaster") + 1).to_string() +
  ".xml"
}

///|
/// `/ppt/slideLayouts/slideLayoutN.xml` with the next free N.
fn Presentation::next_layout_part_name(self : Presentation) -> String {
  "/ppt/slideLayouts/slideLayout" +
  (self.max_part_index("/ppt/slideLayouts/slideLayout") + 1).to_string() +
  ".xml"
}

///|
/// Highest integer `N` among package parts named `{prefix}N{.ext}`, or `0`
/// if none. The shared part-name scanner behind every `next_*_part_name`
/// (slides, layouts, masters, media, images, charts) — it reads the run of
/// digits immediately after `prefix` up to the next `.`, so a non-matching
/// tail (e.g. `chartEx…` under the `chart` prefix) is skipped.
fn Presentation::max_part_index(self : Presentation, prefix : String) -> Int {
  let mut max = 0
  for p in self.pkg.parts() {
    if p.name.length() > prefix.length() &&
      p.name.view(start_offset=0, end_offset=prefix.length()).to_owned() ==
      prefix {
      let rest = p.name.view(start_offset=prefix.length()).to_owned()
      let dot = str_index(rest, ".", 0)
      let digits = if dot >= 0 {
        rest.view(start_offset=0, end_offset=dot).to_owned()
      } else {
        rest
      }
      match @oxml.parse_signed_int(digits) {
        Some(n) => if n > max { max = n }
        None => ()
      }
    }
  }
  max
}

///|
/// Largest `<p:sldLayoutId>` id across every slide master's `sldLayoutIdLst`
/// (each master part carries its own). Returned as the shared-space floor so
/// new master/layout ids stay clear of existing layout ids; `2147483647` if
/// none. (Parsed as `Int64` — these ids exceed `Int`'s range.)
fn Presentation::max_slide_layout_id(self : Presentation) -> Int64 {
  let prefix = "/ppt/slideMasters/slideMaster"
  let marker = "sldLayoutId id=\""
  let mut max = 2147483647L
  for p in self.pkg.parts() {
    if p.name.length() <= prefix.length() ||
      p.name.view(start_offset=0, end_offset=prefix.length()).to_owned() !=
      prefix {
      continue
    }
    let xml = @oxml.bytes_to_string(p.bytes) catch { _ => continue }
    let mut from = 0
    while true {
      let at = str_index(xml, marker, from)
      if at < 0 {
        break
      }
      let mut j = at + marker.length()
      let mut value = 0L
      let mut saw_digit = false
      while j < xml.length() {
        let c = xml[j].to_int()
        if c < '0'.to_int() || c > '9'.to_int() {
          break
        }
        value = value * 10L + (c - '0'.to_int()).to_int64()
        saw_digit = true
        j = j + 1
      }
      if saw_digit && value > max {
        max = value
      }
      from = j + 1
    }
  }
  max
}
