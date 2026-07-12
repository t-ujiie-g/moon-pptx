// Layout resolution / synthesis by type.
//
// The typed layout-handle constructors need a `<p:sldLayout>` of a specific
// `ST_SlideLayoutType` to link their slide to. A deck built by
// `Presentation::new()` ships only a single `type="blank"` layout, so this
// resolves an existing layout of the requested type and, when none exists,
// synthesises one — declaring the layout's placeholders (so slides on it
// inherit their geometry) and wiring it into the first slide master's
// `<p:sldLayoutIdLst>` + rels + content types. Reuses the `define_master`
// placeholder-cSld synthesis (`build_placeholder_csld` / `wrap_slide_layout_xml`).

///|
/// Resolve the part name of a slide layout whose `type=` matches
/// `layout_type`, synthesising one (attached to the first master) when the
/// deck has none. `placeholders` declares the layout's placeholder geometry.
/// Returns the layout part name for `add_slide_on_layout_mut`.
fn Presentation::ensure_layout_of_type(
  self : Presentation,
  layout_type : @slide_master.SlideLayoutType,
  placeholders : Array[PlaceholderDef],
) -> String raise PptxError {
  // 1. Resolve an existing layout of this type.
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_slide_layout {
      let l = @slide_master.SlideLayout::parse(p.bytes) catch {
        e => raise SlideMasterFailure(p.name + ": " + e.to_string())
      }
      if l.layout_type == layout_type {
        return p.name
      }
    }
  }
  // 2. Synthesise, attached to the main (lowest-index) slide master. We
  //    select by part-name index, not package order: `replace_part_bytes`
  //    (remove + re-add) reorders parts, so a plain "first in order" pick
  //    would drift to a different master across successive calls.
  let master_name = match find_main_master_part_name(self.pkg) {
    Some(n) => n
    None => raise Malformed("package has no slide master to attach a layout to")
  }
  let layout_name = self.next_layout_part_name()
  let mut def = MasterDefinition::new("")
  for ph in placeholders {
    def = def.with_placeholder(
      ph.kind,
      ph.position,
      default_text?=ph.default_text,
    )
  }
  let csld = build_placeholder_csld(def, with_bg=false)
  let layout_xml = wrap_slide_layout_xml(csld, layout_type=layout_type.to_xml())
  self.add_xml_part(layout_name, @oxml.ct_slide_layout, layout_xml)
  // 3. master → layout relationship (fresh rId in the master's .rels).
  let master_rels = self.pkg.relationships_for(master_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let layout_rid = next_unused_rid(master_rels)
  let updated = master_rels.with_relationship(@opc.Relationship::{
    id: layout_rid,
    rel_type: @opc.rt_slide_layout,
    target: relative_target(master_name, layout_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(master_name, updated)
  // 4. layout → master relationship.
  self.write_rels_for_part(
    layout_name,
    parsed_rels(layout_name, [
      ("rId1", @opc.rt_slide_master, relative_target(layout_name, master_name)),
    ]),
  )
  // 5. Register the layout in the master's <p:sldLayoutIdLst>.
  let master_part = self.pkg.require_part(master_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let master = @slide_master.SlideMaster::parse(master_part.bytes) catch {
    e => raise SlideMasterFailure(e.to_string())
  }
  master.layout_refs.push({ id: self.next_layout_id(), r_id: layout_rid })
  let master_bytes = master.serialize() catch {
    e => raise SlideMasterFailure(e.to_string())
  }
  self.replace_part_bytes(master_name, master_bytes, @oxml.ct_slide_master)
  // 6. Content types.
  let ct = self.pkg
    .content_types()
    .with_override(layout_name, @oxml.ct_slide_layout)
  self.pkg.set_content_types(ct)
  self.pkg.regenerate_content_types_part() catch {
    e => raise OpcFailure(e.to_string())
  }
  layout_name
}

///|
/// The main slide-master part name — the one with the lowest
/// `/ppt/slideMasters/slideMasterN.xml` index — or `None`. Chosen by name
/// (not package order) so it stays stable when `replace_part_bytes` reorders
/// parts between calls.
fn find_main_master_part_name(pkg : @opc.Package) -> String? {
  let prefix = "/ppt/slideMasters/slideMaster"
  let mut best : String? = None
  let mut best_n = 0
  for p in pkg.parts() {
    if p.content_type == @oxml.ct_slide_master {
      let rest = if p.name.length() > prefix.length() {
        p.name.view(start_offset=prefix.length()).to_owned()
      } else {
        ""
      }
      let dot = str_index(rest, ".", 0)
      let digits = if dot >= 0 {
        rest.view(start_offset=0, end_offset=dot).to_owned()
      } else {
        rest
      }
      let n = @oxml.parse_signed_int(digits).unwrap_or(0)
      if best is None || n < best_n {
        best = Some(p.name)
        best_n = n
      }
    }
  }
  best
}

///|
/// Next id for a `<p:sldLayoutId>` in the shared master/layout id space
/// (`>= 2147483648`): one greater than every existing master id and layout
/// id, so it never collides (a reused id trips PowerPoint's repair prompt).
fn Presentation::next_layout_id(self : Presentation) -> Int64 raise PptxError {
  let mut base = self.max_slide_layout_id()
  match self.presentation_part() {
    Some(pres) =>
      for r in pres.sld_master_ids {
        if r.id > base {
          base = r.id
        }
      }
    None => ()
  }
  base + 1L
}
