// High-level Presentation façade.
//
// Wraps an `@opc.Package` and surfaces typed views of its OOXML parts
// without forcing callers to know about content types, part naming
// conventions, or relationship traversal. The façade is lazy: every
// accessor parses on demand from the current package bytes, so the
// `Presentation` value itself stays cheap to construct and copy.
//
// Read side: `open(bytes)` → `save()` round-trips the package
// verbatim; typed accessors (`slides()` / `slide_masters()` / …) let
// callers inspect the parsed model. Build side: `Presentation::new`
// produces an empty deck; `add_slide_mut` / `update_slide_mut` /
// `with_added_slide` / `with_slide_updated` provide mutating and
// immutable variants of the basic edit operations.

///|
/// A parsed PPTX presentation. The wrapped `@opc.Package` is the
/// source of truth for byte-level state; typed accessors re-parse on
/// demand. Treat the value as conceptually immutable — `save()`
/// serialises a snapshot, and immutable mutation APIs return a new
/// `Presentation` rather than modify in place.
///
/// - `pkg` — The OPC package backing this presentation. Public so consumers
///   who need raw part access can drop down without waiting for a typed
///   wrapper. Named `pkg` because `package` is a reserved keyword in MoonBit.
/// - `slide_order` — internal memo, not part of the API: the slide part
///   names in `<p:sldIdLst>` order, together with the `presentation.xml`
///   and `.rels` byte arrays they were derived from. Reused only while
///   both are still those same objects, so any rewrite drops it without
///   anything having to say so. Visible only because the struct is `pub`.
pub struct Presentation {
  pkg : @opc.Package
  mut slide_order : (FixedArray[Byte], FixedArray[Byte], Array[String])?
}

///|
/// Open a PPTX from raw bytes. Delegates to `@opc.Package::open` and
/// re-wraps the result; no typed parsing happens here, so an OPC-
/// valid package whose OOXML parts are malformed still opens — those
/// errors surface on the per-part accessors.
pub fn Presentation::open(
  bytes : FixedArray[Byte],
) -> Presentation raise PptxError {
  let pkg = @opc.Package::open(bytes) catch {
    e => raise OpcFailure(e.to_string())
  }
  { pkg, slide_order: None, }
}

///|
/// Construct an empty PPTX from scratch: one theme + one slide
/// master + one (Blank) slide layout + no slides. The resulting
/// package has every required structural part wired with valid
/// relationships, so `save() → open()` round-trips cleanly and the
/// produced bytes are accepted by PowerPoint / LibreOffice.
///
/// Use this as the starting point for builder-style construction:
///   let prs = Presentation::new()
///   //   prs.add_slide_mut(layout_index=0) → rId of the new slide
///   prs.save()
pub fn Presentation::new() -> Presentation raise PptxError {
  let parts : Array[(String, String, String)] = [
    ("/ppt/presentation.xml", @oxml.ct_presentation, blank_presentation_xml),
    ("/ppt/theme/theme1.xml", @oxml.ct_theme, blank_theme_xml),
    (
      "/ppt/slideMasters/slideMaster1.xml", @oxml.ct_slide_master, blank_slide_master_xml,
    ),
    (
      "/ppt/slideLayouts/slideLayout1.xml", @oxml.ct_slide_layout, blank_slide_layout_xml,
    ),
    // The next four parts are required by ECMA-376 Part 1 §13.3.6
    // for PowerPoint to accept the file without a "repair" prompt.
    ("/ppt/presProps.xml", @oxml.ct_pres_props, blank_pres_props_xml),
    ("/ppt/viewProps.xml", @oxml.ct_view_props, blank_view_props_xml),
    ("/ppt/tableStyles.xml", @oxml.ct_table_styles, blank_table_styles_xml),
    ("/docProps/core.xml", @oxml.ct_core_properties, blank_core_props_xml),
    ("/docProps/app.xml", @oxml.ct_extended_properties, blank_app_props_xml),
  ]
  let rels : Array[(String, String)] = [
    ("/_rels/.rels", blank_pkg_rels_xml),
    ("/ppt/_rels/presentation.xml.rels", blank_presentation_rels_xml),
    (
      "/ppt/slideMasters/_rels/slideMaster1.xml.rels", blank_slide_master_rels_xml,
    ),
    (
      "/ppt/slideLayouts/_rels/slideLayout1.xml.rels", blank_slide_layout_rels_xml,
    ),
  ]
  let bytes = build_blank_package_bytes(parts, rels) catch {
    e => raise OpcFailure(e.to_string())
  }
  Presentation::open(bytes)
}

