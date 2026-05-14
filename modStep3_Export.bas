Attribute VB_Name = "modStep3_Export"
Option Explicit
' Step 3: Export charts/ranges/text from Excel to PowerPoint (Adaptive Placement)
'
' Config sheet "ExportConfig" columns A:H:
'   A=ShapeName  B=SlideIdx  C=SourceType  D=SourceRef
'   E=DefaultLeft  F=DefaultTop  G=DefaultWidth  H=DefaultHeight  (points)
'   RangeTable part sizing lives in ExportConfig J:M blocks.
'
' SourceType:
'   GroupImage  - paste named charts as one grouped PPT shape
'                 SourceRef = pipe-separated chart names: "Chart 1|Chart 2|Chart 3|Chart 138"
'   ChartImage  - export single chart as PNG image
'                 SourceRef = chart name: "Chart 1"
'   RangeImage  - CopyPicture of a cell range (captures overlapping objects)
'                 SourceRef = range address: "A1:Z10"
'   RangeTable  - paste range as editable PPT table (HTML paste)
'                 SourceRef = range address: "A1:Z10"
'   Text        - plain text box, SourceRef = literal text or "=CellRef"
'
' Table part config blocks live in ExportConfig columns J:M:
'   Header row: PartXRange | PartXCellWidthPt | PartXCellHeightPt | PartXFontSizePt
'   Value row : range      | width points     | height points      | font size points
'   SourceRef still defines the full table range to paste.
'
' Adaptive: if a shape with the same name already exists on the target slide,
'           its current position (Left/Top/Width/Height) overrides the config defaults.
'           This means you can drag shapes in PPT once, and re-runs will respect
'           your custom placement.

Private Type ExportItem
    shapeName   As String
    slideIdx    As Long
    SourceType  As String
    sourceRef   As String
    Left        As Double
    Top         As Double
    Width       As Double
    Height      As Double
    IsAnchor    As Boolean   ' True = first GroupImage on its slide (anchor for auto-arrange)
    WasAdapted  As Boolean   ' True = position was read from existing PPT shape
End Type

' PPT slide assumed 16:9 widescreen = 914.4 x 514.4 pt (33.867cm x 19.05cm)
' Positions below are reasonable defaults — tweak via ExportConfig sheet or drag-in-PPT.

' =============================================================================
Public Sub SetupExportConfig()
' =============================================================================
' Create/reset sheet "ExportConfig" with defaults matching the 4-group layout.
' Edit SourceRef column to use your actual chart names.
    Const SH_NAME As String = "ExportConfig"

    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Sheets(SH_NAME)
    On Error GoTo 0

    If ws Is Nothing Then
        Set ws = ThisWorkbook.Sheets.Add(After:=ThisWorkbook.Sheets(ThisWorkbook.Sheets.Count))
        ws.Name = SH_NAME
    Else
        ws.Cells.Clear
    End If

    ' --- Header ---
    Dim hdr As Variant
    hdr = Array("ShapeName", "SlideIdx", "SourceType", "SourceRef", _
                "DefaultLeft", "DefaultTop", "DefaultWidth", "DefaultHeight")
    Dim c As Long
    For c = 0 To UBound(hdr)
        ws.Cells(1, c + 1).Value = hdr(c)
    Next c
    ws.Rows(1).Font.Bold = True

    ' --- Data table (bảng số liệu) ---
    ' Adjust range address to match actual table on Sheet1
    WriteRow ws, 2, "XL_DataTable", 1, "RangeTable", "AD7:AY12", _
             20, 15, 874, 72
    WriteTablePartConfig ws

    ' --- 5 chart groups ---
    ' *** For GroupImage: only XL_Group1 needs Left/Top/Width — Height = 0 means auto from aspect ratio ***
    ' *** Groups 2-5: Left auto-calculated, Height inherited, Width preserves each group's aspect ratio ***
    ' *** Edit SourceRef to match your actual chart names (pipe-separated) ***
    WriteRow ws, 3, "XL_Group1", 1, "GroupImage", "Chart 1|Chart 2|Chart 3|Chart 100", _
             0, 95, 210, 0     ' <-- set Left / Top / Width here; Height=0 = auto

    WriteRow ws, 4, "XL_Group2", 1, "GroupImage", "Chart 5|Chart 6|Chart 7|Chart 101", _
             0, 0, 0, 0        ' <-- auto-arranged, values ignored

    WriteRow ws, 5, "XL_Group3", 1, "GroupImage", "Chart 9|Chart 10|Chart 11|Chart 102", _
             0, 0, 0, 0

    WriteRow ws, 6, "XL_Group4", 1, "GroupImage", "Chart 13|Chart 14|Chart 15|Chart 103", _
             0, 0, 0, 0

    WriteRow ws, 7, "XL_Group5", 1, "GroupImage", "Chart 16|Chart 17|Chart 18|Chart 104", _
             0, 0, 0, 0

    WriteStep2ScoreRangeConfig ws

    ws.Columns("A:M").AutoFit
    ' Add a comment to the anchor row to guide the user
    ws.Cells(3, 5).AddComment "Set Left/Top/Width for Group1 here. Height=0 = auto aspect ratio."
    ws.Cells(1, 10).AddComment "RangeTable part sizing. SourceRef is the full pasted table range; J:M blocks define subrange width/height/font."
    Debug.Print "SetupExportConfig: done. Edit col D (SourceRef) and J:M table part config, then run ExportToPPT."
End Sub

' =============================================================================
Public Sub UpdateExportConfigTableSettings()
' =============================================================================
' Non-destructive update for the existing ExportConfig sheet:
'   - XL_DataTable SourceRef becomes AD7:AY12
'   - Adds/refreshes J:M table part config
    Const CONFIG_SHEET As String = "ExportConfig"
    Const DATA_TABLE_SHAPE As String = "XL_DataTable"
    Const DATA_TABLE_RANGE As String = "AD7:AY12"

    On Error GoTo CleanFail

    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets(CONFIG_SHEET)

    UpdateSourceRefByShapeName ws, DATA_TABLE_SHAPE, DATA_TABLE_RANGE
    EnsureGroupImageRow ws, "XL_Group2", 1, "Chart 5|Chart 6|Chart 7|Chart 101"
    EnsureGroupImageRow ws, "XL_Group3", 1, "Chart 9|Chart 10|Chart 11|Chart 102"
    EnsureGroupImageRow ws, "XL_Group4", 1, "Chart 13|Chart 14|Chart 15|Chart 103"
    EnsureGroupImageRow ws, "XL_Group5", 1, "Chart 16|Chart 17|Chart 18|Chart 104"
    WriteTablePartConfig ws
    WriteStep2ScoreRangeConfig ws

    ws.Columns("A:M").AutoFit
    Debug.Print "UpdateExportConfigTableSettings: " & DATA_TABLE_SHAPE & _
                " SourceRef=" & DATA_TABLE_RANGE & ", table part config written to J:M."
    Exit Sub

CleanFail:
    Debug.Print "UpdateExportConfigTableSettings ERROR " & Err.Number & ": " & Err.Description
End Sub

