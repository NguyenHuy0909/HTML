Attribute VB_Name = "modStep4_TemplateExport"
Option Explicit

' =============================================================================
' Template-Based Export Mode
' -----------------------------------------------------------------------------
' Entry point:  ExportTemplateSlidesToPPT
'
' Reads Named Ranges with prefix PPT_ on template sheets named ReportSlide_NN.
' Each Named Range becomes one block on PPT slide NN. Position/size mapped
' relative to the PPT_SlideBounds Named Range on the same sheet.
'
' Block types:
'   PPT_XL_DataTable  -> editable PPT table (HTML paste)
'   PPT_XL_*          -> image (Range.CopyPicture xlPrinter)
'
' Phase 1 scope: 1 slide (ReportSlide_01), 1 group (PPT_XL_Group1), 1 table.
' =============================================================================

Public Const TPL_SHEET_PREFIX   As String = "ReportSlide_"
Public Const TPL_NAME_PREFIX    As String = "PPT_"
Public Const TPL_SLIDE_BOUNDS   As String = "PPT_SlideBounds"
Public Const TPL_DATA_TABLE     As String = "PPT_XL_DataTable"
Public Const TPL_PPTX_NAME      As String = "PresTest.pptx"  ' fallback only; ưu tiên ExportConfig!PptxName (cột O/P)
Public Const TPL_LOG_FILE       As String = "export_template_log.txt"

Private Const ppPasteEnhancedMetafile As Long = 2
Private Const ppPastePNG              As Long = 3
Private Const ppPasteBitmap           As Long = 4
Private Const ppPasteHTML             As Long = 8

Private Type LayoutBox
    Left As Double
    Top As Double
    Width As Double
    Height As Double
End Type

Private mLogBuf As String

Private Function ResolvePptxName() As String
    Dim cfgWs As Worksheet
    On Error Resume Next
    Set cfgWs = ThisWorkbook.Sheets("ExportConfig")
    On Error GoTo 0
    If cfgWs Is Nothing Then
        ResolvePptxName = TPL_PPTX_NAME
        Exit Function
    End If
    Dim r As Long, k As String, v As String
    For r = 2 To 100
        k = Trim$(CStr(cfgWs.Cells(r, 15).Value))  ' col O
        If Len(k) = 0 Then Exit For
        If StrComp(k, "PptxName", vbTextCompare) = 0 Then
            v = Trim$(CStr(cfgWs.Cells(r, 16).Value))  ' col P
            If Len(v) > 0 Then
                ResolvePptxName = v
                Exit Function
            End If
            Exit For
        End If
    Next r
    ResolvePptxName = TPL_PPTX_NAME
End Function

' =============================================================================
Public Sub SetupTemplateSlideBounds()
' =============================================================================
'   Manual helper: updates PPT_SlideBounds for one ReportSlide_NN sheet only.
'   It keeps the current bounds top-left and column span, then adjusts the row
'   span to the closest range aspect ratio matching the configured PPTX.
    On Error GoTo CleanFail

    Dim rawSlideIdx As Variant
    rawSlideIdx = Application.InputBox( _
        Prompt:="Slide index cần set PPT_SlideBounds:", _
        Title:="Setup PPT_SlideBounds", _
        Default:=1, _
        Type:=1)
    If VarType(rawSlideIdx) = vbBoolean And rawSlideIdx = False Then Exit Sub

    SetupTemplateSlideBoundsForSlide CLng(rawSlideIdx)
    Exit Sub

CleanFail:
    Debug.Print "SetupTemplateSlideBounds ERROR " & Err.Number & ": " & Err.Description
End Sub

