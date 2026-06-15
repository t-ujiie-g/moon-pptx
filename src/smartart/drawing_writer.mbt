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
/// Compute one box rectangle per flat node within `cx` × `cy`, per `kind`.
/// Boxes are returned in `gidx` order (so `boxes[f.gidx]` is `f`'s rectangle).
/// The flat families ignore the (depth-1) tree and lay out by index; the
/// hierarchical families place parents centred above their children.
fn layout_boxes(
  kind : SmartArtKind,
  flat : Array[FlatNode],
  cx : Int64,
  cy : Int64,
) -> Array[Box] {
  let boxes = []
  let n = flat.length()
  if n <= 0 {
    return boxes
  }
  let nl = n.to_int64()
  match kind {
    OrgChart | Hierarchy => return tree_layout(flat, cx, cy)
    Relationship => return radial_layout(flat, cx, cy)
    Matrix => {
      // Roughly-square grid: smallest `cols` with cols² ≥ n.
      let mut cols = 1
      while cols * cols < n {
        cols = cols + 1
      }
      let rows = (n + cols - 1) / cols
      let cell_w = cx / cols.to_int64()
      let cell_h = cy / rows.to_int64()
      let gap_x = cell_w / 20L
      let gap_y = cell_h / 20L
      for i in 0..<n {
        let col = (i % cols).to_int64()
        let row = (i / cols).to_int64()
        boxes.push({
          x: col * cell_w + gap_x / 2L,
          y: row * cell_h + gap_y / 2L,
          w: cell_w - gap_x,
          h: cell_h - gap_y,
        })
      }
    }
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
/// A tidy top-down tree layout: leaves get successive horizontal slots
/// (left-to-right), each parent is centred over the average of its children's
/// slots, and depth maps to the vertical level. Returns one box per flat node
/// in `gidx` order.
fn tree_layout(flat : Array[FlatNode], cx : Int64, cy : Int64) -> Array[Box] {
  let n = flat.length()
  let slot = Array::make(n, 0.0)
  // Leaves, in pre-order (= left-to-right), take successive slots.
  let mut leaf_count = 0
  for f in flat {
    if f.is_leaf() {
      slot[f.gidx] = leaf_count.to_double()
      leaf_count = leaf_count + 1
    }
  }
  if leaf_count == 0 {
    leaf_count = 1
  }
  // Internal nodes (reverse gidx → all descendants resolved first) sit at the
  // average of their children's slots.
  for k = n - 1; k >= 0; k = k - 1 {
    let f = flat[k]
    if !f.is_leaf() {
      let mut sum = 0.0
      for c in f.children_gidx {
        sum = sum + slot[c]
      }
      slot[k] = sum / f.children_gidx.length().to_double()
    }
  }
  let mut max_depth = 0
  for f in flat {
    if f.depth > max_depth {
      max_depth = f.depth
    }
  }
  let cxf = cx.to_double()
  let cyf = cy.to_double()
  let level_h = cyf / (max_depth + 1).to_double()
  let col_w = cxf / leaf_count.to_double()
  let boxw = col_w * 0.85
  let boxh = level_h * 0.6
  let boxes = []
  for f in flat {
    let x_center = (slot[f.gidx] + 0.5) * col_w
    let y_top = f.depth.to_double() * level_h + (level_h - boxh) / 2.0
    boxes.push({
      x: (x_center - boxw / 2.0).to_int64(),
      y: y_top.to_int64(),
      w: boxw.to_int64(),
      h: boxh.to_int64(),
    })
  }
  boxes
}

///|
/// Hub-and-spoke layout: the first node (gidx 0, the hub) sits at the frame
/// centre; every other node is spread evenly around it on a ring. Returns one
/// box per flat node in `gidx` order.
fn radial_layout(flat : Array[FlatNode], cx : Int64, cy : Int64) -> Array[Box] {
  let n = flat.length()
  let cxf = cx.to_double()
  let cyf = cy.to_double()
  let cx0 = cxf / 2.0
  let cy0 = cyf / 2.0
  let minside = if cxf < cyf { cxf } else { cyf }
  let hub = minside * 0.30
  let spoke = minside * 0.24
  let radius = minside * 0.36
  let spokes = n - 1
  let boxes = []
  for f in flat {
    if f.gidx == 0 {
      // The hub, centred.
      boxes.push({
        x: (cx0 - hub / 2.0).to_int64(),
        y: (cy0 - hub / 2.0).to_int64(),
        w: hub.to_int64(),
        h: hub.to_int64(),
      })
    } else {
      let k = (f.gidx - 1).to_double()
      let ang = two_pi * k / spokes.to_double() - half_pi
      let bxc = cx0 + radius * @math.cos(ang)
      let byc = cy0 + radius * @math.sin(ang)
      boxes.push({
        x: (bxc - spoke / 2.0).to_int64(),
        y: (byc - spoke / 2.0).to_int64(),
        w: spoke.to_int64(),
        h: spoke.to_int64(),
      })
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
  let flat = flatten(self.nodes)
  let boxes = layout_boxes(self.kind, flat, cxv, cyv)
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
  // One <dsp:sp> per node (every node in the forest, in gidx order).
  for f in flat {
    write_dsp_sp(w, node_id(f.gidx), f.text, boxes[f.gidx])
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
  write_run_or_endpara(w, text)
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
