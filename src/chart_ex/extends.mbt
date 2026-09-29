// Trait methods kept callable as regular methods.

///|
pub extend ChartExError with Eq::{equal}

///|
pub extend ChartExError with Show::{to_string}

///|
pub extend ChartEx with Eq::{equal}

///|
pub extend ChartEx with Show::{to_string}

///|
pub extend ChartExBody with Eq::{equal}

///|
pub extend ChartExBody with Show::{to_string}

///|
pub extend ChartExPlotArea with Eq::{equal}

///|
pub extend ChartExPlotArea with Show::{to_string}

///|
pub extend ChartExPlotAreaRegion with Eq::{equal}

///|
pub extend ChartExPlotAreaRegion with Show::{to_string}

///|
pub extend ChartExSeries with Eq::{equal}

///|
pub extend ChartExSeries with Show::{to_string}

///|
pub extend ChartExKind with Eq::{equal}

///|
pub extend ChartExKind with Show::{to_string}

// Redundant trait methods, deprecated for method-call use and hidden
// from the generated interface.

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExError with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExError with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExError with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartEx with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartEx with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartEx with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExBody with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExBody with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExBody with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExPlotArea with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExPlotArea with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExPlotArea with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExPlotAreaRegion with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExPlotAreaRegion with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExPlotAreaRegion with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExSeries with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExSeries with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExSeries with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExKind with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExKind with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ChartExKind with @debug.Debug::{to_repr}