' =============================================================================
Public Sub SetupTemplateSlideBoundsForSlide(ByVal slideIdx As Long)
' =============================================================================
'   Can be called from Immediate Window, e.g.:
'       modStep4_TemplateExport.SetupTemplateSlideBoundsForSlide 2
    On Error GoTo CleanFail
    If slideIdx < 1 Then Err.Raise vbObjectError + 601, , "slideIdx must be >= 1."

    Dim ws As Worksheet
    Set ws = FindTemplateSheetBySlideIdx(slideIdx)
    If ws Is Nothing Then
        Err.Raise vbObjectError + 602, , "Template sheet not found for slide " & slideIdx & "."
    End If

    Dim pptApp As Object, pres As Object
    Dim pptxName As String: pptxName = ResolvePptxName()
    OpenPresentation pptApp, pres, pptxName
    If slideIdx > pres.Slides.Count Then
        Err.Raise vbObjectError + 603, , "Slide " & slideIdx & " is out of range. PPT has " & pres.Slides.Count & " slide(s)."
    End If

    Dim slideRatio As Double
    slideRatio = CDbl(pres.PageSetup.SlideWidth) / CDbl(pres.PageSetup.SlideHeight)

    Dim currentBounds As Range
    Set currentBounds = FindNamedRange(ws, TPL_SLIDE_BOUNDS)

    Dim seed As Range
    If currentBounds Is Nothing Then
        Set seed = ws.Range("A3:Y47")
    Else
        Set seed = currentBounds
    End If

    Dim newBounds As Range
    Set newBounds = BestBoundsRangeForAspect(seed, slideRatio)
    SetSheetNamedRange ws, TPL_SLIDE_BOUNDS, newBounds

    Debug.Print "SetupTemplateSlideBoundsForSlide: " & ws.Name & "!" & TPL_SLIDE_BOUNDS & _
                " -> " & newBounds.Address(False, False) & _
                " | PPT ratio=" & Format$(slideRatio, "0.0000") & _
                " | Excel ratio=" & Format$(newBounds.Width / newBounds.Height, "0.0000")
    Exit Sub

CleanFail:
    Debug.Print "SetupTemplateSlideBoundsForSlide ERROR " & Err.Number & ": " & Err.Description
End Sub

' =============================================================================
Public Sub AutoFitTemplateSlideBounds()
' =============================================================================
'   Manual helper: detects export blocks on one ReportSlide_NN sheet, then sets
'   PPT_SlideBounds around them using the configured PPTX slide aspect ratio.
    On Error GoTo CleanFail

    Dim rawSlideIdx As Variant
    rawSlideIdx = Application.InputBox( _
        Prompt:="Slide index cần auto-fit PPT_SlideBounds:", _
        Title:="AutoFit PPT_SlideBounds", _
        Default:=1, _
        Type:=1)
    If VarType(rawSlideIdx) = vbBoolean And rawSlideIdx = False Then Exit Sub

    AutoFitTemplateSlideBoundsForSlide CLng(rawSlideIdx)
    Exit Sub

CleanFail:
    Debug.Print "AutoFitTemplateSlideBounds ERROR " & Err.Number & ": " & Err.Description
End Sub

' =============================================================================
Public Sub AutoFitTemplateSlideBoundsForSlide(ByVal slideIdx As Long)
' =============================================================================
'   Can be called from Immediate Window, e.g.:
'       modStep4_TemplateExport.AutoFitTemplateSlideBoundsForSlide 2
    On Error GoTo CleanFail
    If slideIdx < 1 Then Err.Raise vbObjectError + 611, , "slideIdx must be >= 1."

    Dim ws As Worksheet
    Set ws = FindTemplateSheetBySlideIdx(slideIdx)
    If ws Is Nothing Then
        Err.Raise vbObjectError + 612, , "Template sheet not found for slide " & slideIdx & "."
    End If

    Dim contentBox As LayoutBox
    If Not TryGetExportBlocksBox(ws, contentBox) Then
        Err.Raise vbObjectError + 613, , "No PPT_* export block found on " & ws.Name & "."
    End If

    Dim pptApp As Object, pres As Object
    Dim pptxName As String: pptxName = ResolvePptxName()
    OpenPresentation pptApp, pres, pptxName
    If slideIdx > pres.Slides.Count Then
        Err.Raise vbObjectError + 614, , "Slide " & slideIdx & " is out of range. PPT has " & pres.Slides.Count & " slide(s)."
    End If

    Dim slideRatio As Double
    slideRatio = CDbl(pres.PageSetup.SlideWidth) / CDbl(pres.PageSetup.SlideHeight)

    Dim fittedBox As LayoutBox
    fittedBox.Left = contentBox.Left
    fittedBox.Top = contentBox.Top
    fittedBox.Width = contentBox.Width
    fittedBox.Height = contentBox.Height
    ExpandBoxToAspect fittedBox, slideRatio

    Dim fittedRange As Range
    Set fittedRange = RangeFromBox(ws, fittedBox)
    SetSheetNamedRange ws, TPL_SLIDE_BOUNDS, fittedRange

    Debug.Print "AutoFitTemplateSlideBoundsForSlide: " & ws.Name & "!" & TPL_SLIDE_BOUNDS & _
                " -> " & fittedRange.Address(False, False) & _
                " | content L=" & Fmt(contentBox.Left) & " T=" & Fmt(contentBox.Top) & _
                " W=" & Fmt(contentBox.Width) & " H=" & Fmt(contentBox.Height) & _
                " | PPT ratio=" & Format$(slideRatio, "0.0000") & _
                " | Excel ratio=" & Format$(fittedRange.Width / fittedRange.Height, "0.0000")
    Exit Sub

