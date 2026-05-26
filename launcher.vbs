Dim shell, scriptDir, chooser, inputFile
Set shell = CreateObject("WScript.Shell")
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
chooser   = scriptDir & "chooser.ps1"
inputFile = WScript.Arguments(0)
shell.Run "powershell.exe -ExecutionPolicy Bypass -NonInteractive -File """ & chooser & """ -InputFile """ & inputFile & """", 0, False
