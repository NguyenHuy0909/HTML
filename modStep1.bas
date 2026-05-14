Attribute VB_Name = "modStep1"
Option Explicit
' Step 1a: Align overlay ChartObjects to cover configured child chart groups
' Step 1b: Align overlay PlotAreas to match configured child chart groups
' Step 2 : Move model TextBoxes to configured overlay series lines and N:P target charts


Private Type StepChartGroup
    OverlayName As String
    ChildTopName As String
    ChildMiddleName As String
    ChildBottomName As String
    ScoreModel1Range As String
End Type

Private Type LabelPlacement
    Label        As Shape
    targetChart  As chartObject
    OverlayChart As chartObject
    ChartIdx     As Long     ' 1=top, 2=middle, 3=bottom
    SeriesWsX    As Double   ' worksheet X of the series vertical line
    modelIdx     As Long
    groupIdx     As Long
End Type

' =============================================================================
Sub Step1a_AlignChartObject()
' =============================================================================
    '
    On Error GoTo CleanFail

    Dim cfgWs As Worksheet
    Set cfgWs = ThisWorkbook.Sheets(CONFIG_SHEET_NAME)

    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets(CStr(modConfig.ReadConfigSetting(cfgWs, "DataSheetName", DATA_SHEET_NAME)))

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

    Dim cfgWs As Worksheet
    Set cfgWs = ThisWorkbook.Sheets(CONFIG_SHEET_NAME)

    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets(CStr(modConfig.ReadConfigSetting(cfgWs, "DataSheetName", DATA_SHEET_NAME)))

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
    Dim cfgWs As Worksheet
    Set cfgWs = ThisWorkbook.Sheets(CONFIG_SHEET_NAME)
    Dim BOTTOM_OFFSET_PT As Double
    BOTTOM_OFFSET_PT = CDbl(modConfig.ReadConfigSetting(cfgWs, "BottomOffsetPt", 3#))

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
    Const FIRST_MODEL As Long = 1
    Const MAX_MODEL As Long = 8
    Const LINE_HALF_W As Double = 0.75         ' 1.5pt line / 2

    On Error GoTo CleanFail

    Dim ws As Worksheet
    Dim cfgWs As Worksheet
    Set cfgWs = ThisWorkbook.Sheets(CONFIG_SHEET_NAME)

    Set ws = ThisWorkbook.Sheets(CStr(modConfig.ReadConfigSetting(cfgWs, "DataSheetName", DATA_SHEET_NAME)))

    Dim leftMargin As Double
    leftMargin = CDbl(modConfig.ReadConfigSetting(cfgWs, "LabelLeftMarginPt", 1))
    Dim rightMargin As Double
    rightMargin = CDbl(modConfig.ReadConfigSetting(cfgWs, "LabelRightMarginPt", 3))

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

        Dim allSeriesX() As Double
        ReDim allSeriesX(1 To modelCount)
        Dim sIdx As Long
        For sIdx = 1 To modelCount
            allSeriesX(sIdx) = ValueXToWsPos(overlay, GetVerticalLineX(overlay.Chart, sIdx))
        Next sIdx

        Dim placements() As LabelPlacement
        Dim placementCount As Long
        placementCount = 0

        Dim modelIdx As Long
        For modelIdx = FIRST_MODEL To modelCount
            Dim pl As LabelPlacement
            If MoveOneModelTextBox(ws, groups(groupIdx), overlay, topChart, middleChart, bottomChart, _
                                   groupIdx, modelIdx, LINE_HALF_W, allSeriesX, modelCount, leftMargin, rightMargin, pl) Then
                placementCount = placementCount + 1
                ReDim Preserve placements(1 To placementCount)
                placements(placementCount) = pl
                Set placements(placementCount).OverlayChart = overlay
                movedCount = movedCount + 1
            End If
        Next modelIdx

        If placementCount > 1 Then
            Dim labelGap As Double
            If leftMargin > rightMargin Then labelGap = leftMargin Else labelGap = rightMargin
            ResolveOverlaps placements, placementCount, labelGap
        End If
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
                                     ByVal lineHalfWidth As Double, _
                                     ByRef allSeriesX() As Double, _
                                     ByVal seriesCount As Long, _
                                     ByVal leftMargin As Double, _
                                     ByVal rightMargin As Double, _
                                     ByRef outPlacement As LabelPlacement) As Boolean
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
    Dim leftOfLine As Double: leftOfLine = wsX - lineHalfWidth - leftMargin - modelLabel.Width
    Dim rightOfLine As Double: rightOfLine = wsX + lineHalfWidth + rightMargin

    Dim hitsLeft As Long: hitsLeft = CountSeriesHits(leftOfLine, modelLabel.Width, modelIdx, allSeriesX, seriesCount, leftMargin)
    Dim hitsRight As Long: hitsRight = CountSeriesHits(rightOfLine, modelLabel.Width, modelIdx, allSeriesX, seriesCount, rightMargin)

    If hitsLeft <= hitsRight Then
        modelLabel.Left = leftOfLine
    Else
        modelLabel.Left = rightOfLine
    End If
    modelLabel.Top = FindClearY(targetChart, modelLabel.Left, modelLabel.Width, modelLabel.Height)

    Set outPlacement.Label = modelLabel
    Set outPlacement.targetChart = targetChart
    outPlacement.ChartIdx = targetChartIdx
    outPlacement.SeriesWsX = wsX
    outPlacement.modelIdx = modelIdx
    outPlacement.groupIdx = groupNumber

    Debug.Print "  Step2 [" & textBoxName & "] " & groupConfig.OverlayName & _
                " model=" & modelIdx & " target=" & targetChart.Name & _
                " x=" & Format$(xValue, "0.00") & _
                " L=" & Format$(modelLabel.Left, "0.00") & _
                " T=" & Format$(modelLabel.Top, "0.00")
    MoveOneModelTextBox = True
End Function

Private Sub ResolveOverlaps(ByRef placements() As LabelPlacement, _
                            ByVal cnt As Long, _
                            ByVal margin As Double)
    Dim maxPass As Long: maxPass = cnt * 3
    Dim pass As Long
    For pass = 1 To maxPass
        Dim anyMoved As Boolean: anyMoved = False
        Dim i As Long, j As Long
        For i = 1 To cnt
            For j = i + 1 To cnt
                If LabelsOverlap(placements(i).Label, placements(j).Label, margin) Then
                    NudgeApart placements(i), placements(j), margin
                    anyMoved = True
                End If
            Next j
        Next i
        If Not anyMoved Then Exit For
    Next pass
    Debug.Print "  ResolveOverlaps: " & pass - 1 & " passes"
End Sub

Private Function LabelsOverlap(ByVal a As Shape, ByVal b As Shape, ByVal margin As Double) As Boolean
    If a.Left + a.Width + margin <= b.Left Then Exit Function
    If b.Left + b.Width + margin <= a.Left Then Exit Function
    If a.Top + a.Height + margin <= b.Top Then Exit Function
    If b.Top + b.Height + margin <= a.Top Then Exit Function
    LabelsOverlap = True
End Function

Private Sub NudgeApart(ByRef plA As LabelPlacement, ByRef plB As LabelPlacement, ByVal margin As Double)
    Dim pa As PlotArea: Set pa = plA.OverlayChart.Chart.PlotArea
    Dim boundsTop As Double: boundsTop = plA.OverlayChart.Top + pa.InsideTop
    Dim boundsBot As Double: boundsBot = boundsTop + pa.InsideHeight

    Dim overlapV As Double
    overlapV = (plA.Label.Top + plA.Label.Height + margin) - plB.Label.Top
    If plA.Label.Top > plB.Label.Top Then
        overlapV = (plB.Label.Top + plB.Label.Height + margin) - plA.Label.Top
    End If
    If overlapV <= 0 Then Exit Sub

    Dim halfShift As Double: halfShift = overlapV / 2 + 0.5

    If plA.Label.Top <= plB.Label.Top Then
        Dim newTopA As Double: newTopA = plA.Label.Top - halfShift
        Dim newTopB As Double: newTopB = plB.Label.Top + halfShift
        If newTopA >= boundsTop And (newTopB + plB.Label.Height) <= boundsBot Then
            plA.Label.Top = newTopA
            plB.Label.Top = newTopB
            Debug.Print "    NudgeV: model " & plA.modelIdx & " up, model " & plB.modelIdx & " down"
            Exit Sub
        End If
    Else
        newTopA = plA.Label.Top + halfShift
        newTopB = plB.Label.Top - halfShift
        If (newTopA + plA.Label.Height) <= boundsBot And newTopB >= boundsTop Then
            plA.Label.Top = newTopA
            plB.Label.Top = newTopB
            Debug.Print "    NudgeV: model " & plA.modelIdx & " down, model " & plB.modelIdx & " up"
            Exit Sub
        End If
    End If

    If plA.Label.Left <= plB.Label.Left Then
        plB.Label.Left = plA.Label.Left + plA.Label.Width + margin
        Debug.Print "    NudgeH: model " & plB.modelIdx & " right"
    Else
        plA.Label.Left = plB.Label.Left + plB.Label.Width + margin
        Debug.Print "    NudgeH: model " & plA.modelIdx & " right"
    End If
End Sub

Private Function FindClearY(ByVal co As chartObject, _
                             ByVal lblLeft As Double, ByVal lblW As Double, _
                             ByVal lblH As Double) As Double
    Dim cht As Chart: Set cht = co.Chart
    Dim pa As PlotArea: Set pa = cht.PlotArea
    Dim ya As Axis: Set ya = cht.Axes(xlValue)
    Dim xa As Axis: Set xa = cht.Axes(xlCategory)

    Dim plotTop As Double: plotTop = co.Top + pa.InsideTop
    Dim plotBot As Double: plotBot = plotTop + pa.InsideHeight
    Dim yMin As Double: yMin = ya.MinimumScale
    Dim yMax As Double: yMax = ya.MaximumScale
    If yMax = yMin Then
        FindClearY = plotTop + pa.InsideHeight / 2 - lblH / 2
        Exit Function
    End If

    Dim xMinScale As Double: xMinScale = xa.MinimumScale
    Dim xMaxScale As Double: xMaxScale = xa.MaximumScale
    Dim plotL As Double: plotL = co.Left + pa.insideLeft
    Dim plotW As Double: plotW = pa.insideWidth

    Dim lblXMin As Double
    Dim lblXMax As Double
    If xMaxScale > xMinScale And plotW > 0 Then
        lblXMin = xMinScale + (lblLeft - plotL) / plotW * (xMaxScale - xMinScale)
        lblXMax = xMinScale + (lblLeft + lblW - plotL) / plotW * (xMaxScale - xMinScale)
    Else
        FindClearY = plotTop + pa.InsideHeight / 2 - lblH / 2
        Exit Function
    End If

    Dim dataYMin As Double: dataYMin = yMax
    Dim dataYMax As Double: dataYMax = yMin
    Dim hasData As Boolean

    Dim sr As Long
    For sr = 1 To cht.SeriesCollection.Count
        Dim xVals As Variant, yVals As Variant
        On Error Resume Next
        xVals = cht.SeriesCollection(sr).xValues
        yVals = cht.SeriesCollection(sr).Values
        On Error GoTo 0
        If Not IsEmpty(xVals) And Not IsEmpty(yVals) Then
            Dim pt As Long
            For pt = LBound(xVals) To UBound(xVals)
                If IsNumeric(xVals(pt)) And IsNumeric(yVals(pt)) Then
                    Dim xv As Double: xv = CDbl(xVals(pt))
                    If xv >= lblXMin And xv <= lblXMax Then
                        Dim yv As Double: yv = CDbl(yVals(pt))
                        If yv < dataYMin Then dataYMin = yv
                        If yv > dataYMax Then dataYMax = yv
                        hasData = True
                    End If
                End If
            Next pt
        End If
    Next sr

    If Not hasData Then
        FindClearY = plotTop + pa.InsideHeight / 2 - lblH / 2
        Exit Function
    End If

    Dim dataWsTop As Double
    dataWsTop = plotTop + (1 - (dataYMax - yMin) / (yMax - yMin)) * pa.InsideHeight
    Dim dataWsBot As Double
    dataWsBot = plotTop + (1 - (dataYMin - yMin) / (yMax - yMin)) * pa.InsideHeight

    Dim gapAbove As Double: gapAbove = dataWsTop - plotTop
    Dim gapBelow As Double: gapBelow = plotBot - dataWsBot

    Const DATA_MARGIN As Double = 3

    If gapBelow >= lblH + DATA_MARGIN Then
        FindClearY = dataWsBot + DATA_MARGIN
    ElseIf gapAbove >= lblH + DATA_MARGIN Then
        FindClearY = dataWsTop - lblH - DATA_MARGIN
    Else
        FindClearY = plotBot - lblH
    End If
End Function

Private Function CountSeriesHits(ByVal lblLeft As Double, ByVal lblWidth As Double, _
                                  ByVal skipIdx As Long, _
                                  ByRef seriesX() As Double, ByVal cnt As Long, _
                                  Optional ByVal HIT_MARGIN As Double = 2) As Long
    Dim lblRight As Double: lblRight = lblLeft + lblWidth
    Dim s As Long
    For s = 1 To cnt
        If s <> skipIdx Then
            If seriesX(s) > (lblLeft - HIT_MARGIN) And seriesX(s) < (lblRight + HIT_MARGIN) Then
                CountSeriesHits = CountSeriesHits + 1
            End If
        End If
    Next s
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

Private Function GetVerticalLineX(ByVal cht As Chart, ByVal seriesIdx As Long) As Double
    Dim xv As Variant
    xv = cht.SeriesCollection(seriesIdx).xValues
    GetVerticalLineX = CDbl(xv(LBound(xv)))
End Function

Private Function ValueXToWsPos(ByVal co As chartObject, ByVal xValue As Double) As Double
    Dim pa As PlotArea: Set pa = co.Chart.PlotArea
    Dim xa As Axis:     Set xa = co.Chart.Axes(xlCategory)
    Dim xMin As Double: xMin = xa.MinimumScale
    Dim xMax As Double: xMax = xa.MaximumScale
    If xMax = xMin Then Err.Raise vbObjectError + 1, , "Axis scale degenerate"

    Dim frac As Double
    frac = (xValue - xMin) / (xMax - xMin)
    ValueXToWsPos = co.Left + pa.insideLeft + frac * pa.insideWidth
End Function
