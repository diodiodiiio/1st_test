# 音声文字起こしアプリ（ローカル実行）

iPhoneなどで録音した音声ファイル（`.m4a` / `.mp3` / `.wav` など）を、**自分のPC内で**文字起こしするWebアプリです。

- **無料・オフライン**：クラウドAI（従量課金）を使いません。音声は外部に送信されず、PC内で処理します。
- **PCでもiPhoneでも**：ブラウザで開くだけ。同じWi-Fi内ならiPhoneのSafariからも使えます。
- 文字起こしエンジンは [faster-whisper](https://github.com/SYSTRAN/faster-whisper)（ローカルWhisper）を使用。

---

## 必要なもの

- Python 3.9 以上
- 初回のみインターネット接続（Whisperモデルを一度だけダウンロードします。以降はオフラインで動きます）

---

## セットアップ

### 1. このフォルダに移動

```bash
cd transcriber
```

### 2. 仮想環境を作って有効化

**Mac / Linux:**
```bash
python3 -m venv .venv
source .venv/bin/activate
```

**Windows (PowerShell):**
```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
```

### 3. ライブラリをインストール

```bash
pip install -r requirements.txt
```

---

## 使い方

### A. Webアプリとして使う（おすすめ）

```bash
uvicorn app:app --reload
```

ブラウザで **http://localhost:8000** を開く → 音声ファイルを選んで「文字起こしする」を押すだけ。

> **初回は少し待ちます**：最初の1回だけWhisperモデル（数百MB）を自動ダウンロードするため時間がかかります。2回目以降は速くなります。

### B. コマンドラインで単体で試す

Webを使わず、文字起こし処理だけを試したいとき：

```bash
python transcribe.py 音声ファイル.m4a
```

英語の音声なら：
```bash
python transcribe.py 音声ファイル.m4a --language en
```

---

## iPhoneから使う（同じWi-Fi内）

1. PCで次のように起動（`0.0.0.0` で外部からのアクセスを許可）：

   ```bash
   uvicorn app:app --host 0.0.0.0
   ```

2. PCのIPアドレスを調べる：
   - **Mac:** `ipconfig getifaddr en0`
   - **Windows:** `ipconfig`（IPv4アドレスの欄）

3. iPhoneのSafariで **http://（PCのIPアドレス）:8000** を開く（例：`http://192.168.1.10:8000`）。

4. iPhoneのボイスメモ等で録音した音声を、「ファイルを選ぶ」から選択してアップロードすれば文字起こしできます。

> PCとiPhoneが**同じWi-Fi**につながっている必要があります。うまく開けない場合はPCのファイアウォール設定を確認してください。

---

## 精度を上げたいとき（モデルサイズの変更）

既定は `small`（速度と精度のバランス）。より高精度にしたい場合は環境変数 `WHISPER_MODEL` で変更できます（そのぶん処理は重くなります）。

**Mac / Linux:**
```bash
WHISPER_MODEL=medium uvicorn app:app
```

**Windows (PowerShell):**
```powershell
$env:WHISPER_MODEL="medium"; uvicorn app:app
```

選べるサイズ：`tiny` → `base` → `small`（既定）→ `medium` → `large-v3`（右ほど高精度・低速）。

---

## よくある質問

- **対応している音声形式は？** `.m4a` `.mp3` `.wav` `.mp4` `.aac` `.ogg` `.flac` `.webm`。iPhoneのボイスメモは通常 `.m4a` なのでそのまま使えます。
- **ffmpegのインストールは必要？** 不要です。faster-whisperが内部で音声をデコードします。
- **音声はどこかに送られる？** 送られません。すべてPC内で処理されます。
