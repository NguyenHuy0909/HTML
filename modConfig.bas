Option Explicit
' Shared constants and ExportConfig sheet management
' Used by modStep1, modStep3_Export

Public Const DATA_SHEET_NAME   As String = "Sheet1"
Public Const CONFIG_SHEET_NAME As String = "ExportConfig"

Private Const SETTING_COL_KEY   As Long = 15  ' column O
Private Const SETTING_COL_VAL   As Long = 16  ' column P
Private Const SETTING_FIRST_ROW As Long = 2

Public Function ReadConfigSetting(ByVal ws As Worksheet, ByVal settingName As String, _
                                   Optional ByVal defaultValue As Variant = "") As Variant
    Dim r As Long
    For r = SETTING_FIRST_ROW To 100
        If Len(Trim$(CStr(ws.Cells(r, SETTING_COL_KEY).Value))) = 0 Then Exit For
        If StrComp(Trim$(CStr(ws.Cells(r, SETTING_COL_KEY).Value)), settingName, vbTextCompare) = 0 Then
            ReadConfigSetting = ws.Cells(r, SETTING_COL_VAL).Value
            Exit Function
        End If
    Next r
    ReadConfigSetting = defaultValue
End Function

Public Function GetDataSheetName(ByVal cfgWs As Worksheet) As String
    GetDataSheetName = CStr(ReadConfigSetting(cfgWs, "DataSheetName", DATA_SHEET_NAME))
End Function

' =============================================================================
Public Sub SetupExportConfig()
' =============================================================================
    On Error GoTo CleanFail
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Sheets(CONFIG_SHEET_NAME)
    On Error GoTo CleanFail

    If ws Is Nothing Then
        Set ws = ThisWorkbook.Sheets.Add(After:=ThisWorkbook.Sheets(ThisWorkbook.Sheets.Count))
        ws.Name = CONFIG_SHEET_NAME
    Else
        ws.Cells.Clear
    End If

    Dim hdr As Variant
    hdr = Array("ShapeName", "SlideIdx", "SourceType", "SourceRef", _
                "DefaultLeft", "DefaultTop", "DefaultWidth", "DefaultHeight")
    Dim c As Long
    For c = 0 To UBound(hdr)
        ws.Cells(1, c + 1).Value = hdr(c)
    Next c
    ws.Rows(1).Font.Bold = True

    WriteRow ws, 2, "XL_DataTable", 1, "RangeTable", "AD7:AY12", _
             20, 15, 874, 72
    WriteTablePartConfig ws

    WriteRow ws, 3, "XL_Group1", 1, "GroupImage", "Chart 1|Chart 2|Chart 3|Chart 100", _
             0, 95, 210, 0
    WriteRow ws, 4, "XL_Group2", 1, "GroupImage", "Chart 5|Chart 6|Chart 7|Chart 101", _
             0, 0, 0, 0
    WriteRow ws, 5, "XL_Group3", 1, "GroupImage", "Chart 9|Chart 10|Chart 11|Chart 102", _
             0, 0, 0, 0
    WriteRow ws, 6, "XL_Group4", 1, "GroupImage", "Chart 13|Chart 14|Chart 15|Chart 103", _
             0, 0, 0, 0
    WriteRow ws, 7, "XL_Group5", 1, "GroupImage", "Chart 16|Chart 17|Chart 18|Chart 104", _
             0, 0, 0, 0

    WriteStep2ScoreRangeConfig ws
    WriteSettings ws

    ws.Columns("A:P").AutoFit
    AddOrReplaceComment ws.Cells(3, 5), "Set Left/Top/Width for Group1 here. Height=0 = auto aspect ratio."
    AddOrReplaceComment ws.Cells(1, 10), "RangeTable part sizing. SourceRef is the full pasted table range; J:M blocks define subrange width/height/font."
    Debug.Print "SetupExportConfig: done."
    Exit Sub
CleanFail:
    Debug.Print "SetupExportConfig ERROR " & Err.Number & ": " & Err.Description
End Sub

