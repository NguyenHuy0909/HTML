Option Explicit
' Step 1a: Align overlay ChartObjects to cover configured child chart groups
' Step 1b: Align overlay PlotAreas to match configured child chart groups
' Step 2 : Move model TextBoxes to configured overlay series lines and N:P target charts

Private Const DATA_SHEET_NAME As String = "Sheet1"
Private Const CONFIG_SHEET_NAME As String = "ExportConfig"

Private Type StepChartGroup
    OverlayName As String
    ChildTopName As String
    ChildMiddleName As String
    ChildBottomName As String
    ScoreModel1Range As String
End Type

' =============================================================================
Sub Step1a_AlignChartObject()
' =============================================================================
    '
    On Error GoTo CleanFail

    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets(DATA_SHEET_NAME)

    Dim cfgWs As Worksheet
    Set cfgWs = ThisWorkbook.Sheets(CONFIG_SHEET_NAME)

    Dim groups() As StepChartGroup
    Dim groupCount As Long
    groupCount = ReadStepChartGroups(cfgWs, groups)
    If groupCount = 0 Then
        Debug.Print "Step1a: no GroupImage chart config found in " & CONFIG_SHEET_NAME
        Exit Sub
    End If

    Dim groupIdx As Long
    Dim alignedCount As Long
    For groupIdx = 1 To groupCount
        If AlignOneOverlayChartObject(ws, groups(groupIdx)) Then
            alignedCount = alignedCount + 1
        End If
    Next groupIdx

    Debug.Print "=== Step1a: ChartObject alignment done. aligned=" & alignedCount & "/" & groupCount
    Exit Sub

CleanFail:
    Debug.Print "Step1a ERROR: " & Err.Number & " - " & Err.Description
End Sub

' =============================================================================
Sub Step1b_AlignPlotArea()
' =============================================================================
    '
    On Error GoTo CleanFail

    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets(DATA_SHEET_NAME)

    Dim cfgWs As Worksheet
    Set cfgWs = ThisWorkbook.Sheets(CONFIG_SHEET_NAME)

    Dim groups() As StepChartGroup
    Dim groupCount As Long
    groupCount = ReadStepChartGroups(cfgWs, groups)
    If groupCount = 0 Then
        Debug.Print "Step1b: no GroupImage chart config found in " & CONFIG_SHEET_NAME
        Exit Sub
    End If

    Dim groupIdx As Long
    Dim alignedCount As Long
    For groupIdx = 1 To groupCount
        If AlignOneOverlayPlotArea(ws, groups(groupIdx)) Then
            alignedCount = alignedCount + 1
        End If
    Next groupIdx

    Debug.Print "=== Step1b: PlotArea alignment done. aligned=" & alignedCount & "/" & groupCount
    Exit Sub

CleanFail:
    Debug.Print "Step1b ERROR: " & Err.Number & " - " & Err.Description
End Sub

Private Function AlignOneOverlayChartObject(ByVal ws As Worksheet, ByRef groupConfig As StepChartGroup) As Boolean
    Dim overlay As chartObject, topChart As chartObject
    Dim middleChart As chartObject, bottomChart As chartObject
    If Not ResolveStep1Group(ws, groupConfig, overlay, topChart, middleChart, bottomChart) Then Exit Function

    Dim targetLeft As Double
    Dim targetTop As Double
    Dim targetRight As Double
    Dim targetBottom As Double
    targetLeft = Application.Min(topChart.Left, middleChart.Left, bottomChart.Left)
    targetTop = Application.Min(topChart.Top, middleChart.Top, bottomChart.Top)
    targetRight = Application.Max(topChart.Left + topChart.Width, _
                                  middleChart.Left + middleChart.Width, _
                                  bottomChart.Left + bottomChart.Width)
    targetBottom = Application.Max(topChart.Top + topChart.Height, _
                                   middleChart.Top + middleChart.Height, _
                                   bottomChart.Top + bottomChart.Height)

    overlay.Left = targetLeft
    overlay.Top = targetTop
    overlay.Width = targetRight - targetLeft
    overlay.Height = targetBottom - targetTop

    Debug.Print "  Step1a [" & overlay.Name & "] target L=" & Format$(targetLeft, "0.00") & _
                " T=" & Format$(targetTop, "0.00") & _
                " W=" & Format$(overlay.Width, "0.00") & _
                " H=" & Format$(overlay.Height, "0.00")
    AlignOneOverlayChartObject = True
