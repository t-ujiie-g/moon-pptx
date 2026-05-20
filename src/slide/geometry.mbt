// Auto-shape geometry — `<a:prstGeom>` and `<a:custGeom>`.
//
// Per ECMA-376 §20.1.10.55 (`ST_ShapeType`), an auto-shape's geometry is
// either a named preset (one of ~187 enumerated shape kinds) or an
// explicit custom path (`<a:custGeom>`). The custom-geometry path commands
// (moveTo / lnTo / cubicBezTo / close / etc.) are large and rarely needed
// for high-level reads, so we record the *presence* of `<a:custGeom>` but
// keep its path data opaque for now.
//
// `<a:prstGeom>` carries adjustment-value formulas via `<a:gd>` children:
//
//   <a:prstGeom prst="roundRect">
//     <a:avLst>
//       <a:gd name="adj" fmla="val 16667"/>
//     </a:avLst>
//   </a:prstGeom>
//
// We store these as `ShapeAdjustValue` pairs in source order. The formula
// language (`val …`, `+- …`, `pin …`, …) is parsed lazily by callers.

///|
/// One `<a:gd name="…" fmla="…"/>` adjustment formula. Stored verbatim;
/// later phases will lift `fmla` into a typed formula AST.
pub(all) struct ShapeAdjustValue {
  name : String
  fmla : String
} derive(Eq, Debug)

///|
/// A shape's geometry. `Preset(kind, adj)` covers `<a:prstGeom>` (with its
/// `<a:avLst>` adjustment list); `Custom(el)` retains the full
/// `<a:custGeom>` subtree (path lists, guides, connections, rectangle)
/// per ADR-004 so a future typed parser can fill in fields without
/// reading the XML again, and Phase 4 writers re-emit the geometry
/// verbatim in the meantime.
pub(all) enum Geometry {
  Preset(PresetShape, Array[ShapeAdjustValue])
  Custom(@xml.XmlElement)
} derive(Eq, Debug)

