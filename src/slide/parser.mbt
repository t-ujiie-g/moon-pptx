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
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri != @oxml.presentation_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "cSld" => slide_name = parse_c_sld(r, attrs, shapes)
          "clrMapOvr" => clr_map_override = parse_clr_map_ovr(r)
          _ => skip_subtree(r) // transition, timing, custDataLst, extLst
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  { name: slide_name, shapes, clr_map_override }
}

///|
fn parse_c_sld(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
  shapes : Array[Shape],
) -> String raise SlideError {
  let name = optional_attr(attrs, "name")
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, _) => {
        if child.uri != @oxml.presentation_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "spTree" => parse_sp_tree(r, shapes)
          _ => skip_subtree(r) // bg, custDataLst, extLst
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
) -> Unit raise SlideError {
  // The first two children of every spTree are nvGrpSpPr + grpSpPr — they
  // describe the implicit root group, which we don't surface in our shape
  // list. Skip them by name; everything else falls into the shape switch.
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri != @oxml.presentation_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "nvGrpSpPr" => skip_subtree(r)
          "grpSpPr" => skip_subtree(r)
          "sp" => shapes.push(AutoShape(parse_auto_shape(r, attrs)))
          "pic" => shapes.push(Picture(parse_picture(r)))
          "cxnSp" => shapes.push(Connector(parse_connector(r)))
          "grpSp" => shapes.push(Group(parse_group_shape(r)))
          // Remaining placeholders for later phases (graphicFrame =
          // table / chart / SmartArt host; contentPart = extension).
          "graphicFrame" | "contentPart" => {
            shapes.push(Unknown(child.local_name))
            skip_subtree(r)
          }
          _ => skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
}

// --- Connector ---

///|
fn parse_connector(r : @xml.XmlReader) -> Connector raise SlideError {
  let mut id = 0
  let mut name = ""
  let mut transform : Transform? = None
  let mut geometry : Geometry? = None
  let mut start : ConnectionEnd? = None
  let mut end : ConnectionEnd? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, _) => {
        if child.uri != @oxml.presentation_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "nvCxnSpPr" => {
            let (parsed_id, parsed_name, st, en) = parse_nv_cxn_sp_pr(r)
            id = parsed_id
            name = parsed_name
            start = st
            end = en
          }
          "spPr" => {
            let (xfrm, geom) = parse_sp_pr(r)
            transform = xfrm
            geometry = geom
          }
          // style, extLst — Phase 3 later slices
          _ => skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  { id, name, transform, geometry, start, end }
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
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) => {
        if child.uri != @oxml.presentation_ns {
          skip_subtree(r)
          continue
        }
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
          "graphicFrame" | "contentPart" => {
            children.push(Unknown(child.local_name))
            skip_subtree(r)
          }
          _ => skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  { id, name, transform, child_offset, child_extent, children }
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
  let mut embed_id = ""
  let mut link_id = ""
  let mut src_rect : SrcRect? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, _) => {
        if child.uri != @oxml.presentation_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "nvPicPr" => {
            // Same shape as nvSpPr (cNvPr + cNvPicPr + nvPr); reuse the
            // (id, name, _) extractor and discard the placeholder slot.
            let (parsed_id, parsed_name, _) = parse_nv_sp_pr(r)
            id = parsed_id
            name = parsed_name
          }
          "blipFill" => {
            let (e, l, sr) = parse_blip_fill(r)
            embed_id = e
            link_id = l
            src_rect = sr
          }
          "spPr" => {
            let (xfrm, geom) = parse_sp_pr(r)
            transform = xfrm
            geometry = geom
          }
          // style, extLst — Phase 3 later slices
          _ => skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  if embed_id.length() == 0 && link_id.length() == 0 {
    raise Malformed("<p:pic> blip is missing both r:embed and r:link")
  }
  { id, name, transform, geometry, embed_id, link_id, src_rect }
}

