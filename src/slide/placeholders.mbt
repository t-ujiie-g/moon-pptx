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
