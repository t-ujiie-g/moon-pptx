// Placeholder named accessors (roadmap v0.3 B1).
//
// The parsed `Placeholder` keeps `ph_type` as the raw `ST_PlaceholderType`
// attribute string for lossless round-trip (ADR-004) — a body/content
// placeholder commonly *omits* the `type` attribute, which the model
// preserves as `ph_type == ""` and the writer round-trips by omitting it.
// We must not collapse that distinction into the struct, so the typed lift
// lives in a non-raising `kind()` accessor on top of the raw string rather
// than in the field itself (this is the difference from how `SlideLayoutType`
// was lifted, where the root `type` attribute is effectively always present).

///|
/// Typed `ST_PlaceholderType` (ECMA-376 §19.7.10). Covers the 16 spec values;
/// `Other(String)` keeps any unrecognised value verbatim for forward
/// compatibility (mirrors `@chart_ex.ChartExKind::Other`), so `kind()` never
/// raises and round-trips even schema-extending tools.
pub(all) enum PlaceholderType {
  Title // "title"
  Body // "body"
  CtrTitle // "ctrTitle"  — centered title (title-slide layout)
  SubTitle // "subTitle"
  Dt // "dt"       — date
  SldNum // "sldNum"   — slide number
  Ftr // "ftr"      — footer
  Hdr // "hdr"      — header (notes / handout)
  Obj // "obj"      — generic object; also the spec default when absent
  Chart // "chart"
  Tbl // "tbl"
  ClipArt // "clipArt"
  Dgm // "dgm"      — diagram
  Media // "media"
  SldImg // "sldImg"   — slide image (notes)
  Pic // "pic"
  /// Any `ST_PlaceholderType` value we don't model — preserved verbatim.
  Other(String)
} derive(Eq, Debug)

///|
/// Map a raw `ST_PlaceholderType` attribute value to the typed enum. The empty
/// string (attribute absent) maps to `Obj`, the schema default. Unknown
/// non-empty values map to `Other(s)` rather than raising — `<p:ph>` is closed
/// in the schema, but tolerating extensions keeps `kind()` total.
pub fn PlaceholderType::from_xml(s : String) -> PlaceholderType {
  match s {
    "" | "obj" => Obj
    "title" => Title
    "body" => Body
    "ctrTitle" => CtrTitle
    "subTitle" => SubTitle
    "dt" => Dt
    "sldNum" => SldNum
    "ftr" => Ftr
    "hdr" => Hdr
    "chart" => Chart
    "tbl" => Tbl
    "clipArt" => ClipArt
    "dgm" => Dgm
    "media" => Media
    "sldImg" => SldImg
    "pic" => Pic
    other => Other(other)
  }
}

///|
/// Render a `PlaceholderType` back to its `ST_PlaceholderType` attribute value.
/// `Obj` renders as `"obj"`; note this is *not* the inverse of `from_xml("")`
/// — the raw `ph_type` field, not `kind()`, is what the writer serialises, so
/// an absent attribute stays absent on round-trip.
pub fn PlaceholderType::to_xml(self : PlaceholderType) -> String {
  match self {
    Title => "title"
    Body => "body"
    CtrTitle => "ctrTitle"
    SubTitle => "subTitle"
    Dt => "dt"
    SldNum => "sldNum"
    Ftr => "ftr"
    Hdr => "hdr"
    Obj => "obj"
    Chart => "chart"
    Tbl => "tbl"
    ClipArt => "clipArt"
    Dgm => "dgm"
    Media => "media"
    SldImg => "sldImg"
    Pic => "pic"
    Other(s) => s
  }
}

///|
/// The typed kind of this placeholder, derived from the raw `ph_type` string.
/// Total — an absent attribute reads as `Obj` (the spec default) and an
/// unmodelled value as `Other(...)`.
pub fn Placeholder::kind(self : Placeholder) -> PlaceholderType {
  PlaceholderType::from_xml(self.ph_type)
}

///|
/// The placeholder metadata attached to a shape, if it is a placeholder.
/// Only `AutoShape` carries placeholder metadata in the current model
/// (title / body / content / footer placeholders are all `<p:sp>`); other
/// shape kinds return `None`.
fn shape_placeholder(shape : Shape) -> Placeholder? {
  match shape {
    AutoShape(sp) => sp.placeholder
    _ => None
  }
}

///|
/// Every placeholder shape on the slide paired with its typed kind, in
/// `<p:spTree>` source order. Non-placeholder shapes are skipped.
pub fn Slide::placeholders(self : Slide) -> Array[(PlaceholderType, Shape)] {
  let out = []
  for shape in self.shapes {
    match shape_placeholder(shape) {
      Some(ph) => out.push((ph.kind(), shape))
      None => ()
    }
  }
  out
}

///|
/// The first placeholder shape matching `kind`, in source order, or `None`.
/// Matching is on the typed `kind()`, so `Obj` also matches placeholders that
/// omit the `type` attribute.
pub fn Slide::placeholder(self : Slide, kind : PlaceholderType) -> Shape? {
  for shape in self.shapes {
    match shape_placeholder(shape) {
      Some(ph) => if ph.kind() == kind { return Some(shape) }
      None => ()
    }
  }
  None
}

///|
/// The title placeholder, if present. Matches both `Title` and `CtrTitle`
/// (the centered title used by the title-slide layout), mirroring
/// python-pptx's `slide.shapes.title`.
pub fn Slide::title(self : Slide) -> Shape? {
  for shape in self.shapes {
    match shape_placeholder(shape) {
      Some(ph) =>
        match ph.kind() {
          Title | CtrTitle => return Some(shape)
          _ => ()
        }
      None => ()
    }
  }
  None
}

///|
/// The first body placeholder (`type="body"`), if present. Content
/// placeholders that omit `type` read as `Obj`, not `Body` — reach those via
/// `placeholder(Obj)`.
pub fn Slide::body(self : Slide) -> Shape? {
  self.placeholder(Body)
}

///|
/// Append a placeholder shape of `kind` with placeholder index `idx`, carrying
/// optional `text`, replacing any existing placeholder of the same kind+idx so
/// the call is idempotent. The shape has no `<a:xfrm>`, so its position and
/// size inherit from the matching placeholder on the slide's layout (the OOXML
/// cascade) — it renders only when the layout declares a placeholder of that
/// kind+idx. Generalises `with_footer` / `with_date` / `with_slide_number`,
/// and is the building block for the typed layout handles (roadmap M1).
pub fn Slide::with_placeholder(
  self : Slide,
  kind : PlaceholderType,
  idx : Int,
  text? : String,
) -> Slide {
  let kept : Array[Shape] = []
  for s in self.shapes {
    let drop = match s {
      AutoShape(a) =>
        match a.placeholder {
          Some(ph) => ph.kind() == kind && ph.idx == idx
          None => false
        }
      _ => false
    }
    if !drop {
      kept.push(s)
    }
  }
  let cleared = { ..self, shapes: kept }
  let body : TextBody? = match text {
    Some(t) => Some(TextBody::of_text(t))
    None => None
  }
  let sp : AutoShape = {
    id: cleared.next_shape_id(),
    name: kind.to_xml() + " Placeholder",
    placeholder: Some({ ph_type: kind.to_xml(), idx }),
    transform: None,
    geometry: None,
    fill: None,
    stroke: None,
    effects: None,
    text_body: body,
    extension: [],
  }
  cleared.with_shape(AutoShape(sp))
}