///|
/// Parse `<p:blipFill>` body. Returns `(embed_id, link_id, src_rect?)`.
fn parse_blip_fill(
  r : @xml.XmlReader,
) -> (String, String, SrcRect?) raise SlideError {
  let mut embed_id = ""
  let mut link_id = ""
  let mut src_rect : SrcRect? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "blip" => {
            let (e, l) = extract_blip_rels(attrs)
            embed_id = e
            link_id = l
            // colour modifications and image effects nested here are
            // intentionally skipped for now.
            skip_subtree(r)
          }
          "srcRect" => {
            src_rect = Some(parse_src_rect_attrs(attrs))
            skip_subtree(r)
          }
          // stretch / tile / fillRect — fill-mode handling lives outside
          // this slice; consume and discard.
          _ => skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  (embed_id, link_id, src_rect)
}

///|
fn extract_blip_rels(attrs : Array[(@xml.QName, String)]) -> (String, String) {
  let mut embed_id = ""
  let mut link_id = ""
  for kv in attrs {
    if kv.0.uri == @oxml.office_relationships_ns {
      if kv.0.local_name == "embed" {
        embed_id = kv.1
      } else if kv.0.local_name == "link" {
        link_id = kv.1
      }
    }
  }
  (embed_id, link_id)
}

///|
fn parse_src_rect_attrs(
  attrs : Array[(@xml.QName, String)],
) -> SrcRect raise SlideError {
  {
    left: parse_percent_attr(attrs, "l"),
    top: parse_percent_attr(attrs, "t"),
    right: parse_percent_attr(attrs, "r"),
    bottom: parse_percent_attr(attrs, "b"),
  }
}

///|
fn parse_percent_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Percentage raise SlideError {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_int_decimal(kv.1) {
        Some(n) => return @units.Percentage::from_ooxml(n)
        None =>
          raise Malformed(
            "srcRect attribute " + name + " is not an integer: " + kv.1,
          )
      }
    }
  }
  @units.Percentage(0.0)
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
  let mut text_body : TextBody? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, _) => {
        if child.uri != @oxml.presentation_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "nvSpPr" => {
            let (parsed_id, parsed_name, ph) = parse_nv_sp_pr(r)
            id = parsed_id
            name = parsed_name
            placeholder = ph
          }
          "spPr" => {
            let (xfrm, geom) = parse_sp_pr(r)
            transform = xfrm
            geometry = geom
          }
          "txBody" => text_body = Some(parse_text_body(r))
          // style, extLst — Phase 3 later slices
          _ => skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  { id, name, placeholder, transform, geometry, text_body }
}

// --- TextBody (Phase 3d1) ---

