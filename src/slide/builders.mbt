// Shape and slide builders.
//
// Hand-friendly constructors that produce well-formed model values
// from minimal inputs. The result is the same shape (no pun intended)
// the parser would produce for a hand-written XML fixture, so every
// builder output flows through the existing writers without any
// special-case logic.
//
// Immutable `Slide::with_shape` returns a new `Slide` with one more
// shape appended; the underlying `shapes` array is copied so callers
// don't see structural sharing.

// --- TextBody / Paragraph constructors ---

///|
/// One paragraph carrying a single plain-text run with default
/// formatting. Used as the building block for `TextBody::of_text`
/// and any other "I just need text" path.
pub fn Paragraph::of_text(text : String) -> Paragraph {
  let run : Run = { properties: RunProperties::default(), text, extension: [] }
  {
    properties: ParagraphProperties::default(),
    content: [RunContent(run)],
    extension: [],
  }
}

///|
/// One paragraph carrying a single run of styled text. The run picks
/// up the supplied properties; the paragraph itself uses default
/// alignment / indentation.
pub fn Paragraph::of_styled_text(
  text : String,
  run_properties : RunProperties,
) -> Paragraph {
  let run : Run = { properties: run_properties, text, extension: [] }
  {
    properties: ParagraphProperties::default(),
    content: [RunContent(run)],
    extension: [],
  }
}

///|
/// Replace the paragraph-level properties (alignment, indentation,
/// spacing, bullet) on a paragraph. Returns a new value; the
/// original paragraph is unchanged.
pub fn Paragraph::with_properties(
  self : Paragraph,
  properties : ParagraphProperties,
) -> Paragraph {
  { ..self, properties, }
}

///|
/// Replace the alignment of a paragraph. Convenience over
/// `with_properties` for the common case.
pub fn Paragraph::with_alignment(
  self : Paragraph,
  align : TextAlignment,
) -> Paragraph {
  { ..self, properties: { ..self.properties, alignment: Some(align) } }
}

///|
/// `TextBody` containing one paragraph of plain text plus default
/// body properties and an empty list style. The default body
/// properties don't carry any rotation / anchor / insets — those
/// inherit from the layout / master per OOXML's cascade.
pub fn TextBody::of_text(text : String) -> TextBody {
  {
    body_properties: Some(BodyProperties::default()),
    list_style: Some(ListStyle::empty()),
    paragraphs: [Paragraph::of_text(text)],
    extension: [],
  }
}

///|
/// `TextBody` containing one paragraph of styled text. Same defaults
/// as `of_text` for the body / list-style wrappers; the styling sits
/// on the run.
pub fn TextBody::of_styled_text(
  text : String,
  run_properties : RunProperties,
) -> TextBody {
  {
    body_properties: Some(BodyProperties::default()),
    list_style: Some(ListStyle::empty()),
    paragraphs: [Paragraph::of_styled_text(text, run_properties)],
    extension: [],
  }
}

///|
/// `TextBody` of multiple paragraphs. Each entry becomes one
/// paragraph; styling is uniform across paragraphs.
pub fn TextBody::of_paragraphs(paragraphs : Array[Paragraph]) -> TextBody {
  {
    body_properties: Some(BodyProperties::default()),
    list_style: Some(ListStyle::empty()),
    paragraphs,
    extension: [],
  }
}

// --- RunProperties fluent builders -----------------------------------------

///|
/// Set the font size (in points).
pub fn RunProperties::with_font_size(
  self : RunProperties,
  pt : @units.Pt,
) -> RunProperties {
  { ..self, font_size: Some(pt) }
}

///|
/// Set the character (letter) spacing / tracking, in points — the `spc`
/// attribute on `<a:rPr>`. May be negative to tighten (e.g. `@units.Pt(-0.5)`).
pub fn RunProperties::with_character_spacing(
  self : RunProperties,
  pt : @units.Pt,
) -> RunProperties {
  { ..self, character_spacing: Some(pt) }
}

///|
/// Mark the run as bold.
pub fn RunProperties::with_bold(self : RunProperties) -> RunProperties {
  { ..self, bold: Some(true) }
}

///|
/// Mark the run as italic.
pub fn RunProperties::with_italic(self : RunProperties) -> RunProperties {
  { ..self, italic: Some(true) }
}

///|
/// Set the run's solid colour from an RGB triple.
pub fn RunProperties::with_color(
  self : RunProperties,
  rgb : @units.RgbColor,
) -> RunProperties {
  { ..self, fill: Some(@oxml.Color::srgb(rgb)) }
}

///|
/// Set the Latin-script typeface (e.g. `"Calibri"`, `"Arial"`).
pub fn RunProperties::with_font(
  self : RunProperties,
  font_name : String,
) -> RunProperties {
  { ..self, latin: Some(font_name) }
}

