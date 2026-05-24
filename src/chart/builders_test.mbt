// Chart-from-scratch builder tests.

///|
fn quarterly_revenue() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_category("Q3")
  .with_category("Q4")
  .with_series("Revenue", [100.0, 200.0, 300.0, 250.0])
  .with_series("Cost", [60.0, 110.0, 180.0, 140.0])
}

// --- ChartData immutable builder ---

///|
test "ChartData::new is empty" {
  let d = @chart.ChartData::new()
  assert_eq(d.categories.length(), 0)
  assert_eq(d.series.length(), 0)
}

///|
test "ChartData::with_category does not mutate the original" {
  let a = @chart.ChartData::new()
  let b = a.with_category("Q1")
  assert_eq(a.categories.length(), 0)
  assert_eq(b.categories.length(), 1)
}

///|
test "ChartData::with_series does not mutate the original" {
  let a = @chart.ChartData::new().with_category("Q1")
  let b = a.with_series("Revenue", [100.0])
  assert_eq(a.series.length(), 0)
  assert_eq(b.series.length(), 1)
  assert_eq(b.series[0].label, "Revenue")
}

// --- Chart::of_bar ---

///|
test "Chart::of_bar: produces a Col bar chart by default" {
  let chart = @chart.Chart::of_bar(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      assert_eq(b.bar_dir, Col)
      assert_true(b.grouping is Some(Clustered))
      assert_eq(b.series.length(), 2)
      assert_eq(b.ax_ids.length(), 2)
    }
    _ => fail("expected BarChart plot")
  }
  // catAx + valAx pair
  assert_eq(chart.chart.plot_area.axes.length(), 2)
  assert_eq(chart.chart.plot_area.axes[0].local_name(), "catAx")
  assert_eq(chart.chart.plot_area.axes[1].local_name(), "valAx")
}

///|
test "Chart::of_bar: horizontal Bar variant" {
  let chart = @chart.Chart::of_bar(
    @chart.ChartData::new().with_category("a").with_series("s", [1.0]),
    bar_dir=Bar,
    grouping=Stacked,
  )
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      assert_eq(b.bar_dir, Bar)
      assert_true(b.grouping is Some(Stacked))
    }
    _ => fail("expected BarChart plot")
  }
}

