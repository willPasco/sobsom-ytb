# 🎬 Video Clipper

> 🤖 Este projeto foi criado inteiramente através de conversas com o [Claude](https://claude.ai), sem nenhuma linha de código escrita manualmente.

Ferramenta para extrair trechos de vídeos com base em palavras-chave.
Suporta upload de arquivos MP4 ou URLs do YouTube.

> ⚠️ **Aviso importante**: esta ferramenta foi desenvolvida exclusivamente para uso local.
> Ela não possui validações de segurança adequadas para ser exposta em redes públicas ou
> utilizada como serviço web. Não hospede em servidores acessíveis externamente.

---

## Como funciona

1. Você faz upload de um vídeo MP4 ou cola uma URL do YouTube
2. O **Whisper** transcreve o áudio localmente com timestamps
3. O sistema identifica todos os trechos onde a palavra aparece
4. O **FFmpeg** corta os clipes automaticamente
5. Você baixa os clipes pela interface web

Tudo roda na sua máquina — nenhum dado é enviado para servidores externos.

---

## Requisitos

- Windows 10 ou 11
- Conexão com a internet (apenas durante o setup)
- ~4GB de RAM (para o modelo `medium` do Whisper)
- GPU NVIDIA (opcional — ativa aceleração automática se disponível)

---

## Instalação

```bash
# 1. Clone o repositório
git clone https://github.com/sua-empresa/video-clipper
cd video-clipper

# 2. Rode o setup (apenas na primeira vez)
# Clique duas vezes no setup.bat ou execute pelo terminal:
setup.bat
```

O setup instala automaticamente:
- Python 3.11
- FFmpeg
- PyTorch (com GPU se houver placa NVIDIA, CPU caso contrário)
- Whisper, FastAPI, yt-dlp e demais dependências

---

## Uso

```bash
# Clique duas vezes ou execute:
start.bat
```

Abre automaticamente em `http://videoclipper.local:8000`.

O CMD precisa permanecer aberto enquanto a ferramenta estiver em uso — ele é o servidor local.

---

## Estrutura do projeto

```
video-clipper/
├── backend/
│   └── main.py           ← API FastAPI + lógica de processamento
├── frontend/
│   └── index.html        ← interface web
├── setup.bat             ← instalação automática (Windows)
└── start.bat             ← inicia o servidor (Windows)
```

---

## Configuração do modelo Whisper

No arquivo `backend/main.py` você pode trocar o modelo conforme a capacidade da máquina:

| Modelo   | RAM necessária | Velocidade   | Precisão |
|----------|---------------|--------------|----------|
| `tiny`   | ~1 GB         | Muito rápido | Básica   |
| `base`   | ~1 GB         | Rápido       | Boa      |
| `small`  | ~2 GB         | Médio        | Boa      |
| `medium` | ~4 GB         | Médio        | Ótima    |
| `large`  | ~8 GB         | Lento        | Máxima   |

```python
# backend/main.py
model = whisper.load_model("medium")  # troque aqui
```

---

## Limitações conhecidas

- Desenvolvido e testado apenas no Windows 10/11
- Não possui autenticação ou controle de acesso
- Não possui validação de tamanho de arquivo
- O uso do yt-dlp para baixar vídeos do YouTube pode violar os termos de serviço da plataforma — utilize com responsabilidade
- Não recomendado para uso em redes corporativas sem as devidas validações de segurança

---

## Privacidade

Nenhum dado é enviado para servidores externos.
Os vídeos são deletados automaticamente após o processamento.