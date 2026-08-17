@echo off
rem Build DeepSeekPeakMonitor.exe from exe_src\Program.cs
rem Uses the built-in .NET Framework C# compiler (csc.exe). No third-party tools needed.
cd /d "%~dp0"
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
    echo [ERROR] csc.exe not found. .NET Framework 4.x is required.
    pause
    exit /b 1
)
"%CSC%" /nologo /optimize+ /target:winexe /out:DeepSeekPeakMonitor.exe /win32icon:exe_src\app.ico /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll exe_src\Program.cs
if errorlevel 1 (
    echo [ERROR] Compile failed. See messages above.
    pause
    exit /b 1
)
echo [OK] Built DeepSeekPeakMonitor.exe
pause