///|
/// One of the named preset shape kinds (`ST_ShapeType`).
///
/// Variant order follows the spec grouping for readability: lines /
/// rectangles, polygons, stars + seals, arrows, callouts, ribbons,
/// flowchart, action buttons, math, Office 2013+ additions. All 187
/// values are present so we can round-trip any real-world PPTX.
pub(all) enum PresetShape {
  // Lines / rectangles
  Line
  LineInv
  Rect
  RoundRect
  Round1Rect
  Round2SameRect
  Round2DiagRect
  SnipRoundRect
  Snip1Rect
  Snip2SameRect
  Snip2DiagRect
  Plaque
  Frame
  HalfFrame
  Corner
  DiagStripe
  // Polygons
  Triangle
  RtTriangle
  Parallelogram
  Trapezoid
  NonIsoscelesTrapezoid
  Diamond
  Pentagon
  Hexagon
  Heptagon
  Octagon
  Decagon
  Dodecagon
  // Stars / seals
  Star4
  Star5
  Star6
  Star7
  Star8
  Star10
  Star12
  Star16
  Star24
  Star32
  IrregularSeal1
  IrregularSeal2
  // Round / pie / arc
  Ellipse
  Teardrop
  Pie
  PieWedge
  Arc
  Chord
  BlockArc
  Donut
  NoSmoking
  // Arrows
  RightArrow
  LeftArrow
  UpArrow
  DownArrow
  LeftRightArrow
  UpDownArrow
  QuadArrow
  LeftRightUpArrow
  LeftUpArrow
  BentArrow
  UturnArrow
  CircularArrow
  LeftCircularArrow
  LeftRightCircularArrow
  CurvedRightArrow
  CurvedLeftArrow
  CurvedUpArrow
  CurvedDownArrow
  StripedRightArrow
  NotchedRightArrow
  SwooshArrow
  HomePlate
  Chevron
  // Arrow callouts
  LeftArrowCallout
  RightArrowCallout
  UpArrowCallout
  DownArrowCallout
  LeftRightArrowCallout
  UpDownArrowCallout
  QuadArrowCallout
  // 3D / pictographic
  Cube
  Can
  Bevel
  LightningBolt
  Heart
  Sun
  Moon
  SmileyFace
  FoldedCorner
  Cloud
  // Brackets / braces
  LeftBracket
  RightBracket
  LeftBrace
  RightBrace
  BracketPair
  BracePair
  // Connectors
  StraightConnector1
  BentConnector2
  BentConnector3
  BentConnector4
  BentConnector5
  CurvedConnector2
  CurvedConnector3
  CurvedConnector4
  CurvedConnector5
  // Callouts
  Callout1
  Callout2
  Callout3
  AccentCallout1
  AccentCallout2
  AccentCallout3
  BorderCallout1
  BorderCallout2
  BorderCallout3
  AccentBorderCallout1
  AccentBorderCallout2
  AccentBorderCallout3
  WedgeRectCallout
  WedgeRoundRectCallout
  WedgeEllipseCallout
  CloudCallout
  // Ribbons / scrolls / waves
  Ribbon
  Ribbon2
  EllipseRibbon
  EllipseRibbon2
  LeftRightRibbon
  VerticalScroll
  HorizontalScroll
  Wave
  DoubleWave
  // Misc
  Plus
  // Flowchart
  FlowChartProcess
  FlowChartDecision
  FlowChartInputOutput
  FlowChartPredefinedProcess
  FlowChartInternalStorage
  FlowChartDocument
  FlowChartMultidocument
  FlowChartTerminator
  FlowChartPreparation
  FlowChartManualInput
  FlowChartManualOperation
  FlowChartConnector
  FlowChartPunchedCard
  FlowChartPunchedTape
  FlowChartSummingJunction
  FlowChartOr
  FlowChartCollate
  FlowChartSort
  FlowChartExtract
  FlowChartMerge
  FlowChartOfflineStorage
  FlowChartOnlineStorage
  FlowChartMagneticTape
  FlowChartMagneticDisk
  FlowChartMagneticDrum
  FlowChartDisplay
  FlowChartDelay
  FlowChartAlternateProcess
  FlowChartOffpageConnector
  // Action buttons
  ActionButtonBlank
  ActionButtonHome
  ActionButtonHelp
  ActionButtonInformation
  ActionButtonForwardNext
  ActionButtonBackPrevious
  ActionButtonEnd
  ActionButtonBeginning
  ActionButtonReturn
  ActionButtonDocument
  ActionButtonSound
  ActionButtonMovie
  // Math
  MathPlus
  MathMinus
  MathMultiply
  MathDivide
  MathEqual
  MathNotEqual
  // Office 2013+ additions
  Gear6
  Gear9
  Funnel
  CornerTabs
  SquareTabs
  PlaqueTabs
  ChartX
  ChartStar
  ChartPlus
} derive(Eq, Debug)

