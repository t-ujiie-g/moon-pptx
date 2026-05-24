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