' =============================================================================
Public Sub UpdateExportConfigTableSettings()
' =============================================================================
    Const DATA_TABLE_SHAPE As String = "XL_DataTable"
    Const DATA_TABLE_RANGE As String = "AD7:AY12"

    On Error GoTo CleanFail

    Dim ws As Worksheet
    Set ws = ThisWorkbook.Sheets(CONFIG_SHEET_NAME)

    UpdateSourceRefByShapeName ws, DATA_TABLE_SHAPE, DATA_TABLE_RANGE
    EnsureGroupImageRow ws, "XL_Group2", 1, "Chart 5|Chart 6|Chart 7|Chart 101"
    EnsureGroupImageRow ws, "XL_Group3", 1, "Chart 9|Chart 10|Chart 11|Chart 102"
    EnsureGroupImageRow ws, "XL_Group4", 1, "Chart 13|Chart 14|Chart 15|Chart 103"
    EnsureGroupImageRow ws, "XL_Group5", 1, "Chart 16|Chart 17|Chart 18|Chart 104"
    WriteTablePartConfig ws
    WriteStep2ScoreRangeConfig ws
    WriteSettings ws

    ws.Columns("A:P").AutoFit
    Debug.Print "UpdateExportConfigTableSettings: done."
    Exit Sub

CleanFail:
    Debug.Print "UpdateExportConfigTableSettings ERROR " & Err.Number & ": " & Err.Description
End Sub

' --- Private helpers ---

Private Sub WriteRow(ByVal ws As Worksheet, ByVal r As Long, _
                     ByVal sName As String, ByVal slideIdx As Long, _
                     ByVal srcType As String, ByVal srcRef As String, _
                     ByVal dL As Double, ByVal dT As Double, _
                     ByVal dW As Double, ByVal dH As Double)
    ws.Cells(r, 1).Value = sName
    ws.Cells(r, 2).Value = slideIdx
    ws.Cells(r, 3).Value = srcType
    ws.Cells(r, 4).Value = srcRef
    ws.Cells(r, 5).Value = dL
    ws.Cells(r, 6).Value = dT
    ws.Cells(r, 7).Value = dW
    ws.Cells(r, 8).Value = dH
End Sub

Private Sub UpdateSourceRefByShapeName(ByVal ws As Worksheet, _
                                        ByVal shapeName As String, _
                                        ByVal sourceRef As String)
    Dim r As Long
    r = 2
    Do While Len(Trim$(ws.Cells(r, 1).Value)) > 0
        If StrComp(Trim$(ws.Cells(r, 1).Value), shapeName, vbTextCompare) = 0 Then
            ws.Cells(r, 4).Value = sourceRef
            Exit Sub
        End If
        r = r + 1
    Loop
    Err.Raise vbObjectError + 301, , "ShapeName not found in ExportConfig: " & shapeName
End Sub

Private Sub EnsureGroupImageRow(ByVal ws As Worksheet, _
                                ByVal shapeName As String, _
                                ByVal slideIdx As Long, _
                                ByVal sourceRef As String)
    Dim r As Long
    r = 2
    Do While Len(Trim$(ws.Cells(r, 1).Value)) > 0
        If StrComp(Trim$(ws.Cells(r, 1).Value), shapeName, vbTextCompare) = 0 Then
            ws.Cells(r, 2).Value = slideIdx
            ws.Cells(r, 3).Value = "GroupImage"
            ws.Cells(r, 4).Value = sourceRef
            Exit Sub
        End If
        r = r + 1
    Loop
    WriteRow ws, r, shapeName, slideIdx, "GroupImage", sourceRef, 0, 0, 0, 0
End Sub