' =============================================================================
Public Sub ExportToPPT()
' =============================================================================
    Const CONFIG_SHEET As String = "ExportConfig"
    Const PPTX_NAME    As String = "PresTest.pptx"
    Const DATA_SHEET   As String = "Sheet1"

    On Error GoTo CleanFail

    Dim cfgWs As Worksheet
    Set cfgWs = ThisWorkbook.Sheets(CONFIG_SHEET)

    Dim dataWs As Worksheet
    Set dataWs = ThisWorkbook.Sheets(DATA_SHEET)

    Dim items() As ExportItem
    Dim n As Long
    n = ReadConfig(cfgWs, items)
    If n = 0 Then
        Debug.Print "ExportToPPT: ExportConfig has no data rows."
        Exit Sub
    End If

    Dim pptApp As Object
    Dim pres   As Object
    OpenPresentation pptApp, pres, PPTX_NAME

    ' --- Phase 1: mark anchor groups + adaptive override ---
    Dim i As Long
    MarkGroupAnchors items, n
    For i = 1 To n
        If ShouldAdaptPosition(items(i)) Then AdaptPosition pres, items(i)
    Next i

    ' --- Phase 2: auto-arrange GroupImage items (aspect ratio + no gap) ---
    ArrangeGroupImages dataWs, items, n

    ' --- Phase 3: export ---
    For i = 1 To n
        ExportOneItem pres, items(i), dataWs, cfgWs
    Next i

    pres.Save
    Debug.Print "ExportToPPT: done. " & n & " items exported to " & PPTX_NAME
    Exit Sub

CleanFail:
    Debug.Print "ExportToPPT ERROR " & Err.Number & ": " & Err.Description
End Sub

Private Function ShouldAdaptPosition(ByRef item As ExportItem) As Boolean
    If LCase$(item.SourceType) = "groupimage" Then
        ShouldAdaptPosition = item.IsAnchor
    Else
        ShouldAdaptPosition = True
    End If
End Function

' =============================================================================
' MarkGroupAnchors: first GroupImage per slide = anchor (controls Left/Top/Width)
' =============================================================================
Private Sub MarkGroupAnchors(ByRef items() As ExportItem, ByVal n As Long)
    ' Track which slides have already seen a GroupImage
    Dim seenSlides(1 To 100) As Boolean   ' max 100 slides
    Dim i As Long
    For i = 1 To n
        If LCase$(items(i).SourceType) = "groupimage" Then
            Dim s As Long: s = items(i).slideIdx
            If s >= 1 And s <= 100 Then
                If Not seenSlides(s) Then
                    items(i).IsAnchor = True
                    seenSlides(s) = True
                End If
            End If
        End If
    Next i
End Sub

' =============================================================================
' ArrangeGroupImages:
'   - Computes Height = Width * (bbH/bbW) to preserve aspect ratio
'   - Groups 2-N on each slide: Left = prev.Right (no gap), inherit Top/Height,
'     compute Width from each group's own aspect ratio
' =============================================================================
Private Sub ArrangeGroupImages(ByVal ws As Worksheet, _
                                ByRef items() As ExportItem, ByVal n As Long)
    ' Store anchor info per slide (Left, Top, Width, Height)
    Dim ancL(1 To 100) As Double, ancT(1 To 100) As Double
    Dim ancW(1 To 100) As Double, ancH(1 To 100) As Double
    Dim ancRight(1 To 100) As Double   ' running right edge for next group

    Dim i As Long
    For i = 1 To n
        If LCase$(items(i).SourceType) <> "groupimage" Then GoTo NextItem
        Dim s As Long: s = items(i).slideIdx
        If s < 1 Or s > 100 Then GoTo NextItem

        If items(i).IsAnchor Then
            ' Compute true aspect ratio (bbWidth/bbHeight) from chart bounding box
            Dim bbW As Double, bbH As Double
            GetGroupBBox ws, items(i).sourceRef, bbW, bbH

            Dim ratio As Double
            ratio = IIf(bbH > 0, bbW / bbH, 1)

            ' Width comes from config on first export, or from existing PPT XL_Group1
            ' after adaptive positioning. Height is recomputed from the real bbox ratio
            ' so the exported image always keeps aspect ratio.
            ancW(s) = items(i).Width
            ancH(s) = IIf(ratio > 0, ancW(s) / ratio, items(i).Height)
            ancL(s) = items(i).Left
            ancT(s) = items(i).Top

            items(i).Height = ancH(s)
            ancRight(s) = ancL(s) + ancW(s)

            Debug.Print "  Anchor [" & items(i).shapeName & "] " & _
                        "bbox=" & Format(bbW, "0") & "x" & Format(bbH, "0") & _
                        " -> ppt " & Format(ancW(s), "0") & "x" & Format(ancH(s), "0.0")
        Else
            ' Non-anchor: inherit height from anchor, preserve this group's own aspect ratio,
            ' then place immediately to the right.
            GetGroupBBox ws, items(i).sourceRef, bbW, bbH
            ratio = IIf(bbH > 0, bbW / bbH, 1)

            items(i).Left = ancRight(s)
            items(i).Top = ancT(s)
            items(i).Width = IIf(ratio > 0, ancH(s) * ratio, ancW(s))
            items(i).Height = ancH(s)
            ancRight(s) = ancRight(s) + items(i).Width

            Debug.Print "  Group  [" & items(i).shapeName & "] " & _
                        "bbox=" & Format(bbW, "0") & "x" & Format(bbH, "0") & _
                        " -> ppt " & Format(items(i).Width, "0") & "x" & Format(items(i).Height, "0.0")
        End If
NextItem:
    Next i
End Sub

' =============================================================================
' GetGroupBBox: compute bounding box dimensions (pts) of pipe-separated charts
' =============================================================================
Private Sub GetGroupBBox(ByVal ws As Worksheet, ByVal sourceRef As String, _
                          ByRef bbWidth As Double, ByRef bbHeight As Double)
    Dim names() As String
    names = Split(sourceRef, "|")

    Dim bbLeft As Double, bbTop As Double
    Dim bbRight As Double, bbBottom As Double
    bbLeft = 1E+15: bbTop = 1E+15: bbRight = 0: bbBottom = 0

    Dim k As Long
    For k = LBound(names) To UBound(names)
        Dim cName As String: cName = Trim$(names(k))
        If Len(cName) = 0 Then GoTo NextN
        Dim co As chartObject
        On Error Resume Next
        Set co = ws.chartObjects(cName)
        On Error GoTo 0
        If co Is Nothing Then GoTo NextN
        If co.Left < bbLeft Then bbLeft = co.Left
        If co.Top < bbTop Then bbTop = co.Top
        If co.Left + co.Width > bbRight Then bbRight = co.Left + co.Width
        If co.Top + co.Height > bbBottom Then bbBottom = co.Top + co.Height
        Set co = Nothing
NextN:
    Next k

    bbWidth = IIf(bbRight > bbLeft, bbRight - bbLeft, 1)
    bbHeight = IIf(bbBottom > bbTop, bbBottom - bbTop, 1)
End Sub

' =============================================================================
' INTERNAL: config reader
' =============================================================================
Private Function ReadConfig(ByVal ws As Worksheet, ByRef items() As ExportItem) As Long
    Dim cnt As Long: cnt = 0
    Dim r As Long:   r = 2
    Do While Len(Trim$(ws.Cells(r, 1).Value)) > 0
        cnt = cnt + 1: r = r + 1
    Loop
    If cnt = 0 Then ReadConfig = 0: Exit Function

    ReDim items(1 To cnt)
    Dim idx As Long
    For idx = 1 To cnt
        With items(idx)
            .shapeName = Trim$(ws.Cells(idx + 1, 1).Value)
            .slideIdx = CLng(ws.Cells(idx + 1, 2).Value)
            .SourceType = Trim$(ws.Cells(idx + 1, 3).Value)
            .sourceRef = Trim$(ws.Cells(idx + 1, 4).Value)
            .Left = CDbl(ws.Cells(idx + 1, 5).Value)
            .Top = CDbl(ws.Cells(idx + 1, 6).Value)
            .Width = CDbl(ws.Cells(idx + 1, 7).Value)
            .Height = CDbl(ws.Cells(idx + 1, 8).Value)
        End With
    Next idx

    ReadConfig = cnt
End Function

