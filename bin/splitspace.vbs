Dim objShell, fso, scriptDir, psScript, cmd, targetApp

Set objShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psScript = fso.BuildPath(scriptDir, "splitspace.ps1")

targetApp = ""
If WScript.Arguments.Count > 0 Then
    targetApp = " -AppName """ & WScript.Arguments(0) & """"
End If

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScript & """" & targetApp
objShell.Run cmd, 0, False
