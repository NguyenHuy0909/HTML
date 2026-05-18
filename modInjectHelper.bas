Attribute VB_Name = "modInjectHelper"
Option Explicit

' =============================================================================
' Paste this module into VBE (Alt+F11), then run from Immediate Window:
'   modInjectHelper.InjectAllReportModules
'
' What it does:
'   1. Removes old modStep4_* modules (if any)
'   2. Removes existing modReport_* modules (if any)
'   3. Imports all 7 modReport_*.bas files from ThisWorkbook.Path
'   4. Saves the workbook
'
' After successful inject, you can delete this module and run:
'   modReport_Runner.RunAll
' =============================================================================

Public Sub InjectAllReportModules()
    Dim basePath As String: basePath = ThisWorkbook.Path & "\"
    
    ' --- Module lists ---
    Dim oldMods As Variant
    oldMods = Array("modStep4_Config", "modStep4_Layout", "modStep4_PPTHelper", _
                    "modStep4_TemplateExport", "modStep4_LineBuilder", _
                    "modStep4_TextBox", "modStep4_Runner")
    
    Dim newMods As Variant
    newMods = Array("modReport_Config", "modReport_Layout", "modReport_Presenter", _
                    "modReport_LineBuilder", "modReport_Label", _
                    "modReport_Export", "modReport_Runner")
    
    Dim vbp As Object: Set vbp = ThisWorkbook.VBProject
    Dim i As Long
    
    ' --- 1. Remove old modStep4_* ---
    For i = LBound(oldMods) To UBound(oldMods)
        RemoveModuleIfExists vbp, CStr(oldMods(i))
    Next i
    
    ' --- 2. Remove existing modReport_* (for clean re-import) ---
    For i = LBound(newMods) To UBound(newMods)
        RemoveModuleIfExists vbp, CStr(newMods(i))
    Next i
    
    ' --- 3. Import all .bas files ---
    Dim imported As Long
    For i = LBound(newMods) To UBound(newMods)
        Dim filePath As String: filePath = basePath & CStr(newMods(i)) & ".bas"
        If Dir$(filePath) <> "" Then
            vbp.VBComponents.Import filePath
            Debug.Print "  Imported: " & CStr(newMods(i))
            imported = imported + 1
        Else
            Debug.Print "  WARNING: not found: " & filePath
        End If
    Next i
    
    ' --- 4. Save ---
    ThisWorkbook.Save
    
    Debug.Print "=== InjectAllReportModules done. Imported " & imported & "/7 modules. ==="
    Debug.Print "=== Now run:  modReport_Runner.RunAll ==="
End Sub

Private Sub RemoveModuleIfExists(ByVal vbp As Object, ByVal modName As String)
    Dim comp As Object
    For Each comp In vbp.VBComponents
        If comp.Name = modName Then
            vbp.VBComponents.Remove comp
            Debug.Print "  Removed: " & modName
            Exit Sub
        End If
    Next comp
End Sub
