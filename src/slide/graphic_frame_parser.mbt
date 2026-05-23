// Graphic frame + table parser — Phase 6a.
//
// Entered from `parse_sp_tree` in `parser.mbt` when it sees
// `<p:graphicFrame>`. Returns a `GraphicFrame` value (which slots
// into `Shape::GraphicFrame`).
//
// The `<a:graphicData uri="…">` URI discriminates the embedded
// content kind. We type the table case; everything else is captured
// wholesale into `GraphicFrameContent::OtherGraphic(uri, element)`
// so charts / SmartArt / OLE round-trip through ADR-004 until their
// own phases arrive.

///|
/// Canonical `<a:graphicData uri="…">` value for embedded tables.
let graphic_data_table_uri : String = "http://schemas.openxmlformats.org/drawingml/2006/table"

///|
fn parse_graphic_frame(r : @xml.XmlReader) -> GraphicFrame raise SlideError {
  let mut id = 0
  let mut name = ""
  let mut transform : Transform? = None
  let mut content : GraphicFrameContent? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "nvGraphicFramePr" => {
              let (parsed_id, parsed_name, _) = parse_nv_sp_pr(r, extension)
              id = parsed_id
              name = parsed_name
            }
            "xfrm" =>
              // graphicFrame's xfrm is in the PML namespace but its
              // body (`<a:off>` / `<a:ext>`) is in drawing-ml.
              transform = Some(parse_xfrm(r, extension))
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
    // graphicFrame may also have foreign-namespace children — handled
    // by the uri != presentation_ns branch above. The drawing-ns
    // `<a:graphic>` is the actual content host; it's dispatched
    // below from the same StartElement match because its uri matches
    // drawing_ns, not presentation_ns. Replay the dispatch.
  }
  // Walk fell out without finding <a:graphic>: try the foreign-
  // namespace path. parse_graphic_frame is called immediately after
  // StartElement(<p:graphicFrame>); we look for <a:graphic> as a
  // child with uri == drawing_ns, captured by `extension` above.
  // Find and lift it.
  let mut graphic_idx = -1
  for i, ext in extension {
    if ext.name.uri == @oxml.drawing_ns && ext.name.local_name == "graphic" {
      graphic_idx = i
      break
    }
  }
  if graphic_idx >= 0 {
    let graphic_el = extension[graphic_idx]
    // Remove it from extension so we don't double-emit on write.
    extension.remove(graphic_idx) |> ignore
    content = Some(parse_graphic_body(graphic_el))
  }
  let c = match content {
    Some(c) => c
    None =>
      raise Malformed("<p:graphicFrame> is missing required <a:graphic> child")
  }
  { id, name, transform, content: c, extension }
}

///|
/// Walk the captured `<a:graphic>` element and extract the
/// `<a:graphicData>` body. If the uri matches the table identifier
/// we lift the body into a typed `Table`; otherwise we emit
/// `OtherGraphic(uri, captured)` so chart / SmartArt etc. round-trip.
fn parse_graphic_body(
  graphic_el : @xml.XmlElement,
) -> GraphicFrameContent raise SlideError {
  // <a:graphic> has exactly one <a:graphicData uri="…"> child per spec.
  let mut data_child : @xml.XmlElement? = None
  for node in graphic_el.children {
    match node {
      Element(c) =>
        if c.name.uri == @oxml.drawing_ns && c.name.local_name == "graphicData" {
          data_child = Some(c)
        }
      _ => ()
    }
  }
  let data = match data_child {
    Some(d) => d
    None =>
      raise Malformed("<a:graphic> is missing required <a:graphicData> child")
  }
  let uri = lookup_attr(data.attributes, "uri")
  if uri == graphic_data_table_uri {
    // Find <a:tbl> inside.
    let mut tbl_child : @xml.XmlElement? = None
    for node in data.children {
      match node {
        Element(c) =>
          if c.name.uri == @oxml.drawing_ns && c.name.local_name == "tbl" {
            tbl_child = Some(c)
          }
        _ => ()
      }
    }
    let tbl_el = match tbl_child {
      Some(t) => t
      None =>
        raise Malformed(
          "<a:graphicData uri=table> is missing required <a:tbl> child",
        )
    }
    TableContent(parse_table(tbl_el))
  } else {
    OtherGraphic(uri, data)
  }
}

