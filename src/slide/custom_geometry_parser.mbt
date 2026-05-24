// Custom-geometry XML reader.
//
// Called from `parse_sp_pr` when it sees a `<a:custGeom>` child. The
// StartElement has already been consumed by the caller; we read events
// through the matching EndElement and return a typed `CustomGeometry`.
//
// All sub-parsers below follow the same contract as the shape-tree
// helpers in `parser.mbt`: they're entered after the StartElement of
// their owning element is consumed, and they consume events through
// (and including) the matching EndElement.
//
// `ST_AdjCoordinate` / `ST_AdjAngle` disambiguation: the OOXML spec
// declares each as the union of a numeric type and `ST_GeomGuideName`.
// A guide name is an XSD `xsd:token` matching `[a-zA-Z_][a-zA-Z0-9_]*`,
// so the leading character of a valid name is never a digit or a `-`
// sign. We use that: attempt integer parsing first, and if it fails
// treat the value as a guide reference. This matches every real-world
// custGeom we've examined and the python-pptx behaviour for the same
// attribute type.

///|
/// Parse `<a:custGeom>` (StartElement already consumed). Reads through
/// the matching EndElement and returns the typed body.
fn parse_custom_geometry(r : @xml.XmlReader) -> CustomGeometry raise SlideError {
  let adjust_values : Array[ShapeAdjustValue] = []
  let guides : Array[ShapeAdjustValue] = []
  let connection_sites : Array[ConnectionSite] = []
  let mut rect : GeomRect? = None
  let paths : Array[Path] = []
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri != @oxml.drawing_ns {
          extension.push(collect_subtree_unknown(r, child, attrs))
        } else {
          match child.local_name {
            "avLst" => parse_av_lst(r, adjust_values, extension)
            "gdLst" => parse_av_lst(r, guides, extension)
            "cxnLst" => parse_cxn_lst(r, connection_sites, extension)
            "rect" => {
              rect = Some(parse_geom_rect(attrs))
              skip_subtree(r) // <a:rect> is a leaf
            }
            "pathLst" => parse_path_lst(r, paths, extension)
            // <a:ahLst> (adjust handles) and any future siblings — keep
            // verbatim per ADR-004.
            _ => extension.push(collect_subtree_unknown(r, child, attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { adjust_values, guides, connection_sites, rect, paths, extension }
}

///|
fn parse_cxn_lst(
  r : @xml.XmlReader,
  out : Array[ConnectionSite],
  parent_extension : Array[@xml.XmlElement],
) -> Unit raise SlideError {
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri == @oxml.drawing_ns && child.local_name == "cxn" {
          out.push(parse_cxn(r, attrs))
        } else {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
}

///|
fn parse_cxn(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> ConnectionSite raise SlideError {
  let ang = parse_adj_angle_attr(attrs, "ang")
  let mut pos : PathPoint? = None
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri == @oxml.drawing_ns && child.local_name == "pos" {
          pos = Some(parse_pt_attrs(child_attrs))
          skip_subtree(r) // <a:pos> is a leaf
        } else {
          extension.push(collect_subtree_unknown(r, child, child_attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
  let p = match pos {
    Some(p) => p
    None => raise Malformed("<a:cxn> is missing required <a:pos>")
  }
  { ang, pos: p, extension }
}

///|
fn parse_geom_rect(
  attrs : Array[(@xml.QName, String)],
) -> GeomRect raise SlideError {
  {
    l: parse_adj_coord_attr(attrs, "l"),
    t: parse_adj_coord_attr(attrs, "t"),
    r: parse_adj_coord_attr(attrs, "r"),
    b: parse_adj_coord_attr(attrs, "b"),
  }
}

///|
fn parse_path_lst(
  r : @xml.XmlReader,
  out : Array[Path],
  parent_extension : Array[@xml.XmlElement],
) -> Unit raise SlideError {
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) =>
        if child.uri == @oxml.drawing_ns && child.local_name == "path" {
          out.push(parse_path(r, attrs))
        } else {
          parent_extension.push(collect_subtree_unknown(r, child, attrs))
        }
      EndElement(_) => break
      _ => ()
    }
  }
}

///|
fn parse_path(
  r : @xml.XmlReader,
  attrs : Array[(@xml.QName, String)],
) -> Path raise SlideError {
  let w = match @oxml.emu_attr_opt(attrs, "w") {
    Some(e) => e
    None => @units.Emu(0L)
  }
  let h = match @oxml.emu_attr_opt(attrs, "h") {
    Some(e) => e
    None => @units.Emu(0L)
  }
  let fill = match @oxml.optional_attr(attrs, "fill") {
    Some(v) => PathFillMode::from_xml(v)
    None => PathFillNorm
  }
  // `stroke` and `extrusionOk` default to `true` per the spec; only
  // an explicit "false" / "0" turns them off.
  let stroke = match @oxml.bool_attr_opt(attrs, "stroke") {
    Some(b) => b
    None => true
  }
  let extrusion_ok = match @oxml.bool_attr_opt(attrs, "extrusionOk") {
    Some(b) => b
    None => true
  }
  let commands : Array[PathCommand] = []
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.drawing_ns {
          extension.push(collect_subtree_unknown(r, child, child_attrs))
        } else {
          match child.local_name {
            "moveTo" => commands.push(MoveTo(parse_single_pt(r)))
            "lnTo" => commands.push(LnTo(parse_single_pt(r)))
            "cubicBezTo" => {
              let (p1, p2, p3) = parse_three_pts(r)
              commands.push(CubicBezTo(p1, p2, p3))
            }
            "quadBezTo" => {
              let (p1, p2) = parse_two_pts(r)
              commands.push(QuadBezTo(p1, p2))
            }
            "arcTo" => {
              commands.push(parse_arc_to(child_attrs))
              skip_subtree(r) // <a:arcTo> is a leaf
            }
            "close" => {
              commands.push(Close)
              skip_subtree(r) // <a:close> is a leaf
            }
            _ => extension.push(collect_subtree_unknown(r, child, child_attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { w, h, fill, stroke, extrusion_ok, commands, extension }
}

///|
/// Parse a path command body containing exactly one `<a:pt>` child.
/// Used for `<a:moveTo>` / `<a:lnTo>`.
fn parse_single_pt(r : @xml.XmlReader) -> PathPoint raise SlideError {
  let mut found : PathPoint? = None
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.drawing_ns && child.local_name == "pt" {
          found = Some(parse_pt_attrs(attrs))
        }
        skip_subtree(r) // `<a:pt>` is always a leaf
      }
      EndElement(_) => break
      _ => ()
    }
  }
  match found {
    Some(p) => p
    None => raise Malformed("expected <a:pt> inside path command body")
  }
}

///|
/// Parse a path command body containing exactly two `<a:pt>` children in
/// source order. Used for `<a:quadBezTo>` (control + end).
fn parse_two_pts(r : @xml.XmlReader) -> (PathPoint, PathPoint) raise SlideError {
  let pts : Array[PathPoint] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.drawing_ns && child.local_name == "pt" {
          pts.push(parse_pt_attrs(attrs))
        }
        skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
  if pts.length() != 2 {
    raise Malformed(
      "expected 2 <a:pt> children, got " + pts.length().to_string(),
    )
  }
  (pts[0], pts[1])
}

///|
/// Parse a path command body containing exactly three `<a:pt>` children
/// in source order. Used for `<a:cubicBezTo>` (two controls + end).
fn parse_three_pts(
  r : @xml.XmlReader,
) -> (PathPoint, PathPoint, PathPoint) raise SlideError {
  let pts : Array[PathPoint] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.drawing_ns && child.local_name == "pt" {
          pts.push(parse_pt_attrs(attrs))
        }
        skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
  if pts.length() != 3 {
    raise Malformed(
      "expected 3 <a:pt> children, got " + pts.length().to_string(),
    )
  }
  (pts[0], pts[1], pts[2])
}

///|
fn parse_arc_to(
  attrs : Array[(@xml.QName, String)],
) -> PathCommand raise SlideError {
  let w_r = parse_adj_coord_attr(attrs, "wR")
  let h_r = parse_adj_coord_attr(attrs, "hR")
  let st_ang = parse_adj_angle_attr(attrs, "stAng")
  let sw_ang = parse_adj_angle_attr(attrs, "swAng")
  ArcTo(w_r, h_r, st_ang, sw_ang)
}

///|
/// Parse an `<a:pt x="…" y="…"/>` attribute pair into a `PathPoint`.
fn parse_pt_attrs(
  attrs : Array[(@xml.QName, String)],
) -> PathPoint raise SlideError {
  { x: parse_adj_coord_attr(attrs, "x"), y: parse_adj_coord_attr(attrs, "y") }
}

///|
/// Look up a required `ST_AdjCoordinate` attribute. Integer values
/// become `Literal(Emu)`; non-numeric tokens become `GuideRef(name)`.
fn parse_adj_coord_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> AdjCoordinate raise SlideError {
  let raw = require_attr(attrs, name)
  match @oxml.parse_signed_int64(raw) {
    Some(n) => Literal(@units.Emu(n))
    None => GuideRef(raw)
  }
}

///|
/// Look up a required `ST_AdjAngle` attribute. Integers become
/// `Literal(Angle)`; non-numeric tokens become `GuideRef`.
fn parse_adj_angle_attr(
  attrs : Array[(@xml.QName, String)],
  name : String,
) -> AdjAngle raise SlideError {
  let raw = require_attr(attrs, name)
  match @oxml.parse_signed_int(raw) {
    Some(n) => AdjAngle::Literal(@units.Angle::from_ooxml(n))
    None => AdjAngle::GuideRef(raw)
  }
}
