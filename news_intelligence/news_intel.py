#!/usr/bin/env python3
"""
ニュース・インテリジェンス・パイプライン

Google ニュースの断片的な記事を、テーマ単位で
「背景・進展・論点・示唆(So What)」を備えた知見レポートに変換する。

flow:
    [1] 収集     Google News RSS でテーマごとに記事メタを取得
    [2] 本文取得  各記事URLから本文を抽出（要約の質を上げる）
    [3] 知見生成  Claude API でテーマ束ごとに構造化レポートを生成
    [4] 出力     Markdown レポートを reports/ に保存

使い方:
    export ANTHROPIC_API_KEY=sk-...
    pip install -r requirements.txt
    python news_intel.py
"""

from __future__ import annotations

import datetime as dt
import os
import sys
import urllib.parse
from dataclasses import dataclass, field

import feedparser

import config


@dataclass
class Article:
    title: str
    link: str
    source: str
    published: str
    summary: str = ""
    body: str = ""


@dataclass
class ThemeBundle:
    theme: str
    articles: list[Article] = field(default_factory=list)


# --------------------------------------------------------------------------
# [1] 収集: Google News RSS
# --------------------------------------------------------------------------
def build_gnews_url(keywords: list[str]) -> str:
    """キーワード(OR)から Google News RSS の検索URLを組み立てる。"""
    query = " OR ".join(keywords)
    q = urllib.parse.quote(query)
    return (
        f"https://news.google.com/rss/search?q={q}"
        f"&hl={config.GNEWS_LANG}"
        f"&gl={config.GNEWS_COUNTRY}"
        f"&ceid={config.GNEWS_CEID}"
    )


def collect_theme(theme: str, keywords: list[str]) -> ThemeBundle:
    """1テーマ分の記事メタを取得する。"""
    url = build_gnews_url(keywords)
    feed = feedparser.parse(url)
    bundle = ThemeBundle(theme=theme)

    for entry in feed.entries[: config.MAX_ARTICLES_PER_THEME]:
        source = ""
        if hasattr(entry, "source") and hasattr(entry.source, "title"):
            source = entry.source.title
        bundle.articles.append(
            Article(
                title=getattr(entry, "title", "(no title)"),
                link=getattr(entry, "link", ""),
                source=source,
                published=getattr(entry, "published", ""),
                summary=getattr(entry, "summary", ""),
            )
        )
    return bundle


# --------------------------------------------------------------------------
# [2] 本文取得
# --------------------------------------------------------------------------
def fetch_bodies(bundle: ThemeBundle) -> None:
    """上位記事の本文を抽出して Article.body に格納する。"""
    try:
        import trafilatura
    except ImportError:
        print("  [warn] trafilatura 未インストール — 本文抽出をスキップ", file=sys.stderr)
        return

    for article in bundle.articles[: config.MAX_FETCH_BODIES_PER_THEME]:
        if not article.link:
            continue
        try:
            downloaded = trafilatura.fetch_url(article.link)
            if downloaded:
                text = trafilatura.extract(downloaded, include_comments=False)
                if text:
                    # 長すぎる本文はトークン節約のため切り詰め
                    article.body = text[:4000]
        except Exception as exc:  # noqa: BLE001 — 収集は best-effort
            print(f"  [warn] 本文取得失敗 {article.link}: {exc}", file=sys.stderr)


# --------------------------------------------------------------------------
# [3] 知見生成: Claude API
# --------------------------------------------------------------------------
PROMPT_TEMPLATE = """あなたは経験豊富なインテリジェンス・アナリストです。
以下は「{theme}」に関する複数のニュース記事です。断片的な情報を統合し、
読者が状況を深く理解できる知見レポートを日本語で作成してください。

# 記事群
{articles_block}

# 出力フォーマット（厳守）
以下の見出しで、Markdown で出力してください。該当情報が乏しい項目は
「今回の記事群からは判断材料が乏しい」と正直に書いてください。

## 何が起きたか
（3〜4行で要点）

## 背景・経緯
（なぜ今これが起きているか。過去の文脈との接続）

## 論点・対立
（誰の主張がどう割れているか。異なる立場・見方）

## So What（示唆）
（読者にとっての意味、今後の注目点、次に何を見るべきか）

## 確度
（各要点が「断定できる事実 / 報道ベース / 憶測」のどれかを明示）
"""


