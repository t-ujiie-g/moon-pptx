// Shared fixture helpers for slide parser tests.
//
// Every `*_test.mbt` in this package compiles into one blackbox-test
// package, so anything defined here is visible to every test file.
// Centralising namespace literals and the UTF-8 encoder removes the
// per-file duplication.

///|
/// Test-side aliases for the shared OOXML namespace URIs. Tests
/// interpolate these directly into XML string literals, so we expose them
/// under short names — the canonical definitions live in `@oxml`.
let pml_ns : String = @oxml.presentation_ns

///|
let dml_ns : String = @oxml.drawing_ns

///|
let off_rel_ns : String = @oxml.office_relationships_ns

///|
/// UTF-8 encode a string to a `FixedArray[Byte]`. Used by every test
/// fixture that hands raw bytes to `Slide::parse`. Handles every code
/// point, including the bullet glyph `•` (U+2022) and similar multi-byte
/// characters that appeared in earlier per-file copies.
