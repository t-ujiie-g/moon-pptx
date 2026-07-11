// Chart-insertion API.
//
// `add_chart_mut(slide_idx, chart, x, y, cx, cy)` attaches a built
// chart to a slide. The chart's bytes go in as a new
// `/ppt/charts/chartN.xml` part; a `<p:graphicFrame>` shape on the
// target slide carries the rId reference to it.
//
// Pair with the chart builders (`@chart.Chart::of_bar`, `of_line`,
// …) to produce a usable PPTX with charts from scratch:
//
//   let chart = @chart.Chart::of_bar(data)
//   prs.add_chart_mut(slide_idx=0, chart, x, y, cx, cy)
//
// Mirrors `add_picture_mut`'s plumbing:
//   1. Serialise the chart to bytes and allocate a part name.
//   2. Add the chart part with `ct_chart` content type (Override).
//   3. Append a `rt_chart` Relationship on the slide.
//   4. Construct a typed `GraphicFrame::of_chart_ref` and append.
//
// For the extended chart families (waterfall / treemap / sunburst
// / etc.), use `add_chart_ex_mut` with a `@chart_ex.ChartEx` value.

///|
/// Insert a built `Chart` as a `<p:graphicFrame>` shape on the
/// slide at `slide_idx`. The chart's serialised bytes are added as
/// a fresh `/ppt/charts/chartN.xml` part with content type
/// `application/vnd.openxmlformats-officedocument.drawingml.chart+xml`.
///
/// `embed_data` opts into an embedded `.xlsx` data workbook: the
/// chart gains a `<c:externalData>` reference to a generated
/// SpreadsheetML part mirroring the given `ChartData`, so
/// PowerPoint's "Edit Data" opens real rows instead of a blank
/// sheet (ADR-009's degraded-UX fix). The chart still renders from
/// its inline literals; pass the same `ChartData` the chart was
/// built from.
pub fn Presentation::add_chart_mut(
  self : Presentation,
  slide_idx : Int,
  chart : @chart.Chart,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
  embed_data? : @chart.ChartData,
) -> Unit raise PptxError {
  let chart_name = self.next_chart_part_name("chart")
  let to_serialize = match embed_data {
    Some(_) => {
      for ext in chart.extension {
        if ext.name.uri == @oxml.chart_ns &&
          ext.name.local_name == "externalData" {
          raise Malformed(
            "add_chart_mut: the chart already references external data; embed_data would duplicate it",
          )
        }
      }
      // The chart part's rels are created below with the workbook as
      // their only entry, so rId1 is the reference by construction.
      { ..chart, extension: [..chart.extension, external_data_element("rId1")] }
    }
    None => chart
  }
  let chart_bytes = to_serialize.serialize() catch {
    e => raise ChartFailure(e.to_string())
  }
  insert_chart_internal(
    self,
    slide_idx,
    chart_bytes,
    chart_name,
    @oxml.ct_chart,
    @opc.rt_chart,
    x,
    y,
    cx,
    cy,
    is_chart_ex=false,
  )
  match embed_data {
    Some(data) => self.attach_chart_workbook(chart_name, data)
    None => ()
  }
}

