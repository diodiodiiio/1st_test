"""
メルカリ ビカクシダ 販売分析スクリプト
tracker.py で収集したデータを集計・表示する。

使い方:
    python analyze.py --metric all
    python analyze.py --metric price_speed
"""

import argparse
import sqlite3
from pathlib import Path

from tabulate import tabulate

DB_PATH = Path(__file__).parent / "mercari.db"

DOW_LABELS = ["日", "月", "火", "水", "木", "金", "土"]


def _conn() -> sqlite3.Connection:
    if not DB_PATH.exists():
        raise FileNotFoundError(
            f"{DB_PATH} が見つかりません。先に tracker.py を実行してください。"
        )
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _section(title: str) -> None:
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


def _sold_at_warning(conn: sqlite3.Connection) -> None:
    """sold_atのデータ品質を表示する。"""
    rows = conn.execute("""
        SELECT sold_at_source, COUNT(*) AS cnt
        FROM items
        WHERE status = 'sold_out'
        GROUP BY sold_at_source
        ORDER BY cnt DESC
    """).fetchall()

    total_sold = conn.execute(
        "SELECT COUNT(*) FROM items WHERE status='sold_out'"
    ).fetchone()[0]
    total_all = conn.execute("SELECT COUNT(*) FROM items").fetchone()[0]

    _section("データ品質サマリー")
    print(f"  総アイテム数   : {total_all:,}")
    print(f"  売切れアイテム : {total_sold:,}")
    print()
    print("  sold_at の取得元 (売切れ商品のみ):")
    for r in rows:
        source = r["sold_at_source"]
        label = {
            "sold_at": "APIの sold_at フィールド (正確)",
            "updated": "APIの updated フィールド (代用・近似値)",
            "none": "取得不可 (NULL)",
        }.get(source, source)
        print(f"    {source:10s}  {r['cnt']:6,}件  ← {label}")

    if not any(r["sold_at_source"] in ("sold_at", "updated") for r in rows):
        print()
        print("  ⚠️  sold_at が取得できていません。")
        print("     時間ベースの分析 (metric 3,4) はスキップされます。")


def days_to_sell(conn: sqlite3.Connection) -> None:
    """分析1: 出品から売れるまでの日数分布"""
    _section("分析1: 何日で売れるか")

    rows = conn.execute("""
        SELECT
            CAST(julianday(sold_at) - julianday(listed_at) AS INTEGER) AS days_taken,
            COUNT(*) AS item_count,
            ROUND(AVG(price), 0) AS avg_price
        FROM items
        WHERE status = 'sold_out'
          AND sold_at IS NOT NULL
          AND listed_at IS NOT NULL
          AND julianday(sold_at) >= julianday(listed_at)
        GROUP BY days_taken
        ORDER BY days_taken
    """).fetchall()

    if not rows:
        print("  データなし (sold_at が NULL のため集計不可)")
        return

    avg_row = conn.execute("""
        SELECT
            ROUND(AVG(julianday(sold_at) - julianday(listed_at)), 1) AS avg_days,
            ROUND(MIN(julianday(sold_at) - julianday(listed_at)), 1) AS min_days,
            ROUND(MAX(julianday(sold_at) - julianday(listed_at)), 1) AS max_days,
            COUNT(*) AS cnt
        FROM items
        WHERE status='sold_out' AND sold_at IS NOT NULL AND listed_at IS NOT NULL
          AND julianday(sold_at) >= julianday(listed_at)
    """).fetchone()

    print(f"  集計対象: {avg_row['cnt']:,}件")
    print(f"  平均: {avg_row['avg_days']}日 / 最短: {avg_row['min_days']}日 / 最長: {avg_row['max_days']}日")
    print()
    print(tabulate(
        [(r["days_taken"], r["item_count"], f"¥{int(r['avg_price']):,}") for r in rows[:30]],
        headers=["経過日数", "件数", "平均価格"],
        tablefmt="simple",
        colalign=("right", "right", "right"),
    ))
    if len(rows) > 30:
        print(f"  ... 他 {len(rows)-30} 行 (長期未売品)")


