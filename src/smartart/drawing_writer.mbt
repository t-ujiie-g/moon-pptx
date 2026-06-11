// Cached drawing writer (roadmap D1).
//
// Emits `/ppt/drawings/drawingN.xml` — `<dsp:drawing>` (Microsoft 2008
// diagram-drawing extension): the *laid-out* shapes for the diagram, so
// PowerPoint (and viewers that don't run the layout engine, incl. < 2010)
// render the SmartArt directly. This is the "cached graphic-frame fallback"
// the roadmap calls for — and the piece fully under our control, so we compute
// box positions ourselves from the frame extent.
//
// Coordinates are relative to the host `<p:graphicFrame>`'s origin (0,0) with
// its `cx` × `cy` extent. List stacks boxes top-to-bottom; Process places them
// left-to-right. Each box's `modelId` matches the corresponding data-model
// node point (they must agree).

///|
/// Generate the `drawingN.xml` bytes laying this diagram out within a frame of
/// `cx` × `cy` EMU.
pub fn SmartArt::drawing_xml(
  self : SmartArt,
  cx : @units.Emu,
  cy : @units.Emu,
) -> FixedArray[Byte] raise SmartArtError {
  let xml = self.serialize_drawing_xml(cx, cy) catch { e => raise wrap_xml(e) }
  @oxml.string_to_bytes(xml)
}

///|
/// One laid-out box: position + extent in EMU.
priv struct Box {
  x : Int64
  y : Int64
  w : Int64
  h : Int64
}

///|
/// Compute box rectangles for `n` nodes within `cx` × `cy`, per `kind`.
fn layout_boxes(
  kind : SmartArtKind,
  n : Int,
  cx : Int64,
  cy : Int64,
) -> Array[Box] {
  let boxes = []
  if n <= 0 {
    return boxes
  }
  let nl = n.to_int64()
  match kind {
    List => {
      let slot = cy / nl
      let gap = slot / 10L
      for i in 0..<n {
        boxes.push({
          x: 0L,
          y: i.to_int64() * slot + gap / 2L,
          w: cx,
          h: slot - gap,
        })
      }
    }
    Process => {
      let slot = cx / nl
      let gap = slot / 10L
      for i in 0..<n {
        boxes.push({
          x: i.to_int64() * slot + gap / 2L,
          y: 0L,
          w: slot - gap,
          h: cy,
        })
      }
    }
    Cycle => {
      // Evenly spaced around a ring centred in the frame, starting at the top.
      let cxf = cx.to_double()
      let cyf = cy.to_double()
      let cx0 = cxf / 2.0
      let cy0 = cyf / 2.0
      let minside = if cxf < cyf { cxf } else { cyf }
      let radius = minside * 0.34
      let bsize = minside * 0.28
      for i in 0..<n {
        let ang = two_pi * i.to_double() / nl.to_double() - half_pi
        let bxc = cx0 + radius * @math.cos(ang)
        let byc = cy0 + radius * @math.sin(ang)
        boxes.push({
          x: (bxc - bsize / 2.0).to_int64(),
          y: (byc - bsize / 2.0).to_int64(),
          w: bsize.to_int64(),
          h: bsize.to_int64(),
        })
      }
    }
    Pyramid => {
      // Stacked centred bands, widening toward the base (apex first).
      let band = cy / nl
      let gap = band / 20L
      for i in 0..<n {
        let width = cx * (i.to_int64() + 1L) / nl
        boxes.push({
          x: (cx - width) / 2L,
          y: i.to_int64() * band,
          w: width,
          h: band - gap,
        })
      }
    }
  }
  boxes
}

///|
/// 2π and π/2 in radians — for the cycle ring layout.
let two_pi : Double = 6.283185307179586

///|
let half_pi : Double = 1.5707963267948966

