@echo off
setlocal
cd /d "%~dp0"

echo ==============================================
echo   Luelement Engine - Build Android ARM64
echo ==============================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build_engine_android.ps1"
set EXIT_CODE=%ERRORLEVEL%

echo.
if not "%EXIT_CODE%"=="0" (
    echo [ERRO] O build do Luelement Engine falhou.
) else (
    echo [OK] Build concluido.
)
echo.
pause
exit /b %EXIT_CODE%