///|
/// Serialise the presentation back to PPTX bytes. The current
/// implementation is a pass-through of `Package::to_bytes`, so any
/// part mutations callers made via the lower-level `@opc` API are
/// included; typed model edits via `update_slide_mut` /
/// `with_slide_updated` re-encode the affected parts before saving.
pub fn Presentation::save(self : Presentation) -> FixedArray[Byte] {
  self.pkg.to_bytes()
}

// --- typed accessors ---

///|
/// Parsed slides in the order declared by `<p:sldIdLst>` in
/// `presentation.xml`. Falls back to package storage order if the
/// presentation part is absent or malformed — that path only fires
/// on edge cases since well-formed PPTX always carries a
/// `presentation.xml` with at least one slide ID entry.
pub fn Presentation::slides(
  self : Presentation,
) -> Array[@slide.Slide] raise PptxError {
  let ordered_parts = self.ordered_slide_parts()
  let out : Array[@slide.Slide] = []
  for p in ordered_parts {
    let s = @slide.Slide::parse(p.bytes) catch {
      e => raise SlideFailure(p.name + ": " + e.to_string())
    }
    out.push(s)
  }
  out
}

///|
/// The slide at `index` in `<p:sldIdLst>` order, parsed on its own.
///
/// `slides()` parses every slide in the deck, so reaching for one by
/// index inside a loop re-parses the whole deck each time round. This
/// parses exactly the one asked for. Raises `Malformed` if `index` is out
/// of range.
pub fn Presentation::slide_at(
  self : Presentation,
  index : Int,
) -> @slide.Slide raise PptxError {
  let names = self.ordered_slide_part_names()
  if index < 0 || index >= names.length() {
    raise Malformed("slide index " + index.to_string() + " is out of range")
  }
  let name = names[index]
  let part = self.pkg.require_part(name) catch {
    e => raise OpcFailure(e.to_string())
  }
  @slide.Slide::parse(part.bytes) catch {
    e => raise SlideFailure(name + ": " + e.to_string())
  }
}

///|
/// How many slides the deck has, without parsing any of them.
pub fn Presentation::slide_count(self : Presentation) -> Int raise PptxError {
  self.ordered_slide_part_names().length()
}

///|
/// Resolve the slide parts in `<p:sldIdLst>` order. Falls back to
/// scanning by content-type *only* when the package doesn't expose a
/// main-document relationship at all; once we find one, any further
/// failure (missing presentation part, malformed XML, broken rId) is
/// raised so callers see the real problem instead of silently
/// dropping back to source order.
fn Presentation::ordered_slide_parts(
  self : Presentation,
) -> Array[@opc.Part] raise PptxError {
  let names = self.ordered_slide_part_names()
  let out : Array[@opc.Part] = Array::new(capacity=names.length())
  for n in names {
    match self.pkg.part_by_name(n) {
      Some(p) => out.push(p)
      None => raise Malformed("presentation.xml references missing slide " + n)
    }
  }
  out
}

