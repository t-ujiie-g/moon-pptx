// Per-family `<c:*Chart>` body writers.
//
// One function per chart-family kind; each emits the typed
// `*ChartBody` it owns in the ECMA-376 schema's required child order.
// The family-dispatch (`write_plot`), the chartSpace and chart shells
// (`serialize_chart_xml`, `write_chart_body`, `write_plot_area`), and
// the shared `emit_val_*` helpers all live in `writer.mbt`.

///|
/// Emit `<c:barChart>` body. Element order follows ECMA-376
/// §21.2.2.16 (`CT_BarChart`).
fn write_bar_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : BarChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "barChart"))
  emit_val_string(w, "barDir", b.bar_dir.to_xml())
  match b.grouping {
    Some(g) => emit_val_string(w, "grouping", g.to_xml())
    None => ()
  }
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.gap_width {
    Some(n) => emit_val_int(w, "gapWidth", n)
    None => ()
  }
  match b.overlap {
    Some(n) => emit_val_int(w, "overlap", n)
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit `<c:lineChart>` body in ECMA-376 §21.2.2.97 schema order.
fn write_line_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : LineChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "lineChart"))
  emit_val_string(w, "grouping", b.grouping.to_xml())
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.drop_lines {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.hi_low_lines {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.up_down_bars {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.marker {
    Some(v) => emit_val_bool(w, "marker", v)
    None => ()
  }
  match b.smooth {
    Some(v) => emit_val_bool(w, "smooth", v)
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
/// Emit `<c:pieChart>` body in ECMA-376 §21.2.2.141 schema order.
fn write_pie_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : PieChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "pieChart"))
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.first_slice_ang {
    Some(n) => emit_val_int(w, "firstSliceAng", n)
    None => ()
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

// --- area / 3-D variants / doughnut / radar ---

///|
fn write_area_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : AreaChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "areaChart"))
  match b.grouping {
    Some(g) => emit_val_string(w, "grouping", g.to_xml())
    None => ()
  }
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.drop_lines {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_area_3d_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : Area3DChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "area3DChart"))
  match b.grouping {
    Some(g) => emit_val_string(w, "grouping", g.to_xml())
    None => ()
  }
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.drop_lines {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.gap_depth {
    Some(n) => emit_val_int(w, "gapDepth", n)
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_bar_3d_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : Bar3DChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "bar3DChart"))
  emit_val_string(w, "barDir", b.bar_dir.to_xml())
  match b.grouping {
    Some(g) => emit_val_string(w, "grouping", g.to_xml())
    None => ()
  }
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.gap_width {
    Some(n) => emit_val_int(w, "gapWidth", n)
    None => ()
  }
  match b.gap_depth {
    Some(n) => emit_val_int(w, "gapDepth", n)
    None => ()
  }
  match b.shape {
    Some(s) => emit_val_string(w, "shape", s.to_xml())
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_line_3d_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : Line3DChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "line3DChart"))
  emit_val_string(w, "grouping", b.grouping.to_xml())
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.drop_lines {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.gap_depth {
    Some(n) => emit_val_int(w, "gapDepth", n)
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_pie_3d_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : Pie3DChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "pie3DChart"))
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_doughnut_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : DoughnutChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "doughnutChart"))
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.first_slice_ang {
    Some(n) => emit_val_int(w, "firstSliceAng", n)
    None => ()
  }
  match b.hole_size {
    Some(n) => emit_val_int(w, "holeSize", n)
    None => ()
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_radar_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : RadarChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "radarChart"))
  emit_val_string(w, "radarStyle", b.radar_style.to_xml())
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

// --- scatter / bubble / stock / surface / ofPie ---

///|
fn write_scatter_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : ScatterChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "scatterChart"))
  emit_val_string(w, "scatterStyle", b.scatter_style.to_xml())
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_scatter_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_bubble_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : BubbleChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "bubbleChart"))
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_bubble_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.bubble_3d {
    Some(v) => emit_val_bool(w, "bubble3D", v)
    None => ()
  }
  match b.bubble_scale {
    Some(n) => emit_val_int(w, "bubbleScale", n)
    None => ()
  }
  match b.show_neg_bubbles {
    Some(v) => emit_val_bool(w, "showNegBubbles", v)
    None => ()
  }
  match b.size_represents {
    Some(s) => emit_val_string(w, "sizeRepresents", s.to_xml())
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_stock_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : StockChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "stockChart"))
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.drop_lines {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.hi_low_lines {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.up_down_bars {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_surface_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : SurfaceChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "surfaceChart"))
  match b.wireframe {
    Some(v) => emit_val_bool(w, "wireframe", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.band_fmts {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_surface_3d_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : Surface3DChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "surface3DChart"))
  match b.wireframe {
    Some(v) => emit_val_bool(w, "wireframe", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.band_fmts {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  for id in b.ax_ids {
    emit_val_int(w, "axId", id)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}

///|
fn write_of_pie_chart(
  w : @xml.XmlWriter,
  ctx : @oxml.WriteCtx,
  b : OfPieChartBody,
) -> Unit raise @xml.XmlError {
  w.start_element(@xml.QName::new(@oxml.chart_ns, "ofPieChart"))
  emit_val_string(w, "ofPieType", b.of_pie_type.to_xml())
  match b.vary_colors {
    Some(v) => emit_val_bool(w, "varyColors", v)
    None => ()
  }
  for s in b.series {
    write_chart_series_core(w, ctx, s)
  }
  match b.d_lbls {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.gap_width {
    Some(n) => emit_val_int(w, "gapWidth", n)
    None => ()
  }
  match b.split_type {
    Some(s) => emit_val_string(w, "splitType", s.to_xml())
    None => ()
  }
  match b.split_pos {
    Some(s) => emit_val_string(w, "splitPos", s)
    None => ()
  }
  match b.cust_split {
    Some(e) => @oxml.write_xml_element(w, ctx, e)
    None => ()
  }
  match b.second_pie_size {
    Some(n) => emit_val_int(w, "secondPieSize", n)
    None => ()
  }
  for sl in b.ser_lines {
    @oxml.write_xml_element(w, ctx, sl)
  }
  for ext in b.extension {
    @oxml.write_xml_element(w, ctx, ext)
  }
  w.end_element()
}
