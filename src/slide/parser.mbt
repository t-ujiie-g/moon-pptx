// Slide XML reader.
//
// Same recursive-descent contract as `@theme` and `@slide_master`: each
// `parse_*` helper is called *just after* its element's StartElement has
// been consumed and consumes events through the matching EndElement.
//
// ADR-004 lossless preservation: helpers that walk a body and would
// otherwise drop unknown children take a `parent_extension` argument —
// the surrounding shape's (or slide's) `extension : Array[XmlElement]`.
// Unknown children land on that array via `collect_subtree_unknown` so
// every <a:scene3d> / <a:sp3d> / <p:custDataLst> / <a:hlinkClick> /
// foreign-namespace child survives a read → write round-trip even when
// the typed parser doesn't model it. The intentional `skip_subtree`
// calls that remain are inside elements the spec defines as empty
// (`<a:off>`, `<a:ext>`, `<a:gd>`, `<a:stCxn>`, `<a:endCxn>`,
// `<a:masterClrMapping>`, `<a:overrideClrMapping>`) — there's nothing
// to preserve in their bodies, the skip just consumes the EndElement.

///|
/// Parse a slide part from raw XML bytes.
pub fn Slide::parse(bytes : FixedArray[Byte]) -> Slide raise SlideError {
  parse_slide_xml(bytes_to_string(bytes), "sld")
}

///|
/// Parse a slide-shaped XML part whose root element local-name is
/// `root_local_name`. `<p:sld>` (slides) and `<p:notes>` (speaker notes)
/// share the same `<p:cSld>` + `<p:clrMapOvr>` content model, so the
/// `@notes` package re-uses this entry point with `"notes"` instead of
/// re-implementing the spTree walk.
pub fn Slide::parse_with_root(
  bytes : FixedArray[Byte],
  root_local_name : String,
) -> Slide raise SlideError {
  parse_slide_xml(bytes_to_string(bytes), root_local_name)
}

