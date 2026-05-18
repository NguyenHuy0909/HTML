Attribute VB_Name = "modArrange"
Option Explicit

' =============================================================================
' modArrange — User-facing macros for chart arrangement and vertical line drawing.
'
' Public:
'   ArrangeChart — interactively arrange selected charts into a grid,
'                  then automatically redraws vertical lines (CreateLine).
'   CreateLine   — read ExportConfig table and draw one vertical line per
'                  X-value, spanning PlotArea of top chart to bottom chart.
'
' ArrangeChart usage:
'   1. Use "Select Objects" mode, click each chart in order.
'   2. Run ArrangeChart.
'   3. Enter number of rows; columns auto-calculated.
'   4. Charts placed column-first; first chart anchors position and size.
'   After placement, CreateLine runs automatically to keep lines in sync.
' =============================================================================

' =============================================================================
Public Sub ArrangeChart()
' =============================================================================
    On Error GoTo CleanFail

    Dim ws       As Worksheet
    Dim coList() As ChartObject
    Dim coCount  As Long
    Dim sr       As ShapeRange
    Dim co       As ChartObject
    Dim i        As Long
    Dim inp      As String
    Dim nRows    As Long
    Dim nCols    As Long
    Dim startL   As Double
    Dim startT   As Double
    Dim cellW    As Double
    Dim cellH    As Double
    Dim rowIdx   As Long
    Dim colIdx   As Long

    Set ws = ActiveSheet

    On Error Resume Next
    Set sr = Selection.ShapeRange
    On Error GoTo CleanFail

    If Not sr Is Nothing Then
        ReDim coList(1 To sr.count)
        For i = 1 To sr.count
            If sr(i).Type = msoChart Then
                On Error Resume Next
                Set co = ws.ChartObjects(sr(i).Name)
                On Error GoTo CleanFail
                If Not co Is Nothing Then
                    coCount = coCount + 1
                    Set coList(coCount) = co
                    Set co = Nothing
                End If
            End If
        Next i

    ElseIf TypeName(Selection) = "ChartObject" Then
        coCount = 1
        ReDim coList(1 To 1)
        Set coList(1) = Selection

    Else
        MsgBox "Please select at least one chart before running." & vbCrLf & _
               "(Use Select Objects mode, then click each chart in order)" & vbCrLf & vbCrLf & _
               "Current selection type: " & TypeName(Selection), _
               vbExclamation, "ArrangeChart"
        Exit Sub
    End If

    If coCount = 0 Then
        MsgBox "No charts found in the current selection." & vbCrLf & _
               "Make sure you select chart objects (not a cell range).", _
               vbExclamation, "ArrangeChart"
        Exit Sub
    End If

    inp = InputBox("Enter number of rows:" & vbCrLf & vbCrLf & _
                   "Charts selected: " & coCount, "ArrangeChart")
    If Len(Trim(inp)) = 0 Then Exit Sub

    If Not IsNumeric(inp) Then
        MsgBox "Please enter a whole number.", vbExclamation, "ArrangeChart"
        Exit Sub
    End If

    nRows = CLng(inp)
    If nRows < 1 Then
        MsgBox "Number of rows must be >= 1.", vbExclamation, "ArrangeChart"
        Exit Sub
    End If
    If nRows > coCount Then nRows = coCount

    nCols = (coCount + nRows - 1) \ nRows

    startL = coList(1).Left
    startT = coList(1).Top
    cellW = coList(1).Width
    cellH = coList(1).Height

    For i = 1 To coCount
        rowIdx = (i - 1) Mod nRows
        colIdx = (i - 1) \ nRows
        coList(i).Left = startL + colIdx * cellW
        coList(i).Top = startT + rowIdx * cellH
        coList(i).Width = cellW
        coList(i).Height = cellH
        Debug.Print "  [" & rowIdx + 1 & "," & colIdx + 1 & "] " & coList(i).Name & _
                    "  L=" & Format$(coList(i).Left, "0.0") & _
                    "  T=" & Format$(coList(i).Top, "0.0")
    Next i

    Debug.Print "=== ArrangeChart done: " & coCount & " charts -> " & _
                nRows & "x" & nCols & " grid ==="

    Call CreateLine
    Exit Sub

