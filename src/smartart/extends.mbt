// Trait methods kept callable as regular methods.

///|
pub extend SmartArtError with Eq::{equal}

///|
pub extend SmartArtError with Show::{to_string}

///|
pub extend SmartArtKind with Eq::{equal}

///|
pub extend NodeStyle with Eq::{equal}

///|
pub extend Node with Eq::{equal}

///|
pub extend SmartArt with Eq::{equal}

// Redundant trait methods, deprecated for method-call use and hidden
// from the generated interface.

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend SmartArtError with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend SmartArtError with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SmartArtError with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend SmartArtKind with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SmartArtKind with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend NodeStyle with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend NodeStyle with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Node with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Node with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend SmartArt with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SmartArt with @debug.Debug::{to_repr}