///|
fn lookup_attr(attrs : Array[(@xml.QName, String)], name : String) -> String {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return kv.1
    }
  }
  ""
}

///|
fn parse_table(tbl : @xml.XmlElement) -> Table raise SlideError {
  let mut properties : TableProperties? = None
  let grid : Array[@units.Emu] = []
  let rows : Array[TableRow] = []
  let extension : Array[@xml.XmlElement] = []
  for node in tbl.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.drawing_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "tblPr" => properties = Some(parse_tbl_pr(c))
            "tblGrid" => parse_tbl_grid(c, grid)
            "tr" => rows.push(parse_tr(c))
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { properties, grid, rows, extension }
}

///|
/// Parse an `<a:tblPr>` body into typed `TableProperties`. The
/// attributes carry the seven style-hint booleans + `rtl`; the
/// children are a fill choice (optional) and / or `<a:tableStyleId>`
/// (optional). `<a:tableStyle>` (inline-style) and any other
/// children ride on `extension`.
fn parse_tbl_pr(el : @xml.XmlElement) -> TableProperties raise SlideError {
  let attrs = el.attributes
  let mut fill : @oxml.Fill? = None
  let mut table_style_id : String? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.drawing_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "noFill" | "solidFill" | "gradFill" | "blipFill" | "pattFill" =>
              fill = Some(parse_fill_from_element(c))
            "tableStyleId" => table_style_id = Some(extract_text(c))
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  {
    first_row: bool_attr_opt(attrs, "firstRow"),
    first_col: bool_attr_opt(attrs, "firstCol"),
    last_row: bool_attr_opt(attrs, "lastRow"),
    last_col: bool_attr_opt(attrs, "lastCol"),
    band_row: bool_attr_opt(attrs, "bandRow"),
    band_col: bool_attr_opt(attrs, "bandCol"),
    rtl: bool_attr_opt(attrs, "rtl"),
    fill,
    table_style_id,
    extension,
  }
}

///|
/// Look up an attribute and parse it as a boolean.  Accepts `1` /
/// `0` / `true` / `false` per OOXML; anything else (including
/// absent) returns `None`.
fn bool_attr_opt(attrs : Array[(@xml.QName, String)], name : String) -> Bool? {
  match lookup_attr(attrs, name) {
    "1" | "true" => Some(true)
    "0" | "false" => Some(false)
    _ => None
  }
}

