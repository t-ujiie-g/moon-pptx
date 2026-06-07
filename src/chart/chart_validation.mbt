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

///|
/// Quote a series label in an error message so an empty or whitespace label is
/// still legible.
fn escape_label(label : String) -> String {
  "\"" + label + "\""
}