///|
/// The slide part *names* in `<p:sldIdLst>` order.
///
/// Memoised, because resolving the order means parsing `presentation.xml`
/// and its `.rels` — both of which grow with the deck — and callers do it
/// once per mutation. The memo validates itself: the order is a pure
/// function of those two byte arrays, so the cache is reused only while
/// both are the *same objects* it was computed from. Every write goes
/// through a fresh `FixedArray[Byte]`, so adding, removing or reordering a
/// slide invalidates it with no bookkeeping at the ~25 sites that mutate
/// the package (ROADMAP.md G13).
fn Presentation::ordered_slide_part_names(
  self : Presentation,
) -> Array[String] raise PptxError {
  let main_part_name = match self.main_document_part_name() {
    Some(n) => n
    None => {
      let out : Array[String] = []
      for p in self.fallback_slide_parts_in_package_order() {
        out.push(p.name)
      }
      return out
    }
  }
  let part = self.pkg.require_part(main_part_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let rels_bytes = match
    self.pkg.part_by_name(@opc.rels_path_for(main_part_name)) {
    Some(p) => Some(p.bytes)
    None => None
  }
  if self.slide_order is Some((pres_bytes, cached_rels, names)) &&
    rels_bytes is Some(rb) &&
    physical_equal(pres_bytes, part.bytes) &&
    physical_equal(cached_rels, rb) {
    return names
  }
  let pres = PresentationPart::parse(part.bytes)
  let rels = self.pkg.relationships_for(main_part_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let names : Array[String] = Array::new(capacity=pres.sld_ids.length())
  for s in pres.sld_ids {
    let rel = match rels.by_id(s.r_id) {
      Some(r) => r
      None =>
        raise Malformed(
          "presentation.xml sldId " + s.r_id + " has no relationship",
        )
    }
    names.push(@opc.resolve_target(main_part_name, rel.target, rel.target_mode))
  }
  if rels_bytes is Some(rb) {
    self.slide_order = Some((part.bytes, rb, names))
  }
  names
}

///|
/// Look up the relationship target of the package-level
/// `/_rels/.rels` entry whose type is `…/officeDocument`. Returns
/// `None` if the package doesn't have one — that's malformed PPTX
/// but cheap to handle gracefully.
fn Presentation::main_document_part_name(self : Presentation) -> String? {
  let rels = self.pkg.relationships_for("/") catch { _ => return None }
  let matches = rels.by_type(@opc.rt_office_document)
  if matches.is_empty() {
    return None
  }
  let rel = matches[0]
  Some(@opc.resolve_target("/", rel.target, rel.target_mode))
}

///|
fn Presentation::fallback_slide_parts_in_package_order(
  self : Presentation,
) -> Array[@opc.Part] {
  let out : Array[@opc.Part] = []
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_slide {
      out.push(p)
    }
  }
  out
}

///|
/// Parsed presentation.xml metadata. Returns `None` for packages
/// without a main-document part (malformed PPTX).
pub fn Presentation::presentation_part(
  self : Presentation,
) -> PresentationPart? raise PptxError {
  match self.main_document_part_name() {
    Some(name) => {
      let part = self.pkg.require_part(name) catch {
        e => raise OpcFailure(e.to_string())
      }
      Some(PresentationPart::parse(part.bytes))
    }
    None => None
  }
}

///|
/// Parsed theme parts. PowerPoint conventionally ships one theme per
/// slide master; both are surfaced verbatim here so callers can pick
/// the one they want by index.
pub fn Presentation::themes(
  self : Presentation,
) -> Array[@theme.Theme] raise PptxError {
  let out : Array[@theme.Theme] = []
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_theme {
      let t = @theme.Theme::parse(p.bytes) catch {
        e => raise ThemeFailure(p.name + ": " + e.to_string())
      }
      out.push(t)
    }
  }
  out
}

///|
/// Parsed slide-master parts in package order.
pub fn Presentation::slide_masters(
  self : Presentation,
) -> Array[@slide_master.SlideMaster] raise PptxError {
  let out : Array[@slide_master.SlideMaster] = []
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_slide_master {
      let m = @slide_master.SlideMaster::parse(p.bytes) catch {
        e => raise SlideMasterFailure(p.name + ": " + e.to_string())
      }
      out.push(m)
    }
  }
  out
}

