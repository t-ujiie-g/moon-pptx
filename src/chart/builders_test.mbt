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