' =============================================================================
' INTERNAL: PowerPoint connection
' =============================================================================
Private Sub OpenPresentation(ByRef pptApp As Object, ByRef pres As Object, _
                              ByVal pptxName As String)
    Dim pptxPath As String
    pptxPath = ThisWorkbook.Path & "\" & pptxName

    On Error Resume Next
    Set pptApp = GetObject(, "PowerPoint.Application")
    On Error GoTo 0

    If pptApp Is Nothing Then
        Set pptApp = CreateObject("PowerPoint.Application")
        pptApp.Visible = True
    End If

    Dim p As Object
    For Each p In pptApp.Presentations
        If StrComp(p.Name, pptxName, vbTextCompare) = 0 Then
            Set pres = p: Exit Sub
        End If
    Next p
    Set pres = pptApp.Presentations.Open(pptxPath)
End Sub

' =============================================================================
' INTERNAL: adaptive position — read existing shape position from PPT
' =============================================================================
Private Sub AdaptPosition(ByVal pres As Object, ByRef item As ExportItem)
    If item.slideIdx < 1 Or item.slideIdx > pres.Slides.Count Then Exit Sub
    Dim shp As Object
    Set shp = FindShapeByName(pres.Slides(item.slideIdx), item.shapeName)
    If shp Is Nothing Then Exit Sub

    item.Left = shp.Left
    item.Top = shp.Top
    item.Width = shp.Width
    item.Height = shp.Height
    Debug.Print "  Adapt [" & item.shapeName & "] L=" & shp.Left & _
                " T=" & shp.Top & " W=" & shp.Width & " H=" & shp.Height
End Sub

' =============================================================================
' INTERNAL: dispatch one export item
' =============================================================================
Private Sub ExportOneItem(ByVal pres As Object, ByRef item As ExportItem, _
                           ByVal dataWs As Worksheet, ByVal cfgWs As Worksheet)
    On Error GoTo CleanFail

    If item.slideIdx < 1 Or item.slideIdx > pres.Slides.Count Then
        Debug.Print "  SKIP [" & item.shapeName & "]: slide " & item.slideIdx & " out of range"
        Exit Sub
    End If
    Dim sld As Object
    Set sld = pres.Slides(item.slideIdx)

    If LCase$(item.SourceType) = "rangetable" Then
        If Not IsRangeTableConfigValid(cfgWs, dataWs, item) Then Exit Sub
    End If
    DeleteShapesByPrefix sld, item.shapeName & "_part_"
    DeleteShapesByPrefix sld, item.shapeName & "_new_"
    DeleteShapesByPrefix sld, item.shapeName & "_label_"
    DeleteShapesByPrefix sld, item.shapeName & "_model_"

    Dim newShp As Object
    Select Case LCase$(item.SourceType)
        Case "groupimage":  Set newShp = ExportGroupImage(sld, item, dataWs)
        Case "chartimage":  Set newShp = ExportChartImage(sld, item, dataWs)
        Case "rangeimage":  Set newShp = ExportRangeImage(sld, item, dataWs)
        Case "rangetable":  Set newShp = ExportRangeTable(sld, item, dataWs, cfgWs)
        Case "text":        Set newShp = ExportText(sld, item, dataWs)
        Case Else
            Debug.Print "  SKIP [" & item.shapeName & "]: unknown SourceType=" & item.SourceType
            Exit Sub
    End Select

    If Not newShp Is Nothing Then
        DeleteShapeByName sld, item.shapeName   ' remove stale shape only after replacement exists
        newShp.Name = item.shapeName
        newShp.Left = item.Left
        newShp.Top = item.Top
        newShp.Width = item.Width
        newShp.Height = item.Height
        LockShapeAspectRatio newShp
        Debug.Print "  OK [" & item.shapeName & "] -> slide " & item.slideIdx
    End If
    Exit Sub

CleanFail:
    Dim errNumber As Long: errNumber = Err.Number
    Dim errDescription As String: errDescription = Err.Description
    On Error Resume Next
    DeleteShapesByPrefix sld, item.shapeName & "_part_"
    DeleteShapesByPrefix sld, item.shapeName & "_new_"
    DeleteShapesByPrefix sld, item.shapeName & "_label_"
    DeleteShapesByPrefix sld, item.shapeName & "_model_"
    On Error GoTo 0
    LogExportMessage "  ERROR [" & item.shapeName & "]: " & errNumber & " - " & errDescription
End Sub

' =============================================================================
' GroupImage: paste named charts as one grouped PPT shape
'   SourceRef = pipe-separated chart names, e.g. "Chart 1|Chart 2|Chart 3|Chart 138"
' =============================================================================
Private Function ExportGroupImage(ByVal sld As Object, ByRef item As ExportItem, _
                                   ByVal ws As Worksheet) As Object
    Dim names() As String
    names = Split(item.sourceRef, "|")

    Dim chartCount As Long
    chartCount = UBound(names) - LBound(names) + 1
    If chartCount <= 0 Then
        Debug.Print "  ERROR GroupImage [" & item.shapeName & "]: no chart names configured"
        Set ExportGroupImage = Nothing
        Exit Function
    End If

    Dim chartObjects() As chartObject
    ReDim chartObjects(1 To chartCount)

    Dim bbLeft As Double, bbTop As Double
    Dim bbRight As Double, bbBottom As Double
    bbLeft = 1E+15: bbTop = 1E+15: bbRight = 0: bbBottom = 0

    Dim validCount As Long
    Dim k As Long
    For k = LBound(names) To UBound(names)
        Dim cName As String: cName = Trim$(names(k))
        If Len(cName) = 0 Then GoTo NextC
        Dim co As chartObject
        On Error Resume Next
        Set co = ws.chartObjects(cName)
        On Error GoTo 0
        If co Is Nothing Then
            Debug.Print "    WARNING: chart not found: " & cName
            GoTo NextC
        End If
        validCount = validCount + 1
        Set chartObjects(validCount) = co
        If co.Left < bbLeft Then bbLeft = co.Left
        If co.Top < bbTop Then bbTop = co.Top
        If co.Left + co.Width > bbRight Then bbRight = co.Left + co.Width
        If co.Top + co.Height > bbBottom Then bbBottom = co.Top + co.Height
NextC:
    Next k

    If validCount = 0 Or bbLeft >= 100000000000000# Then
        Debug.Print "  ERROR GroupImage [" & item.shapeName & "]: no valid charts found"
        Set ExportGroupImage = Nothing: Exit Function
    End If

    Dim bbWidth As Double:  bbWidth = bbRight - bbLeft
    Dim bbHeight As Double: bbHeight = bbBottom - bbTop
    If bbWidth <= 0 Or bbHeight <= 0 Then
        Debug.Print "  ERROR GroupImage [" & item.shapeName & "]: invalid chart bounding box"
        Set ExportGroupImage = Nothing: Exit Function
    End If

    Dim scaleX As Double: scaleX = item.Width / bbWidth
    Dim scaleY As Double: scaleY = item.Height / bbHeight
    Dim labelCount As Long
    labelCount = CountLabelsInBounds(ws, bbLeft, bbTop, bbRight, bbBottom) + _
                 CountStep2ModelTextBoxesInBounds(ws, item.sourceRef, bbLeft, bbTop, bbRight, bbBottom)
    Debug.Print "  GroupImage [" & item.shapeName & "]: charts=" & validCount & ", grouped labels=" & labelCount

    Dim pastedNames() As Variant
    ReDim pastedNames(1 To 1)
    Dim tempBaseName As String
    tempBaseName = item.shapeName & "_new_" & Format$(CLng(Timer * 1000), "00000000")

    Dim idx As Long
    Dim pastedCount As Long
    For idx = 1 To validCount
        Set co = chartObjects(idx)
        Dim pastedShape As Object
        Set pastedShape = AddChartObjectPicture(sld, co, item.shapeName, idx)

        pastedShape.Name = MakeTempShapeName(tempBaseName, idx)
        pastedShape.Left = item.Left + (co.Left - bbLeft) * scaleX
        pastedShape.Top = item.Top + (co.Top - bbTop) * scaleY
        pastedShape.Width = co.Width * scaleX
        pastedShape.Height = co.Height * scaleY
        AppendShapeName pastedNames, pastedCount, pastedShape.Name
    Next idx

    AddLabelsForGroupToShapeRange sld, ws, item, bbLeft, bbTop, bbRight, bbBottom, scaleX, scaleY, pastedNames, pastedCount
    AddStep2ModelTextBoxesForGroupToShapeRange sld, ws, item, bbLeft, bbTop, bbRight, bbBottom, scaleX, scaleY, pastedNames, pastedCount

    If pastedCount = 1 Then
        Set ExportGroupImage = sld.Shapes(CStr(pastedNames(1)))
        Exit Function
    End If

    Dim groupedRange As Object
    Set groupedRange = sld.Shapes.Range(pastedNames).Group
    Set ExportGroupImage = groupedRange
