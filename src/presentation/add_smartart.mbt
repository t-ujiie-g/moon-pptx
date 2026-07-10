// SmartArt-insertion API.
//
// `add_smartart_mut(slide_idx, smartart, x, y, cx, cy)` attaches a built
// SmartArt diagram to a slide. A diagram is five OPC parts:
//
//   /ppt/diagrams/dataN.xml       (<dgm:dataModel>  — nodes + connections)
//   /ppt/diagrams/layoutN.xml     (<dgm:layoutDef>  — layout algorithm)
//   /ppt/diagrams/quickStyleN.xml (<dgm:styleDef>   — quick style)
//   /ppt/diagrams/colorsN.xml     (<dgm:colorsDef>  — colour transform)
//   /ppt/drawings/drawingN.xml    (<dsp:drawing>    — cached laid-out shapes)
//
// The slide references the first four via a `<dgm:relIds>` inside a
// `<p:graphicFrame>` (four relationships: dm / lo / qs / cs). The data part
// references the cached drawing via a relationship in *its own* `.rels`
// (recorded inside the data model as `<dsp:dataModelExt relId=…>`). The cached
// drawing carries the laid-out boxes so the diagram renders without a layout
// engine.

///|
/// Insert a built `SmartArt` diagram as a `<p:graphicFrame>` on the slide at
/// `slide_idx`, positioned at `(x, y)` with extent `(cx, cy)` (EMU). The five
/// DiagramML parts are synthesised and wired into the package. Raises
/// `Malformed` if the diagram has no nodes or `slide_idx` is out of range.
///
/// ```
/// let art = @smartart.SmartArt::list(["Plan", "Build", "Ship"])
/// prs.add_smartart_mut(0, art, x, y, cx, cy)
/// ```
pub fn Presentation::add_smartart_mut(
  self : Presentation,
  slide_idx : Int,
  smartart : @smartart.SmartArt,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Unit raise PptxError {
  if smartart.nodes.length() == 0 {
    raise Malformed("add_smartart_mut: diagram has no nodes")
  }
  // Resolve the target slide up front (so we fail before mutating parts).
  let slide_parts = self.ordered_slide_parts()
  if slide_idx < 0 || slide_idx >= slide_parts.length() {
    raise Malformed(
      "add_smartart_mut: slide_idx " +
      slide_idx.to_string() +
      " out of range (0.." +
      slide_parts.length().to_string() +
      ")",
    )
  }
  let slide_part = slide_parts[slide_idx]
  let slide_name = slide_part.name

  // One shared index N across all five parts (data1 / layout1 / … / drawing1).
  let n = self.next_diagram_index()
  let data_name = "/ppt/diagrams/data" + n.to_string() + ".xml"
  let layout_name = "/ppt/diagrams/layout" + n.to_string() + ".xml"
  let quick_name = "/ppt/diagrams/quickStyle" + n.to_string() + ".xml"
  let colors_name = "/ppt/diagrams/colors" + n.to_string() + ".xml"
  let drawing_name = "/ppt/drawings/drawing" + n.to_string() + ".xml"

  // The cached drawing is referenced from the data part's own rels.
  let data_rels0 = @opc.Relationships::new(data_name)
  let drawing_rid = next_unused_rid(data_rels0)

  // Generate the five part payloads.
  let data_bytes = smartart.data_xml(drawing_rid) catch {
    e => raise SmartArtFailure(e.to_string())
  }
  let drawing_bytes = smartart.drawing_xml(cx, cy) catch {
    e => raise SmartArtFailure(e.to_string())
  }
  let layout_bytes = smartart.layout_xml()
  let quick_bytes = smartart.quick_style_xml()
  let colors_bytes = smartart.colors_xml()

  // Add the five parts.
  add_diagram_part(self, data_name, @oxml.ct_diagram_data, data_bytes)
  add_diagram_part(self, layout_name, @oxml.ct_diagram_layout, layout_bytes)
  add_diagram_part(self, quick_name, @oxml.ct_diagram_style, quick_bytes)
  add_diagram_part(self, colors_name, @oxml.ct_diagram_colors, colors_bytes)
  add_diagram_part(self, drawing_name, @oxml.ct_diagram_drawing, drawing_bytes)

  // Content-type Overrides for all five (diagram parts are not extension-keyed).
  let ct = self.pkg
    .content_types()
    .with_override(data_name, @oxml.ct_diagram_data)
    .with_override(layout_name, @oxml.ct_diagram_layout)
    .with_override(quick_name, @oxml.ct_diagram_style)
    .with_override(colors_name, @oxml.ct_diagram_colors)
    .with_override(drawing_name, @oxml.ct_diagram_drawing)
  self.pkg.set_content_types(ct)
  self.pkg.regenerate_content_types_part() catch {
    e => raise OpcFailure(e.to_string())
  }

  // Data part → cached drawing relationship.
  let data_rels = data_rels0.with_relationship(@opc.Relationship::{
    id: drawing_rid,
    rel_type: @opc.rt_diagram_drawing,
    target: relative_target(data_name, drawing_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(data_name, data_rels)

  // Slide → four diagram-part relationships (dm / lo / qs / cs).
  let slide_rels0 = self.pkg.relationships_for(slide_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let (slide_rels1, dm_rid) = add_diagram_rel(
    slide_rels0, slide_name, data_name, @opc.rt_diagram_data,
  )
  let (slide_rels2, lo_rid) = add_diagram_rel(
    slide_rels1, slide_name, layout_name, @opc.rt_diagram_layout,
  )
  let (slide_rels3, qs_rid) = add_diagram_rel(
    slide_rels2, slide_name, quick_name, @opc.rt_diagram_quick_style,
  )
  let (slide_rels4, cs_rid) = add_diagram_rel(
    slide_rels3, slide_name, colors_name, @opc.rt_diagram_colors,
  )
  self.write_rels_for_part(slide_name, slide_rels4)

  // Build the graphicFrame and append it.
  let gf_id = next_picture_shape_id(slide_part)
  let gf = @slide.GraphicFrame::of_diagram_ref(
    gf_id,
    "Diagram " + gf_id.to_string(),
    x,
    y,
    cx,
    cy,
    dm_rid,
    lo_rid,
    qs_rid,
    cs_rid,
  )
  let slide_obj = @slide.Slide::parse(slide_part.bytes) catch {
    e => raise SlideFailure(e.to_string())
  }
  self.update_slide_mut(slide_idx, slide_obj.with_shape(GraphicFrame(gf)))
}

///|
/// Add a single diagram part, mapping OPC failures into `PptxError`.
fn add_diagram_part(
  prs : Presentation,
  name : String,
  content_type : String,
  bytes : FixedArray[Byte],
) -> Unit raise PptxError {
  let part = @opc.Part::new(name, content_type, bytes) catch {
    e => raise OpcFailure(e.to_string())
  }
  prs.pkg.add_part(part) catch {
    e => raise OpcFailure(e.to_string())
  }
}

///|
/// Append one slide→diagram relationship, returning the updated rels + the new
/// rId.
fn add_diagram_rel(
  rels : @opc.Relationships,
  slide_name : String,
  target_name : String,
  rel_type : String,
) -> (@opc.Relationships, String) raise PptxError {
  let rid = next_unused_rid(rels)
  let updated = rels.with_relationship(@opc.Relationship::{
    id: rid,
    rel_type,
    target: relative_target(slide_name, target_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  (updated, rid)
}

///|
/// Next shared diagram index N — the max across all five diagram part prefixes
/// plus one, so `dataN` / `layoutN` / `quickStyleN` / `colorsN` / `drawingN`
/// all share one number (matching PowerPoint's per-diagram numbering).
fn Presentation::next_diagram_index(self : Presentation) -> Int {
  let mut m = self.max_part_index("/ppt/diagrams/data")
  for
    prefix in [
      "/ppt/diagrams/layout", "/ppt/diagrams/quickStyle", "/ppt/diagrams/colors",
      "/ppt/drawings/drawing",
    ] {
    let v = self.max_part_index(prefix)
    if v > m {
      m = v
    }
  }
  m + 1
}
