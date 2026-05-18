Attribute VB_Name = "modLayout"
Option Explicit

' =============================================================================
' Layout helpers: coordinate mapping between Excel template and PPT slide.
' Template-sheet discovery and Named Range lookup utilities.
' =============================================================================

Public Type LayoutBox
    Left As Double
    Top As Double
    Width As Double
    Height As Double
End Type

' =============================================================================
Public Sub GridLayout()
' =============================================================================
'   Reads ExportConfig:
'     ChartGridCols    = number of group columns (e.g. 5)
'     ChartGridRows    = rows per group (e.g. 3 = Top/Mid/Bot)
'     ChartGridLeft    = top-left X of grid (worksheet pt)
'     ChartGridTop     = top-left Y of grid (worksheet pt)
'     ChartCellWidthIn  = each chart width in INCHES (Excel "Width" dialog)
'     ChartCellHeightIn = each chart height in INCHES (Excel "Height" dialog)
'   Tiles edge-to-edge: each chart cell = CellWidthIn x CellHeightIn (no gap).
'   Total grid = (cellW x cols) by (cellH x rows).
'
'   For each cell (g, r), looks up chart name from
'     G{g}_TopChart   (r=1)
'     G{g}_MidChart   (r=2)
'     G{g}_BotChart   (r=3)
'   Rows > 3 use convention G{g}_R{r}Chart (e.g. G1_R4Chart).
    modConfig.InvalidateCache
    Dim ws As Worksheet: Set ws = modConfig.GetDataSheet()
    If ws Is Nothing Then Debug.Print "GridLayout: data sheet not found": Exit Sub

    Const INCH_TO_PT As Double = 72#
    Dim cols As Long:    cols    = modConfig.CfgLong("ChartGridCols", 5)
    Dim rows As Long:    rows    = modConfig.CfgLong("ChartGridRows", 3)
    Dim gridL As Double: gridL   = modConfig.CfgDbl("ChartGridLeft", 0)
    Dim gridT As Double: gridT   = modConfig.CfgDbl("ChartGridTop", 170)
    Dim cellWIn As Double: cellWIn = modConfig.CfgDbl("ChartCellWidthIn", 2.28)
    Dim cellHIn As Double: cellHIn = modConfig.CfgDbl("ChartCellHeightIn", 1.36)
    If cols <= 0 Or rows <= 0 Or cellWIn <= 0 Or cellHIn <= 0 Then
        Debug.Print "GridLayout: invalid dimensions": Exit Sub
    End If

    Dim cellW As Double: cellW = cellWIn * INCH_TO_PT
    Dim cellH As Double: cellH = cellHIn * INCH_TO_PT
    Debug.Print "GridLayout: " & cols & "x" & rows & _
                "  cell=" & Format$(cellWIn, "0.00") & """x" & Format$(cellHIn, "0.00") & """" & _
                "  (" & Format$(cellW, "0.0") & "x" & Format$(cellH, "0.0") & "pt)" & _
                "  total=" & Format$(cellW * cols, "0.0") & "x" & Format$(cellH * rows, "0.0") & "pt"
    Dim placed As Long, missing As Long
    Dim g As Long, r As Long
    For g = 1 To cols
        For r = 1 To rows
            Dim key As String, chartName As String
            Select Case r
                Case 1: key = "G" & g & "_TopChart"
                Case 2: key = "G" & g & "_MidChart"
                Case 3: key = "G" & g & "_BotChart"
                Case Else: key = "G" & g & "_R" & r & "Chart"
            End Select
            chartName = modConfig.CfgStr(key, "")
            If Len(chartName) = 0 Then
                Debug.Print "  [skip] " & key & " (empty)"
            Else
                Dim co As ChartObject
                Set co = Nothing
                On Error Resume Next
                Set co = ws.ChartObjects(chartName)
                On Error GoTo 0
                If co Is Nothing Then
                    Debug.Print "  [MISS] " & key & "=" & chartName & " not found"
                    missing = missing + 1
                Else
                    co.Left   = gridL + (g - 1) * cellW
                    co.Top    = gridT + (r - 1) * cellH
                    co.Width  = cellW
                    co.Height = cellH
                    placed = placed + 1
                    Debug.Print "  G" & g & " R" & r & " " & chartName & _
                                " L=" & Format$(co.Left, "0.0") & _
                                " T=" & Format$(co.Top, "0.0") & _
                                " W=" & Format$(co.Width, "0.0") & _
                                " H=" & Format$(co.Height, "0.0")
                End If
            End If
        Next r
    Next g
    Debug.Print "=== GridLayout: placed=" & placed & "  missing=" & missing & " ==="
End Sub

' =============================================================================
Public Function MapToSlide(ByVal src As Range, ByVal bounds As Range, _
                             ByVal slideW As Double, ByVal slideH As Double) As LayoutBox
