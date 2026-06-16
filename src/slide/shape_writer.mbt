// Shape writer.
//
// One dispatch (`write_shape`) plus per-variant emit helpers for
// AutoShape (`<p:sp>`), Picture (`<p:pic>`), Connector (`<p:cxnSp>`),
// GroupShape (`<p:grpSp>`), and Unknown (the captured XmlElement
// emitted verbatim).
//
// Each shape has a parsed `extension : Array[XmlElement]` that came
// from a mix of locations: inside <p:nvSpPr>/<p:nvPicPr>/<p:nvCxnSpPr>
// (e.g. cNvPr body, spLocks, hlinkClick, nvPr.custDataLst), inside
// <p:spPr> (scene3d, sp3d, extLst, foreign-namespace), or as siblings
// of the shape body (<p:style>, <p:extLst>, foreign-ns). On write we
// can't reliably tell which one came from where without classifying by
// local-name, so we use the same trick as the slide-level extension
// replay: emit the spec-defined "lives inside nvSpPr" elements there,
// the "lives inside spPr" elements there, and the rest as siblings
// of the shape body.

///|
/// Per-shape extension scope. Drives the multi-pass replay inside each
/// shape's `<p:sp>` / `<p:pic>` / `<p:cxnSp>` / `<p:grpSp>` body.
priv enum ShapeExtScope {
  /// Captured wrapper element that belongs *inside* `<p:nvSpPr>` /
  /// `<p:nvPicPr>` / `<p:nvCxnSpPr>` / `<p:nvGrpSpPr>`. Concretely
  /// `<p:cNvPr>` (the parser captures the whole element including its
  /// `id`/`name` attrs and any `<a:hlinkClick>` child) and the
  /// per-shape-kind `<p:cNv*Pr>` wrapper.
  ShapeExtNvWrapper
  /// Captured child of `<p:nvPr>` — `<p:custDataLst>`,
  /// `<p:audioFile>`, `<p:videoFile>` and any foreign sibling. Goes
  /// after the modeled `<p:ph>` inside `<p:nvPr>`.
  ShapeExtNvPrChild
  /// Lives inside the visual properties wrapper (`<p:spPr>` for sp /
  /// pic / cxnSp; `<p:grpSpPr>` for grpSp). Examples: `<a:scene3d>`,
  /// `<a:sp3d>`, `<a:extLst>` (drawing-ml).
  ShapeExtSpPr
  /// Lives directly as a sibling of the shape body — `<p:style>`,
  /// `<p:extLst>` (presentation-ml), foreign-namespace extensions.
  ShapeExtBody
}

///|
/// Classify a captured shape-level extension element by its local-name.
/// The shape kind determines which `<p:cNv*Pr>` local-name belongs to
/// the nv wrapper (sp → `cNvSpPr`, pic → `cNvPicPr`, etc.) — pass that
/// as `cnv_kind` so the classifier puts the right wrapper inside
/// `<p:nvSpPr>` / `<p:nvPicPr>` / …
fn classify_shape_ext(el : @xml.XmlElement, cnv_kind : String) -> ShapeExtScope {
  if el.name.uri == @oxml.presentation_ns {
    if el.name.local_name == "cNvPr" || el.name.local_name == cnv_kind {
      return ShapeExtNvWrapper
    }
    match el.name.local_name {
      "custDataLst" | "audioFile" | "videoFile" => return ShapeExtNvPrChild
      "style" => return ShapeExtBody
      _ => ()
    }
  }
  if el.name.uri == @oxml.drawing_ns {
    match el.name.local_name {
      "scene3d" | "sp3d" | "extLst" => return ShapeExtSpPr
      _ => ()
    }
  }
  // Foreign-namespace + everything else: shape-body level.
  ShapeExtBody
}

///|
/// Dispatch a `Shape` onto its variant-specific writer.
fn write_shape(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  shape : Shape,
) -> Unit raise @xml.XmlError {
  match shape {
    AutoShape(s) => write_auto_shape(w, ctx, s)
    Picture(p) => write_picture(w, ctx, p)
    Connector(c) => write_connector(w, ctx, c)
    Group(g) => write_group_shape(w, ctx, g)
    GraphicFrame(gf) => write_graphic_frame(w, ctx, gf)
    Unknown(el) => @oxml.write_xml_element(w, ctx, el)
  }
}

