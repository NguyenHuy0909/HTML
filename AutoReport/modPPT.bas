Attribute VB_Name = "modPPT"
Option Explicit

' =============================================================================
' PPT export: offset-based positioning from PPT_SlideBounds.Left/Top.
' Charts exported as SVG (vector) via Chart.Export + Shapes.AddPicture.
' DataTable pasted as HTML via clipboard.
'
' All settings read from ExportConfig sheet via modConfig.
' Entry point: ExportToPPT
' =============================================================================

Private Const ppPasteHTML             As Long = 8
Private Const ppPasteEnhancedMetafile As Long = 2
Private Const msoFalse                As Long = 0
Private Const msoTrue                 As Long = -1

' =============================================================================
Public Sub ExportToPPT()
' =============================================================================
    Dim prevEvents As Boolean: prevEvents = Application.EnableEvents
    Application.EnableEvents = False
    On Error GoTo CleanFail

    modConfig.InvalidateCache

    ' --- Read all config up front ---
    Dim boundsName  As String: boundsName = modConfig.CfgStr("SlideBoundsName", "PPT_SlideBounds")
    Dim tableName   As String: tableName = modConfig.CfgStr("DataTableName", "PPT_XL_DataTable")
    Dim chartPfx    As String: chartPfx = modConfig.CfgStr("ChartShapePrefix", "Chart_")
    Dim tblShpName  As String: tblShpName = modConfig.CfgStr("DataTableShapeName", "XL_DataTable")
    Dim tblFont     As String: tblFont = modConfig.CfgStr("DataTableFontName", "")
    Dim tblFontSz   As Double: tblFontSz = modConfig.CfgDbl("DataTableFontSize", 0)
    Dim lblFontSz   As Double: lblFontSz = modConfig.CfgDbl("LabelFontSize", 0)


    Dim pres As Object: Set pres = OpenPres()
    If pres Is Nothing Then
        Debug.Print "ExportToPPT: cannot open presentation": GoTo CleanExit
    End If
    Debug.Print "=== ExportToPPT start: " & pres.Name & " (" & pres.Slides.count & " slides) ==="

    Dim slideW As Double: slideW = pres.PageSetup.SlideWidth
    Dim slideH As Double: slideH = pres.PageSetup.SlideHeight
    Dim cfgWs As Worksheet
    Set cfgWs = modConfig.GetConfigSheet()
    If Not cfgWs Is Nothing Then
        cfgWs.Range("M1").Value2 = "PPT ratio"
        cfgWs.Range("N1").Value2 = slideW / slideH
    End If

    Dim ws As Worksheet
    For Each ws In ThisWorkbook.Worksheets
        Dim slideIdx As Long
        slideIdx = SlideIdxFromConfig(ws.Name)
        If slideIdx < 1 Or slideIdx > pres.Slides.count Then GoTo NextSheet

        Dim bounds As Range
        Set bounds = modLayout.FindNamedRange(ws, boundsName)
        If bounds Is Nothing Then
            Debug.Print "  [SKIP] " & ws.Name & ": " & boundsName & " missing"
            GoTo NextSheet
        End If
        Debug.Print "--- " & ws.Name & " -> slide " & slideIdx & " ---"

        Dim sld As Object: Set sld = pres.Slides(slideIdx)

        ' Navigate PPT view to this slide so PasteSpecial targets it correctly
        On Error Resume Next
        pres.Application.ActiveWindow.View.GotoSlide slideIdx
        On Error GoTo CleanFail

        ' DataTable
        Dim dtRng As Range
        Set dtRng = modLayout.FindNamedRange(ws, tableName)
        If Not dtRng Is Nothing Then ExportTable dtRng, sld, bounds, tblShpName, slideW, slideH, tblFont, tblFontSz

        ' All charts on this sheet
        Dim co As chartObject
        For Each co In ws.chartObjects
            ExportChart co, sld, bounds, chartPfx, slideW, slideH
        Next co

        ' All line shapes (prefix "Line_") — lines + circle markers
        Dim lineShp As Shape
        For Each lineShp In ws.Shapes
            If Left$(lineShp.Name, 5) = "Line_" Then
                ExportLineShape lineShp, sld, bounds, slideH
            End If
        Next lineShp

        ' All label shapes (prefix "LabelOut_") — textbox copies from modShape
        Dim labelShp As Shape
        For Each labelShp In ws.Shapes
            If Left$(labelShp.Name, 9) = "LabelOut_" Then
                ExportLabelShape labelShp, sld, bounds, slideH, tblFont, lblFontSz
            End If
        Next labelShp