def price_vs_speed(conn: sqlite3.Connection) -> None:
    """分析2: 価格帯と販売速度の関係"""
    _section("分析2: 価格帯 vs 平均売却日数")

    rows = conn.execute("""
        SELECT
            CASE
                WHEN price <  1000  THEN '1_~999'
                WHEN price <  3000  THEN '2_1000-2999'
                WHEN price <  5000  THEN '3_3000-4999'
                WHEN price < 10000  THEN '4_5000-9999'
                WHEN price < 30000  THEN '5_10000-29999'
                ELSE                     '6_30000+'
            END AS bucket_key,
            CASE
                WHEN price <  1000  THEN '~999'
                WHEN price <  3000  THEN '1,000〜2,999'
                WHEN price <  5000  THEN '3,000〜4,999'
                WHEN price < 10000  THEN '5,000〜9,999'
                WHEN price < 30000  THEN '10,000〜29,999'
                ELSE                     '30,000+'
            END AS price_bucket,
            COUNT(*) AS sold_count,
            ROUND(AVG(julianday(sold_at) - julianday(listed_at)), 1) AS avg_days
        FROM items
        WHERE status = 'sold_out'
          AND sold_at IS NOT NULL
          AND listed_at IS NOT NULL
          AND julianday(sold_at) >= julianday(listed_at)
        GROUP BY bucket_key
        ORDER BY bucket_key
    """).fetchall()

    if not rows:
        print("  データなし")
        return

    print(tabulate(
        [(r["price_bucket"], r["sold_count"], r["avg_days"]) for r in rows],
        headers=["価格帯 (円)", "売却件数", "平均売却日数"],
        tablefmt="simple",
        colalign=("left", "right", "right"),
    ))


def best_time_to_list(conn: sqlite3.Connection) -> None:
    """分析3: 売れた商品の出品曜日・時間帯 (= 出品すべき時間帯)"""
    _section("分析3: 出品すべき曜日・時間帯 (売れた商品の出品時刻から逆算)")
    print("  ※ 時刻はUTC。日本時間 (JST) は +9時間で換算してください。")

    dow_rows = conn.execute("""
        SELECT
            CAST(strftime('%w', listed_at) AS INTEGER) AS dow,
            COUNT(*) AS sold_listings
        FROM items
        WHERE status = 'sold_out' AND listed_at IS NOT NULL
        GROUP BY dow
        ORDER BY sold_listings DESC
    """).fetchall()

    hour_rows = conn.execute("""
        SELECT
            CAST(strftime('%H', listed_at) AS INTEGER) AS hour,
            COUNT(*) AS sold_listings
        FROM items
        WHERE status = 'sold_out' AND listed_at IS NOT NULL
        GROUP BY hour
        ORDER BY sold_listings DESC
        LIMIT 10
    """).fetchall()

    if not dow_rows:
        print("  データなし")
        return

    print()
    print("  【曜日別】(売れた商品の出品曜日)")
    print(tabulate(
        [(DOW_LABELS[r["dow"]], r["sold_listings"]) for r in dow_rows],
        headers=["曜日", "件数"],
        tablefmt="simple",
        colalign=("left", "right"),
    ))

    print()
    print("  【時間帯別 TOP10】(売れた商品の出品時刻・UTC)")
    print(tabulate(
        [(f"{r['hour']:02d}:00 (JST {(r['hour']+9)%24:02d}:00)", r["sold_listings"])
         for r in hour_rows],
        headers=["時間帯 (UTC / JST)", "件数"],
        tablefmt="simple",
        colalign=("left", "right"),
    ))


