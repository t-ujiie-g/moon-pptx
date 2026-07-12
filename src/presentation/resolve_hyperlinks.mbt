// Hyperlink resolution.
//
// Runs built via `RunProperties::with_hyperlink(url)` carry an
// **unresolved** `hyperlink_target` value. The url/slide-idx itself
// can't live in the OOXML serialisation — OOXML stores hyperlinks as
// a slide-rels relationship (rId) referenced from `<a:hlinkClick>`.
//
// `update_slide_mut` invokes `resolve_slide_hyperlinks` just before
// serialisation: we walk the slide tree, and for every RunProperties
// with `hyperlink_target = Some(_)` we
//   1. Allocate the next unused rId on the slide's `.rels`
//   2. Register the appropriate `<Relationship>` (External URL or
//      Internal target-slide pointer)
//   3. Set the run's `hyperlink_click` to the new rId and clear its
//      `hyperlink_target` (resolution is now baked in)
//   4. Mark the rels dirty
//
// If any rels were touched, we write them back via
// `write_rels_for_part`.

///|
/// Walk `slide` and resolve every unresolved hyperlink against the
/// part at `slide_name`. Returns the resolved slide. Side-effects:
/// updates the slide's `.rels` part in the package when any
/// resolution happens.
fn Presentation::resolve_slide_hyperlinks(
  self : Presentation,
  slide_name : String,
  slide : @slide.Slide,
) -> @slide.Slide raise PptxError {
  // Cheap pre-check: scan the slide for any unresolved targets so we
  // avoid loading rels (and writing them back) when there's nothing
  // to resolve. The vast majority of slides have no hyperlinks.
  if !slide_has_unresolved_hyperlinks(slide) {
    return slide
  }
  let initial_rels = self.pkg.relationships_for(slide_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let ctx = HyperlinkCtx::{
    prs: self,
    slide_name,
    rels: initial_rels,
    changed: false,
  }
  let new_shapes = []
  for sh in slide.shapes {
    new_shapes.push(resolve_shape_hyperlinks(sh, ctx))
  }
  if ctx.changed {
    self.write_rels_for_part(slide_name, ctx.rels)
  }
  { ..slide, shapes: new_shapes }
}

///|
/// Mutable resolution context threaded through the walk. The
/// `rels` field is rebuilt as new relationships are appended.
priv struct HyperlinkCtx {
  prs : Presentation
  slide_name : String
  mut rels : @opc.Relationships
  mut changed : Bool
}

///|
/// Pre-check: does any run anywhere in this slide tree carry an
/// unresolved hyperlink_target? Cheap walk so we skip the rels
/// roundtrip when nothing needs resolving.
fn slide_has_unresolved_hyperlinks(slide : @slide.Slide) -> Bool {
  for sh in slide.shapes {
    if shape_has_unresolved_hyperlinks(sh) {
      return true
    }
  }
  false
}

///|
fn shape_has_unresolved_hyperlinks(shape : @slide.Shape) -> Bool {
  match shape {
    AutoShape(a) =>
      shape_hyperlink_unresolved(a.hyperlink) ||
      (match a.text_body {
        Some(tb) => text_body_has_unresolved(tb)
        None => false
      })
    Picture(p) => shape_hyperlink_unresolved(p.hyperlink)
    Connector(c) => shape_hyperlink_unresolved(c.hyperlink)
    GraphicFrame(gf) => shape_hyperlink_unresolved(gf.hyperlink)
    Group(g) => {
      if shape_hyperlink_unresolved(g.hyperlink) {
        return true
      }
      for c in g.children {
        if shape_has_unresolved_hyperlinks(c) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
/// Whether a shape-level hyperlink still carries an unresolved target.
fn shape_hyperlink_unresolved(hl : @slide.ShapeHyperlink?) -> Bool {
  match hl {
    Some(h) => h.target is Some(_)
    None => false
  }
}

///|
fn text_body_has_unresolved(tb : @slide.TextBody) -> Bool {
  for p in tb.paragraphs {
    for c in p.content {
      let rp = match c {
        RunContent(r) => r.properties
        Break(rp) => rp
        FieldContent(f) => f.properties
      }
      if rp.hyperlink_target is Some(_) {
        return true
      }
    }
  }
  false
}

// --- per-node resolvers ---

///|
fn resolve_shape_hyperlinks(
  shape : @slide.Shape,
  ctx : HyperlinkCtx,
) -> @slide.Shape raise PptxError {
  match shape {
    AutoShape(a) => {
      let new_hyperlink = match a.hyperlink {
        Some(h) => Some(resolve_shape_hyperlink(h, ctx))
        None => None
      }
      let new_text_body = match a.text_body {
        Some(tb) => Some(resolve_text_body_hyperlinks(tb, ctx))
        None => None
      }
      AutoShape({ ..a, hyperlink: new_hyperlink, text_body: new_text_body })
    }
    Picture(p) =>
      match p.hyperlink {
        Some(h) =>
          Picture({ ..p, hyperlink: Some(resolve_shape_hyperlink(h, ctx)) })
        None => shape
      }
    Connector(c) =>
      match c.hyperlink {
        Some(h) =>
          Connector({ ..c, hyperlink: Some(resolve_shape_hyperlink(h, ctx)) })
        None => shape
      }
    GraphicFrame(gf) =>
      match gf.hyperlink {
        Some(h) =>
          GraphicFrame({
            ..gf,
            hyperlink: Some(resolve_shape_hyperlink(h, ctx)),
          })
        None => shape
      }
    Group(g) => {
      let new_hyperlink = match g.hyperlink {
        Some(h) => Some(resolve_shape_hyperlink(h, ctx))
        None => None
      }
      let new_children = []
      for c in g.children {
        new_children.push(resolve_shape_hyperlinks(c, ctx))
      }
      Group({ ..g, hyperlink: new_hyperlink, children: new_children })
    }
    _ => shape
  }
}

///|
fn resolve_text_body_hyperlinks(
  tb : @slide.TextBody,
  ctx : HyperlinkCtx,
) -> @slide.TextBody raise PptxError {
  let new_paragraphs = []
  for p in tb.paragraphs {
    let new_content = []
    for c in p.content {
      new_content.push(resolve_paragraph_content(c, ctx))
    }
    new_paragraphs.push({ ..p, content: new_content })
  }
  { ..tb, paragraphs: new_paragraphs }
}

///|
fn resolve_paragraph_content(
  c : @slide.ParagraphContent,
  ctx : HyperlinkCtx,
) -> @slide.ParagraphContent raise PptxError {
  match c {
    RunContent(r) => {
      let new_props = resolve_run_properties(r.properties, ctx)
      RunContent({ ..r, properties: new_props })
    }
    Break(rp) => Break(resolve_run_properties(rp, ctx))
    FieldContent(f) => {
      let new_props = resolve_run_properties(f.properties, ctx)
      FieldContent({ ..f, properties: new_props })
    }
  }
}

///|
fn resolve_run_properties(
  rp : @slide.RunProperties,
  ctx : HyperlinkCtx,
) -> @slide.RunProperties raise PptxError {
  match rp.hyperlink_target {
    None => rp
    Some(target) => {
      let (rid, action) = allocate_hyperlink(ctx, target)
      {
        ..rp,
        hyperlink_click: Some(rid),
        hyperlink_action: action,
        hyperlink_target: None,
      }
    }
  }
}

///|
/// Allocate a slide-rels relationship for `target`, register it, and return
/// the new `(rId, action)`. Shared by run-level (`RunProperties`) and
/// shape-level (`ShapeHyperlink`) hyperlink resolution. Mutates
/// `ctx.rels` / `ctx.changed`.
fn allocate_hyperlink(
  ctx : HyperlinkCtx,
  target : @slide.HyperlinkTarget,
) -> (String, String?) raise PptxError {
  let rid = next_unused_rid(ctx.rels)
  let (rel, action) : (@opc.Relationship, String?) = match target {
    ExternalUrl(url) =>
      (
        {
          id: rid,
          rel_type: @opc.rt_hyperlink,
          target: url,
          target_mode: External,
        },
        None,
      )
    InternalSlide(idx) => {
      let parts = ctx.prs.ordered_slide_parts()
      if idx < 0 || idx >= parts.length() {
        raise Malformed(
          "hyperlink_to_slide: target slide_idx " +
          idx.to_string() +
          " out of range (have " +
          parts.length().to_string() +
          " slides)",
        )
      }
      let target_name = parts[idx].name
      (
        {
          id: rid,
          rel_type: @opc.rt_slide,
          target: relative_target(ctx.slide_name, target_name),
          target_mode: Internal,
        },
        // PowerPoint needs `action="ppaction://hlinksldjump"` to
        // recognise the rId as a slide jump.
        Some("ppaction://hlinksldjump"),
      )
    }
  }
  ctx.rels = ctx.rels.with_relationship(rel) catch {
    e => raise OpcFailure(e.to_string())
  }
  ctx.changed = true
  (rid, action)
}

///|
/// Resolve a shape-level hyperlink: allocate its rId + action and clear
/// the unresolved target. A `None`-target hyperlink (already resolved or
/// absent) is returned unchanged.
fn resolve_shape_hyperlink(
  hl : @slide.ShapeHyperlink,
  ctx : HyperlinkCtx,
) -> @slide.ShapeHyperlink raise PptxError {
  match hl.target {
    None => hl
    Some(target) => {
      let (rid, action) = allocate_hyperlink(ctx, target)
      { target: None, click: Some(rid), action }
    }
  }
}
