@echo off
setlocal EnableDelayedExpansion

rem Target architecture: 32 = Windows 7 SP1 x86 (Qt5 msvc2019 32-bit), 64 = Windows 10+ x64
set ARCH_BITS=32

set MSVC_VERSION=2019
set "MSVC_DIR=%programfiles(x86)%\Microsoft Visual Studio\%MSVC_VERSION%"

rem Import build environment
for %%s in (Community Professional Enterprise) do (
    set "MSVC_VCVARS_PATH=%MSVC_DIR%\%%s\VC\Auxiliary\Build\vcvars%ARCH_BITS%.bat"
    if exist !MSVC_VCVARS_PATH! (
        goto foundmsvc
    )
)

echo Could not find MSVC && goto error

:foundmsvc
call "!MSVC_VCVARS_PATH!"

rem Application version: latest git tag if it is plain X.X.X, otherwise 0.0.0
rem (VIProductVersion in the installer needs exactly four numbers)
set "APP_VERSION=0.0.0"
for /f "usebackq delims=" %%v in (`powershell -NoProfile -Command "$t = git describe --tags --abbrev=0 2>$null; if ($t -match '^[0-9]+\.[0-9]+\.[0-9]+$') { $t } else { '0.0.0' }"`) do set "APP_VERSION=%%v"
echo Application version: %APP_VERSION%

set QT_DIR=C:\Qt
rem Qt 5.15 is the last Qt line that runs on Windows 7. Qt 6 requires Windows 10+.
set QT_VERSION=5.15.2
rem Qt5 installer names the 32-bit MSVC kit "msvc2019" and the 64-bit kit "msvc2019_64"
set QT_COMPILER=msvc2019
if %ARCH_BITS%==64 set QT_COMPILER=msvc2019_64
set QT_BIN_DIR=%QT_DIR%\%QT_VERSION%\%QT_COMPILER%\bin

rem Download here https://cdn.flipperzero.one/STM32_DFU_USB_Driver.zip
set STM32_DRIVER_DIR="C:\STM32 Driver"

set QMAKE=%QT_BIN_DIR%\qmake.exe
set WINDEPLOYQT=%QT_BIN_DIR%\windeployqt.exe
set JOM=%QT_DIR%\Tools\QtCreator\bin\jom\jom.exe

set TARGET=qFlipper
set TARGET_CLI=%TARGET%-cli
set PROTO_TARGET=flipperproto
set DRIVER_TOOL=FlipperDriverTool

set PROJECT_DIR=%cd%
set BUILD_DIR=%PROJECT_DIR%\build
set QML_DIR=%PROJECT_DIR%\Application
set DIST_DIR=%BUILD_DIR%\%TARGET%
set PLUGINS_DIR=%DIST_DIR%\plugins
set DRIVER_TOOL_DIR=%PROJECT_DIR%\driver-tool

rem Qt ships OpenSSL as Win_x86 for 32-bit and Win_x64 for 64-bit
set OPENSSL_ARCH=x86
if %ARCH_BITS%==64 set OPENSSL_ARCH=x64
set OPENSSL_DIR=%QT_DIR%\Tools\OpenSSL\Win_%OPENSSL_ARCH%\bin
set VCREDIST_DIR=%QT_DIR%\vcredist

rem VC++ redistributable names must match what the CI downloads and what installer_windows.nsi expects
set VCREDIST_ARCH=x86
if %ARCH_BITS%==64 set VCREDIST_ARCH=x64
set VCREDIST2019_EXE=%VCREDIST_DIR%\vcredist_msvc%MSVC_VERSION%_%VCREDIST_ARCH%.exe
set VCREDIST2010_EXE=%VCREDIST_DIR%\vcredist_%VCREDIST_ARCH%.exe

set NSIS="%programfiles(x86)%\NSIS\makensis.exe"

rem if exist %BUILD_DIR% (rmdir /S /Q %BUILD_DIR%)

rem Build the application
mkdir %BUILD_DIR%
cd %BUILD_DIR%

%QMAKE% %PROJECT_DIR%\%TARGET%.pro -spec win32-msvc "CONFIG+=qtquickcompiler" &&^
%JOM% qmake_all && %JOM% && %JOM% install || goto error

rem Deploy the application
cd %DIST_DIR%

%WINDEPLOYQT% --release --no-compiler-runtime --dir %DIST_DIR% %PLUGINS_DIR%/%PROTO_TARGET%0.dll &&^
%WINDEPLOYQT% --release --no-compiler-runtime --qmldir %QML_DIR% %TARGET%.exe &&^
%WINDEPLOYQT% --release --no-compiler-runtime %TARGET_CLI%.exe || goto error

rem Copy OpenSSL binaries
copy /Y %OPENSSL_DIR%\*.dll . || goto error

rem Copy the STM32 DFU driver
xcopy /Y /E /I %STM32_DRIVER_DIR% %DIST_DIR%\"STM32 Driver" || goto error

rem Copy extra driver packages from the repo "drivers" folder.
rem Every .inf found there is installed by the NSIS installer ("Bundled drivers" section).
if exist "%PROJECT_DIR%\drivers" (
    xcopy /Y /E /I "%PROJECT_DIR%\drivers" "%DIST_DIR%\Drivers" || goto error
)

rem Copy Microsoft Visual C++ redistributable packages (fail early if they are missing)
if not exist "%VCREDIST2019_EXE%" echo Missing file: %VCREDIST2019_EXE% && goto error
if not exist "%VCREDIST2010_EXE%" echo Missing file: %VCREDIST2010_EXE% && goto error
copy /Y "%VCREDIST2019_EXE%" . || goto error
copy /Y "%VCREDIST2010_EXE%" . || goto error

if defined SIGNING_TOOL (
    rem Sign the executables
    call %SIGNING_TOOL% %DIST_DIR%\%TARGET%.exe || goto error
    call %SIGNING_TOOL% %DIST_DIR%\%TARGET_CLI%.exe || goto error
)

rem Make the zip archive as well
tar -a -cf %BUILD_DIR%\%TARGET%-%ARCH_BITS%bit.zip * || goto error

rem Make the installer (version is passed from the git tag above)
cd %PROJECT_DIR%
%NSIS% /DNAME=%TARGET% /DARCH_BITS=%ARCH_BITS% /DVERSION=%APP_VERSION% installer_windows.nsi || goto error

timeout /T 5 /NOBREAK > nul

if defined SIGNING_TOOL (
    rem Sign the installer
    call %SIGNING_TOOL% %BUILD_DIR%\%TARGET%Setup-%ARCH_BITS%bit.exe || goto error
)

echo The resulting installer is %BUILD_DIR%\%TARGET%Setup-%ARCH_BITS%bit.exe.
echo Finished.
exit 0

:error
echo There were errors during the build process!
exit 1
