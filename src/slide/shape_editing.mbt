// Pinpoint shape editing.
//
// The base mutation API is append-only (`Slide::with_shape`) + whole-slide
// replace (`@presentation.update_slide_mut`). These helpers close the gap:
// locate an *existing* shape (by position, by stable id, or via the placeholder
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
/// Return the shape with its `<p:cNvPr id>` set to `id`. An `Unknown` shape
/// carries no typed id and comes back untouched.
pub fn Shape::with_id(self : Shape, id : Int) -> Shape {
  match self {
    AutoShape(s) => AutoShape({ ..s, id, })
    Picture(p) => Picture({ ..p, id, })
    Connector(c) => Connector({ ..c, id, })
    Group(g) => Group({ ..g, id, })
    GraphicFrame(gf) => GraphicFrame({ ..gf, id, })
    Unknown(_) => self
  }
}

///|
/// Append every id under `shapes` to `out`, descending into groups — a group's
/// children live in the same `<p:spTree>` as their parent, so they compete for
/// the same id space.
fn collect_shape_ids(shapes : Array[Shape], out : Array[Int]) -> Unit {
  for s in shapes {
    match s.id() {
      Some(i) => out.push(i)
      None => ()
    }
    match s {
      Group(g) => collect_shape_ids(g.children, out)
      _ => ()
    }
  }
}

///|
/// The lowest id no shape on the slide is using (highest in use + 1, never
/// below 2 — id 1 belongs to the root `<p:spTree>` itself). Group children
/// count: they share the slide's id space, so an id taken from here is free
/// against the whole tree, not just the top level.
///
/// `<p:cNvPr id>` must be unique within a slide. Every shape builder takes an
/// explicit id, so this is what a caller assembling shapes one at a time asks
/// for instead of tracking a counter — or see `with_shape_auto_id`, which
/// asks on the caller's behalf.
pub fn Slide::next_shape_id(self : Slide) -> Int {
  let ids : Array[Int] = []
  collect_shape_ids(self.shapes, ids)
  let mut max = 1
  for i in ids {
    if i > max {
      max = i
    }
  }
  max + 1
}

///|
/// Append `shape` with its id replaced by `next_shape_id()`, so it cannot
/// collide with anything already on the slide. Whatever id the builder was
/// given is discarded. An `Unknown` shape has no id to assign and is appended
/// unchanged.
pub fn Slide::with_shape_auto_id(self : Slide, shape : Shape) -> Slide {
  self.with_shape(shape.with_id(self.next_shape_id()))
}

///|
/// Every `<p:cNvPr id>` that more than one shape on the slide claims, each
/// listed once, ascending. An empty array is the healthy answer — the
/// attribute is required to be unique within the slide, and a duplicate is
/// one of the things PowerPoint offers to repair a file over.
///
/// This is a query and not a `serialize` failure on purpose: a deck parsed
/// from a third-party file can arrive with duplicates already in it, and
/// refusing to write it back would cost the lossless round-trip (ADR-004).
/// Check it on decks you assemble; leave the ones you are only passing
/// through alone.
pub fn Slide::duplicate_shape_ids(self : Slide) -> Array[Int] {
  let ids : Array[Int] = []
  collect_shape_ids(self.shapes, ids)
  let seen : Map[Int, Int] = Map([])
  for i in ids {
    seen[i] = match seen.get(i) {
      Some(n) => n + 1
      None => 1
    }
  }
  let dups : Array[Int] = []
  for i in ids {
    if seen.get(i) is Some(n) && n > 1 && !dups.contains(i) {
      dups.push(i)
    }
  }
  dups.sort()
  dups
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
  { ..self, shapes: new_shapes, }
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
  { ..self, shapes: new_shapes, }
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
  { ..self, shapes: new_shapes, }
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
  { ..self, shapes: new_shapes, }
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
  { ..self, shapes: new_shapes, }
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
  { ..self, shapes: new_shapes, }
}
