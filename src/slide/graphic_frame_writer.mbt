// Graphic frame + table writer — Phase 6b slice.
//
// Inverse of `graphic_frame_parser.mbt`. Emits `<p:graphicFrame>`
// with `<p:nvGraphicFramePr>` (reusing the captured wrappers from
// `extension`), `<p:xfrm>` (presentation-ns wrapper, drawing-ns
// `<a:off>` / `<a:ext>` inside), and `<a:graphic><a:graphicData
// uri="…">…</a:graphicData></a:graphic>` carrying the typed Table
// or pass-through `OtherGraphic` element.

///|
fn write_graphic_frame(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  gf : GraphicFrame,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "graphicFrame"))
  // <p:nvGraphicFramePr> — reuses the captured-wrapper pattern from
  // sp / pic / grpSp via write_nv_wrapper. The wrapper's per-kind
  // child is <p:cNvGraphicFramePr>.
  write_nv_wrapper(
    w,
    ctx,
    "nvGraphicFramePr",
    "cNvGraphicFramePr",
    gf.id,
    gf.name,
    None,
    gf.extension,
  )
  // <p:xfrm> — graphicFrame's transform wrapper is presentation-ns,
  // not drawing-ns. Body uses drawing-ns <a:off> / <a:ext>.
  match gf.transform {
    Some(xfrm) => write_pml_xfrm(w, xfrm)
    None => ()
  }
  // <a:graphic><a:graphicData uri="…">…</a:graphicData></a:graphic>
  write_graphic_body(w, ctx, gf.content)
  // Any captured body-level extensions (foreign-namespace siblings,
  // <p:extLst>, etc.) that aren't part of the nv wrapper or xfrm.
  write_body_extensions(w, ctx, gf.extension, "cNvGraphicFramePr")
  w.end_element()
}

///|
/// Emit `<p:xfrm><a:off …/><a:ext …/></p:xfrm>` — graphic-frame
/// transform wrapper. Note: `<p:xfrm>` lives in the presentation
/// namespace, not the drawing namespace like AutoShape's `<a:xfrm>`.
fn write_pml_xfrm(
  w : @xml.XmlWriter,
  xfrm : Transform,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.presentation_ns, "xfrm"))
  let @units.Emu(x) = xfrm.offset.x
  let @units.Emu(y) = xfrm.offset.y
  let @units.Emu(cx) = xfrm.extent.cx
  let @units.Emu(cy) = xfrm.extent.cy
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "off"))
  w.attribute(@xml.QName::unqualified("x"), x.to_string())
  w.attribute(@xml.QName::unqualified("y"), y.to_string())
  w.end_element()
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "ext"))
  w.attribute(@xml.QName::unqualified("cx"), cx.to_string())
  w.attribute(@xml.QName::unqualified("cy"), cy.to_string())
  w.end_element()
  w.end_element()
}

///|
fn write_graphic_body(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  content : GraphicFrameContent,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "graphic"))
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "graphicData"))
  match content {
    TableContent(tbl) => {
      w.attribute(@xml.QName::unqualified("uri"), graphic_data_table_uri)
      write_table(w, ctx, tbl)
    }
    OtherGraphic(uri, captured) => {
      w.attribute(@xml.QName::unqualified("uri"), uri)
      // The captured element is the original <a:graphicData> — emit
      // its children verbatim so chart / SmartArt / OLE round-trip.
      for node in captured.children {
        match node {
          Element(c) => @oxml.write_xml_element(w, ctx, c)
          Text(s) => w.text(s)
          CData(s) => w.cdata(s)
        }
      }
    }
  }
  w.end_element() // graphicData
  w.end_element() // graphic
}

///|
fn write_table(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  tbl : Table,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "tbl"))
  // <a:tblPr> — typed body.
  match tbl.properties {
    Some(p) => write_tbl_pr(w, ctx, p)
    None => ()
  }
  // <a:tblGrid> — generated from typed widths.
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "tblGrid"))
  for col_w in tbl.grid {
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "gridCol"))
    let @units.Emu(n) = col_w
    w.attribute(@xml.QName::unqualified("w"), n.to_string())
    w.end_element()
  }
  w.end_element()
  // <a:tr> rows in source order.
  for row in tbl.rows {
    write_tr(w, ctx, row)
  }
  // Captured tail extension.
  for ext in tbl.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_tr(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  row : TableRow,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "tr"))
  let @units.Emu(h) = row.height
  w.attribute(@xml.QName::unqualified("h"), h.to_string())
  for cell in row.cells {
    write_tc(w, ctx, cell)
  }
  for ext in row.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_tc(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  cell : TableCell,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "tc"))
  if cell.grid_span != 1 {
    w.attribute(@xml.QName::unqualified("gridSpan"), cell.grid_span.to_string())
  }
  if cell.row_span != 1 {
    w.attribute(@xml.QName::unqualified("rowSpan"), cell.row_span.to_string())
  }
  if cell.h_merge {
    w.attribute(@xml.QName::unqualified("hMerge"), "1")
  }
  if cell.v_merge {
    w.attribute(@xml.QName::unqualified("vMerge"), "1")
  }
  // <a:txBody> — re-using the same text-body writer the slide uses
  // for <p:txBody>; the structural shape is identical, only the
  // local name and namespace of the wrapper differ.
  match cell.text_body {
    Some(tb) => write_table_cell_text_body(w, ctx, tb)
    None => ()
  }
  // <a:tcPr> — typed body.
  match cell.properties {
    Some(p) => write_tc_pr(w, ctx, p)
    None => ()
  }
  for ext in cell.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit `<a:tblPr>` from typed `TableProperties`. Body order