// --- AutoShape ---

///|
fn write_auto_shape(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  s : AutoShape,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "sp"))
  write_nv_wrapper(
    w,
    ctx,
    "nvSpPr",
    "cNvSpPr",
    s.id,
    s.name,
    s.placeholder,
    None,
    s.extension,
  )
  write_sp_pr(
    w,
    ctx,
    s.transform,
    s.geometry,
    s.fill,
    s.stroke,
    s.effects,
    s.extension,
    "cNvSpPr",
  )
  match s.text_body {
    Some(tb) => write_text_body(w, ctx, tb)
    None => ()
  }
  // Body-level captured siblings (<p:style>, foreign-ns, <p:extLst>).
  write_body_extensions(w, ctx, s.extension, "cNvSpPr")
  w.end_element()
}

///|
/// Emit a non-visual-properties wrapper element (`<p:nvSpPr>` /
/// `<p:nvPicPr>` / `<p:nvCxnSpPr>` / `<p:nvGrpSpPr>`).
///
/// `wrapper_local` selects the outer wrapper local name; `cnv_kind`
/// names the per-shape-kind `<p:cNv*Pr>` child (`cNvSpPr` /
/// `cNvPicPr` / `cNvCxnSpPr` / `cNvGrpSpPr`).
///
/// Both `<p:cNvPr>` and `<p:cNv*Pr>` are captured wholesale into
/// `extension` during parse. `<p:cNvPr>` goes through `write_cnvpr`
/// (which keeps the typed `id`/`name` authoritative so B4 edits take
/// effect); the `<p:cNv*Pr>` wrapper is emitted verbatim — both are
/// synthesised only when the input didn't include them (hand-built
/// values, not anything that round-trips through `::parse`).

///|
/// Emit `<p:cNvPr>`. The element is captured wholesale into `extension`
/// during parse (it can carry `descr` / `title` / `hidden` attributes and
/// `<a:hlinkClick>` / `<a:extLst>` children), so we re-emit the captured one
/// verbatim — *except* we override its `id` and `name` attribute values with
/// the typed fields. For a freshly-parsed shape those values are identical
/// (the parser read them from this very element), so the output is
/// byte-for-byte unchanged; once a builder edits `name`/`id` (B4), the new
/// value flows through while everything else round-trips losslessly. When no
/// `<p:cNvPr>` was captured (hand-built shapes), synthesise a minimal one.
fn write_cnvpr(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  id : Int,
  name : String,
  media : MediaInfo?,
  extension : Array[@xml.XmlElement],
) -> Unit raise @xml.XmlError {
  let mut captured : @xml.XmlElement? = None
  for ext in extension {
    if ext.name.uri == @oxml.presentation_ns && ext.name.local_name == "cNvPr" {
      captured = Some(ext)
    }
  }
  match captured {
    Some(cnvpr) => {
      let attrs : Array[(@xml.QName, String)] = []
      let mut saw_id = false
      let mut saw_name = false
      for kv in cnvpr.attributes {
        if kv.0.local_name == "id" {
          attrs.push((kv.0, id.to_string()))
          saw_id = true
        } else if kv.0.local_name == "name" {
          attrs.push((kv.0, name))
          saw_name = true
        } else {
          attrs.push(kv)
        }
      }
      // Defensive: the schema requires id + name. They are present (and thus
      // replaced in place above, preserving order) for any real input; only
      // if a malformed source omitted one do we prepend it.
      let final_attrs : Array[(@xml.QName, String)] = []
      if !saw_id {
        final_attrs.push((@xml.QName::unqualified("id"), id.to_string()))
      }
      if !saw_name {
        final_attrs.push((@xml.QName::unqualified("name"), name))
      }
      for a in attrs {
        final_attrs.push(a)
      }
      @oxml.write_xml_element(
        w,
        ctx,
        @xml.XmlElement::new(cnvpr.name, final_attrs, cnvpr.children),
      )
    }
    None => {
      w.start_element(@xml.QName::new(@oxml.presentation_ns, "cNvPr"))
      w.attribute(@xml.QName::unqualified("id"), id.to_string())
      w.attribute(@xml.QName::unqualified("name"), name)
      // A media picture needs a `ppaction://media` hyperlink so PowerPoint
      // treats the shape as a playable clip (roadmap A6).
      match media {
        Some(_) => {
          w.start_element(@xml.QName::new(@oxml.drawing_ns, "hlinkClick"))
          w.attribute(@xml.QName::new(@oxml.office_relationships_ns, "id"), "")
          w.attribute(@xml.QName::unqualified("action"), "ppaction://media")
          w.end_element()
        }
        None => ()
      }
      w.end_element()
    }
  }
}

