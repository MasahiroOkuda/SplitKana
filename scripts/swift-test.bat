@echo off
rem ---------------------------------------------------------------------------
rem Run the SplitKanaCore tests on Windows.
rem
rem ASCII only, CRLF only. cmd reads .bat in the OEM codepage and mis-parses
rem non-ASCII bytes, and it also mis-splits LF-only files. See .gitattributes.
rem
rem Why each flag is here is documented in docs/windows-swift.md.
rem ---------------------------------------------------------------------------
setlocal

set "REPO=%~dp0.."

rem vcvars64 looks for vswhere on PATH.
set "VSINSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer"
if exist "%VSINSTALLER%" set "PATH=%VSINSTALLER%;%PATH%"

set "VCVARS=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" set "VCVARS=%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" (
  echo [swift-test] vcvars64.bat not found. Install VS Build Tools with the C++ workload.
  exit /b 1
)
call "%VCVARS%" >nul

rem The Swift installer writes PATH and SDKROOT as user environment variables,
rem so a shell started before the install will not have them.
for /d %%D in ("%LOCALAPPDATA%\Programs\Swift\Toolchains\*") do set "SWIFT_TOOLCHAIN=%%D"
for /d %%D in ("%LOCALAPPDATA%\Programs\Swift\Platforms\*") do set "SWIFT_PLATFORM=%%D"
if defined SWIFT_TOOLCHAIN set "PATH=%SWIFT_TOOLCHAIN%\usr\bin;%PATH%"
if defined SWIFT_PLATFORM set "SDKROOT=%SWIFT_PLATFORM%\Windows.platform\Developer\SDKs\Windows.sdk\"

where swift.exe >nul 2>nul
if errorlevel 1 (
  echo [swift-test] swift.exe not found. Run: winget install --id Swift.Toolchain -e
  exit /b 1
)

swift test --package-path "%REPO%\Packages\SplitKanaKit" --enable-index-store -Xswiftc -index-ignore-system-modules -Xswiftc -index-ignore-clang-modules %*
exit /b %ERRORLEVEL%
