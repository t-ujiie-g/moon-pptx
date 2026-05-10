// OPC Package — the top-level container, a ZIP file holding parts and
// relationships per ISO/IEC 29500-2.
//
// This module covers Phase 2a: the bare structural layer. ContentTypes
// (Phase 2b) and Relationships (Phase 2c) build on top.

///|
/// An OPC package — a collection of named parts that round-trips through ZIP.
///
/// The `parts` array preserves the order of entries in the underlying ZIP
/// for stable byte-near-equal round-trip, even though OPC itself does not
/// give meaning to entry order.
pub struct Package {
  parts : Array[Part]
}

///|
/// Open a package from raw `.pptx` bytes.
///
/// Wraps every fzip failure in `OpcError::ZipFailure` so callers don't
/// have to mix two error types.
pub fn Package::open(bytes : FixedArray[Byte]) -> Package raise OpcError {
  let entries = @fzip.unzip_sync(bytes) catch { e => raise wrap_fzip(e) }
  let parts : Array[Part] = Array::new(capacity=entries.length())
  for entry in entries {
    let name = zip_name_to_opc(entry.0)
    parts.push({ name, content_type: "", bytes: entry.1 })
  }
  { parts, }
}

///|
/// Construct an empty package with no parts. Useful as a starting point for
/// builder code or tests.
pub fn Package::new() -> Package {
  { parts: Array::new() }
}

///|
/// Pack the package back to ZIP bytes.
pub fn Package::to_bytes(self : Package) -> FixedArray[Byte] {
  let entries : Array[(String, FixedArray[Byte])] = Array::new(
    capacity=self.parts.length(),
  )
  for p in self.parts {
    entries.push((opc_name_to_zip(p.name), p.bytes))
  }
  @fzip.zip_sync(entries)
}

///|
/// Return all parts in source / construction order.
pub fn Package::parts(self : Package) -> Array[Part] {
  self.parts
}

///|
/// Look up a part by its OPC name (`/ppt/presentation.xml`). Returns `None`
/// if no such part exists. Use `require_part` if absence should be an error.
pub fn Package::part_by_name(self : Package, name : String) -> Part? {
  for p in self.parts {
    if p.name == name {
      return Some(p)
    }
  }
  None
}

///|
/// Like `part_by_name` but raises `OpcError::PartNotFound` instead of
/// returning `None`. Convenience for callers that have already established
/// the part must exist.
pub fn Package::require_part(
  self : Package,
  name : String,
) -> Part raise OpcError {
  match self.part_by_name(name) {
    Some(p) => p
    None => raise PartNotFound(name)
  }
}

///|
/// Append a part. Raises if a part with the same name already exists.
pub fn Package::add_part(self : Package, part : Part) -> Unit raise OpcError {
  for p in self.parts {
    if p.name == part.name {
      raise MalformedPackage("duplicate part name: " + part.name)
    }
  }
  self.parts.push(part)
}

///|
/// Remove a part by OPC name. Returns true if a part was removed.
pub fn Package::remove_part(self : Package, name : String) -> Bool {
  let mut i = 0
  while i < self.parts.length() {
    if self.parts[i].name == name {
      let _ = self.parts.remove(i)
      return true
    }
    i = i + 1
  }
  false
}