///|
fn write_nv_wrapper(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  wrapper_local : String,
  cnv_kind : String,
  id : Int,
  name : String,
  placeholder : Placeholder?,
  media : MediaInfo?,
  extension : Array[@xml.XmlElement],
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, wrapper_local))
  // <p:cNvPr>: emit it, with the typed id/name authoritative so edits to
  // those fields (roadmap B4) take effect.
  write_cnvpr(w, ctx, id, name, media, extension)
  // <p:cNv*Pr>: captured if present, empty otherwise.
  let mut emitted_cnvkind = false
  for ext in extension {
    if ext.name.uri == @oxml.presentation_ns && ext.name.local_name == cnv_kind {
      @oxml.write_xml_element(w, ctx, ext)
      emitted_cnvkind = true
    }
  }
  if !emitted_cnvkind {
    w.start_element(@xml.QName::new(@oxml.presentation_ns, cnv_kind))
    w.end_element()
  }
  // <p:nvPr>: placeholder (modeled) + media (modeled) + nvPr-child captures.
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "nvPr"))
  match placeholder {
    Some(ph) => write_placeholder(w, ph)
    None => ()
  }
  // Typed media reference (roadmap A6): <a:videoFile>/<a:audioFile> +
  // <p:extLst><p14:media>. Parsed media pics carry this verbatim in
  // `extension` instead (media is None), so the two paths never overlap.
  match media {
    Some(m) =>
      for el in media_nv_elements(m) {
        @oxml.write_xml_element(w, ctx, el)
      }
    None => ()
  }
  for ext in extension {
    if classify_shape_ext(ext, cnv_kind) is ShapeExtNvPrChild {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  w.end_element()
  w.end_element() // wrapper
}

///|
/// Emit captured body-level extensions (`<p:style>`, `<p:extLst>`,
/// foreign-namespace siblings). Excludes elements that were already
/// emitted inside the nv wrapper or inside `<p:spPr>`.
fn write_body_extensions(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  extension : Array[@xml.XmlElement],
  cnv_kind : String,
) -> Unit raise @xml.XmlError {
  for ext in extension {
    if classify_shape_ext(ext, cnv_kind) is ShapeExtBody {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
}

///|
fn write_placeholder(
  w : @xml.XmlWriter,
  ph : Placeholder,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "ph"))
  if ph.ph_type != "" {
    w.attribute(@xml.QName::unqualified("type"), ph.ph_type)
  }
  if ph.idx != 0 {
    w.attribute(@xml.QName::unqualified("idx"), ph.idx.to_string())
  }
  w.end_element()
}

///|
/// `<p:spPr>` body: optional `<a:xfrm>` + geometry + fill choice +
/// `<a:ln>` + effects + captured drawing-ml children (scene3d /
/// sp3d / extLst). Child order matches the ECMA-376 CT_ShapeProperties
/// schema.
fn write_sp_pr(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  transform : Transform?,
  geometry : Geometry?,
  fill : @oxml.Fill?,
  stroke : @oxml.Stroke?,
  effects : @oxml.EffectList?,
  extension : Array[@xml.XmlElement],
  cnv_kind : String,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "spPr"))
  match transform {
    Some(xfrm) => write_xfrm(w, xfrm)
    None => ()
  }
  match geometry {
    Some(g) => write_geometry(w, ctx, g)
    None => ()
  }
  match fill {
    Some(f) => @oxml.write_fill(w, ctx, f)
    None => ()
  }
  match stroke {
    Some(s) => @oxml.write_stroke(w, ctx, s)
    None => ()
  }
  match effects {
    Some(e) => @oxml.write_effect_list(w, ctx, e)
    None => ()
  }
  // spPr-level captured extensions (scene3d, sp3d, drawing-ml extLst).
  for ext in extension {
    if classify_shape_ext(ext, cnv_kind) is ShapeExtSpPr {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  w.end_element()
}

///|
fn write_xfrm(w : @xml.XmlWriter, xfrm : Transform) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "xfrm"))
  write_xfrm_orientation_attrs(w, xfrm)
  let @units.Emu(x) = xfrm.offset.x
  let @units.Emu(y) = xfrm.offset.y
  let @units.Emu(cx) = xfrm.extent.cx
  let @units.Emu(cy) = xfrm.extent.cy
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "off"))
  w.attribute(@xml.QName::unqualified("x"), x.to_string())
  w.attribute(@xml.QName::unqualified("y"), y.to_string())
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "ext"))
  w.attribute(@xml.QName::unqualified("cx"), cx.to_string())
  w.attribute(@xml.QName::unqualified("cy"), cy.to_string())
  w.end_element()
  w.end_element()
}

