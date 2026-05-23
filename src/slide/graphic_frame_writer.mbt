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
  // <a:tblPr> — emit the captured element if present.
  match tbl.properties {
    Some(p) => @oxml.write_xml_element(w, ctx, p)
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
  // <a:tcPr> — emit the captured element if present.
  match cell.properties {
    Some(p) => @oxml.write_xml_element(w, ctx, p)
    None => ()
  }
  for ext in cell.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
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
