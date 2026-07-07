# ニュース・インテリジェンス・パイプライン

Google ニュースの**断片的な記事（information）**を、テーマ単位で
**「背景・進展・論点・示唆(So What)」を備えた知見（intelligence）** に
変換して毎日レポート化するツール。

追跡テーマ（初期設定）: **農業 / 宇宙 / 量子技術 / 水産業**

## なぜ作るか

Google ニュースは記事が個別に並ぶだけで、以下が欠けている:

| 不足 | 本ツールでの補完 |
|---|---|
| 文脈 | 「背景・経緯」セクションで過去との接続を生成 |
| 統合 | テーマ単位で複数記事を1つの知見に束ねる |
| 対立軸 | 「論点・対立」で立場の割れを可視化 |
| 示唆 | 「So What」で自分にとっての意味・次の注目点を提示 |
| 確度 | 「事実 / 報道ベース / 憶測」を明示し鵜呑みを防ぐ |

## 処理フロー

```
[1] 収集      Google News RSS でテーマごとに記事メタを取得
[2] 本文取得   各記事URLから本文を抽出（trafilatura）
[3] 知見生成   Claude API でテーマ束ごとに構造化レポートを生成
[4] 出力      Markdown 日報を reports/YYYY-MM-DD.md に保存
```

## セットアップ

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...
```

> **注意**: `feedparser` の依存 `sgmllib3k` のビルドで
> `AttributeError: install_layout` が出る環境では、
> `SETUPTOOLS_USE_DISTUTILS=stdlib pip install -r requirements.txt` で回避できる。

## 実行

```bash
python news_intel.py
```

`reports/YYYY-MM-DD.md` に日報が出力される。
`sample_report.md` に出力イメージを同梱している。

## カスタマイズ

`config.py` を編集するだけ:

- `THEMES` — 追跡テーマとキーワード（増減自由）
- `CLAUDE_MODEL` — 高品質 `claude-opus-4-8` / 低コスト `claude-haiku-4-5-20251001`
- `MAX_ARTICLES_PER_THEME` — テーマあたりの取得記事数
- `MAX_FETCH_BODIES_PER_THEME` — 本文抽出する記事数（コスト調整）

## 毎朝自動配信（cron 例）

```cron
# 毎朝 7:00 に実行
0 7 * * * cd /path/to/news_intelligence && \
  ANTHROPIC_API_KEY=sk-ant-... python news_intel.py
```

メールや Slack へ流したい場合は、`main()` の末尾で
生成した `report` を SMTP / Slack Webhook に送る処理を追加すればよい。

## コスト目安

1日 4テーマ × 各5〜8記事を Haiku で処理する場合、
1回あたり数円程度。月額でも数百円に収まる想定。

## 制約・注意

- 本ツールは `news.google.com` への外部アクセスが必要。
  ネットワークポリシーで Google への接続が遮断された環境
  （一部のCI/リモートサンドボックス等）では収集できない。
  ローカルPCなど通常のネットワーク環境で実行すること。
- 本文抽出・要約は best-effort。生成結果は必ず「確度」欄を確認し、
  重要判断は一次ソースに当たること。
