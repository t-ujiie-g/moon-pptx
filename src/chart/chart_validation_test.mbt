// Tests for chart-data validation (roadmap v0.4 D7).

// --- ChartData ---

///|
test "ChartData::validate: consistent data passes and returns self" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [100.0, 200.0])
    .with_series("Cost", [60.0, 110.0])
  let validated = data.validate()
  assert_true(validated == data)
  assert_eq(data.is_consistent(), true)
}

///|
test "ChartData::validate: too few values raises Malformed" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_category("Q3")
    .with_series("Revenue", [100.0, 200.0])
  assert_eq(data.is_consistent(), false)
  try data.validate() |> ignore catch {
    @chart.ChartError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected validate to raise")
  }
}

///|
test "ChartData::validate: too many values raises Malformed" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_series("Revenue", [100.0, 200.0, 300.0])
  assert_eq(data.is_consistent(), false)
  try data.validate() |> ignore catch {
    @chart.ChartError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected validate to raise")
  }
}

///|
test "ChartData::validate: composes into a chart builder" {
  let data = @chart.ChartData::new()
    .with_category("Q1")
    .with_category("Q2")
    .with_series("Revenue", [100.0, 200.0])
  // The validated value feeds straight into of_bar.
  let chart = @chart.Chart::of_bar(data.validate())
  match chart.chart.plot_area.plots[0] {
    BarChart(b) => assert_eq(b.series.length(), 1)
    _ => fail("expected BarChart")
  }
}

///|
test "ChartData::validate: empty data (no categories, no series) is consistent" {
  let data = @chart.ChartData::new()
  assert_eq(data.is_consistent(), true)
  let _ = data.validate()
}

// --- ScatterData ---

///|
test "ScatterData::validate: matching X/Y passes, mismatch raises" {
  let ok = @chart.ScatterData::new().with_series("s", [1.0, 2.0, 3.0], [
    10.0, 20.0, 30.0,
  ])
  assert_eq(ok.is_consistent(), true)
  assert_true(ok.validate() == ok)
  let bad = @chart.ScatterData::new().with_series("s", [1.0, 2.0, 3.0], [
    10.0, 20.0,
  ])
  assert_eq(bad.is_consistent(), false)
  try bad.validate() |> ignore catch {
    @chart.ChartError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected validate to raise")
  }
}

// --- BubbleData ---

///|
test "BubbleData::validate: matching X/Y/size passes, mismatch raises" {
  let ok = @chart.BubbleData::new().with_series("s", [1.0, 2.0], [10.0, 20.0], [
    3.0, 4.0,
  ])
  assert_eq(ok.is_consistent(), true)
  assert_true(ok.validate() == ok)
  let bad = @chart.BubbleData::new().with_series(
    "s",
    [1.0, 2.0],
    [10.0, 20.0],
    [3.0],
  )
  assert_eq(bad.is_consistent(), false)
  try bad.validate() |> ignore catch {
    @chart.ChartError::Malformed(_) => ()
    _ => fail("expected Malformed")
  } noraise {
    _ => fail("expected validate to raise")
  }
}