CleanFail:
    MsgBox "Error in ArrangeChart:" & vbCrLf & _
           Err.Number & " - " & Err.Description, vbCritical, "ArrangeChart"
End Sub

' =============================================================================
Public Sub CreateLine()
' =============================================================================
    On Error GoTo CleanFail

    Dim cfgWs As Worksheet
    Set cfgWs = ThisWorkbook.Worksheets(modConfig.CFG_SHEET_NAME)

    Dim xOffsetRgt As Double
    xOffsetRgt = ReadConfigCalib(cfgWs, "OffsetRgt")

    Dim xOffsetBot As Double
    xOffsetBot = ReadConfigCalib(cfgWs, "OffsetBot")

    Dim xLineLen As Double
    xLineLen = ReadConfigCalib(cfgWs, "Line length")

    ' Line colors — hardcoded from ExportConfig H9:H11 fill colors
    Dim lineColors(0 To 2) As Long
    lineColors(0) = 255       ' H9  RGB(255,   0,   0) — Red
    lineColors(1) = 16711680  ' H10 RGB(  0,   0, 255) — Blue
    lineColors(2) = 5287936   ' H11 RGB(  0, 176,  80) — Green

    Dim colSheet As Long, colGroup As Long, colPoints As Long, colXvalue As Long
    colSheet = FindHeaderColumn(cfgWs, modConfig.HDR_SHEET)
    colGroup = FindHeaderColumn(cfgWs, modConfig.HDR_GROUP)
    colPoints = FindHeaderColumn(cfgWs, modConfig.HDR_POINTS)
    colXvalue = FindHeaderColumn(cfgWs, modConfig.HDR_XVALUE)
    If colSheet = 0 Or colPoints = 0 Or colXvalue = 0 Then
        MsgBox "ExportConfig: missing required header(s) on row " & modConfig.HDR_ROW & _
               " (need: " & modConfig.HDR_SHEET & ", " & modConfig.HDR_POINTS & ", " & modConfig.HDR_XVALUE & ")", _
               vbExclamation, "CreateLine"
        Exit Sub
    End If

    Dim lastRow As Long
    lastRow = cfgWs.Cells(cfgWs.rows.count, colPoints).End(xlUp).row
    If lastRow < modConfig.HDR_ROW + 1 Then
        MsgBox "ExportConfig: no data rows found.", vbExclamation, "CreateLine"
        Exit Sub
    End If

    Dim curSheet  As String
    Dim totalLine As Long

    Dim r As Long
    For r = modConfig.HDR_ROW + 1 To lastRow
        Dim aVal As String, bVal As String, cVal As String, dVal As String
        aVal = Trim$(CStr(cfgWs.Cells(r, colSheet).Value))
        bVal = Trim$(CStr(cfgWs.Cells(r, colGroup).Value))
        cVal = Trim$(CStr(cfgWs.Cells(r, colPoints).Value))
        dVal = Trim$(CStr(cfgWs.Cells(r, colXvalue).Value))

        If Len(aVal) = 0 And Len(cVal) = 0 Then Exit For

        If Len(aVal) > 0 Then curSheet = aVal
        If Len(curSheet) = 0 Or Len(cVal) = 0 Then GoTo NextRow

        Dim ws As Worksheet
        Set ws = Nothing
        On Error Resume Next
        Set ws = ThisWorkbook.Worksheets(curSheet)
        On Error GoTo CleanFail
        If ws Is Nothing Then
            Debug.Print "CreateLine: sheet not found - " & curSheet
            GoTo NextRow
        End If

        Dim topName As String, botName As String
        ParsePointGroup cVal, topName, botName
        If Len(topName) = 0 Or Len(botName) = 0 Then
            Debug.Print "CreateLine: bad POINT Group at row " & r & " - " & cVal
            GoTo NextRow
        End If

        Dim drawn As Long
        drawn = ProcessGroup(ws, topName, botName, dVal, _
                             "Line_" & curSheet & "_G" & bVal, _
                             xOffsetRgt, xOffsetBot, xLineLen, lineColors)
        totalLine = totalLine + drawn

