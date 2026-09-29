// Trait methods kept callable as regular methods.

///|
pub extend AppProperties with Eq::{equal}

///|
pub extend CoreProperties with Eq::{equal}

///|
pub extend PptxError with Eq::{equal}

///|
pub extend PptxError with Show::{to_string}

///|
pub extend SlideMasterIdRef with Eq::{equal}

///|
pub extend SlideIdRef with Eq::{equal}

///|
pub extend SlideSize with Eq::{equal}

///|
pub extend NotesSize with Eq::{equal}

///|
pub extend PresentationPart with Eq::{equal}

///|
pub extend Section with Eq::{equal}

///|
pub extend SlideSizeKind with Eq::{equal}

///|
pub extend SlideSizeKind with Show::{to_string}

// Redundant trait methods, deprecated for method-call use and hidden
// from the generated interface.

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend AppProperties with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend AppProperties with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend CoreProperties with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend CoreProperties with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend PptxError with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend PptxError with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend PptxError with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend SlideMasterIdRef with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SlideMasterIdRef with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend SlideIdRef with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SlideIdRef with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend SlideSize with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SlideSize with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend NotesSize with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend NotesSize with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend PresentationPart with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend PresentationPart with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Section with Eq::{not_equal}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend Section with @debug.Debug::{to_repr}

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend SlideSizeKind with Eq::{not_equal}

///|
#deprecated("Use `Show::output` instead", skip_current_package=true)
#doc(hidden)
pub extend SlideSizeKind with Show::{output}

///|
#deprecated("Use `Debug::to_repr` instead", skip_current_package=true)
#doc(hidden)
pub extend SlideSizeKind with @debug.Debug::{to_repr}

///|
#deprecated("Use `LayoutType::layout_type` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleSlide with LayoutType::{layout_type}

///|
#deprecated("Use `LayoutPlaceholders::placeholders` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleSlide with LayoutPlaceholders::{placeholders}

///|
#deprecated("Use `HasTitle::title_spec` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleSlide with HasTitle::{title_spec}

///|
#deprecated("Use `HasSubtitle::subtitle_spec` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleSlide with HasSubtitle::{subtitle_spec}

///|
#deprecated("Use `LayoutType::layout_type` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleAndContent with LayoutType::{layout_type}

///|
#deprecated("Use `LayoutPlaceholders::placeholders` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleAndContent with LayoutPlaceholders::{placeholders}

///|
#deprecated("Use `HasTitle::title_spec` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleAndContent with HasTitle::{title_spec}

///|
#deprecated("Use `HasBody::body_spec` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleAndContent with HasBody::{body_spec}

///|
#deprecated("Use `LayoutType::layout_type` instead", skip_current_package=true)
#doc(hidden)
pub extend SectionHeader with LayoutType::{layout_type}

///|
#deprecated("Use `LayoutPlaceholders::placeholders` instead", skip_current_package=true)
#doc(hidden)
pub extend SectionHeader with LayoutPlaceholders::{placeholders}

///|
#deprecated("Use `HasTitle::title_spec` instead", skip_current_package=true)
#doc(hidden)
pub extend SectionHeader with HasTitle::{title_spec}

///|
#deprecated("Use `HasBody::body_spec` instead", skip_current_package=true)
#doc(hidden)
pub extend SectionHeader with HasBody::{body_spec}

///|
#deprecated("Use `LayoutType::layout_type` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleOnly with LayoutType::{layout_type}

///|
#deprecated("Use `LayoutPlaceholders::placeholders` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleOnly with LayoutPlaceholders::{placeholders}

///|
#deprecated("Use `HasTitle::title_spec` instead", skip_current_package=true)
#doc(hidden)
pub extend TitleOnly with HasTitle::{title_spec}

///|
#deprecated("Use `LayoutType::layout_type` instead", skip_current_package=true)
#doc(hidden)
pub extend BlankSlide with LayoutType::{layout_type}

///|
#deprecated("Use `LayoutPlaceholders::placeholders` instead", skip_current_package=true)
#doc(hidden)
pub extend BlankSlide with LayoutPlaceholders::{placeholders}
