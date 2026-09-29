// Trait methods kept callable as regular methods.

///|
pub extend ContentTypes with Eq::{equal}

///|
pub extend OpcError with Eq::{equal}

///|
pub extend OpcError with Show::{to_string}

///|
pub extend Part with Show::{to_string}

///|
pub extend TargetMode with Eq::{equal}

///|
pub extend Relationship with Eq::{equal}

///|
pub extend Relationship with Show::{to_string}

// Redundant trait methods, deprecated for method-call use and hidden
// from the generated interface.

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend ContentTypes with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend ContentTypes with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend OpcError with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend OpcError with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend OpcError with @debug.Debug::{to_repr}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend Part with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Part with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend TargetMode with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend TargetMode with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Relationship with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend Relationship with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Relationship with @debug.Debug::{to_repr}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Relationships with @debug.Debug::{to_repr}