Private Sub WriteTablePartConfig(ByVal ws As Worksheet)
    ws.Range("J1:M6").ClearContents

    ws.Cells(1, 10).Value = "Part1Range"
    ws.Cells(1, 11).Value = "Part1CellWidthPt"
    ws.Cells(1, 12).Value = "Part1CellHeightPt"
    ws.Cells(1, 13).Value = "Part1FontSizePt"
    ws.Cells(2, 10).Value = "AD7:AD12"
    ws.Cells(2, 11).Value = 300
    ws.Cells(2, 12).Value = 10
    ws.Cells(2, 13).Value = 7

    ws.Cells(3, 10).Value = "Part2Range"
    ws.Cells(3, 11).Value = "Part2CellWidthPt"
    ws.Cells(3, 12).Value = "Part2CellHeightPt"
    ws.Cells(3, 13).Value = "Part2FontSizePt"
    ws.Cells(4, 10).Value = "AE7:AE12"
    ws.Cells(4, 11).Value = 300
    ws.Cells(4, 12).Value = 10
    ws.Cells(4, 13).Value = 7

    ws.Cells(5, 10).Value = "Part3Range"
    ws.Cells(5, 11).Value = "Part3CellWidthPt"
    ws.Cells(5, 12).Value = "Part3CellHeightPt"
    ws.Cells(5, 13).Value = "Part3FontSizePt"
    ws.Cells(6, 10).Value = "AF7:AY12"
    ws.Cells(6, 11).Value = 14
    ws.Cells(6, 12).Value = 10
    ws.Cells(6, 13).Value = 7

    ws.Range("J1:M1").Font.Bold = True
    ws.Range("J3:M3").Font.Bold = True
    ws.Range("J5:M5").Font.Bold = True
End Sub

Private Sub WriteStep2ScoreRangeConfig(ByVal ws As Worksheet)
    ws.Cells(1, 9).Value = "Step2Model1ScoreRange"
    WriteStep2ScoreRange ws, "XL_Group1", "AF10:AH10"
    WriteStep2ScoreRange ws, "XL_Group2", "AJ10:AL10"
    WriteStep2ScoreRange ws, "XL_Group3", "AN10:AP10"
    WriteStep2ScoreRange ws, "XL_Group4", "AR10:AT10"
    WriteStep2ScoreRange ws, "XL_Group5", "AV10:AX10"
End Sub

Private Sub WriteStep2ScoreRange(ByVal ws As Worksheet, _
                                 ByVal shapeName As String, _
                                 ByVal scoreRange As String)
    Dim r As Long
    r = 2
    Do While Len(Trim$(ws.Cells(r, 1).Value)) > 0
        If StrComp(Trim$(ws.Cells(r, 1).Value), shapeName, vbTextCompare) = 0 Then
            ws.Cells(r, 9).Value = scoreRange
            Exit Sub
        End If
        r = r + 1
    Loop
End Sub

Private Sub AddOrReplaceComment(ByVal cell As Range, ByVal txt As String)
    On Error Resume Next
    cell.Comment.Delete
    On Error GoTo 0
    cell.AddComment txt
End Sub

Private Sub WriteSettings(ByVal ws As Worksheet)
    ws.Cells(1, SETTING_COL_KEY).Value = "Setting"
    ws.Cells(1, SETTING_COL_VAL).Value = "Value"
    ws.Cells(1, SETTING_COL_KEY).Font.Bold = True
    ws.Cells(1, SETTING_COL_VAL).Font.Bold = True

    EnsureSetting ws, 2, "PptxName", "PresTest.pptx"
    EnsureSetting ws, 3, "BottomOffsetPt", 3
    EnsureSetting ws, 4, "DataSheetName", DATA_SHEET_NAME
    EnsureSetting ws, 5, "LabelLeftMarginPt", 1
    EnsureSetting ws, 6, "LabelRightMarginPt", 3

    ws.Columns(SETTING_COL_KEY).AutoFit
    ws.Columns(SETTING_COL_VAL).AutoFit
End Sub

Private Sub EnsureSetting(ByVal ws As Worksheet, ByVal r As Long, _
                           ByVal key As String, ByVal defaultValue As Variant)
    ws.Cells(r, SETTING_COL_KEY).Value = key
    If Len(Trim$(CStr(ws.Cells(r, SETTING_COL_VAL).Value))) = 0 Then
        ws.Cells(r, SETTING_COL_VAL).Value = defaultValue
    End If
End Sub