///|
test "Chart::of_bar: round-trips through serialize → parse" {
  let original = @chart.Chart::of_bar(quarterly_revenue())
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- Chart::of_line ---

///|
test "Chart::of_line: standard grouping by default" {
  let chart = @chart.Chart::of_line(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    LineChart(b) => {
      assert_eq(b.grouping, Standard)
      assert_eq(b.series.length(), 2)
      assert_eq(b.ax_ids.length(), 2)
    }
    _ => fail("expected LineChart plot")
  }
}

///|
test "Chart::of_line: round-trips through serialize → parse" {
  let original = @chart.Chart::of_line(quarterly_revenue(), grouping=Stacked)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- Chart::of_pie ---

///|
test "Chart::of_pie: no axes, vary_colors defaults to true" {
  let chart = @chart.Chart::of_pie(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    PieChart(b) => {
      assert_eq(b.vary_colors.unwrap(), true)
      assert_eq(b.series.length(), 2)
    }
    _ => fail("expected PieChart plot")
  }
  assert_eq(chart.chart.plot_area.axes.length(), 0)
}

///|
test "Chart::of_pie: round-trips through serialize → parse" {
  let original = @chart.Chart::of_pie(quarterly_revenue())
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- Chart::of_area ---

///|
test "Chart::of_area: standard grouping by default" {
  let chart = @chart.Chart::of_area(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    AreaChart(b) => {
      assert_true(b.grouping is Some(Standard))
      assert_eq(b.series.length(), 2)
      assert_eq(b.ax_ids.length(), 2)
    }
    _ => fail("expected AreaChart plot")
  }
}

///|
test "Chart::of_area: round-trips" {
  let original = @chart.Chart::of_area(
    quarterly_revenue(),
    grouping=PercentStacked,
  )
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- Chart::of_radar ---

///|
test "Chart::of_radar: marker style by default" {
  let chart = @chart.Chart::of_radar(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    RadarChart(b) => {
      assert_eq(b.radar_style, Marker)
      assert_eq(b.series.length(), 2)
    }
    _ => fail("expected RadarChart plot")
  }
}

///|
test "Chart::of_radar: filled variant round-trips" {
  let original = @chart.Chart::of_radar(quarterly_revenue(), radar_style=Filled)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- Chart::of_scatter ---

///|
test "Chart::of_scatter: two value axes" {
  let data = @chart.ScatterData::new()
    .with_series("s1", [1.0, 2.0, 3.0], [10.0, 20.0, 30.0])
    .with_series("s2", [1.5, 2.5, 3.5], [12.0, 24.0, 36.0])
  let chart = @chart.Chart::of_scatter(data)
  match chart.chart.plot_area.plots[0] {
    ScatterChart(b) => {
      assert_eq(b.scatter_style, LineMarker)
      assert_eq(b.series.length(), 2)
    }
    _ => fail("expected ScatterChart")
  }
  assert_eq(chart.chart.plot_area.axes.length(), 2)
  // Both axes for scatter are valAx (not catAx).
  assert_eq(chart.chart.plot_area.axes[0].local_name(), "valAx")
  assert_eq(chart.chart.plot_area.axes[1].local_name(), "valAx")
}

///|
test "Chart::of_scatter: explicit style + round-trip" {
  let data = @chart.ScatterData::new().with_series("s1", [0.0], [0.0])
  let original = @chart.Chart::of_scatter(data, scatter_style=Smooth)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

///|
test "Chart::of_scatter: series carry xVal + yVal (not cat+val)" {
  let data = @chart.ScatterData::new().with_series("s", [1.0, 2.0], [10.0, 20.0])
  let chart = @chart.Chart::of_scatter(data)
  match chart.chart.plot_area.plots[0] {
    ScatterChart(b) => {
      let s = b.series[0]
      assert_true(has_child(s, "xVal"))
      assert_true(has_child(s, "yVal"))
      assert_false(has_child(s, "cat"))
      assert_false(has_child(s, "val"))
    }
    _ => fail("expected ScatterChart")
  }
}

// --- Chart::of_bubble ---

///|
test "Chart::of_bubble: triples lift correctly" {
  let data = @chart.BubbleData::new().with_series(
    "growth",
    [1.0, 2.0, 3.0],
    [100.0, 200.0, 150.0],
    [10.0, 20.0, 30.0],
  )
  let chart = @chart.Chart::of_bubble(data)
  match chart.chart.plot_area.plots[0] {
    BubbleChart(b) => assert_eq(b.series.length(), 1)
    _ => fail("expected BubbleChart")
  }
}

///|
test "Chart::of_bubble: series carry xVal + yVal + bubbleSize" {
  let data = @chart.BubbleData::new().with_series("s", [1.0], [2.0], [3.0])
  let chart = @chart.Chart::of_bubble(data)
  match chart.chart.plot_area.plots[0] {
    BubbleChart(b) => {
      let s = b.series[0]
      assert_true(has_child(s, "xVal"))
      assert_true(has_child(s, "yVal"))
      assert_true(has_child(s, "bubbleSize"))
    }
    _ => fail("expected BubbleChart")
  }
}

///|
test "Chart::of_bubble: round-trips" {
  let data = @chart.BubbleData::new().with_series(
    "s",
    [1.0, 2.0],
    [10.0, 20.0],
    [5.0, 8.0],
  )
  let original = @chart.Chart::of_bubble(data)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- series synthesis ---

///|
test "synthesized series: idx + order assigned sequentially" {
  let chart = @chart.Chart::of_bar(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      // First series carries <c:idx val="0"/> <c:order val="0"/>.
      let s0 = b.series[0]
      let idx_val = find_val(s0, "idx")
      let order_val = find_val(s0, "order")
      assert_eq(idx_val, "0")
      assert_eq(order_val, "0")
      // Second series → idx=1, order=1.
      let s1 = b.series[1]
      assert_eq(find_val(s1, "idx"), "1")
      assert_eq(find_val(s1, "order"), "1")
    }
    _ => fail("expected BarChart")
  }
}

///|
test "synthesized series: every series carries cat + val children" {
  let chart = @chart.Chart::of_bar(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    BarChart(b) =>
      for s in b.series {
        assert_true(has_child(s, "cat"))
        assert_true(has_child(s, "val"))
        assert_true(has_child(s, "tx"))
      }
    _ => fail("expected BarChart")
  }
}

///|
test "synthesized series: shorter values array gets zero-padded" {
  let data = @chart.ChartData::new()
    .with_category("a")
    .with_category("b")
    .with_category("c")
    // Only one value for three categories — emitter pads to ptCount=3.
    .with_series("partial", [42.0])
  let chart = @chart.Chart::of_bar(data)
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => {
      let s = b.series[0]
      // Find <c:val><c:numLit><c:ptCount val="3"/>…
      let val = find_child(s, "val")
      let num_lit = find_child(val, "numLit")
      let pt_count = find_val(num_lit, "ptCount")
      assert_eq(pt_count, "3")
    }
    _ => fail("expected BarChart")
  }
}

// --- helpers ---

///|
fn find_val(el : @xml.XmlElement, local_name : String) -> String {
  for node in el.children {
    match node {
      Element(c) =>
        if c.name.local_name == local_name {
          for kv in c.attributes {
            if kv.0.local_name == "val" {
              return kv.1
            }
          }
        }
      _ => ()
    }
  }
  ""
}

///|
fn find_child(
  el : @xml.XmlElement,
  local_name : String,
) -> @xml.XmlElement raise {
  for node in el.children {
    match node {
      Element(c) => if c.name.local_name == local_name { return c }
      _ => ()
    }
  }
  fail("child <" + local_name + "> not found")
}

///|
fn has_child(el : @xml.XmlElement, local_name : String) -> Bool {
  for node in el.children {
    match node {
      Element(c) => if c.name.local_name == local_name { return true }
      _ => ()
    }
  }
  false
}