End Function

Private Sub AppendShapeName(ByRef shapeNames() As Variant, _
                            ByRef shapeCount As Long, _
                            ByVal shapeName As String)
    shapeCount = shapeCount + 1
    If UBound(shapeNames) < shapeCount Then ReDim Preserve shapeNames(1 To shapeCount)
    shapeNames(shapeCount) = shapeName
End Sub

Private Function MakeTempShapeName(ByVal baseName As String, ByVal idx As Long) As String
    MakeTempShapeName = baseName & "_part_" & Format$(idx, "000")
End Function

Private Function AddChartObjectPicture(ByVal sld As Object, _
                                       ByVal co As chartObject, _
                                       ByVal baseName As String, _
                                       ByVal idx As Long) As Object
    Dim tmpPath As String
    tmpPath = Environ$("TEMP") & "\" & baseName & "_chart_" & Format$(idx, "000") & ".png"
    co.Chart.Export tmpPath, "PNG"

    Set AddChartObjectPicture = sld.Shapes.AddPicture( _
        FileName:=tmpPath, LinkToFile:=0, SaveWithDocument:=-1, _
        Left:=0, Top:=0, Width:=co.Width, Height:=co.Height)
    LockShapeAspectRatio AddChartObjectPicture

    On Error Resume Next
    Kill tmpPath
    On Error GoTo 0
End Function

Private Function AddLabelShape(ByVal sld As Object, ByVal xlLabel As Shape) As Object
    On Error Resume Next
    Set AddLabelShape = sld.Shapes.AddShape(xlLabel.AutoShapeType, 0, 0, xlLabel.Width, xlLabel.Height)
    If AddLabelShape Is Nothing Then
        Err.Clear
        Set AddLabelShape = sld.Shapes.AddShape(1, 0, 0, xlLabel.Width, xlLabel.Height)
    End If

    AddLabelShape.Fill.Visible = xlLabel.Fill.Visible
    AddLabelShape.Fill.ForeColor.RGB = xlLabel.Fill.ForeColor.RGB
    AddLabelShape.Fill.Transparency = xlLabel.Fill.Transparency
    AddLabelShape.Line.Visible = xlLabel.Line.Visible
    AddLabelShape.Line.ForeColor.RGB = xlLabel.Line.ForeColor.RGB
    AddLabelShape.Line.Weight = xlLabel.Line.Weight

    AddLabelShape.TextFrame.TextRange.Text = xlLabel.TextFrame.Characters.Text
    AddLabelShape.TextFrame.TextRange.Font.Size = xlLabel.TextFrame.Characters.Font.Size
    AddLabelShape.TextFrame.TextRange.Font.Name = xlLabel.TextFrame.Characters.Font.Name
    AddLabelShape.TextFrame.TextRange.Font.Bold = xlLabel.TextFrame.Characters.Font.Bold
    AddLabelShape.TextFrame.TextRange.Font.Color.RGB = xlLabel.TextFrame.Characters.Font.Color
    AddLabelShape.TextFrame.MarginLeft = xlLabel.TextFrame.MarginLeft
    AddLabelShape.TextFrame.MarginRight = xlLabel.TextFrame.MarginRight
    AddLabelShape.TextFrame.MarginTop = xlLabel.TextFrame.MarginTop
    AddLabelShape.TextFrame.MarginBottom = xlLabel.TextFrame.MarginBottom
    AddLabelShape.TextFrame.HorizontalAnchor = xlLabel.TextFrame.HorizontalAlignment
    AddLabelShape.TextFrame.VerticalAnchor = xlLabel.TextFrame.VerticalAlignment
    On Error GoTo 0
End Function

Private Sub AddLabelsForGroup(ByVal sld As Object, ByVal ws As Worksheet, _
                               ByRef item As ExportItem, _
                               ByVal bbLeft As Double, ByVal bbTop As Double, _
                               ByVal bbRight As Double, ByVal bbBottom As Double, _
                               ByVal scaleX As Double, ByVal scaleY As Double)
    Dim labelIdx As Long
    Dim labelShape As Shape
    For Each labelShape In ws.Shapes
        If IsExportLabelShape(labelShape) Then
            If ShapeCenterInBounds(labelShape, bbLeft, bbTop, bbRight, bbBottom) Then
                On Error Resume Next
                Err.Clear
                Dim pptLabel As Object
                Set pptLabel = AddLabelShape(sld, labelShape)
                If Err.Number <> 0 Or pptLabel Is Nothing Then
                    Debug.Print "    WARNING: could not create PPT label shape: " & labelShape.Name
                    Err.Clear
                Else
                    labelIdx = labelIdx + 1
                    ' Label position follows the chart group, but label size remains independent.
                    pptLabel.Name = item.shapeName & "_label_" & Format$(labelIdx, "000")
                    pptLabel.Width = labelShape.Width
                    pptLabel.Height = labelShape.Height
                    pptLabel.Left = item.Left + (labelShape.Left + labelShape.Width - bbLeft) * scaleX - pptLabel.Width
                    pptLabel.Top = item.Top + (labelShape.Top + labelShape.Height / 2 - bbTop) * scaleY - pptLabel.Height / 2
                    If Err.Number <> 0 Then
                        Debug.Print "    WARNING: could not position PPT label shape: " & labelShape.Name
                        Err.Clear
                    End If
                End If
                On Error GoTo 0
            End If
        End If
    Next labelShape
End Sub

Private Sub AddLabelsForGroupToShapeRange(ByVal sld As Object, ByVal ws As Worksheet, _
                                           ByRef item As ExportItem, _
                                           ByVal bbLeft As Double, ByVal bbTop As Double, _
                                           ByVal bbRight As Double, ByVal bbBottom As Double, _
                                           ByVal scaleX As Double, ByVal scaleY As Double, _
                                           ByRef pastedNames() As Variant, _
                                           ByRef pastedCount As Long)
    Dim labelIdx As Long
    Dim labelShape As Shape
    For Each labelShape In ws.Shapes
        If IsExportLabelShape(labelShape) Then
            If ShapeCenterInBounds(labelShape, bbLeft, bbTop, bbRight, bbBottom) Then
                On Error Resume Next
                Err.Clear
                Dim pptLabel As Object
                Set pptLabel = AddLabelShape(sld, labelShape)
                If Err.Number <> 0 Or pptLabel Is Nothing Then
                    Debug.Print "    WARNING: could not create grouped PPT label shape: " & labelShape.Name
                    Err.Clear
                Else
                    labelIdx = labelIdx + 1
                    pptLabel.Name = item.shapeName & "_new_label_" & Format$(labelIdx, "000")
                    pptLabel.Width = labelShape.Width
                    pptLabel.Height = labelShape.Height
                    pptLabel.Left = item.Left + (labelShape.Left + labelShape.Width - bbLeft) * scaleX - pptLabel.Width
                    pptLabel.Top = item.Top + (labelShape.Top + labelShape.Height / 2 - bbTop) * scaleY - pptLabel.Height / 2
                    If Err.Number = 0 Then
                        AppendShapeName pastedNames, pastedCount, pptLabel.Name
                    Else
                        Debug.Print "    WARNING: could not position grouped PPT label shape: " & labelShape.Name
                        Err.Clear
                    End If
                End If
                On Error GoTo 0
            End If
        End If
    Next labelShape
