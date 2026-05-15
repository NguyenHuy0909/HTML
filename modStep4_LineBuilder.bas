Attribute VB_Name = "modStep4_LineBuilder"
Option Explicit

' =============================================================================
' Line Builder — replaces Chart 100~104 overlay with native AutoShape Lines.
' -----------------------------------------------------------------------------
' For each group, draws vertical lines on the worksheet at the score X values
' (read from ExportConfig). Line spans from top chart's PlotArea top to
' bottom chart's PlotArea bottom.
'
' Entry point: BuildAllGroupLines (rebuild every group)
'              BuildGroupLines (single group)
'
' Line naming: "Line_G<groupIdx>_M<modelIdx>"
' =============================================================================

Public Const LINE_NAME_PREFIX As String = "Line_G"
Public Const LINE_COLOR_RGB   As Long = 0          ' black
Public Const LINE_WEIGHT_PT   As Double = 1.25
Public Const LINE_DASH_STYLE  As Long = 1          ' msoLineSolid

Private Const msoLine          As Long = 9
Private Const msoLineSolid     As Long = 1

Public Type GroupLineConfig
    GroupIdx     As Long
    TopChartName As String
    BotChartName As String
    ScoreRange   As String   ' worksheet range with X values, e.g. "AF10:AH10"
    DataSheet    As String
End Type

' =============================================================================
Public Sub BuildAllGroupLines()
' =============================================================================
'   Phase 1: only Group1 wired. Add more groups as template scope expands.
    Dim cfg As GroupLineConfig
    cfg.GroupIdx = 1
    cfg.TopChartName = "Chart 1"
    cfg.BotChartName = "Chart 3"
    cfg.ScoreRange = "AF10:AH10"
    cfg.DataSheet = GetDataSheet()

    BuildGroupLines cfg
End Sub

' =============================================================================
Private Sub BuildGroupLines(ByRef cfg As GroupLineConfig)
' =============================================================================
    On Error GoTo CleanFail
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets(cfg.DataSheet)

    CleanupGroupLines ws, cfg.GroupIdx

    Dim topCo As ChartObject, botCo As ChartObject
    Set topCo = ws.ChartObjects(cfg.TopChartName)
    Set botCo = ws.ChartObjects(cfg.BotChartName)

    Dim lineTop As Double, lineBot As Double
    lineTop = topCo.Top + topCo.Chart.PlotArea.InsideTop
    lineBot = botCo.Top + botCo.Chart.PlotArea.InsideTop + botCo.Chart.PlotArea.InsideHeight

    Dim ax As Axis: Set ax = topCo.Chart.Axes(1)  ' xlCategory=1; for value-axis use xlValue=2
    Dim axMin As Double: axMin = ax.MinimumScale
    Dim axMax As Double: axMax = ax.MaximumScale
    Dim paLeft As Double: paLeft = topCo.Left + topCo.Chart.PlotArea.InsideLeft
    Dim paWidth As Double: paWidth = topCo.Chart.PlotArea.InsideWidth

    Dim vals As Variant: vals = ws.Range(cfg.ScoreRange).Value
    Dim modelIdx As Long
    Dim cols As Long: cols = UBound(vals, 2)

    For modelIdx = 1 To cols
        Dim xv As Variant: xv = vals(1, modelIdx)
        If IsNumeric(xv) Then
            Dim wsX As Double
            wsX = paLeft + (CDbl(xv) - axMin) / (axMax - axMin) * paWidth
            Dim shp As Shape
            Set shp = ws.Shapes.AddLine(wsX, lineTop, wsX, lineBot)
            shp.Name = LINE_NAME_PREFIX & cfg.GroupIdx & "_M" & modelIdx
            With shp.Line
                .ForeColor.RGB = LINE_COLOR_RGB
                .Weight = LINE_WEIGHT_PT
                .DashStyle = msoLineSolid
            End With
            Debug.Print "  [Line] " & shp.Name & " wsX=" & Format$(wsX, "0.00") & _
                        " span " & Format$(lineTop, "0.00") & ".." & Format$(lineBot, "0.00")
        End If
    Next modelIdx

    Debug.Print "BuildGroupLines G" & cfg.GroupIdx & ": done"
    Exit Sub
CleanFail:
    Debug.Print "BuildGroupLines G" & cfg.GroupIdx & " ERROR " & Err.Number & ": " & Err.Description
End Sub

' =============================================================================
Public Sub CleanupGroupLines(ByVal ws As Worksheet, ByVal groupIdx As Long)
' =============================================================================
    Dim prefix As String: prefix = LINE_NAME_PREFIX & groupIdx & "_"
    Dim i As Long
    For i = ws.Shapes.Count To 1 Step -1
        If StrComp(Left$(ws.Shapes(i).Name, Len(prefix)), prefix, vbTextCompare) = 0 Then
            ws.Shapes(i).Delete
        End If
    Next i
End Sub

Private Function GetDataSheet() As String
    Dim cfgWs As Worksheet
    On Error Resume Next
    Set cfgWs = ThisWorkbook.Sheets("ExportConfig")
    On Error GoTo 0
    If cfgWs Is Nothing Then GetDataSheet = "Sheet1": Exit Function

    Dim r As Long
    For r = 2 To 50
        If StrComp(Trim$(CStr(cfgWs.Cells(r, 15).Value)), "DataSheetName", vbTextCompare) = 0 Then
            GetDataSheet = CStr(cfgWs.Cells(r, 16).Value)
            If Len(GetDataSheet) > 0 Then Exit Function
        End If
    Next r
    GetDataSheet = "Sheet1"
End Function
