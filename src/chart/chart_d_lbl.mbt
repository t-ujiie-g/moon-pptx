// Typed per-data-point data-label override (CT_DLbl).
//
// `<c:dLbl>` (ECMA-376 §21.2.2.47, CT_DLbl) is the per-data-point
// override inside `<c:dLbls>`. Each entry targets a single data
// point by its `<c:idx>` and either hides the label entirely
// (`<c:delete val="1"/>`) or provides per-point styling overrides
// (full EG_DLbls body plus optional `<c:layout>` / `<c:tx>` rich
// text).
//
// Schema body (CT_DLbl):
//
//   <c:idx>           (REQUIRED, UInt)
//   choice (EG_DLblChoice):
//     - <c:delete>    (CT_Boolean — if true, hide this point's label)
//     OR
//     - <c:layout>?   (CT_Layout)
//       <c:tx>?       (CT_Tx — rich text body or strRef)
//       EG_DLbls (numFmt, spPr, txPr, dLblPos, showLegendKey,
//                 showVal, showCatName, showSerName, showPercent,
//                 showBubbleSize, separator)
//   <c:extLst>?
//
// Both choice branches are stored as optional fields so the source
// shape round-trips faithfully (in practice only one is present at
// a time). `<c:layout>` / `<c:tx>` keep round-tripping as captured
// XmlElement until later slices type them; every other EG_DLbls
// leaf lifts to a typed value (sharing the same enum / Bool / String
// vocabulary as `DLbls`).

///|
/// Per-data-point label override (`<c:dLbl>`, CT_DLbl). The
/// schema offers two choices: hide this point's label via
/// `delete=true`, or override the full styling — both branches
/// are stored optional so the writer round-trips whatever is set.
pub(all) struct DLbl {
  /// `<c:idx val="…"/>` — REQUIRED. Identifies which data point.
  idx : Int
  /// `<c:delete val="…"/>` — EG_DLblChoice branch 1.
  delete : Bool?
  /// `<c:layout>` (CT_Layout). Captured.
  layout : Layout?
  /// `<c:tx>` (CT_Tx) — per-point label text override. Captured.
  tx : @xml.XmlElement?
  /// `<c:numFmt>` (CT_NumFmt) — number-format override.
  num_fmt : NumFmt?
  /// `<c:spPr>` (CT_ShapeProperties). Captured.
  sp_pr : @xml.XmlElement?
  /// `<c:txPr>` (CT_TextBody). Captured.
  tx_pr : @xml.XmlElement?
  /// `<c:dLblPos val="…"/>` — per-point label placement.
  d_lbl_pos : DLblPos?
  show_legend_key : Bool?
  show_val : Bool?
  show_cat_name : Bool?
  show_ser_name : Bool?
  show_percent : Bool?
  show_bubble_size : Bool?
  separator : String?
  /// `<c:extLst>` and foreign-namespace siblings. ADR-004.
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
pub impl Show for DLbl with fn output(self, logger) {
  logger.write_string("DLbl(idx=")
  logger.write_string(self.idx.to_string())
  logger.write_string(")")
}

// --- parsing -----------------------------------------------------------------

///|
/// Walk a captured `<c:dLbl>` element into a typed `DLbl`. Raises
/// `Malformed` if the schema-required `<c:idx>` leaf is absent.
fn parse_d_lbl(el : @xml.XmlElement) -> DLbl raise ChartError {
  let mut idx : Int? = None
  let mut delete : Bool? = None
  let mut layout : Layout? = None
  let mut tx : @xml.XmlElement? = None
  let mut num_fmt : NumFmt? = None
  let mut sp_pr : @xml.XmlElement? = None
  let mut tx_pr : @xml.XmlElement? = None
  let mut d_lbl_pos : DLblPos? = None
  let mut show_legend_key : Bool? = None
  let mut show_val : Bool? = None
  let mut show_cat_name : Bool? = None
  let mut show_ser_name : Bool? = None
  let mut show_percent : Bool? = None
  let mut show_bubble_size : Bool? = None
  let mut separator : String? = None
  let extension : Array[@xml.XmlElement] = []
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.uri != @oxml.chart_ns {
          extension.push(c)
        } else {
          match c.name.local_name {
            "idx" => idx = val_int(c)
            "delete" => delete = val_bool(c)
            "layout" => layout = Some(parse_layout(c))
            "tx" => tx = Some(c)
            "numFmt" => num_fmt = Some(parse_num_fmt(c))
            "spPr" => sp_pr = Some(c)
            "txPr" => tx_pr = Some(c)
            "dLblPos" => d_lbl_pos = val_string(c).bind(DLblPos::from_xml)
            "showLegendKey" => show_legend_key = val_bool(c)
            "showVal" => show_val = val_bool(c)
            "showCatName" => show_cat_name = val_bool(c)
            "showSerName" => show_ser_name = val_bool(c)
            "showPercent" => show_percent = val_bool(c)
            "showBubbleSize" => show_bubble_size = val_bool(c)
            "separator" => separator = Some(extract_text_content(c))
            _ => extension.push(c)
          }
        }
      _ => ()
    }
  }
  let i = match idx {
    Some(n) => n
    None => raise Malformed("<c:dLbl> is missing required <c:idx>")
  }
  {
    idx: i,
    delete,
    layout,
    tx,
    num_fmt,
    sp_pr,
    tx_pr,
    d_lbl_pos,
    show_legend_key,
    show_val,
    show_cat_name,
    show_ser_name,
    show_percent,
    show_bubble_size,
    separator,
    extension,
  }
}

