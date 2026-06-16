// Compile-time placeholder schema — typed layout handles (roadmap v0.4 M1). ⭐
//
// Each slide layout has a fixed set of placeholders. M1 makes that set part of
// the *type*: `Presentation::add_title_slide_mut()` returns a
// `LayoutSlide[TitleSlide]`, and the placeholder accessors (`title`,
// `subtitle`, `body`) are gated by capability traits the layout marker
// implements. Accessing a placeholder the layout doesn't have — e.g. `.body()`
// on a title slide — is a *compile error*, not a runtime check.
//
// Design (Q7 resolved → hybrid):
//   * One generic builder `LayoutSlide[L]` carrying a marker value of the
//     layout type `L`, so each accessor is defined once and gated via
//     `fn[L : HasTitle] …`. Carrying the marker instance (rather than a pure
//     phantom) keeps the build warning-clean under `--deny-warn` (a bare
//     phantom param trips `unused_type_variable` / `struct_never_constructed`).
//   * Capability traits are methods on the marker returning a `PlaceholderSpec`
//     that drives both layout synthesis and the slide-side placeholder.
//   * Ergonomic per-layout named constructors (no turbofish for callers).
//   * Layout binding resolves/synthesises a real `<p:sldLayout type=…>`
//     (ensure_layout_of_type), so placeholders actually inherit geometry.
//
// The legacy index-based `add_slide_mut(layout_index)` stays unchanged.
//
// Scope: the first cut ships the layouts whose placeholder sets are
// unambiguous — TitleSlide, TitleAndContent, SectionHeader, TitleOnly, Blank.
// TwoContent / Comparison / Content+Picture-with-caption (multi-body / caption
// layouts) are a documented follow-up.

///|
/// A placeholder's kind, layout index, and geometry. Drives both the
/// synthesised layout placeholder (which carries the geometry) and the
/// slide-side placeholder the accessor appends (which inherits it).
pub(all) struct PlaceholderSpec {
  kind : @slide.PlaceholderType
  idx : Int
  position : @slide.Transform
}

// --- capability traits (methods on the layout marker) ---

///|
/// The layout's concrete `ST_SlideLayoutType`.
pub trait LayoutType {
  fn layout_type(Self) -> @slide_master.SlideLayoutType
}

///|
/// The full placeholder set this layout declares (used for synthesis).
pub trait LayoutPlaceholders {
  fn placeholders(Self) -> Array[PlaceholderSpec]
}

///|
/// Capability: this layout has a title placeholder.
pub trait HasTitle {
  fn title_spec(Self) -> PlaceholderSpec
}

///|
/// Capability: this layout has a subtitle placeholder.
pub trait HasSubtitle {
  fn subtitle_spec(Self) -> PlaceholderSpec
}

///|
/// Capability: this layout has a body / content placeholder.
pub trait HasBody {
  fn body_spec(Self) -> PlaceholderSpec
}

// --- the typed builder ---

///|
/// A slide being built on a known layout `L`. The placeholder accessors are
/// gated by `L`'s capability traits. Build with a `Presentation::add_*_mut`
/// constructor, set placeholders, then `finish_mut()`.
pub struct LayoutSlide[L] {
  prs : Presentation
  slide_name : String
  slide : @slide.Slide
  marker : L
}

///|
/// Set the title placeholder text. Available only when `L` has a title.
pub fn[L : HasTitle] LayoutSlide::title(
  self : LayoutSlide[L],
  text : String,
) -> LayoutSlide[L] {
  let spec = self.marker.title_spec()
  { ..self, slide: self.slide.with_placeholder(spec.kind, spec.idx, text~) }
}

///|
/// Set the subtitle placeholder text. Available only when `L` has a subtitle.
pub fn[L : HasSubtitle] LayoutSlide::subtitle(
  self : LayoutSlide[L],
  text : String,
) -> LayoutSlide[L] {
  let spec = self.marker.subtitle_spec()
  { ..self, slide: self.slide.with_placeholder(spec.kind, spec.idx, text~) }
}

///|
/// Set the body / content placeholder text. Available only when `L` has a body.
pub fn[L : HasBody] LayoutSlide::body(
  self : LayoutSlide[L],
  text : String,
) -> LayoutSlide[L] {
  let spec = self.marker.body_spec()
  { ..self, slide: self.slide.with_placeholder(spec.kind, spec.idx, text~) }
}

///|
/// Commit the built slide back into the deck (replacing the blank body the
/// constructor created) and return its part name.
pub fn[L] LayoutSlide::finish_mut(
  self : LayoutSlide[L],
) -> String raise PptxError {
  let bytes = self.slide.serialize() catch {
    e => raise SlideFailure(e.to_string())
  }
  self.prs.replace_part_bytes(self.slide_name, bytes, @oxml.ct_slide)
  self.slide_name
}

