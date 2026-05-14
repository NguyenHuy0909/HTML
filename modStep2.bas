Attribute VB_Name = "modStep2"
Option Explicit

' Step 2: Move Blue/Orange aligned with ch138 series lines
' X: parse ch138 series formula -> read first X cell -> convert via ch138 axis + InsidePlotArea
' Y: maxVal from N2:P2/N3:P3    -> convert via ch138 axis + InsidePlotArea (same coord system)
' Series fixed: Blue=Series1, Orange=Series2 in ch138

Sub Step2_MoveShapes()

    Const SHEET_NAME   As String = "Sheet1"
    Const CH138_NAME   As String = "Chart 138"
    Const CHART1_NAME  As String = "Chart 1"
    Const CHART2_NAME  As String = "Chart 2"
    Const CHART3_NAME  As String = "Chart 3"
    Const BLUE_SHAPE   As String = "Blue"
    Const ORANGE_SHAPE As String = "Orange"
    Const START_COL    As Long = 14     ' N=Chart1, O=Chart2, P=Chart3
    Const BLUE_ROW     As Long = 2      ' N2:P2 for Blue
    Const ORANGE_ROW   As Long = 3      ' N3:P3 for Orange

    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets(SHEET_NAME)

    Dim co138 As chartObject
    Set co138 = ws.chartObjects(CH138_NAME)

    Dim coArr(1 To 3) As chartObject
    Set coArr(1) = ws.chartObjects(CHART1_NAME)
    Set coArr(2) = ws.chartObjects(CHART2_NAME)
    Set coArr(3) = ws.chartObjects(CHART3_NAME)

    Dim blueIdx   As Long, blueMaxVal   As Double
    Dim orangeIdx As Long, orangeMaxVal As Double
    blueIdx = FindMaxColIndex(ws, BLUE_ROW, START_COL, blueMaxVal)
    orangeIdx = FindMaxColIndex(ws, ORANGE_ROW, START_COL, orangeMaxVal)

    Debug.Print "=== Step2: MoveShapes ==="
    Debug.Print "  Blue   -> " & coArr(blueIdx).Name & "  maxVal=" & blueMaxVal
    Debug.Print "  Orange -> " & coArr(orangeIdx).Name & "  maxVal=" & orangeMaxVal

    MoveShape ws, co138, coArr(blueIdx), ws.Shapes(BLUE_SHAPE), 1, blueMaxVal
    MoveShape ws, co138, coArr(orangeIdx), ws.Shapes(ORANGE_SHAPE), 2, orangeMaxVal

End Sub

' ---------------------------------------------------------------
' Returns 1/2/3: col with max value in row; returns max via ByRef
' ---------------------------------------------------------------
Private Function FindMaxColIndex(ws As Worksheet, _
                                 row As Long, _
                                 startCol As Long, _
                                 ByRef maxVal As Double) As Long
    maxVal = CDbl(ws.Cells(row, startCol).Value)
    Dim maxIdx As Long: maxIdx = 1
    Dim i As Long
    For i = 1 To 2
        Dim v As Double
        v = CDbl(ws.Cells(row, startCol + i).Value)
        If v > maxVal Then
            maxVal = v
            maxIdx = i + 1
        End If
    Next i
    FindMaxColIndex = maxIdx
End Function

' ---------------------------------------------------------------
' Parse =SERIES(name, xRange, yRange, order) -> return first cell value of xRange
' Avoids .XValues which fails on line chart type
' ---------------------------------------------------------------
Private Function GetSeriesXVal(s As Series) As Double
    Dim f As String
    f = s.Formula  ' e.g. =SERIES(,Sheet1!$I$1:$I$2,Sheet1!$H$1:$H$2,1)

    Dim inner As String
    inner = Mid(f, 9, Len(f) - 9)   ' strip =SERIES( and trailing )

    Dim parts() As String
    parts = Split(inner, ",")
    ' parts(0)=name  parts(1)=xRange  parts(2)=yRange  parts(3)=order

    Dim xRange As Range
    Set xRange = Application.Evaluate(Trim(parts(1)))
    GetSeriesXVal = CDbl(xRange.Cells(1, 1).Value2)
End Function

' ---------------------------------------------------------------
' X: parse series formula -> first X cell -> ch138 axis + InsidePlotArea
' Y: maxVal              -> ch138 axis + InsidePlotArea  (same coord system)
' Right edge of shape at xPos
' ---------------------------------------------------------------
Private Sub MoveShape(ws As Worksheet, _
                      co138 As chartObject, _
                      targetCo As chartObject, _
                      shp As Shape, _
                      seriesIdx As Long, _
                      maxVal As Double)

    Dim s As Series
    Set s = co138.Chart.FullSeriesCollection(seriesIdx)

    Dim xVal As Double
    xVal = GetSeriesXVal(s)

    Dim xMin As Double, xMax As Double
    With co138.Chart.Axes(xlCategory)
        xMin = .MinimumScale
        xMax = .MaximumScale
    End With

    ' X: ch138 InsidePlotArea
    Dim plotLeft As Double, plotWidth As Double
    With co138.Chart.PlotArea
        plotLeft = co138.Left + .insideLeft
        plotWidth = .insideWidth
    End With

    Dim xPos As Double
    xPos = plotLeft + ((xVal - xMin) / (xMax - xMin)) * plotWidth

    ' Y: targetCo (chart có max) InsidePlotArea + Y axis
    Dim yMin As Double, yMax As Double
    With targetCo.Chart.Axes(xlValue)
        yMin = .MinimumScale
        yMax = .MaximumScale
    End With

    Dim plotTop As Double, plotHeight As Double
    With targetCo.Chart.PlotArea
        plotTop = targetCo.Top + .InsideTop
        plotHeight = .InsideHeight
    End With

    Dim yPos As Double
    yPos = plotTop + ((yMax - maxVal) / (yMax - yMin)) * plotHeight

    shp.Left = xPos - shp.Width
    shp.Top = yPos - shp.Height / 2

    Debug.Print "  " & shp.Name & ": xVal=" & Round(xVal, 4) & _
                "  xPos=" & Round(xPos, 2) & _
                "  maxVal=" & Round(maxVal, 4) & _
                "  yPos=" & Round(yPos, 2) & _
                "  shp.Left=" & Round(shp.Left, 2) & _
                "  shp.Top=" & Round(shp.Top, 2)
End Sub