///|
fn parse_slide_xml(
  xml : String,
  expected_root : String,
) -> Slide raise SlideError {
  let r = @xml.XmlReader::new(xml)
  let event = next_event(r)
  match event {
    StartElement(name, _) => expect_pml(name, expected_root)
    _ => raise Malformed("expected <p:" + expected_root + "> root element")
  }
  let mut slide_name = ""
  let mut background : Background? = None
  let shapes : Array[Shape] = []
  let mut clr_map_override : @slide_master.ClrMapOverride = MasterMapping
  let mut transition : Transition? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.presentation_ns {
          // Foreign-namespace child of <p:sld> — capture verbatim.
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "cSld" => {
              let (n, bg) = parse_c_sld(r, attrs, shapes, extension)
              slide_name = n
              background = bg
            }
            "clrMapOvr" => clr_map_override = parse_clr_map_ovr(r, extension)
            "transition" => transition = Some(parse_transition(r, attrs))
            // timing, custDataLst, extLst, and any future <p:sld> children we
            // don't yet model.
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  {
    name: slide_name,
    background,
    shapes,
    clr_map_override,
    transition,
    // <p:timing> stays captured in `extension` (D2 is build-only); see
    // animation.mbt.
    timing: None,
    extension,
  }
}

///|
/// Parse `<p:transition>` (CT_SlideTransition) — the `spd` / `advClick` /
/// `advTm` attributes plus the optional single transition-effect child. Lifts
/// the transition out of `extension` into the typed `Slide.transition` field
/// (roadmap D3). `<p:sndAc>` / `<p:extLst>` and any unmodelled children are
/// preserved per ADR-004.
fn parse_transition(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Transition raise SlideError {
  let speed = match @oxml.optional_attr(attrs, "spd") {
    Some(s) => TransitionSpeed::from_xml(s)
    None => Fast
  }
  let advance_on_click = match @oxml.bool_attr_opt(attrs, "advClick") {
    Some(b) => b
    None => true
  }
  let advance_after = match @oxml.optional_attr(attrs, "advTm") {
    Some(s) => @oxml.parse_signed_int(s)
    None => None
  }
  let mut kind : TransitionKind = NoEffect
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == @oxml.presentation_ns {
          match transition_kind_from(child.local_name, child_attrs) {
            // A modelled effect element is a leaf (attribute-only); consume its
            // (empty) subtree to balance the reader.
            Some(k) => {
              kind = k
              skip_subtree(r)
            }
            // <p:sndAc>, <p:extLst>, or anything else — preserve verbatim.
            None =>
              extension.push(collect_subtree_unknown(r, child, child_attrs))
          }
        } else {
          extension.push(collect_subtree_unknown(r, child, child_attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { kind, speed, advance_on_click, advance_after, extension }
}

///|
/// Map a `<p:transition>` choice-child local name + attributes to a typed
/// `TransitionKind`. Returns `None` for non-effect children (`sndAc`,
/// `extLst`, …) so the caller preserves them in `extension`. Direction /
/// orientation attributes default to the schema's first value when absent.
fn transition_kind_from(
  local_name : String,
  attrs : Array[(@xml.QName, String)],
) -> TransitionKind? {
  let dir = @oxml.optional_attr_or(attrs, "dir", "")
  match local_name {
    "blinds" => Some(Blinds(TransitionOrientation::from_xml(dir)))
    "checker" => Some(Checker(TransitionOrientation::from_xml(dir)))
    "circle" => Some(Circle)
    "comb" => Some(Comb(TransitionOrientation::from_xml(dir)))
    "cover" => Some(Cover(TransitionDirection::from_xml(dir)))
    "cut" => Some(Cut(@oxml.bool_attr_opt(attrs, "thruBlk").unwrap_or(false)))
    "diamond" => Some(Diamond)
    "dissolve" => Some(Dissolve)
    "fade" => Some(Fade(@oxml.bool_attr_opt(attrs, "thruBlk").unwrap_or(false)))
    "newsflash" => Some(Newsflash)
    "plus" => Some(Plus)
    "pull" => Some(Pull(TransitionDirection::from_xml(dir)))
    "push" => Some(Push(TransitionSide::from_xml(dir)))
    "random" => Some(Random)
    "randomBar" => Some(RandomBar(TransitionOrientation::from_xml(dir)))
    "split" =>
      Some(
        Split(
          TransitionOrientation::from_xml(
            @oxml.optional_attr_or(attrs, "orient", ""),
          ),
          TransitionInOut::from_xml(dir),
        ),
      )
    "strips" => Some(Strips(TransitionCorner::from_xml(dir)))
    "wedge" => Some(Wedge)
    "wheel" =>
      Some(
        Wheel(
          match @oxml.optional_attr(attrs, "spokes") {
            Some(s) =>
              @oxml.parse_signed_int(s).unwrap_or(transition_default_spokes)
            None => transition_default_spokes
          },
        ),
      )
    "wipe" => Some(Wipe(TransitionSide::from_xml(dir)))
    "zoom" => Some(Zoom(TransitionInOut::from_xml(dir)))
    _ => None
  }
}

///|
fn parse_c_sld(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
  shapes : Array[Shape],
  extension : Array[@xml.XmlElement],
) -> (String, Background?) raise SlideError {
  let name = optional_attr(attrs, "name")
  let mut background : Background? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, child_attrs))
        } else {
          match child.local_name {
            "bg" => background = Some(parse_bg(r))
            "spTree" => parse_sp_tree(r, shapes, extension)
            // custDataLst, extLst, controls, and any future <p:cSld> child.
            _ => extension.push(collect_subtree_unknown(r, child, child_attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  (name, background)
}

///|
/// Parse `<p:bg>` (CT_Background) — a choice of `<p:bgPr>` (explicit fill)
/// or `<p:bgRef>` (theme style-matrix reference). Lifts the background out
/// of `extension` into the typed `Slide.background` field (roadmap A7).
fn parse_bg(r : @xml.XmlReader) -> Background raise SlideError {
  let mut bg : Background? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == @oxml.presentation_ns && child.local_name == "bgPr" {
          bg = Some(parse_bg_pr(r, child_attrs))
        } else if child.uri == @oxml.presentation_ns &&
          child.local_name == "bgRef" {
          bg = Some(parse_bg_ref(r, child_attrs))
        } else {
          // <p:bg> is a strict bgPr|bgRef choice per ECMA-376; nothing else
          // is valid, but skip defensively rather than mis-model.
          skip_subtree(r)
        }
      EndElement(_) => break
      _ => ()
    }
  }
  match bg {
    Some(b) => b
    None => raise Malformed("<p:bg> has neither <p:bgPr> nor <p:bgRef>")
  }
}

///|
/// Parse `<p:bgPr>` (CT_BackgroundProperties): a required fill, optional
/// `<a:effectLst>`, the `shadeToTitle` attribute, and any unmodelled
/// children preserved per ADR-004.
fn parse_bg_pr(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Background raise SlideError {
  let shade = optional_attr(attrs, "shadeToTitle")
  let shade_to_title = shade == "1" || shade == "true"
  let mut fill : @oxml.Fill? = None
  let mut effects : @oxml.EffectList? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == @oxml.drawing_ns &&
          (
            child.local_name == "noFill" ||
            child.local_name == "solidFill" ||
            child.local_name == "gradFill" ||
            child.local_name == "blipFill" ||
            child.local_name == "pattFill"
          ) {
          fill = Some(
            @oxml.parse_fill(r, child, child_attrs) catch {
              e =>
                raise Malformed("a:" + child.local_name + ": " + e.to_string())
            },
          )
        } else if child.uri == @oxml.drawing_ns &&
          child.local_name == "effectLst" {
          effects = Some(
            @oxml.parse_effect_list(r) catch {
              e => raise Malformed("a:effectLst: " + e.to_string())
            },
          )
        } else {
          // grpFill (not modelled by @oxml.Fill), effectDag, extLst,
          // foreign-namespace children — preserve verbatim.
          extension.push(collect_subtree_unknown(r, child, child_attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
  Properties({ fill, shade_to_title, effects, extension })
}

///|
/// Parse `<p:bgRef>` (CT_StyleMatrixReference): the required `idx` attribute
/// plus a single colour child resolving the referenced style's `phClr`.
fn parse_bg_ref(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Background raise SlideError {
  let idx = parse_int_attr(attrs, "idx")
  let mut color : @oxml.Color? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == @oxml.drawing_ns {
          color = Some(
            @oxml.parse_color_element(r, child, child_attrs) catch {
              e =>
                raise Malformed("a:" + child.local_name + ": " + e.to_string())
            },
          )
        } else {
          skip_subtree(r)
        }
      EndElement(_) => break
      _ => ()
    }
  }
  match color {
    Some(c) => StyleReference(idx, c)
    None => raise Malformed("<p:bgRef> is missing its colour child")
  }
}

///|
fn parse_sp_tree(
  r : @xml.XmlReader,
  shapes : Array[Shape],
  extension : Array[@xml.XmlElement],
) -> Unit raise SlideError {
  // The first two children of every spTree are nvGrpSpPr + grpSpPr —
  // metadata for the implicit root group. We don't model them as part
  // of the shape list, but per ADR-004 they round-trip through the
  // slide-level `extension` so writers can re-emit them.
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "nvGrpSpPr" | "grpSpPr" =>
              extension.push(collect_subtree_unknown(r, child, attrs))
            "sp" => shapes.push(AutoShape(parse_auto_shape(r, attrs)))
            "pic" => shapes.push(Picture(parse_picture(r)))
            "cxnSp" => shapes.push(Connector(parse_connector(r)))
            "grpSp" => shapes.push(Group(parse_group_shape(r)))
            "graphicFrame" => shapes.push(GraphicFrame(parse_graphic_frame(r)))
            // contentPart (extensions) and any future shape kind we
            // haven't typed yet round-trip via the captured XML.
            _ => shapes.push(Unknown(collect_subtree_unknown(r, child, attrs)))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
}

///|
/// Thin wrapper around `@oxml.collect_subtree` that maps the neutral
/// `XmlReadError` into `SlideError::Malformed`. Centralises the conversion
/// so every shape parser uses the same one-liner.
fn collect_subtree_unknown(
  r : @xml.XmlReader,
  name : @xml.QName,
  attrs : Array[(@xml.QName, String)],
) -> @xml.XmlElement raise SlideError {
  @oxml.collect_subtree(r, name, attrs) catch {
    e => raise Malformed(e.to_string())
  }
}

// --- Connector ---

///|
fn parse_connector(r : @xml.XmlReader) -> Connector raise SlideError {
  let mut id = 0
  let mut name = ""
  let mut transform : Transform? = None
  let mut geometry : Geometry? = None
  let mut stroke : @oxml.Stroke? = None
  let mut effects : @oxml.EffectList? = None
  let mut start : ConnectionEnd? = None
  let mut end : ConnectionEnd? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "nvCxnSpPr" => {
              let (parsed_id, parsed_name, st, en) = parse_nv_cxn_sp_pr(
                r, extension,
              )
              id = parsed_id
              name = parsed_name
              start = st
              end = en
            }
            "spPr" => {
              let (xfrm, geom, fl, ln, fx) = parse_sp_pr(r, extension)
              transform = xfrm
              geometry = geom
              stroke = ln
              effects = fx
              // Connectors don't carry a fill field in the typed
              // model today; if one is present it round-trips via
              // the connector's `extension` array.
              match fl {
                Some(_) => () // ignore for now; connectors are line-only by spec
                None => ()
              }
            }
            // style, extLst, and any future <p:cxnSp> children.
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { id, name, transform, geometry, stroke, effects, start, end, extension }
}

///|
fn parse_nv_cxn_sp_pr(
  r : @xml.XmlReader,
  parent_extension : Array[@xml.XmlElement],
) -> (Int, String, ConnectionEnd?, ConnectionEnd?) raise SlideError {
  let mut id = 0
  let mut name = ""
  let mut start : ConnectionEnd? = None
  let mut end : ConnectionEnd? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.presentation_ns {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "cNvPr" => {
              id = parse_int_attr(attrs, "id")
              name = optional_attr(attrs, "name")
              // <p:cNvPr> body (hlinkClick / hlinkHover / extLst) is
              // preserved on the surrounding shape's extension.
              parent_extension.push(collect_subtree_unknown(r, child, attrs))
            }
            "cNvCxnSpPr" => {
              let (st, en) = parse_cxn_sp_locks(r, parent_extension)
              start = st
              end = en
            }
            // nvPr — placeholder/extension info; preserved verbatim.
            _ => parent_extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  (id, name, start, end)
}

///|
/// Parse the body of `<p:cNvCxnSpPr>` looking for `<a:stCxn>` and
/// `<a:endCxn>` children. Other children (spec defines `<a:cxnSpLocks>`
/// and `<a:extLst>` here) land on `parent_extension`.
fn parse_cxn_sp_locks(
  r : @xml.XmlReader,
  parent_extension : Array[@xml.XmlElement],
) -> (ConnectionEnd?, ConnectionEnd?) raise SlideError {
  let mut start : ConnectionEnd? = None
  let mut end : ConnectionEnd? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri == @oxml.drawing_ns {
          match child.local_name {
            "stCxn" => {
              start = Some(parse_connection_end(attrs))
              skip_subtree(r) // <a:stCxn> is a leaf
            }
            "endCxn" => {
              end = Some(parse_connection_end(attrs))
              skip_subtree(r) // <a:endCxn> is a leaf
            }
            // cxnSpLocks (rare on real slides), extLst, others.
            _ => parent_extension.push(collect_subtree_unknown(r, child, attrs))
          }
        } else {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
  (start, end)
}

///|
fn parse_connection_end(
  attrs : Array[(@xml.QName, String)],
) -> ConnectionEnd raise SlideError {
  { shape_id: parse_int_attr(attrs, "id"), idx: parse_int_attr(attrs, "idx") }
}

// --- GroupShape (recursive) ---

///|
fn parse_group_shape(r : @xml.XmlReader) -> GroupShape raise SlideError {
  let mut id = 0
  let mut name = ""
  let mut transform : Transform? = None
  let mut child_offset : Point? = None
  let mut child_extent : Size? = None
  let children : Array[Shape] = []
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, child_attrs))
        } else {
          match child.local_name {
            "nvGrpSpPr" => {
              // Same shape as nvSpPr/nvPicPr's first three children;
              // re-use that extractor and discard the placeholder slot.
              let (parsed_id, parsed_name, _) = parse_nv_sp_pr(r, extension)
              id = parsed_id
              name = parsed_name
            }
            "grpSpPr" => {
              let (xfrm, ch_off, ch_ext) = parse_grp_sp_pr(r, extension)
              transform = xfrm
              child_offset = ch_off
              child_extent = ch_ext
            }
            // Recurse into child shapes — same dispatch as parse_sp_tree.
            "sp" => children.push(AutoShape(parse_auto_shape(r, child_attrs)))
            "pic" => children.push(Picture(parse_picture(r)))
            "cxnSp" => children.push(Connector(parse_connector(r)))
            "grpSp" => children.push(Group(parse_group_shape(r)))
            "graphicFrame" =>
              children.push(GraphicFrame(parse_graphic_frame(r)))
            // contentPart and future shape kinds — preserve the full
            // subtree.
            _ =>
              children.push(
                Unknown(collect_subtree_unknown(r, child, child_attrs)),
              )
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { id, name, transform, child_offset, child_extent, children, extension }
}

///|
/// Parse `<p:grpSpPr>` body. Returns `(transform?, child_offset?,
/// child_extent?)`. The child-coordinate fields come from `<a:chOff>` /
/// `<a:chExt>` which only appear inside group-shape `xfrm`s.
/// `<a:solidFill>` / `<a:gradFill>` / `<a:pattFill>` / `<a:ln>` /
/// `<a:effectLst>` / `<a:scene3d>` / `<a:extLst>` are not yet modelled
/// on group shapes — they round-trip via `parent_extension`.
fn parse_grp_sp_pr(
  r : @xml.XmlReader,
  parent_extension : Array[@xml.XmlElement],
) -> (Transform?, Point?, Size?) raise SlideError {
  let mut transform : Transform? = None
  let mut child_offset : Point? = None
  let mut child_extent : Size? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.drawing_ns {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        } else if child.local_name == "xfrm" {
          let (t, co, ce) = parse_group_xfrm(r, parent_extension)
          transform = t
          child_offset = co
          child_extent = ce
        } else {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
  (transform, child_offset, child_extent)
}

///|
/// Parse a group-shape `<a:xfrm>` body — accepts `<a:off>` / `<a:ext>`
/// (the group's own placement) plus `<a:chOff>` / `<a:chExt>` (the child
/// coordinate space). All four are optional; missing pairs collapse to
/// `None`.
fn parse_group_xfrm(
  r : @xml.XmlReader,
  parent_extension : Array[@xml.XmlElement],
) -> (Transform?, Point?, Size?) raise SlideError {
  let mut offset : Point? = None
  let mut extent : Size? = None
  let mut child_offset : Point? = None
  let mut child_extent : Size? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.drawing_ns {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "off" => {
              offset = Some(parse_point_xy(attrs))
              skip_subtree(r) // leaf
            }
            "ext" => {
              extent = Some(parse_size_xy(attrs))
              skip_subtree(r) // leaf
            }
            "chOff" => {
              child_offset = Some(parse_point_xy(attrs))
              skip_subtree(r) // leaf
            }
            "chExt" => {
              child_extent = Some(parse_size_xy(attrs))
              skip_subtree(r) // leaf
            }
            _ => parent_extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  let transform = match (offset, extent) {
    (Some(o), Some(e)) => Some({ offset: o, extent: e })
    _ => None
  }
  (transform, child_offset, child_extent)
}

///|
fn parse_point_xy(
  attrs : Array[(@xml.QName, String)],
) -> Point raise SlideError {
  {
    x: @units.Emu(parse_int64_attr(attrs, "x")),
    y: @units.Emu(parse_int64_attr(attrs, "y")),
  }
}

///|
fn parse_size_xy(attrs : Array[(@xml.QName, String)]) -> Size raise SlideError {
  {
    cx: @units.Emu(parse_int64_attr(attrs, "cx")),
    cy: @units.Emu(parse_int64_attr(attrs, "cy")),
  }
}

// --- Picture ---

///|
fn parse_picture(r : @xml.XmlReader) -> Picture raise SlideError {
  let mut id = 0
  let mut name = ""
  let mut transform : Transform? = None
  let mut geometry : Geometry? = None
  let mut stroke : @oxml.Stroke? = None
  let mut effects : @oxml.EffectList? = None
  let mut blip_fill : @oxml.BlipFill? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "nvPicPr" => {
              // Same shape as nvSpPr (cNvPr + cNvPicPr + nvPr); reuse the
              // (id, name, _) extractor and discard the placeholder slot.
              let (parsed_id, parsed_name, _) = parse_nv_sp_pr(r, extension)
              id = parsed_id
              name = parsed_name
            }
            "blipFill" => {
              // Delegate to the shared @oxml.parse_fill, which handles
              // blip / srcRect / stretch / tile uniformly.
              let f = @oxml.parse_fill(r, child, attrs) catch {
                e => raise Malformed("p:blipFill: " + e.to_string())
              }
              blip_fill = match f {
                BlipFillVariant(b) => Some(b)
                _ => raise Malformed("p:blipFill resolved to non-blip fill")
              }
            }
            "spPr" => {
              let (xfrm, geom, _, ln, fx) = parse_sp_pr(r, extension)
              transform = xfrm
              geometry = geom
              stroke = ln
              effects = fx
              // Pictures carry their fill via `blipFill` outside
              // `spPr`; any solidFill etc. inside spPr is unusual
              // and we currently drop it (it round-trips through
              // `extension` for foreign-ns siblings; native ones
              // would need a typed picture fill).
            }
            // style, extLst, and any future <p:pic> children.
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  let bf = match blip_fill {
    Some(b) => b
    None => raise Malformed("<p:pic> is missing <p:blipFill>")
  }
  {
    id,
    name,
    transform,
    geometry,
    stroke,
    effects,
    blip_fill: bf,
    // Media is lifted only by builders; parsed media refs round-trip via
    // `extension` (ADR-004). See `media.mbt`.
    media: None,
    extension,
  }
}

// --- AutoShape ---

///|
fn parse_auto_shape(
  r : @xml.XmlReader,
  _ : Array[(@xml.QName, String)],
) -> AutoShape raise SlideError {
  let mut id = 0
  let mut name = ""
  let mut placeholder : Placeholder? = None
  let mut transform : Transform? = None
  let mut geometry : Geometry? = None
  let mut fill : @oxml.Fill? = None
  let mut stroke : @oxml.Stroke? = None
  let mut effects : @oxml.EffectList? = None
  let mut text_body : TextBody? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "nvSpPr" => {
              let (parsed_id, parsed_name, ph) = parse_nv_sp_pr(r, extension)
              id = parsed_id
              name = parsed_name
              placeholder = ph
            }
            "spPr" => {
              let (xfrm, geom, fl, ln, fx) = parse_sp_pr(r, extension)
              transform = xfrm
              geometry = geom
              fill = fl
              stroke = ln
              effects = fx
            }
            "txBody" => text_body = Some(parse_text_body(r))
            // style, extLst, and any future <p:sp> children.
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  {
    id,
    name,
    placeholder,
    transform,
    geometry,
    fill,
    stroke,
    effects,
    text_body,
    extension,
  }
}

///|
/// Parse an integer attribute in 1/60000 of a degree (`ST_Angle`) and
/// lift to `Angle`. Returns `None` for absent / unparseable.
fn parse_angle_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Angle? {
  @oxml.angle_attr_opt(attrs, name)
}

///|
/// Parse a decimal integer attribute and lift to `Emu`. Returns `None`
/// for absent or unparseable values.
fn parse_emu_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Emu? {
  @oxml.emu_attr_opt(attrs, name)
}

///|
/// Parse an attribute encoded as 1/1000 of a percent (`lineSpacing` and
/// similar) and lift to `Percentage`.
fn parse_thousandths_pct_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Percentage? {
  @oxml.pct_attr_opt(attrs, name)
}

///|
/// Parse an attribute encoded as 1/100 of a point (`spaceBefore`,
/// `spaceAfter`) and lift to `Pt`.
fn parse_hundredths_pt_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Pt? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match @oxml.parse_signed_int(kv.1) {
        Some(n) => return Some(@units.Pt(n.to_double() / 100.0))
        None => return None
      }
    }
  }
  None
}

///|
/// Look up an attribute and map its string value through `from_xml`.
/// Absent attribute returns `None`; unrecognised string value returns
/// `None` (caller can decide whether to be strict elsewhere).
fn[T] parse_enum_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
  from_xml : (String) -> T?,
) -> T? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return from_xml(kv.1)
    }
  }
  None
}

///|
/// Extract the `r:id` value from a set of attributes (OOXML
/// relationships namespace).
fn extract_rid(attrs : Array[(@xml.QName, String)]) -> String {
  for kv in attrs {
    if kv.0.uri == @oxml.office_relationships_ns && kv.0.local_name == "id" {
      return kv.1
    }
  }
  ""
}

///|
/// Consume events until the EndElement closing the current text-bearing
/// element. Text and CData are appended to `buf`; nested elements are
/// not expected inside `<a:t>` per spec, but we handle them defensively.
fn collect_text_until_end(
  r : @xml.XmlReader,
  buf : StringBuilder,
) -> Unit raise SlideError {
  let mut depth = 1
  while depth > 0 {
    let ev = next_event(r)
    match ev {
      StartElement(_, _) => depth = depth + 1
      EndElement(_) => depth = depth - 1
      Text(s) => buf.write_string(s)
      CData(s) => buf.write_string(s)
    }
  }
}
//|

///|
fn parse_nv_sp_pr(
  r : @xml.XmlReader,
  parent_extension : Array[@xml.XmlElement],
) -> (Int, String, Placeholder?) raise SlideError {
  let mut id = 0
  let mut name = ""
  let mut placeholder : Placeholder? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.presentation_ns {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "cNvPr" => {
              id = parse_int_attr(attrs, "id")
              name = optional_attr(attrs, "name")
              // <p:cNvPr> can carry <a:hlinkClick> / <a:hlinkHover> /
              // <a:extLst>. Capture the whole subtree so those survive.
              parent_extension.push(collect_subtree_unknown(r, child, attrs))
            }
            "nvPr" => placeholder = parse_nv_pr(r, parent_extension)
            // cNvSpPr / cNvPicPr / cNvCxnSpPr / cNvGrpSpPr — locks live
            // here; preserve verbatim.
            _ => parent_extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  (id, name, placeholder)
}

///|
fn parse_nv_pr(
  r : @xml.XmlReader,
  parent_extension : Array[@xml.XmlElement],
) -> Placeholder? raise SlideError {
  let mut ph : Placeholder? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri == @oxml.presentation_ns && child.local_name == "ph" {
          ph = Some({
            ph_type: optional_attr(attrs, "type"),
            idx: parse_int_attr_default(attrs, "idx", 0),
          })
          skip_subtree(r) // <p:ph> is a leaf per spec
        } else {
          // <p:audioFile>, <p:videoFile>, <p:custDataLst>, <p:extLst>,
          // foreign-namespace siblings — all preserved.
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
  ph
}

///|
/// Look inside `<p:spPr>` for `<a:xfrm>`, geometry, the fill choice
/// (`<a:solidFill>` / `<a:gradFill>` / `<a:pattFill>` / `<a:blipFill>`
/// / `<a:noFill>`), `<a:ln>`, and `<a:effectLst>`. Other children
/// (`<a:scene3d>`, `<a:sp3d>`, `<a:extLst>`, foreign-namespace) land
/// on `parent_extension` so they round-trip per ADR-004.
fn parse_sp_pr(
  r : @xml.XmlReader,
  parent_extension : Array[@xml.XmlElement],
) -> (Transform?, Geometry?, @oxml.Fill?, @oxml.Stroke?, @oxml.EffectList?) raise SlideError {
  let mut transform : Transform? = None
  let mut geometry : Geometry? = None
  let mut fill : @oxml.Fill? = None
  let mut stroke : @oxml.Stroke? = None
  let mut effects : @oxml.EffectList? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.drawing_ns {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "xfrm" => transform = Some(parse_xfrm(r, parent_extension))
            "prstGeom" =>
              geometry = Some(parse_prst_geom(r, attrs, parent_extension))
            "custGeom" =>
              // Typed `<a:custGeom>` parser. Path commands, guides,
              // connection sites, and rect lift into the
              // `CustomGeometry` AST; unknown siblings round-trip via
              // its own `extension` per ADR-004.
              geometry = Some(Custom(parse_custom_geometry(r)))
            // EG_FillProperties choice — at most one fires.
            "noFill"
            | "solidFill"
            | "gradFill"
            | "blipFill"
            | "pattFill"
            | "grpFill" => {
              let f = @oxml.parse_fill(r, child, attrs) catch {
                e =>
                  raise Malformed(
                    "a:" + child.local_name + ": " + e.to_string(),
                  )
              }
              fill = Some(f)
            }
            "ln" => {
              let s = @oxml.parse_stroke(r, attrs) catch {
                e => raise Malformed("a:ln: " + e.to_string())
              }
              stroke = Some(s)
            }
            "effectLst" => {
              let e = @oxml.parse_effect_list(r) catch {
                err => raise Malformed("a:effectLst: " + err.to_string())
              }
              effects = Some(e)
            }
            // scene3d / sp3d / extLst / effectDag / fillOverlay etc. —
            // not yet modelled, preserved per ADR-004.
            _ => parent_extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  (transform, geometry, fill, stroke, effects)
}

///|
/// Parse `<a:prstGeom prst="…">` plus its `<a:avLst>` adjustment values.
/// Any unrecognised sibling of `<a:avLst>` (the spec defines none, but
/// extension-aware tools emit `<a:extLst>` etc.) lands on
/// `parent_extension`.
fn parse_prst_geom(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
  parent_extension : Array[@xml.XmlElement],
) -> Geometry raise SlideError {
  let prst_raw = require_attr(attrs, "prst")
  let preset = PresetShape::from_xml(prst_raw)
  let adjustments : Array[ShapeAdjustValue] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == @oxml.drawing_ns && child.local_name == "avLst" {
          parse_av_lst(r, adjustments, parent_extension)
        } else {
          parent_extension.push(collect_subtree_unknown(r, child, child_attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
  Preset(preset, adjustments)
}

///|
/// Parse the `<a:avLst>` body — zero or more `<a:gd name="…" fmla="…"/>`.
/// Unknown children of `<a:avLst>` (the spec defines only `<a:gd>` but
/// foreign-namespace extensions appear in the wild) land on
/// `parent_extension`.
fn parse_av_lst(
  r : @xml.XmlReader,
  out : Array[ShapeAdjustValue],
  parent_extension : Array[@xml.XmlElement],
) -> Unit raise SlideError {
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri == @oxml.drawing_ns && child.local_name == "gd" {
          let name = require_attr(attrs, "name")
          let fmla = require_attr(attrs, "fmla")
          out.push({ name, fmla })
          skip_subtree(r) // <a:gd> is a leaf
        } else {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
}

///|
fn parse_xfrm(
  r : @xml.XmlReader,
  parent_extension : Array[@xml.XmlElement],
) -> Transform raise SlideError {
  let mut offset : Point? = None
  let mut extent : Size? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.drawing_ns {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "off" => {
              offset = Some({
                x: @units.Emu(parse_int64_attr(attrs, "x")),
                y: @units.Emu(parse_int64_attr(attrs, "y")),
              })
              skip_subtree(r) // <a:off> is a leaf per spec
            }
            "ext" => {
              extent = Some({
                cx: @units.Emu(parse_int64_attr(attrs, "cx")),
                cy: @units.Emu(parse_int64_attr(attrs, "cy")),
              })
              skip_subtree(r) // <a:ext> is a leaf per spec
            }
            // chOff/chExt belong on group-shape xfrm; not modelled here.
            // Capture so they survive round-trip if a writer puts them
            // on a non-group xfrm.
            _ => parent_extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  match (offset, extent) {
    (Some(o), Some(e)) => { offset: o, extent: e }
    _ =>
      raise Malformed("<a:xfrm> on <p:sp> must have both <a:off> and <a:ext>")
  }
}

// --- clrMapOvr (mirror of @slide_master's logic) ---

///|
fn parse_clr_map_ovr(
  r : @xml.XmlReader,
  parent_extension : Array[@xml.XmlElement],
) -> @slide_master.ClrMapOverride raise SlideError {
  let mut result : @slide_master.ClrMapOverride = MasterMapping
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri == @oxml.drawing_ns &&
          child.local_name == "overrideClrMapping" {
          let cm = @slide_master.parse_clr_map_attrs(attrs) catch {
            e => raise Malformed("overrideClrMapping invalid: " + e.to_string())
          }
          result = Override(cm)
          skip_subtree(r) // <a:overrideClrMapping> is attribute-only
        } else if child.uri == @oxml.drawing_ns &&
          child.local_name == "masterClrMapping" {
          // Explicit master mapping — already the default. Leaf element.
          skip_subtree(r)
        } else {
          // Foreign-namespace or other unmodelled child.
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
  result
}

// --- shared helpers (mirror of @slide_master / @theme — see ADR-009 below
// for the planned consolidation) ---

///|
fn skip_subtree(r : @xml.XmlReader) -> Unit raise SlideError {
  let mut depth = 1
  while depth > 0 {
    let ev = next_event(r)
    match ev {
      StartElement(_, _) => depth = depth + 1
      EndElement(_) => depth = depth - 1
      _ => ()
    }
  }
}

///|
fn next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise SlideError {
  let event = r.next() catch { e => raise wrap_xml(e) }
  match event {
    Some(e) => e
    None => raise Malformed("unexpected end of input")
  }
}

///|
fn expect_pml(name : @xml.QName, expected : String) -> Unit raise SlideError {
  if name.uri != @oxml.presentation_ns || name.local_name != expected {
    raise Malformed(
      "expected <p:" + expected + "> but got <" + name.local_name + ">",
    )
  }
}

///|
fn optional_attr(attrs : Array[(@xml.QName, String)], name : String) -> String {
  @oxml.optional_attr_or(attrs, name, "")
}

///|
fn parse_int_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> Int raise SlideError {
  let raw = require_attr(attrs, name)
  match @oxml.parse_signed_int(raw) {
    Some(n) => n
    None => raise Malformed("attribute " + name + " is not an integer: " + raw)
  }
}

///|
fn parse_int_attr_default(
  attrs : Array[(@xml.QName, String)],
  name : String,
  default : Int,
) -> Int {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return @oxml.parse_signed_int(kv.1).unwrap_or(default)
    }
  }
  default
}

///|
fn parse_int64_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> Int64 raise SlideError {
  let raw = require_attr(attrs, name)
  match @oxml.parse_signed_int64(raw) {
    Some(n) => n
    None => raise Malformed("attribute " + name + " is not an integer: " + raw)
  }
}

///|
fn require_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> String raise SlideError {
  @oxml.require_attr(attrs, name, name) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
/// Decode UTF-8 bytes via the shared `@oxml.bytes_to_string` helper,
/// mapping any `Utf8Error` into the domain error variant.
fn bytes_to_string(bytes : FixedArray[Byte]) -> String raise SlideError {
  @oxml.bytes_to_string(bytes) catch {
    e => raise Malformed(e.to_string())
  }
}
