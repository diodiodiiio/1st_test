"""
ニュース・インテリジェンス・パイプラインの設定。

追跡テーマとキーワードをここで定義する。テーマを増減したい場合は
THEMES を編集するだけでよい。
"""

# 追跡するテーマ。key = テーマ名（レポート見出しに使う）、
# value = Google News 検索に使うキーワード（OR 検索される）
THEMES: dict[str, list[str]] = {
    "農業": ["農業", "スマート農業", "農政", "食料自給率"],
    "宇宙": ["宇宙開発", "ロケット打ち上げ", "衛星", "JAXA"],
    "量子技術": ["量子コンピュータ", "量子暗号", "量子技術"],
    "水産業": ["水産業", "漁業", "養殖", "水産資源"],
}

# Google News RSS の言語・地域設定（日本語・日本）
GNEWS_LANG = "ja"
GNEWS_COUNTRY = "JP"
GNEWS_CEID = "JP:ja"

# 1テーマあたり取得する記事数の上限
MAX_ARTICLES_PER_THEME = 8

# 本文抽出を行う記事数の上限（テーマあたり／コスト・時間の節約用）
MAX_FETCH_BODIES_PER_THEME = 5

# 使用する Claude モデル
#   高品質: "claude-opus-4-8"
#   低コスト: "claude-haiku-4-5-20251001"
CLAUDE_MODEL = "claude-haiku-4-5-20251001"

# 生成トークン上限（テーマごとの知見レポート）
MAX_TOKENS = 1500

# 出力先ディレクトリ
OUTPUT_DIR = "reports"