CleanFail:
    Debug.Print "AutoFitTemplateSlideBoundsForSlide ERROR " & Err.Number & ": " & Err.Description
End Sub

Public Sub Step4_NoOp()
    Debug.Print "Step4_NoOp: module loaded."
End Sub

' =============================================================================
Public Sub ExportTemplateSlidesToPPT()
' =============================================================================
    Dim t0 As Double: t0 = Timer
    Dim prevEvents As Boolean: prevEvents = Application.EnableEvents
    Application.EnableEvents = False
    ' NOTE: do NOT set ScreenUpdating=False — slows Range.CopyPicture significantly.

    On Error GoTo CleanFail
    InitLog

    Dim pptApp As Object, pres As Object
    Dim pptxName As String: pptxName = ResolvePptxName()
    LogMsg "[..] PptxName resolved: " & pptxName
    OpenPresentation pptApp, pres, pptxName
    LogMsg "[OK] Opened presentation: " & pres.Name

    Dim ws As Worksheet
    Dim slideIdx As Long
    Dim exported As Long: exported = 0

    For Each ws In ThisWorkbook.Worksheets
        slideIdx = ParseSlideIdx(ws.Name)
        If slideIdx > 0 Then
            LogMsg "--- Template sheet: " & ws.Name & " -> slide " & slideIdx & " ---"
            If ValidateTemplate(ws, pres, slideIdx) Then
                exported = exported + ExportSheetBlocks(ws, pres, slideIdx)
            Else
                LogMsg "[SKIP] " & ws.Name & ": validation failed"
            End If
        End If
    Next ws

    LogMsg "=== ExportTemplateSlidesToPPT DONE. Blocks=" & exported & " Elapsed=" & Format$(Timer - t0, "0.00") & "s ==="
    FlushLog

CleanExit:
    Application.EnableEvents = prevEvents
    Exit Sub
CleanFail:
    LogMsg "[ERROR] ExportTemplateSlidesToPPT: " & Err.Number & " - " & Err.Description
    FlushLog
    Resume CleanExit
End Sub

' --- Validation ---------------------------------------------------------------
Private Function ValidateTemplate(ByVal ws As Worksheet, ByVal pres As Object, _
                                   ByVal slideIdx As Long) As Boolean
    Dim bounds As Range
    Set bounds = FindNamedRange(ws, TPL_SLIDE_BOUNDS)
    If bounds Is Nothing Then
        LogMsg "  [ERR] " & TPL_SLIDE_BOUNDS & " missing on " & ws.Name
        Exit Function
    End If
    If bounds.Width <= 0 Or bounds.Height <= 0 Then
        LogMsg "  [ERR] " & TPL_SLIDE_BOUNDS & " has zero area"
        Exit Function
    End If
    If slideIdx < 1 Or slideIdx > pres.Slides.Count Then
        LogMsg "  [ERR] slide " & slideIdx & " out of range (PPT has " & pres.Slides.Count & ")"
        Exit Function
    End If

    Dim nm As Name, blockCount As Long
    For Each nm In ThisWorkbook.Names
        If IsTemplateName(nm, ws) Then
            blockCount = blockCount + 1
            Dim r As Range
            Set r = SafeRefersToRange(nm)
            If r Is Nothing Then
                LogMsg "  [ERR] " & nm.Name & ": cannot resolve range"
                Exit Function
            End If
            If r.Width <= 0 Or r.Height <= 0 Then
                LogMsg "  [ERR] " & nm.Name & ": zero area"
                Exit Function
            End If
        End If
    Next nm

    If blockCount = 0 Then
        LogMsg "  [ERR] no PPT_* blocks found on " & ws.Name
        Exit Function
    End If

    LogMsg "  [OK] validation: bounds OK, blocks=" & blockCount
    ValidateTemplate = True