///|
/// Parsed slide-layout parts in package order.
pub fn Presentation::slide_layouts(
  self : Presentation,
) -> Array[@slide_master.SlideLayout] raise PptxError {
  let out : Array[@slide_master.SlideLayout] = []
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_slide_layout {
      let l = @slide_master.SlideLayout::parse(p.bytes) catch {
        e => raise SlideMasterFailure(p.name + ": " + e.to_string())
      }
      out.push(l)
    }
  }
  out
}

///|
/// Parsed notes-slide parts in package order. Returns an empty array
/// for decks without speaker notes (which is most of them).
pub fn Presentation::notes_slides(
  self : Presentation,
) -> Array[@notes.NotesSlide] raise PptxError {
  let out : Array[@notes.NotesSlide] = []
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_notes_slide {
      let n = @notes.NotesSlide::parse(p.bytes) catch {
        e => raise NotesFailure(p.name + ": " + e.to_string())
      }
      out.push(n)
    }
  }
  out
}

///|
/// Parsed `commentAuthors.xml`, if present. PPTX packages with no
/// review comments omit the part entirely; this method returns `None`
/// for that case.
pub fn Presentation::comment_authors(
  self : Presentation,
) -> @comments.CommentAuthorList? raise PptxError {
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_comment_authors {
      let cl = @comments.CommentAuthorList::parse(p.bytes) catch {
        e => raise CommentsFailure(p.name + ": " + e.to_string())
      }
      return Some(cl)
    }
  }
  None
}

///|
/// Parsed `commentsN.xml` parts in package order. Cross-reference
/// each `Comment.author_id` against `comment_authors()` to resolve
/// who said what.
pub fn Presentation::comment_lists(
  self : Presentation,
) -> Array[@comments.CommentList] raise PptxError {
  let out : Array[@comments.CommentList] = []
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_comments {
      let cl = @comments.CommentList::parse(p.bytes) catch {
        e => raise CommentsFailure(p.name + ": " + e.to_string())
      }
      out.push(cl)
    }
  }
  out
}

///|
/// Parsed chart parts (`/ppt/charts/chartN.xml`) in package order.
/// Returns an empty array for decks without charts. Cross-reference
/// each `Shape::GraphicFrame(GraphicFrameContent::ChartContent(rid))`
/// against the slide's relationships to map a slide-side chart shape
/// back to its chart part — `rid` resolves through
/// `@opc.Package::relationships_for("ppt/slides/slideN.xml")`.
pub fn Presentation::charts(
  self : Presentation,
) -> Array[@chart.Chart] raise PptxError {
  let out : Array[@chart.Chart] = []
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_chart {
      let c = @chart.Chart::parse(p.bytes) catch {
        e => raise ChartFailure(p.name + ": " + e.to_string())
      }
      out.push(c)
    }
  }
  out
}

///|
/// Parsed extended-chart parts (`/ppt/charts/chartExN.xml`) in
/// package order — the Microsoft 2016 chart families (waterfall,
/// treemap, sunburst, histogram, boxWhisker, funnel, paretoLine,
/// regionMap, clusteredColumn). Distinct from `charts()` because
/// extended charts use a separate schema, content type, and
/// graphic-data URI.
pub fn Presentation::charts_ex(
  self : Presentation,
) -> Array[@chart_ex.ChartEx] raise PptxError {
  let out : Array[@chart_ex.ChartEx] = []
  for p in self.pkg.parts() {
    if p.content_type == @oxml.ct_chart_ex {
      let c = @chart_ex.ChartEx::parse(p.bytes) catch {
        e => raise ChartExFailure(p.name + ": " + e.to_string())
      }
      out.push(c)
    }
  }
  out
}