///|
/// Attach an external hyperlink to this run. The URL is stored
/// **unresolved** in `hyperlink_target`; `Presentation::update_slide_mut`
/// allocates the slide-rels rId and writes the final
/// `<a:hlinkClick r:id="…"/>` at serialisation time.
///
/// Pass an empty `tooltip` (the default) to omit the attribute.
pub fn RunProperties::with_hyperlink(
  self : RunProperties,
  url : String,
  tooltip? : String = "",
) -> RunProperties {
  let tt : String? = if tooltip.length() > 0 { Some(tooltip) } else { None }
  {
    ..self,
    hyperlink_target: Some(ExternalUrl(url)),
    hyperlink_click: None,
    hyperlink_tooltip: tt,
  }
}

///|
/// Attach an internal hyperlink that jumps to slide `slide_idx`
/// (zero-based, as in `Presentation::slides()`). The rId + slide
/// relationship are allocated by `Presentation::update_slide_mut`
/// at serialisation time.
pub fn RunProperties::with_hyperlink_to_slide(
  self : RunProperties,
  slide_idx : Int,
  tooltip? : String = "",
) -> RunProperties {
  let tt : String? = if tooltip.length() > 0 { Some(tooltip) } else { None }
  {
    ..self,
    hyperlink_target: Some(InternalSlide(slide_idx)),
    hyperlink_click: None,
    hyperlink_tooltip: tt,
  }
}

// --- AutoShape constructors ---

