// Slide Layout model + parser.
//
// A slide layout part (`/ppt/slideLayouts/slideLayout*.xml`) extends a slide
// master and may override the color map. Per ECMA-376 §19.3.1.39:
//
//   <p:sldLayout type="title" preserve="1">
//     <p:cSld name="Title Slide">…</p:cSld>
//     <p:clrMapOvr>
//       <a:masterClrMapping/>           -- inherit from master (default)
//       OR
//       <a:overrideClrMapping bg1="…" tx1="…" …/>  -- explicit overrides
//     </p:clrMapOvr>
//     <p:transition>…</p:transition>    -- optional
//     <p:timing>…</p:timing>            -- optional
//     <p:hf …/>                         -- optional
//     <p:extLst>…</p:extLst>            -- optional
//   </p:sldLayout>

///|
/// Layout type per `ST_SlideLayoutType` (ECMA-376 §20.3.1.42). Covers the
/// 27 spec values plus `Custom` for `type="cust"`. Real PPTX uses about a
/// half-dozen of these in practice; we model all of them so we can preserve
/// values from third-party tools.
pub(all) enum SlideLayoutType {
  Title // "title"
  Tx // "tx"
  TwoColTx // "twoColTx"
  Tbl // "tbl"
  TxAndChart // "txAndChart"
  ChartAndTx // "chartAndTx"
  Diagram // "dgm"
  Chart // "chart"
  TxAndClipArt // "txAndClipArt"
  ClipArtAndTx // "clipArtAndTx"
  TitleOnly // "titleOnly"
  Blank // "blank"
  TxAndObj // "txAndObj"
  ObjAndTx // "objAndTx"
  ObjOnly // "objOnly"
  Object // "obj"
  TxAndMedia // "txAndMedia"
  MediaAndTx // "mediaAndTx"
  ObjOverTx // "objOverTx"
  TxOverObj // "txOverObj"
  TxAndTwoObj // "txAndTwoObj"
  TwoObjAndTx // "twoObjAndTx"
  TwoObjOverTx // "twoObjOverTx"
  FourObj // "fourObj"
  VertTx // "vertTx"
  ClipArtAndVertTx // "clipArtAndVertTx"
  VertTitleAndTx // "vertTitleAndTx"
  VertTitleAndTxOverChart // "vertTitleAndTxOverChart"
  TwoObj // "twoObj"
  ObjAndTwoObj // "objAndTwoObj"
  TwoObjAndObj // "twoObjAndObj"
  Custom // "cust"
  SecHead // "secHead"
  TwoTxTwoObj // "twoTxTwoObj"
  ObjTx // "objTx"
  PicTx // "picTx"
} derive(Eq, Debug)

///|
/// Convert a `ST_SlideLayoutType` attribute value to the typed enum.
pub fn SlideLayoutType::from_xml(
  s : String,
) -> SlideLayoutType raise SlideMasterError {
  match s {
    "title" => Title
    "tx" => Tx
    "twoColTx" => TwoColTx
    "tbl" => Tbl
    "txAndChart" => TxAndChart
    "chartAndTx" => ChartAndTx
    "dgm" => Diagram
    "chart" => Chart
    "txAndClipArt" => TxAndClipArt
    "clipArtAndTx" => ClipArtAndTx
    "titleOnly" => TitleOnly
    "blank" => Blank
    "txAndObj" => TxAndObj
    "objAndTx" => ObjAndTx
    "objOnly" => ObjOnly
    "obj" => Object
    "txAndMedia" => TxAndMedia
    "mediaAndTx" => MediaAndTx
    "objOverTx" => ObjOverTx
    "txOverObj" => TxOverObj
    "txAndTwoObj" => TxAndTwoObj
    "twoObjAndTx" => TwoObjAndTx
    "twoObjOverTx" => TwoObjOverTx
    "fourObj" => FourObj
    "vertTx" => VertTx
    "clipArtAndVertTx" => ClipArtAndVertTx
    "vertTitleAndTx" => VertTitleAndTx
    "vertTitleAndTxOverChart" => VertTitleAndTxOverChart
    "twoObj" => TwoObj
    "objAndTwoObj" => ObjAndTwoObj
    "twoObjAndObj" => TwoObjAndObj
    "cust" => Custom
    "secHead" => SecHead
    "twoTxTwoObj" => TwoTxTwoObj
    "objTx" => ObjTx
    "picTx" => PicTx
    _ => raise Malformed("unknown slide layout type: " + s)
  }
}

///|
/// Render a `SlideLayoutType` back to its `ST_SlideLayoutType` attribute
/// value. Inverse of `from_xml`.
pub fn SlideLayoutType::to_xml(self : SlideLayoutType) -> String {
  match self {
    Title => "title"
    Tx => "tx"
    TwoColTx => "twoColTx"
    Tbl => "tbl"
    TxAndChart => "txAndChart"
    ChartAndTx => "chartAndTx"
    Diagram => "dgm"
    Chart => "chart"
    TxAndClipArt => "txAndClipArt"
    ClipArtAndTx => "clipArtAndTx"
    TitleOnly => "titleOnly"
    Blank => "blank"
    TxAndObj => "txAndObj"
    ObjAndTx => "objAndTx"
    ObjOnly => "objOnly"
    Object => "obj"
    TxAndMedia => "txAndMedia"
    MediaAndTx => "mediaAndTx"
    ObjOverTx => "objOverTx"
    TxOverObj => "txOverObj"
    TxAndTwoObj => "txAndTwoObj"
    TwoObjAndTx => "twoObjAndTx"
    TwoObjOverTx => "twoObjOverTx"
    FourObj => "fourObj"
    VertTx => "vertTx"
    ClipArtAndVertTx => "clipArtAndVertTx"
    VertTitleAndTx => "vertTitleAndTx"
    VertTitleAndTxOverChart => "vertTitleAndTxOverChart"
    TwoObj => "twoObj"
    ObjAndTwoObj => "objAndTwoObj"
    TwoObjAndObj => "twoObjAndObj"
    Custom => "cust"
    SecHead => "secHead"
    TwoTxTwoObj => "twoTxTwoObj"
    ObjTx => "objTx"
    PicTx => "picTx"
  }
}