End Function

' --- Block dispatch -----------------------------------------------------------
Private Function ExportSheetBlocks(ByVal ws As Worksheet, ByVal pres As Object, _
                                    ByVal slideIdx As Long) As Long
    Dim bounds As Range: Set bounds = FindNamedRange(ws, TPL_SLIDE_BOUNDS)
    Dim sld As Object: Set sld = pres.Slides(slideIdx)

    Dim slideWidthPt  As Double: slideWidthPt = pres.PageSetup.SlideWidth
    Dim slideHeightPt As Double: slideHeightPt = pres.PageSetup.SlideHeight

    Dim nm As Name, count As Long
    For Each nm In ThisWorkbook.Names
        If IsTemplateName(nm, ws) Then
            If StrComp(nm.Name, TPL_SLIDE_BOUNDS, vbTextCompare) = 0 Then GoTo NextName
            If InStr(1, nm.Name, TPL_SLIDE_BOUNDS, vbTextCompare) > 0 Then GoTo NextName

            Dim shapeName As String
            shapeName = StripPptPrefix(nm.Name)
            Dim src As Range
            Set src = SafeRefersToRange(nm)

            LogMsg "  [..] " & nm.Name & " -> " & shapeName
            On Error Resume Next
            Err.Clear
            If StrComp(shapeName, "XL_DataTable", vbTextCompare) = 0 Then
                ExportAsEditableTable src, sld, shapeName, bounds, slideWidthPt, slideHeightPt
            Else
                ExportAsImage src, sld, shapeName, bounds, slideWidthPt, slideHeightPt
            End If
            If Err.Number <> 0 Then
                LogMsg "  [ERR] " & shapeName & ": " & Err.Number & " - " & Err.Description
                Err.Clear
            Else
                count = count + 1
                LogMsg "  [OK] " & shapeName
            End If
            On Error GoTo 0
        End If
NextName:
    Next nm
    ExportSheetBlocks = count
End Function

' --- Image export -------------------------------------------------------------
Private Sub ExportAsImage(ByVal srcRange As Range, ByVal sld As Object, _
                           ByVal shapeName As String, ByVal bounds As Range, _
                           ByVal slideW As Double, ByVal slideH As Double)
    DeleteShapeByName sld, shapeName

    Dim sr As Object
    Set sr = CopyAndPasteWithRetry(srcRange, sld, 5)
    Dim shp As Object
    If sr.Count > 0 Then Set shp = sr(1) Else Set shp = sr
    shp.Name = shapeName

    Dim p As LayoutBox
    p = MapToSlide(srcRange, bounds, slideW, slideH)
    shp.LockAspectRatio = 0  ' msoFalse — allow non-proportional set, then revert
    shp.Left = p.Left
    shp.Top = p.Top
    shp.Width = p.Width
    shp.Height = p.Height

    LogMsg "       src(pt) L=" & Fmt(srcRange.Left) & " T=" & Fmt(srcRange.Top) & _
           " W=" & Fmt(srcRange.Width) & " H=" & Fmt(srcRange.Height)
    LogMsg "       ppt(pt) L=" & Fmt(p.Left) & " T=" & Fmt(p.Top) & _
           " W=" & Fmt(p.Width) & " H=" & Fmt(p.Height)
End Sub

' --- Table export -------------------------------------------------------------
Private Sub ExportAsEditableTable(ByVal srcRange As Range, ByVal sld As Object, _
                                   ByVal shapeName As String, ByVal bounds As Range, _
                                   ByVal slideW As Double, ByVal slideH As Double)
    DeleteShapeByName sld, shapeName

    srcRange.Copy
    Dim sr As Object
    Set sr = sld.Shapes.PasteSpecial(ppPasteHTML)
    Application.CutCopyMode = False

    Dim shp As Object
    If sr.Count > 0 Then Set shp = sr(1) Else Set shp = sr
    shp.Name = shapeName

    ApplyTablePartSizes shp, srcRange

    Dim p As LayoutBox
    p = MapToSlide(srcRange, bounds, slideW, slideH)
    shp.Left = p.Left
    shp.Top = p.Top
    ' For editable table, width/height set by part config; only position from mapping.

    LogMsg "       src(pt) L=" & Fmt(srcRange.Left) & " T=" & Fmt(srcRange.Top) & _
           " W=" & Fmt(srcRange.Width) & " H=" & Fmt(srcRange.Height)
    LogMsg "       ppt(pt) L=" & Fmt(p.Left) & " T=" & Fmt(p.Top) & _
           " (size from part config)"