///|
/// Parse `<p:txBody>` body. Picks up `<a:bodyPr>`, `<a:lstStyle>`, and
/// the paragraph list (in source order).
fn parse_text_body(r : @xml.XmlReader) -> TextBody raise SlideError {
  let paragraphs : Array[Paragraph] = []
  let mut body_properties : BodyProperties? = None
  let mut list_style : ListStyle? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
        } else {
          match child.local_name {
            "bodyPr" =>
              body_properties = Some(parse_body_properties(r, child_attrs))
            "lstStyle" => list_style = Some(parse_list_style(r))
            "p" => paragraphs.push(parse_paragraph(r))
            _ => skip_subtree(r)
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { body_properties, list_style, paragraphs }
}

///|
/// Parse `<a:bodyPr>` attributes + auto-fit child.
fn parse_body_properties(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> BodyProperties raise SlideError {
  let rotation = parse_angle_attr(attrs, "rot")
  let vertical_text = parse_enum_attr(attrs, "vert", VerticalText::from_xml)
  let wrap = parse_enum_attr(attrs, "wrap", WrapKind::from_xml)
  let anchor = parse_enum_attr(attrs, "anchor", Anchor::from_xml)
  let left_inset = parse_emu_attr(attrs, "lIns")
  let top_inset = parse_emu_attr(attrs, "tIns")
  let right_inset = parse_emu_attr(attrs, "rIns")
  let bottom_inset = parse_emu_attr(attrs, "bIns")
  let mut auto_fit : AutoFit? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
        } else {
          match child.local_name {
            "noAutofit" => {
              auto_fit = Some(NoAutoFit)
              skip_subtree(r)
            }
            "normAutofit" => {
              let font_scale = parse_thousandths_pct_attr(
                child_attrs, "fontScale",
              ).unwrap_or(@units.Percentage(100.0))
              let line_reduction = parse_thousandths_pct_attr(
                child_attrs, "lnSpcReduction",
              ).unwrap_or(@units.Percentage(0.0))
              auto_fit = Some(NormAutoFit(font_scale, line_reduction))
              skip_subtree(r)
            }
            "spAutoFit" => {
              auto_fit = Some(SpAutoFit)
              skip_subtree(r)
            }
            // prstTxWarp, scene3d, sp3d, flatTx, extLst — deferred.
            _ => skip_subtree(r)
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  {
    rotation,
    vertical_text,
    wrap,
    anchor,
    left_inset,
    top_inset,
    right_inset,
    bottom_inset,
    auto_fit,
  }
}

///|
/// Parse `<a:lstStyle>` body — `<a:defPPr>` plus `<a:lvl1pPr>` …
/// `<a:lvl9pPr>`. Slots may appear in any order; missing levels stay
/// `None`. Unknown children are skipped.
fn parse_list_style(r : @xml.XmlReader) -> ListStyle raise SlideError {
  let level_props : Array[ParagraphProperties?] = [
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  ]
  let mut default_props : ParagraphProperties? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
        } else if child.local_name == "defPPr" {
          default_props = Some(parse_paragraph_properties(r, child_attrs))
        } else {
          let lvl = match_level_name(child.local_name)
          match lvl {
            Some(idx) =>
              level_props[idx] = Some(
                parse_paragraph_properties(r, child_attrs),
              )
            None => skip_subtree(r)
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { default_props, level_props }
}

///|
/// Map `"lvl1pPr"` → `Some(0)` … `"lvl9pPr"` → `Some(8)`. Returns
/// `None` for any other local name.
fn match_level_name(name : String) -> Int? {
  match name {
    "lvl1pPr" => Some(0)
    "lvl2pPr" => Some(1)
    "lvl3pPr" => Some(2)
    "lvl4pPr" => Some(3)
    "lvl5pPr" => Some(4)
    "lvl6pPr" => Some(5)
    "lvl7pPr" => Some(6)
    "lvl8pPr" => Some(7)
    "lvl9pPr" => Some(8)
    _ => None
  }
}

///|
/// Parse an integer attribute in 1/60000 of a degree (`ST_Angle`) and
/// lift to `Angle`. Returns `None` for absent / unparseable.
fn parse_angle_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Angle? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_int_decimal(kv.1) {
        Some(n) => return Some(@units.Angle::from_ooxml(n))
        None => return None
      }
    }
  }
  None
}

///|
/// Parse `<a:p>` body — `<a:pPr>?`, then a sequence of `<a:r>` / `<a:br>` /
/// `<a:fld>` content.
fn parse_paragraph(r : @xml.XmlReader) -> Paragraph raise SlideError {
  let content : Array[ParagraphContent] = []
  let mut properties : ParagraphProperties = ParagraphProperties::default()
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
        } else {
          match child.local_name {
            "pPr" => properties = parse_paragraph_properties(r, child_attrs)
            "r" => content.push(RunContent(parse_run(r)))
            "br" => content.push(Break(parse_break(r)))
            "fld" => content.push(FieldContent(parse_field(r, child_attrs)))
            // endParaRPr (run props for the implicit terminal break) and
            // anything we don't yet model: skip.
            _ => skip_subtree(r)
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { properties, content }
}

///|
/// Parse `<a:pPr>` — attributes off the start tag plus bullet children.
fn parse_paragraph_properties(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> ParagraphProperties raise SlideError {
  let level = parse_int_attr_default(attrs, "lvl", 0)
  let alignment = parse_enum_attr(attrs, "algn", TextAlignment::from_xml)
  let margin_left = parse_emu_attr(attrs, "marL")
  let indent = parse_emu_attr(attrs, "indent")
  let line_spacing = parse_thousandths_pct_attr(attrs, "lineSpacing")
  let space_before = parse_hundredths_pt_attr(attrs, "spaceBefore")
  let space_after = parse_hundredths_pt_attr(attrs, "spaceAfter")
  let mut bullet : Bullet? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
        } else {
          match child.local_name {
            "buNone" => {
              bullet = Some(BulNone)
              skip_subtree(r)
            }
            "buChar" => {
              bullet = Some(Char(optional_attr(child_attrs, "char")))
              skip_subtree(r)
            }
            "buAutoNum" => {
              let type_raw = require_attr(child_attrs, "type")
              let an = match AutoNumType::from_xml(type_raw) {
                Some(t) => t
                None => raise Malformed("unknown buAutoNum type: " + type_raw)
              }
              let start_at = parse_int_attr_default(child_attrs, "startAt", 1)
              bullet = Some(AutoNum(an, start_at))
              skip_subtree(r)
            }
            "buBlip" => bullet = Some(parse_bu_blip(r))
            // buFont, buSzPct, buClr, buClrTx, tabLst — not modelled yet.
            _ => skip_subtree(r)
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  {
    level,
    alignment,
    margin_left,
    indent,
    line_spacing,
    space_before,
    space_after,
    bullet,
  }
}

///|
/// Parse `<a:buBlip>` body looking for the embedded
/// `<a:blip r:embed="…"/>`. The blip's relationship is in the
/// office-relationships namespace under local name `embed` (NOT `id`).
fn parse_bu_blip(r : @xml.XmlReader) -> Bullet raise SlideError {
  let mut rid = ""
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) => {
        if child.uri == @oxml.drawing_ns && child.local_name == "blip" {
          let (embed, _) = extract_blip_rels(child_attrs)
          rid = embed
        }
        skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
  Picture(rid)
}

///|
/// Parse a decimal integer attribute and lift to `Emu`. Returns `None`
/// for absent or unparseable values.
fn parse_emu_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Emu? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_int64_decimal(kv.1) {
        Some(n) => return Some(@units.Emu(n))
        None => return None
      }
    }
  }
  None
}

///|
/// Parse an attribute encoded as 1/1000 of a percent (`lineSpacing` and
/// similar) and lift to `Percentage`.
fn parse_thousandths_pct_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Percentage? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match parse_int_decimal(kv.1) {
        Some(n) => return Some(@units.Percentage::from_ooxml(n))
        None => return None
      }
    }
  }
  None
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
      match parse_int_decimal(kv.1) {
        Some(n) => return Some(@units.Pt(n.to_double() / 100.0))
        None => return None
      }
    }
  }
  None
}