' =============================================================================
    Dim out As LayoutBox
    out.Left = (src.Left - bounds.Left) / bounds.Width * slideW
    out.Top = (src.Top - bounds.Top) / bounds.Height * slideH
    out.Width = src.Width / bounds.Width * slideW
    out.Height = src.Height / bounds.Height * slideH
    MapToSlide = out
End Function

' =============================================================================
Public Function MapBoxToSlide(ByVal L As Double, ByVal T As Double, _
                                ByVal W As Double, ByVal H As Double, _
                                ByVal bounds As Range, _
                                ByVal slideW As Double, ByVal slideH As Double) As LayoutBox
' =============================================================================
'   Same mapping as MapToSlide but takes raw box coordinates (worksheet pt)
'   instead of a Range. Used for chart-group bbox export.
    Dim out As LayoutBox
    out.Left = (L - bounds.Left) / bounds.Width * slideW
    out.Top = (T - bounds.Top) / bounds.Height * slideH
    out.Width = W / bounds.Width * slideW
    out.Height = H / bounds.Height * slideH
    MapBoxToSlide = out
End Function

' =============================================================================
Public Function ComputeGroupBBox(ByVal ws As Worksheet, ByVal g As Long, _
                                  ByVal cfgWs As Worksheet) As LayoutBox
' =============================================================================
'   Computes the bounding box (in worksheet points) covering all shapes
'   that visually belong to group g.
    Dim minL As Double, minT As Double, maxR As Double, maxB As Double
    Dim found As Boolean
    minL = 1E+15: minT = 1E+15: maxR = -1E+15: maxB = -1E+15
    found = False

    ' --- Charts (Top/Mid/Bot) ---
    Dim names As Variant: names = Array("Top", "Mid", "Bot")
    Dim k As Long
    For k = 0 To 2
        Dim nm As String
        nm = modConfig.CfgStr("G" & g & "_" & names(k) & "Chart", "")
        If Len(nm) > 0 Then
            Dim co As ChartObject
            Set co = Nothing
            On Error Resume Next
            Set co = ws.ChartObjects(nm)
            On Error GoTo 0
            If Not co Is Nothing Then
                ExtendBox minL, minT, maxR, maxB, co.Left, co.Top, co.Width, co.Height, found
            End If
            Set co = Nothing
        End If
    Next k

    ' --- Lines + TextBoxes ---
    Dim linePfx As String: linePfx = modConfig.CfgStr("LineShapePrefix", "Line_G")
    Dim labelPfx As String: labelPfx = modConfig.CfgStr("LabelCopyPrefix", "Step2_TextBox_")
    Dim shp As Shape
    For Each shp In ws.Shapes
        Dim sn As String: sn = shp.Name
        If sn Like (linePfx & g & "_*") Then
            ExtendBox minL, minT, maxR, maxB, shp.Left, shp.Top, shp.Width, shp.Height, found
        ElseIf StrComp(Left$(sn, Len(labelPfx)), labelPfx, vbTextCompare) = 0 Then
            Dim idx As Long: idx = TryParseLabelIdx(sn)
            If idx > 0 Then
                If (idx Mod 10) = g Then
                    ExtendBox minL, minT, maxR, maxB, shp.Left, shp.Top, shp.Width, shp.Height, found
                End If
            End If
        End If
    Next shp

    Dim out As LayoutBox
    If found Then
        out.Left = minL
        out.Top = minT
        out.Width = maxR - minL
        out.Height = maxB - minT
    End If
    ComputeGroupBBox = out
End Function

' =============================================================================
Public Function CellsCoveringBBox(ByVal ws As Worksheet, _
                                    ByVal L As Double, ByVal T As Double, _
                                    ByVal W As Double, ByVal H As Double) As Range
' =============================================================================
'   Returns the smallest cell range whose outer rectangle covers (L,T,W,H).
    Dim c1 As Range, c2 As Range
    Set c1 = CellAtOrBeforePoint(ws, L, T)
    Set c2 = CellAtOrAfterPoint(ws, L + W, T + H)
    If c1 Is Nothing Or c2 Is Nothing Then Exit Function
    Set CellsCoveringBBox = ws.Range(c1, c2)
End Function

' --- BBox helpers -------------------------------------------------------------
Private Sub ExtendBox(ByRef minL As Double, ByRef minT As Double, _
                       ByRef maxR As Double, ByRef maxB As Double, _
                       ByVal L As Double, ByVal T As Double, _
                       ByVal W As Double, ByVal H As Double, _
                       ByRef found As Boolean)
    If L < minL Then minL = L
    If T < minT Then minT = T
    If L + W > maxR Then maxR = L + W
    If T + H > maxB Then maxB = T + H
    found = True
End Sub

Private Function TryParseLabelIdx(ByVal n As String) As Long
    Dim p As Long: p = InStrRev(n, "_")
    If p = 0 Or p = Len(n) Then Exit Function
    Dim tail As String: tail = Mid$(n, p + 1)
    If Not IsNumeric(tail) Then Exit Function
    TryParseLabelIdx = CLng(tail)
