// Slide Master model + parser.
//
// A slide master part (`/ppt/slideMasters/slideMaster*.xml`) carries:
//   * `p:cSld` (common slide data: background + shape tree)
//   * `p:clrMap` (the color mapping — modeled here)
//   * `p:sldLayoutIdLst` (references to slide layouts)
//   * optional `p:txStyles`, `p:hf`, `p:timing`, `p:transition`, `p:extLst`
//
// Phase 3b1 covers the structural skeleton: `clrMap` and `sldLayoutIdLst`.
// Shape tree, text styles, header/footer toggles are skipped via
// `skip_subtree` until later phases need them.

///|
/// One slide-layout reference inside `<p:sldLayoutIdLst>`.
///
/// `id` is a layout-internal numeric id (a 32-bit unsigned per spec, so we
/// hold it as `Int64` to fit unsigned values). `r_id` is the relationship
/// id pointing at the layout part inside the master's `.rels`.
pub(all) struct SlideLayoutRef {
  id : Int64
  r_id : String
} derive(Eq, Debug)

///|
/// A parsed slide master.
///
/// `color_mapping` is required by the spec and always present after a
/// successful parse. `layout_refs` lists the layouts in source order.
pub(all) struct SlideMaster {
  color_mapping : ColorMapping
  layout_refs : Array[SlideLayoutRef]
} derive(Eq, Debug)

///|
/// Parse a slide master part from raw XML bytes.
pub fn SlideMaster::parse(
  bytes : FixedArray[Byte],
) -> SlideMaster raise SlideMasterError {
  parse_slide_master_xml(bytes_to_string(bytes))
}

///|
fn parse_slide_master_xml(xml : String) -> SlideMaster raise SlideMasterError {
  let r = @xml.XmlReader::new(xml)
  // Root must be <p:sldMaster>.
  let event = next_event(r)
  match event {
    StartElement(name, _) => expect_pml(name, "sldMaster")
    _ => raise Malformed("expected <p:sldMaster> root element")
  }
  let mut color_mapping : ColorMapping? = None
  let layout_refs : Array[SlideLayoutRef] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri != @oxml.presentation_ns {
          skip_subtree(r)
          continue
        }
        match child.local_name {
          "clrMap" => {
            color_mapping = Some(parse_clr_map_attrs(attrs))
            skip_subtree(r) // clrMap is empty per schema
          }
          "sldLayoutIdLst" => parse_layout_id_lst(r, layout_refs)
          // cSld, txStyles, hf, transition, timing, extLst, etc.
          _ => skip_subtree(r)
        }
      }
      EndElement(_) => break
      _ => ()
    }
  }
  match color_mapping {
    Some(cm) => { color_mapping: cm, layout_refs }
    None => raise Malformed("slide master is missing required <p:clrMap>")
  }
}

///|
/// Parse the twelve required `clrMap` attributes into a `ColorMapping`.
/// Used by both the slide-master parser and (later) the slide-layout
/// parser when `clrMapOvr` carries an explicit override.
pub fn parse_clr_map_attrs(
  attrs : Array[(@xml.QName, String)],
) -> ColorMapping raise SlideMasterError {
  {
    bg1: require_clr_attr(attrs, "bg1"),
    tx1: require_clr_attr(attrs, "tx1"),
    bg2: require_clr_attr(attrs, "bg2"),
    tx2: require_clr_attr(attrs, "tx2"),
    accent1: require_clr_attr(attrs, "accent1"),
    accent2: require_clr_attr(attrs, "accent2"),
    accent3: require_clr_attr(attrs, "accent3"),
    accent4: require_clr_attr(attrs, "accent4"),
    accent5: require_clr_attr(attrs, "accent5"),
    accent6: require_clr_attr(attrs, "accent6"),
    hlink: require_clr_attr(attrs, "hlink"),
    fol_hlink: require_clr_attr(attrs, "folHlink"),
  }
}

// --- internal ---

///|
fn parse_layout_id_lst(
  r : @xml.XmlReader,
  out : Array[SlideLayoutRef],
) -> Unit raise SlideMasterError {
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri != @oxml.presentation_ns ||
          child.local_name != "sldLayoutId" {
          skip_subtree(r)
          continue
        }
        let id = parse_id_attr(attrs)
        let r_id = require_r_id(attrs)
        out.push({ id, r_id })
        skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
}

///|
fn parse_id_attr(
  attrs : Array[(@xml.QName, String)],
) -> Int64 raise SlideMasterError {
  let raw = require_attr(attrs, "id")
  match parse_uint64_decimal(raw) {
    Some(n) => n
    None =>
      raise Malformed("sldLayoutId id is not a non-negative integer: " + raw)
  }
}

///|
fn require_r_id(
  attrs : Array[(@xml.QName, String)],
) -> String raise SlideMasterError {
  for kv in attrs {
    if kv.0.uri == @oxml.office_relationships_ns && kv.0.local_name == "id" {
      return kv.1
    }
  }
  raise Malformed("sldLayoutId is missing r:id attribute")
}

///|
fn require_clr_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.ThemeColor raise SlideMasterError {
  let raw = require_attr(attrs, name)
  @units.ThemeColor::from_xml(raw) catch {
    _ =>
      raise Malformed(
        "clrMap " + name + " has unknown ST_ColorSchemeIndex value: " + raw,
      )
  }
}

///|
/// Thin delegator to `@oxml.require_attr`.
fn require_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> String raise SlideMasterError {
  @oxml.require_attr(attrs, name, name) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
fn parse_uint64_decimal(s : String) -> Int64? {
  let chars = s.to_array()
  if chars.length() == 0 {
    return None
  }
  let mut acc : Int64 = 0L
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      return None
    }
    acc = acc * 10L + (c.to_int() - '0'.to_int()).to_int64()
    i = i + 1
  }
  Some(acc)
}

///|
fn expect_pml(
  name : @xml.QName,
  expected : String,
) -> Unit raise SlideMasterError {
  if name.uri != @oxml.presentation_ns || name.local_name != expected {
    raise Malformed(
      "expected element <p:" + expected + "> but got <" + name.local_name + ">",
    )
  }
}

///|
fn skip_subtree(r : @xml.XmlReader) -> Unit raise SlideMasterError {
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
fn next_event(r : @xml.XmlReader) -> @xml.XmlEvent raise SlideMasterError {
  let event = r.next() catch { e => raise wrap_xml(e) }
  match event {
    Some(e) => e
    None => raise Malformed("unexpected end of input")
  }
}

///|
/// Decode UTF-8 bytes via the shared `@oxml.bytes_to_string` helper,
/// mapping any `Utf8Error` into the domain error variant.
fn bytes_to_string(bytes : FixedArray[Byte]) -> String raise SlideMasterError {
  @oxml.bytes_to_string(bytes) catch {
    e => raise Malformed(e.to_string())
  }
}