///|
/// Look up an attribute and parse it as a non-negative integer EMU.
fn emu_attr_opt(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> @units.Emu? {
  let raw = lookup_attr(attrs, name)
  if raw == "" {
    return None
  }
  match @oxml.parse_signed_int64(raw) {
    Some(n) => Some(@units.Emu(n))
    None => None
  }
}

///|
/// Extract the text content of an element (concatenating Text and
/// CData nodes). Used for `<a:tableStyleId>` which has the GUID as
/// plain text content.
fn extract_text(el : @xml.XmlElement) -> String {
  let mut out = ""
  for node in el.children {
    match node {
      Text(s) => out = out + s
      CData(s) => out = out + s
      _ => ()
    }
  }
  out
}

///|
fn parse_tbl_grid(
  grid_el : @xml.XmlElement,
  out : Array[@units.Emu],
) -> Unit raise SlideError {
  for node in grid_el.children {
    match node {
      Element(c) =>
        if c.name.uri == @oxml.drawing_ns && c.name.local_name == "gridCol" {
          let w_raw = lookup_attr(c.attributes, "w")
          match @oxml.parse_signed_int64(w_raw) {
            Some(n) => out.push(@units.Emu(n))
            None => raise Malformed("gridCol w is not an integer: " + w_raw)
          }
        }
      _ => ()
    }
  }
}

///|
fn parse_tr(tr : @xml.XmlElement) -> TableRow raise SlideError {
  let h_raw = lookup_attr(tr.attributes, "h")
  let height = match @oxml.parse_signed_int64(h_raw) {
    Some(n) => @units.Emu(n)
    None => raise Malformed("tr h is not an integer: " + h_raw)
  }
  let cells : Array[TableCell] = []
  let extension : Array[@xml.XmlElement] = []
  for node in tr.children {
    match node {
      Element(c) =>
        if c.name.uri == @oxml.drawing_ns && c.name.local_name == "tc" {
          cells.push(parse_tc(c))
        } else {
          extension.push(c)
        }
      _ => ()
    }
  }
  { height, cells, extension }
}

///|
fn parse_tc(tc : @xml.XmlElement) -> TableCell raise SlideError {
  let grid_span = parse_int_attr_default_or(
    lookup_attr(tc.attributes, "gridSpan"),
    1,
  )
  let row_span = parse_int_attr_default_or(
    lookup_attr(tc.attributes, "rowSpan"),
    1,
  )
  let h_merge = parse_bool_string(lookup_attr(tc.attributes, "hMerge"))
  let v_merge = parse_bool_string(lookup_attr(tc.attributes, "vMerge"))
  let mut text_body : TextBody? = None
  let mut properties : TableCellProperties? = None
  let extension : Array[@xml.XmlElement] = []
  for node in tc.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.drawing_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "txBody" => text_body = Some(parse_text_body_from_element(c))
            "tcPr" => properties = Some(parse_tc_pr(c))
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  { grid_span, row_span, h_merge, v_merge, text_body, properties, extension }
}

///|
/// Parse an `<a:tcPr>` body into typed `TableCellProperties`.
///
/// Attributes carry margins / anchor / vertical-text-direction;
/// children carry six possible borders (left / right / top / bottom
/// / TL→BR / BL→TR) and a fill choice. Unrecognised children
/// (`<a:cell3D>`, `<a:headers>`, `<a:extLst>`, foreign-namespace)
/// ride on `extension`.
fn parse_tc_pr(el : @xml.XmlElement) -> TableCellProperties raise SlideError {
  let attrs = el.attributes
  let mut border_left : @oxml.Stroke? = None
  let mut border_right : @oxml.Stroke? = None
  let mut border_top : @oxml.Stroke? = None
  let mut border_bottom : @oxml.Stroke? = None
  let mut border_tl_to_br : @oxml.Stroke? = None
  let mut border_bl_to_tr : @oxml.Stroke? = None
  let mut fill : @oxml.Fill? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.drawing_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "lnL" => border_left = Some(parse_stroke_from_element(c))
            "lnR" => border_right = Some(parse_stroke_from_element(c))
            "lnT" => border_top = Some(parse_stroke_from_element(c))
            "lnB" => border_bottom = Some(parse_stroke_from_element(c))
            "lnTlToBr" => border_tl_to_br = Some(parse_stroke_from_element(c))
            "lnBlToTr" => border_bl_to_tr = Some(parse_stroke_from_element(c))
            "noFill" | "solidFill" | "gradFill" | "blipFill" | "pattFill" =>
              fill = Some(parse_fill_from_element(c))
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let anchor = @oxml.optional_attr(attrs, "anchor").bind(Anchor::from_xml)
  let vertical_text = @oxml.optional_attr(attrs, "vert").bind(
    VerticalText::from_xml,
  )
  {
    margin_l: emu_attr_opt(attrs, "marL"),
    margin_r: emu_attr_opt(attrs, "marR"),
    margin_t: emu_attr_opt(attrs, "marT"),
    margin_b: emu_attr_opt(attrs, "marB"),
    anchor,
    anchor_ctr: bool_attr_opt(attrs, "anchorCtr"),
    vertical_text,
    border_left,
    border_right,
    border_top,
    border_bottom,
    border_tl_to_br,
    border_bl_to_tr,
    fill,
    extension,
  }
}

///|
/// Re-serialise a captured stroke / fill element to a standalone
/// XML string and re-parse via `@oxml.parse_stroke / parse_fill`.
/// Same bridge as `parse_text_body_from_element` for the same
/// reason: lets us reuse the well-tested streaming parsers without
/// duplicating their logic on top of the captured DOM.
fn parse_stroke_from_element(
  el : @xml.XmlElement,
) -> @oxml.Stroke raise SlideError {
  let serialized = serialize_standalone_xml(el)
  let r = @xml.XmlReader::new(serialized)
  let ev = next_event(r)
  let attrs = match ev {
    StartElement(_, a) => a
    _ => raise Malformed("stroke re-parse: expected StartElement")
  }
  @oxml.parse_stroke(r, attrs) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
fn parse_fill_from_element(el : @xml.XmlElement) -> @oxml.Fill raise SlideError {
  let serialized = serialize_standalone_xml(el)
  let r = @xml.XmlReader::new(serialized)
  let ev = next_event(r)
  let (name, attrs) = match ev {
    StartElement(n, a) => (n, a)
    _ => raise Malformed("fill re-parse: expected StartElement")
  }
  @oxml.parse_fill(r, name, attrs) catch {
    e => raise Malformed(e.to_string())
  }
}

///|
/// Parse `gridSpan` / `rowSpan` integer attribute with a default
/// fallback. Empty / unparseable → default.
fn parse_int_attr_default_or(raw : String, default : Int) -> Int {
  if raw == "" {
    return default
  }
  match @oxml.parse_signed_int(raw) {
    Some(n) => n
    None => default
  }
}

///|
fn parse_bool_string(raw : String) -> Bool {
  match raw {
    "1" | "true" => true
    _ => false
  }
}

///|
/// Parse a `<a:txBody>` from an already-captured `XmlElement`. We
/// can't reuse the streaming `parse_text_body` from `text_parser.mbt`
/// directly because the parser walks events; instead we serialise
/// the XmlElement back to a standalone XML string (with explicit
/// `xmlns:*` declarations on the root) and re-parse via an event
/// stream. Round-tripping is overkill for production use but lets us
/// reuse the well-tested text parser without duplicating its
/// thousand lines of logic. Phase 6d can replace this with an
/// XmlElement-driven text-body parser if profiling demands.
fn parse_text_body_from_element(
  el : @xml.XmlElement,
) -> TextBody raise SlideError {
  let serialized = serialize_standalone_xml(el)
  let r = @xml.XmlReader::new(serialized)
  // Skip the root start tag — parse_text_body expects to be called
  // just after `<a:txBody>` has been consumed.
  let _ = next_event(r)
  parse_text_body(r)
}

///|
/// Serialise an `XmlElement` to a *standalone* XML string —
/// `xmlns:a` / `xmlns:p` / `xmlns:r` declarations are emitted on
/// the root element so the result re-parses cleanly without any
/// inherited namespace scope from an enclosing document.
///
/// Used by `parse_text_body_from_element` to bridge the DOM-capture
/// side and the event-streaming text parser.
fn serialize_standalone_xml(el : @xml.XmlElement) -> String raise SlideError {
  serialize_standalone_xml_inner(el) catch {
    e => raise wrap_xml(e)
  }
}

///|
fn serialize_standalone_xml_inner(
  el : @xml.XmlElement,
) -> String raise @xml.XmlError {
  let w = @xml.XmlWriter::new()
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("p", @oxml.presentation_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  // Emit the captured element's start tag manually so we can attach
  // namespace declarations onto it.
  w.start_element(el.name)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("p", @oxml.presentation_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  for kv in el.attributes {
    w.attribute(kv.0, kv.1)
  }
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  for node in el.children {
    match node {
      Element(c) => @oxml.write_xml_element(w, ctx, c)
      Text(s) => w.text(s)
      CData(s) => w.cdata(s)
    }
  }
  w.end_element()
  w.to_string()
}
