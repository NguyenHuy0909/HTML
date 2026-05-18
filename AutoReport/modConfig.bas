Attribute VB_Name = "modConfig"
Option Explicit

' =============================================================================
' Centralized configuration reader + shared constants for all modules.
'
' Source: sheet "ExportConfig", column O = key, column P = value.
' Section headers (key starts with "#") and blank rows are skipped.
' Scan stops at row CFG_MAX_ROW.
'
' Typed getters: CfgStr / CfgLong / CfgDbl / CfgBool
' All return the supplied default if the key is missing or unparseable.
'
' Cache: rows are read once per session into mCfg(). Call InvalidateCache when
' the sheet changes mid-session.
' =============================================================================

' ── Sheet / table names ──────────────────────────────────────────────────────
' dùng: modConfig.GetConfigSheet, modConfig.EnsureLoaded, modScale.SetScale, modArrange.CreateLine
Public Const CFG_SHEET_NAME  As String = "ExportConfig"
' dùng: modConfig.EnsureLoaded
Public Const CFG_KEY_HEADER  As String = "Key"
' dùng: modConfig.EnsureLoaded
Public Const CFG_MAX_ROW     As Long = 500
' dùng: modLayout.ParseSlideIdx (default khi không có "TemplateSheetPrefix" trong config)
Public Const TPL_SHEET_PREFIX As String = "ReportSlide_"

' ── ExportConfig table headers ───────────────────────────────────────────────
' dùng: modScale.SetScale/FindHeaderColumn, modArrange.CreateLine/FindHeaderColumn, modPPT.SlideIdxFromConfig
Public Const HDR_ROW    As Long = 1
' dùng: modPPT.SlideIdxFromConfig
Public Const HDR_SLIDE  As String = "PPT Slide"
' dùng: modScale.SetScale, modArrange.CreateLine, modPPT.SlideIdxFromConfig
Public Const HDR_SHEET  As String = "SHEET NAME"
' dùng: modScale.SetScale, modArrange.CreateLine
Public Const HDR_POINTS As String = "POINT Group"
' dùng: modArrange.CreateLine, modPPT.SlideIdxFromConfig
Public Const HDR_GROUP  As String = "GROUP"
' dùng: modArrange.CreateLine
Public Const HDR_XVALUE  As String = "#XVALUE"

' ── ScaleControl table ───────────────────────────────────────────────────────
' dùng: modScale.ReadScaleTable, modArrange.ReadConfigCalib
Public Const SCALE_ANCHOR As String = "ScaleControl"

' ── Parsing ──────────────────────────────────────────────────────────────────
' dùng: modScale.SetScale, modArrange.ProcessGroup/ParsePointGroup
Public Const SEPARATOR As String = "|"

' ── Line style ───────────────────────────────────────────────────────────────
' dùng: modArrange.DrawVerticalLine
Public Const LINE_COLOR  As Long = 0       ' RGB(0,0,0)
' dùng: modArrange.DrawVerticalLine
Public Const LINE_WEIGHT As Double = 1.25

' =============================================================================
Private mCfgLoaded  As Boolean
Private mCfgKeys()  As String
Private mCfgValues() As String
Private mCfgCount   As Long
Private mKeyCol     As Long
Private mValCol     As Long

' =============================================================================
Public Function FindHeaderCol(ByVal ws As Worksheet, ByVal headerText As String) As Long
    Dim found As Range
    On Error Resume Next
    Set found = ws.Rows(HDR_ROW).Find(What:=headerText, LookIn:=xlValues, _
                                       LookAt:=xlWhole, MatchCase:=False)
    On Error GoTo 0
    If Not found Is Nothing Then FindHeaderCol = found.Column
End Function

Public Function GetConfigSheet() As Worksheet
    On Error Resume Next
    Set GetConfigSheet = ThisWorkbook.Sheets(CFG_SHEET_NAME)
    On Error GoTo 0
End Function

Public Function GetDataSheet() As Worksheet
    Dim n As String: n = CfgStr("DataSheetName", "ReportSlide_01")
    On Error Resume Next
    Set GetDataSheet = ThisWorkbook.Sheets(n)
    On Error GoTo 0
End Function

' --- Typed getters -----------------------------------------------------------
Public Function CfgStr(ByVal key As String, ByVal defaultVal As String) As String
    Dim v As String, found As Boolean
    v = Lookup(key, found)
    If found Then CfgStr = v Else CfgStr = defaultVal
End Function

Public Function CfgLong(ByVal key As String, ByVal defaultVal As Long) As Long
    Dim v As String, found As Boolean
    v = Lookup(key, found)
    If found And IsNumeric(v) Then CfgLong = CLng(CDbl(v)) Else CfgLong = defaultVal
End Function

Public Function CfgDbl(ByVal key As String, ByVal defaultVal As Double) As Double
    Dim v As String, found As Boolean
    v = Lookup(key, found)
    If found And IsNumeric(v) Then CfgDbl = CDbl(v) Else CfgDbl = defaultVal
End Function

Public Function CfgBool(ByVal key As String, ByVal defaultVal As Boolean) As Boolean
    Dim v As String, found As Boolean
    v = Lookup(key, found)
    If Not found Then CfgBool = defaultVal: Exit Function
    Select Case LCase$(Trim$(v))
        Case "1", "true", "yes", "y", "on": CfgBool = True
        Case "0", "false", "no", "n", "off": CfgBool = False
        Case Else: CfgBool = defaultVal
    End Select
End Function

' --- Cache management --------------------------------------------------------
Public Sub InvalidateCache()
    mCfgLoaded = False
    mCfgCount = 0
    mKeyCol = 0
    mValCol = 0
End Sub

Private Function Lookup(ByVal key As String, ByRef found As Boolean) As String
    EnsureLoaded
    found = False
    Dim i As Long
    For i = 1 To mCfgCount
        If StrComp(mCfgKeys(i), key, vbTextCompare) = 0 Then
            Lookup = mCfgValues(i)
            found = True
            Exit Function
        End If
    Next i
End Function

Private Sub EnsureLoaded()
    If mCfgLoaded Then Exit Sub
    mCfgCount = 0
    ReDim mCfgKeys(1 To CFG_MAX_ROW)
    ReDim mCfgValues(1 To CFG_MAX_ROW)

    Dim cfgWs As Worksheet: Set cfgWs = GetConfigSheet()
    If cfgWs Is Nothing Then mCfgLoaded = True: Exit Sub

    If mKeyCol = 0 Then
        Dim hdr As Range
        On Error Resume Next
        Set hdr = cfgWs.Rows(1).Find(What:=CFG_KEY_HEADER, LookIn:=xlValues, _
                                      LookAt:=xlWhole, MatchCase:=False)
        On Error GoTo 0
        If hdr Is Nothing Then
            Debug.Print "modConfig: header '" & CFG_KEY_HEADER & "' not found in row 1"
            mCfgLoaded = True: Exit Sub
        End If
        mKeyCol = hdr.Column
        mValCol = mKeyCol + 1
    End If

    Dim r As Long
    For r = 2 To CFG_MAX_ROW
        Dim k As String: k = Trim$(CStr(cfgWs.Cells(r, mKeyCol).Value))
        If Len(k) = 0 Then GoTo NextRow
        If Left$(k, 1) = "#" Then GoTo NextRow
        mCfgCount = mCfgCount + 1
        mCfgKeys(mCfgCount) = k
        mCfgValues(mCfgCount) = Trim$(CStr(cfgWs.Cells(r, mValCol).Value))
NextRow:
    Next r
    mCfgLoaded = True
End Sub