End Sub

Private Sub AddStep2ModelTextBoxesForGroupToShapeRange(ByVal sld As Object, ByVal ws As Worksheet, _
                                                        ByRef item As ExportItem, _
                                                        ByVal bbLeft As Double, ByVal bbTop As Double, _
                                                        ByVal bbRight As Double, ByVal bbBottom As Double, _
                                                        ByVal scaleX As Double, ByVal scaleY As Double, _
                                                        ByRef pastedNames() As Variant, _
                                                        ByRef pastedCount As Long)
    Const FIRST_MODEL As Long = 1
    Const MAX_MODEL As Long = 8

    Dim overlayChart As chartObject
    Set overlayChart = GetOverlayChartObject(ws, item.sourceRef)
    If overlayChart Is Nothing Then Exit Sub

    Dim chartIdx As Long
    chartIdx = ChartNumberFromName(overlayChart.Name) - 99
    If chartIdx < 1 Or chartIdx > 5 Then Exit Sub

    Dim modelCount As Long
    modelCount = overlayChart.Chart.SeriesCollection.Count
    If modelCount > MAX_MODEL Then modelCount = MAX_MODEL

    Dim modelIdx As Long
    For modelIdx = FIRST_MODEL To modelCount
        Dim sourceTextBox As Shape
        Set sourceTextBox = FindStep2ModelTextBox(ws, modelIdx * 10 + chartIdx)
        If sourceTextBox Is Nothing Then GoTo NextModel
        If Not ShapeCenterInBounds(sourceTextBox, bbLeft, bbTop, bbRight, bbBottom) Then GoTo NextModel

        On Error Resume Next
        Err.Clear
        Dim pptTextBox As Object
        Set pptTextBox = AddLabelShape(sld, sourceTextBox)
        If Err.Number <> 0 Or pptTextBox Is Nothing Then
            Debug.Print "    WARNING: could not create grouped PPT model TextBox: " & sourceTextBox.Name
            Err.Clear
            GoTo NextModel
        End If

        pptTextBox.Name = item.shapeName & "_new_model_" & _
                          Format$(modelIdx, "00") & "_" & Format$(chartIdx, "00")
        pptTextBox.Width = sourceTextBox.Width
        pptTextBox.Height = sourceTextBox.Height
        pptTextBox.Left = item.Left + (sourceTextBox.Left + sourceTextBox.Width - bbLeft) * scaleX - pptTextBox.Width
        pptTextBox.Top = item.Top + (sourceTextBox.Top + sourceTextBox.Height / 2 - bbTop) * scaleY - pptTextBox.Height / 2
        If Err.Number = 0 Then
            AppendShapeName pastedNames, pastedCount, pptTextBox.Name
        Else
            Debug.Print "    WARNING: could not position grouped PPT model TextBox: " & sourceTextBox.Name
            Err.Clear
        End If
        On Error GoTo 0
NextModel:
        On Error GoTo 0
    Next modelIdx
End Sub

Private Sub AddModelTextBoxesForGroup(ByVal sld As Object, ByVal ws As Worksheet, _
                                      ByRef item As ExportItem, _
                                      ByVal bbLeft As Double, ByVal bbTop As Double, _
                                      ByVal scaleX As Double, ByVal scaleY As Double)
    Const FIRST_MODEL As Long = 1
    Const MAX_MODEL As Long = 8

    Dim overlayChart As chartObject
    Set overlayChart = GetOverlayChartObject(ws, item.sourceRef)
    If overlayChart Is Nothing Then Exit Sub

    Dim chartIdx As Long
    chartIdx = ChartNumberFromName(overlayChart.Name) - 99
    If chartIdx < 1 Or chartIdx > 5 Then Exit Sub

    Dim modelCount As Long
    modelCount = overlayChart.Chart.SeriesCollection.Count
    If modelCount > MAX_MODEL Then
        Debug.Print "    WARNING: " & overlayChart.Name & " has " & modelCount & _
                    " series, but TextBox config supports models 1-" & MAX_MODEL
        modelCount = MAX_MODEL
    End If

    Dim modelIdx As Long
    For modelIdx = FIRST_MODEL To modelCount
        Dim sourceTextBox As Shape
        Set sourceTextBox = FindStep2ModelTextBox(ws, modelIdx * 10 + chartIdx)
        If sourceTextBox Is Nothing Then
            Debug.Print "    WARNING: missing model TextBox " & (modelIdx * 10 + chartIdx) & _
                        " for " & overlayChart.Name
            GoTo NextModel
        End If

        On Error Resume Next
        Err.Clear
        Dim lineX As Double
        lineX = SeriesXToWorksheetLeft(overlayChart, modelIdx)
        If Err.Number <> 0 Then
            Debug.Print "    WARNING: could not read model line X from " & overlayChart.Name & _
                        " series " & modelIdx
            Err.Clear
            GoTo NextModel
        End If

        Dim pptTextBox As Object
        Set pptTextBox = AddLabelShape(sld, sourceTextBox)
        If Err.Number <> 0 Or pptTextBox Is Nothing Then
            Debug.Print "    WARNING: could not create PPT model TextBox: " & sourceTextBox.Name
            Err.Clear
            GoTo NextModel
        End If

        pptTextBox.Name = item.shapeName & "_model_" & _
                          Format$(modelIdx, "00") & "_" & Format$(chartIdx, "00")
        pptTextBox.Width = sourceTextBox.Width
        pptTextBox.Height = sourceTextBox.Height
        pptTextBox.Left = item.Left + (lineX - bbLeft) * scaleX - pptTextBox.Width
        pptTextBox.Top = item.Top + (sourceTextBox.Top + sourceTextBox.Height / 2 - bbTop) * scaleY - pptTextBox.Height / 2
        If Err.Number <> 0 Then
            Debug.Print "    WARNING: could not position PPT model TextBox: " & sourceTextBox.Name
            Err.Clear
        End If
        On Error GoTo 0
NextModel:
        On Error GoTo 0
    Next modelIdx
End Sub

Private Function FindStep2ModelTextBox(ByVal ws As Worksheet, ByVal textBoxNumber As Long) As Shape
    Set FindStep2ModelTextBox = FindWorksheetShapeByName(ws, "Step2_TextBox_" & CStr(textBoxNumber))
    If FindStep2ModelTextBox Is Nothing Then
        Set FindStep2ModelTextBox = FindWorksheetShapeByName(ws, "TextBox " & CStr(textBoxNumber))
    End If
End Function

Private Function GetOverlayChartObject(ByVal ws As Worksheet, ByVal sourceRef As String) As chartObject
    Dim chartNames() As String
    chartNames = Split(sourceRef, "|")

    Dim idx As Long
    For idx = LBound(chartNames) To UBound(chartNames)
        Dim chartName As String
        chartName = Trim$(chartNames(idx))
        If ChartNumberFromName(chartName) >= 100 And ChartNumberFromName(chartName) <= 104 Then
            On Error Resume Next
            Set GetOverlayChartObject = ws.chartObjects(chartName)
            On Error GoTo 0
            Exit Function
        End If
    Next idx
