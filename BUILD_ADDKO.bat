@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build_addko.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" (
  echo Falha ao gerar o pacote Luelement .addko.
) else (
  echo Pacote Luelement gerado com sucesso na pasta dist.
)

echo.
pause
exit /b %EXIT_CODE%
