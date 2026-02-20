@echo off
setlocal EnableDelayedExpansion

echo.
echo  ================================
echo   Video Clipper - Setup (Windows)
echo  ================================
echo.

:: ── Verifica se esta rodando como Administrador ───────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Solicitando permissao de Administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ── Localiza o winget pelo caminho completo ───────────────────────────────────
set WINGET=
for /f "delims=" %%i in ('where winget 2^>nul') do set WINGET=%%i

if not defined WINGET (
    set WINGET=%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe
)

if not exist "%WINGET%" (
    echo [ERRO] winget nao encontrado.
    echo        Atualize o Windows 10/11 ou instale em: https://aka.ms/getwinget
    pause
    exit /b 1
)
echo [OK] winget encontrado em: %WINGET%

:: ── Instala Python ────────────────────────────────────────────────────────────
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [INFO] Python nao encontrado. Instalando...
    "%WINGET%" install --id Python.Python.3.11 --source winget --accept-package-agreements --accept-source-agreements
    if %errorlevel% neq 0 (
        echo.
        echo [ERRO] Falha ao instalar o Python. Codigo de erro: %errorlevel%
        echo  Tente instalar manualmente: https://www.python.org/downloads/
        echo  (Marque "Add Python to PATH" durante a instalacao)
        pause
        exit /b 1
    )
    set "PATH=%PATH%;%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts"
    echo [OK] Python instalado com sucesso.
) else (
    echo [OK] Python ja instalado:
    python --version
)

:: ── Instala FFmpeg ────────────────────────────────────────────────────────────
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [INFO] FFmpeg nao encontrado. Instalando...
    "%WINGET%" install --id Gyan.FFmpeg --source winget --accept-package-agreements --accept-source-agreements
    if %errorlevel% neq 0 (
        echo.
        echo [ERRO] Falha ao instalar o FFmpeg. Codigo de erro: %errorlevel%
        echo  Tente instalar manualmente: https://ffmpeg.org/download.html
        pause
        exit /b 1
    )
    set "PATH=%PATH%;%ProgramFiles%\ffmpeg\bin"
    echo [OK] FFmpeg instalado com sucesso.
) else (
    echo [OK] FFmpeg ja instalado.
)

:: ── Detecta GPU NVIDIA e versao CUDA ─────────────────────────────────────────
echo.
echo [INFO] Verificando GPU NVIDIA...

set CUDA_VERSION=
set HAS_GPU=0

nvidia-smi >nul 2>&1
if %errorlevel% equ 0 (
    set HAS_GPU=1

    :: Extrai a versao do CUDA do nvidia-smi
    for /f "tokens=9" %%v in ('nvidia-smi ^| findstr "CUDA Version"') do set CUDA_VERSION=%%v

    echo [OK] GPU NVIDIA detectada. CUDA Version: !CUDA_VERSION!
) else (
    echo [INFO] GPU NVIDIA nao detectada. Whisper usara a CPU.
)

:: ── Instala PyTorch (GPU ou CPU) ──────────────────────────────────────────────
echo.
echo [INFO] Instalando PyTorch...

if !HAS_GPU! equ 1 (
    :: Determina o canal correto baseado na versao do CUDA
    set CUDA_MAJOR=0
    for /f "delims=." %%a in ("!CUDA_VERSION!") do set CUDA_MAJOR=%%a

    if !CUDA_MAJOR! geq 12 (
        echo [INFO] Instalando PyTorch com suporte CUDA 12...
        python -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    ) else if !CUDA_MAJOR! geq 11 (
        echo [INFO] Instalando PyTorch com suporte CUDA 11...
        python -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
    ) else (
        echo [AVISO] Versao do CUDA muito antiga. Usando CPU como fallback.
        python -m pip install torch torchvision torchaudio
    )
) else (
    echo [INFO] Instalando PyTorch para CPU...
    python -m pip install torch torchvision torchaudio
)

if %errorlevel% neq 0 (
    echo [ERRO] Falha ao instalar PyTorch.
    pause
    exit /b 1
)
echo [OK] PyTorch instalado com sucesso.

:: ── Instala demais dependencias Python ───────────────────────────────────────
echo.
echo [INFO] Instalando demais dependencias...
echo.

set DEPS=openai-whisper fastapi "uvicorn[standard]" python-multipart yt-dlp

for %%p in (%DEPS%) do (
    echo [INFO] Instalando %%p...
    python -m pip install %%p
    if %errorlevel% neq 0 (
        echo [ERRO] Falha ao instalar %%p
        pause
        exit /b 1
    )
)

:: ── Instala Triton (opcional, elimina warnings de GPU) ───────────────────────
echo.
echo [INFO] Tentando instalar Triton (otimizacao GPU, opcional)...
python -m pip install triton >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Triton instalado com sucesso.
) else (
    echo [AVISO] Triton nao disponivel nesta maquina ^(opcional^). Sem impacto no funcionamento.
)

:: ── Configura hosts (videoclipper.local) ─────────────────────────────────────
echo.
echo [INFO] Configurando dominio local...

set HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts
set DOMAIN=videoclipper.local
set ENTRY=127.0.0.1 %DOMAIN%

findstr /C:"%DOMAIN%" "%HOSTS_FILE%" >nul 2>&1
if %errorlevel% neq 0 (
    echo %ENTRY% >> "%HOSTS_FILE%"
    echo [OK] Dominio "%DOMAIN%" configurado com sucesso.
) else (
    echo [OK] Dominio "%DOMAIN%" ja estava configurado.
)

echo.
if !HAS_GPU! equ 1 (
    echo  =====================================================
    echo   Setup concluido! GPU NVIDIA ativada.
    echo   Transcricao sera muito mais rapida.
) else (
    echo  =====================================================
    echo   Setup concluido! Usando CPU para transcricao.
    echo   Maquinas com GPU NVIDIA serao automaticamente
    echo   configuradas para usar aceleracao por GPU.
)
echo.
echo   Execute start.bat e acesse:
echo   http://videoclipper.local:8000
echo  =====================================================
echo.
pause