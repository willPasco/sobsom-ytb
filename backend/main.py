import os
import uuid
import subprocess
from pathlib import Path
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import whisper
import torch
import yt_dlp

# ─── Config ───────────────────────────────────────────────────────────────────

UPLOAD_DIR = Path("temp/uploads")
OUTPUT_DIR = Path("temp/outputs")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

VALID_MODELS  = {"tiny", "medium", "large"}
VALID_DEVICES = {"cpu", "cuda"}

HAS_CUDA = torch.cuda.is_available()

app = FastAPI(title="Video Clipper")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory="../frontend"), name="static")

# Cache de modelos já carregados para não recarregar desnecessariamente
model_cache: dict = {}

def get_model(model_name: str, device: str):
    key = f"{model_name}_{device}"
    if key not in model_cache:
        print(f"⏳ Carregando modelo '{model_name}' no dispositivo '{device}'...")
        model_cache[key] = whisper.load_model(model_name, device=device)
        print(f"✅ Modelo '{model_name}' carregado em {device.upper()}!")
    return model_cache[key]

# ─── Helpers ──────────────────────────────────────────────────────────────────

def download_youtube(url: str, session_id: str) -> tuple[Path, str]:
    output_template = str(UPLOAD_DIR / f"{session_id}.%(ext)s")
    ydl_opts = {
        "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
        "outtmpl": output_template,
        "quiet": True,
        "no_warnings": True,
        "merge_output_format": "mp4",
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        title = info.get("title", "video")

    video_path = UPLOAD_DIR / f"{session_id}.mp4"
    if not video_path.exists():
        candidates = list(UPLOAD_DIR.glob(f"{session_id}.*"))
        if not candidates:
            raise HTTPException(status_code=500, detail="Falha ao baixar o vídeo do YouTube.")
        video_path = candidates[0]

    return video_path, title


def process_video_file(video_path: Path, keyword: str, padding: int, session_id: str, model_name: str, device: str):
    output_dir = OUTPUT_DIR / session_id
    output_dir.mkdir(parents=True, exist_ok=True)

    model = get_model(model_name, device)

    print(f"🎙️ Transcrevendo {video_path.name} [{model_name} / {device}]...")
    result = model.transcribe(str(video_path), language="pt", word_timestamps=True)

    keyword_lower = keyword.lower()
    matches = []

    for segment in result["segments"]:
        if keyword_lower in segment["text"].lower():
            start = max(0, segment["start"] - padding)
            end = segment["end"] + padding
            matches.append({
                "start": start,
                "end": end,
                "text": segment["text"].strip(),
            })

    if not matches:
        raise HTTPException(
            status_code=404,
            detail=f"Nenhuma ocorrência de '{keyword}' encontrada no vídeo."
        )

    clips = []
    for i, match in enumerate(matches):
        clip_name = f"clipe_{i+1:02d}.mp4"
        clip_path = output_dir / clip_name

        subprocess.run([
            "ffmpeg", "-y",
            "-i", str(video_path),
            "-ss", str(match["start"]),
            "-to", str(match["end"]),
            "-c:v", "libx264",
            "-c:a", "aac",
            "-loglevel", "error",
            str(clip_path)
        ], check=True)

        clips.append({
            "name": clip_name,
            "text": match["text"],
            "start": round(match["start"], 1),
            "end": round(match["end"], 1),
            "download_url": f"/download/{session_id}/{clip_name}",
        })

    print(f"✅ {len(clips)} clipes gerados para sessão {session_id}")
    return clips

# ─── Endpoints ────────────────────────────────────────────────────────────────

@app.get("/")
def index():
    return FileResponse("../frontend/index.html")

@app.get("/capabilities")
def capabilities():
    """Informa ao frontend se CUDA está disponível."""
    return {"cuda_available": HAS_CUDA}

@app.post("/process/upload")
async def process_upload(
    video: UploadFile = File(...),
    keyword: str = Form(...),
    padding: int = Form(3),
    model_name: str = Form("medium"),
    device: str = Form("cpu"),
):
    if model_name not in VALID_MODELS:
        raise HTTPException(status_code=400, detail=f"Modelo inválido: {model_name}")
    if device not in VALID_DEVICES:
        raise HTTPException(status_code=400, detail=f"Dispositivo inválido: {device}")
    if device == "cuda" and not HAS_CUDA:
        raise HTTPException(status_code=400, detail="GPU NVIDIA não disponível nesta máquina.")

    session_id = str(uuid.uuid4())[:8]
    video_path = UPLOAD_DIR / f"{session_id}_{video.filename}"

    with open(video_path, "wb") as f:
        f.write(await video.read())

    try:
        clips = process_video_file(video_path, keyword, padding, session_id, model_name, device)
        return {"session_id": session_id, "keyword": keyword, "total_clips": len(clips), "clips": clips}
    finally:
        video_path.unlink(missing_ok=True)


@app.post("/process/youtube")
async def process_youtube(
    url: str = Form(...),
    keyword: str = Form(...),
    padding: int = Form(3),
    model_name: str = Form("medium"),
    device: str = Form("cpu"),
):
    if model_name not in VALID_MODELS:
        raise HTTPException(status_code=400, detail=f"Modelo inválido: {model_name}")
    if device not in VALID_DEVICES:
        raise HTTPException(status_code=400, detail=f"Dispositivo inválido: {device}")
    if device == "cuda" and not HAS_CUDA:
        raise HTTPException(status_code=400, detail="GPU NVIDIA não disponível nesta máquina.")

    session_id = str(uuid.uuid4())[:8]
    video_path = None

    try:
        print(f"⬇️  Baixando: {url}")
        video_path, title = download_youtube(url, session_id)
        print(f"✅ Download concluído: {title}")

        clips = process_video_file(video_path, keyword, padding, session_id, model_name, device)
        return {
            "session_id": session_id,
            "keyword": keyword,
            "title": title,
            "total_clips": len(clips),
            "clips": clips,
        }
    finally:
        if video_path and video_path.exists():
            video_path.unlink(missing_ok=True)


@app.get("/download/{session_id}/{filename}")
def download_clip(session_id: str, filename: str):
    clip_path = OUTPUT_DIR / session_id / filename
    if not clip_path.exists():
        raise HTTPException(status_code=404, detail="Clipe não encontrado.")
    return FileResponse(path=clip_path, media_type="video/mp4", filename=filename)


@app.delete("/session/{session_id}")
def cleanup_session(session_id: str):
    import shutil
    session_dir = OUTPUT_DIR / session_id
    if session_dir.exists():
        shutil.rmtree(session_dir)
    return {"status": "ok"}