End Sub

Private Sub ApplyTablePartSizes(ByVal tableShape As Object, ByVal srcRange As Range)
    If Not tableShape.HasTable Then
        LogMsg "       WARNING: pasted shape is not editable table"
        Exit Sub
    End If

    Dim cfgWs As Worksheet
    On Error Resume Next
    Set cfgWs = ThisWorkbook.Sheets("ExportConfig")
    On Error GoTo 0
    If cfgWs Is Nothing Then
        LogMsg "       WARNING: ExportConfig sheet missing; skipping part sizing"
        Exit Sub
    End If

    Dim pptTable As Object: Set pptTable = tableShape.Table
    Dim rowIdx As Long
    For rowIdx = 1 To 5 Step 2
        Dim header As String
        header = LCase$(Trim$(CStr(cfgWs.Cells(rowIdx, 10).Value)))
        If InStr(1, header, "range", vbTextCompare) > 0 Then
            Dim addr As String: addr = Trim$(CStr(cfgWs.Cells(rowIdx + 1, 10).Value))
            Dim wPt As Double:  wPt = Val(cfgWs.Cells(rowIdx + 1, 11).Value)
            Dim hPt As Double:  hPt = Val(cfgWs.Cells(rowIdx + 1, 12).Value)
            Dim fPt As Double:  fPt = Val(cfgWs.Cells(rowIdx + 1, 13).Value)
            ApplyOnePart pptTable, srcRange, addr, wPt, hPt, fPt
        End If
    Next rowIdx
End Sub

Private Sub ApplyOnePart(ByVal pptTable As Object, ByVal srcRange As Range, _
                          ByVal partAddress As String, ByVal cellW As Double, _
                          ByVal cellH As Double, ByVal fontSize As Double)
    If Len(partAddress) = 0 Then Exit Sub
    Dim partRange As Range
    On Error Resume Next
    Set partRange = srcRange.Worksheet.Range(partAddress)
    On Error GoTo 0
    If partRange Is Nothing Then Exit Sub
    If Intersect(srcRange, partRange) Is Nothing Then Exit Sub

    Dim firstCol As Long: firstCol = partRange.Column - srcRange.Column + 1
    Dim lastCol  As Long: lastCol = firstCol + partRange.Columns.Count - 1
    Dim firstRow As Long: firstRow = partRange.Row - srcRange.Row + 1
    Dim lastRow  As Long: lastRow = firstRow + partRange.Rows.Count - 1

    If firstCol < 1 Then firstCol = 1
    If firstRow < 1 Then firstRow = 1
    If lastCol > pptTable.Columns.Count Then lastCol = pptTable.Columns.Count
    If lastRow > pptTable.Rows.Count Then lastRow = pptTable.Rows.Count

    Dim i As Long
    If cellW > 0 Then
        For i = firstCol To lastCol: pptTable.Columns(i).Width = cellW: Next i
    End If
    If cellH > 0 Then
        For i = firstRow To lastRow: pptTable.Rows(i).Height = cellH: Next i
    End If
    If fontSize > 0 Then
        Dim r As Long, c As Long
        For r = firstRow To lastRow
            For c = firstCol To lastCol
                pptTable.Cell(r, c).Shape.TextFrame.TextRange.Font.Size = fontSize
            Next c
        Next r
    End If
End Sub

' --- Copy + paste with clipboard retry ---------------------------------------
'   Re-copies on each retry (clipboard may be cleared by other apps). Uses DoEvents
'   for fast retry, no Application.Wait (1s min) since clipboard usually settles
'   within microseconds.
Private Function CopyAndPasteWithRetry(ByVal srcRange As Range, ByVal sld As Object, _
                                        ByVal maxAttempts As Long) As Object
    Dim attempt As Long, i As Long
    For attempt = 1 To maxAttempts
        srcRange.CopyPicture Appearance:=xlScreen, Format:=xlPicture
        ' Let clipboard settle. Extra DoEvents on later attempts.
        For i = 1 To attempt: DoEvents: Next i
        On Error Resume Next
        Err.Clear
        Set CopyAndPasteWithRetry = sld.Shapes.Paste
        If Err.Number = 0 Then
            On Error GoTo 0
            Exit Function
        End If
        Err.Clear
        On Error GoTo 0
    Next attempt
    Err.Raise vbObjectError + 501, , "Paste failed after " & maxAttempts & " attempts."