End Function

Private Function ChartNumberFromName(ByVal chartName As String) As Long
    Dim digits As String
    Dim idx As Long
    For idx = 1 To Len(chartName)
        Dim ch As String
        ch = Mid$(chartName, idx, 1)
        If ch >= "0" And ch <= "9" Then digits = digits & ch
    Next idx

    If Len(digits) > 0 Then ChartNumberFromName = CLng(digits)
End Function

Private Function FindWorksheetShapeByName(ByVal ws As Worksheet, ByVal shapeName As String) As Shape
    On Error Resume Next
    Set FindWorksheetShapeByName = ws.Shapes(shapeName)
    On Error GoTo 0
End Function

Private Function SeriesXToWorksheetLeft(ByVal chartObject As chartObject, ByVal seriesIdx As Long) As Double
    Dim xValue As Double
    xValue = FirstSeriesXValue(chartObject.Chart, seriesIdx)

    Dim minX As Double
    Dim maxX As Double
    minX = chartObject.Chart.Axes(xlCategory).MinimumScale
    maxX = chartObject.Chart.Axes(xlCategory).MaximumScale

    Dim scaleRatio As Double
    If maxX <> minX Then scaleRatio = (xValue - minX) / (maxX - minX)

    SeriesXToWorksheetLeft = chartObject.Left + _
                             chartObject.Chart.PlotArea.insideLeft + _
                             chartObject.Chart.PlotArea.insideWidth * scaleRatio
End Function

Private Function FirstSeriesXValue(ByVal chartObject As Chart, ByVal seriesIdx As Long) As Double
    Dim xValues As Variant
    xValues = chartObject.SeriesCollection(seriesIdx).xValues

    If IsArray(xValues) Then
        FirstSeriesXValue = CDbl(xValues(LBound(xValues)))
    Else
        FirstSeriesXValue = CDbl(xValues)
    End If
End Function

Private Function CountLabelsInBounds(ByVal ws As Worksheet, _
                                      ByVal bbLeft As Double, ByVal bbTop As Double, _
                                      ByVal bbRight As Double, ByVal bbBottom As Double) As Long
    Dim shp As Shape
    For Each shp In ws.Shapes
        If IsExportLabelShape(shp) Then
            If ShapeCenterInBounds(shp, bbLeft, bbTop, bbRight, bbBottom) Then
                CountLabelsInBounds = CountLabelsInBounds + 1
            End If
        End If
    Next shp
End Function

Private Function CountStep2ModelTextBoxesInBounds(ByVal ws As Worksheet, _
                                                  ByVal sourceRef As String, _
                                                  ByVal bbLeft As Double, ByVal bbTop As Double, _
                                                  ByVal bbRight As Double, ByVal bbBottom As Double) As Long
    Const FIRST_MODEL As Long = 1
    Const MAX_MODEL As Long = 8

    Dim overlayChart As chartObject
    Set overlayChart = GetOverlayChartObject(ws, sourceRef)
    If overlayChart Is Nothing Then Exit Function

    Dim chartIdx As Long
    chartIdx = ChartNumberFromName(overlayChart.Name) - 99
    If chartIdx < 1 Or chartIdx > 5 Then Exit Function

    Dim modelCount As Long
    modelCount = overlayChart.Chart.SeriesCollection.Count
    If modelCount > MAX_MODEL Then modelCount = MAX_MODEL

    Dim modelIdx As Long
    For modelIdx = FIRST_MODEL To modelCount
        Dim sourceTextBox As Shape
        Set sourceTextBox = FindStep2ModelTextBox(ws, modelIdx * 10 + chartIdx)
        If Not sourceTextBox Is Nothing Then
            If ShapeCenterInBounds(sourceTextBox, bbLeft, bbTop, bbRight, bbBottom) Then
                CountStep2ModelTextBoxesInBounds = CountStep2ModelTextBoxesInBounds + 1
            End If
        End If
    Next modelIdx
End Function

Private Function IsExportLabelShape(ByVal shp As Shape) As Boolean
    IsExportLabelShape = (LCase$(Left$(shp.Name, 5)) = "label")
End Function

Private Function ShapeCenterInBounds(ByVal shp As Shape, _
                                      ByVal bbLeft As Double, ByVal bbTop As Double, _
                                      ByVal bbRight As Double, ByVal bbBottom As Double) As Boolean
    Dim centerX As Double: centerX = shp.Left + shp.Width / 2
    Dim centerY As Double: centerY = shp.Top + shp.Height / 2
    ShapeCenterInBounds = _
        centerX >= bbLeft And centerX <= bbRight And _
        centerY >= bbTop And centerY <= bbBottom
End Function

Private Sub LogExportMessage(ByVal message As String)
    Debug.Print message
    On Error Resume Next
    Dim fileNo As Integer
    fileNo = FreeFile
    Open ThisWorkbook.Path & "\export_debug.log" For Append As #fileNo
    Print #fileNo, Format$(Now, "yyyy-mm-dd hh:nn:ss") & " " & message
    Close #fileNo
    On Error GoTo 0
End Sub

Private Function CopyShapeForPptPaste(ByVal shp As Shape) As Boolean
    On Error Resume Next
    Err.Clear
    shp.CopyPicture Appearance:=xlScreen, Format:=xlPicture
    If Err.Number <> 0 Then
        Err.Clear
        shp.Copy
    End If
    If Err.Number <> 0 Then
        Debug.Print "    WARNING: could not copy label shape: " & shp.Name & _
                    " (" & Err.Description & ")"
        Err.Clear
        CopyShapeForPptPaste = False
    Else
        CopyShapeForPptPaste = True
    End If
    On Error GoTo 0
End Function

Private Function PasteShapeRangeWithRetry(ByVal sld As Object) As Object
    Const MAX_ATTEMPTS As Long = 5

    Dim attempt As Long
    For attempt = 1 To MAX_ATTEMPTS
        DoEvents
        On Error Resume Next
        Err.Clear
        Set PasteShapeRangeWithRetry = sld.Shapes.Paste
        If Err.Number = 0 Then
            On Error GoTo 0
            Exit Function
        End If
        Err.Clear
        On Error GoTo 0
        Application.Wait Now + TimeSerial(0, 0, 1)
    Next attempt

    Err.Raise vbObjectError + 401, , "PowerPoint paste failed after clipboard retry."
End Function

' =============================================================================
' RangeImage: CopyPicture of cell range (includes overlapping chart objects)
' =============================================================================
Private Function ExportRangeImage(ByVal sld As Object, ByRef item As ExportItem, _
                                   ByVal ws As Worksheet) As Object
    ws.Range(item.sourceRef).CopyPicture xlScreen, xlPicture

    Dim sr As Object
    Set sr = sld.Shapes.Paste
    If sr.Count > 0 Then
        Set ExportRangeImage = sr(1)
    Else
        Set ExportRangeImage = sr
    End If
End Function

' =============================================================================
' ChartImage: export single chart via Chart.Export (high-res PNG)
' =============================================================================
Private Function ExportChartImage(ByVal sld As Object, ByRef item As ExportItem, _
                                   ByVal ws As Worksheet) As Object
    Dim co As chartObject
    Set co = ws.chartObjects(item.sourceRef)

    Dim tmpPath As String
    tmpPath = Environ$("TEMP") & "\" & item.shapeName & "_tmp.png"
    co.Chart.Export tmpPath, "PNG"

    Set ExportChartImage = sld.Shapes.AddPicture( _
        FileName:=tmpPath, LinkToFile:=0, SaveWithDocument:=-1, _
        Left:=item.Left, Top:=item.Top, Width:=item.Width, Height:=item.Height)
    LockShapeAspectRatio ExportChartImage

    On Error Resume Next
    Kill tmpPath
    On Error GoTo 0
