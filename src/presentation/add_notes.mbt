// Speaker-notes builder.
//
// `set_notes_mut(slide_idx, text)` attaches a notes slide to the
// given source slide. If a notes slide already exists for that slide
// we replace its bytes; otherwise we synthesise a fresh
// `/ppt/notesSlides/notesSlideN.xml` part, plumb the slide → notes
// relationship, and register the Override content type.
//
// PowerPoint Online refuses to open a deck whose notes slides aren't
// backed by a notes master (it pops a "needs repair" banner), so on
// the first call to `set_notes_mut` we also synthesise a minimal
// `/ppt/notesMasters/notesMaster1.xml` linked to the existing
// `theme1.xml` and register it via `<p:notesMasterIdLst>` in
// `presentation.xml`. Subsequent calls reuse the master.

///|
/// Set the speaker notes on slide `slide_idx` to `text`. Creates the
/// underlying notesSlide part on first use; replaces its body on
/// subsequent calls. Raises `Malformed` if the slide index is out of
/// range.
pub fn Presentation::set_notes_mut(
  self : Presentation,
  slide_idx : Int,
  text : String,
) -> Unit raise PptxError {
  let slide_parts = self.ordered_slide_parts()
  if slide_idx < 0 || slide_idx >= slide_parts.length() {
    raise Malformed(
      "set_notes_mut: slide_idx " +
      slide_idx.to_string() +
      " out of range (have " +
      slide_parts.length().to_string() +
      " slides)",
    )
  }
  let slide_part = slide_parts[slide_idx]
  let slide_name = slide_part.name

  // Make sure a notes master is in place — PowerPoint Online flags a
  // notesSlide with no backing master as needing repair.
  let notes_master_name = self.ensure_notes_master()

  // Build the typed NotesSlide value first — text escaping comes for
  // free through the XML writer.
  let notes = build_notes_slide(text)
  let notes_bytes = notes.serialize() catch {
    e => raise NotesFailure(e.to_string())
  }

  // Is there already a notes slide attached to this slide? If so we
  // overwrite that part rather than creating a new one.
  let slide_rels = self.pkg.relationships_for(slide_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let existing_rels = slide_rels.by_type(@opc.rt_notes_slide)
  if existing_rels.length() > 0 {
    // Resolve relative target → absolute part name and replace bytes.
    let existing_target = @opc.resolve_target(
      slide_name,
      existing_rels[0].target,
      existing_rels[0].target_mode,
    )
    self.replace_part_bytes(existing_target, notes_bytes, @oxml.ct_notes_slide)
    return
  }

  // Fresh notesSlide. Allocate a part name + slide-rels rId.
  let notes_name = self.next_notes_part_name()
  let new_rid = next_unused_rid(slide_rels)
  // 1. Add the notes part.
  let notes_part = @opc.Part::new(notes_name, @oxml.ct_notes_slide, notes_bytes) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(notes_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  // 2. Add notesSlideN.xml.rels — link to the notes master + back to
  //    the source slide. PowerPoint expects the notes-master rel
  //    first; we match that ordering.
  let notes_rels = @opc.Relationships::new(notes_name)
    .with_relationship({
      id: "rId1",
      rel_type: @opc.rt_notes_master,
      target: relative_target(notes_name, notes_master_name),
      target_mode: Internal,
    })
    .with_relationship({
      id: "rId2",
      rel_type: @opc.rt_slide,
      target: relative_target(notes_name, slide_name),
      target_mode: Internal,
    }) catch {
      e => raise OpcFailure(e.to_string())
    }
  self.write_rels_for_part(notes_name, notes_rels)
  // 3. Add slideN.xml.rels — append slide → notesSlide rel.
  let updated_slide_rels = slide_rels.with_relationship({
    id: new_rid,
    rel_type: @opc.rt_notes_slide,
    target: relative_target(slide_name, notes_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(slide_name, updated_slide_rels)
  // 4. Register an Override content type for the notes part.
  let ct = self.pkg
    .content_types()
    .with_override(notes_name, @oxml.ct_notes_slide)
  self.pkg.set_content_types(ct)
  self.pkg.regenerate_content_types_part() catch {
    e => raise OpcFailure(e.to_string())
  }
}

// --- notes-master synthesis ---

///|
/// Locate (or synthesise on first call) a notes-master part. Returns
/// its absolute OPC name (e.g. `/ppt/notesMasters/notesMaster1.xml`).
/// The synthesised master:
///   - lives at `/ppt/notesMasters/notesMaster1.xml`
///   - declares an Override content type
///   - has a `.rels` linking to the existing `theme1.xml` (we share
///     the deck's main theme rather than duplicating it as `theme2.xml`
///     — PowerPoint accepts this and we save a few KB)
///   - is referenced from `presentation.xml.rels`
///   - is registered in `presentation.xml`'s `<p:notesMasterIdLst>`
fn Presentation::ensure_notes_master(
  self : Presentation,
) -> String raise PptxError {
  // Already present? Reuse it.
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_notes_master {
      return p.name
    }
  }
  let notes_master_name = "/ppt/notesMasters/notesMaster1.xml"
  // 1. Add the notes-master part itself.
  let master_part = @opc.Part::new(
    notes_master_name,
    @oxml.ct_notes_master,
    @oxml.string_to_bytes(blank_notes_master_xml),
  ) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(master_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  // 2. Duplicate `theme1.xml` as `theme2.xml` for the notes master.
  //    PowerPoint Online flags the file as needing repair if the
  //    notes master shares the main theme, even though the rels
  //    structure is otherwise legal — so we pay the small (~2 KB)
  //    cost of a separate theme part to keep the file repair-clean.
  let main_theme_name = find_theme_part_name(self.pkg)
  let theme2_name = "/ppt/theme/theme2.xml"
  let main_theme_bytes = self.pkg.require_part(main_theme_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let theme2_part = @opc.Part::new(
    theme2_name,
    @oxml.ct_theme,
    main_theme_bytes.bytes,
  ) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(theme2_part) catch {
    e => raise OpcFailure(e.to_string())
  }
  // 3. notesMaster1.xml.rels → theme2.xml.
  let master_rels = @opc.Relationships::new(notes_master_name).with_relationship({
      id: "rId1",
      rel_type: @opc.rt_theme,
      target: relative_target(notes_master_name, theme2_name),
      target_mode: Internal,
    },
  ) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(notes_master_name, master_rels)
  // 4. Add Override content types for both the notes master and the
  //    duplicated theme.
  let ct = self.pkg
    .content_types()
    .with_override(notes_master_name, @oxml.ct_notes_master)
    .with_override(theme2_name, @oxml.ct_theme)
  self.pkg.set_content_types(ct)
  self.pkg.regenerate_content_types_part() catch {
    e => raise OpcFailure(e.to_string())
  }
  // 4. presentation.xml.rels → notesMaster1.xml.
  let pres_name = match self.main_document_part_name() {
    Some(n) => n
    None =>
      raise Malformed(
        "ensure_notes_master: package has no main-document relationship",
      )
  }
  let pres_rels = self.pkg.relationships_for(pres_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let nm_rid = next_unused_rid(pres_rels)
  let updated_pres_rels = pres_rels.with_relationship({
    id: nm_rid,
    rel_type: @opc.rt_notes_master,
    target: relative_target(pres_name, notes_master_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(pres_name, updated_pres_rels)
  // 5. presentation.xml: register the notes-master id list entry.
  let pres = match self.presentation_part() {
    Some(p) => p
    None =>
      raise Malformed(
        "ensure_notes_master: presentation.xml could not be parsed",
      )
  }
  // Notes-master id by convention sits above the slide-id range; use
  // a high but stable value (matches what PowerPoint emits).
  let new_pres : PresentationPart = {
    ..pres
    // The `id` field is unused for `<p:notesMasterId>` (spec defines
    // only `r:id` on this element); we leave it at 0 so round-trip
    // comparisons stay clean.
    ,
    notes_master_id: Some({ id: 0L, r_id: nm_rid }),
  }
  let new_pres_bytes = new_pres.serialize()
  self.replace_part_bytes(pres_name, new_pres_bytes, @oxml.ct_presentation)
  notes_master_name
}

///|
/// Look up the (first) theme part inside `pkg`. `Presentation::new()`
/// always emits exactly one theme part, so this returns deterministically
/// in practice; defensively returns `/ppt/theme/theme1.xml` when no
/// theme is found at all (which is malformed input).
fn find_theme_part_name(pkg : @opc.Package) -> String {
  for p in pkg.parts() {
    if p.content_type == @oxml.ct_theme {
      return p.name
    }
  }
  "/ppt/theme/theme1.xml"
}

///|
/// Minimal notes-master body. ECMA-376 §19.3.1.27 marks `<p:cSld>` +
/// `<p:clrMap>` as required; everything else (notes styles, header /
/// footer / date / slide-number placeholders) is optional. We emit
/// the absolute minimum so PowerPoint stops flagging notes slides
/// as needing repair without bloating decks that don't use notes
/// styling.
let blank_notes_master_xml : String = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
  "<p:notesMaster xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"" +
  " xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"" +
  " xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
  "<p:cSld>" +
  "<p:bg><p:bgRef idx=\"1001\"><a:schemeClr val=\"bg1\"/></p:bgRef></p:bg>" +
  "<p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/>" +
  "<a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
  "</p:spTree>" +
  "</p:cSld>" +
  "<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\"" +
  " accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\" accent4=\"accent4\"" +
  " accent5=\"accent5\" accent6=\"accent6\" hlink=\"hlink\" folHlink=\"folHlink\"/>" +
  "</p:notesMaster>"

// --- helpers ---

///|
/// Construct a `NotesSlide` whose body placeholder carries `text` as
/// a single paragraph. The minimal-but-realistic shape tree matches
/// what PowerPoint emits when you click "Add Notes" on a fresh slide
/// (a body-type placeholder at idx 1; the slide-image placeholder is
/// omitted — neither PowerPoint nor LibreOffice mind).
fn build_notes_slide(text : String) -> @notes.NotesSlide {
  let run : @slide.Run = {
    properties: @slide.RunProperties::default(),
    text,
    extension: [],
  }
  let para : @slide.Paragraph = {
    properties: @slide.ParagraphProperties::default(),
    content: [@slide.RunContent(run)],
    extension: [],
  }
  let body : @slide.TextBody = {
    body_properties: Some(@slide.BodyProperties::default()),
    list_style: Some(@slide.ListStyle::empty()),
    paragraphs: [para],
    extension: [],
  }
  let placeholder_shape : @slide.AutoShape = {
    id: 2,
    name: "Notes Placeholder 1",
    placeholder: Some({ ph_type: "body", idx: 1 }),
    transform: None,
    geometry: None,
    fill: None,
    stroke: None,
    effects: None,
    text_body: Some(body),
    hyperlink: None,
    extension: [],
  }
  {
    name: "",
    shapes: [@slide.AutoShape(placeholder_shape)],
    clr_map_override: @slide_master.MasterMapping,
    extension: [],
  }
}

///|
/// Allocate the next `/ppt/notesSlides/notesSlideN.xml` part name
/// (shared scanner: `max_part_index`).
fn Presentation::next_notes_part_name(self : Presentation) -> String {
  "/ppt/notesSlides/notesSlide" +
  (self.max_part_index("/ppt/notesSlides/notesSlide") + 1).to_string() +
  ".xml"
}
