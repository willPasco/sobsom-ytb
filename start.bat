@echo off
echo.
echo  Iniciando Video Clipper...
echo  Acesse: http://videoclipper.local:8000
echo.

:: Abre o navegador apos 3 segundos
start "" /b cmd /c "timeout /t 3 >nul && start http://videoclipper.local:8000"

:: Inicia o servidor a partir da pasta do script
cd /d "%~dp0backend"
python -m uvicorn main:app --host 0.0.0.0 --port 8000