End Function

' =============================================================================
' RangeTable: paste as editable PowerPoint table
' =============================================================================
Private Function ExportRangeTable(ByVal sld As Object, ByRef item As ExportItem, _
                                   ByVal ws As Worksheet, ByVal cfgWs As Worksheet) As Object
    Dim srcRange As Range
    Set srcRange = ws.Range(item.sourceRef)
    srcRange.Copy

    ' ppPasteHTML=8 → creates editable table in PPT
    Dim sr As Object
    Set sr = sld.Shapes.PasteSpecial(8)
    Application.CutCopyMode = False

    Dim tableShape As Object
    If sr.Count > 0 Then
        Set tableShape = sr(1)
    Else
        Set tableShape = sr
    End If

    ApplyTableCellSize tableShape, item, srcRange, cfgWs
    Set ExportRangeTable = tableShape
End Function

Private Sub ApplyTableCellSize(ByVal tableShape As Object, _
                                ByRef item As ExportItem, _
                                ByVal srcRange As Range, _
                                ByVal cfgWs As Worksheet)
    If Not tableShape.HasTable Then Exit Sub

    Dim pptTable As Object
    Set pptTable = tableShape.Table

    Dim configRow As Long
    configRow = FirstTablePartHeaderRow(cfgWs)
    Do While IsTablePartHeaderRow(cfgWs, configRow)
        ApplyTablePartSize pptTable, srcRange, _
                           CStr(cfgWs.Cells(configRow + 1, 10).Value), _
                           Val(cfgWs.Cells(configRow + 1, 11).Value), _
                           Val(cfgWs.Cells(configRow + 1, 12).Value), _
                           Val(cfgWs.Cells(configRow + 1, 13).Value)
        configRow = configRow + 2
    Loop

    item.Width = SumPptTableColumnWidths(pptTable)
    item.Height = SumPptTableRowHeights(pptTable)
End Sub

Private Function IsRangeTableConfigValid(ByVal cfgWs As Worksheet, _
                                         ByVal dataWs As Worksheet, _
                                         ByRef item As ExportItem) As Boolean
    On Error GoTo CleanFail

    Dim srcRange As Range
    Set srcRange = dataWs.Range(item.sourceRef)

    Dim rowCount As Long: rowCount = srcRange.Rows.Count
    Dim colCount As Long: colCount = srcRange.Columns.Count
    Dim covered() As Boolean
    ReDim covered(1 To rowCount, 1 To colCount)

    Dim coveredCells As Long
    Dim partCount As Long
    Dim configRow As Long
    configRow = FirstTablePartHeaderRow(cfgWs)

    Do While IsTablePartHeaderRow(cfgWs, configRow)
        Dim partAddress As String
        partAddress = Trim$(CStr(cfgWs.Cells(configRow + 1, 10).Value))

        If Len(partAddress) = 0 Then
            Debug.Print "  ERROR [" & item.shapeName & "]: missing table part range at ExportConfig row " & (configRow + 1)
            Exit Function
        End If

        Dim partRange As Range
        Set partRange = dataWs.Range(partAddress)
        If Intersect(srcRange, partRange) Is Nothing Or Not RangeContains(srcRange, partRange) Then
            Debug.Print "  ERROR [" & item.shapeName & "]: table part outside SourceRef: " & partAddress
            Exit Function
        End If

        Dim r As Long, c As Long
        For r = 1 To partRange.Rows.Count
            For c = 1 To partRange.Columns.Count
                Dim relRow As Long: relRow = partRange.row - srcRange.row + r
                Dim relCol As Long: relCol = partRange.Column - srcRange.Column + c
                If covered(relRow, relCol) Then
                    Debug.Print "  ERROR [" & item.shapeName & "]: overlapping table part at " & _
                                partRange.Cells(r, c).Address(False, False)
                    Exit Function
                End If
                covered(relRow, relCol) = True
                coveredCells = coveredCells + 1
            Next c
        Next r

        partCount = partCount + 1
        configRow = configRow + 2
    Loop

    If partCount = 0 Then
        Debug.Print "  ERROR [" & item.shapeName & "]: no table part config found in ExportConfig J:M"
        Exit Function
    End If

    If coveredCells <> srcRange.Cells.CountLarge Then
        Debug.Print "  ERROR [" & item.shapeName & "]: table part ranges cover " & coveredCells & _
                    " cells, but SourceRef " & item.sourceRef & " has " & srcRange.Cells.CountLarge & _
                    " cells. Fix ExportConfig table part ranges."
        Exit Function
    End If

    IsRangeTableConfigValid = True
    Exit Function

CleanFail:
    Debug.Print "  ERROR [" & item.shapeName & "]: invalid RangeTable config - " & Err.Description
End Function

Private Function FirstTablePartHeaderRow(ByVal cfgWs As Worksheet) As Long
    Const TABLE_PART_FIRST_ROW As Long = 1
    FirstTablePartHeaderRow = TABLE_PART_FIRST_ROW
End Function

Private Function IsTablePartHeaderRow(ByVal cfgWs As Worksheet, ByVal rowIdx As Long) As Boolean
    Dim headerText As String
    headerText = LCase$(Trim$(CStr(cfgWs.Cells(rowIdx, 10).Value)))
    IsTablePartHeaderRow = (Len(headerText) > 0 And InStr(1, headerText, "range", vbTextCompare) > 0)
End Function

Private Function RangeContains(ByVal outerRange As Range, ByVal innerRange As Range) As Boolean
    RangeContains = _
        innerRange.row >= outerRange.row And _
        innerRange.Column >= outerRange.Column And _
        innerRange.row + innerRange.Rows.Count - 1 <= outerRange.row + outerRange.Rows.Count - 1 And _
        innerRange.Column + innerRange.Columns.Count - 1 <= outerRange.Column + outerRange.Columns.Count - 1
End Function

Private Sub ApplyTablePartSize(ByVal pptTable As Object, _
                                ByVal srcRange As Range, _
                                ByVal partAddress As String, _
                                ByVal cellWidthPt As Double, _
                                ByVal cellHeightPt As Double, _
                                ByVal fontSizePt As Double)
    If Len(partAddress) = 0 Then Exit Sub
    If cellWidthPt <= 0 And cellHeightPt <= 0 And fontSizePt <= 0 Then Exit Sub

    Dim partRange As Range
    Set partRange = srcRange.Worksheet.Range(partAddress)
    If Intersect(srcRange, partRange) Is Nothing Then
        Debug.Print "    WARNING: table part outside SourceRef: " & partAddress
        Exit Sub
    End If

    Dim firstCol As Long: firstCol = partRange.Column - srcRange.Column + 1
    Dim lastCol As Long:  lastCol = firstCol + partRange.Columns.Count - 1
    Dim firstRow As Long: firstRow = partRange.row - srcRange.row + 1
    Dim lastRow As Long:  lastRow = firstRow + partRange.Rows.Count - 1

    If firstCol < 1 Then firstCol = 1
    If firstRow < 1 Then firstRow = 1
    If lastCol > pptTable.Columns.Count Then lastCol = pptTable.Columns.Count
    If lastRow > pptTable.Rows.Count Then lastRow = pptTable.Rows.Count

    Dim idx As Long
    If cellWidthPt > 0 Then
        For idx = firstCol To lastCol
            pptTable.Columns(idx).Width = cellWidthPt
        Next idx
    End If

    If cellHeightPt > 0 Then
        For idx = firstRow To lastRow
            pptTable.Rows(idx).Height = cellHeightPt
        Next idx
    End If

    If fontSizePt > 0 Then
        Dim rowIdx As Long, colIdx As Long
        For rowIdx = firstRow To lastRow
            For colIdx = firstCol To lastCol
                pptTable.Cell(rowIdx, colIdx).Shape.TextFrame.TextRange.Font.Size = fontSizePt
            Next colIdx
        Next rowIdx
    End If
