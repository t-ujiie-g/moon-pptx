// Slide date / footer / slide-number placeholders.
//
// These append the slide-level placeholder shapes PowerPoint fills from the
// master / layout: `<p:ph type="dt"/"ftr"/"sldNum">`. They render only when
// the master declares matching placeholders — pair with `define_master`
// and `MasterDefinition.slide_number` / `footer_text`. The shapes carry
// no `<a:xfrm>`, so position / size inherit from the master placeholder of
// the same type (the OOXML cascade).

///|
/// How a date placeholder is filled. `Auto` emits an updating
/// `<a:fld type="datetime1">`; `Fixed` emits literal text.
pub(all) enum DateMode {
  Auto
  Fixed(String)
} derive(Eq, Debug)

///|
/// Conventional slide-level placeholder indices, matching PowerPoint's own
/// output: date = 10, footer = 11, slide number = 12.
let ph_idx_date : Int = 10

///|
let ph_idx_footer : Int = 11

///|
let ph_idx_slide_number : Int = 12

///|
/// A fixed `<a:fld>` id. PowerPoint regenerates it on edit; a stable GUID
/// keeps our output deterministic.
let placeholder_field_id : String = "{1F3B9E54-0000-4000-8000-000000000001}"

///|
/// A `TextBody` holding a single `<a:fld>` field of the given type.
fn field_text_body(field_type : String, cached : String) -> TextBody {
  let fld : Field = {
    id: placeholder_field_id,
    field_type,
    properties: RunProperties::default(),
    text: cached,
    extension: [],
  }
  {
    body_properties: Some(BodyProperties::default()),
    list_style: Some(ListStyle::empty()),
    paragraphs: [
      {
        properties: ParagraphProperties::default(),
        content: [FieldContent(fld)],
        extension: [],
      },
    ],
    extension: [],
  }
}

///|
/// Build a slide-level placeholder `<p:sp>` with no transform (position
/// inherited from the master) carrying `body`.
fn placeholder_shape(
  id : Int,
  name : String,
  ph_type : String,
  idx : Int,
  body : TextBody,
) -> AutoShape {
  {
    id,
    name,
    placeholder: Some({ ph_type, idx }),
    transform: None,
    geometry: None,
    fill: None,
    stroke: None,
    effects: None,
    text_body: Some(body),
    hyperlink: None,
    extension: [],
  }
}

///|
/// Next free shape id on the slide (max existing + 1, floor 2 — id 1 is the
/// implicit root group).
fn Slide::next_shape_id(self : Slide) -> Int {
  let mut max = 1
  for s in self.shapes {
    match s.id() {
      Some(i) => if i > max { max = i }
      None => ()
    }
  }
  max + 1
}

///|
/// Drop every placeholder shape of `kind` (keeps everything else), so the
/// header/footer builders are idempotent — calling one twice replaces rather
/// than duplicates.
fn Slide::without_placeholder_kind(
  self : Slide,
  kind : PlaceholderType,
) -> Slide {
  let kept : Array[Shape] = []
  for s in self.shapes {
    let drop = match s {
      AutoShape(a) =>
        match a.placeholder {
          Some(ph) => ph.kind() == kind
          None => false
        }
      _ => false
    }
    if !drop {
      kept.push(s)
    }
  }
  { ..self, shapes: kept }
}

///|
/// Return a new `Slide` with a slide-number placeholder (`<p:ph
/// type="sldNum">` + a `slidenum` field) when `visible`, or with any
/// existing slide-number placeholder removed when not. Renders only if the
/// master declares a `sldNum` placeholder (see `MasterDefinition`).
pub fn Slide::with_slide_number(self : Slide, visible : Bool) -> Slide {
  let cleared = self.without_placeholder_kind(SldNum)
  if visible {
    let body = field_text_body("slidenum", "1")
    let sp = placeholder_shape(
      cleared.next_shape_id(),
      "Slide Number Placeholder",
      "sldNum",
      ph_idx_slide_number,
      body,
    )
    cleared.with_shape(AutoShape(sp))
  } else {
    cleared
  }
}

///|
/// Return a new `Slide` carrying a footer placeholder (`<p:ph type="ftr">`)
/// with the given text. Replaces any existing footer placeholder.
pub fn Slide::with_footer(self : Slide, text : String) -> Slide {
  let cleared = self.without_placeholder_kind(Ftr)
  let sp = placeholder_shape(
    cleared.next_shape_id(),
    "Footer Placeholder",
    "ftr",
    ph_idx_footer,
    TextBody::of_text(text),
  )
  cleared.with_shape(AutoShape(sp))
}

///|
/// Return a new `Slide` carrying a date placeholder (`<p:ph type="dt">`).
/// `Auto` inserts an updating date field; `Fixed(text)` inserts literal
/// text. Replaces any existing date placeholder.
pub fn Slide::with_date(self : Slide, mode : DateMode) -> Slide {
  let cleared = self.without_placeholder_kind(Dt)
  let body = match mode {
    Auto => field_text_body("datetime1", "")
    Fixed(text) => TextBody::of_text(text)
  }
  let sp = placeholder_shape(
    cleared.next_shape_id(),
    "Date Placeholder",
    "dt",
    ph_idx_date,
    body,
  )
  cleared.with_shape(AutoShape(sp))
}