End Function

Private Function CellAtOrBeforePoint(ByVal ws As Worksheet, _
                                      ByVal x As Double, ByVal y As Double) As Range
    Dim col As Long, row As Long
    col = ColumnAtOrBefore(ws, x)
    row = RowAtOrBefore(ws, y)
    If col < 1 Then col = 1
    If row < 1 Then row = 1
    Set CellAtOrBeforePoint = ws.Cells(row, col)
End Function

Private Function CellAtOrAfterPoint(ByVal ws As Worksheet, _
                                     ByVal x As Double, ByVal y As Double) As Range
    Dim col As Long, row As Long
    col = ColumnAtOrAfter(ws, x)
    row = RowAtOrAfter(ws, y)
    If col < 1 Then col = 1
    If row < 1 Then row = 1
    Set CellAtOrAfterPoint = ws.Cells(row, col)
End Function

Private Function ColumnAtOrBefore(ByVal ws As Worksheet, ByVal x As Double) As Long
    Dim c As Long, accum As Double
    accum = 0
    For c = 1 To ws.Columns.Count
        Dim w As Double: w = ws.Columns(c).Width
        If accum + w > x + 0.001 Then
            ColumnAtOrBefore = c
            Exit Function
        End If
        accum = accum + w
        If c > 1000 Then Exit For
    Next c
    ColumnAtOrBefore = 1
End Function

Private Function ColumnAtOrAfter(ByVal ws As Worksheet, ByVal x As Double) As Long
    Dim c As Long, accum As Double
    accum = 0
    For c = 1 To ws.Columns.Count
        Dim w As Double: w = ws.Columns(c).Width
        accum = accum + w
        If accum >= x - 0.001 Then
            ColumnAtOrAfter = c
            Exit Function
        End If
        If c > 1000 Then Exit For
    Next c
    ColumnAtOrAfter = 1
End Function

Private Function RowAtOrBefore(ByVal ws As Worksheet, ByVal y As Double) As Long
    Dim r As Long, accum As Double
    accum = 0
    For r = 1 To ws.Rows.Count
        Dim h As Double: h = ws.Rows(r).Height
        If accum + h > y + 0.001 Then
            RowAtOrBefore = r
            Exit Function
        End If
        accum = accum + h
        If r > 5000 Then Exit For
    Next r
    RowAtOrBefore = 1
End Function

Private Function RowAtOrAfter(ByVal ws As Worksheet, ByVal y As Double) As Long
    Dim r As Long, accum As Double
    accum = 0
    For r = 1 To ws.Rows.Count
        Dim h As Double: h = ws.Rows(r).Height
        accum = accum + h
        If accum >= y - 0.001 Then
            RowAtOrAfter = r
            Exit Function
        End If
        If r > 5000 Then Exit For
    Next r
    RowAtOrAfter = 1
End Function

' --- Template-sheet discovery -------------------------------------------------
Public Function ParseSlideIdx(ByVal sheetName As String) As Long
    Dim pfx As String: pfx = modConfig.CfgStr("TemplateSheetPrefix", modConfig.TPL_SHEET_PREFIX)
    If Len(sheetName) <= Len(pfx) Then Exit Function
    If StrComp(Left$(sheetName, Len(pfx)), pfx, vbTextCompare) <> 0 Then Exit Function
    Dim tail As String: tail = Mid$(sheetName, Len(pfx) + 1)
    If Not IsNumeric(tail) Then Exit Function
    ParseSlideIdx = CLng(tail)
End Function

Public Function FindSlideSheet(ByVal slideIdx As Long) As Worksheet
    Dim ws As Worksheet
    For Each ws In ThisWorkbook.Worksheets
        If ParseSlideIdx(ws.Name) = slideIdx Then
            Set FindSlideSheet = ws
            Exit Function
        End If
    Next ws
End Function

' --- Named Range lookup -------------------------------------------------------
Public Function FindNamedRange(ByVal ws As Worksheet, ByVal nameBase As String) As Range
    Dim nm As Name
    For Each nm In ThisWorkbook.Names
        Dim baseName As String: baseName = nm.Name
        Dim sepPos As Long: sepPos = InStrRev(baseName, "!")
        If sepPos > 0 Then baseName = Mid$(baseName, sepPos + 1)
        If StrComp(baseName, nameBase, vbTextCompare) = 0 Then
            Dim r As Range
            Set r = SafeRefersToRange(nm)
            If Not r Is Nothing Then
                If r.Worksheet.Name = ws.Name Then
                    Set FindNamedRange = r
                    Exit Function
                End If
            End If
        End If
    Next nm
End Function

Public Function SafeRefersToRange(ByVal nm As Name) As Range
    On Error Resume Next
    Set SafeRefersToRange = nm.RefersToRange
    On Error GoTo 0
End Function
