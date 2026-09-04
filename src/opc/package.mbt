// OPC Package — the top-level container, a ZIP file holding parts and
// relationships per ISO/IEC 29500-2.
//
// This module owns the bare structural layer. `ContentTypes` and
// `Relationships` build on top.

///|
/// An OPC package — a collection of named parts that round-trips through ZIP.
///
/// The `parts` array preserves the order of entries in the underlying ZIP
/// for stable byte-near-equal round-trip, even though OPC itself does not
/// give meaning to entry order.
///
/// `content_types` mirrors the parsed `[Content_Types].xml` for fast lookup.
/// `Package::open` populates it; `Package::new` starts it empty. There is
/// no automatic synchronisation when parts are added or removed; the caller
/// (or a higher layer) is responsible for keeping `[Content_Types].xml` in
/// sync via `set_content_types`.
pub struct Package {
  parts : Array[Part]
  mut content_types : ContentTypes
  index : Map[String, Int]
}

// `index` maps a part name to its position in `parts`, so `part_by_name`
// and `add_part`'s duplicate check do not scan the array. It is
// maintained by every mutator here and rebuilt by `remove_part`, whose
// removal shifts later positions. `parts()` hands out the live array:
// pushing or removing through it directly would desync the map, so
// package mutation goes through this API.

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
    parts.push({ name, content_type: "", bytes: entry.1, })
  }
  let index = build_part_index(parts)
  // Locate [Content_Types].xml and parse it.
  let mut ct_bytes : FixedArray[Byte]? = None
  for p in parts {
    if p.name == content_types_part_name {
      ct_bytes = Some(p.bytes)
      break
    }
  }
  let content_types = match ct_bytes {
    Some(b) => ContentTypes::parse(b)
    None =>
      raise MalformedPackage(
        "package is missing the required " + content_types_part_name + " part",
      )
  }
  // Populate each part's content_type by lookup.
  for p in parts {
    if p.name == content_types_part_name {
      // [Content_Types].xml itself is implicit; the spec doesn't require an
      // entry. Skip resolution for it to keep behaviour predictable.
      continue
    }
    match content_types.resolve(p.name) {
      Some(ct) => p.content_type = ct
      None => () // unresolved — leave empty; callers can detect with `is_empty`
    }
  }
  { parts, content_types, index, }
}

///|
/// Construct an empty package with no parts and an empty content-types
/// catalog. Useful as a starting point for builder code or tests.
pub fn Package::new() -> Package {
  { parts: [], content_types: ContentTypes::new(), index: Map([]), }
}

///|
/// Build the name → position map `Package.index` keeps. On a duplicate
/// name the first position wins, matching the old linear scan.
fn build_part_index(parts : Array[Part]) -> Map[String, Int] {
  let index : Map[String, Int] = Map([])
  for i, p in parts {
    if index.get(p.name) is None {
      index[p.name] = i
    }
  }
  index
}

///|
/// Return the parsed content-types catalog.
pub fn Package::content_types(self : Package) -> ContentTypes {
  self.content_types
}

///|
/// Replace the content-types catalog. Does NOT update the
/// `[Content_Types].xml` part bytes — call `regenerate_content_types_part`
/// (or do it yourself) before `to_bytes` if you want the change to round-trip.
pub fn Package::set_content_types(self : Package, ct : ContentTypes) -> Unit {
  self.content_types = ct
}

///|
/// Re-serialise the in-memory `ContentTypes` to bytes and store them as the
/// `[Content_Types].xml` part. Adds the part if it's missing.
pub fn Package::regenerate_content_types_part(
  self : Package,
) -> Unit raise OpcError {
  let bytes = self.content_types.serialize()
  let part : Part = { name: content_types_part_name, content_type: "", bytes, }
  if !self.replace_part(part) {
    self.index[content_types_part_name] = self.parts.length()
    self.parts.push(part)
  }
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
  match self.index.get(name) {
    Some(i) => Some(self.parts[i])
    None => None
  }
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
  if self.index.get(part.name) is Some(_) {
    raise MalformedPackage("duplicate part name: " + part.name)
  }
  self.index[part.name] = self.parts.length()
  self.parts.push(part)
}

///|
/// Replace the part named `part.name` in place, keeping its position.
/// Returns false — and changes nothing — if no such part exists.
///
/// This is the cheap alternative to remove-then-add for a part whose bytes
/// changed: it is O(1) instead of two linear scans plus an array shift, and
/// it leaves package order alone, so re-emitted ZIP entries stay in the
/// order they were read in.
pub fn Package::replace_part(self : Package, part : Part) -> Bool {
  match self.index.get(part.name) {
    Some(i) => {
      self.parts[i] = part
      true
    }
    None => false
  }
}

///|
/// Return the relationships originating from `source` (a part name, or
/// `package_root` for the package-level rels at `/_rels/.rels`).
///
/// If the corresponding `.rels` part is missing, returns an empty
/// `Relationships` — per OPC, parts are not required to have rels.
pub fn Package::relationships_for(
  self : Package,
  source : String,
) -> Relationships raise OpcError {
  let path = rels_path_for(source)
  match self.part_by_name(path) {
    Some(p) => Relationships::parse(source, p.bytes)
    None => Relationships::new(source)
  }
}

///|
/// Remove a part by OPC name. Returns true if a part was removed.
pub fn Package::remove_part(self : Package, name : String) -> Bool {
  match self.index.get(name) {
    Some(i) => {
      let _ = self.parts.remove(i)
      // Every position after `i` shifted down, so the map is rebuilt
      // rather than patched. Removal is rare; replacement is the hot path
      // and goes through `replace_part`.
      let rebuilt = build_part_index(self.parts)
      self.index.clear()
      for k, v in rebuilt {
        self.index[k] = v
      }
      true
    }
    None => false
  }
}
