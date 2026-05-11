// Length units.
//
// OOXML's canonical length unit is the EMU (English Metric Unit). All
// other units convert through EMU. The conversion table is exact:
//
//   1 inch = 914_400 EMU = 72 pt = 2.54 cm
//
// `Emu` is `Int64` because slide-coordinate math overflows 32-bit Int
// (a single 1920x1080 slide is ~12_192_000 x 6_858_000 EMU; products of
// two such values exceed 2^31).
//
// `Pt`, `Inch`, `Cm` carry `Double` for ergonomic input (e.g. `Inch(0.5)`).
// Round-trip through EMU is lossy at sub-EMU precision; the truncation
// happens at `*::to_emu()`.

///|
/// Number of EMU in one inch (the OOXML canonical conversion factor).
pub let emu_per_inch : Int64 = 914_400L

///|
/// Number of EMU in one point (914_400 / 72).
pub let emu_per_pt : Int64 = 12_700L

///|
/// Number of EMU in one centimetre (914_400 / 2.54).
pub let emu_per_cm : Int64 = 360_000L

///|
/// English Metric Unit, OOXML's canonical length unit. Always exact.
pub(all) struct Emu(Int64) derive(Eq, Compare, Debug)

///|
/// Length expressed in points (1/72 inch). Constructor accepts fractional values.
pub(all) struct Pt(Double) derive(Eq, Debug)

///|
/// Length expressed in inches. Constructor accepts fractional values.
pub(all) struct Inch(Double) derive(Eq, Debug)

///|
/// Length expressed in centimetres. Constructor accepts fractional values.
pub(all) struct Cm(Double) derive(Eq, Debug)

// --- accessors ---

///|
pub fn Emu::value(self : Emu) -> Int64 {
  self.0
}

///|
pub fn Pt::value(self : Pt) -> Double {
  self.0
}

///|
pub fn Inch::value(self : Inch) -> Double {
  self.0
}

///|
pub fn Cm::value(self : Cm) -> Double {
  self.0
}

// --- conversions to Emu (the canonical unit) ---

///|
/// Convert points to EMU. Truncates toward zero at sub-EMU precision.
pub fn Pt::to_emu(self : Pt) -> Emu {
  Emu((self.0 * emu_per_pt.to_double()).to_int64())
}

///|
/// Convert inches to EMU. Truncates toward zero at sub-EMU precision.
pub fn Inch::to_emu(self : Inch) -> Emu {
  Emu((self.0 * emu_per_inch.to_double()).to_int64())
}

///|
/// Convert centimetres to EMU. Truncates toward zero at sub-EMU precision.
pub fn Cm::to_emu(self : Cm) -> Emu {
  Emu((self.0 * emu_per_cm.to_double()).to_int64())
}

// --- conversions from Emu ---

///|
/// Convert EMU to points (lossy: precision limited to Double mantissa).
pub fn Emu::to_pt(self : Emu) -> Pt {
  Pt(self.0.to_double() / emu_per_pt.to_double())
}

///|
/// Convert EMU to inches (lossy: precision limited to Double mantissa).
pub fn Emu::to_inch(self : Emu) -> Inch {
  Inch(self.0.to_double() / emu_per_inch.to_double())
}

///|
/// Convert EMU to centimetres (lossy: precision limited to Double mantissa).
pub fn Emu::to_cm(self : Emu) -> Cm {
  Cm(self.0.to_double() / emu_per_cm.to_double())
}

// --- Show (for assert_eq diagnostics) ---

///|
pub impl Show for Emu with output(self, logger) {
  logger.write_string("Emu(")
  logger.write_object(self.0)
  logger.write_string(")")
}

///|
pub impl Show for Pt with output(self, logger) {
  logger.write_string("Pt(")
  logger.write_object(self.0)
  logger.write_string(")")
}

///|
pub impl Show for Inch with output(self, logger) {
  logger.write_string("Inch(")
  logger.write_object(self.0)
  logger.write_string(")")
}

///|
pub impl Show for Cm with output(self, logger) {
  logger.write_string("Cm(")
  logger.write_object(self.0)
  logger.write_string(")")
}

// --- Emu arithmetic (the only unit where exact math makes sense) ---

///|
pub fn Emu::add(self : Emu, other : Emu) -> Emu {
  Emu(self.0 + other.0)
}

///|
pub fn Emu::sub(self : Emu, other : Emu) -> Emu {
  Emu(self.0 - other.0)
}

///|
pub fn Emu::neg(self : Emu) -> Emu {
  Emu(-self.0)
}
