"""音声ファイルを文字起こしする中心部品。

faster-whisper を使ってローカルで音声（.m4a / .mp3 / .wav など）をテキストに変換します。
クラウドAPIは使わないので、初回のモデルダウンロード以降はオフライン・無料で動きます。

使い方（コマンドラインから単体で試す）:
    python transcribe.py 音声ファイル.m4a
    python transcribe.py 音声ファイル.m4a --language en

モデルサイズは環境変数 WHISPER_MODEL で切り替えられます（既定: small）。
    WHISPER_MODEL=medium python transcribe.py 音声ファイル.m4a
"""

from __future__ import annotations

import argparse
import os
import sys
from functools import lru_cache

from faster_whisper import WhisperModel

# 既定のモデルサイズ。CPUでも実用的な精度と速度のバランスとして small を採用。
# より高精度が欲しい場合は medium / large-v3 を環境変数で指定する。
DEFAULT_MODEL_SIZE = os.environ.get("WHISPER_MODEL", "small")


@lru_cache(maxsize=1)
def _load_model(model_size: str) -> WhisperModel:
    """WhisperModel を読み込む。

    モデルの読み込みは重い（初回はダウンロードも走る）ため、
    lru_cache で一度だけ読み込んで使い回す。
    CPU 前提で compute_type="int8" にして省メモリ・高速化する。
    """
    return WhisperModel(model_size, device="cpu", compute_type="int8")


def transcribe_file(
    path: str,
    language: str = "ja",
    model_size: str | None = None,
) -> str:
    """音声ファイルを文字起こししてテキストを返す。

    Args:
        path: 音声ファイルのパス（.m4a / .mp3 / .wav など）。
        language: 音声の言語コード（既定は日本語 "ja"）。
        model_size: 使うモデルサイズ。未指定なら環境変数/既定を使う。

    Returns:
        文字起こしされたテキスト全体（セグメントを連結したもの）。
    """
    if not os.path.exists(path):
        raise FileNotFoundError(f"音声ファイルが見つかりません: {path}")

    model = _load_model(model_size or DEFAULT_MODEL_SIZE)

    # segments は遅延評価のジェネレータ。回して初めて文字起こしが実行される。
    segments, _info = model.transcribe(path, language=language, beam_size=5)

    texts = [segment.text.strip() for segment in segments]
    return "".join(texts).strip()


def _main() -> int:
    parser = argparse.ArgumentParser(description="音声ファイルをローカルで文字起こしする")
    parser.add_argument("audio", help="音声ファイルのパス（.m4a / .mp3 / .wav など）")
    parser.add_argument(
        "--language",
        default="ja",
        help="音声の言語コード（既定: ja）",
    )
    parser.add_argument(
        "--model",
        default=None,
        help=f"モデルサイズ（既定: {DEFAULT_MODEL_SIZE}）",
    )
    args = parser.parse_args()

    try:
        text = transcribe_file(args.audio, language=args.language, model_size=args.model)
    except FileNotFoundError as e:
        print(e, file=sys.stderr)
        return 1

    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