///|
/// Color-map override on a slide layout.
///
/// `MasterMapping` means "inherit the master's `clrMap` verbatim" (the
/// default). `Override(...)` supplies an explicit twelve-slot mapping that
/// replaces the master's mapping for slides using this layout.
pub(all) enum ClrMapOverride {
  MasterMapping
  Override(ColorMapping)
} derive(Eq, Debug)

///|
/// A parsed slide layout.
pub(all) struct SlideLayout {
  /// `name` from `<p:cSld name="…">`. May be empty if absent.
  name : String
  /// Layout type (`p:sldLayout/@type`); `Blank` is the spec default if the
  /// attribute is missing.
  layout_type : SlideLayoutType
  /// `<p:clrMapOvr>` resolution. Empty `<p:clrMapOvr>` is treated the same
  /// as an explicit `<a:masterClrMapping/>`.
  clr_map_override : ClrMapOverride
  /// Lossless preservation (ADR-004): unmodelled `<p:sldLayout>` children
  /// (`<p:cSld>` shape tree once it's pulled out of the name-only stub,
  /// `<p:transition>`, `<p:timing>`, `<p:hf>`, `<p:extLst>`, foreign-
  /// namespace siblings).
  extension : Array[@xml.XmlElement]
} derive(Eq, Debug)

///|
/// Parse a slide layout part from raw XML bytes.
pub fn SlideLayout::parse(
  bytes : FixedArray[Byte],
) -> SlideLayout raise SlideMasterError {
  parse_slide_layout_xml(bytes_to_string(bytes))
}

///|
fn parse_slide_layout_xml(xml : String) -> SlideLayout raise SlideMasterError {
  let r = @xml.XmlReader::new(xml)
  let event = next_event(r)
  let attrs = match event {
    StartElement(name, attrs) => {
      expect_pml(name, "sldLayout")
      attrs
    }
    _ => raise Malformed("expected <p:sldLayout> root element")
  }
  let layout_type = match optional_attr(attrs, "type") {
    "" => Blank
    s => SlideLayoutType::from_xml(s)
  }
  let mut name = ""
  // Default per ECMA-376: inherit the master's color map if `clrMapOvr`
  // is absent.
  let mut clr_map_override : ClrMapOverride = MasterMapping
  let extension : Array[@xml.XmlElement] = []
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, child_attrs) =>
        if child.uri != @oxml.presentation_ns {
          extension.push(collect_subtree_unknown(r, child, child_attrs))
        } else {
          match child.local_name {
            "cSld" => {
              // Layout-level <p:cSld> still has its full body — name out,
              // remainder onto extension so the shape tree round-trips.
              let (parsed_name, captured) = parse_cSld_for_name(
                r, child, child_attrs,
              )
              name = parsed_name
              extension.push(captured)
            }
            "clrMapOvr" => clr_map_override = parse_clr_map_ovr(r)
            // transition / timing / hf / extLst / etc.
            _ => extension.push(collect_subtree_unknown(r, child, child_attrs))
          }
        }
      EndElement(_) => break
      _ => ()
    }
  }
  { name, layout_type, clr_map_override, extension }
}

///|
/// Read the `name` attribute off `<p:cSld>` and capture its body into
/// an XmlElement so the writer re-emits the shape tree verbatim. A
/// typed layout shape-tree parser would replace this if needed.
fn parse_cSld_for_name(
  r : @xml.XmlReader,
  name : @xml.QName,
  attrs : Array[(@xml.QName, String)],
) -> (String, @xml.XmlElement) raise SlideMasterError {
  let cSld_name = optional_attr(attrs, "name")
  let captured = collect_subtree_unknown(r, name, attrs)
  (cSld_name, captured)
}

///|
/// Parse `<p:clrMapOvr>` body. Empty body or `<a:masterClrMapping/>` ⇒
/// `MasterMapping`; `<a:overrideClrMapping …/>` ⇒ `Override(...)`.
fn parse_clr_map_ovr(
  r : @xml.XmlReader,
) -> ClrMapOverride raise SlideMasterError {
  let mut result : ClrMapOverride = MasterMapping
  while true {
    let ev = next_event(r)
    match ev {
      StartElement(child, attrs) => {
        if child.uri == @oxml.drawing_ns &&
          child.local_name == "overrideClrMapping" {
          result = Override(parse_clr_map_attrs(attrs))
        }
        // `masterClrMapping` and any other child collapse to the default.
        skip_subtree(r)
      }
      EndElement(_) => break
      _ => ()
    }
  }
  result
}

///|
fn optional_attr(attrs : Array[(@xml.QName, String)], name : String) -> String {
  for kv in attrs {
    if kv.0.local_name == name && kv.0.uri == "" {
      return kv.1
    }
  }
  ""
}