NextRow:
    Next r

    MsgBox "CreateLine done. " & totalLine & " lines created.", _
           vbInformation, "CreateLine"
    Exit Sub

CleanFail:
    MsgBox "CreateLine error:" & vbCrLf & Err.Number & " - " & Err.Description, _
           vbCritical, "CreateLine"
End Sub

' =============================================================================
Private Function ProcessGroup(ByVal ws As Worksheet, _
                              ByVal topName As String, _
                              ByVal botName As String, _
                              ByVal addrCSV As String, _
                              ByVal lineNameBase As String, _
                              ByVal xOffsetRgt As Double, _
                              ByVal xOffsetBot As Double, _
                              ByVal xLineLen As Double, _
                              ByRef lineColors() As Long) As Long
    Dim topCo As ChartObject, botCo As ChartObject
    On Error Resume Next
    Set topCo = ws.ChartObjects(topName)
    Set botCo = ws.ChartObjects(botName)
    On Error GoTo 0
    If topCo Is Nothing Or botCo Is Nothing Then
        Debug.Print "ProcessGroup: chart missing on " & ws.Name & _
                    " (top=" & topName & " bot=" & botName & ")"
        Exit Function
    End If

    Dim topCht As Chart
    Set topCht = topCo.Chart

    Dim xMin As Double, xMax As Double
    If Not ReadChartXScale(topCht, xMin, xMax) Then
        Debug.Print "ProcessGroup: cannot read X axis on " & topName
        Exit Function
    End If
    If xMax = xMin Then
        Debug.Print "ProcessGroup: xMin = xMax on " & topName
        Exit Function
    End If

    Dim paL As Double, paW As Double
    paL = topCo.Left + topCht.PlotArea.insideLeft
    paW = topCht.PlotArea.insideWidth

    Dim lineTop As Double, lineBot As Double
    lineTop = topCo.Top + topCht.PlotArea.InsideTop + HalfYLabelHeight(topCht) - xLineLen
    lineBot = botCo.Top + botCo.Chart.PlotArea.InsideTop + _
              botCo.Chart.PlotArea.InsideHeight + xOffsetBot + xLineLen

    Dim addrs() As String
    addrs = SplitTrim(addrCSV, modConfig.SEPARATOR)

    Dim i As Long, drawn As Long
    For i = LBound(addrs) To UBound(addrs)
        Dim addr As String: addr = addrs(i)
        If Len(addr) = 0 Then GoTo NextAddr

        Dim rngVal As Variant
        On Error Resume Next
        rngVal = ws.Range(addr).Value
        On Error GoTo 0
        If Not IsNumeric(rngVal) Then
            Debug.Print "ProcessGroup: " & addr & " is not numeric on " & ws.Name
            GoTo NextAddr
        End If

        Dim xv As Double, frac As Double, wsX As Double
        xv = CDbl(rngVal)
        frac = (xv - xMin) / (xMax - xMin)
        wsX = paL + frac * paW + xOffsetRgt

        DrawVerticalLine ws, wsX, lineTop, lineBot, _
                         lineNameBase & "_" & (i + 1), _
                         lineColors(i Mod 3)
        drawn = drawn + 1
NextAddr:
    Next i

    ProcessGroup = drawn
End Function

Private Sub DrawVerticalLine(ByVal ws As Worksheet, _
                             ByVal x As Double, _
                             ByVal yTop As Double, _
                             ByVal yBot As Double, _
                             ByVal lnName As String, _
                             ByVal lineColor As Long)
    Const MARK_SIZE As Double = 9

    On Error Resume Next
    ws.Shapes(lnName).Delete
    ws.Shapes(lnName & "_T").Delete
    ws.Shapes(lnName & "_B").Delete
    On Error GoTo 0

    ' Dashed line, weight 2
    Dim ln As Shape
    Set ln = ws.Shapes.AddLine(x, yTop, x, yBot)
    ln.Name = lnName
    With ln.Line
        .ForeColor.RGB = lineColor
        .Weight = 2
        .DashStyle = msoLineDash
    End With

    ' Top circle marker
    Dim mkT As Shape
    Set mkT = ws.Shapes.AddShape(msoShapeOval, _
                                  x - MARK_SIZE / 2, yTop - MARK_SIZE / 2, _
                                  MARK_SIZE, MARK_SIZE)
    mkT.Name = lnName & "_T"
    mkT.Line.Visible = msoFalse
    mkT.Fill.ForeColor.RGB = lineColor

    ' Bottom circle marker
    Dim mkB As Shape
    Set mkB = ws.Shapes.AddShape(msoShapeOval, _
                                  x - MARK_SIZE / 2, yBot - MARK_SIZE / 2, _
                                  MARK_SIZE, MARK_SIZE)
    mkB.Name = lnName & "_B"
    mkB.Line.Visible = msoFalse
    mkB.Fill.ForeColor.RGB = lineColor