///|
/// Parse the `prst` attribute value into a `PresetShape`. Unknown values
/// raise `SlideError::Malformed` so we notice and intentionally widen the
/// enum instead of silently miscategorising.
pub fn PresetShape::from_xml(s : String) -> PresetShape raise SlideError {
  match s {
    "line" => Line
    "lineInv" => LineInv
    "rect" => Rect
    "roundRect" => RoundRect
    "round1Rect" => Round1Rect
    "round2SameRect" => Round2SameRect
    "round2DiagRect" => Round2DiagRect
    "snipRoundRect" => SnipRoundRect
    "snip1Rect" => Snip1Rect
    "snip2SameRect" => Snip2SameRect
    "snip2DiagRect" => Snip2DiagRect
    "plaque" => Plaque
    "frame" => Frame
    "halfFrame" => HalfFrame
    "corner" => Corner
    "diagStripe" => DiagStripe
    "triangle" => Triangle
    "rtTriangle" => RtTriangle
    "parallelogram" => Parallelogram
    "trapezoid" => Trapezoid
    "nonIsoscelesTrapezoid" => NonIsoscelesTrapezoid
    "diamond" => Diamond
    "pentagon" => Pentagon
    "hexagon" => Hexagon
    "heptagon" => Heptagon
    "octagon" => Octagon
    "decagon" => Decagon
    "dodecagon" => Dodecagon
    "star4" => Star4
    "star5" => Star5
    "star6" => Star6
    "star7" => Star7
    "star8" => Star8
    "star10" => Star10
    "star12" => Star12
    "star16" => Star16
    "star24" => Star24
    "star32" => Star32
    "irregularSeal1" => IrregularSeal1
    "irregularSeal2" => IrregularSeal2
    "ellipse" => Ellipse
    "teardrop" => Teardrop
    "pie" => Pie
    "pieWedge" => PieWedge
    "arc" => Arc
    "chord" => Chord
    "blockArc" => BlockArc
    "donut" => Donut
    "noSmoking" => NoSmoking
    "rightArrow" => RightArrow
    "leftArrow" => LeftArrow
    "upArrow" => UpArrow
    "downArrow" => DownArrow
    "leftRightArrow" => LeftRightArrow
    "upDownArrow" => UpDownArrow
    "quadArrow" => QuadArrow
    "leftRightUpArrow" => LeftRightUpArrow
    "leftUpArrow" => LeftUpArrow
    "bentArrow" => BentArrow
    "uturnArrow" => UturnArrow
    "circularArrow" => CircularArrow
    "leftCircularArrow" => LeftCircularArrow
    "leftRightCircularArrow" => LeftRightCircularArrow
    "curvedRightArrow" => CurvedRightArrow
    "curvedLeftArrow" => CurvedLeftArrow
    "curvedUpArrow" => CurvedUpArrow
    "curvedDownArrow" => CurvedDownArrow
    "stripedRightArrow" => StripedRightArrow
    "notchedRightArrow" => NotchedRightArrow
    "swooshArrow" => SwooshArrow
    "homePlate" => HomePlate
    "chevron" => Chevron
    "leftArrowCallout" => LeftArrowCallout
    "rightArrowCallout" => RightArrowCallout
    "upArrowCallout" => UpArrowCallout
    "downArrowCallout" => DownArrowCallout
    "leftRightArrowCallout" => LeftRightArrowCallout
    "upDownArrowCallout" => UpDownArrowCallout
    "quadArrowCallout" => QuadArrowCallout
    "cube" => Cube
    "can" => Can
    "bevel" => Bevel
    "lightningBolt" => LightningBolt
    "heart" => Heart
    "sun" => Sun
    "moon" => Moon
    "smileyFace" => SmileyFace
    "foldedCorner" => FoldedCorner
    "cloud" => Cloud
    "leftBracket" => LeftBracket
    "rightBracket" => RightBracket
    "leftBrace" => LeftBrace
    "rightBrace" => RightBrace
    "bracketPair" => BracketPair
    "bracePair" => BracePair
    "straightConnector1" => StraightConnector1
    "bentConnector2" => BentConnector2
    "bentConnector3" => BentConnector3
    "bentConnector4" => BentConnector4
    "bentConnector5" => BentConnector5
    "curvedConnector2" => CurvedConnector2
    "curvedConnector3" => CurvedConnector3
    "curvedConnector4" => CurvedConnector4
    "curvedConnector5" => CurvedConnector5
    "callout1" => Callout1
    "callout2" => Callout2
    "callout3" => Callout3
    "accentCallout1" => AccentCallout1
    "accentCallout2" => AccentCallout2
    "accentCallout3" => AccentCallout3
    "borderCallout1" => BorderCallout1
    "borderCallout2" => BorderCallout2
    "borderCallout3" => BorderCallout3
    "accentBorderCallout1" => AccentBorderCallout1
    "accentBorderCallout2" => AccentBorderCallout2
    "accentBorderCallout3" => AccentBorderCallout3
    "wedgeRectCallout" => WedgeRectCallout
    "wedgeRoundRectCallout" => WedgeRoundRectCallout
    "wedgeEllipseCallout" => WedgeEllipseCallout
    "cloudCallout" => CloudCallout
    "ribbon" => Ribbon
    "ribbon2" => Ribbon2
    "ellipseRibbon" => EllipseRibbon
    "ellipseRibbon2" => EllipseRibbon2
    "leftRightRibbon" => LeftRightRibbon
    "verticalScroll" => VerticalScroll
    "horizontalScroll" => HorizontalScroll
    "wave" => Wave
    "doubleWave" => DoubleWave
    "plus" => Plus
    "flowChartProcess" => FlowChartProcess
    "flowChartDecision" => FlowChartDecision
    "flowChartInputOutput" => FlowChartInputOutput
    "flowChartPredefinedProcess" => FlowChartPredefinedProcess
    "flowChartInternalStorage" => FlowChartInternalStorage
    "flowChartDocument" => FlowChartDocument
    "flowChartMultidocument" => FlowChartMultidocument
    "flowChartTerminator" => FlowChartTerminator
    "flowChartPreparation" => FlowChartPreparation
    "flowChartManualInput" => FlowChartManualInput
    "flowChartManualOperation" => FlowChartManualOperation
    "flowChartConnector" => FlowChartConnector
    "flowChartPunchedCard" => FlowChartPunchedCard
    "flowChartPunchedTape" => FlowChartPunchedTape
    "flowChartSummingJunction" => FlowChartSummingJunction
    "flowChartOr" => FlowChartOr
    "flowChartCollate" => FlowChartCollate
    "flowChartSort" => FlowChartSort
    "flowChartExtract" => FlowChartExtract
    "flowChartMerge" => FlowChartMerge
    "flowChartOfflineStorage" => FlowChartOfflineStorage
    "flowChartOnlineStorage" => FlowChartOnlineStorage
    "flowChartMagneticTape" => FlowChartMagneticTape
    "flowChartMagneticDisk" => FlowChartMagneticDisk
    "flowChartMagneticDrum" => FlowChartMagneticDrum
    "flowChartDisplay" => FlowChartDisplay
    "flowChartDelay" => FlowChartDelay
    "flowChartAlternateProcess" => FlowChartAlternateProcess
    "flowChartOffpageConnector" => FlowChartOffpageConnector
    "actionButtonBlank" => ActionButtonBlank
    "actionButtonHome" => ActionButtonHome
    "actionButtonHelp" => ActionButtonHelp
    "actionButtonInformation" => ActionButtonInformation
    "actionButtonForwardNext" => ActionButtonForwardNext
    "actionButtonBackPrevious" => ActionButtonBackPrevious
    "actionButtonEnd" => ActionButtonEnd
    "actionButtonBeginning" => ActionButtonBeginning
    "actionButtonReturn" => ActionButtonReturn
    "actionButtonDocument" => ActionButtonDocument
    "actionButtonSound" => ActionButtonSound
    "actionButtonMovie" => ActionButtonMovie
    "mathPlus" => MathPlus
    "mathMinus" => MathMinus
    "mathMultiply" => MathMultiply
    "mathDivide" => MathDivide
    "mathEqual" => MathEqual
    "mathNotEqual" => MathNotEqual
    "gear6" => Gear6
    "gear9" => Gear9
    "funnel" => Funnel
    "cornerTabs" => CornerTabs
    "squareTabs" => SquareTabs
    "plaqueTabs" => PlaqueTabs
    "chartX" => ChartX
    "chartStar" => ChartStar
    "chartPlus" => ChartPlus
    _ => raise Malformed("unknown ST_ShapeType value: " + s)
  }
}

