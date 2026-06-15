// Chart-data validation (roadmap v0.4 D7).
//
// The `with_series` builders are deliberately lenient — a series whose value
// count differs from the category count is zero-padded (or truncated) at emit
// time, so a length mismatch never produces invalid XML, it just silently
// misaligns the data. `validate()` is the opt-in strict gate that turns that
// silent misalignment into an explicit `ChartError::Malformed`, naming the
// offending series and the mismatched counts.
//
// Each data type has one "first offending series" predicate that both
// `validate` (raises) and `is_consistent` (returns Bool) consume, so the two
// can never disagree on what "consistent" means.
//
// Deviation from the roadmap sketch: validation is a separate `validate()`
// method rather than baked into `with_series`. Making `with_series` raise
// would (1) force categories to be added strictly before series and (2) break
// the infallible fluent chains used throughout the cookbook
// (`ChartData::new().with_category(...).with_series(...)`). A standalone gate
// is order-independent and non-breaking: `Chart::of_bar(data.validate())`
// validates exactly at the build boundary, while lenient building stays the
// default. The phantom-type-parameter lift to *compile-time* validation
// remains deferred until MoonBit's const-generics-like features stabilise
// (per the roadmap).

// --- ChartData ---

///|
/// The first series whose value count differs from the category count, or
/// `None` when every series is aligned. Single source of truth for both
/// `validate` and `is_consistent`.
fn ChartData::first_misaligned_series(self : ChartData) -> ChartSeries? {
  let n = self.categories.length()
  for s in self.series {
    if s.values.length() != n {
      return Some(s)
    }
  }
  None
}

///|
/// Validate that every series carries exactly one value per category, then
/// return `self` unchanged so it composes in a builder chain
/// (`Chart::of_bar(data.validate())`). Raises `ChartError::Malformed` naming
/// the first series whose value count differs from the category count.
pub fn ChartData::validate(self : ChartData) -> ChartData raise ChartError {
  match self.first_misaligned_series() {
    Some(s) =>
      raise Malformed(
        "series " +
        escape_label(s.label) +
        " has " +
        s.values.length().to_string() +
        " values but the chart has " +
        self.categories.length().to_string() +
        " categories",
      )
    None => self
  }
}

///|
/// Non-raising counterpart to `validate`: `true` when every series has one
/// value per category.
pub fn ChartData::is_consistent(self : ChartData) -> Bool {
  self.first_misaligned_series() is None
}

// --- ScatterData ---

///|
/// The first scatter series whose X and Y lengths differ, or `None`.
fn ScatterData::first_misaligned_series(self : ScatterData) -> ScatterSeries? {
  for s in self.series {
    if s.x.length() != s.y.length() {
      return Some(s)
    }
  }
  None
}

///|
/// Validate that each scatter series has matching X / Y lengths, then return
/// `self`. Raises `ChartError::Malformed` on the first mismatch.
pub fn ScatterData::validate(
  self : ScatterData,
) -> ScatterData raise ChartError {
  match self.first_misaligned_series() {
    Some(s) =>
      raise Malformed(
        "scatter series " +
        escape_label(s.label) +
        " has " +
        s.x.length().to_string() +
        " X values but " +
        s.y.length().to_string() +
        " Y values",
      )
    None => self
  }
}

///|
/// Non-raising counterpart to `ScatterData::validate`.
pub fn ScatterData::is_consistent(self : ScatterData) -> Bool {
  self.first_misaligned_series() is None
}

// --- BubbleData ---

///|
/// The first bubble series whose X / Y / size lengths are not all equal, or
/// `None`.
fn BubbleData::first_misaligned_series(self : BubbleData) -> BubbleSeries? {
  for s in self.series {
    if s.x.length() != s.y.length() || s.y.length() != s.size.length() {
      return Some(s)
    }
  }
  None
}

///|
/// Validate that each bubble series has matching X / Y / size lengths, then
/// return `self`. Raises `ChartError::Malformed` on the first mismatch.
pub fn BubbleData::validate(self : BubbleData) -> BubbleData raise ChartError {
  match self.first_misaligned_series() {
    Some(s) =>
      raise Malformed(
        "bubble series " +
        escape_label(s.label) +
        " has mismatched lengths: " +
        s.x.length().to_string() +
        " X, " +
        s.y.length().to_string() +
        " Y, " +
        s.size.length().to_string() +
        " size",
      )
    None => self
  }
}

///|
/// Non-raising counterpart to `BubbleData::validate`.
pub fn BubbleData::is_consistent(self : BubbleData) -> Bool {
  self.first_misaligned_series() is None
}

// --- Chart (plot-type-aware data-label position) — roadmap v0.5 D8 ---
//
// `Chart::with_options(DataLabels(pos))` (M2) and the lower-level `DLbls`
// builders faithfully emit *any* `ST_DLblPos` the caller supplies, matching the
// lenient philosophy of `with_series`. But `<c:dLblPos>` is constrained per
// plot family (ECMA-376 + MS-OI29500): `outEnd` is valid on a `barChart` /
// `pieChart` yet **invalid on a `lineChart` / `scatterChart` / `radarChart`**,
// and several families (`area*`, `*3D`, `doughnut`, `stock`, `bubble`,
// `surface*`) permit no explicit position at all. PowerPoint refuses to load a
// file with an out-of-range position and runs its repair pass.
//
// `Chart::validate` is the opt-in gate (pairing with D7's `ChartData::validate`)
// that catches the mismatch before it reaches PowerPoint, naming the offending
// plot family and position. The plot-vs-position table lives in one place
// (`valid_d_lbl_positions`), exhaustive over `Plot` — adding a new plot family
// without classifying it is a compile error.
//
// The *compile-time* lift sketched in the roadmap (per-family `DataLabelPosition`
// so an invalid combo is a type error) is deferred; this slice ships the runtime
// gate that the roadmap says ships regardless.