///|
/// Generate the embedded workbook for `data` and wire it to the
/// chart part: the `.xlsx` goes in under `/ppt/embeddings/`, the
/// `xlsx` Default content type is registered, and the chart's rels
/// gain the `rt_package` reference as `rId1`.
fn Presentation::attach_chart_workbook(
  self : Presentation,
  chart_name : String,
  data : @chart.ChartData,
) -> Unit raise PptxError {
  let emb_name = "/ppt/embeddings/Microsoft_Excel_Worksheet" +
    (self.max_part_index("/ppt/embeddings/Microsoft_Excel_Worksheet") + 1).to_string() +
    ".xlsx"
  let part = @opc.Part::new(
    emb_name,
    @oxml.ct_xlsx_sheet,
    chart_data_xlsx(data),
  ) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.pkg.add_part(part) catch {
    e => raise OpcFailure(e.to_string())
  }
  let ct = self.pkg.content_types().with_default("xlsx", @oxml.ct_xlsx_sheet)
  self.pkg.set_content_types(ct)
  self.pkg.regenerate_content_types_part() catch {
    e => raise OpcFailure(e.to_string())
  }
  let chart_rels = self.pkg.relationships_for(chart_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let updated = chart_rels.with_relationship({
    id: "rId1",
    rel_type: @opc.rt_package,
    target: relative_target(chart_name, emb_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  self.write_rels_for_part(chart_name, updated)
}

///|
/// Same as `add_chart_mut` but for the Microsoft 2016 extended
/// chart families (waterfall, treemap, sunburst, …). The part
/// goes in as `/ppt/charts/chartExN.xml` with content type
/// `application/vnd.ms-office.chartex+xml`, and the slide-side
/// reference uses the `cx:` namespace via
/// `GraphicFrameContent::ChartExContent`.
pub fn Presentation::add_chart_ex_mut(
  self : Presentation,
  slide_idx : Int,
  chart_ex : @chart_ex.ChartEx,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
) -> Unit raise PptxError {
  let chart_bytes = chart_ex.serialize() catch {
    e => raise ChartExFailure(e.to_string())
  }
  let chart_name = self.next_chart_part_name("chartEx")
  insert_chart_internal(
    self,
    slide_idx,
    chart_bytes,
    chart_name,
    @oxml.ct_chart_ex,
    @opc.rt_chart_ex,
    x,
    y,
    cx,
    cy,
    is_chart_ex=true,
  )
}

// --- shared plumbing -------------------------------------------------------

///|
/// Common body for chart / chartEx insertion. Adds the part, content-
/// type Override, slide relationship, and graphicFrame shape.
fn insert_chart_internal(
  prs : Presentation,
  slide_idx : Int,
  chart_bytes : FixedArray[Byte],
  chart_name : String,
  content_type : String,
  rel_type : String,
  x : @units.Emu,
  y : @units.Emu,
  cx : @units.Emu,
  cy : @units.Emu,
  is_chart_ex~ : Bool,
) -> Unit raise PptxError {
  // 1. Add chart part.
  let part = @opc.Part::new(chart_name, content_type, chart_bytes) catch {
    e => raise OpcFailure(e.to_string())
  }
  prs.pkg.add_part(part) catch {
    e => raise OpcFailure(e.to_string())
  }
  // 2. Register content-type override (chart parts use Override, not
  //    Default — they're not extension-keyed like images).
  let ct = prs.pkg.content_types().with_override(chart_name, content_type)
  prs.pkg.set_content_types(ct)
  prs.pkg.regenerate_content_types_part() catch {
    e => raise OpcFailure(e.to_string())
  }
  // 3. Resolve target slide, add the chart relationship.
  let slide_parts = prs.ordered_slide_parts()
  if slide_idx < 0 || slide_idx >= slide_parts.length() {
    raise Malformed(
      "add_chart_mut: slide_idx " +
      slide_idx.to_string() +
      " out of range (0.." +
      slide_parts.length().to_string() +
      ")",
    )
  }
  let slide_part = slide_parts[slide_idx]
  let slide_name = slide_part.name
  let slide_rels = prs.pkg.relationships_for(slide_name) catch {
    e => raise OpcFailure(e.to_string())
  }
  let new_rid = next_unused_rid(slide_rels)
  let updated_rels = slide_rels.with_relationship(@opc.Relationship::{
    id: new_rid,
    rel_type,
    target: relative_target(slide_name, chart_name),
    target_mode: Internal,
  }) catch {
    e => raise OpcFailure(e.to_string())
  }
  prs.write_rels_for_part(slide_name, updated_rels)
  // 4. Construct the GraphicFrame shape and append.
  let gf_id = next_picture_shape_id(slide_part) // shared helper from add_picture
  let gf_name = if is_chart_ex {
    "ChartEx " + gf_id.to_string()
  } else {
    "Chart " + gf_id.to_string()
  }
  let gf = if is_chart_ex {
    @slide.GraphicFrame::of_chart_ex_ref(gf_id, gf_name, x, y, cx, cy, new_rid)
  } else {
    @slide.GraphicFrame::of_chart_ref(gf_id, gf_name, x, y, cx, cy, new_rid)
  }
  let slide_obj = @slide.Slide::parse(slide_part.bytes) catch {
    e => raise SlideFailure(e.to_string())
  }
  prs.update_slide_mut(slide_idx, slide_obj.with_shape(GraphicFrame(gf)))
}

///|
/// Allocate the next chart part name. `prefix` is either `"chart"`
/// (standard) or `"chartEx"` (extended) — both flavours share the
/// `/ppt/charts/` directory and are counted together because
/// PowerPoint's numbering is sequential across both.
fn Presentation::next_chart_part_name(
  self : Presentation,
  prefix : String,
) -> String {
  // `chartN` and `chartExN` share one sequence, so take the max across both
  // prefixes (the `chart` scan ignores `chartEx…` parts since their tail
  // doesn't parse as an integer, and vice-versa).
  let chart_max = self.max_part_index("/ppt/charts/chart")
  let chart_ex_max = self.max_part_index("/ppt/charts/chartEx")
  let next = (if chart_max > chart_ex_max { chart_max } else { chart_ex_max }) +
    1
  "/ppt/charts/" + prefix + next.to_string() + ".xml"
}
