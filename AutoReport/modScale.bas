Attribute VB_Name = "modScale"
Option Explicit

' =============================================================================
' modScale — Forces uniform X/Y axis scale on every chart referenced by the
'            POINT Group column of ExportConfig.
'
' Public:
'   SetScale — read ScaleControl table + POINT Group rows, apply Min/Max/Major
'              unit to both X and Y axes of every chart in the POINT Group.
'
' Scale table layout (anchored at any cell whose value = modConfig.SCALE_ANCHOR):
'
'   | ScaleControl | Xscale | Yscale |
'   | min          |  0     |  80    |
'   | max          |  1500  |  180   |
'   | Major        |  300   |  20    |
' =============================================================================

Private Type AxisSpec
    minVal   As Double
    maxVal   As Double
    majorVal As Double
    isValid  As Boolean
End Type

' =============================================================================
Public Sub SetScale()
    On Error GoTo CleanFail

    Dim cfgWs As Worksheet
    Set cfgWs = ThisWorkbook.Worksheets(modConfig.CFG_SHEET_NAME)

    Dim xSpec As AxisSpec, ySpec As AxisSpec
    If Not ReadScaleTable(cfgWs, xSpec, ySpec) Then
        MsgBox "ScaleControl table not found on " & modConfig.CFG_SHEET_NAME & ".", _
               vbExclamation, "SetScale"
        Exit Sub
    End If

    Dim colSheet As Long, colPoints As Long
    colSheet = FindHeaderColumn(cfgWs, modConfig.HDR_SHEET)
    colPoints = FindHeaderColumn(cfgWs, modConfig.HDR_POINTS)
    If colSheet = 0 Or colPoints = 0 Then
        MsgBox "ExportConfig: missing header(s) on row " & modConfig.HDR_ROW & _
               " (need: " & modConfig.HDR_SHEET & ", " & modConfig.HDR_POINTS & ")", _
               vbExclamation, "SetScale"
        Exit Sub
    End If

    Dim lastRow As Long
    lastRow = cfgWs.Cells(cfgWs.rows.count, colPoints).End(xlUp).row
    If lastRow < modConfig.HDR_ROW + 1 Then Exit Sub

    Dim curSheet As String
    Dim applied  As Long

    Dim r As Long
    For r = modConfig.HDR_ROW + 1 To lastRow
        Dim aVal As String, cVal As String
        aVal = Trim$(CStr(cfgWs.Cells(r, colSheet).Value))
        cVal = Trim$(CStr(cfgWs.Cells(r, colPoints).Value))

        If Len(aVal) = 0 And Len(cVal) = 0 Then Exit For
        If Len(aVal) > 0 Then curSheet = aVal
        If Len(curSheet) = 0 Or Len(cVal) = 0 Then GoTo NextRow

        Dim ws As Worksheet
        Set ws = Nothing
        On Error Resume Next
        Set ws = ThisWorkbook.Worksheets(curSheet)
        On Error GoTo CleanFail
        If ws Is Nothing Then
            Debug.Print "SetScale: sheet not found - " & curSheet
            GoTo NextRow
        End If

        Dim names() As String
        names = SplitTrim(cVal, modConfig.SEPARATOR)
        Dim i As Long
        For i = LBound(names) To UBound(names)
            If Len(names(i)) > 0 Then
                If ApplyToChart(ws, names(i), xSpec, ySpec) Then _
                    applied = applied + 1
            End If
        Next i

NextRow:
    Next r

    MsgBox "SetScale done. Axes updated on " & applied & " chart(s).", _
           vbInformation, "SetScale"
    Exit Sub

CleanFail:
    MsgBox "SetScale error:" & vbCrLf & Err.Number & " - " & Err.Description, _
           vbCritical, "SetScale"
End Sub