///|
/// Emit the orientation attributes (`rot` / `flipH` / `flipV`) on an
/// already-opened `<a:xfrm>` / `<p:xfrm>` element. Must be called right
/// after `start_element` (before any child). Defaults are omitted so an
/// unrotated, un-flipped transform re-serialises byte-identically.
fn write_xfrm_orientation_attrs(
  w : @xml.XmlWriter,
  xfrm : Transform,
) -> Unit raise @xml.XmlError {
  match xfrm.rotation {
    Some(angle) => {
      let n = angle.to_ooxml()
      if n != 0 {
        w.attribute(@xml.QName::unqualified("rot"), n.to_string())
      }
    }
    None => ()
  }
  if xfrm.flip_h {
    w.attribute(@xml.QName::unqualified("flipH"), "1")
  }
  if xfrm.flip_v {
    w.attribute(@xml.QName::unqualified("flipV"), "1")
  }
}

///|
fn write_geometry(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  g : Geometry,
) -> Unit raise @xml.XmlError {
  match g {
    Preset(preset, adjustments) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "prstGeom"))
      w.attribute(@xml.QName::unqualified("prst"), preset.to_xml())
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "avLst"))
      for adj in adjustments {
        w.start_element(@xml.QName::new(@oxml.drawing_ns, "gd"))
        w.attribute(@xml.QName::unqualified("name"), adj.name)
        w.attribute(@xml.QName::unqualified("fmla"), adj.fmla)
        w.end_element()
      }
      w.end_element()
      w.end_element()
    }
    Custom(cg) => write_custom_geometry(w, ctx, cg)
  }
}

// --- Picture ---

///|
fn write_picture(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  p : Picture,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "pic"))
  // <p:nvPicPr> body — same shape as nvSpPr but with cNvPicPr.
  write_nv_wrapper(
    w,
    ctx,
    "nvPicPr",
    "cNvPicPr",
    p.id,
    p.name,
    None,
    p.media,
    p.extension,
  )
  // <p:blipFill> — picture's blipFill lives in the presentation
  // namespace (not drawing-ml) but otherwise has the same body.
  write_pic_blip_fill(w, ctx, p.blip_fill)
  // <p:spPr> body.
  write_sp_pr(
    w,
    ctx,
    p.transform,
    p.geometry,
    None, // pictures' fill lives in <p:blipFill>, not <p:spPr>
    p.stroke,
    p.effects,
    p.extension,
    "cNvPicPr",
  )
  // Body-level extensions.
  write_body_extensions(w, ctx, p.extension, "cNvPicPr")
  w.end_element()
}