End Function

Private Function AlignOneOverlayPlotArea(ByVal ws As Worksheet, ByRef groupConfig As StepChartGroup) As Boolean
    Const MAX_ADJUST_ATTEMPTS As Long = 5
    Const ALIGN_TOLERANCE_PT As Double = 0.05
    Const BOTTOM_OFFSET_PT As Double = 3#   ' hiá»‡u chá»‰nh cáº¡nh dÆ°á»›i overlay (dÆ°Æ¡ng = xuá»‘ng)

    Dim overlay As chartObject, topChart As chartObject
    Dim middleChart As chartObject, bottomChart As chartObject
    If Not ResolveStep1Group(ws, groupConfig, overlay, topChart, middleChart, bottomChart) Then Exit Function

    Dim wsInsideLeft As Double
    Dim wsInsideRight As Double
    Dim wsInsideTop As Double
    Dim wsInsideBottom As Double
    wsInsideLeft = topChart.Left + topChart.Chart.PlotArea.insideLeft
    wsInsideRight = wsInsideLeft + topChart.Chart.PlotArea.insideWidth
    wsInsideTop = topChart.Top + topChart.Chart.PlotArea.InsideTop
    wsInsideBottom = bottomChart.Top + bottomChart.Chart.PlotArea.InsideTop + _
                     bottomChart.Chart.PlotArea.InsideHeight + BOTTOM_OFFSET_PT

    With overlay.Chart.PlotArea
        .Left = wsInsideLeft - overlay.Left
        .Top = wsInsideTop - overlay.Top
        .Width = wsInsideRight - wsInsideLeft
        .Height = wsInsideBottom - wsInsideTop
    End With

    Dim pa As PlotArea
    Dim attempt As Long
    For attempt = 1 To MAX_ADJUST_ATTEMPTS
        Set pa = overlay.Chart.PlotArea

        Dim actualLeft As Double
        Dim actualRight As Double
        Dim actualTop As Double
        Dim actualBottom As Double
        actualLeft = overlay.Left + pa.insideLeft
        actualRight = actualLeft + pa.insideWidth
        actualTop = overlay.Top + pa.InsideTop
        actualBottom = actualTop + pa.InsideHeight

        Dim deltaLeft As Double
        Dim deltaRight As Double
        Dim deltaTop As Double
        Dim deltaBottom As Double
        deltaLeft = wsInsideLeft - actualLeft
        deltaRight = wsInsideRight - actualRight
        deltaTop = wsInsideTop - actualTop
        deltaBottom = wsInsideBottom - actualBottom

        If Abs(deltaLeft) <= ALIGN_TOLERANCE_PT And _
           Abs(deltaRight) <= ALIGN_TOLERANCE_PT And _
           Abs(deltaTop) <= ALIGN_TOLERANCE_PT And _
           Abs(deltaBottom) <= ALIGN_TOLERANCE_PT Then
            Exit For
        End If

        With overlay.Chart.PlotArea
            .Left = .Left + deltaLeft
            .Top = .Top + deltaTop
            .Width = .Width + deltaRight - deltaLeft
            .Height = .Height + deltaBottom - deltaTop
        End With
    Next attempt

    Set pa = overlay.Chart.PlotArea
    Debug.Print "  Step1b [" & overlay.Name & "] PA L=" & Format$(overlay.Left + pa.insideLeft, "0.00") & _
                " R=" & Format$(overlay.Left + pa.insideLeft + pa.insideWidth, "0.00") & _
                " T=" & Format$(overlay.Top + pa.InsideTop, "0.00") & _
                " B=" & Format$(overlay.Top + pa.InsideTop + pa.InsideHeight, "0.00")

    AlignOneOverlayPlotArea = True
