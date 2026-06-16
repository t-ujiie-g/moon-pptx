// Text-body writer.
//
// Inverse of `text_parser.mbt`. Each `write_*` helper opens its element
// and writes children in source order. The `extension` arrays on every
// node (`TextBody` / `BodyProperties` / `ListStyle` / `Paragraph` /
// `ParagraphProperties` / `Run` / `Field` / `RunProperties`) replay
// captured unknown children via `@oxml.write_xml_element`.

///|
fn write_text_body(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  tb : TextBody,
) -> Unit raise @xml.XmlError {
  write_text_body_with_wrapper(w, ctx, tb, @oxml.presentation_ns, "txBody")
}

///|
/// Emit a text body inside a wrapper of the caller's choice. Slide
/// AutoShapes wrap with `<p:txBody>` (presentation-ns); table cells
/// wrap with `<a:txBody>` (drawing-ns). The body structure is
/// identical between the two callers, so the wrapper is the only
/// parameter that varies.
fn write_text_body_with_wrapper(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  tb : TextBody,
  wrapper_uri : String,
  wrapper_local : String,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(wrapper_uri, wrapper_local))
  match tb.body_properties {
    Some(bp) => write_body_properties(w, ctx, bp)
    None => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "bodyPr"))
      w.end_element()
    }
  }
  match tb.list_style {
    Some(ls) => write_list_style(w, ctx, ls)
    None => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "lstStyle"))
      w.end_element()
    }
  }
  for p in tb.paragraphs {
    write_paragraph(w, ctx, p)
  }
  for ext in tb.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_body_properties(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  bp : BodyProperties,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "bodyPr"))
  match bp.rotation {
    Some(a) =>
      w.attribute(@xml.QName::unqualified("rot"), a.to_ooxml().to_string())
    None => ()
  }
  match bp.vertical_text {
    Some(v) =>
      w.attribute(@xml.QName::unqualified("vert"), vertical_text_to_xml(v))
    None => ()
  }
  match bp.wrap {
    Some(wr) =>
      w.attribute(@xml.QName::unqualified("wrap"), wrap_kind_to_xml(wr))
    None => ()
  }
  match bp.left_inset {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("lIns"), n.to_string())
    None => ()
  }
  match bp.top_inset {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("tIns"), n.to_string())
    None => ()
  }
  match bp.right_inset {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("rIns"), n.to_string())
    None => ()
  }
  match bp.bottom_inset {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("bIns"), n.to_string())
    None => ()
  }
  match bp.anchor {
    Some(a) => w.attribute(@xml.QName::unqualified("anchor"), anchor_to_xml(a))
    None => ()
  }
  // Auto-fit choice (NoAutoFit / NormAutoFit / SpAutoFit).
  match bp.auto_fit {
    Some(NoAutoFit) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "noAutofit"))
      w.end_element()
    }
    Some(NormAutoFit(font_scale, ln_spc_reduction)) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "normAutofit"))
      w.attribute(
        @xml.QName::unqualified("fontScale"),
        font_scale.to_ooxml().to_string(),
      )
      w.attribute(
        @xml.QName::unqualified("lnSpcReduction"),
        ln_spc_reduction.to_ooxml().to_string(),
      )
      w.end_element()
    }
    Some(SpAutoFit) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "spAutoFit"))
      w.end_element()
    }
    None => ()
  }
  for ext in bp.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_list_style(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  ls : ListStyle,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "lstStyle"))
  // <a:defPPr> (defaults).
  match ls.default_props {
    Some(p) => write_paragraph_props_with_wrapper(w, ctx, "defPPr", p)
    None => ()
  }
  // <a:lvl1pPr> .. <a:lvl9pPr>.
  for i, lvl_props in ls.level_props {
    match lvl_props {
      Some(p) =>
        write_paragraph_props_with_wrapper(
          w,
          ctx,
          "lvl" + (i + 1).to_string() + "pPr",
          p,
        )
      None => ()
    }
  }
  for ext in ls.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_paragraph(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  p : Paragraph,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "p"))
  // Emit pPr only when at least one field is non-default.
  if needs_p_pr(p.properties) {
    write_paragraph_props_with_wrapper(w, ctx, "pPr", p.properties)
  }
  for c in p.content {
    match c {
      RunContent(r) => write_run(w, ctx, r)
      Break(rpr) => write_break(w, ctx, rpr)
      FieldContent(f) => write_field(w, ctx, f)
    }
  }
  for ext in p.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// True if `p` carries any non-default attribute or modeled child.