///|
/// Shared constructor: ensure a layout of the marker's type exists, append a
/// blank slide linked to it, and wrap it as a typed handle.
fn[L : LayoutType + LayoutPlaceholders] Presentation::add_typed_slide(
  self : Presentation,
  marker : L,
) -> LayoutSlide[L] raise PptxError {
  let layout_name = self.ensure_layout_of_type(
    marker.layout_type(),
    specs_to_defs(marker.placeholders()),
  )
  let slide_name = self.add_slide_on_layout_mut(layout_name)
  let part = self.pkg.require_part(slide_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let slide = @slide.Slide::parse(part.bytes) catch {
    e => raise SlideFailure(e.to_string())
  }
  { prs: self, slide_name, slide, marker }
}

///|
fn specs_to_defs(specs : Array[PlaceholderSpec]) -> Array[PlaceholderDef] {
  let out : Array[PlaceholderDef] = []
  for s in specs {
    out.push({ kind: s.kind, position: s.position, default_text: None })
  }
  out
}

// --- standard placeholder specs (4:3 deck geometry, ~PowerPoint defaults) ---

///|
fn emu_rect(x : Int64, y : Int64, cx : Int64, cy : Int64) -> @slide.Transform {
  @slide.Transform::new(offset={ x: @units.Emu(x), y: @units.Emu(y) }, extent={
    cx: @units.Emu(cx),
    cy: @units.Emu(cy),
  })
}

///|
fn spec_title() -> PlaceholderSpec {
  {
    kind: Title,
    idx: 0,
    position: emu_rect(838200L, 365125L, 7467600L, 1325563L),
  }
}

///|
fn spec_ctr_title() -> PlaceholderSpec {
  {
    kind: CtrTitle,
    idx: 0,
    position: emu_rect(685800L, 2130425L, 7772400L, 1470025L),
  }
}

///|
fn spec_subtitle() -> PlaceholderSpec {
  {
    kind: SubTitle,
    idx: 1,
    position: emu_rect(1371600L, 3886200L, 6400800L, 1752600L),
  }
}

///|
fn spec_body() -> PlaceholderSpec {
  {
    kind: Body,
    idx: 1,
    position: emu_rect(838200L, 1825625L, 7467600L, 4351338L),
  }
}

// --- layout markers + capability impls ---

///|
/// Title-slide layout (`type="title"`): a centered title + a subtitle.
pub struct TitleSlide {}

///|
pub impl LayoutType for TitleSlide with fn layout_type(_) {
  @slide_master.SlideLayoutType::Title
}

///|
pub impl LayoutPlaceholders for TitleSlide with fn placeholders(_) {
  [spec_ctr_title(), spec_subtitle()]
}

///|
pub impl HasTitle for TitleSlide with fn title_spec(_) {
  spec_ctr_title()
}

///|
pub impl HasSubtitle for TitleSlide with fn subtitle_spec(_) {
  spec_subtitle()
}

///|
/// Title-and-content layout (`type="obj"`): a title + a body/content area.
pub struct TitleAndContent {}

///|
pub impl LayoutType for TitleAndContent with fn layout_type(_) {
  @slide_master.SlideLayoutType::Object
}

///|
pub impl LayoutPlaceholders for TitleAndContent with fn placeholders(_) {
  [spec_title(), spec_body()]
}

///|
pub impl HasTitle for TitleAndContent with fn title_spec(_) {
  spec_title()
}

///|
pub impl HasBody for TitleAndContent with fn body_spec(_) {
  spec_body()
}

///|
/// Section-header layout (`type="secHead"`): a title + a text body.
pub struct SectionHeader {}

///|
pub impl LayoutType for SectionHeader with fn layout_type(_) {
  @slide_master.SlideLayoutType::SecHead
}

///|
pub impl LayoutPlaceholders for SectionHeader with fn placeholders(_) {
  [spec_title(), spec_body()]
}

///|
pub impl HasTitle for SectionHeader with fn title_spec(_) {
  spec_title()
}

///|
pub impl HasBody for SectionHeader with fn body_spec(_) {
  spec_body()
}

///|
/// Title-only layout (`type="titleOnly"`): just a title.
pub struct TitleOnly {}

///|
pub impl LayoutType for TitleOnly with fn layout_type(_) {
  @slide_master.SlideLayoutType::TitleOnly
}

///|
pub impl LayoutPlaceholders for TitleOnly with fn placeholders(_) {
  [spec_title()]
}

///|
pub impl HasTitle for TitleOnly with fn title_spec(_) {
  spec_title()
}

///|
/// Blank layout (`type="blank"`): no placeholders.
pub struct BlankSlide {}

///|
pub impl LayoutType for BlankSlide with fn layout_type(_) {
  @slide_master.SlideLayoutType::Blank
}

///|
pub impl LayoutPlaceholders for BlankSlide with fn placeholders(_) {
  []
}

// --- named constructors (no turbofish for callers) ---

///|
/// Add a title slide and return its typed handle (title + subtitle).
pub fn Presentation::add_title_slide_mut(
  self : Presentation,
) -> LayoutSlide[TitleSlide] raise PptxError {
  self.add_typed_slide(TitleSlide::{  })
}

///|
/// Add a title-and-content slide and return its typed handle (title + body).
pub fn Presentation::add_title_content_slide_mut(
  self : Presentation,
) -> LayoutSlide[TitleAndContent] raise PptxError {
  self.add_typed_slide(TitleAndContent::{  })
}

///|
/// Add a section-header slide and return its typed handle (title + body).
pub fn Presentation::add_section_header_slide_mut(
  self : Presentation,
) -> LayoutSlide[SectionHeader] raise PptxError {
  self.add_typed_slide(SectionHeader::{  })
}

///|
/// Add a title-only slide and return its typed handle (title).
pub fn Presentation::add_title_only_slide_mut(
  self : Presentation,
) -> LayoutSlide[TitleOnly] raise PptxError {
  self.add_typed_slide(TitleOnly::{  })
}

///|
/// Add a blank slide and return its typed handle (no placeholders).
pub fn Presentation::add_blank_typed_slide_mut(
  self : Presentation,
) -> LayoutSlide[BlankSlide] raise PptxError {
  self.add_typed_slide(BlankSlide::{  })
}