' =============================================================================
Private Function ReadScaleTable(ByVal ws As Worksheet, _
                                ByRef xSpec As AxisSpec, _
                                ByRef ySpec As AxisSpec) As Boolean
    Dim anchor As Range
    Set anchor = FindAnchor(ws, modConfig.SCALE_ANCHOR)
    If anchor Is Nothing Then
        ReadScaleTable = False
        Exit Function
    End If

    Dim r0 As Long, c0 As Long
    r0 = anchor.row
    c0 = anchor.Column

    Dim rMin As Long, rMax As Long, rMajor As Long
    rMin = FindLabelRow(ws, c0, r0, "min")
    rMax = FindLabelRow(ws, c0, r0, "max")
    rMajor = FindLabelRow(ws, c0, r0, "Major")

    If rMin > 0 Then
        xSpec.minVal = ReadNum(ws, rMin, c0 + 1)
        ySpec.minVal = ReadNum(ws, rMin, c0 + 2)
    End If
    If rMax > 0 Then
        xSpec.maxVal = ReadNum(ws, rMax, c0 + 1)
        ySpec.maxVal = ReadNum(ws, rMax, c0 + 2)
    End If
    If rMajor > 0 Then
        xSpec.majorVal = ReadNum(ws, rMajor, c0 + 1)
        ySpec.majorVal = ReadNum(ws, rMajor, c0 + 2)
    End If

    xSpec.isValid = (xSpec.maxVal > xSpec.minVal) And (xSpec.majorVal > 0)
    ySpec.isValid = (ySpec.maxVal > ySpec.minVal) And (ySpec.majorVal > 0)

    ReadScaleTable = (xSpec.isValid Or ySpec.isValid)
End Function

Private Function FindLabelRow(ByVal ws As Worksheet, _
                              ByVal col As Long, _
                              ByVal r0 As Long, _
                              ByVal label As String) As Long
    Dim wantLbl As String
    wantLbl = LCase$(Trim$(label))

    Dim r As Long
    For r = r0 + 1 To r0 + 20
        Dim lbl As String
        lbl = LCase$(Trim$(CStr(ws.Cells(r, col).Value)))
        If lbl = wantLbl Then
            FindLabelRow = r
            Exit Function
        End If
    Next r
End Function

Private Function FindAnchor(ByVal ws As Worksheet, ByVal key As String) As Range
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

Private Function ReadNum(ByVal ws As Worksheet, _
                         ByVal r As Long, _
                         ByVal c As Long) As Double
    Dim v As Variant
    v = ws.Cells(r, c).Value
    If IsNumeric(v) Then ReadNum = CDbl(v) Else ReadNum = 0
End Function

Private Function ApplyToChart(ByVal ws As Worksheet, _
                              ByVal chartName As String, _
                              ByRef xSpec As AxisSpec, _
                              ByRef ySpec As AxisSpec) As Boolean
    Dim co As chartObject
    On Error Resume Next
    Set co = ws.chartObjects(chartName)
    On Error GoTo 0
    If co Is Nothing Then
        Debug.Print "ApplyToChart: missing " & chartName & " on " & ws.Name
        Exit Function
    End If

    Dim cht As Chart
    Set cht = co.Chart

    If xSpec.isValid Then ApplyAxisSpec cht, xlCategory, xSpec
    If ySpec.isValid Then ApplyAxisSpec cht, xlValue, ySpec

    ApplyToChart = True
End Function

Private Sub ApplyAxisSpec(ByVal cht As Chart, _
                          ByVal axType As XlAxisType, _
                          ByRef spec As AxisSpec)
    Dim ax As Axis
    On Error Resume Next
    Set ax = cht.Axes(axType, xlPrimary)
    On Error GoTo 0
    If ax Is Nothing Then Exit Sub

    On Error Resume Next
    ax.MinimumScaleIsAuto = False
    ax.MaximumScaleIsAuto = False
    ax.MajorUnitIsAuto = False
    ax.MinimumScale = spec.minVal
    ax.MaximumScale = spec.maxVal
    ax.MajorUnit = spec.majorVal
    On Error GoTo 0
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