///|
/// Parse `<a:r>` body — `<a:rPr>?` plus one or more `<a:t>` text runs.
fn parse_run(r : @xml.XmlReader) -> Run raise SlideError {
  let buf = StringBuilder::new(size_hint=32)
  let mut properties = RunProperties::default()
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.drawing_ns {
          skip_subtree(r)
        } else {
          match child.local_name {
            "rPr" => properties = parse_run_properties(r, attrs)
            "t" => collect_text_until_end(r, buf)
            _ => skip_subtree(r)
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { properties, text: buf.to_string() }
}

///|
/// Parse `<a:rPr>` — attributes off the start tag and a handful of
/// children (`<a:solidFill>`, `<a:latin>`, `<a:ea>`, `<a:cs>`,
/// `<a:hlinkClick>`). Other children (gradient/pattern fill, effects,
/// underline fills, east-asian list) are skipped — they land alongside
/// the shape-level fill ADT in Phase 3e.
fn parse_run_properties(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> RunProperties raise SlideError {
  let lang = optional_attr(attrs, "lang")
  let font_size = parse_font_size_attr(attrs)
  let bold = parse_bool_attr(attrs, "b")
  let italic = parse_bool_attr(attrs, "i")
  let underline = parse_enum_attr(attrs, "u", UnderlineKind::from_xml)
  let strikethrough = parse_enum_attr(attrs, "strike", StrikeKind::from_xml)
  let baseline = parse_baseline_attr(attrs)
  let caps = parse_enum_attr(attrs, "cap", CapsKind::from_xml)
  let mut latin : String? = None
  let mut east_asian : String? = None
  let mut complex_script : String? = None
  let mut fill : RunFill? = None
  let mut hyperlink_click : String? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == @oxml.drawing_ns {
          match child.local_name {
            "latin" => {
              latin = Some(optional_attr(child_attrs, "typeface"))
              skip_subtree(r)
            }
            "ea" => {
              east_asian = Some(optional_attr(child_attrs, "typeface"))
              skip_subtree(r)
            }
            "cs" => {
              complex_script = Some(optional_attr(child_attrs, "typeface"))
              skip_subtree(r)
            }
            "solidFill" => fill = parse_solid_fill(r)
            "hlinkClick" => {
              hyperlink_click = Some(extract_rid(child_attrs))
              skip_subtree(r)
            }
            _ => skip_subtree(r)
          }
        } else {
          skip_subtree(r)
        }
      EndElement(_) => break
      _ => ()
    }
  }
  {
    lang,
    font_size,
    bold,
    italic,
    underline,
    strikethrough,
    baseline,
    caps,
    latin,
    east_asian,
    complex_script,
    fill,
    hyperlink_click,
  }
}

///|
/// Parse `<a:solidFill>` looking for `<a:srgbClr>` or `<a:schemeClr>`.
/// Returns `None` if the body is empty or carries an unsupported colour
/// element (we expand the ADT when callers need them).
fn parse_solid_fill(r : @xml.XmlReader) -> RunFill? raise SlideError {
  let mut result : RunFill? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == @oxml.drawing_ns {
          match child.local_name {
            "srgbClr" => {
              let hex = require_attr(child_attrs, "val")
              let rgb = @units.RgbColor::parse_hex(hex) catch {
                _ =>
                  raise Malformed(
                    "srgbClr val is not a 6-hex-digit color: " + hex,
                  )
              }
              if result is None {
                result = Some(SolidRgb(rgb))
              }
              skip_subtree(r)
            }
            "schemeClr" => {
              let raw = require_attr(child_attrs, "val")
              let theme = @units.ThemeColor::from_xml(raw) catch {
                _ =>
                  raise Malformed(
                    "schemeClr val is not a ST_SchemeColorVal: " + raw,
                  )
              }
              if result is None {
                result = Some(SolidTheme(theme))
              }
              skip_subtree(r)
            }
            // hsl, prst, scrgb — widen RunFill if a real PPTX needs them.
            _ => skip_subtree(r)
          }
        } else {
          skip_subtree(r)
        }
      EndElement(_) => break
      _ => ()
    }
  }
  result
}