End Sub

Private Function SumPptTableColumnWidths(ByVal pptTable As Object) As Double
    Dim idx As Long
    For idx = 1 To pptTable.Columns.Count
        SumPptTableColumnWidths = SumPptTableColumnWidths + pptTable.Columns(idx).Width
    Next idx
End Function

Private Function SumPptTableRowHeights(ByVal pptTable As Object) As Double
    Dim idx As Long
    For idx = 1 To pptTable.Rows.Count
        SumPptTableRowHeights = SumPptTableRowHeights + pptTable.Rows(idx).Height
    Next idx
End Function

' =============================================================================
' Text: plain text box; SourceRef = literal text or "=CellAddress"
' =============================================================================
Private Function ExportText(ByVal sld As Object, ByRef item As ExportItem, _
                             ByVal ws As Worksheet) As Object
    Dim txt As String
    If Left$(item.sourceRef, 1) = "=" Then
        txt = CStr(ws.Range(Mid$(item.sourceRef, 2)).Value)
    Else
        txt = item.sourceRef
    End If

    ' msoTextOrientationHorizontal = 1
    Dim shp As Object
    Set shp = sld.Shapes.AddTextbox(1, item.Left, item.Top, item.Width, item.Height)
    shp.TextFrame.TextRange.Text = txt
    Set ExportText = shp
End Function

' =============================================================================
' HELPERS
' =============================================================================
Private Function FindShapeByName(ByVal sld As Object, ByVal sName As String) As Object
    Dim shp As Object
    For Each shp In sld.Shapes
        If StrComp(shp.Name, sName, vbTextCompare) = 0 Then
            Set FindShapeByName = shp: Exit Function
        End If
    Next shp
    Set FindShapeByName = Nothing
End Function

Private Sub DeleteShapeByName(ByVal sld As Object, ByVal sName As String)
    Dim shp As Object
    Set shp = FindShapeByName(sld, sName)
    If Not shp Is Nothing Then shp.Delete
End Sub

Private Sub DeleteShapesByPrefix(ByVal sld As Object, ByVal namePrefix As String)
    Dim i As Long
    For i = sld.Shapes.Count To 1 Step -1
        If StrComp(Left$(sld.Shapes(i).Name, Len(namePrefix)), namePrefix, vbTextCompare) = 0 Then
            sld.Shapes(i).Delete
        End If
    Next i
End Sub

Private Sub LockShapeAspectRatio(ByVal shp As Object)
    On Error Resume Next
    shp.LockAspectRatio = -1   ' msoTrue
    On Error GoTo 0
End Sub

Private Sub WriteRow(ByVal ws As Worksheet, ByVal r As Long, _
                     ByVal sName As String, ByVal slideIdx As Long, _
                     ByVal srcType As String, ByVal srcRef As String, _
                     ByVal dL As Double, ByVal dT As Double, _
                     ByVal dW As Double, ByVal dH As Double)
    ws.Cells(r, 1).Value = sName
    ws.Cells(r, 2).Value = slideIdx
    ws.Cells(r, 3).Value = srcType
    ws.Cells(r, 4).Value = srcRef
    ws.Cells(r, 5).Value = dL
    ws.Cells(r, 6).Value = dT
    ws.Cells(r, 7).Value = dW
    ws.Cells(r, 8).Value = dH
End Sub

Private Sub UpdateSourceRefByShapeName(ByVal ws As Worksheet, _
                                        ByVal shapeName As String, _
                                        ByVal sourceRef As String)
    Dim r As Long
    r = 2
    Do While Len(Trim$(ws.Cells(r, 1).Value)) > 0
        If StrComp(Trim$(ws.Cells(r, 1).Value), shapeName, vbTextCompare) = 0 Then
            ws.Cells(r, 4).Value = sourceRef
            Exit Sub
        End If
        r = r + 1
    Loop
    Err.Raise vbObjectError + 301, , "ShapeName not found in ExportConfig: " & shapeName
End Sub

Private Sub EnsureGroupImageRow(ByVal ws As Worksheet, _
                                ByVal shapeName As String, _
                                ByVal slideIdx As Long, _
                                ByVal sourceRef As String)
    Dim r As Long
    r = 2
    Do While Len(Trim$(ws.Cells(r, 1).Value)) > 0
        If StrComp(Trim$(ws.Cells(r, 1).Value), shapeName, vbTextCompare) = 0 Then
            ws.Cells(r, 2).Value = slideIdx
            ws.Cells(r, 3).Value = "GroupImage"
            ws.Cells(r, 4).Value = sourceRef
            Exit Sub
        End If
        r = r + 1
    Loop

    WriteRow ws, r, shapeName, slideIdx, "GroupImage", sourceRef, 0, 0, 0, 0
End Sub

Private Sub WriteTablePartConfig(ByVal ws As Worksheet)
    ws.Range("J1:M6").ClearContents

    ws.Cells(1, 10).Value = "Part1Range"
    ws.Cells(1, 11).Value = "Part1CellWidthPt"
    ws.Cells(1, 12).Value = "Part1CellHeightPt"
    ws.Cells(1, 13).Value = "Part1FontSizePt"
    ws.Cells(2, 10).Value = "AD7:AD12"
    ws.Cells(2, 11).Value = 300
    ws.Cells(2, 12).Value = 10
    ws.Cells(2, 13).Value = 7

    ws.Cells(3, 10).Value = "Part2Range"
    ws.Cells(3, 11).Value = "Part2CellWidthPt"
    ws.Cells(3, 12).Value = "Part2CellHeightPt"
    ws.Cells(3, 13).Value = "Part2FontSizePt"
    ws.Cells(4, 10).Value = "AE7:AE12"
    ws.Cells(4, 11).Value = 300
    ws.Cells(4, 12).Value = 10
    ws.Cells(4, 13).Value = 7

    ws.Cells(5, 10).Value = "Part3Range"
    ws.Cells(5, 11).Value = "Part3CellWidthPt"
    ws.Cells(5, 12).Value = "Part3CellHeightPt"
    ws.Cells(5, 13).Value = "Part3FontSizePt"
    ws.Cells(6, 10).Value = "AF7:AY12"
    ws.Cells(6, 11).Value = 14
    ws.Cells(6, 12).Value = 10
    ws.Cells(6, 13).Value = 7

    ws.Range("J1:M1").Font.Bold = True
    ws.Range("J3:M3").Font.Bold = True
    ws.Range("J5:M5").Font.Bold = True
End Sub

Private Sub WriteStep2ScoreRangeConfig(ByVal ws As Worksheet)
    ws.Cells(1, 9).Value = "Step2Model1ScoreRange"
    WriteStep2ScoreRange ws, "XL_Group1", "AF10:AH10"
    WriteStep2ScoreRange ws, "XL_Group2", "AJ10:AL10"
    WriteStep2ScoreRange ws, "XL_Group3", "AN10:AP10"
    WriteStep2ScoreRange ws, "XL_Group4", "AR10:AT10"
    WriteStep2ScoreRange ws, "XL_Group5", "AV10:AX10"
End Sub

Private Sub WriteStep2ScoreRange(ByVal ws As Worksheet, _
                                 ByVal shapeName As String, _
                                 ByVal scoreRange As String)
    Dim r As Long
    r = 2
    Do While Len(Trim$(ws.Cells(r, 1).Value)) > 0
        If StrComp(Trim$(ws.Cells(r, 1).Value), shapeName, vbTextCompare) = 0 Then
            ws.Cells(r, 9).Value = scoreRange
            Exit Sub
        End If
        r = r + 1
    Loop
End Sub