def sell_timing(conn: sqlite3.Connection) -> None:
    """分析4: 実際に売れた曜日・時間帯"""
    _section("分析4: 売れる曜日・時間帯 (sold_at から集計)")
    print("  ※ 時刻はUTC。日本時間 (JST) は +9時間で換算してください。")

    qualified = conn.execute("""
        SELECT COUNT(*) FROM items
        WHERE status='sold_out' AND sold_at IS NOT NULL AND sold_at_source != 'none'
    """).fetchone()[0]
    total_sold = conn.execute(
        "SELECT COUNT(*) FROM items WHERE status='sold_out'"
    ).fetchone()[0]

    print(f"  集計対象: {qualified:,}件 / 全売切れ {total_sold:,}件")

    if qualified == 0:
        print("  データなし (sold_at が取得できていません)")
        return

    dow_rows = conn.execute("""
        SELECT
            CAST(strftime('%w', sold_at) AS INTEGER) AS dow,
            COUNT(*) AS cnt
        FROM items
        WHERE status = 'sold_out'
          AND sold_at IS NOT NULL
          AND sold_at_source != 'none'
        GROUP BY dow
        ORDER BY cnt DESC
    """).fetchall()

    hour_rows = conn.execute("""
        SELECT
            CAST(strftime('%H', sold_at) AS INTEGER) AS hour,
            COUNT(*) AS cnt
        FROM items
        WHERE status = 'sold_out'
          AND sold_at IS NOT NULL
          AND sold_at_source != 'none'
        GROUP BY hour
        ORDER BY cnt DESC
        LIMIT 10
    """).fetchall()

    print()
    print("  【曜日別】")
    print(tabulate(
        [(DOW_LABELS[r["dow"]], r["cnt"]) for r in dow_rows],
        headers=["曜日", "件数"],
        tablefmt="simple",
        colalign=("left", "right"),
    ))

    print()
    print("  【時間帯別 TOP10】(UTC / JST)")
    print(tabulate(
        [(f"{r['hour']:02d}:00 (JST {(r['hour']+9)%24:02d}:00)", r["cnt"])
         for r in hour_rows],
        headers=["時間帯 (UTC / JST)", "件数"],
        tablefmt="simple",
        colalign=("left", "right"),
    ))


def monthly_trends(conn: sqlite3.Connection) -> None:
    """分析5: 月別の出品数・販売数推移"""
    _section("分析5: 月別動向")

    rows = conn.execute("""
        SELECT
            strftime('%Y-%m', listed_at) AS month,
            COUNT(*) AS listed_count,
            SUM(CASE WHEN status = 'sold_out' THEN 1 ELSE 0 END) AS sold_count,
            ROUND(
                100.0 * SUM(CASE WHEN status='sold_out' THEN 1 ELSE 0 END) / COUNT(*),
                1
            ) AS sell_through_pct
        FROM items
        WHERE listed_at IS NOT NULL
        GROUP BY month
        ORDER BY month
    """).fetchall()

    if not rows:
        print("  データなし")
        return

    print(tabulate(
        [
            (r["month"], r["listed_count"], r["sold_count"], f"{r['sell_through_pct']}%")
            for r in rows
        ],
        headers=["月", "出品数", "売却数", "売切率"],
        tablefmt="simple",
        colalign=("left", "right", "right", "right"),
    ))


def main() -> None:
    p = argparse.ArgumentParser(description="メルカリ ビカクシダ 販売分析")
    p.add_argument(
        "--metric",
        choices=["days_to_sell", "price_speed", "list_timing", "sell_timing", "monthly", "all"],
        default="all",
        help="実行する分析メトリクス",
    )
    args = p.parse_args()

    conn = _conn()
    _sold_at_warning(conn)

    dispatch = {
        "days_to_sell": days_to_sell,
        "price_speed": price_vs_speed,
        "list_timing": best_time_to_list,
        "sell_timing": sell_timing,
        "monthly": monthly_trends,
    }

    if args.metric == "all":
        for fn in dispatch.values():
            fn(conn)
    else:
        dispatch[args.metric](conn)

    conn.close()
    print()


if __name__ == "__main__":
    main()