///|
/// Emit `<p:blipFill>` (note the `p:` prefix, not `a:` — picture's
/// blipFill lives in the presentation namespace while shape-level
/// blipFill uses drawing-ml). Body content is the same as a drawing-ml
/// blipFill, so we manually replay the same structure here.
fn write_pic_blip_fill(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  bf : @oxml.BlipFill,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "blipFill"))
  // The captured <a:blip> subtree carries r:embed / r:link plus any
  // colour-mod / image-effect children.  Emit it verbatim.
  let mut blip_emitted = false
  for ext in bf.extension {
    if ext.name.uri == @oxml.drawing_ns && ext.name.local_name == "blip" {
      @oxml.write_xml_element(w, ctx, ext)
      blip_emitted = true
    }
  }
  if !blip_emitted {
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "blip"))
    if bf.embed_id != "" {
      w.attribute(
        @xml.QName::new(@oxml.office_relationships_ns, "embed"),
        bf.embed_id,
      )
    }
    if bf.link_id != "" {
      w.attribute(
        @xml.QName::new(@oxml.office_relationships_ns, "link"),
        bf.link_id,
      )
    }
    w.end_element()
  }
  match bf.src_rect {
    Some(rect) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "srcRect"))
      w.attribute(
        @xml.QName::unqualified("l"),
        rect.left.to_ooxml().to_string(),
      )
      w.attribute(@xml.QName::unqualified("t"), rect.top.to_ooxml().to_string())
      w.attribute(
        @xml.QName::unqualified("r"),
        rect.right.to_ooxml().to_string(),
      )
      w.attribute(
        @xml.QName::unqualified("b"),
        rect.bottom.to_ooxml().to_string(),
      )
      w.end_element()
    }
    None => ()
  }
  match bf.fill_mode {
    Stretch(opt_rect) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "stretch"))
      match opt_rect {
        Some(rect) => {
          w.start_element(@xml.QName::new(@oxml.drawing_ns, "fillRect"))
          w.attribute(
            @xml.QName::unqualified("l"),
            rect.left.to_ooxml().to_string(),
          )
          w.attribute(
            @xml.QName::unqualified("t"),
            rect.top.to_ooxml().to_string(),
          )
          w.attribute(
            @xml.QName::unqualified("r"),
            rect.right.to_ooxml().to_string(),
          )
          w.attribute(
            @xml.QName::unqualified("b"),
            rect.bottom.to_ooxml().to_string(),
          )
          w.end_element()
        }
        None => ()
      }
      w.end_element()
    }
    Tile(_) =>
      // Tile is rare on pictures; let the @oxml writer handle the
      // body and just emit the wrapper. The @oxml writer emits an
      // <a:blipFill> wrapper though, so we replicate the tile body
      // inline — but tile on a picture is uncommon enough that we
      // can defer the dedicated path.
      // For now emit nothing — the parsed model would have caught
      // this case as a tile inside <a:blipFill> on shape-level, not
      // <p:blipFill> on a picture.
      ()
  }
  // Any remaining extension elements that aren't the blip (rare).
  for ext in bf.extension {
    if !(ext.name.uri == @oxml.drawing_ns && ext.name.local_name == "blip") {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  w.end_element()
}

// --- Connector ---

///|
fn write_connector(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  c : Connector,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "cxnSp"))
  // <p:nvCxnSpPr> body. Unlike sp / pic / grp the parser walks
  // `<p:cNvCxnSpPr>` into the modeled `start` / `end` fields rather
  // than capturing it wholesale, so we re-synthesise it from those
  // fields here.
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "nvCxnSpPr"))
  // cNvPr (still captured wholesale per parse_nv_cxn_sp_pr).
  let mut emitted_cnvpr = false
  for ext in c.extension {
    if ext.name.uri == @oxml.presentation_ns && ext.name.local_name == "cNvPr" {
      @oxml.write_xml_element(w, ctx, ext)
      emitted_cnvpr = true
    }
  }
  if !emitted_cnvpr {
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "cNvPr"))
    w.attribute(@xml.QName::unqualified("id"), c.id.to_string())
    w.attribute(@xml.QName::unqualified("name"), c.name)
    w.end_element()
  }
  // cNvCxnSpPr re-synthesised with modeled stCxn / endCxn.
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "cNvCxnSpPr"))
  match c.start {
    Some(e) => write_connection_end(w, "stCxn", e)
    None => ()
  }
  match c.end {
    Some(e) => write_connection_end(w, "endCxn", e)
    None => ()
  }
  w.end_element()
  // nvPr (captured wholesale by parse_nv_cxn_sp_pr).
  let mut emitted_nvpr = false
  for ext in c.extension {
    if ext.name.uri == @oxml.presentation_ns && ext.name.local_name == "nvPr" {
      @oxml.write_xml_element(w, ctx, ext)
      emitted_nvpr = true
    }
  }
  if !emitted_nvpr {
    w.start_element(@xml.QName::new(@oxml.presentation_ns, "nvPr"))
    w.end_element()
  }
  w.end_element() // nvCxnSpPr
  // <p:spPr>
  write_sp_pr(
    w,
    ctx,
    c.transform,
    c.geometry,
    None, // connectors are line-only — no shape-level fill
    c.stroke,
    c.effects,
    c.extension,
    "cNvCxnSpPr",
  )
  // Body-level extensions, excluding the cNvPr / nvPr we already
  // emitted inside nvCxnSpPr above.
  for ext in c.extension {
    if ext.name.uri == @oxml.presentation_ns &&
      (ext.name.local_name == "cNvPr" || ext.name.local_name == "nvPr") {
      continue
    }
    if classify_shape_ext(ext, "cNvCxnSpPr") is ShapeExtBody {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  w.end_element()
}

///|
fn write_connection_end(
  w : @xml.XmlWriter,
  wrapper_local : String,
  e : ConnectionEnd,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, wrapper_local))
  w.attribute(@xml.QName::unqualified("id"), e.shape_id.to_string())
  w.attribute(@xml.QName::unqualified("idx"), e.idx.to_string())
  w.end_element()
}

