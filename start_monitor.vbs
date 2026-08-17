' DeepSeek-V4-Flash peak-price monitor - flash-free launcher (no console window)
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\deepseek_peak_monitor.ps1"""
Set sh = CreateObject("WScript.Shell")
sh.Run cmd, 0, False
