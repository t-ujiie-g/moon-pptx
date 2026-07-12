// Tests for ADT-driven chart options.

///|
fn opt_data() -> @chart.ChartData {
  @chart.ChartData::new()
  .with_category("Q1")
  .with_category("Q2")
  .with_series("Revenue", [100.0, 200.0])
}

///|
/// First index of `needle` in `haystack`, or -1 (String has no `index_of`).
fn index_of(haystack : String, needle : String) -> Int {
  let h : Array[Char] = []
  for c in haystack {
    h.push(c)
  }
  let n : Array[Char] = []
  for c in needle {
    n.push(c)
  }
  let mut i = 0
  while i + n.length() <= h.length() {
    let mut j = 0
    while j < n.length() && h[i + j] == n[j] {
      j = j + 1
    }
    if j == n.length() {
      return i
    }
    i = i + 1
  }
  -1
}

// --- title ---

///|
test "ChartOption Title: sets a rich-text title and serialises the text" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([Title("Revenue")])
  assert_true(chart.chart.title is Some(_))
  assert_true(chart.chart.auto_title_deleted is None)
  // The text reaches the serialised XML inside <c:title>.
  let xml = @oxml.bytes_to_string(chart.serialize())
  assert_true(index_of(xml, "<c:title>") >= 0)
  assert_true(index_of(xml, "Revenue") >= 0)
  // And the whole thing round-trips structurally.
  assert_eq(@chart.Chart::parse(chart.serialize()), chart)
}

///|
test "ChartOption TitleDeleted: clears title + sets autoTitleDeleted" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    Title("X"),
    TitleDeleted,
  ])
  assert_true(chart.chart.title is None)
  assert_true(chart.chart.auto_title_deleted == Some(true))
}

// --- legend ---

///|
test "ChartOption Legend: sets the legend position" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    Legend(LegendBottom),
  ])
  match chart.chart.legend {
    Some(lg) => assert_true(lg.legend_pos == Some(LegendBottom))
    None => fail("expected a legend")
  }
  assert_eq(@chart.Chart::parse(chart.serialize()), chart)
}

///|
test "ChartOption Legend: later option wins; LegendHidden clears" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    Legend(LegendRight),
    Legend(LegendTop),
  ])
  match chart.chart.legend {
    Some(lg) => assert_true(lg.legend_pos == Some(LegendTop))
    None => fail("expected a legend")
  }
  let hidden = chart.with_options([LegendHidden])
  assert_true(hidden.chart.legend is None)
}

// --- data labels ---

///|
test "ChartOption DataLabels: sets value labels on the bar plot" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    DataLabels(DLblOutEnd),
  ])
  match chart.chart.plot_area.plots[0] {
    BarChart(b) =>
      match b.d_lbls {
        Some(d) => {
          assert_true(d.d_lbl_pos == Some(DLblOutEnd))
          assert_true(d.show_val == Some(true))
        }
        None => fail("expected d_lbls")
      }
    _ => fail("expected BarChart")
  }
  assert_eq(@chart.Chart::parse(chart.serialize()), chart)
}

///|
test "ChartOption DataLabels: applies to a pie plot too" {
  let chart = @chart.Chart::of_pie(opt_data()).with_options([
    DataLabels(DLblCenter),
  ])
  match chart.chart.plot_area.plots[0] {
    PieChart(b) => assert_true(b.d_lbls is Some(_))
    _ => fail("expected PieChart")
  }
}

///|
test "ChartOption DataLabelsHidden: clears data labels" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    DataLabels(DLblOutEnd),
    DataLabelsHidden,
  ])
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => assert_true(b.d_lbls is None)
    _ => fail("expected BarChart")
  }
}

///|
test "ChartOption DataLabels: surface charts are left untouched (no-op)" {
  let base = @chart.Chart::of_surface(opt_data())
  let labelled = base.with_options([DataLabels(DLblOutEnd)])
  // Surface has no <c:dLbls>; the option must not change anything.
  assert_eq(labelled, base)
}

// --- data table ---

///|
test "ChartOption DataTable: toggles the plot-area data table" {
  let on = @chart.Chart::of_bar(opt_data()).with_options([DataTable(true)])
  assert_true(on.chart.plot_area.data_table is Some(_))
  let off = on.with_options([DataTable(false)])
  assert_true(off.chart.plot_area.data_table is None)
  assert_eq(@chart.Chart::parse(on.serialize()), on)
}

// --- scalar chartSpace / chart toggles ---

///|
test "ChartOption scalar toggles set their fields" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    Style(7),
    RoundedCorners(false),
    PlotVisibleOnly(true),
    DisplayBlanks(Gap),
  ])
  assert_true(chart.style == Some(7))
  assert_true(chart.rounded_corners == Some(false))
  assert_true(chart.chart.plot_vis_only == Some(true))
  assert_true(chart.chart.disp_blanks_as == Some(Gap))
  assert_eq(@chart.Chart::parse(chart.serialize()), chart)
}

// --- composition + immutability ---

///|
test "with_options: applies many options and round-trips" {
  let chart = @chart.Chart::of_bar(opt_data()).with_options([
    Title("Quarterly revenue"),
    Legend(LegendBottom),
    DataLabels(DLblOutEnd),
    DataTable(true),
    Style(2),
    RoundedCorners(false),
    PlotVisibleOnly(true),
    DisplayBlanks(Zero),
  ])
  assert_true(chart.chart.title is Some(_))
  assert_true(chart.chart.legend is Some(_))
  assert_eq(@chart.Chart::parse(chart.serialize()), chart)
}

///|
test "with_options: does not mutate the original chart" {
  let base = @chart.Chart::of_bar(opt_data())
  let _ = base.with_options([Title("X"), Legend(LegendTop)])
  assert_true(base.chart.title is None)
  assert_true(base.chart.legend is None)
}

///|
test "with_options: empty list is the identity" {
  let base = @chart.Chart::of_bar(opt_data())
  assert_eq(base.with_options([]), base)
}
