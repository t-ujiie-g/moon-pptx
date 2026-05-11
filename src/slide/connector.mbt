// Connector (`p:cxnSp`) shape model.
//
// A connector is structurally a sibling of `p:sp`: same `<p:spPr>` body
// (transform + geometry), but the non-visual properties carry optional
// start/end "connection sites" — references that snap the connector's
// endpoints to specific connection points on other shapes.
//
//   <p:cxnSp>
//     <p:nvCxnSpPr>
//       <p:cNvPr id="6" name="Straight Connector 5"/>
//       <p:cNvCxnSpPr>
//         <a:stCxn id="2" idx="3"/>
//         <a:endCxn id="3" idx="1"/>
//       </p:cNvCxnSpPr>
//       <p:nvPr/>
//     </p:nvCxnSpPr>
//     <p:spPr>…</p:spPr>
//   </p:cxnSp>

///|
/// One end of a connector — references the target shape by `id` and
/// chooses one of its connection-point indices.
pub(all) struct ConnectionEnd {
  shape_id : Int
  idx : Int
} derive(Eq, Debug)

///|
/// `<p:cxnSp>` — connector shape.
///
/// `start` and `end` are present only when the connector is bound to
/// other shapes; free-floating connectors (drawn between coordinates
/// alone) have both as `None`.
pub(all) struct Connector {
  id : Int
  name : String
  transform : Transform?
  geometry : Geometry?
  /// `<a:ln>` outline parsed off `<p:spPr>`. Connectors almost always
  /// carry one (they're a line by definition).
  stroke : @oxml.Stroke?
  /// `<a:effectLst>` parsed off `<p:spPr>`.
  effects : @oxml.EffectList?
  start : ConnectionEnd?
  end : ConnectionEnd?
} derive(Eq, Debug)