End Function

Private Function ResolveStep1Group(ByVal ws As Worksheet, ByRef groupConfig As StepChartGroup, _
                                   ByRef overlay As chartObject, _
                                   ByRef topChart As chartObject, _
                                   ByRef middleChart As chartObject, _
                                   ByRef bottomChart As chartObject) As Boolean
    Set overlay = TryGetChartObject(ws, groupConfig.OverlayName)
    Set topChart = TryGetChartObject(ws, groupConfig.ChildTopName)
    Set middleChart = TryGetChartObject(ws, groupConfig.ChildMiddleName)
    Set bottomChart = TryGetChartObject(ws, groupConfig.ChildBottomName)

    If overlay Is Nothing Or topChart Is Nothing Or middleChart Is Nothing Or bottomChart Is Nothing Then
        Debug.Print "  SKIP Step1 group [" & groupConfig.OverlayName & "]: missing chart in config " & _
                    groupConfig.OverlayName & " | " & groupConfig.ChildTopName & " | " & _
                    groupConfig.ChildMiddleName & " | " & groupConfig.ChildBottomName
        Exit Function
    End If

    ResolveStep1Group = True
End Function

Private Function ReadStepChartGroups(ByVal cfgWs As Worksheet, ByRef groups() As StepChartGroup) As Long
    Const FIRST_CONFIG_ROW As Long = 2
    Const SHAPE_NAME_COL As Long = 1
    Const SOURCE_TYPE_COL As Long = 3
    Const SOURCE_REF_COL As Long = 4
    Const SCORE_RANGE_COL As Long = 9

    Dim rowIdx As Long
    rowIdx = FIRST_CONFIG_ROW
    Do While Len(Trim$(CStr(cfgWs.Cells(rowIdx, SHAPE_NAME_COL).Value))) > 0
        If StrComp(Trim$(CStr(cfgWs.Cells(rowIdx, SOURCE_TYPE_COL).Value)), "GroupImage", vbTextCompare) = 0 Then
            Dim parsedGroup As StepChartGroup
            If TryParseStepChartGroup(CStr(cfgWs.Cells(rowIdx, SOURCE_REF_COL).Value), parsedGroup) Then
                parsedGroup.ScoreModel1Range = Trim$(CStr(cfgWs.Cells(rowIdx, SCORE_RANGE_COL).Value))
                ReadStepChartGroups = ReadStepChartGroups + 1
                ReDim Preserve groups(1 To ReadStepChartGroups)
                groups(ReadStepChartGroups) = parsedGroup
            Else
                Debug.Print "  WARNING [ExportConfig row " & rowIdx & "]: invalid GroupImage SourceRef"
            End If
        End If
        rowIdx = rowIdx + 1
    Loop
End Function

Private Function TryParseStepChartGroup(ByVal sourceRef As String, ByRef parsedGroup As StepChartGroup) As Boolean
    Dim parts() As String
    parts = Split(sourceRef, "|")

    Dim childCount As Long
    Dim idx As Long
    For idx = LBound(parts) To UBound(parts)
        Dim chartName As String
        chartName = Trim$(parts(idx))
        If Len(chartName) = 0 Then GoTo NextPart

        If ChartNumberFromName(chartName) >= 100 Then
            parsedGroup.OverlayName = chartName
        Else
            childCount = childCount + 1
            Select Case childCount
                Case 1: parsedGroup.ChildTopName = chartName
                Case 2: parsedGroup.ChildMiddleName = chartName
                Case 3: parsedGroup.ChildBottomName = chartName
            End Select
        End If
NextPart:
    Next idx

    TryParseStepChartGroup = Len(parsedGroup.OverlayName) > 0 And childCount >= 3
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

Private Function TryGetChartObject(ByVal ws As Worksheet, ByVal chartName As String) As chartObject
    On Error Resume Next
    Set TryGetChartObject = ws.chartObjects(chartName)
    On Error GoTo 0
End Function

