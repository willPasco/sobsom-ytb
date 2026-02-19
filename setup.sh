#!/bin/bash

echo "🎬 Video Clipper — Setup"
echo "========================"

# Detecta OS
OS="$(uname -s)"

# Verifica Python
if ! command -v python3 &>/dev/null; then
  echo "❌ Python 3 não encontrado. Instale em https://python3.org"
  exit 1
fi

echo "✅ Python: $(python3 --version)"

# Verifica FFmpeg
if ! command -v ffmpeg &>/dev/null; then
  echo "⏳ Instalando FFmpeg..."
  if [ "$OS" = "Darwin" ]; then
    brew install ffmpeg
  elif [ "$OS" = "Linux" ]; then
    sudo apt-get update && sudo apt-get install -y ffmpeg
  else
    echo "❌ Instale o FFmpeg manualmente: https://ffmpeg.org/download.html"
    exit 1
  fi
fi

echo "✅ FFmpeg: $(ffmpeg -version 2>&1 | head -1)"

# Instala dependências Python
echo "⏳ Instalando dependências Python..."
cd backend
pip3 install -r requirements.txt

echo ""
echo "✅ Setup concluído!"
echo "   Execute ./start.sh para iniciar a aplicação."
