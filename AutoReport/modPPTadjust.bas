Attribute VB_Name = "modPPTadjust"
Option Explicit

' =============================================================================
' modPPTadjust — Pre-export Excel grid alignment utilities.
'
' Public:
'   AlignGridToSlide — resizes only columns of every template sheet's
'                      PPT_SlideBounds so the grid's visual width matches
'                      the PPT slide exactly.  Row heights are not touched.
'
' XY_SCALE corrects for the ~1.3% difference between Excel's column-width
' point unit (character-based, 96-DPI) and row-height point unit (physical).
' Derived empirically by placing a PPT slide screenshot on the sheet and
' comparing picture.Width to bounds.Height * (slideW/slideH).
' Re-calibrate with CalibrateXYScale if the DPI or font changes.
' =============================================================================

' Empirical X/Y pt-unit correction for this machine/Excel setup.
' Derived: picture.W(1901.3) / (bounds.H(1056) * slideRatio(1.7778)) = 1.01276
Private Const XY_SCALE As Double = 1.013

' =============================================================================
Public Sub AlignGridToSlide()
' =============================================================================
    modConfig.InvalidateCache

    Dim pres As Object: Set pres = GetOrOpenPres()
    If pres Is Nothing Then
        MsgBox "AlignGridToSlide: cannot open presentation.", vbExclamation, "AlignGridToSlide"
        Exit Sub
    End If

    Dim slideW As Double: slideW = pres.PageSetup.SlideWidth
    Dim slideH As Double: slideH = pres.PageSetup.SlideHeight
    Dim boundsName As String: boundsName = modConfig.CfgStr("SlideBoundsName", "PPT_SlideBounds")

    Dim updated As Long
    Dim ws As Worksheet
    For Each ws In ThisWorkbook.Worksheets
        Dim bounds As Range
        Set bounds = modLayout.FindNamedRange(ws, boundsName)
        If bounds Is Nothing Then GoTo NextWs

        Dim nCols As Long: nCols = bounds.Columns.Count
        Dim nRows As Long: nRows = bounds.Rows.Count
        If nCols < 1 Or nRows < 1 Then GoTo NextWs

        Dim targetW As Double
        targetW = bounds.Height * (slideW / slideH) * XY_SCALE

        SetEqualColWidthPt ws, bounds.Column, nCols, targetW / nCols

        Debug.Print "AlignGridToSlide: " & ws.Name & _
                    "  cols=" & nCols & " rows=" & nRows & _
                    "  W=" & Format$(bounds.Width, "0.0") & " H=" & Format$(bounds.Height, "0.0") & _
                    "  W/H=" & Format$(bounds.Width / bounds.Height, "0.000") & _
                    "  target=" & Format$(slideW / slideH, "0.000")
        updated = updated + 1
NextWs:
    Next ws

    MsgBox "AlignGridToSlide done. " & updated & " sheet(s) adjusted.", vbInformation, "AlignGridToSlide"
End Sub

' =============================================================================
Public Sub EqualizeRange()
' =============================================================================
' Select a range, then run this sub to distribute its total width equally
' across all columns and its total height equally across all rows in that range.
    If TypeName(Selection) <> "Range" Then
        MsgBox "Please select a range first.", vbExclamation, "EqualizeRange"
        Exit Sub
    End If

    Dim rng As Range: Set rng = Selection
    Dim ws As Worksheet: Set ws = rng.Parent
    Dim nCols As Long: nCols = rng.Columns.Count
    Dim nRows As Long: nRows = rng.Rows.Count

    Dim totalW As Double: totalW = rng.Width
    Dim totalH As Double: totalH = rng.Height

    SetEqualColWidthPt ws, rng.Column, nCols, totalW / nCols

    Dim eachH As Double: eachH = totalH / nRows
    Dim r As Long
    For r = rng.Row To rng.Row + nRows - 1
        ws.Rows(r).RowHeight = eachH
    Next r

    Debug.Print "EqualizeRange: " & rng.Address & _
                "  cols=" & nCols & " rows=" & nRows & _
                "  colW=" & Format$(totalW / nCols, "0.00") & "pt" & _
                "  rowH=" & Format$(eachH, "0.00") & "pt"
    MsgBox "EqualizeRange done." & vbCrLf & _
           nCols & " cols  @ " & Format$(rng.Width / nCols, "0.00") & " pt each" & vbCrLf & _
           nRows & " rows @ " & Format$(eachH, "0.00") & " pt each", _
           vbInformation, "EqualizeRange"
