' DeepSeek 计费时段挂件 - 启动器（无窗口）
Option Explicit
Dim fso, wsh, baseDir, scriptPath, commandLine, quote
Set fso = CreateObject("Scripting.FileSystemObject")
Set wsh = CreateObject("WScript.Shell")
baseDir = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = baseDir & "\DeepSeekClock.ps1"
If Not fso.FileExists(scriptPath) Then
    MsgBox "DeepSeekClock.ps1 not found. Keep the whole DeepSeekClock folder together.", 16, "DeepSeek Clock"
    WScript.Quit 1
End If
quote = Chr(34)
commandLine = "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File " & quote & scriptPath & quote
wsh.Run commandLine, 0, False
