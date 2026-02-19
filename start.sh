#!/bin/bash

echo "🎬 Iniciando Video Clipper..."

# Abre o navegador após 3 segundos
(sleep 3 && python3 -c "import webbrowser; webbrowser.open('http://localhost:8000')") &

# Inicia o servidor
cd backend
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
