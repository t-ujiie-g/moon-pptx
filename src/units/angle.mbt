// Angle.
//
// OOXML's `ST_Angle` (xsd:int) encodes angles in 1/60_000 of a degree, so a
// quarter turn (90°) is 5_400_000. Used for shape rotation and gradient
// direction. Positive values are clockwise per OOXML's coordinate system.
//
// We expose `Angle` as a degree-valued `Double` (e.g. `Angle(90.0)` for 90°).
// Conversion to/from the OOXML 1/60_000-degree integer is explicit.

///|
/// Conversion factor: 1 degree = 60_000 OOXML units.
pub let ooxml_per_degree : Int = 60_000

///|
/// An angle in degrees. Sign convention is OOXML's (positive = clockwise).
pub(all) struct Angle(Double) derive(Eq, Debug)

///|
pub fn Angle::degrees(self : Angle) -> Double {
  self.0
}

///|
/// Convert to the OOXML 1/60_000-degree integer representation.
/// Truncates toward zero.
pub fn Angle::to_ooxml(self : Angle) -> Int {
  (self.0 * ooxml_per_degree.to_double()).to_int()
}

///|
/// Construct an `Angle` from the OOXML 1/60_000-degree integer representation
/// (e.g. `from_ooxml(5_400_000)` is 90°).
pub fn Angle::from_ooxml(n : Int) -> Angle {
  Angle(n.to_double() / ooxml_per_degree.to_double())
}

///|
pub impl Show for Angle with output(self, logger) {
  logger.write_string("Angle(")
  logger.write_object(self.0)
  logger.write_string("deg)")
}