/// We avoid emitting an empty `<a:pPr/>` for the common default case.
fn needs_p_pr(p : ParagraphProperties) -> Bool {
  p.level != 0 ||
  p.alignment is Some(_) ||
  p.margin_left is Some(_) ||
  p.indent is Some(_) ||
  p.line_spacing is Some(_) ||
  p.space_before is Some(_) ||
  p.space_after is Some(_) ||
  p.bullet is Some(_) ||
  p.extension.length() > 0
}

///|
fn write_paragraph_props_with_wrapper(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  wrapper_local : String,
  p : ParagraphProperties,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, wrapper_local))
  if p.level != 0 {
    w.attribute(@xml.QName::unqualified("lvl"), p.level.to_string())
  }
  match p.margin_left {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("marL"), n.to_string())
    None => ()
  }
  match p.indent {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("indent"), n.to_string())
    None => ()
  }
  match p.alignment {
    Some(a) =>
      w.attribute(@xml.QName::unqualified("algn"), text_alignment_to_xml(a))
    None => ()
  }
  // Body content: lnSpc, spcBef, spcAft, bullet.
  match p.line_spacing {
    Some(pct) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "lnSpc"))
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "spcPct"))
      w.attribute(@xml.QName::unqualified("val"), pct.to_ooxml().to_string())
      w.end_element()
      w.end_element()
    }
    None => ()
  }
  match p.space_before {
    Some(pt) => write_spc_pts(w, "spcBef", pt)
    None => ()
  }
  match p.space_after {
    Some(pt) => write_spc_pts(w, "spcAft", pt)
    None => ()
  }
  match p.bullet {
    Some(b) => write_bullet(w, ctx, b)
    None => ()
  }
  for ext in p.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit `<a:spcBef>` / `<a:spcAft>` with the `<a:spcPts val="…"/>` child.
/// Pt is multiplied by 100 to match the OOXML encoding (1/100-point).
fn write_spc_pts(
  w : @xml.XmlWriter,
  wrapper_local : String,
  pt : @units.Pt,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, wrapper_local))
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "spcPts"))
  let @units.Pt(v) = pt
  let centi = (v * 100.0).to_int()
  w.attribute(@xml.QName::unqualified("val"), centi.to_string())
  w.end_element()
  w.end_element()
}

///|
fn write_bullet(
  w : @xml.XmlWriter,
  _ctx : @oxml.WriteCtx,
  b : Bullet,
) -> Unit raise @xml.XmlError {
  match b {
    BulNone => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "buNone"))
      w.end_element()
    }
    Char(s) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "buChar"))
      w.attribute(@xml.QName::unqualified("char"), s)
      w.end_element()
    }
    AutoNum(t, start) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "buAutoNum"))
      w.attribute(@xml.QName::unqualified("type"), auto_num_type_to_xml(t))
      if start != 1 {
        w.attribute(@xml.QName::unqualified("startAt"), start.to_string())
      }
      w.end_element()
    }
    Picture(rid) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "buBlip"))
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "blip"))
      w.attribute(@xml.QName::new(@oxml.office_relationships_ns, "embed"), rid)
      w.end_element()
      w.end_element()
    }
  }
}

///|
fn write_run(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  r : Run,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "r"))
  write_run_properties(w, ctx, "rPr", r.properties)
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "t"))
  w.text(r.text)
  w.end_element()
  for ext in r.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_break(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  rpr : RunProperties,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "br"))
  if needs_r_pr(rpr) {
    write_run_properties(w, ctx, "rPr", rpr)
  }
  w.end_element()
}

///|
fn write_field(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  f : Field,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "fld"))
  w.attribute(@xml.QName::unqualified("id"), f.id)
  w.attribute(@xml.QName::unqualified("type"), f.field_type)
  write_run_properties(w, ctx, "rPr", f.properties)
  if f.text != "" {
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "t"))
    w.text(f.text)
    w.end_element()
  }
  for ext in f.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn needs_r_pr(p : RunProperties) -> Bool {
  p.lang != "" ||
  p.font_size is Some(_) ||
  p.character_spacing is Some(_) ||
  p.kerning is Some(_) ||
  p.bold is Some(_) ||
  p.italic is Some(_) ||
  p.underline is Some(_) ||
  p.strikethrough is Some(_) ||
  p.baseline is Some(_) ||
  p.caps is Some(_) ||
  p.latin is Some(_) ||
  p.east_asian is Some(_) ||
  p.complex_script is Some(_) ||
  p.fill is Some(_) ||
  p.outline is Some(_) ||
  p.text_effects is Some(_) ||
  p.highlight is Some(_) ||
  p.hyperlink_click is Some(_) ||
  p.extension.length() > 0
}