' =============================================================================
Sub Step2_MoveShapesToMaxY()
' =============================================================================
    '
    Const FIRST_MODEL As Long = 1
    Const MAX_MODEL As Long = 8
    Const LINE_HALF_W As Double = 0.75         ' 1.5pt line / 2

    On Error GoTo CleanFail

    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets(DATA_SHEET_NAME)

    Dim cfgWs As Worksheet
    Set cfgWs = ThisWorkbook.Sheets(CONFIG_SHEET_NAME)

    Dim groups() As StepChartGroup
    Dim groupCount As Long
    groupCount = ReadStepChartGroups(cfgWs, groups)
    If groupCount = 0 Then
        Debug.Print "Step2: no GroupImage chart config found in " & CONFIG_SHEET_NAME
        Exit Sub
    End If

    Dim movedCount As Long
    Dim groupIdx As Long
    For groupIdx = 1 To groupCount
        Dim overlay As chartObject
        Dim topChart As chartObject
        Dim middleChart As chartObject
        Dim bottomChart As chartObject
        If Not ResolveStep1Group(ws, groups(groupIdx), overlay, topChart, middleChart, bottomChart) Then GoTo NextGroup
        If Len(groups(groupIdx).ScoreModel1Range) = 0 Then
            Debug.Print "  WARNING [" & overlay.Name & "]: missing Step2Model1ScoreRange in ExportConfig"
            GoTo NextGroup
        End If

        Dim modelCount As Long
        modelCount = overlay.Chart.SeriesCollection.Count
        If modelCount > MAX_MODEL Then
            Debug.Print "  WARNING [" & overlay.Name & "]: series count " & modelCount & _
                        " exceeds supported TextBox models 1-" & MAX_MODEL
            modelCount = MAX_MODEL
        End If

        Dim modelIdx As Long
        For modelIdx = FIRST_MODEL To modelCount
            If MoveOneModelTextBox(ws, groups(groupIdx), overlay, topChart, middleChart, bottomChart, _
                                   groupIdx, modelIdx, LINE_HALF_W) Then
                movedCount = movedCount + 1
            End If
        Next modelIdx
NextGroup:
    Next groupIdx

    Debug.Print "=== Step2: MoveShapesToMaxY done. moved=" & movedCount
    Exit Sub

CleanFail:
    Debug.Print "Step2 ERROR: " & Err.Number & " - " & Err.Description
End Sub

Private Function MoveOneModelTextBox(ByVal ws As Worksheet, _
                                     ByRef groupConfig As StepChartGroup, _
                                     ByVal overlay As chartObject, _
                                     ByVal topChart As chartObject, _
                                     ByVal middleChart As chartObject, _
                                     ByVal bottomChart As chartObject, _
                                     ByVal groupNumber As Long, _
                                     ByVal modelIdx As Long, _
                                     ByVal lineHalfWidth As Double) As Boolean
    Dim textBoxName As String
    textBoxName = "TextBox " & CStr(modelIdx * 10 + groupNumber)

    Dim sourceLabel As Shape
    Set sourceLabel = TryGetWorksheetShape(ws, textBoxName)
    If sourceLabel Is Nothing Then
        Debug.Print "  WARNING [" & overlay.Name & "]: missing " & textBoxName
        Exit Function
    End If

    Dim targetChartIdx As Long
    targetChartIdx = MaxIndexInConfiguredRange(ws, groupConfig.ScoreModel1Range, modelIdx)
    If targetChartIdx < 1 Then
        Debug.Print "  WARNING [" & overlay.Name & "]: no valid score in " & _
                    groupConfig.ScoreModel1Range & " for model " & modelIdx
        Exit Function
    End If

    Dim targetChart As chartObject
    Select Case targetChartIdx
        Case 1: Set targetChart = topChart
        Case 2: Set targetChart = middleChart
        Case 3: Set targetChart = bottomChart
    End Select

    Dim xValue As Double
    xValue = GetVerticalLineX(overlay.Chart, modelIdx)

    Dim wsX As Double
    wsX = ValueXToWsPos(overlay, xValue)

    Dim modelLabel As Shape
    Set modelLabel = CreateStep2ModelTextBoxCopy(ws, sourceLabel)

    Dim pa As PlotArea
    Set pa = targetChart.Chart.PlotArea
    modelLabel.Left = wsX + lineHalfWidth - modelLabel.Width
    modelLabel.Top = targetChart.Top + pa.InsideTop + pa.InsideHeight / 2 - modelLabel.Height / 2

    Debug.Print "  Step2 [" & textBoxName & "] " & groupConfig.OverlayName & _
                " model=" & modelIdx & " target=" & targetChart.Name & _
                " x=" & Format$(xValue, "0.00") & _
                " L=" & Format$(modelLabel.Left, "0.00") & _
                " T=" & Format$(modelLabel.Top, "0.00")
    MoveOneModelTextBox = True
