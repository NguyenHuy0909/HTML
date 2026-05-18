Attribute VB_Name = "modShape"
Option Explicit

' =============================================================================
' modShape — Shape utilities for report template sheets.
'
' Public:
'   AddLabel — duplicate each "TextBox {X}{Y}" label, place the copy at the
'              corresponding vertical line, then resolve overlaps.
'
' Naming convention:
'   TextBox name : "TextBox " + X + Y   e.g. "TextBox 11", "TextBox 23"
'   Line name    : "Line_" & ws.Name & "_G" & Y & "_" & X
'
'   hàng chục (X) → số thứ tự line  (tens  digit = line index)
'   hàng đơn vị (Y) → chỉ số group  (units digit = group)
'
' Overlap resolution (iterative, clamp to winner PlotArea bounds):
'   Step 1: flip to other edge of line
'   Step 2: shift down  (only if stays within PlotArea)
'   Step 3: shift up    (only if stays within PlotArea)
' =============================================================================

Private Const MAX_COPIES      As Long = 50

' =============================================================================
' ── Hardcode cho PlaceLabelVertical — SỬA Ở ĐÂY NẾU CẦN ────────────────────
'
'   Hàng dữ liệu = LINE_BASE_ROW + lineIdx
'     lineIdx 1 → hàng 5,  lineIdx 2 → hàng 6,  lineIdx 3 → hàng 7
'
'   Cột bắt đầu theo group (mỗi group dùng 3 cột liên tiếp):
'     group "1" → I J K  = cột 9  10 11
'     group "2" → M N O  = cột 13 14 15
'     group "3" → Q R S  = cột 17 18 19
' =============================================================================
Private Const LINE_BASE_ROW  As Long = 4   ' line 1→row5, line 2→row6, line 3→row7
Private Const GRP1_COL_START As Long = 9   ' group "1": I(9)  J(10) K(11)
Private Const GRP2_COL_START As Long = 13  ' group "2": M(13) N(14) O(15)
Private Const GRP3_COL_START As Long = 17  ' group "3": Q(17) R(18) S(19)

' =============================================================================
' ── Hardcode cho ResolveOverlaps — SỬA Ở ĐÂY NẾU CẦN ───────────────────────
Private Const MAX_RESOLVE_ITER As Long = 20   ' số vòng lặp tối đa

' =============================================================================
Public Sub AddLabel()
' =============================================================================
    Dim ws As Worksheet: Set ws = ActiveSheet

    Dim shp      As Shape
    Dim lineShp  As Shape
    Dim copyShp  As Shape
    Dim suffix   As String
    Dim grp      As String
    Dim idx      As String
    Dim lineName As String
    Dim copyName As String
    Dim i        As Long

    ' ── Pass 1: collect matching templates (no mutation of ws.Shapes) ────────
    Dim templates(1 To MAX_COPIES) As Shape
    Dim tCount As Long

    For Each shp In ws.Shapes
        If Left$(shp.Name, 8) <> "TextBox " Then GoTo SkipCollect
        suffix = Mid$(shp.Name, 9)
        If Len(suffix) >= 2 And IsNumeric(suffix) Then
            tCount = tCount + 1
            Set templates(tCount) = shp
        End If