End Sub

Private Sub ParsePointGroup(ByVal s As String, _
                            ByRef topName As String, _
                            ByRef botName As String)
    Dim parts() As String
    parts = SplitTrim(s, modConfig.SEPARATOR)
    If UBound(parts) < LBound(parts) Then
        topName = "": botName = "": Exit Sub
    End If
    topName = parts(LBound(parts))
    botName = parts(UBound(parts))
End Sub

Private Function SplitTrim(ByVal s As String, ByVal sep As String) As String()
    Dim parts() As String
    parts = Split(s, sep)
    Dim i As Long
    For i = LBound(parts) To UBound(parts)
        parts(i) = Trim$(parts(i))
    Next i
    SplitTrim = parts
End Function

Private Function HalfYLabelHeight(ByVal cht As Chart) As Double
    On Error Resume Next
    Dim fontSize As Double
    fontSize = cht.Axes(xlValue, xlPrimary).TickLabels.Font.Size
    If fontSize <= 0 Then fontSize = 9
    On Error GoTo 0
    HalfYLabelHeight = fontSize / 2
End Function

Private Function ReadChartXScale(ByVal cht As Chart, _
                                 ByRef xMin As Double, _
                                 ByRef xMax As Double) As Boolean
    Dim ax As Axis
    On Error Resume Next
    Set ax = cht.Axes(xlCategory, xlPrimary)
    If ax Is Nothing Then Set ax = cht.Axes(xlValue, xlPrimary)
    On Error GoTo 0
    If ax Is Nothing Then
        ReadChartXScale = False
        Exit Function
    End If

    On Error Resume Next
    xMin = ax.MinimumScale
    xMax = ax.MaximumScale
    On Error GoTo 0
    ReadChartXScale = (xMax > xMin)
End Function

Private Function ReadConfigCalib(ByVal cfgWs As Worksheet, _
                                 ByVal label As String) As Double
    Dim anchor As Range
    Set anchor = FindAnchor(cfgWs, modConfig.SCALE_ANCHOR)
    If anchor Is Nothing Then Exit Function

    Dim r0 As Long, c0 As Long
    r0 = anchor.row
    c0 = anchor.Column

    Dim wantLbl As String
    wantLbl = LCase$(Trim$(label))

    Dim r As Long
    For r = r0 + 1 To r0 + 20
        Dim lbl As String
        lbl = LCase$(Trim$(CStr(cfgWs.Cells(r, c0).Value)))
        If lbl = wantLbl Then
            Dim v As Variant
            v = cfgWs.Cells(r, c0 + 1).Value
            If IsNumeric(v) Then ReadConfigCalib = CDbl(v)
            Exit Function
        End If
    Next r
End Function

Private Function FindAnchor(ByVal ws As Worksheet, _
                            ByVal key As String) As Range
    Dim found As Range
    On Error Resume Next
    Set found = ws.Cells.Find(What:=key, LookIn:=xlValues, _
                              LookAt:=xlWhole, MatchCase:=False)
    On Error GoTo 0
    Set FindAnchor = found
End Function

Private Function FindHeaderColumn(ByVal ws As Worksheet, _
                                  ByVal headerText As String) As Long
    Dim found As Range
    On Error Resume Next
    Set found = ws.rows(modConfig.HDR_ROW).Find(What:=headerText, _
                                                LookIn:=xlValues, _
                                                LookAt:=xlWhole, _
                                                MatchCase:=False)
    On Error GoTo 0
    If Not found Is Nothing Then FindHeaderColumn = found.Column
End Function
