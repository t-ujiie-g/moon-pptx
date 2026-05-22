// Stroke writer — Phase 4c slice.
//
// Inverse of `parse_stroke`. Emits an `<a:ln>` start element with the
// modeled width/cap/cmpd/algn attributes, then its children in
// schema-canonical order: fill choice → dash → join → headEnd →
// tailEnd → unmodelled extension.

///|
/// Emit an `<a:ln>` element representing `s`. Caller controls the
/// surrounding context.
pub fn write_stroke(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  s : Stroke,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "ln"))
  match s.width {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("w"), n.to_string())
    None => ()
  }
  match s.cap {
    Some(c) => w.attribute(@xml.QName::unqualified("cap"), line_cap_to_xml(c))
    None => ()
  }
  match s.compound {
    Some(c) =>
      w.attribute(@xml.QName::unqualified("cmpd"), compound_line_to_xml(c))
    None => ()
  }
  match s.alignment {
    Some(a) =>
      w.attribute(@xml.QName::unqualified("algn"), pen_alignment_to_xml(a))
    None => ()
  }
  // Fill choice.
  match s.fill {
    Some(f) => write_fill(w, ctx, f)
    None => ()
  }
  // Dash.
  match s.dash {
    Some(d) => {
      w.start_element(@xml.QName::new(drawing_ns, "prstDash"))
      w.attribute(@xml.QName::unqualified("val"), dash_style_to_xml(d))
      w.end_element()
    }
    None => ()
  }
  // Join.
  match s.join {
    Some(JoinRound) => {
      w.start_element(@xml.QName::new(drawing_ns, "round"))
      w.end_element()
    }
    Some(JoinBevel) => {
      w.start_element(@xml.QName::new(drawing_ns, "bevel"))
      w.end_element()
    }
    Some(JoinMiter(lim)) => {
      w.start_element(@xml.QName::new(drawing_ns, "miter"))
      match lim {
        Some(p) =>
          w.attribute(@xml.QName::unqualified("lim"), p.to_ooxml().to_string())
        None => ()
      }
      w.end_element()
    }
    None => ()
  }
  // Arrow ends.
  match s.head_end {
    Some(a) => write_arrow_end(w, "headEnd", a)
    None => ()
  }
  match s.tail_end {
    Some(a) => write_arrow_end(w, "tailEnd", a)
    None => ()
  }
  // Captured unmodelled tail.
  for ext in s.extension {
    write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_arrow_end(
  w : @xml.XmlWriter,
  wrapper_local : String,
  a : ArrowEnd,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, wrapper_local))
  w.attribute(@xml.QName::unqualified("type"), arrow_type_to_xml(a.arrow_type))
  match a.width {
    Some(s) => w.attribute(@xml.QName::unqualified("w"), arrow_size_to_xml(s))
    None => ()
  }
  match a.length {
    Some(s) => w.attribute(@xml.QName::unqualified("len"), arrow_size_to_xml(s))
    None => ()
  }
  w.end_element()
}

///|
fn line_cap_to_xml(c : LineCap) -> String {
  match c {
    CapFlat => "flat"
    CapRound => "rnd"
    CapSquare => "sq"
  }
}

///|
fn compound_line_to_xml(c : CompoundLine) -> String {
  match c {
    CmpdSingle => "sng"
    CmpdDouble => "dbl"
    CmpdThickThin => "thickThin"
    CmpdThinThick => "thinThick"
    CmpdTriple => "tri"
  }
}

///|
fn pen_alignment_to_xml(p : PenAlignment) -> String {
  match p {
    AlignPenCenter => "ctr"
    AlignPenInset => "in"
  }
}

///|
fn dash_style_to_xml(d : DashStyle) -> String {
  match d {
    DashSolid => "solid"
    DashDot => "dot"
    DashDash => "dash"
    DashLgDash => "lgDash"
    DashDashDot => "dashDot"
    DashLgDashDot => "lgDashDot"
    DashLgDashDotDot => "lgDashDotDot"
    DashSysDash => "sysDash"
    DashSysDot => "sysDot"
    DashSysDashDot => "sysDashDot"
    DashSysDashDotDot => "sysDashDotDot"
  }
}

///|
fn arrow_type_to_xml(t : ArrowType) -> String {
  match t {
    ArrowNone => "none"
    ArrowTriangle => "triangle"
    ArrowStealth => "stealth"
    ArrowDiamond => "diamond"
    ArrowOval => "oval"
    ArrowArrow => "arrow"
  }
}

///|
fn arrow_size_to_xml(s : ArrowSize) -> String {
  match s {
    SizeSmall => "sm"
    SizeMedium => "med"
    SizeLarge => "lg"
  }
}
