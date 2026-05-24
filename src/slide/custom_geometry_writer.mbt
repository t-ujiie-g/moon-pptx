// Custom-geometry writer.
//
// Inverse of `custom_geometry_parser.mbt`. Emits `<a:custGeom>` with
// `<a:avLst>` / `<a:gdLst>` / `<a:ahLst>` (preserved via extension) /
// `<a:cxnLst>` / `<a:rect>` / `<a:pathLst>`, then the path commands
// inside each `<a:path>` element.
//
// `AdjCoordinate` / `AdjAngle` serialise either as their integer
// representation or as the bare guide-name token; that matches what
// `parse_adj_coord_attr` and `parse_adj_angle_attr` accept.

///|
fn write_custom_geometry(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  cg : CustomGeometry,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "custGeom"))
  // <a:avLst> (always emit, even if empty, to match Office output).
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "avLst"))
  for adj in cg.adjust_values {
    write_gd(w, adj)
  }
  w.end_element()
  // <a:gdLst>
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "gdLst"))
  for g in cg.guides {
    write_gd(w, g)
  }
  w.end_element()
  // <a:ahLst> + foreign-namespace extensions ride via `extension`.
  for ext in cg.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  // <a:cxnLst>
  if cg.connection_sites.length() > 0 {
    w.start_element(@xml.QName::new(@oxml.drawing_ns, "cxnLst"))
    for cs in cg.connection_sites {
      write_cxn(w, ctx, cs)
    }
    w.end_element()
  }
  // <a:rect>
  match cg.rect {
    Some(r) => write_geom_rect(w, r)
    None => ()
  }
  // <a:pathLst>
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "pathLst"))
  for p in cg.paths {
    write_path(w, ctx, p)
  }
  w.end_element()
  w.end_element() // custGeom
}

///|
fn write_gd(
  w : @xml.XmlWriter,
  adj : ShapeAdjustValue,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "gd"))
  w.attribute(@xml.QName::unqualified("name"), adj.name)
  w.attribute(@xml.QName::unqualified("fmla"), adj.fmla)
  w.end_element()
}

///|
fn write_cxn(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  cs : ConnectionSite,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "cxn"))
  w.attribute(@xml.QName::unqualified("ang"), adj_angle_to_xml(cs.ang))
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "pos"))
  w.attribute(@xml.QName::unqualified("x"), adj_coord_to_xml(cs.pos.x))
  w.attribute(@xml.QName::unqualified("y"), adj_coord_to_xml(cs.pos.y))
  w.end_element()
  for ext in cs.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_geom_rect(
  w : @xml.XmlWriter,
  r : GeomRect,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "rect"))
  w.attribute(@xml.QName::unqualified("l"), adj_coord_to_xml(r.l))
  w.attribute(@xml.QName::unqualified("t"), adj_coord_to_xml(r.t))
  w.attribute(@xml.QName::unqualified("r"), adj_coord_to_xml(r.r))
  w.attribute(@xml.QName::unqualified("b"), adj_coord_to_xml(r.b))
  w.end_element()
}

///|
fn write_path(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  p : Path,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "path"))
  let @units.Emu(w_val) = p.w
  let @units.Emu(h_val) = p.h
  // Emit w/h only when non-zero (the default per spec is 0).
  if w_val != 0L {
    w.attribute(@xml.QName::unqualified("w"), w_val.to_string())
  }
  if h_val != 0L {
    w.attribute(@xml.QName::unqualified("h"), h_val.to_string())
  }
  // `fill` defaults to norm. Emit when non-default so round-trip on an
  // explicit `fill="norm"` input also re-emits it; we don't preserve
  // that distinction today and treat absent as norm on parse too.
  match p.fill {
    PathFillNorm => ()
    other => w.attribute(@xml.QName::unqualified("fill"), other.to_xml())
  }
  // `stroke` and `extrusionOk` default to true.
  if !p.stroke {
    w.attribute(@xml.QName::unqualified("stroke"), "0")
  }
  if !p.extrusion_ok {
    w.attribute(@xml.QName::unqualified("extrusionOk"), "0")
  }
  for cmd in p.commands {
    write_path_command(w, cmd)
  }
  for ext in p.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_path_command(
  w : @xml.XmlWriter,
  cmd : PathCommand,
) -> Unit raise @xml.XmlError {
  match cmd {
    MoveTo(pt) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "moveTo"))
      write_pt(w, pt)
      w.end_element()
    }
    LnTo(pt) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "lnTo"))
      write_pt(w, pt)
      w.end_element()
    }
    CubicBezTo(p1, p2, p3) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "cubicBezTo"))
      write_pt(w, p1)
      write_pt(w, p2)
      write_pt(w, p3)
      w.end_element()
    }
    QuadBezTo(p1, p2) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "quadBezTo"))
      write_pt(w, p1)
      write_pt(w, p2)
      w.end_element()
    }
    ArcTo(w_r, h_r, st, sw) => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "arcTo"))
      w.attribute(@xml.QName::unqualified("wR"), adj_coord_to_xml(w_r))
      w.attribute(@xml.QName::unqualified("hR"), adj_coord_to_xml(h_r))
      w.attribute(@xml.QName::unqualified("stAng"), adj_angle_to_xml(st))
      w.attribute(@xml.QName::unqualified("swAng"), adj_angle_to_xml(sw))
      w.end_element()
    }
    Close => {
      w.start_element(@xml.QName::new(@oxml.drawing_ns, "close"))
      w.end_element()
    }
  }
}

///|
fn write_pt(w : @xml.XmlWriter, pt : PathPoint) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.drawing_ns, "pt"))
  w.attribute(@xml.QName::unqualified("x"), adj_coord_to_xml(pt.x))
  w.attribute(@xml.QName::unqualified("y"), adj_coord_to_xml(pt.y))
  w.end_element()
}

///|
fn adj_coord_to_xml(c : AdjCoordinate) -> String {
  match c {
    Literal(@units.Emu(n)) => n.to_string()
    GuideRef(s) => s
  }
}

///|
fn adj_angle_to_xml(a : AdjAngle) -> String {
  match a {
    AdjAngle::Literal(angle) => angle.to_ooxml().to_string()
    AdjAngle::GuideRef(s) => s
  }
}