///|
fn write_run_properties(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  wrapper_local : String,
  p : RunProperties,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, wrapper_local))
  if p.lang != "" {
    w.attribute(@xml.QName::unqualified("lang"), p.lang)
  }
  match p.font_size {
    Some(pt) => {
      let @units.Pt(v) = pt
      let centi = (v * 100.0).to_int()
      w.attribute(@xml.QName::unqualified("sz"), centi.to_string())
    }
    None => ()
  }
  match p.character_spacing {
    Some(pt) => {
      let @units.Pt(v) = pt
      let centi = (v * 100.0).to_int()
      w.attribute(@xml.QName::unqualified("spc"), centi.to_string())
    }
    None => ()
  }
  match p.kerning {
    Some(pt) => {
      let @units.Pt(v) = pt
      let centi = (v * 100.0).to_int()
      w.attribute(@xml.QName::unqualified("kern"), centi.to_string())
    }
    None => ()
  }
  match p.bold {
    Some(b) =>
      w.attribute(@xml.QName::unqualified("b"), if b { "1" } else { "0" })
    None => ()
  }
  match p.italic {
    Some(b) =>
      w.attribute(@xml.QName::unqualified("i"), if b { "1" } else { "0" })
    None => ()
  }
  match p.underline {
    Some(u) => w.attribute(@xml.QName::unqualified("u"), underline_to_xml(u))
    None => ()
  }
  match p.strikethrough {
    Some(s) => w.attribute(@xml.QName::unqualified("strike"), strike_to_xml(s))
    None => ()
  }
  match p.baseline {
    Some(b) =>
      w.attribute(@xml.QName::unqualified("baseline"), b.to_ooxml().to_string())
    None => ()
  }
  match p.caps {
    Some(c) => w.attribute(@xml.QName::unqualified("cap"), caps_to_xml(c))
    None => ()
  }
  // Child elements in CT_TextCharacterProperties sequence order:
  // ln, fill, effectLst, highlight, …, latin/ea/cs, hlinkClick.
  // Outline (`<a:ln>`).
  match p.outline {
    Some(s) => @oxml.write_stroke(w, ctx, s)
    None => ()
  }
  // Solid fill child.
  match p.fill {
    Some(c) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "solidFill"))
      @oxml.write_color(w, ctx, c)
      w.end_element()
    }
    None => ()
  }
  // Text effects (`<a:effectLst>`).
  match p.text_effects {
    Some(e) => @oxml.write_effect_list(w, ctx, e)
    None => ()
  }
  // Highlight colour (`<a:highlight>`).
  match p.highlight {
    Some(c) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "highlight"))
      @oxml.write_color(w, ctx, c)
      w.end_element()
    }
    None => ()
  }
  // Typeface children.
  match p.latin {
    Some(face) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "latin"))
      w.attribute(@xml.QName::unqualified("typeface"), face)
      w.end_element()
    }
    None => ()
  }
  match p.east_asian {
    Some(face) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "ea"))
      w.attribute(@xml.QName::unqualified("typeface"), face)
      w.end_element()
    }
    None => ()
  }
  match p.complex_script {
    Some(face) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "cs"))
      w.attribute(@xml.QName::unqualified("typeface"), face)
      w.end_element()
    }
    None => ()
  }
  // Hyperlink-click rId + optional tooltip + optional action. The
  // `action` attribute is critical for internal-slide jumps: PowerPoint
  // expects `action="ppaction://hlinksldjump"` whenever the rId points
  // at another slide, and silently rewrites the hlinkClick to a no-op
  // if it isn't present.
  match p.hyperlink_click {
    Some(rid) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "hlinkClick"))
      w.attribute(@xml.QName::new(@oxml.office_relationships_ns, "id"), rid)
      match p.hyperlink_tooltip {
        Some(t) => w.attribute(@xml.QName::unqualified("tooltip"), t)
        None => ()
      }
      match p.hyperlink_action {
        Some(a) => w.attribute(@xml.QName::unqualified("action"), a)
        None => ()
      }
      w.end_element()
    }
    None => ()
  }
  for ext in p.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

// --- enum → xml helpers ---

///|
fn vertical_text_to_xml(v : VerticalText) -> String {
  match v {
    VertHorz => "horz"
    VertVert => "vert"
    VertVert270 => "vert270"
    VertWordArtVert => "wordArtVert"
    VertEaVert => "eaVert"
    VertMongolianVert => "mongolianVert"
    VertWordArtVertRtl => "wordArtVertRtl"
  }
}