///|
/// Convert the `sz` attribute (1/100 of a point per spec) to `Pt`.
/// Returns `None` if absent or unparseable so the caller's `Option<Pt>`
/// reflects "inherit".
fn parse_font_size_attr(attrs : Array[(@xml.QName, String)]) -> @units.Pt? {
  for kv in attrs {
    if kv.0.local_name == "sz" && kv.0.uri == "" {
      match parse_int_decimal(kv.1) {
        Some(n) => return Some(@units.Pt(n.to_double() / 100.0))
        None => return None
      }
    }
  }
  None
}

///|
/// Parse an OOXML `xsd:boolean` attribute (`1` / `0` / `true` / `false`).
/// Returns `None` if absent; rejects any other value as `Malformed`.
fn parse_bool_attr(attrs : Array[(@xml.QName, String)], name : String) -> Bool? {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      match kv.1 {
        "1" | "true" => return Some(true)
        "0" | "false" => return Some(false)
        _ => return None // tolerate by returning "inherit"
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
/// `baseline` is `xsd:percentage` (1/1000 of a percent, may be negative).
fn parse_baseline_attr(
  attrs : Array[(@xml.QName, String)],
) -> @units.Percentage? {
  for kv in attrs {
    if kv.0.local_name == "baseline" && kv.0.uri == "" {
      match parse_int_decimal(kv.1) {
        Some(n) => return Some(@units.Percentage::from_ooxml(n))
        None => return None
      }
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

///|
/// Parse `<a:br>` body. `<a:rPr>` is currently skipped; we return an
/// empty `RunProperties` placeholder so the variant stays well-typed.
fn parse_break(r : @xml.XmlReader) -> RunProperties raise SlideError {
  skip_subtree(r)
  RunProperties::default()
}

///|
/// Parse `<a:fld>` body. `id` and `type` come off the start tag; the
/// body is one or more `<a:t>` runs whose text we concatenate.
fn parse_field(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Field raise SlideError {
  let id = optional_attr(attrs, "id")
  let field_type = optional_attr(attrs, "type")
  let buf = StringBuilder::new(size_hint=16)
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, _) =>
        if child.uri == @oxml.drawing_ns && child.local_name == "t" {
          collect_text_until_end(r, buf)
        } else {
          skip_subtree(r)
        }
      EndElement(_) => break
      _ => ()
    }
  }
  {
    id,
    field_type,
    properties: RunProperties::default(),
    text: buf.to_string(),
  }
}

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
/// Look inside `<p:spPr>` for an `<a:xfrm>` and either `<a:prstGeom>` or
/// `<a:custGeom>`. Other children (`a:solidFill`, `a:ln`, `a:effectLst`, …)
/// are skipped; later 3c / 3d slices fill them in.
fn parse_sp_pr(r : @xml.XmlReader) -> (Transform?, Geometry?) raise SlideError {
  let mut transform : Transform? = None
  let mut geometry : Geometry? = None
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
            _ => skip_subtree(r)
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  (transform, geometry)
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
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return kv.1
    }
  }
  ""
}

///|
fn parse_int_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> Int raise SlideError {
  let raw = require_attr(attrs, name)
  match parse_int_decimal(raw) {
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
      return parse_int_decimal(kv.1).unwrap_or(default)
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
  match parse_int64_decimal(raw) {
    Some(n) => n
    None => raise Malformed("attribute " + name + " is not an integer: " + raw)
  }
}

///|
fn require_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> String raise SlideError {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return kv.1
    }
  }
  raise Malformed("missing required attribute: " + name)
}