SkipCollect:
    Next shp

    ' ── Pass 2: delete old copies, duplicate, position ───────────────────────
    Dim copies(1 To MAX_COPIES)    As Shape
    Dim lineLefts(1 To MAX_COPIES) As Double
    Dim paTops(1 To MAX_COPIES)    As Double   ' InsidePlotArea top  (ws coords)
    Dim paBots(1 To MAX_COPIES)    As Double   ' InsidePlotArea bottom (ws coords)
    Dim n As Long

    For i = 1 To tCount
        Set shp = templates(i)
        suffix = Mid$(shp.Name, 9)
        idx = Left$(suffix, 1)
        grp = Mid$(suffix, 2)

        lineName = "Line_" & ws.Name & "_G" & grp & "_" & idx
        Set lineShp = Nothing
        On Error Resume Next
        Set lineShp = ws.Shapes(lineName)
        On Error GoTo 0

        If lineShp Is Nothing Then
            Debug.Print "AddLabel: line not found — " & lineName & _
                        "  (for """ & shp.Name & """)"
            GoTo NextTpl
        End If

        copyName = "LabelOut_G" & grp & "_" & idx
        On Error Resume Next
        ws.Shapes(copyName).Delete
        On Error GoTo 0

        Set copyShp = shp.Duplicate()
        copyShp.Left = lineShp.Left
        copyShp.Name = copyName

        n = n + 1
        lineLefts(n) = lineShp.Left
        paTops(n)    = 0       ' fallback: no constraint
        paBots(n)    = 99999

        PlaceLabelVertical copyShp, ws, grp, CLng(idx), paTops(n), paBots(n)
        Set copies(n) = copyShp

        Debug.Print "AddLabel: """ & shp.Name & """ → """ & copyName & _
                    """  Left=" & Format$(copyShp.Left, "0.0") & _
                    "  Top=" & Format$(copyShp.Top, "0.0") & "  <- " & lineName
NextTpl:
    Next i

    ' ── Resolve overlaps (iterative, clamp to PlotArea) ──────────────────────
    If n > 1 Then ResolveOverlaps copies, lineLefts, paTops, paBots, n

    MsgBox "AddLabel done.  " & n & " label(s) placed on [" & ws.Name & "].", _
           vbInformation, "AddLabel"
End Sub

' =============================================================================
' ResolveOverlaps — iterative greedy pairwise, label vs label.
'   Shift down/up chỉ được thực hiện nếu vị trí mới nằm trong [paTop, paBot].
' =============================================================================
Private Sub ResolveOverlaps(ByRef copies()    As Shape, _
                             ByRef lineLefts() As Double, _
                             ByRef paTops()    As Double, _
                             ByRef paBots()    As Double, _
                             ByVal n           As Long)
    Const GAP As Double = 2
    Dim i As Long, j As Long
    Dim origLeft As Double, origTop As Double
    Dim newTop   As Double
    Dim anyMoved As Boolean
    Dim iter     As Long

    For iter = 1 To MAX_RESOLVE_ITER
        anyMoved = False

        For i = 1 To n - 1
            For j = i + 1 To n
                If Not ShapesOverlap(copies(i), copies(j)) Then GoTo NextPair

                origLeft = copies(j).Left
                origTop  = copies(j).Top

                ' Step 1: flip (không đổi Top → không cần clamp dọc)
                copies(j).Left = lineLefts(j) - copies(j).Width
                If Not ShapesOverlap(copies(i), copies(j)) Then
                    Debug.Print "  Resolved (flip): " & copies(j).Name
                    anyMoved = True: GoTo NextPair
                End If
                copies(j).Left = origLeft

                ' Step 2: shift xuống — chỉ nếu vẫn trong PlotArea
                newTop = origTop + copies(j).Height + GAP
                If newTop + copies(j).Height <= paBots(j) Then
                    copies(j).Top = newTop
                    If Not ShapesOverlap(copies(i), copies(j)) Then
                        Debug.Print "  Resolved (down): " & copies(j).Name
                        anyMoved = True: GoTo NextPair
                    End If
                    copies(j).Top = origTop
                End If

                ' Step 3: shift lên — chỉ nếu vẫn trong PlotArea
                newTop = origTop - copies(j).Height - GAP
                If newTop >= paTops(j) Then
                    copies(j).Top = newTop
                    If Not ShapesOverlap(copies(i), copies(j)) Then
                        Debug.Print "  Resolved (up): " & copies(j).Name
                        anyMoved = True: GoTo NextPair
                    End If
                    copies(j).Top = origTop
                End If

                Debug.Print "  Unresolved: " & copies(i).Name & " <-> " & copies(j).Name

NextPair:
            Next j
        Next i

        If Not anyMoved Then Exit For
    Next iter
    Debug.Print "ResolveOverlaps: " & iter & " iteration(s)"
End Sub

' =============================================================================
' ShapesOverlap — true nếu bounding box của a và b giao nhau.
' =============================================================================
Private Function ShapesOverlap(ByVal a As Shape, ByVal b As Shape) As Boolean
    ShapesOverlap = Not (a.Left + a.Width  <= b.Left   Or _
                         b.Left + b.Width  <= a.Left   Or _
                         a.Top  + a.Height <= b.Top    Or _
                         b.Top  + b.Height <= a.Top)
End Function

' =============================================================================
' PlaceLabelVertical — đặt copyShp.Top vào giữa InsidePlotArea của chart
'   có |giá trị| lớn nhất trong nhóm cột ứng với group, hàng ứng với lineIdx.
'   Trả về outPaTop / outPaBot (ws coords) của PlotArea để clamp sau này.
' =============================================================================
Private Sub PlaceLabelVertical(ByVal copyShp  As Shape, _
                               ByVal ws       As Worksheet, _
                               ByVal grp      As String, _
                               ByVal lineIdx  As Long, _
                               ByRef outPaTop As Double, _
                               ByRef outPaBot As Double)
    ' ── Xác định cột bắt đầu theo group ─────────────────────────────────────
    Dim colStart As Long
    Select Case grp
        Case "1": colStart = GRP1_COL_START
        Case "2": colStart = GRP2_COL_START
        Case "3": colStart = GRP3_COL_START
        Case Else
            Debug.Print "PlaceLabelVertical: unknown group '" & grp & "'"
            Exit Sub
    End Select

    Dim dataRow As Long: dataRow = LINE_BASE_ROW + lineIdx

    ' ── Lấy tên chart từ POINT Group trong ExportConfig ──────────────────────
    Dim cfgWs As Worksheet
    Set cfgWs = modConfig.GetConfigSheet()
    If cfgWs Is Nothing Then Exit Sub

    Dim colGrp    As Long: colGrp    = modConfig.FindHeaderCol(cfgWs, modConfig.HDR_GROUP)
    Dim colPoints As Long: colPoints = modConfig.FindHeaderCol(cfgWs, modConfig.HDR_POINTS)
    If colGrp = 0 Or colPoints = 0 Then
        Debug.Print "PlaceLabelVertical: missing header(s) in ExportConfig"
        Exit Sub
    End If

    Dim chartNamesStr As String
    Dim r As Long
    For r = modConfig.HDR_ROW + 1 To modConfig.CFG_MAX_ROW
        Dim gVal As String: gVal = Trim$(CStr(cfgWs.Cells(r, colGrp).Value))
        Dim pVal As String: pVal = Trim$(CStr(cfgWs.Cells(r, colPoints).Value))
        If Len(gVal) = 0 And Len(pVal) = 0 Then Exit For
        If StrComp(gVal, grp, vbTextCompare) = 0 And Len(pVal) > 0 Then
            chartNamesStr = pVal: Exit For
        End If
    Next r

    If Len(chartNamesStr) = 0 Then
        Debug.Print "PlaceLabelVertical: group '" & grp & "' not found"
        Exit Sub
    End If

    Dim chartNames() As String
    chartNames = SplitTrim(chartNamesStr, modConfig.SEPARATOR)
    Dim nCharts As Long: nCharts = UBound(chartNames) - LBound(chartNames) + 1

    ' ── Tìm chart thắng: |giá trị| lớn nhất ─────────────────────────────────
    Dim winnerIdx As Long: winnerIdx = 0
    Dim maxAbs    As Double: maxAbs = -1
    Dim k As Long
    For k = 0 To nCharts - 1
        Dim v As Variant
        On Error Resume Next
        v = ws.Cells(dataRow, colStart + k).Value
        On Error GoTo 0
        If IsNumeric(v) Then
            Dim absV As Double: absV = Abs(CDbl(v))
            If absV > maxAbs Then maxAbs = absV: winnerIdx = k
        End If
    Next k

    If maxAbs < 0 Then
        Debug.Print "PlaceLabelVertical: no value, grp=" & grp & " lineIdx=" & lineIdx
        Exit Sub
    End If

    ' ── Đặt Top vào giữa InsidePlotArea; lưu bounds ──────────────────────────
    Dim winnerName As String: winnerName = chartNames(LBound(chartNames) + winnerIdx)
    Dim co As ChartObject
    On Error Resume Next
    Set co = ws.ChartObjects(winnerName)
    On Error GoTo 0
    If co Is Nothing Then
        Debug.Print "PlaceLabelVertical: chart not found — " & winnerName
        Exit Sub
    End If

    Dim pa As PlotArea: Set pa = co.Chart.PlotArea
    outPaTop = co.Top + pa.InsideTop
    outPaBot = outPaTop + pa.InsideHeight
    copyShp.Top = outPaTop + (pa.InsideHeight - copyShp.Height) / 2

    Debug.Print "PlaceLabelVertical: grp=" & grp & " lineIdx=" & lineIdx & _
                " winner=" & winnerName & " Top=" & Format$(copyShp.Top, "0.0") & _
                " [" & Format$(outPaTop, "0.0") & ".." & Format$(outPaBot, "0.0") & "]"
End Sub

' =============================================================================
' SplitTrim — split on sep and trim each part.
' =============================================================================
Private Function SplitTrim(ByVal s As String, ByVal sep As String) As String()
    Dim parts() As String
    parts = Split(s, sep)
    Dim i As Long
    For i = LBound(parts) To UBound(parts)
        parts(i) = Trim$(parts(i))
    Next i
    SplitTrim = parts
End Function
