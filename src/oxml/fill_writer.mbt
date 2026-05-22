// Fill writer — Phase 4c slice.
//
// Inverse of `parse_fill`. Each `Fill` variant emits its canonical
// wrapper element (`<a:noFill/>` / `<a:solidFill>` / `<a:gradFill>` /
// `<a:pattFill>` / `<a:blipFill>`) followed by its body. Caller must
// have already bound the drawing-ml namespace on the writer.
//
// `BlipFill.extension` carries a captured `<a:blip>` subtree (so the
// blip's modeled `r:embed` / `r:link` attributes are *already* inside
// the captured element). We don't re-emit them from `embed_id` /
// `link_id` to avoid duplicating attributes; the captured element
// round-trips verbatim. Other extension entries that aren't the blip
// (rare — spec doesn't define siblings) emit as additional blipFill
// children, schema-shaped output left to the input data.

///|
/// Emit a `Fill` onto `w`. Caller controls the surrounding context;
/// this helper does *not* open a wrapper element of its own beyond the
/// `<a:…Fill>` choice element matching the variant.
pub fn write_fill(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  f : Fill,
) -> Unit raise @xml.XmlError {
  match f {
    NoFill => {
      w.start_element(@xml.QName::new(drawing_ns, "noFill"))
      w.end_element()
    }
    SolidFill(c) => {
      w.start_element(@xml.QName::new(drawing_ns, "solidFill"))
      write_color(w, ctx, c)
      w.end_element()
    }
    GradientFill(g) => write_gradient_fill(w, ctx, g)
    PatternFill(p) => write_pattern_fill(w, ctx, p)
    BlipFillVariant(bf) => write_blip_fill(w, ctx, bf)
  }
}

///|
fn write_gradient_fill(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  g : Gradient,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "gradFill"))
  match g.rotate_with_shape {
    Some(b) =>
      w.attribute(
        @xml.QName::unqualified("rotWithShape"),
        if b {
          "1"
        } else {
          "0"
        },
      )
    None => ()
  }
  match g.flip {
    Some(f) => w.attribute(@xml.QName::unqualified("flip"), tile_flip_to_xml(f))
    None => ()
  }
  // <a:gsLst>
  w.start_element(@xml.QName::new(drawing_ns, "gsLst"))
  for s in g.stops {
    w.start_element(@xml.QName::new(drawing_ns, "gs"))
    w.attribute(
      @xml.QName::unqualified("pos"),
      s.position.to_ooxml().to_string(),
    )
    write_color(w, ctx, s.color)
    w.end_element()
  }
  w.end_element()
  // Direction child.
  match g.direction {
    Linear(angle, scaled) => {
      w.start_element(@xml.QName::new(drawing_ns, "lin"))
      w.attribute(@xml.QName::unqualified("ang"), angle.to_ooxml().to_string())
      w.attribute(
        @xml.QName::unqualified("scaled"),
        if scaled {
          "1"
        } else {
          "0"
        },
      )
      w.end_element()
    }
    PathRect | PathCircle | PathShape => {
      w.start_element(@xml.QName::new(drawing_ns, "path"))
      let path_val = match g.direction {
        PathRect => "rect"
        PathCircle => "circle"
        PathShape => "shape"
        // Unreachable — outer match handles linear separately.
        _ => "rect"
      }
      w.attribute(@xml.QName::unqualified("path"), path_val)
      w.end_element()
    }
  }
  // Extension tail (e.g. <a:tileRect>).
  for ext in g.extension {
    write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_pattern_fill(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  p : Pattern,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "pattFill"))
  if p.preset != "" {
    w.attribute(@xml.QName::unqualified("prst"), p.preset)
  }
  w.start_element(@xml.QName::new(drawing_ns, "fgClr"))
  write_color(w, ctx, p.fg)
  w.end_element()
  w.start_element(@xml.QName::new(drawing_ns, "bgClr"))
  write_color(w, ctx, p.bg)
  w.end_element()
  for ext in p.extension {
    write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_blip_fill(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  bf : BlipFill,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "blipFill"))
  // The parser pushes the entire `<a:blip>` subtree into `extension`
  // (with `r:embed` / `r:link` already on its attributes), so we just
  // emit that captured element. If no blip was captured (defensive),
  // synthesise one from the modeled embed_id / link_id fields so
  // downstream consumers still see a valid <a:blip>.
  let mut blip_emitted = false
  for ext in bf.extension {
    if ext.name.uri == drawing_ns && ext.name.local_name == "blip" {
      write_xml_element(w, ctx, ext)
      blip_emitted = true
    }
  }
  if !blip_emitted {
    w.start_element(@xml.QName::new(drawing_ns, "blip"))
    if bf.embed_id != "" {
      w.attribute(
        @xml.QName::new(office_relationships_ns, "embed"),
        bf.embed_id,
      )
    }
    if bf.link_id != "" {
      w.attribute(@xml.QName::new(office_relationships_ns, "link"), bf.link_id)
    }
    w.end_element()
  }
  // Optional crop.
  match bf.src_rect {
    Some(rect) => {
      w.start_element(@xml.QName::new(drawing_ns, "srcRect"))
      write_rect_attrs(w, rect.left, rect.top, rect.right, rect.bottom)
      w.end_element()
    }
    None => ()
  }
  // Fill mode (stretch vs tile).
  match bf.fill_mode {
    Stretch(opt_rect) => {
      w.start_element(@xml.QName::new(drawing_ns, "stretch"))
      match opt_rect {
        Some(rect) => {
          w.start_element(@xml.QName::new(drawing_ns, "fillRect"))
          write_rect_attrs(w, rect.left, rect.top, rect.right, rect.bottom)
          w.end_element()
        }
        None => ()
      }
      w.end_element()
    }
    Tile(ts) => write_tile(w, ts)
  }
  // Remaining extension siblings (anything that isn't the blip).
  for ext in bf.extension {
    if !(ext.name.uri == drawing_ns && ext.name.local_name == "blip") {
      write_xml_element(w, ctx, ext)
    }
  }
  w.end_element()
}