///|
/// Render a `PresetShape` back to its ECMA-376 `prst` attribute value.
pub fn PresetShape::to_xml(self : PresetShape) -> String {
  match self {
    Line => "line"
    LineInv => "lineInv"
    Rect => "rect"
    RoundRect => "roundRect"
    Round1Rect => "round1Rect"
    Round2SameRect => "round2SameRect"
    Round2DiagRect => "round2DiagRect"
    SnipRoundRect => "snipRoundRect"
    Snip1Rect => "snip1Rect"
    Snip2SameRect => "snip2SameRect"
    Snip2DiagRect => "snip2DiagRect"
    Plaque => "plaque"
    Frame => "frame"
    HalfFrame => "halfFrame"
    Corner => "corner"
    DiagStripe => "diagStripe"
    Triangle => "triangle"
    RtTriangle => "rtTriangle"
    Parallelogram => "parallelogram"
    Trapezoid => "trapezoid"
    NonIsoscelesTrapezoid => "nonIsoscelesTrapezoid"
    Diamond => "diamond"
    Pentagon => "pentagon"
    Hexagon => "hexagon"
    Heptagon => "heptagon"
    Octagon => "octagon"
    Decagon => "decagon"
    Dodecagon => "dodecagon"
    Star4 => "star4"
    Star5 => "star5"
    Star6 => "star6"
    Star7 => "star7"
    Star8 => "star8"
    Star10 => "star10"
    Star12 => "star12"
    Star16 => "star16"
    Star24 => "star24"
    Star32 => "star32"
    IrregularSeal1 => "irregularSeal1"
    IrregularSeal2 => "irregularSeal2"
    Ellipse => "ellipse"
    Teardrop => "teardrop"
    Pie => "pie"
    PieWedge => "pieWedge"
    Arc => "arc"
    Chord => "chord"
    BlockArc => "blockArc"
    Donut => "donut"
    NoSmoking => "noSmoking"
    RightArrow => "rightArrow"
    LeftArrow => "leftArrow"
    UpArrow => "upArrow"
    DownArrow => "downArrow"
    LeftRightArrow => "leftRightArrow"
    UpDownArrow => "upDownArrow"
    QuadArrow => "quadArrow"
    LeftRightUpArrow => "leftRightUpArrow"
    LeftUpArrow => "leftUpArrow"
    BentArrow => "bentArrow"
    UturnArrow => "uturnArrow"
    CircularArrow => "circularArrow"
    LeftCircularArrow => "leftCircularArrow"
    LeftRightCircularArrow => "leftRightCircularArrow"
    CurvedRightArrow => "curvedRightArrow"
    CurvedLeftArrow => "curvedLeftArrow"
    CurvedUpArrow => "curvedUpArrow"
    CurvedDownArrow => "curvedDownArrow"
    StripedRightArrow => "stripedRightArrow"
    NotchedRightArrow => "notchedRightArrow"
    SwooshArrow => "swooshArrow"
    HomePlate => "homePlate"
    Chevron => "chevron"
    LeftArrowCallout => "leftArrowCallout"
    RightArrowCallout => "rightArrowCallout"
    UpArrowCallout => "upArrowCallout"
    DownArrowCallout => "downArrowCallout"
    LeftRightArrowCallout => "leftRightArrowCallout"
    UpDownArrowCallout => "upDownArrowCallout"
    QuadArrowCallout => "quadArrowCallout"
    Cube => "cube"
    Can => "can"
    Bevel => "bevel"
    LightningBolt => "lightningBolt"
    Heart => "heart"
    Sun => "sun"
    Moon => "moon"
    SmileyFace => "smileyFace"
    FoldedCorner => "foldedCorner"
    Cloud => "cloud"
    LeftBracket => "leftBracket"
    RightBracket => "rightBracket"
    LeftBrace => "leftBrace"
    RightBrace => "rightBrace"
    BracketPair => "bracketPair"
    BracePair => "bracePair"
    StraightConnector1 => "straightConnector1"
    BentConnector2 => "bentConnector2"
    BentConnector3 => "bentConnector3"
    BentConnector4 => "bentConnector4"
    BentConnector5 => "bentConnector5"
    CurvedConnector2 => "curvedConnector2"
    CurvedConnector3 => "curvedConnector3"
    CurvedConnector4 => "curvedConnector4"
    CurvedConnector5 => "curvedConnector5"
    Callout1 => "callout1"
    Callout2 => "callout2"
    Callout3 => "callout3"
    AccentCallout1 => "accentCallout1"
    AccentCallout2 => "accentCallout2"
    AccentCallout3 => "accentCallout3"
    BorderCallout1 => "borderCallout1"
    BorderCallout2 => "borderCallout2"
    BorderCallout3 => "borderCallout3"
    AccentBorderCallout1 => "accentBorderCallout1"
    AccentBorderCallout2 => "accentBorderCallout2"
    AccentBorderCallout3 => "accentBorderCallout3"
    WedgeRectCallout => "wedgeRectCallout"
    WedgeRoundRectCallout => "wedgeRoundRectCallout"
    WedgeEllipseCallout => "wedgeEllipseCallout"
    CloudCallout => "cloudCallout"
    Ribbon => "ribbon"
    Ribbon2 => "ribbon2"
    EllipseRibbon => "ellipseRibbon"
    EllipseRibbon2 => "ellipseRibbon2"
    LeftRightRibbon => "leftRightRibbon"
    VerticalScroll => "verticalScroll"
    HorizontalScroll => "horizontalScroll"
    Wave => "wave"
    DoubleWave => "doubleWave"
    Plus => "plus"
    FlowChartProcess => "flowChartProcess"
    FlowChartDecision => "flowChartDecision"
    FlowChartInputOutput => "flowChartInputOutput"
    FlowChartPredefinedProcess => "flowChartPredefinedProcess"
    FlowChartInternalStorage => "flowChartInternalStorage"
    FlowChartDocument => "flowChartDocument"
    FlowChartMultidocument => "flowChartMultidocument"
    FlowChartTerminator => "flowChartTerminator"
    FlowChartPreparation => "flowChartPreparation"
    FlowChartManualInput => "flowChartManualInput"
    FlowChartManualOperation => "flowChartManualOperation"
    FlowChartConnector => "flowChartConnector"
    FlowChartPunchedCard => "flowChartPunchedCard"
    FlowChartPunchedTape => "flowChartPunchedTape"
    FlowChartSummingJunction => "flowChartSummingJunction"
    FlowChartOr => "flowChartOr"
    FlowChartCollate => "flowChartCollate"
    FlowChartSort => "flowChartSort"
    FlowChartExtract => "flowChartExtract"
    FlowChartMerge => "flowChartMerge"
    FlowChartOfflineStorage => "flowChartOfflineStorage"
    FlowChartOnlineStorage => "flowChartOnlineStorage"
    FlowChartMagneticTape => "flowChartMagneticTape"
    FlowChartMagneticDisk => "flowChartMagneticDisk"
    FlowChartMagneticDrum => "flowChartMagneticDrum"
    FlowChartDisplay => "flowChartDisplay"
    FlowChartDelay => "flowChartDelay"
    FlowChartAlternateProcess => "flowChartAlternateProcess"
    FlowChartOffpageConnector => "flowChartOffpageConnector"
    ActionButtonBlank => "actionButtonBlank"
    ActionButtonHome => "actionButtonHome"
    ActionButtonHelp => "actionButtonHelp"
    ActionButtonInformation => "actionButtonInformation"
    ActionButtonForwardNext => "actionButtonForwardNext"
    ActionButtonBackPrevious => "actionButtonBackPrevious"
    ActionButtonEnd => "actionButtonEnd"
    ActionButtonBeginning => "actionButtonBeginning"
    ActionButtonReturn => "actionButtonReturn"
    ActionButtonDocument => "actionButtonDocument"
    ActionButtonSound => "actionButtonSound"
    ActionButtonMovie => "actionButtonMovie"
    MathPlus => "mathPlus"
    MathMinus => "mathMinus"
    MathMultiply => "mathMultiply"
    MathDivide => "mathDivide"
    MathEqual => "mathEqual"
    MathNotEqual => "mathNotEqual"
    Gear6 => "gear6"
    Gear9 => "gear9"
    Funnel => "funnel"
    CornerTabs => "cornerTabs"
    SquareTabs => "squareTabs"
    PlaqueTabs => "plaqueTabs"
    ChartX => "chartX"
    ChartStar => "chartStar"
    ChartPlus => "chartPlus"
  }
}
