// Slide XML reader.
//
// Same recursive-descent contract as `@theme` and `@slide_master`: each
// `parse_*` helper is called *just after* its element's StartElement has
// been consumed and consumes events through the matching EndElement.
// `skip_subtree` swallows everything we don't yet model.

///|
/// Parse a slide part from raw XML bytes.
pub fn Slide::parse(bytes : FixedArray[Byte]) -> Slide raise SlideError {
  parse_slide_xml(bytes_to_string(bytes))
}

///|
fn parse_slide_xml(xml : String) -> Slide raise SlideError {
  let r = @xml.XmlReader::new(xml)
  let event = next_event(r)
  match event {
    StartElement(name, _) => expect_pml(name, "sld")
    _ => raise Malformed("expected <p:sld> root element")
  }
  let mut slide_name = ""
  let shapes : Array[Shape] = []
  let mut clr_map_override : @slide_master.ClrMapOverride = MasterMapping
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
            "cSld" => slide_name = parse_c_sld(r, attrs, shapes, extension)
            "clrMapOvr" => clr_map_override = parse_clr_map_ovr(r)
            // transition, timing, custDataLst, extLst, and any future
            // <p:sld> children we don't yet model.
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { name: slide_name, shapes, clr_map_override, extension }
}

///|
fn parse_c_sld(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
  shapes : Array[Shape],
  extension : Array[@xml.XmlElement],
) -> String raise SlideError {
  let name = optional_attr(attrs, "name")
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, child_attrs))
        } else {
          match child.local_name {
            "spTree" => parse_sp_tree(r, shapes, extension)
            // bg, custDataLst, extLst, and any future <p:cSld> children.
            _ => extension.push(collect_subtree_unknown(r, child, child_attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  name
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
            // graphicFrame (tables / charts / SmartArt) and contentPart
            // (extensions) are not yet typed — preserve the full XML so
            // they round-trip verbatim.
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
              let (parsed_id, parsed_name, st, en) = parse_nv_cxn_sp_pr(r)
              id = parsed_id
              name = parsed_name
              start = st
              end = en
            }
            "spPr" => {
              let (xfrm, geom, ln, fx) = parse_sp_pr(r)
              transform = xfrm
              geometry = geom
              stroke = ln
              effects = fx
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
) -> (Int, String, ConnectionEnd?, ConnectionEnd?) raise SlideError {
  let mut id = 0
  let mut name = ""
  let mut start : ConnectionEnd? = None
  let mut end : ConnectionEnd? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri == @oxml.presentation_ns {
          match child.local_name {
            "cNvPr" => {
              id = parse_int_attr(attrs, "id")
              name = optional_attr(attrs, "name")
              skip_subtree(r)
            }
            "cNvCxnSpPr" => {
              let (st, en) = parse_cxn_sp_locks(r)
              start = st
              end = en
            }
            // nvPr — placeholder/extension info, not modelled here
            _ => skip_subtree(r)
          }
        } else {
          skip_subtree(r)
        }
      EndElement(_) => break
      _ => ()
    }
  }
  (id, name, start, end)
}

///|
/// Parse the body of `<p:cNvCxnSpPr>` looking for `<a:stCxn>` and
/// `<a:endCxn>` children.
fn parse_cxn_sp_locks(
  r : @xml.XmlReader,
) -> (ConnectionEnd?, ConnectionEnd?) raise SlideError {
  let mut start : ConnectionEnd? = None
  let mut end : ConnectionEnd? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.drawing_ns {
          match child.local_name {
            "stCxn" => start = Some(parse_connection_end(attrs))
            "endCxn" => end = Some(parse_connection_end(attrs))
            _ => ()
          }
        }
        skip_subtree(r)
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
              let (parsed_id, parsed_name, _) = parse_nv_sp_pr(r)
              id = parsed_id
              name = parsed_name
            }
            "grpSpPr" => {
              let (xfrm, ch_off, ch_ext) = parse_grp_sp_pr(r)
              transform = xfrm
              child_offset = ch_off
              child_extent = ch_ext
            }
            // Recurse into child shapes — same dispatch as parse_sp_tree.
            "sp" => children.push(AutoShape(parse_auto_shape(r, child_attrs)))
            "pic" => children.push(Picture(parse_picture(r)))
            "cxnSp" => children.push(Connector(parse_connector(r)))
            "grpSp" => children.push(Group(parse_group_shape(r)))
            // graphicFrame / contentPart — preserve the full subtree.
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
fn parse_grp_sp_pr(
  r : @xml.XmlReader,
) -> (Transform?, Point?, Size?) raise SlideError {
  let mut transform : Transform? = None
  let mut child_offset : Point? = None
  let mut child_extent : Size? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, _) =>
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
        } else if child.local_name == "xfrm" {
          let (t, co, ce) = parse_group_xfrm(r)
          transform = t
          child_offset = co
          child_extent = ce
        } else {
          // fill / line / effects / extLst — later phases
          skip_subtree(r)
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
) -> (Transform?, Point?, Size?) raise SlideError {
  let mut offset : Point? = None
  let mut extent : Size? = None
  let mut child_offset : Point? = None
  let mut child_extent : Size? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.drawing_ns {
          match child.local_name {
            "off" => offset = Some(parse_point_xy(attrs))
            "ext" => extent = Some(parse_size_xy(attrs))
            "chOff" => child_offset = Some(parse_point_xy(attrs))
            "chExt" => child_extent = Some(parse_size_xy(attrs))
            _ => ()
          }
        }
        skip_subtree(r)
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
              let (parsed_id, parsed_name, _) = parse_nv_sp_pr(r)
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
              let (xfrm, geom, ln, fx) = parse_sp_pr(r)
              transform = xfrm
              geometry = geom
              stroke = ln
              effects = fx
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
  { id, name, transform, geometry, stroke, effects, blip_fill: bf, extension }
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
              let (parsed_id, parsed_name, ph) = parse_nv_sp_pr(r)
              id = parsed_id
              name = parsed_name
              placeholder = ph
            }
            "spPr" => {
              let (xfrm, geom, ln, fx) = parse_sp_pr(r)
              transform = xfrm
              geometry = geom
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
) -> (Int, String, Placeholder?) raise SlideError {
  let mut id = 0
  let mut name = ""
  let mut placeholder : Placeholder? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri != @oxml.presentation_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "cNvPr" => {
            id = parse_int_attr(attrs, "id")
            name = optional_attr(attrs, "name")
            skip_subtree(r)
          }
          "nvPr" => placeholder = parse_nv_pr(r)
          // cNvSpPr — locks etc., not modeled in skeleton
          _ => skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  (id, name, placeholder)
}