End Function

Private Function CreateStep2ModelTextBoxCopy(ByVal ws As Worksheet, ByVal sourceLabel As Shape) As Shape
    Dim copyName As String
    copyName = Step2ModelTextBoxCopyName(sourceLabel.Name)

    DeleteWorksheetShapeByName ws, copyName

    Set CreateStep2ModelTextBoxCopy = sourceLabel.Duplicate
    CreateStep2ModelTextBoxCopy.Name = copyName
End Function

Private Function Step2ModelTextBoxCopyName(ByVal sourceName As String) As String
    Step2ModelTextBoxCopyName = "Step2_" & Replace$(sourceName, " ", "_")
End Function

Private Sub DeleteWorksheetShapeByName(ByVal ws As Worksheet, ByVal shapeName As String)
    Dim oldShape As Shape
    Set oldShape = TryGetWorksheetShape(ws, shapeName)
    If Not oldShape Is Nothing Then oldShape.Delete
End Sub

Private Function MaxIndexInConfiguredRange(ByVal ws As Worksheet, _
                                           ByVal model1RangeAddress As String, _
                                           ByVal modelIdx As Long) As Long
    Dim model1Range As Range
    Set model1Range = ws.Range(model1RangeAddress)

    Dim scoreRange As Range
    Set scoreRange = model1Range.Offset(modelIdx - 1, 0)

    Dim bestValue As Double
    Dim hasValue As Boolean
    Dim idx As Long
    For idx = 1 To scoreRange.Columns.Count
        Dim cellValue As Variant
        cellValue = scoreRange.Cells(1, idx).Value
        If IsNumeric(cellValue) And Len(CStr(cellValue)) > 0 Then
            If Not hasValue Or CDbl(cellValue) > bestValue Then
                bestValue = CDbl(cellValue)
                MaxIndexInConfiguredRange = idx
                hasValue = True
            End If
        End If
    Next idx
End Function

Private Function TryGetWorksheetShape(ByVal ws As Worksheet, ByVal shapeName As String) As Shape
    On Error Resume Next
    Set TryGetWorksheetShape = ws.Shapes(shapeName)
    On Error GoTo 0
End Function

' -----------------------------------------------------------------------------
Private Function GetVerticalLineX(ByVal cht As Chart, ByVal seriesIdx As Long) As Double
' Tra ve gia tri X cua vertical line (gia su XValues(1) = XValues(2))
    Dim xv As Variant
    xv = cht.SeriesCollection(seriesIdx).xValues
    GetVerticalLineX = CDbl(xv(LBound(xv)))
End Function

' -----------------------------------------------------------------------------
Private Function ValueXToWsPos(ByVal co As chartObject, ByVal xValue As Double) As Double
' Map data X value -> worksheet position dua tren axis scale + InsidePlotArea
    Dim pa As PlotArea: Set pa = co.Chart.PlotArea
    Dim xa As Axis:     Set xa = co.Chart.Axes(xlCategory)
    Dim xMin As Double: xMin = xa.MinimumScale
    Dim xMax As Double: xMax = xa.MaximumScale
    If xMax = xMin Then Err.Raise vbObjectError + 1, , "Axis scale degenerate"

    Dim frac As Double
    frac = (xValue - xMin) / (xMax - xMin)
    ValueXToWsPos = co.Left + pa.insideLeft + frac * pa.insideWidth
End Function