NextSheet:
    Next ws
    Debug.Print "=== ExportToPPT done ==="

CleanExit:
    Application.EnableEvents = prevEvents
    Exit Sub
CleanFail:
    Debug.Print "[ERROR] ExportToPPT: " & Err.Number & " - " & Err.Description
    Resume CleanExit
End Sub

' --- DataTable ----------------------------------------------------------------
Private Sub ExportTable(ByVal rng As Range, ByVal sld As Object, _
                         ByVal bounds As Range, ByVal shapeName As String, _
                         ByVal slideW As Double, ByVal slideH As Double, _
                         ByVal fontName As String, ByVal fontSize As Double)
    DeleteByName sld, shapeName
    rng.Copy
    Dim shp As Object
    On Error Resume Next
    Err.Clear
    Set shp = sld.Shapes.PasteSpecial(ppPasteHTML)
    On Error GoTo 0
    Application.CutCopyMode = False
    If shp Is Nothing Then Debug.Print "  [ERR] DataTable paste failed": Exit Sub

    Dim scaleX As Double: scaleX = slideW / bounds.Width
    Dim scaleY As Double: scaleY = slideH / bounds.Height

    shp.Name = shapeName
    shp.LockAspectRatio = False
    shp.Left = (rng.Left - bounds.Left) * scaleX
    shp.Top = (rng.Top - bounds.Top) * scaleY
    shp.Width = rng.Width * scaleX
    shp.Height = rng.Height * scaleY

    If shp.HasTable Then ApplyTableFont shp.Table, fontName, fontSize

    Debug.Print "  [OK] " & shapeName & " L=" & Pt(shp.Left) & " T=" & Pt(shp.Top) & _
                " W=" & Pt(shp.Width) & " H=" & Pt(shp.Height)
End Sub

Private Sub ApplyTableFont(ByVal tbl As Object, _
                            ByVal fontName As String, ByVal fontSize As Double)
    If Len(fontName) = 0 And fontSize <= 0 Then Exit Sub
    Dim r As Long, c As Long
    For r = 1 To tbl.Rows.Count
        For c = 1 To tbl.Columns.Count
            With tbl.Cell(r, c).Shape.TextFrame.TextRange.Font
                If Len(fontName) > 0 Then .Name = fontName
                If fontSize > 0 Then .Size = fontSize
            End With
        Next c
    Next r
End Sub
Private Sub ExportChart(ByVal co As chartObject, ByVal sld As Object, _
                         ByVal bounds As Range, ByVal prefix As String, _
                         ByVal slideW As Double, ByVal slideH As Double)
    Dim sName As String
    sName = prefix & co.Name
    DeleteByName sld, sName

    Dim scaleY As Double: scaleY = slideH / bounds.Height
    Dim pptL As Double: pptL = (co.Left  - bounds.Left) * scaleY
    Dim pptT As Double: pptT = (co.Top   - bounds.Top)  * scaleY
    Dim pptW As Double: pptW = co.Width  * scaleY
    Dim pptH As Double: pptH = co.Height * scaleY

    Dim tmpFile As String
    tmpFile = Environ("TEMP") & "\" & Replace(co.Name, " ", "_") & ".svg"

    On Error Resume Next
    Err.Clear
    co.Chart.Export Filename:=tmpFile, FilterName:="SVG"
    Dim expErr As Long: expErr = Err.Number
    On Error GoTo 0
    If expErr <> 0 Then
        Debug.Print "  [ERR] SVG export '" & co.Name & "': " & expErr
        Exit Sub
    End If

    Dim shp As Object
    On Error Resume Next
    Err.Clear
    Set shp = sld.Shapes.AddPicture(tmpFile, msoFalse, msoTrue, pptL, pptT, pptW, pptH)
    Dim insErr As Long: insErr = Err.Number
    On Error GoTo 0

    On Error Resume Next: Kill tmpFile: On Error GoTo 0

    If insErr <> 0 Or shp Is Nothing Then
        Debug.Print "  [ERR] " & sName & " AddPicture failed (" & insErr & ")"
        Exit Sub
    End If

    shp.Name = sName
    Debug.Print "  [OK] " & sName & " L=" & Pt(pptL) & " T=" & Pt(pptT) & _
                " W=" & Pt(pptW) & " H=" & Pt(pptH)
