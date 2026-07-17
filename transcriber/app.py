"""音声文字起こしWebアプリ（FastAPI）。

ブラウザ（PC / iPhoneのSafari）から音声ファイルをアップロードすると、
ローカルの faster-whisper で文字起こししてテキストを返します。

起動方法:
    uvicorn app:app --reload
ブラウザで http://localhost:8000 を開く。

同じLAN内のiPhoneから使う場合:
    uvicorn app:app --host 0.0.0.0
iPhoneのSafariで http://<PCのIPアドレス>:8000 を開く。
"""

from __future__ import annotations

import os
import tempfile

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse, JSONResponse

from transcribe import transcribe_file

app = FastAPI(title="音声文字起こし")

# このファイルがある場所を基準に static/ を探す（どこから起動しても動くように）。
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")

# アップロード可能な拡張子とサイズ上限。
ALLOWED_EXTENSIONS = {".m4a", ".mp3", ".wav", ".mp4", ".aac", ".ogg", ".flac", ".webm"}
MAX_FILE_SIZE = 200 * 1024 * 1024  # 200MB


@app.get("/")
def index() -> FileResponse:
    """アップロード画面（1ページ）を返す。"""
    return FileResponse(os.path.join(STATIC_DIR, "index.html"))


@app.post("/transcribe")
async def transcribe(
    file: UploadFile = File(...),
    language: str = "ja",
) -> JSONResponse:
    """アップロードされた音声を文字起こししてテキストを返す。"""
    _, ext = os.path.splitext(file.filename or "")
    ext = ext.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"対応していないファイル形式です: {ext or '(拡張子なし)'}",
        )

    data = await file.read()
    if len(data) == 0:
        raise HTTPException(status_code=400, detail="ファイルが空です。")
    if len(data) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"ファイルが大きすぎます（上限 {MAX_FILE_SIZE // (1024 * 1024)}MB）。",
        )

    # 一時ファイルに保存して文字起こし。処理後は必ず削除する。
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
            tmp.write(data)
            tmp_path = tmp.name

        text = transcribe_file(tmp_path, language=language)
    except Exception as e:  # noqa: BLE001 - ユーザーにわかるメッセージを返す
        raise HTTPException(status_code=500, detail=f"文字起こしに失敗しました: {e}")
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)

    return JSONResponse({"text": text})
