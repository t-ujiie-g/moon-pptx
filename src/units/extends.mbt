// Trait methods kept callable as regular methods.

///|
pub extend Angle with Eq::{equal}

///|
pub extend Angle with Show::{to_string}

///|
pub extend UnitsError with Eq::{equal}

///|
pub extend UnitsError with Show::{to_string}

///|
pub extend HslColor with Eq::{equal}

///|
pub extend HslColor with Show::{to_string}

///|
pub extend Emu with Eq::{equal}

///|
pub extend Emu with Compare::{compare}

///|
pub extend Emu with Show::{to_string}

///|
pub extend Pt with Eq::{equal}

///|
pub extend Pt with Show::{to_string}

///|
pub extend Inch with Eq::{equal}

///|
pub extend Inch with Show::{to_string}

///|
pub extend Cm with Eq::{equal}

///|
pub extend Cm with Show::{to_string}

///|
pub extend Percentage with Eq::{equal}

///|
pub extend Percentage with Show::{to_string}

///|
pub extend RgbColor with Eq::{equal}

///|
pub extend RgbColor with Show::{to_string}

///|
pub extend ThemeColor with Eq::{equal}

///|
pub extend ThemeColor with Show::{to_string}

///|
pub extend ColorTransform with Eq::{equal}

///|
pub extend ColorTransform with Show::{to_string}

///|
pub extend SchemeColor with Show::{to_string}

// Redundant trait methods, deprecated for method-call use and hidden
// from the generated interface.

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Angle with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend Angle with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Angle with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend UnitsError with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend UnitsError with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend UnitsError with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend HslColor with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend HslColor with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend HslColor with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Emu with Eq::{not_equal}

///|
#deprecated("Use the comparison operators (`<`, `<=`, `>=`, `>`) instead", skip_current_package=true)
#doc(hidden)
pub extend Emu with Compare::{op_lt, op_le, op_gt, op_ge}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend Emu with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Emu with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Pt with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend Pt with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Pt with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Inch with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend Inch with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Inch with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Cm with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend Cm with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Cm with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Percentage with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend Percentage with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Percentage with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend RgbColor with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend RgbColor with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend RgbColor with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ThemeColor with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend ThemeColor with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ThemeColor with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ColorTransform with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend ColorTransform with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ColorTransform with @debug.Debug::{to_repr}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend SchemeColor with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SchemeColor with @debug.Debug::{to_repr}
