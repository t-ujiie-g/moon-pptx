// Deep-clone helpers for `@opc` data types.
//
// Immutable builder variants on `@presentation.Presentation`
// (`with_added_slide`, `with_slide_updated`, …) all share the same
// shape: clone the package, mutate the clone, return the new value.
// To make that fast and safe we need every layer to be cloneable:
//
//   - `FixedArray[Byte]` for part bytes — must copy the buffer so a
//     mutation on one clone's bytes can't reach the other. MoonBit's
//     `FixedArray::copy()` would do it, but writing the loop here keeps
//     us insulated from any future signature shift.
//   - `Array[(String, String)]` for ContentTypes' defaults / overrides
//     — `String` itself is immutable in MoonBit, so a shallow push-
//     into-new-array is sufficient.
//   - `Array[Part]` for the package's parts — each entry is a fresh
//     `Part` value built from a cloned bytes buffer.
//
// These are exposed as `pub fn` on each type rather than free
// functions so callers can write `pkg.clone()` symmetrically with
// the rest of the API.

///|
/// Copy a byte buffer. Used internally by `Part::clone`; exposed
/// publicly because higher-level wrappers (`Presentation::clone`)
/// occasionally want to duplicate a buffer directly.
pub fn copy_bytes(bytes : FixedArray[Byte]) -> FixedArray[Byte] {
  let out = FixedArray::make(bytes.length(), b'\x00')
  let mut i = 0
  while i < bytes.length() {
    out[i] = bytes[i]
    i = i + 1
  }
  out
}

///|
/// Deep-copy a `Part`. The cloned part shares no mutable state with
/// the original — its byte buffer is a fresh `FixedArray` and the
/// `mut content_type` field can be mutated on one side without
/// affecting the other.
pub fn Part::clone(self : Part) -> Part {
  {
    name: self.name,
    content_type: self.content_type,
    bytes: copy_bytes(self.bytes),
  }
}

///|
/// Deep-copy a `ContentTypes` catalog. Both `defaults` and
/// `overrides` get fresh arrays so `with_default` / `with_override`
/// on a clone don't reach back into the original.
pub fn ContentTypes::clone(self : ContentTypes) -> ContentTypes {
  let new_defaults : Array[(String, String)] = []
  for kv in self.defaults {
    new_defaults.push(kv)
  }
  let new_overrides : Array[(String, String)] = []
  for kv in self.overrides {
    new_overrides.push(kv)
  }
  { defaults: new_defaults, overrides: new_overrides }
}

///|
/// Deep-copy an entire `Package`. The cloned package can be mutated
/// (parts added / removed, content types updated, bytes replaced)
/// without affecting the original. Used by the immutable builder
/// variants on `Presentation` (`with_added_slide`, `with_slide_updated`).
pub fn Package::clone(self : Package) -> Package {
  let new_parts : Array[Part] = []
  for p in self.parts {
    new_parts.push(p.clone())
  }
  { parts: new_parts, content_types: self.content_types.clone() }
}