End Sub

' =============================================================================
Public Sub CalibrateXYScale()
' =============================================================================
' Place a PPT slide screenshot (Picture) at L=0 on any template sheet,
' then run this sub to print the correct XY_SCALE value to Immediate Window.
    modConfig.InvalidateCache

    Dim pres As Object: Set pres = GetOrOpenPres()
    If pres Is Nothing Then MsgBox "Cannot open presentation.", vbExclamation: Exit Sub

    Dim slideW As Double: slideW = pres.PageSetup.SlideWidth
    Dim slideH As Double: slideH = pres.PageSetup.SlideHeight
    Dim boundsName As String: boundsName = modConfig.CfgStr("SlideBoundsName", "PPT_SlideBounds")

    Dim ws As Worksheet
    For Each ws In ThisWorkbook.Worksheets
        Dim bounds As Range
        Set bounds = modLayout.FindNamedRange(ws, boundsName)
        If bounds Is Nothing Then GoTo NextWs

        Dim shp As Shape
        For Each shp In ws.Shapes
            If shp.Type = 13 And shp.Left < 1 Then
                Dim factor As Double
                factor = shp.Width / (bounds.Height * (slideW / slideH))
                Debug.Print "CalibrateXYScale [" & ws.Name & "] " & shp.Name & _
                            "  picW=" & Format$(shp.Width, "0.000") & _
                            "  boundsH=" & Format$(bounds.Height, "0.0") & _
                            "  slideRatio=" & Format$(slideW / slideH, "0.000") & _
                            "  => XY_SCALE = " & Format$(factor, "0.000") & _
                            "  (current=" & XY_SCALE & ")"
                Exit For
            End If
        Next shp
NextWs:
    Next ws
End Sub

' --- Helpers ------------------------------------------------------------------

Private Sub SetEqualColWidthPt(ByVal ws As Worksheet, _
                                ByVal firstCol As Long, ByVal nCols As Long, _
                                ByVal targetPt As Double)
    Const TRIAL As Double = 10#
    Dim c As Long
    For c = firstCol To firstCol + nCols - 1
        ws.Columns(c).ColumnWidth = TRIAL
    Next c
    Dim actualPt As Double: actualPt = ws.Columns(firstCol).Width
    If actualPt <= 0 Then Exit Sub
    Dim finalCW As Double: finalCW = TRIAL * targetPt / actualPt
    For c = firstCol To firstCol + nCols - 1
        ws.Columns(c).ColumnWidth = finalCW
    Next c
End Sub

Private Function GetOrOpenPres() As Object
    Dim cfgPath As String: cfgPath = modConfig.CfgStr("PptxPath", "")
    If Len(cfgPath) = 0 Then
        Debug.Print "GetOrOpenPres: PptxPath not configured": Exit Function
    End If

    Dim pptxPath As String
    If Mid$(cfgPath, 2, 1) = ":" Or Left$(cfgPath, 2) = "\\" Then
        pptxPath = cfgPath
    Else
        pptxPath = ThisWorkbook.Path & "\" & cfgPath
    End If

    Dim pptApp As Object
    On Error Resume Next
    Set pptApp = GetObject(, "PowerPoint.Application")
    On Error GoTo 0
    If pptApp Is Nothing Then
        Set pptApp = CreateObject("PowerPoint.Application")
        pptApp.Visible = True
    End If

    Dim p As Object
    For Each p In pptApp.Presentations
        If StrComp(p.FullName, pptxPath, vbTextCompare) = 0 Then
            Set GetOrOpenPres = p: Exit Function
        End If
    Next p
    Set GetOrOpenPres = pptApp.Presentations.Open(pptxPath)
End Function
