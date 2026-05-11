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
          // Placeholder for shape kinds we'll fill in across later 3c slices.
          "pic" | "cxnSp" | "grpSp" | "graphicFrame" | "contentPart" => {
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
          // style, txBody, extLst — Phase 3c later slices
          _ => skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  { id, name, placeholder, transform, geometry }
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
