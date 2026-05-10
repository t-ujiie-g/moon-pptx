// Errors raised by the OPC layer.

///|
/// Errors raised while reading or writing an OPC package.
///
/// `ZipFailure` carries the underlying `@fzip` error code and message as
/// strings (the `FzipError` type itself does not implement `Debug`/`Show`,
/// so we flatten at the boundary).
/// `MalformedPackage` covers OPC-spec violations detected on top of a
/// successfully unzipped container.
pub(all) suberror OpcError {
  /// Raised when the underlying ZIP layer cannot pack or unpack the bytes.
  /// Payload is `(code-name, message)`.
  ZipFailure(String, String)
  /// Raised when the package structure violates the OPC spec (missing
  /// required parts, malformed names, etc.). Payload is a description.
  MalformedPackage(String)
  /// Raised when a requested part name is not present in the package.
  PartNotFound(String)
} derive(Eq, Debug)

///|
/// Wrap a `@fzip.FzipError` as an `OpcError::ZipFailure`. Used at every call
/// site that bridges the `@fzip` and OPC layers.
pub fn wrap_fzip(e : @fzip.FzipError) -> OpcError {
  let FzipError(code~, message~) = e
  ZipFailure(code.to_string(), message)
}

///|
pub impl Show for OpcError with output(self, logger) {
  match self {
    ZipFailure(code, msg) => {
      logger.write_string("ZipFailure(")
      logger.write_object(code)
      logger.write_string(", ")
      logger.write_object(msg)
      logger.write_string(")")
    }
    MalformedPackage(s) => {
      logger.write_string("MalformedPackage(")
      logger.write_object(s)
      logger.write_string(")")
    }
    PartNotFound(s) => {
      logger.write_string("PartNotFound(")
      logger.write_object(s)
      logger.write_string(")")
    }
  }
}