// --- GroupShape ---

///|
fn write_group_shape(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  g : GroupShape,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "grpSp"))
  // <p:nvGrpSpPr> body — cNvPr + cNvGrpSpPr come from extension.
  write_nv_wrapper(
    w,
    ctx,
    "nvGrpSpPr",
    "cNvGrpSpPr",
    g.id,
    g.name,
    None,
    None,
    g.extension,
  )
  // <p:grpSpPr> with group-specific xfrm.
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "grpSpPr"))
  write_group_xfrm(w, g.transform, g.child_offset, g.child_extent)
  // spPr-level captured extensions (scene3d / extLst / etc.).
  for ext in g.extension {
    if classify_shape_ext(ext, "cNvGrpSpPr") is ShapeExtSpPr {
      @oxml.write_xml_element(w, ctx, ext)
    }
  }
  w.end_element() // grpSpPr
  for child in g.children {
    write_shape(w, ctx, child)
  }
  // Body-level extensions.
  write_body_extensions(w, ctx, g.extension, "cNvGrpSpPr")
  w.end_element() // grpSp
}

///|
fn write_group_xfrm(
  w : @xml.XmlWriter,
  transform : Transform?,
  child_offset : Point?,
  child_extent : Size?,
) -> Unit raise @xml.XmlError {
  let any_present = transform is Some(_) ||
    child_offset is Some(_) ||
    child_extent is Some(_)
  if !any_present {
    return
  }
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "xfrm"))
  match transform {
    Some(xfrm) => write_xfrm_orientation_attrs(w, xfrm)
    None => ()
  }
  match transform {
    Some(xfrm) => {
      let @units.Emu(x) = xfrm.offset.x
      let @units.Emu(y) = xfrm.offset.y
      let @units.Emu(cx) = xfrm.extent.cx
      let @units.Emu(cy) = xfrm.extent.cy
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "off"))
      w.attribute(@xml.QName::unqualified("x"), x.to_string())
      w.attribute(@xml.QName::unqualified("y"), y.to_string())
      w.end_element()
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "ext"))
      w.attribute(@xml.QName::unqualified("cx"), cx.to_string())
      w.attribute(@xml.QName::unqualified("cy"), cy.to_string())
      w.end_element()
    }
    None => ()
  }
  match child_offset {
    Some(p) => {
      let @units.Emu(x) = p.x
      let @units.Emu(y) = p.y
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "chOff"))
      w.attribute(@xml.QName::unqualified("x"), x.to_string())
      w.attribute(@xml.QName::unqualified("y"), y.to_string())
      w.end_element()
    }
    None => ()
  }
  match child_extent {
    Some(s) => {
      let @units.Emu(cx) = s.cx
      let @units.Emu(cy) = s.cy
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "chExt"))
      w.attribute(@xml.QName::unqualified("cx"), cx.to_string())
      w.attribute(@xml.QName::unqualified("cy"), cy.to_string())
      w.end_element()
    }
    None => ()
  }
  w.end_element()
}