///|
/// Emit the `l` / `t` / `r` / `b` attributes shared by `<a:srcRect>` and
/// `<a:fillRect>`. All four are 1/1000-percent integers.
fn write_rect_attrs(
  w : @xml.XmlWriter,
  l : @units.Percentage,
  t : @units.Percentage,
  r : @units.Percentage,
  b : @units.Percentage,
) -> Unit raise @xml.XmlError {
  w.attribute(@xml.QName::unqualified("l"), l.to_ooxml().to_string())
  w.attribute(@xml.QName::unqualified("t"), t.to_ooxml().to_string())
  w.attribute(@xml.QName::unqualified("r"), r.to_ooxml().to_string())
  w.attribute(@xml.QName::unqualified("b"), b.to_ooxml().to_string())
}

///|
fn write_tile(w : @xml.XmlWriter, ts : TileSpec) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(drawing_ns, "tile"))
  match ts.tx {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("tx"), n.to_string())
    None => ()
  }
  match ts.ty {
    Some(@units.Emu(n)) =>
      w.attribute(@xml.QName::unqualified("ty"), n.to_string())
    None => ()
  }
  match ts.sx {
    Some(p) =>
      w.attribute(@xml.QName::unqualified("sx"), p.to_ooxml().to_string())
    None => ()
  }
  match ts.sy {
    Some(p) =>
      w.attribute(@xml.QName::unqualified("sy"), p.to_ooxml().to_string())
    None => ()
  }
  match ts.flip {
    Some(f) => w.attribute(@xml.QName::unqualified("flip"), tile_flip_to_xml(f))
    None => ()
  }
  match ts.alignment {
    Some(a) =>
      w.attribute(@xml.QName::unqualified("algn"), tile_alignment_to_xml(a))
    None => ()
  }
  w.end_element()
}

///|
fn tile_flip_to_xml(t : TileFlip) -> String {
  match t {
    FlipNone => "none"
    FlipX => "x"
    FlipY => "y"
    FlipXy => "xy"
  }
}

///|
fn tile_alignment_to_xml(a : TileAlignment) -> String {
  match a {
    AlignTopLeft => "tl"
    AlignTop => "t"
    AlignTopRight => "tr"
    AlignLeft => "l"
    AlignCenter => "ctr"
    AlignRight => "r"
    AlignBottomLeft => "bl"
    AlignBottom => "b"
    AlignBottomRight => "br"
  }
}