End Function

' --- Coordinate mapping -------------------------------------------------------
Private Function MapToSlide(ByVal src As Range, ByVal bounds As Range, _
                             ByVal slideW As Double, ByVal slideH As Double) As LayoutBox
    Dim out As LayoutBox
    out.Left = (src.Left - bounds.Left) / bounds.Width * slideW
    out.Top = (src.Top - bounds.Top) / bounds.Height * slideH
    out.Width = src.Width / bounds.Width * slideW
    out.Height = src.Height / bounds.Height * slideH
    MapToSlide = out
End Function

' --- Helpers ------------------------------------------------------------------
Private Function ParseSlideIdx(ByVal sheetName As String) As Long
    If Len(sheetName) <= Len(TPL_SHEET_PREFIX) Then Exit Function
    If StrComp(Left$(sheetName, Len(TPL_SHEET_PREFIX)), TPL_SHEET_PREFIX, vbTextCompare) <> 0 Then Exit Function
    Dim tail As String: tail = Mid$(sheetName, Len(TPL_SHEET_PREFIX) + 1)
    If Not IsNumeric(tail) Then Exit Function
    ParseSlideIdx = CLng(tail)
End Function

Private Function FindTemplateSheetBySlideIdx(ByVal slideIdx As Long) As Worksheet
    Dim ws As Worksheet
    For Each ws In ThisWorkbook.Worksheets
        If ParseSlideIdx(ws.Name) = slideIdx Then
            Set FindTemplateSheetBySlideIdx = ws
            Exit Function
        End If
    Next ws
End Function

Private Function BestBoundsRangeForAspect(ByVal seed As Range, ByVal targetRatio As Double) As Range
    If targetRatio <= 0 Then Err.Raise vbObjectError + 604, , "Invalid slide aspect ratio."

    Dim anchor As Range
    Set anchor = seed.Cells(1, 1)

    Dim colCount As Long: colCount = seed.Columns.Count
    If colCount < 1 Then colCount = 1

    Dim bestRows As Long: bestRows = seed.Rows.Count
    Dim bestDelta As Double: bestDelta = 1E+99
    Dim rowCount As Long
    Dim candidate As Range
    Dim ratio As Double
    Dim delta As Double

    For rowCount = 1 To 200
        Set candidate = anchor.Resize(rowCount, colCount)
        If candidate.Height > 0 Then
            ratio = candidate.Width / candidate.Height
            delta = Abs(ratio - targetRatio)
            If delta < bestDelta Then
                bestDelta = delta
                bestRows = rowCount
            End If
        End If
    Next rowCount

    Set BestBoundsRangeForAspect = anchor.Resize(bestRows, colCount)
End Function

Private Function TryGetExportBlocksBox(ByVal ws As Worksheet, ByRef outBox As LayoutBox) As Boolean
    Dim nm As Name
    Dim firstBlock As Boolean: firstBlock = True

    For Each nm In ThisWorkbook.Names
        If IsTemplateName(nm, ws) Then
            Dim baseName As String
            baseName = BaseNameFromName(nm.Name)
            If StrComp(baseName, TPL_SLIDE_BOUNDS, vbTextCompare) <> 0 Then
                Dim r As Range
                Set r = SafeRefersToRange(nm)
                If Not r Is Nothing Then
                    If firstBlock Then
                        outBox.Left = r.Left
                        outBox.Top = r.Top
                        outBox.Width = r.Width
                        outBox.Height = r.Height
                        firstBlock = False
                    Else
                        IncludeRangeInBox outBox, r
                    End If
                    Debug.Print "  [AutoFit source] " & nm.Name & " -> " & r.Address(False, False)
                End If
            End If
        End If
    Next nm

    TryGetExportBlocksBox = Not firstBlock
End Function