End Sub

' --- Line shapes (Line_ prefix) -----------------------------------------------
' msoLine (Type=9)  : CopyPicture + PasteSpecial(EMF), scale Left/Top/Height.
' Oval markers      : AddShape (exact color, no distortion), scale all dims.
Private Sub ExportLineShape(ByVal xlShp As Shape, ByVal sld As Object, _
                             ByVal bounds As Range, ByVal slideH As Double)
    DeleteByName sld, xlShp.Name

    Dim scaleY As Double: scaleY = slideH / bounds.Height
    Dim pptL   As Double: pptL = (xlShp.Left - bounds.Left) * scaleY
    Dim pptT   As Double: pptT = (xlShp.Top  - bounds.Top)  * scaleY
    Dim pptW   As Double: pptW = xlShp.Width  * scaleY
    Dim pptH   As Double: pptH = xlShp.Height * scaleY

    Dim pptShp As Object
    On Error Resume Next
    Err.Clear

    If xlShp.Type = 9 Then
        ' ── Dashed vertical line — CopyPicture (preserves dash style exactly) ──
        xlShp.CopyPicture Appearance:=xlScreen, Format:=xlPicture
        DoEvents
        Set pptShp = sld.Shapes.PasteSpecial(ppPasteEnhancedMetafile)
        Dim pasteErr As Long: pasteErr = Err.Number
        On Error GoTo 0
        Application.CutCopyMode = False
        If pasteErr <> 0 Or pptShp Is Nothing Then
            Debug.Print "  [ERR] ExportLineShape paste '" & xlShp.Name & "': " & pasteErr
            Exit Sub
        End If
        On Error Resume Next
        pptShp.LockAspectRatio = msoFalse
        pptShp.Left   = pptL
        pptShp.Top    = pptT
        pptShp.Width  = 1
        pptShp.Height = pptH
        pptShp.Name   = xlShp.Name
        On Error GoTo 0
    Else
        ' ── Oval marker — AddShape (exact color, no distortion) ──────────────
        Set pptShp = sld.Shapes.AddShape(9, pptL, pptT, pptW, pptH)
        If Err.Number = 0 And Not pptShp Is Nothing Then
            pptShp.Line.Visible       = msoFalse
            pptShp.Fill.ForeColor.RGB = xlShp.Fill.ForeColor.RGB
            pptShp.Name               = xlShp.Name
        End If
        On Error GoTo 0
    End If

    Debug.Print "  [OK] " & xlShp.Name & " L=" & Pt(pptL) & " T=" & Pt(pptT) & _
                " W=" & Pt(pptW) & " H=" & Pt(pptH)
End Sub

Private Function OpenPres() As Object
    Dim cfgPath As String: cfgPath = modConfig.CfgStr("PptxPath", "")
    If Len(cfgPath) = 0 Then
        Debug.Print "OpenPres: PptxPath not configured": Exit Function
    End If

    ' Resolve relative path against workbook folder
    Dim pptxPath As String
    If Mid$(cfgPath, 2, 1) = ":" Or Left$(cfgPath, 2) = "\\" Then
        pptxPath = cfgPath
    Else
        pptxPath = ThisWorkbook.path & "\" & cfgPath
    End If

    Dim pptApp As Object
    On Error Resume Next
    Set pptApp = GetObject(, "PowerPoint.Application")
    On Error GoTo 0
    If pptApp Is Nothing Then
        Set pptApp = CreateObject("PowerPoint.Application")
        pptApp.Visible = True
    End If

    ' Detect already-open presentation by full path
    Dim p As Object
    For Each p In pptApp.Presentations
        If StrComp(p.fullName, pptxPath, vbTextCompare) = 0 Then
            Set OpenPres = p: Exit Function
        End If
    Next p
    Set OpenPres = pptApp.Presentations.Open(pptxPath)
End Function

Private Sub DeleteByName(ByVal sld As Object, ByVal sName As String)
    Dim i As Long
    For i = sld.Shapes.count To 1 Step -1
        If StrComp(sld.Shapes(i).Name, sName, vbTextCompare) = 0 Then
            sld.Shapes(i).Delete
        End If
    Next i
End Sub


