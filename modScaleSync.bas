Option Explicit
' Sync axis scale cua tat ca ChartObjects hien co theo bang R1:T3 tren Sheet1
'   S2 = X-min, S3 = X-max, T2 = Y-min, T3 = Y-max

Public Sub SyncAllChartsScale()
    Const SHEET_NAME As String = "Sheet1"
    On Error GoTo CleanFail

    Dim ws As Worksheet: Set ws = ThisWorkbook.Sheets(SHEET_NAME)

    Dim xMin As Double, xMax As Double, yMin As Double, yMax As Double
    xMin = CDbl(ws.Range("S2").Value)
    xMax = CDbl(ws.Range("S3").Value)
    yMin = CDbl(ws.Range("T2").Value)
    yMax = CDbl(ws.Range("T3").Value)

    If xMax <= xMin Or yMax <= yMin Then
        Debug.Print "SyncAllChartsScale: invalid range (min >= max). Skip."
        Exit Sub
    End If

    Dim syncedCount As Long
    Dim skippedCount As Long
    Dim co As chartObject
    For Each co In ws.chartObjects
        If ApplyScale(co.Chart, co.Name, xMin, xMax, yMin, yMax) Then
            syncedCount = syncedCount + 1
        Else
            skippedCount = skippedCount + 1
        End If
    Next co

    Debug.Print "SyncAllChartsScale: X=[" & xMin & "," & xMax & "]  Y=[" & yMin & "," & yMax & _
                "], synced=" & syncedCount & ", skipped=" & skippedCount
    Exit Sub

CleanFail:
    Debug.Print "SyncAllChartsScale ERROR " & Err.Number & ": " & Err.Description
End Sub

Private Function ApplyScale(ByVal cht As Chart, _
                            ByVal chartName As String, _
                            ByVal xMin As Double, ByVal xMax As Double, _
                            ByVal yMin As Double, ByVal yMax As Double) As Boolean
    Dim xApplied As Boolean
    Dim yApplied As Boolean

    On Error Resume Next
    With cht.Axes(xlCategory)
        .MinimumScale = xMin
        .MaximumScale = xMax
    End With
    If Err.Number = 0 Then
        xApplied = True
    Else
        Debug.Print "  WARNING [" & chartName & "]: cannot apply X scale - " & Err.Description
        Err.Clear
    End If

    With cht.Axes(xlValue)
        .MinimumScale = yMin
        .MaximumScale = yMax
    End With
    If Err.Number = 0 Then
        yApplied = True
    Else
        Debug.Print "  WARNING [" & chartName & "]: cannot apply Y scale - " & Err.Description
        Err.Clear
    End If
    On Error GoTo 0

    ApplyScale = (xApplied Or yApplied)
End Function