/// follows the ECMA-376 schema: fill choice → `<a:tableStyleId>` →
/// captured extension tail.
fn write_tbl_pr(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  p : TableProperties,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "tblPr"))
  emit_bool_attr(w, "firstRow", p.first_row)
  emit_bool_attr(w, "firstCol", p.first_col)
  emit_bool_attr(w, "lastRow", p.last_row)
  emit_bool_attr(w, "lastCol", p.last_col)
  emit_bool_attr(w, "bandRow", p.band_row)
  emit_bool_attr(w, "bandCol", p.band_col)
  emit_bool_attr(w, "rtl", p.rtl)
  match p.fill {
    Some(f) => @oxml.write_fill(w, ctx, f)
    None => ()
  }
  match p.table_style_id {
    Some(s) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "tableStyleId"))
      w.text(s)
      w.end_element()
    }
    None => ()
  }
  for ext in p.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit `<a:tcPr>` from typed `TableCellProperties`. Body order
/// follows the ECMA-376 schema: lnL → lnR → lnT → lnB → lnTlToBr
/// → lnBlToTr → fill choice → captured extension tail.
fn write_tc_pr(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  p : TableCellProperties,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "tcPr"))
  emit_emu_attr(w, "marL", p.margin_l)
  emit_emu_attr(w, "marT", p.margin_t)
  emit_emu_attr(w, "marR", p.margin_r)
  emit_emu_attr(w, "marB", p.margin_b)
  match p.vertical_text {
    Some(v) =>
      w.attribute(@xml.QName::unqualified("vert"), vertical_text_to_xml(v))
    None => ()
  }
  match p.anchor {
    Some(a) => w.attribute(@xml.QName::unqualified("anchor"), anchor_to_xml(a))
    None => ()
  }
  emit_bool_attr(w, "anchorCtr", p.anchor_ctr)
  match p.border_left {
    Some(s) => @oxml.write_stroke_with_local_name(w, ctx, s, "lnL")
    None => ()
  }
  match p.border_right {
    Some(s) => @oxml.write_stroke_with_local_name(w, ctx, s, "lnR")
    None => ()
  }
  match p.border_top {
    Some(s) => @oxml.write_stroke_with_local_name(w, ctx, s, "lnT")
    None => ()
  }
  match p.border_bottom {
    Some(s) => @oxml.write_stroke_with_local_name(w, ctx, s, "lnB")
    None => ()
  }
  match p.border_tl_to_br {
    Some(s) => @oxml.write_stroke_with_local_name(w, ctx, s, "lnTlToBr")
    None => ()
  }
  match p.border_bl_to_tr {
    Some(s) => @oxml.write_stroke_with_local_name(w, ctx, s, "lnBlToTr")
    None => ()
  }
  match p.fill {
    Some(f) => @oxml.write_fill(w, ctx, f)
    None => ()
  }
  for ext in p.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit an attribute holding "1" or "0" iff the option is `Some`.
fn emit_bool_attr(
  w : @xml.XmlWriter,
  name : String,
  v : Bool?,
) -> Unit raise @xml.XmlError {
  match v {
    Some(b) =>
      w.attribute(@xml.QName::unqualified(name), if b { "1" } else { "0" })
    None => ()
  }
}

///|
/// Emit an attribute holding the EMU value iff the option is `Some`.
fn emit_emu_attr(
  w : @xml.XmlWriter,
  name : String,
  v : @units.Emu?,
) -> Unit raise @xml.XmlError {
  match v {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified(name), n.to_string())
    None => ()
  }
}

///|
/// Emit `<a:txBody>` (drawing-ns) instead of `<p:txBody>`.
/// Delegates to the shared parameterised helper in `text_writer.mbt`
/// so cell text bodies and slide-shape text bodies stay in lockstep.
fn write_table_cell_text_body(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  tb : TextBody,
) -> Unit raise @xml.XmlError {
  write_text_body_with_wrapper(w, ctx, tb, @oxml.drawing_ns, "txBody")
}