///|
fn SmartArt::serialize_drawing_xml(
  self : SmartArt,
  cx : @units.Emu,
  cy : @units.Emu,
) -> String raise @xml.XmlError {
  let @units.Emu(cxv) = cx
  let @units.Emu(cyv) = cy
  let boxes = layout_boxes(self.kind, self.nodes.length(), cxv, cyv)
  let w = @xml.XmlWriter::new()
  w.bind_namespace("dsp", @oxml.diagram_drawing_ns)
  w.bind_namespace("a", @oxml.drawing_ns)
  w.bind_namespace("r", @oxml.office_relationships_ns)
  w.xml_declaration()
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "drawing"))
  w.namespace_attr("dsp", @oxml.diagram_drawing_ns)
  w.namespace_attr("a", @oxml.drawing_ns)
  w.namespace_attr("r", @oxml.office_relationships_ns)
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "spTree"))
  // Group wrappers (mirrors <p:spTree>'s CT_GroupShape head).
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "nvGrpSpPr"))
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "cNvPr"))
  w.attribute(@xml.QName::unqualified("id"), "0")
  w.attribute(@xml.QName::unqualified("name"), "")
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "cNvGrpSpPr"))
  w.end_element()
  w.end_element() // nvGrpSpPr
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "grpSpPr"))
  w.end_element()
  // One <dsp:sp> per node.
  for i, node in self.nodes {
    write_dsp_sp(w, node_id(i), node.text, boxes[i])
  }
  w.end_element() // spTree
  w.end_element() // drawing
  w.to_string()
}

///|
/// One laid-out `<dsp:sp>` (rounded box) with `text` at rectangle `b`.
fn write_dsp_sp(
  w : @xml.XmlWriter,
  model_id : String,
  text : String,
  b : Box,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "sp"))
  w.attribute(@xml.QName::unqualified("modelId"), model_id)
  // nvSpPr
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "nvSpPr"))
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "cNvPr"))
  w.attribute(@xml.QName::unqualified("id"), "0")
  w.attribute(@xml.QName::unqualified("name"), "")
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "cNvSpPr"))
  w.end_element()
  w.end_element() // nvSpPr
  // spPr: xfrm + geometry + fill + line
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "spPr"))
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "xfrm"))
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "off"))
  w.attribute(@xml.QName::unqualified("x"), b.x.to_string())
  w.attribute(@xml.QName::unqualified("y"), b.y.to_string())
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "ext"))
  w.attribute(@xml.QName::unqualified("cx"), b.w.to_string())
  w.attribute(@xml.QName::unqualified("cy"), b.h.to_string())
  w.end_element()
  w.end_element() // xfrm
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "prstGeom"))
  w.attribute(@xml.QName::unqualified("prst"), "roundRect")
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "avLst"))
  w.end_element()
  w.end_element() // prstGeom
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "solidFill"))
  write_scheme_clr(w, "accent1")
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "ln"))
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "solidFill"))
  write_scheme_clr(w, "lt1")
  w.end_element()
  w.end_element() // ln
  w.end_element() // spPr
  // txBody
  w.start_element(@xml.QName::new(@oxml.diagram_drawing_ns, "txBody"))
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "bodyPr"))
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "lstStyle"))
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "p"))
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "pPr"))
  w.attribute(@xml.QName::unqualified("algn"), "ctr")
  w.end_element()
  if text == "" {
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "endParaRPr"))
    w.attribute(@xml.QName::unqualified("lang"), "en-US")
    w.end_element()
  } else {
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "r"))
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "rPr"))
    w.attribute(@xml.QName::unqualified("lang"), "en-US")
    w.end_element()
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "t"))
    w.text(text)
    w.end_element()
    w.end_element() // r
  }
  w.end_element() // p
  w.end_element() // txBody
  w.end_element() // sp
}

///|
/// `<a:schemeClr val="…"/>`.
fn write_scheme_clr(
  w : @xml.XmlWriter,
  val : String,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "schemeClr"))
  w.attribute(@xml.QName::unqualified("val"), val)
  w.end_element()
}