def format_articles_block(bundle: ThemeBundle) -> str:
    lines = []
    for i, a in enumerate(bundle.articles, 1):
        lines.append(f"## 記事{i}: {a.title}")
        if a.source:
            lines.append(f"出典: {a.source}")
        if a.published:
            lines.append(f"日時: {a.published}")
        body = a.body or a.summary
        if body:
            lines.append(f"内容: {body}")
        lines.append(f"URL: {a.link}")
        lines.append("")
    return "\n".join(lines)


def generate_intelligence(bundle: ThemeBundle, client) -> str:
    """テーマ束から知見レポート本文（Markdown）を生成する。"""
    prompt = PROMPT_TEMPLATE.format(
        theme=bundle.theme,
        articles_block=format_articles_block(bundle),
    )
    message = client.messages.create(
        model=config.CLAUDE_MODEL,
        max_tokens=config.MAX_TOKENS,
        messages=[{"role": "user", "content": prompt}],
    )
    return "".join(
        block.text for block in message.content if block.type == "text"
    )


# --------------------------------------------------------------------------
# [4] 出力
# --------------------------------------------------------------------------
def build_report(bundles: list[ThemeBundle], sections: dict[str, str]) -> str:
    today = dt.date.today().isoformat()
    out = [f"# ニュース・インテリジェンス日報 {today}", ""]
    out.append("> Googleニュースの断片を、テーマ単位の知見に統合したレポート。")
    out.append("")
    out.append("## 目次")
    for b in bundles:
        out.append(f"- [{b.theme}](#{b.theme})")
    out.append("")

    for b in bundles:
        out.append(f"# {b.theme}")
        out.append("")
        out.append(sections.get(b.theme, "_(生成失敗)_"))
        out.append("")
        out.append("### 参照した記事")
        for a in b.articles:
            src = f" — {a.source}" if a.source else ""
            out.append(f"- [{a.title}]({a.link}){src}")
        out.append("")
        out.append("---")
        out.append("")
    return "\n".join(out)


# --------------------------------------------------------------------------
# メイン
# --------------------------------------------------------------------------
def main() -> int:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("ERROR: 環境変数 ANTHROPIC_API_KEY が未設定です。", file=sys.stderr)
        return 1

    try:
        import anthropic
    except ImportError:
        print("ERROR: anthropic 未インストール — pip install -r requirements.txt", file=sys.stderr)
        return 1

    client = anthropic.Anthropic(api_key=api_key)

    bundles: list[ThemeBundle] = []
    sections: dict[str, str] = {}

    for theme, keywords in config.THEMES.items():
        print(f"[collect] {theme} ...")
        bundle = collect_theme(theme, keywords)
        if not bundle.articles:
            print(f"  [warn] 記事が取得できませんでした: {theme}", file=sys.stderr)
            bundles.append(bundle)
            sections[theme] = "_(記事を取得できませんでした)_"
            continue

        print(f"  {len(bundle.articles)} 件取得 / 本文抽出中 ...")
        fetch_bodies(bundle)

        print(f"  [intelligence] Claude で知見生成中 ...")
        try:
            sections[theme] = generate_intelligence(bundle, client)
        except Exception as exc:  # noqa: BLE001
            print(f"  [error] 生成失敗 {theme}: {exc}", file=sys.stderr)
            sections[theme] = f"_(生成失敗: {exc})_"
        bundles.append(bundle)

    report = build_report(bundles, sections)

    os.makedirs(config.OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(
        config.OUTPUT_DIR, f"{dt.date.today().isoformat()}.md"
    )
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(report)

    print(f"\n✅ レポート出力: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
