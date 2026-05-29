// Pinpoint shape editing (roadmap v0.3 B4).
//
// The base mutation API is append-only (`Slide::with_shape`) + whole-slide
// replace (`@presentation.update_slide_mut`). These helpers close the gap:
// locate an *existing* shape (by position, by stable id, or via the B1
// placeholder accessors) and overwrite it in place, all without rebuilding
// the `shapes` array by hand. Immutable per ADR-003 — every builder returns
// a new `Slide`; the original is untouched. Lookups that can't resolve their
// target raise `SlideError` (mirroring `update_slide_mut`'s out-of-range
// behaviour) rather than silently doing nothing — use `map_shapes` for
// best-effort edits that pass non-matching shapes through.

///|
/// The shape's unique-per-slide id (`<p:cNvPr id>`), or `None` for an
/// `Unknown` shape (an unmodelled `<p:contentPart>` etc., which carries no
/// typed id). Stable across edits, so it's the safest handle for targeted
/// updates — see `Slide::with_shape_by_id`.
pub fn Shape::id(self : Shape) -> Int? {
  match self {
    AutoShape(s) => Some(s.id)
    Picture(p) => Some(p.id)
    Connector(c) => Some(c.id)
    Group(g) => Some(g.id)
    GraphicFrame(gf) => Some(gf.id)
    Unknown(_) => None
  }
}

///|
/// The shape's name (`<p:cNvPr name>`), or `None` for an `Unknown` shape.
pub fn Shape::name(self : Shape) -> String? {
  match self {
    AutoShape(s) => Some(s.name)
    Picture(p) => Some(p.name)
    Connector(c) => Some(c.name)
    Group(g) => Some(g.name)
    GraphicFrame(gf) => Some(gf.name)
    Unknown(_) => None
  }
}

///|
/// Return a new `Slide` with `f` applied to every shape, in order. Total —
/// returning the argument unchanged is an identity passthrough, so this
/// doubles as a best-effort targeted edit (match the shapes you want, return
/// the rest as-is) without the raise of the id/index helpers.
pub fn Slide::map_shapes(self : Slide, f : (Shape) -> Shape) -> Slide {
  let new_shapes : Array[Shape] = []
  for s in self.shapes {
    new_shapes.push(f(s))
  }
  { ..self, shapes: new_shapes }
}

///|
/// Return a new `Slide` with the shape at `index` replaced by `shape`.
/// Raises `SlideError::Malformed` if `index` is out of range.
pub fn Slide::with_shape_at(
  self : Slide,
  index : Int,
  shape : Shape,
) -> Slide raise SlideError {
  if index < 0 || index >= self.shapes.length() {
    raise Malformed(
      "with_shape_at: index " +
      index.to_string() +
      " out of range (0.." +
      self.shapes.length().to_string() +
      ")",
    )
  }
  let new_shapes : Array[Shape] = []
  for i, s in self.shapes {
    if i == index {
      new_shapes.push(shape)
    } else {
      new_shapes.push(s)
    }
  }
  { ..self, shapes: new_shapes }
}

///|
/// Return a new `Slide` with the shape at `index` transformed by `f`.
/// Raises `SlideError::Malformed` if `index` is out of range.
pub fn Slide::with_shape_mapped(
  self : Slide,
  index : Int,
  f : (Shape) -> Shape,
) -> Slide raise SlideError {
  if index < 0 || index >= self.shapes.length() {
    raise Malformed(
      "with_shape_mapped: index " +
      index.to_string() +
      " out of range (0.." +
      self.shapes.length().to_string() +
      ")",
    )
  }
  let new_shapes : Array[Shape] = []
  for i, s in self.shapes {
    if i == index {
      new_shapes.push(f(s))
    } else {
      new_shapes.push(s)
    }
  }
  { ..self, shapes: new_shapes }
}

///|
/// Return a new `Slide` with the shape whose id is `id` transformed by `f`.
/// `Unknown` shapes have no id and are never matched. Raises
/// `SlideError::Malformed` if no shape has that id. (If multiple shapes
/// share an id — malformed input — every match is transformed.)
pub fn Slide::with_shape_by_id(
  self : Slide,
  id : Int,
  f : (Shape) -> Shape,
) -> Slide raise SlideError {
  let new_shapes : Array[Shape] = []
  let mut found = false
  for s in self.shapes {
    match s.id() {
      Some(sid) =>
        if sid == id {
          found = true
          new_shapes.push(f(s))
        } else {
          new_shapes.push(s)
        }
      None => new_shapes.push(s)
    }
  }
  if !found {
    raise Malformed("with_shape_by_id: no shape with id " + id.to_string())
  }
  { ..self, shapes: new_shapes }
}

///|
/// Return a new `Slide` with the shape at `index` removed. Raises
/// `SlideError::Malformed` if `index` is out of range.
pub fn Slide::without_shape(
  self : Slide,
  index : Int,
) -> Slide raise SlideError {
  if index < 0 || index >= self.shapes.length() {
    raise Malformed(
      "without_shape: index " +
      index.to_string() +
      " out of range (0.." +
      self.shapes.length().to_string() +
      ")",
    )
  }
  let new_shapes : Array[Shape] = []
  for i, s in self.shapes {
    if i != index {
      new_shapes.push(s)
    }
  }
  { ..self, shapes: new_shapes }
}

///|
/// Return a new `Slide` with the shape whose id is `id` removed. Raises
/// `SlideError::Malformed` if no shape has that id.
pub fn Slide::without_shape_by_id(
  self : Slide,
  id : Int,
) -> Slide raise SlideError {
  let new_shapes : Array[Shape] = []
  let mut found = false
  for s in self.shapes {
    match s.id() {
      Some(sid) => if sid == id { found = true } else { new_shapes.push(s) }
      None => new_shapes.push(s)
    }
  }
  if !found {
    raise Malformed("without_shape_by_id: no shape with id " + id.to_string())
  }
  { ..self, shapes: new_shapes }
}
