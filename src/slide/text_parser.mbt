// Text body parsing — `<p:txBody>` and everything beneath it.
//
// Split out of `parser.mbt` as part of the post-3d refactor. The
// recursive-descent contract is the same: each `parse_*` runs after
// its element's StartElement has been consumed and consumes events
// through the matching EndElement.

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
          for kv in child_attrs {
            if kv.0.uri == @oxml.office_relationships_ns &&
              kv.0.local_name == "embed" {
              rid = kv.1
            }
          }
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
  let mut fill : @oxml.Color? = None
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
/// Parse `<a:solidFill>` body. Delegates colour parsing to
/// `@oxml.parse_color_element` so every colour kind (srgb / hsl / sys /
/// scheme / prst / scrgb) and its modifiers come through one path.
/// Returns `None` if the body has no recognised colour child.
fn parse_solid_fill(r : @xml.XmlReader) -> @oxml.Color? raise SlideError {
  let mut result : @oxml.Color? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == @oxml.drawing_ns {
          let color = @oxml.parse_color_element(r, child, child_attrs) catch {
            e => raise Malformed("solidFill: " + e.to_string())
          }
          if result is None {
            result = Some(color)
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
      match @oxml.parse_signed_int(kv.1) {
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
/// `baseline` is `xsd:percentage` (1/1000 of a percent, may be negative).
fn parse_baseline_attr(
  attrs : Array[(@xml.QName, String)],
) -> @units.Percentage? {
  for kv in attrs {
    if kv.0.local_name == "baseline" && kv.0.uri == "" {
      match @oxml.parse_signed_int(kv.1) {
        Some(n) => return Some(@units.Percentage::from_ooxml(n))
        None => return None
      }
    }
  }
  None
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
