// Tests for combo charts.

///|
fn revenue() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_series("Revenue", [100.0, 200.0])
  .with_series("Cost", [60.0, 110.0])
}

///|
fn margin_pct() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_series("Margin %", [40.0, 45.0])
}

// --- shared-axis combo (default) ---

///|
test "of_combo: two plots on a shared cat/val axis pair" {
  let chart = @chart.Chart::of_combo(Bar(revenue()), Line(margin_pct()))
  let pa = chart.chart.plot_area
  assert_eq(pa.plots.length(), 2)
  assert_eq(pa.plots[0].local_name(), "barChart")
  assert_eq(pa.plots[1].local_name(), "lineChart")
  // Only the single 2-D axis pair.
  assert_eq(pa.axes.length(), 2)
  assert_eq(pa.axes[0].local_name(), "catAx")
  assert_eq(pa.axes[1].local_name(), "valAx")
  // Both plots reference the same axis ids.
  // (assert_true on `==` rather than assert_eq: Array Show is deprecated.)
  match pa.plots[0] {
    BarChart(b) => assert_true(b.ax_ids == [1, 2])
    _ => fail("expected barChart")
  }
  match pa.plots[1] {
    LineChart(l) => assert_true(l.ax_ids == [1, 2])
    _ => fail("expected lineChart")
  }
}

///|
test "of_combo: secondary series indices are offset past the primary's" {
  let chart = @chart.Chart::of_combo(Bar(revenue()), Line(margin_pct()))
  let pa = chart.chart.plot_area
  // Primary bar has 2 series → idx 0, 1.
  match pa.plots[0] {
    BarChart(b) => {
      assert_eq(b.series.length(), 2)
      assert_eq(b.series[0].idx, 0)
      assert_eq(b.series[1].idx, 1)
    }
    _ => fail("expected barChart")
  }
  // Secondary line has 1 series → idx continues at 2 (not a duplicate 0).
  match pa.plots[1] {
    LineChart(l) => {
      assert_eq(l.series.length(), 1)
      assert_eq(l.series[0].idx, 2)
      assert_eq(l.series[0].order, 2)
    }
    _ => fail("expected lineChart")
  }
}

// --- secondary-axis combo ---

///|
test "of_combo: secondary_axis adds a right value axis + hidden cat axis" {
  let chart = @chart.Chart::of_combo(
    Bar(revenue()),
    Line(margin_pct()),
    secondary_axis=true,
  )
  let pa = chart.chart.plot_area
  // Four axes: primary cat/val (1,2) + secondary val/cat (4,3).
  assert_eq(pa.axes.length(), 4)
  assert_eq(pa.axes[0].local_name(), "catAx")
  assert_eq(pa.axes[1].local_name(), "valAx")
  assert_eq(pa.axes[2].local_name(), "valAx")
  assert_eq(pa.axes[3].local_name(), "catAx")
  // Secondary value axis: id 4, drawn on the right, crossing at max.
  let sec_val = pa.axes[2].core()
  assert_eq(sec_val.ax_id, 4)
  assert_true(sec_val.ax_pos is Some(Right))
  assert_true(sec_val.crosses is Some(Max))
  assert_true(sec_val.cross_ax is Some(3))
  // Secondary category axis: id 3, deleted (not rendered).
  let sec_cat = pa.axes[3].core()
  assert_eq(sec_cat.ax_id, 3)
  assert_true(sec_cat.delete is Some(true))
  // The secondary plot binds to the secondary axis pair.
  match pa.plots[1] {
    LineChart(l) => assert_true(l.ax_ids == [3, 4])
    _ => fail("expected lineChart")
  }
}

// --- round-trip ---

///|
test "of_combo: round-trips through serialize → parse (shared axis)" {
  let original = @chart.Chart::of_combo(Bar(revenue()), Area(margin_pct()))
  let reparsed = @chart.Chart::parse(original.serialize())
  assert_eq(reparsed, original)
}

///|
test "of_combo: round-trips through serialize → parse (secondary axis)" {
  let original = @chart.Chart::of_combo(
    Bar(revenue()),
    Line(margin_pct()),
    secondary_axis=true,
  )
  let reparsed = @chart.Chart::parse(original.serialize())
  assert_eq(reparsed, original)
}