///|
fn parse_int_decimal(s : String) -> Int? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut i = 0
  let mut sign = 1
  if chars[0] == '-' {
    sign = -1
    i = 1
  } else if chars[0] == '+' {
    i = 1
  }
  if i >= chars.length() {
    return None
  }
  let mut acc = 0
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      return None
    }
    acc = acc * 10 + (c.to_int() - '0'.to_int())
    i = i + 1
  }
  Some(acc * sign)
}

///|
fn parse_int64_decimal(s : String) -> Int64? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut i = 0
  let mut sign : Int64 = 1L
  if chars[0] == '-' {
    sign = -1L
    i = 1
  } else if chars[0] == '+' {
    i = 1
  }
  if i >= chars.length() {
    return None
  }
  let mut acc : Int64 = 0L
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      return None
    }
    acc = acc * 10L + (c.to_int() - '0'.to_int()).to_int64()
    i = i + 1
  }
  Some(acc * sign)
}

///|
fn bytes_to_string(bytes : FixedArray[Byte]) -> String raise SlideError {
  let chars : Array[Char] = []
  let mut i = 0
  while i < bytes.length() {
    let b0 = bytes[i].to_int().land(0xFF)
    if b0 < 0x80 {
      chars.push(b0.unsafe_to_char())
      i = i + 1
    } else if b0 < 0xC0 {
      raise Malformed(
        "stray UTF-8 continuation byte at offset " + i.to_string(),
      )
    } else if b0 < 0xE0 {
      if i + 1 >= bytes.length() {
        raise Malformed("truncated 2-byte UTF-8 sequence")
      }
      let b1 = bytes[i + 1].to_int().land(0xFF)
      let cp = (b0 - 0xC0) * 0x40 + (b1 - 0x80)
      chars.push(cp.unsafe_to_char())
      i = i + 2
    } else if b0 < 0xF0 {
      if i + 2 >= bytes.length() {
        raise Malformed("truncated 3-byte UTF-8 sequence")
      }
      let b1 = bytes[i + 1].to_int().land(0xFF)
      let b2 = bytes[i + 2].to_int().land(0xFF)
      let cp = (b0 - 0xE0) * 0x1000 + (b1 - 0x80) * 0x40 + (b2 - 0x80)
      chars.push(cp.unsafe_to_char())
      i = i + 3
    } else {
      if i + 3 >= bytes.length() {
        raise Malformed("truncated 4-byte UTF-8 sequence")
      }
      let b1 = bytes[i + 1].to_int().land(0xFF)
      let b2 = bytes[i + 2].to_int().land(0xFF)
      let b3 = bytes[i + 3].to_int().land(0xFF)
      let cp = (b0 - 0xF0) * 0x40000 +
        (b1 - 0x80) * 0x1000 +
        (b2 - 0x80) * 0x40 +
        (b3 - 0x80)
      chars.push(cp.unsafe_to_char())
      i = i + 4
    }
  }
  String::from_array(chars)
}