// --- writing -----------------------------------------------------------------

///|
/// Emit a `<c:dLbl>` element. Child order follows ECMA-376
/// §21.2.2.47: idx → delete (choice 1) OR (layout → tx → numFmt →
/// spPr → txPr → dLblPos → show* → separator) (choice 2) → extension.
///
/// The schema requires exactly one of the two EG_DLblChoice branches;
/// the parser tolerates both being set or neither, and the writer
/// emits whatever is set. Real-world files don't mix the two
/// branches, so the produced XML is schema-conformant in practice.
fn write_d_lbl(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  d : DLbl,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "dLbl"))
  w.start_element(@xml.QName::new(@oxml.chart_ns, "idx"))
  w.attribute(@xml.QName::unqualified("val"), d.idx.to_string())
  w.end_element()
  match d.delete {
    Some(b) => emit_val_bool(w, "delete", b)
    None => ()
  }
  match d.layout {
    Some(l) => write_layout(w, ctx, l)
    None => ()
  }
  match d.tx {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match d.num_fmt {
    Some(nf) => write_num_fmt(w, nf)
    None => ()
  }
  match d.sp_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match d.tx_pr {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match d.d_lbl_pos {
    Some(p) => emit_val_string(w, "dLblPos", p.to_xml())
    None => ()
  }
  match d.show_legend_key {
    Some(b) => emit_val_bool(w, "showLegendKey", b)
    None => ()
  }
  match d.show_val {
    Some(b) => emit_val_bool(w, "showVal", b)
    None => ()
  }
  match d.show_cat_name {
    Some(b) => emit_val_bool(w, "showCatName", b)
    None => ()
  }
  match d.show_ser_name {
    Some(b) => emit_val_bool(w, "showSerName", b)
    None => ()
  }
  match d.show_percent {
    Some(b) => emit_val_bool(w, "showPercent", b)
    None => ()
  }
  match d.show_bubble_size {
    Some(b) => emit_val_bool(w, "showBubbleSize", b)
    None => ()
  }
  match d.separator {
    Some(s) => {
      w.start_element(@xml.QName::new(@oxml.chart_ns, "separator"))
      w.text(s)
      w.end_element()
    }
    None => ()
  }
  for ext in d.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}
