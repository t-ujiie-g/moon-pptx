// Percentage.
//
// OOXML uses two related percentage encodings:
//   * `ST_Percentage` (xsd:int): value in 1/1000 of a percent — so 50% = 50_000.
//   * `ST_PositivePercentage` / `ST_NegativePercentage`: same scale, signed bound.
//
// We expose `Percentage` as a percent-valued `Double` (e.g. `Percentage(50.0)`
// for 50%), with explicit conversion to/from the OOXML 1/1000 % integer
// representation via `to_ooxml()` / `from_ooxml()`.

///|
/// Conversion factor: 1 percent = 1000 OOXML units.
pub let ooxml_per_percent : Int = 1000

///|
/// A percentage value, expressed in percent (e.g. `Percentage(50.0)` is 50%).
/// Negative values are permitted; OOXML element constraints decide validity.
pub(all) struct Percentage(Double) derive(Eq, Debug)

///|
/// Unwrap the percentage value as a `Double` percent (e.g.
/// `50.0` for 50 %).
pub fn Percentage::value(self : Percentage) -> Double {
  self.0
}

///|
/// Convert to the OOXML 1/1000-of-a-percent integer representation.
/// Truncates toward zero.
pub fn Percentage::to_ooxml(self : Percentage) -> Int {
  (self.0 * ooxml_per_percent.to_double()).to_int()
}

///|
/// Construct a `Percentage` from the OOXML 1/1000-of-a-percent integer
/// representation (e.g. `from_ooxml(50_000)` is 50%).
pub fn Percentage::from_ooxml(n : Int) -> Percentage {
  Percentage(n.to_double() / ooxml_per_percent.to_double())
}

///|
pub impl Show for Percentage with fn output(self, logger) {
  logger.write_string("Percentage(")
  logger.write_object(self.0)
  logger.write_string("%)")
}