' --- Label shapes (LabelOut_ prefix) ----------------------------------------
' CopyPicture + PasteSpecial(EMF) — scale Left/Top/Width/Height bằng scaleY.
' fontName / fontSize: lấy chung từ DataTableFontName / DataTableFontSize (config).
Private Sub ExportLabelShape(ByVal xlShp As Shape, ByVal sld As Object, _
                              ByVal bounds As Range, ByVal slideH As Double, _
                              ByVal fontName As String, ByVal fontSize As Double)
    DeleteByName sld, xlShp.Name

    Dim scaleY As Double: scaleY = slideH / bounds.Height
    Dim pptL   As Double: pptL = (xlShp.Left - bounds.Left) * scaleY
    Dim pptT   As Double: pptT = (xlShp.Top  - bounds.Top)  * scaleY
    Dim pptW   As Double: pptW = xlShp.Width  * scaleY
    Dim pptH   As Double: pptH = xlShp.Height * scaleY

    xlShp.CopyPicture Appearance:=xlScreen, Format:=xlPicture
    DoEvents

    Dim pptShp As Object
    On Error Resume Next
    Err.Clear
    Set pptShp = sld.Shapes.PasteSpecial(ppPasteEnhancedMetafile)
    Dim pasteErr As Long: pasteErr = Err.Number
    On Error GoTo 0
    Application.CutCopyMode = False

    If pasteErr <> 0 Or pptShp Is Nothing Then
        Debug.Print "  [ERR] ExportLabelShape paste '" & xlShp.Name & "': " & pasteErr
        Exit Sub
    End If

    On Error Resume Next
    pptShp.LockAspectRatio = msoFalse
    pptShp.Left   = pptL
    pptShp.Top    = pptT
    pptShp.Width  = pptW
    pptShp.Height = pptH
    If Len(fontName) > 0 Then pptShp.TextFrame.TextRange.Font.Name = fontName
    If fontSize > 0     Then pptShp.TextFrame.TextRange.Font.Size = fontSize
    pptShp.Name   = xlShp.Name
    On Error GoTo 0

    Debug.Print "  [OK] " & xlShp.Name & " L=" & Pt(pptL) & " T=" & Pt(pptT) & _
                " W=" & Pt(pptW) & " H=" & Pt(pptH)
End Sub

Private Function Pt(ByVal v As Double) As String
    Pt = Format$(v, "0.0")
End Function

' Read "PPT Slide" for a given SHEET NAME from the ExportConfig data table.
' Returns 0 if not found.
Private Function SlideIdxFromConfig(ByVal sheetName As String) As Long
    Dim cfgWs As Worksheet
    Set cfgWs = modConfig.GetConfigSheet()
    If cfgWs Is Nothing Then Exit Function

    Dim colSlide As Long: colSlide = modConfig.FindHeaderCol(cfgWs, modConfig.HDR_SLIDE)
    Dim colSheet As Long: colSheet = modConfig.FindHeaderCol(cfgWs, modConfig.HDR_SHEET)
    Dim colGroup As Long: colGroup = modConfig.FindHeaderCol(cfgWs, modConfig.HDR_GROUP)
    If colSlide = 0 Or colSheet = 0 Then
        Debug.Print "SlideIdxFromConfig: missing header '" & modConfig.HDR_SLIDE & _
                    "' or '" & modConfig.HDR_SHEET & "'"
        Exit Function
    End If

    Dim r As Long
    For r = modConfig.HDR_ROW + 1 To modConfig.CFG_MAX_ROW
        Dim aVal As Variant: aVal = cfgWs.Cells(r, colSlide).Value2
        Dim bVal As Variant: bVal = cfgWs.Cells(r, colSheet).Value2
        Dim cVal As Variant
        If colGroup > 0 Then cVal = cfgWs.Cells(r, colGroup).Value2 Else cVal = ""
        If (IsEmpty(aVal) Or Len(Trim$(CStr(aVal))) = 0) And _
           (IsEmpty(bVal) Or Len(Trim$(CStr(bVal))) = 0) And _
           (IsEmpty(cVal) Or Len(Trim$(CStr(cVal))) = 0) Then Exit For
        If Not IsEmpty(bVal) Then
            If StrComp(Trim$(CStr(bVal)), sheetName, vbTextCompare) = 0 Then
                If IsNumeric(aVal) Then SlideIdxFromConfig = CLng(aVal)
                Exit Function
            End If
        End If
    Next r
End Function