///|
fn wrap_kind_to_xml(wr : WrapKind) -> String {
  match wr {
    WrapNone => "none"
    WrapSquare => "square"
  }
}

///|
fn anchor_to_xml(a : Anchor) -> String {
  match a {
    AnchorTop => "t"
    AnchorCenter => "ctr"
    AnchorBottom => "b"
    AnchorJustify => "just"
    AnchorDistributed => "dist"
  }
}

///|
fn text_alignment_to_xml(a : TextAlignment) -> String {
  match a {
    AlignLeft => "l"
    AlignCenter => "ctr"
    AlignRight => "r"
    AlignJustify => "just"
    AlignJustifyLow => "justLow"
    AlignDistributed => "dist"
    AlignThaiDistributed => "thaiDist"
  }
}

///|
fn underline_to_xml(u : UnderlineKind) -> String {
  match u {
    UlNone => "none"
    UlWords => "words"
    UlSingle => "sng"
    UlDouble => "dbl"
    UlHeavy => "heavy"
    UlDotted => "dotted"
    UlDottedHeavy => "dottedHeavy"
    UlDash => "dash"
    UlDashHeavy => "dashHeavy"
    UlDashLong => "dashLong"
    UlDashLongHeavy => "dashLongHeavy"
    UlDotDash => "dotDash"
    UlDotDashHeavy => "dotDashHeavy"
    UlDotDotDash => "dotDotDash"
    UlDotDotDashHeavy => "dotDotDashHeavy"
    UlWavy => "wavy"
    UlWavyHeavy => "wavyHeavy"
    UlWavyDouble => "wavyDbl"
  }
}

///|
fn strike_to_xml(s : StrikeKind) -> String {
  match s {
    StNoStrike => "noStrike"
    StSingle => "sngStrike"
    StDouble => "dblStrike"
  }
}

///|
fn caps_to_xml(c : CapsKind) -> String {
  match c {
    CapsNone => "none"
    CapsSmall => "small"
    CapsAll => "all"
  }
}

///|
fn auto_num_type_to_xml(t : AutoNumType) -> String {
  match t {
    ArabicPeriod => "arabicPeriod"
    ArabicParenR => "arabicParenR"
    ArabicParenBoth => "arabicParenBoth"
    ArabicPlain => "arabicPlain"
    ArabicDbPeriod => "arabicDbPeriod"
    ArabicDbPlain => "arabicDbPlain"
    RomanUcPeriod => "romanUcPeriod"
    RomanUcParenR => "romanUcParenR"
    RomanUcParenBoth => "romanUcParenBoth"
    RomanLcPeriod => "romanLcPeriod"
    RomanLcParenR => "romanLcParenR"
    RomanLcParenBoth => "romanLcParenBoth"
    AlphaUcPeriod => "alphaUcPeriod"
    AlphaUcParenR => "alphaUcParenR"
    AlphaUcParenBoth => "alphaUcParenBoth"
    AlphaLcPeriod => "alphaLcPeriod"
    AlphaLcParenR => "alphaLcParenR"
    AlphaLcParenBoth => "alphaLcParenBoth"
    CircleNumDbPlain => "circleNumDbPlain"
    CircleNumWdBlackPlain => "circleNumWdBlackPlain"
    CircleNumWdWhitePlain => "circleNumWdWhitePlain"
    Ea1ChsPlain => "ea1ChsPlain"
    Ea1ChsPeriod => "ea1ChsPeriod"
    Ea1ChtPlain => "ea1ChtPlain"
    Ea1ChtPeriod => "ea1ChtPeriod"
    Ea1JpnChsDbPeriod => "ea1JpnChsDbPeriod"
    Ea1JpnKorPlain => "ea1JpnKorPlain"
    Ea1JpnKorPeriod => "ea1JpnKorPeriod"
    Hebrew2Minus => "hebrew2Minus"
    ThaiAlphaPeriod => "thaiAlphaPeriod"
    ThaiAlphaParenR => "thaiAlphaParenR"
    ThaiAlphaParenBoth => "thaiAlphaParenBoth"
    ThaiNumPeriod => "thaiNumPeriod"
    ThaiNumParenR => "thaiNumParenR"
    ThaiNumParenBoth => "thaiNumParenBoth"
    HindiAlphaPeriod => "hindiAlphaPeriod"
    HindiNumPeriod => "hindiNumPeriod"
    HindiNumParenR => "hindiNumParenR"
    HindiAlpha1Period => "hindiAlpha1Period"
  }
}