///|
fn parse_nv_pr(r : @xml.XmlReader) -> Placeholder? raise SlideError {
  let mut ph : Placeholder? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.presentation_ns && child.local_name == "ph" {
          ph = Some({
            ph_type: optional_attr(attrs, "type"),
            idx: parse_int_attr_default(attrs, "idx", 0),
          })
        }
        skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
  ph
}

///|
/// Look inside `<p:spPr>` for `<a:xfrm>`, geometry, `<a:ln>`, and
/// `<a:effectLst>`. Other children (`a:solidFill`, `a:scene3d`, …) are
/// skipped — shape-level fill will arrive in a later slice.
fn parse_sp_pr(
  r : @xml.XmlReader,
) -> (Transform?, Geometry?, @oxml.Stroke?, @oxml.EffectList?) raise SlideError {
  let mut transform : Transform? = None
  let mut geometry : Geometry? = None
  let mut stroke : @oxml.Stroke? = None
  let mut effects : @oxml.EffectList? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
        } else {
          match child.local_name {
            "xfrm" => transform = Some(parse_xfrm(r))
            "prstGeom" => geometry = Some(parse_prst_geom(r, attrs))
            "custGeom" => {
              skip_subtree(r) // path data not yet modelled
              geometry = Some(Custom)
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
            _ => skip_subtree(r)
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  (transform, geometry, stroke, effects)
}

///|
/// Parse `<a:prstGeom prst="…">` plus its `<a:avLst>` adjustment values.
fn parse_prst_geom(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Geometry raise SlideError {
  let prst_raw = require_attr(attrs, "prst")
  let preset = PresetShape::from_xml(prst_raw)
  let adjustments : Array[ShapeAdjustValue] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, _) =>
        if child.uri == @oxml.drawing_ns && child.local_name == "avLst" {
          parse_av_lst(r, adjustments)
        } else {
          skip_subtree(r)
        }
      EndElement(_) => break
      _ => ()
    }
  }
  Preset(preset, adjustments)
}

///|
/// Parse the `<a:avLst>` body — zero or more `<a:gd name="…" fmla="…"/>`.
fn parse_av_lst(
  r : @xml.XmlReader,
  out : Array[ShapeAdjustValue],
) -> Unit raise SlideError {
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.drawing_ns && child.local_name == "gd" {
          let name = require_attr(attrs, "name")
          let fmla = require_attr(attrs, "fmla")
          out.push({ name, fmla })
        }
        skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
}

///|
fn parse_xfrm(r : @xml.XmlReader) -> Transform raise SlideError {
  let mut offset : Point? = None
  let mut extent : Size? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "off" => {
            offset = Some({
              x: @units.Emu(parse_int64_attr(attrs, "x")),
              y: @units.Emu(parse_int64_attr(attrs, "y")),
            })
            skip_subtree(r)
          }
          "ext" => {
            extent = Some({
              cx: @units.Emu(parse_int64_attr(attrs, "cx")),
              cy: @units.Emu(parse_int64_attr(attrs, "cy")),
            })
            skip_subtree(r)
          }
          // chOff/chExt are group-shape coordinates; ignored on auto-shapes.
          _ => skip_subtree(r)
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
) -> @slide_master.ClrMapOverride raise SlideError {
  let mut result : @slide_master.ClrMapOverride = MasterMapping
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.drawing_ns &&
          child.local_name == "overrideClrMapping" {
          let cm = @slide_master.parse_clr_map_attrs(attrs) catch {
            e => raise Malformed("overrideClrMapping invalid: " + e.to_string())
          }
          result = Override(cm)
        }
        skip_subtree(r)
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