Private Sub IncludeRangeInBox(ByRef targetBox As LayoutBox, ByVal r As Range)
    Dim rightEdge As Double
    Dim bottomEdge As Double
    Dim newRight As Double
    Dim newBottom As Double

    rightEdge = targetBox.Left + targetBox.Width
    bottomEdge = targetBox.Top + targetBox.Height
    newRight = r.Left + r.Width
    newBottom = r.Top + r.Height

    If r.Left < targetBox.Left Then targetBox.Left = r.Left
    If r.Top < targetBox.Top Then targetBox.Top = r.Top
    If newRight > rightEdge Then rightEdge = newRight
    If newBottom > bottomEdge Then bottomEdge = newBottom

    targetBox.Width = rightEdge - targetBox.Left
    targetBox.Height = bottomEdge - targetBox.Top
End Sub

Private Sub ExpandBoxToAspect(ByRef targetBox As LayoutBox, ByVal targetRatio As Double)
    If targetRatio <= 0 Then Err.Raise vbObjectError + 615, , "Invalid slide aspect ratio."
    If targetBox.Width <= 0 Or targetBox.Height <= 0 Then Err.Raise vbObjectError + 616, , "Invalid content box."

    Dim currentRatio As Double
    Dim originalWidth As Double
    Dim originalHeight As Double
    currentRatio = targetBox.Width / targetBox.Height

    If currentRatio < targetRatio Then
        originalWidth = targetBox.Width
        targetBox.Width = targetBox.Height * targetRatio
        targetBox.Left = targetBox.Left - (targetBox.Width - originalWidth) / 2
    ElseIf currentRatio > targetRatio Then
        originalHeight = targetBox.Height
        targetBox.Height = targetBox.Width / targetRatio
        targetBox.Top = targetBox.Top - (targetBox.Height - originalHeight) / 2
    End If
End Sub

Private Function RangeFromBox(ByVal ws As Worksheet, ByRef sourceBox As LayoutBox) As Range
    Dim firstCell As Range
    Dim lastCell As Range
    Set firstCell = CellAtOrBeforePoint(ws, sourceBox.Left, sourceBox.Top)
    Set lastCell = CellAtOrAfterPoint(ws, sourceBox.Left + sourceBox.Width, sourceBox.Top + sourceBox.Height)
    Set RangeFromBox = ws.Range(firstCell, lastCell)
End Function

Private Function CellAtOrBeforePoint(ByVal ws As Worksheet, ByVal xPt As Double, ByVal yPt As Double) As Range
    Dim colIdx As Long
    Dim rowIdx As Long

    For colIdx = 1 To ws.Columns.Count
        If ws.Cells(1, colIdx).Left + ws.Cells(1, colIdx).Width >= xPt Then Exit For
    Next colIdx
    If colIdx > ws.Columns.Count Then colIdx = ws.Columns.Count

    For rowIdx = 1 To ws.Rows.Count
        If ws.Cells(rowIdx, 1).Top + ws.Cells(rowIdx, 1).Height >= yPt Then Exit For
    Next rowIdx
    If rowIdx > ws.Rows.Count Then rowIdx = ws.Rows.Count

    Set CellAtOrBeforePoint = ws.Cells(rowIdx, colIdx)
End Function

Private Function CellAtOrAfterPoint(ByVal ws As Worksheet, ByVal xPt As Double, ByVal yPt As Double) As Range
    Dim colIdx As Long
    Dim rowIdx As Long

    For colIdx = 1 To ws.Columns.Count
        If ws.Cells(1, colIdx).Left >= xPt Then Exit For
    Next colIdx
    If colIdx > ws.Columns.Count Then colIdx = ws.Columns.Count

    For rowIdx = 1 To ws.Rows.Count
        If ws.Cells(rowIdx, 1).Top >= yPt Then Exit For
    Next rowIdx
    If rowIdx > ws.Rows.Count Then rowIdx = ws.Rows.Count

    Set CellAtOrAfterPoint = ws.Cells(rowIdx, colIdx)
End Function

Private Sub SetSheetNamedRange(ByVal ws As Worksheet, ByVal nameBase As String, ByVal targetRange As Range)
    Dim refersToText As String
    refersToText = "='" & Replace(ws.Name, "'", "''") & "'!" & targetRange.Address(True, True)

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
                    nm.RefersTo = refersToText
                    Exit Sub
                End If
            End If
        End If
    Next nm

    ws.Names.Add Name:=nameBase, RefersTo:=refersToText
End Sub

