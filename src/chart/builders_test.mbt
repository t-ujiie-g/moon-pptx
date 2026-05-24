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
      assert_true(s.x_val is Some(_))
      assert_true(s.y_val is Some(_))
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
      assert_true(s.x_val is Some(_))
      assert_true(s.y_val is Some(_))
      assert_true(s.bubble_size is Some(_))
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

// --- Chart::of_doughnut ---

///|
test "Chart::of_doughnut: holeSize lifts" {
  let chart = @chart.Chart::of_doughnut(quarterly_revenue(), hole_size=60)
  match chart.chart.plot_area.plots[0] {
    DoughnutChart(b) => {
      assert_eq(b.hole_size.unwrap(), 60)
      assert_eq(b.vary_colors.unwrap(), true)
    }
    _ => fail("expected DoughnutChart")
  }
}

///|
test "Chart::of_doughnut: round-trips" {
  let original = @chart.Chart::of_doughnut(quarterly_revenue())
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- Chart::of_of_pie ---

///|
test "Chart::of_of_pie: defaults to Pie + Auto split" {
  let chart = @chart.Chart::of_of_pie(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    OfPieChart(b) => {
      assert_eq(b.of_pie_type, Pie)
      assert_true(b.split_type is Some(Auto))
    }
    _ => fail("expected OfPieChart")
  }
}

///|
test "Chart::of_of_pie: bar variant + Percent split round-trips" {
  let original = @chart.Chart::of_of_pie(
    quarterly_revenue(),
    of_pie_type=Bar,
    split_type=Percent,
  )
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- Chart::of_bar_3d ---

///|
test "Chart::of_bar_3d: three axIds + shape default Box" {
  let chart = @chart.Chart::of_bar_3d(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    Bar3DChart(b) => {
      assert_eq(b.bar_dir, Col)
      assert_true(b.shape is Some(Box))
      assert_eq(b.ax_ids.length(), 3)
    }
    _ => fail("expected Bar3DChart")
  }
  assert_eq(chart.chart.plot_area.axes.length(), 3)
  assert_eq(chart.chart.plot_area.axes[2].local_name(), "serAx")
}

///|
test "Chart::of_bar_3d: cylinder shape + round-trip" {
  let original = @chart.Chart::of_bar_3d(quarterly_revenue(), shape=Cylinder)
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- Chart::of_line_3d ---

///|
test "Chart::of_line_3d: three axIds" {
  let chart = @chart.Chart::of_line_3d(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    Line3DChart(b) => assert_eq(b.ax_ids.length(), 3)
    _ => fail("expected Line3DChart")
  }
}

///|
test "Chart::of_line_3d: round-trips" {
  let original = @chart.Chart::of_line_3d(quarterly_revenue())
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- Chart::of_pie_3d ---

///|
test "Chart::of_pie_3d: no axes" {
  let chart = @chart.Chart::of_pie_3d(quarterly_revenue())
  assert_eq(chart.chart.plot_area.axes.length(), 0)
  match chart.chart.plot_area.plots[0] {
    Pie3DChart(b) => assert_eq(b.vary_colors.unwrap(), true)
    _ => fail("expected Pie3DChart")
  }
}

// --- Chart::of_surface ---

///|
test "Chart::of_surface: wireframe defaults false" {
  let chart = @chart.Chart::of_surface(quarterly_revenue())
  match chart.chart.plot_area.plots[0] {
    SurfaceChart(b) => assert_eq(b.wireframe.unwrap(), false)
    _ => fail("expected SurfaceChart")
  }
}

///|
test "Chart::of_surface_3d: three axIds; wireframe lifts" {
  let chart = @chart.Chart::of_surface_3d(quarterly_revenue(), wireframe=true)
  match chart.chart.plot_area.plots[0] {
    Surface3DChart(b) => {
      assert_eq(b.wireframe.unwrap(), true)
      assert_eq(b.ax_ids.length(), 3)
    }
    _ => fail("expected Surface3DChart")
  }
  assert_eq(chart.chart.plot_area.axes.length(), 3)
}

///|
test "Chart::of_surface_3d: round-trips" {
  let original = @chart.Chart::of_surface_3d(
    quarterly_revenue(),
    wireframe=true,
  )
  let bytes = original.serialize()
  let re_parsed = @chart.Chart::parse(bytes)
  assert_eq(re_parsed, original)
}

// --- Chart::of_stock ---

///|
test "Chart::of_stock: HLC variant gets 3 series" {
  let data = @chart.ChartData::new()
    .with_category("Jan")
    .with_category("Feb")
    .with_series("High", [100.0, 110.0])
    .with_series("Low", [80.0, 85.0])
    .with_series("Close", [90.0, 105.0])
  let chart = @chart.Chart::of_stock(data)
  match chart.chart.plot_area.plots[0] {
    StockChart(b) => {
      assert_eq(b.series.length(), 3)
      assert_true(b.hi_low_lines is Some(_))
    }
    _ => fail("expected StockChart")
  }
}

///|
test "Chart::of_stock: OHLC variant gets 4 series; extras truncated" {
  let data = @chart.ChartData::new()
    .with_category("Jan")
    .with_series("a", [1.0])
    .with_series("b", [2.0])
    .with_series("c", [3.0])
    .with_series("d", [4.0])
    .with_series("e", [5.0]) // excess — should be truncated to 4
  let chart = @chart.Chart::of_stock(data, kind=OHLC)
  match chart.chart.plot_area.plots[0] {
    StockChart(b) => assert_eq(b.series.length(), 4)
    _ => fail("expected StockChart")
  }
}

///|
test "Chart::of_stock: insufficient series get zero-padded" {
  let data = @chart.ChartData::new()
    .with_category("Jan")
    .with_category("Feb")
    .with_series("only-one", [1.0, 2.0])
  let chart = @chart.Chart::of_stock(data)
  match chart.chart.plot_area.plots[0] {
    StockChart(b) => assert_eq(b.series.length(), 3) // HLC default
    _ => fail("expected StockChart")
  }
}

///|
test "Chart::of_stock: HLC round-trips" {
  let data = @chart.ChartData::new()
    .with_category("Jan")
    .with_series("H", [100.0])
    .with_series("L", [80.0])
    .with_series("C", [90.0])
  let original = @chart.Chart::of_stock(data)
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
      let s0 = b.series[0]
      assert_eq(s0.idx, 0)
      assert_eq(s0.order, 0)
      let s1 = b.series[1]
      assert_eq(s1.idx, 1)
      assert_eq(s1.order, 1)
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
        assert_true(s.cat is Some(_))
        assert_true(s.val is Some(_))
        assert_true(s.tx is Some(_))
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
      // <c:val><c:numLit><c:ptCount val="3"/>…
      let val = s.val.unwrap()
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