///|
/// Construct an `AutoShape` with the given preset geometry,
/// transform, and no fill / stroke / effects / text. Users typically
/// reach for the per-preset helpers (`rect` / `ellipse` /
/// `round_rect` / `textbox`) rather than this — those apply visible
/// defaults so PowerPoint actually renders the shape. `of_preset`
/// remains the lowest-level builder for callers that want to start
/// from zero and layer their own styling.
pub fn AutoShape::of_preset(
  id : Int,
  name : String,
  preset : PresetShape,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> AutoShape {
  {
    id,
    name,
    placeholder: None,
    transform: Some({ offset: { x, y }, extent: { cx, cy } }),
    geometry: Some(Preset(preset, [])),
    fill: None,
    stroke: None,
    effects: None,
    text_body: None,
    extension: [],
  }
}

///|
/// Default fill used by `rect` / `ellipse` / `round_rect` so the
/// shape is actually visible in PowerPoint / LibreOffice. A
/// non-placeholder shape with no `<a:solidFill>` (or any fill
/// choice) renders fully transparent.
fn default_shape_fill() -> @oxml.Fill {
  @oxml.SolidFill(@oxml.Color::srgb(@units.RgbColor::new(0xDD, 0xE3, 0xEE)))
}

///|
/// Default 1-point dark line so shapes have a visible outline.
fn default_shape_stroke() -> @oxml.Stroke {
  {
    width: Some(@units.Emu(12_700L)), // 1 pt
    cap: None,
    compound: None,
    alignment: None,
    fill: Some(
      @oxml.SolidFill(@oxml.Color::srgb(@units.RgbColor::new(0x44, 0x55, 0x66))),
    ),
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
}

///|
/// Rectangle shape with the canonical `prst="rect"` preset, the
/// given placement, and visible default fill + 1pt outline.
pub fn AutoShape::rect(
  id : Int,
  name : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> AutoShape {
  let s = AutoShape::of_preset(id, name, PresetShape::Rect, x, y, cx, cy)
  {
    ..s,
    fill: Some(default_shape_fill()),
    stroke: Some(default_shape_stroke()),
  }
}

///|
/// Ellipse shape (`prst="ellipse"`) with visible default fill + outline.
pub fn AutoShape::ellipse(
  id : Int,
  name : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> AutoShape {
  let s = AutoShape::of_preset(id, name, PresetShape::Ellipse, x, y, cx, cy)
  {
    ..s,
    fill: Some(default_shape_fill()),
    stroke: Some(default_shape_stroke()),
  }
}

///|
/// Rounded-rectangle (`prst="roundRect"`) with visible default
/// fill + outline.
pub fn AutoShape::round_rect(
  id : Int,
  name : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> AutoShape {
  let s = AutoShape::of_preset(id, name, PresetShape::RoundRect, x, y, cx, cy)
  {
    ..s,
    fill: Some(default_shape_fill()),
    stroke: Some(default_shape_stroke()),
  }
}

///|
/// Text box — a rectangle with text content. Unlike the geometric
/// builders this leaves `fill` and `stroke` as `None` so the box
/// renders as plain text without a background or border (matching
/// the typical "TextBox" tool in PowerPoint).
pub fn AutoShape::textbox(
  id : Int,
  name : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
  text : String,
) -> AutoShape {
  let s = AutoShape::of_preset(id, name, PresetShape::Rect, x, y, cx, cy)
  { ..s, text_body: Some(TextBody::of_text(text)) }
}

// --- AutoShape fluent setters ----------------------------------------------

///|
/// Replace the fill of an existing `AutoShape`. Returns a new
/// value; the original is unchanged.
pub fn AutoShape::with_fill(self : AutoShape, fill : @oxml.Fill) -> AutoShape {
  { ..self, fill: Some(fill) }
}

///|
/// Mark the shape as transparent — explicitly emits `<a:noFill/>`
/// instead of relying on placeholder / theme inheritance. Useful on
/// top of the geometric builders to opt out of their default fill.
pub fn AutoShape::with_no_fill(self : AutoShape) -> AutoShape {
  { ..self, fill: Some(@oxml.NoFill) }
}

///|
/// Replace the outline (`<a:ln>`) of an existing `AutoShape`.
pub fn AutoShape::with_stroke(
  self : AutoShape,
  stroke : @oxml.Stroke,
) -> AutoShape {
  { ..self, stroke: Some(stroke) }
}

///|
/// Drop the outline — emits no `<a:ln>` so the shape inherits its
/// border from the layout / theme (typically: none).
pub fn AutoShape::with_no_stroke(self : AutoShape) -> AutoShape {
  { ..self, stroke: None }
}

///|
/// Replace the text body of an existing `AutoShape`. Pairs with
/// `TextBody::of_styled_text` for terse styled-text construction:
///
///   AutoShape::rect(1, "Card", x, y, w, h)
///     .with_fill(@oxml.SolidFill(@oxml.Color::srgb(navy)))
///     .with_text_body(
///       TextBody::of_styled_text(
///         "Header",
///         RunProperties::default()
///           .with_font_size(@units.Pt(28.0))
///           .with_bold()
///           .with_color(white),
///       ),
///     )
pub fn AutoShape::with_text_body(
  self : AutoShape,
  body : TextBody,
) -> AutoShape {
  { ..self, text_body: Some(body) }
}

// --- Picture builder -------------------------------------------------------

///|
/// Construct a `Picture` shape that embeds the image part referenced
/// by `embed_id`. The actual image bytes have to be added to the OPC
/// package separately — `@presentation.Presentation::add_picture_mut`
/// handles the full pipeline (bytes → media part → relationship →
/// `Picture` shape → slide append).
///
/// `name` is the user-visible shape name (`p:cNvPr` `name` attribute).
/// `embed_id` is the `r:embed` relationship id pointing at the
/// image media part.
///
/// The picture renders as a stretched fit (`<a:stretch><a:fillRect/></a:stretch>`)
/// inside a plain `prst="rect"` boundary — the standard "insert
/// picture" result PowerPoint produces.
pub fn Picture::of_image(
  id : Int,
  name : String,
  embed_id : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Picture {
  {
    id,
    name,
    transform: Some({ offset: { x, y }, extent: { cx, cy } }),
    geometry: Some(Preset(PresetShape::Rect, [])),
    stroke: None,
    effects: None,
    blip_fill: {
      embed_id,
      link_id: "",
      src_rect: None,
      fill_mode: Stretch(None),
      extension: [],
    },
    media: None,
    extension: [],
  }
}

///|
/// Construct an SVG `Picture` shape. `png_embed_id` is the `r:embed` of
/// the raster fallback part (rendered by viewers that don't understand
/// SVG); `svg_embed_id` is the `r:embed` of the SVG part. Both relationship
/// ids and both media parts must be added to the OPC package separately —
/// `@presentation.Presentation::add_svg_picture_mut` runs the full pipeline.
///
/// The blip embeds the raster fallback and carries an `<asvg:svgBlip>`
/// extension pointing at the SVG (roadmap C4); otherwise identical to
/// `Picture::of_image` (stretched fit inside a `prst="rect"` boundary).
pub fn Picture::of_svg_image(
  id : Int,
  name : String,
  png_embed_id : String,
  svg_embed_id : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Picture {
  {
    id,
    name,
    transform: Some({ offset: { x, y }, extent: { cx, cy } }),
    geometry: Some(Preset(PresetShape::Rect, [])),
    stroke: None,
    effects: None,
    blip_fill: @oxml.BlipFill::svg(png_embed_id, svg_embed_id),
    media: None,
    extension: [],
  }
}

///|
/// Crop the picture by setting its `<a:srcRect>` to `(l, t, r, b)`
/// percentages off each edge of the source image. Replaces any
/// existing crop — the call is idempotent rather than additive.
///
/// Each value is in percent (e.g. `Percentage(10.0)` = 10 %). A
/// 0 % crop on every edge is the same as no crop.
pub fn Picture::with_crop(
  self : Picture,
  left? : @units.Percentage = @units.Percentage(0.0),
  top? : @units.Percentage = @units.Percentage(0.0),
  right? : @units.Percentage = @units.Percentage(0.0),
  bottom? : @units.Percentage = @units.Percentage(0.0),
) -> Picture {
  let rect : @oxml.SrcRect = { left, top, right, bottom }
  { ..self, blip_fill: { ..self.blip_fill, src_rect: Some(rect) } }
}

// --- Slide::with_shape ---

///|
/// Return a new `Slide` whose `shapes` is the original list with
/// `shape` appended. The shapes array is copied — mutations on the
/// returned slide don't affect the original.
pub fn Slide::with_shape(self : Slide, shape : Shape) -> Slide {
  let new_shapes : Array[Shape] = []
  for s in self.shapes {
    new_shapes.push(s)
  }
  new_shapes.push(shape)
  { ..self, shapes: new_shapes }
}