Private Function BaseNameFromName(ByVal fullName As String) As String
    Dim sepPos As Long
    sepPos = InStrRev(fullName, "!")
    If sepPos > 0 Then
        BaseNameFromName = Mid$(fullName, sepPos + 1)
    Else
        BaseNameFromName = fullName
    End If
End Function

Private Function IsTemplateName(ByVal nm As Name, ByVal ws As Worksheet) As Boolean
    Dim shortName As String: shortName = nm.Name
    Dim dotPos As Long: dotPos = InStr(1, shortName, "!")
    If dotPos > 0 Then shortName = Mid$(shortName, dotPos + 1)

    If Len(nm.Name) < Len(TPL_NAME_PREFIX) Then Exit Function

    Dim baseName As String: baseName = nm.Name
    Dim sepPos As Long: sepPos = InStrRev(baseName, "!")
    If sepPos > 0 Then baseName = Mid$(baseName, sepPos + 1)

    If StrComp(Left$(baseName, Len(TPL_NAME_PREFIX)), TPL_NAME_PREFIX, vbTextCompare) <> 0 Then Exit Function

    Dim r As Range
    Set r = SafeRefersToRange(nm)
    If r Is Nothing Then Exit Function
    If r.Worksheet.Name <> ws.Name Then Exit Function
    IsTemplateName = True
End Function

Private Function FindNamedRange(ByVal ws As Worksheet, ByVal nameBase As String) As Range
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

Private Function SafeRefersToRange(ByVal nm As Name) As Range
    On Error Resume Next
    Set SafeRefersToRange = nm.RefersToRange
    On Error GoTo 0
End Function

Private Function StripPptPrefix(ByVal fullName As String) As String
    Dim baseName As String: baseName = fullName
    Dim sepPos As Long: sepPos = InStrRev(baseName, "!")
    If sepPos > 0 Then baseName = Mid$(baseName, sepPos + 1)
    If StrComp(Left$(baseName, Len(TPL_NAME_PREFIX)), TPL_NAME_PREFIX, vbTextCompare) = 0 Then
        StripPptPrefix = Mid$(baseName, Len(TPL_NAME_PREFIX) + 1)
    Else
        StripPptPrefix = baseName
    End If
End Function

Private Sub DeleteShapeByName(ByVal sld As Object, ByVal sName As String)
    Dim i As Long
    For i = sld.Shapes.Count To 1 Step -1
        If StrComp(sld.Shapes(i).Name, sName, vbTextCompare) = 0 Then
            sld.Shapes(i).Delete
        End If
    Next i
End Sub

Private Function Fmt(ByVal v As Double) As String
    Fmt = Format$(v, "0.00")
End Function

' --- PowerPoint open ----------------------------------------------------------
Private Sub OpenPresentation(ByRef pptApp As Object, ByRef pres As Object, _
                              ByVal pptxName As String)
    Dim pptxPath As String
    If Mid$(pptxName, 2, 1) = ":" Or Left$(pptxName, 2) = "\\" Then
        pptxPath = pptxName
    Else
        pptxPath = ThisWorkbook.Path & "\" & pptxName
    End If

    On Error Resume Next
    Set pptApp = GetObject(, "PowerPoint.Application")
    On Error GoTo 0
    If pptApp Is Nothing Then
        Set pptApp = CreateObject("PowerPoint.Application")
        pptApp.Visible = True
    End If

    Dim leaf As String: leaf = Dir$(pptxPath)
    Dim p As Object
    For Each p In pptApp.Presentations
        If StrComp(p.Name, leaf, vbTextCompare) = 0 Then
            Set pres = p: Exit Sub
        End If
    Next p
    Set pres = pptApp.Presentations.Open(pptxPath)
End Sub

' --- Logging (buffered, single flush at end) ----------------------------------
Private Sub InitLog()
    mLogBuf = "=== ExportTemplateSlidesToPPT START " & Now & " ===" & vbCrLf
End Sub

Private Sub LogMsg(ByVal msg As String)
    Debug.Print msg
    mLogBuf = mLogBuf & msg & vbCrLf
End Sub

Private Sub FlushLog()
    On Error Resume Next
    Dim path As String: path = ThisWorkbook.Path & "\" & TPL_LOG_FILE
    Dim fn As Integer: fn = FreeFile
    Open path For Output As #fn
    Print #fn, mLogBuf;
    Close #fn
    mLogBuf = ""
End Sub
