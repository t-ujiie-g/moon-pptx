// Shared XML write helpers for OOXML serialisers.
//
// All Phase 3 parsers capture unmodelled XML into `extension :
// Array[@xml.XmlElement]` per ADR-004; the Phase 4 writers need a
// counterpart that emits those captured subtrees back to the wire
// without loss. `write_xml_element` walks the captured DOM recursively
// and feeds events into a `@xml.XmlWriter`.
//
// Namespace handling: the writer requires every namespace URI used in
// an element or attribute name to have a prefix already bound via
// `XmlWriter::bind_namespace`. The captured `XmlElement`s carry only
// resolved URIs (the reader strips `xmlns:*` declarations), so this
// helper has to allocate prefixes itself for any URI the caller hasn't
// pre-bound. We track pre-bound URIs through a caller-supplied
// `known_prefixes : Map[String, String]` (URI → prefix). Anything not
// in that map gets a fresh `ext0`, `ext1`, … prefix bound on-the-fly
// and emitted as an `xmlns:extN` attribute at the element where the
// URI first appears.
//
// Calling convention: callers bind the document's well-known
// namespaces (e.g. `p`, `a`, `r`) on the writer **and** populate
// `known_prefixes` with the same entries before invoking
// `write_xml_element`. The helper then handles only the long-tail
// foreign-namespace extensions that real-world PPTX occasionally
// carries inside `<p:extLst>` and friends.

///|
/// Mutable counter for fresh `extN` prefixes. Carried alongside the
/// known-prefix map so nested calls share the same allocator.
pub(all) struct WriteCtx {
  /// URI → prefix bindings the writer already knows. Updated in place
  /// as `write_xml_element` discovers foreign URIs.
  known_prefixes : Map[String, String]
  /// Next free `extN` counter.
  mut next_ext : Int
}

///|
/// Create a fresh write context seeded with the well-known OOXML
/// namespaces bound to their canonical short prefixes (`a`, `p`, `r`).
/// Callers must also call `bind_namespace` on their writer for the same
/// URIs — this helper only tracks what the writer is *expected* to
/// know; it can't introspect the writer's actual state.
pub fn WriteCtx::with_well_known_prefixes() -> WriteCtx {
  let m : Map[String, String] = Map([])
  m[drawing_ns] = "a"
  m[presentation_ns] = "p"
  m[office_relationships_ns] = "r"
  { known_prefixes: m, next_ext: 0 }
}

///|
/// Write a captured `XmlElement` subtree onto `w` verbatim, allocating
/// fresh prefixes (and emitting their `xmlns:extN` declarations) for
/// any namespace URI not already in `ctx.known_prefixes`. Mutates
/// `ctx` so subsequent calls reuse the allocations.
pub fn write_xml_element(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  el : @xml.XmlElement,
) -> Unit raise @xml.XmlError {
  // 1. Bind any URIs in this element's name + attribute names that
  //    aren't yet known. Track which ones were freshly bound at this
  //    level so we emit their `xmlns:extN` decls on the start tag.
  let newly_bound : Array[(String, String)] = [] // (prefix, uri)
  ensure_uri_bound(w, ctx, el.name.uri, newly_bound)
  for kv in el.attributes {
    ensure_uri_bound(w, ctx, kv.0.uri, newly_bound)
  }
  // 2. Open the element.
  w.start_element(el.name)
  // 3. Emit xmlns declarations for the freshly-bound URIs at this
  //    element. (Already-known URIs were declared upstream.)
  for nb in newly_bound {
    w.namespace_attr(nb.0, nb.1)
  }
  // 4. Emit attributes verbatim.
  for kv in el.attributes {
    w.attribute(kv.0, kv.1)
  }
  // 5. Recurse into children, then close.
  for child in el.children {
    match child {
      Element(c) => write_xml_element(w, ctx, c)
      Text(s) => w.text(s)
      CData(s) => w.cdata(s)
    }
  }
  w.end_element()
}

///|
/// Bind `uri` on `w` with a fresh `extN` prefix iff it isn't already
/// in `ctx.known_prefixes` (and isn't the empty default-namespace
/// URI). Pushes the new (prefix, uri) onto `newly_bound` so the caller
/// can emit `xmlns:extN` on the active start tag.
fn ensure_uri_bound(
  w : @xml.XmlWriter,
  ctx : WriteCtx,
  uri : String,
  newly_bound : Array[(String, String)],
) -> Unit {
  if uri == "" {
    return
  }
  if ctx.known_prefixes.contains(uri) {
    return
  }
  let prefix = "ext" + ctx.next_ext.to_string()
  ctx.next_ext = ctx.next_ext + 1
  ctx.known_prefixes[uri] = prefix
  w.bind_namespace(prefix, uri)
  newly_bound.push((prefix, uri))
}

///|
/// UTF-8 encode a `String` into a `FixedArray[Byte]`. Mirrors
/// `bytes_to_string` (the reader-side decoder) — every Phase 4
/// serialiser ends with this conversion when producing part bytes.
pub fn string_to_bytes(s : String) -> FixedArray[Byte] {
  let buf : Array[Int] = []
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      buf.push(cp)
    } else if cp < 0x800 {
      buf.push(0xC0 | (cp >> 6))
      buf.push(0x80 | (cp & 0x3F))
    } else if cp < 0x10000 {
      buf.push(0xE0 | (cp >> 12))
      buf.push(0x80 | ((cp >> 6) & 0x3F))
      buf.push(0x80 | (cp & 0x3F))
    } else {
      buf.push(0xF0 | (cp >> 18))
      buf.push(0x80 | ((cp >> 12) & 0x3F))
      buf.push(0x80 | ((cp >> 6) & 0x3F))
      buf.push(0x80 | (cp & 0x3F))
    }
  }
  let bytes = FixedArray::make(buf.length(), b'\x00')
  let mut i = 0
  while i < buf.length() {
    bytes[i] = buf[i].to_byte()
    i = i + 1
  }
  bytes
}