///|
/// The data-label positions ECMA-376 + MS-OI29500 permit for a plot family.
/// An empty array means the family supports **no** explicit `<c:dLblPos>` —
/// PowerPoint will not load a file that carries one. Bar grouping splits the
/// set: stacked / 100%-stacked drop `outEnd`. Radar is treated leniently (the
/// marker set) rather than distinguishing the filled variant, which forbids any
/// position — a documented simplification to avoid false positives.
///
/// Exhaustive over `Plot`: a newly-added plot family that is not classified
/// here is a compile error.
fn valid_d_lbl_positions(plot : Plot) -> Array[DLblPos] {
  // line / scatter / radar share the "marker" position set.
  let marker = [DLblCenter, DLblLeft, DLblRight, DLblTop, DLblBottom]
  // pie / pie-of-pie / bar-of-pie.
  let pie = [DLblBestFit, DLblCenter, DLblInEnd, DLblOutEnd]
  match plot {
    BarChart(b) =>
      match b.grouping {
        Some(Stacked) | Some(PercentStacked) =>
          [DLblCenter, DLblInBase, DLblInEnd]
        _ => [DLblCenter, DLblInBase, DLblInEnd, DLblOutEnd]
      }
    LineChart(_) | ScatterChart(_) | RadarChart(_) => marker
    PieChart(_) | OfPieChart(_) => pie
    // MS-OI29500: these families permit no <c:dLblPos> at all.
    AreaChart(_)
    | Area3DChart(_)
    | Bar3DChart(_)
    | Line3DChart(_)
    | Pie3DChart(_)
    | DoughnutChart(_)
    | StockChart(_)
    | BubbleChart(_)
    | SurfaceChart(_)
    | Surface3DChart(_) => []
  }
}

///|
/// The typed `<c:dLbls>` of a plot, or `None` when the family has no data-label
/// child (the two surface families). Exhaustive over `Plot`.
fn plot_d_lbls(plot : Plot) -> DLbls? {
  match plot {
    AreaChart(b) => b.d_lbls
    Area3DChart(b) => b.d_lbls
    LineChart(b) => b.d_lbls
    Line3DChart(b) => b.d_lbls
    StockChart(b) => b.d_lbls
    RadarChart(b) => b.d_lbls
    ScatterChart(b) => b.d_lbls
    PieChart(b) => b.d_lbls
    Pie3DChart(b) => b.d_lbls
    DoughnutChart(b) => b.d_lbls
    BarChart(b) => b.d_lbls
    Bar3DChart(b) => b.d_lbls
    OfPieChart(b) => b.d_lbls
    BubbleChart(b) => b.d_lbls
    // CT_SurfaceChart / CT_Surface3DChart have no <c:dLbls> child.
    SurfaceChart(_) | Surface3DChart(_) => None
  }
}

///|
/// The first `(plot local-name, offending position)` whose data-label position
/// is invalid for its plot family, or `None` when every position is allowed.
/// Walks both the plot-level `<c:dLblPos>` and each per-point `<c:dLbl>`
/// override. Single source of truth for both `validate` and `is_consistent`.
fn Chart::first_invalid_d_lbl_pos(self : Chart) -> (String, DLblPos)? {
  for plot in self.chart.plot_area.plots {
    guard plot_d_lbls(plot) is Some(dlbls) else { continue }
    let valid = valid_d_lbl_positions(plot)
    let name = plot.local_name()
    // plot-level <c:dLblPos>
    if dlbls.d_lbl_pos is Some(pos) && !valid.contains(pos) {
      return Some((name, pos))
    }
    // per-point <c:dLbl><c:dLblPos> overrides
    for d in dlbls.d_lbl {
      if d.d_lbl_pos is Some(pos) && !valid.contains(pos) {
        return Some((name, pos))
      }
    }
  }
  None
}

///|
/// Validate that every data-label position in the chart is permitted for its
/// plot family (ECMA-376 + MS-OI29500), then return `self` so it composes in a
/// builder chain. Raises `ChartError::Malformed` naming the offending plot
/// family and position on the first mismatch — catching, before PowerPoint's
/// repair pass, combinations like `outEnd` on a line chart.
///
/// ```
/// let chart = Chart::of_bar(data)
///   .with_options([DataLabels(DLblOutEnd)])
///   .validate()
/// ```
pub fn Chart::validate(self : Chart) -> Chart raise ChartError {
  match self.first_invalid_d_lbl_pos() {
    Some((name, pos)) =>
      raise Malformed(
        "data-label position " +
        escape_label(pos.to_xml()) +
        " is not valid for the " +
        name +
        " plot",
      )
    None => self
  }
}

///|
/// Non-raising counterpart to `Chart::validate`: `true` when every data-label
/// position is permitted for its plot family.
pub fn Chart::is_consistent(self : Chart) -> Bool {
  self.first_invalid_d_lbl_pos() is None
}

///|
/// Quote a series label in an error message so an empty or whitespace label is
/// still legible.
fn escape_label(label : String) -> String {
  "\"" + label + "\""
}
