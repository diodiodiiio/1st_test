"""
Mercari ビカクシダ データ収集スクリプト
メルカリ非公式APIから出品・売却データを取得してSQLiteに保存する。

使い方:
    python tracker.py --keyword ビカクシダ --days-back 90
    python tracker.py --keyword ビカクシダ --days-back 30 --status sold_out
"""

import argparse
import sqlite3
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import requests

DB_PATH = Path(__file__).parent / "mercari.db"
API_URL = "https://api.mercari.jp/v2/entities:search"
ITEM_LIMIT_PER_PAGE = 120
RATE_DELAY = 1.2  # seconds between pages

BASE_HEADERS = {
    "X-Platform": "web",
    "Content-Type": "application/json; charset=UTF-8",
    "Accept": "application/json, text/plain, */*",
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Origin": "https://jp.mercari.com",
    "Referer": "https://jp.mercari.com/",
}
# 401/403が返る場合はメルカリがDPoP認証を要求している可能性あり。
# ブラウザDevTools (Network タブ) から取得して以下に追記:
#   BASE_HEADERS["DPoP"] = "eyJ..."
#   BASE_HEADERS["Authorization"] = "Bearer ..."
# DPoP トークンの有効期間は約15分。


class MercariHTTPError(Exception):
    def __init__(self, status_code: int, body: str):
        self.status_code = status_code
        self.body = body
        super().__init__(f"HTTP {status_code}")


def init_db(conn: sqlite3.Connection) -> None:
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS items (
            item_id        TEXT PRIMARY KEY,
            name           TEXT NOT NULL,
            price          INTEGER NOT NULL,
            status         TEXT NOT NULL,
            listed_at      DATETIME,
            sold_at        DATETIME,
            sold_at_source TEXT DEFAULT 'none',
            raw_created    INTEGER,
            raw_updated    INTEGER
        );
        CREATE INDEX IF NOT EXISTS idx_status    ON items(status);
        CREATE INDEX IF NOT EXISTS idx_listed_at ON items(listed_at);
        CREATE INDEX IF NOT EXISTS idx_sold_at   ON items(sold_at);
    """)


def search(
    session: requests.Session,
    keyword: str,
    statuses: list,
    page_token: str | None = None,
) -> tuple:
    """1ページ分を取得して (items, next_page_token) を返す。"""
    body: dict = {
        "keyword": keyword,
        "status": statuses,
        "limit": ITEM_LIMIT_PER_PAGE,
        "search_session_id": "",
    }
    if page_token:
        body["pageToken"] = page_token

    resp = session.post(API_URL, json=body, timeout=(10, 30))
    if not resp.ok:
        raise MercariHTTPError(resp.status_code, resp.text[:500])

    data = resp.json()
    items = data.get("items", [])
    next_token = data.get("nextPageToken") or None
    return items, next_token


def parse_item(raw: dict) -> dict | None:
    """APIレスポンスの1商品を DB行 dict に変換。必須フィールド欠損時は None。"""
    item_id = raw.get("id")
    if not item_id:
        print(f"[skip] item missing id: {str(raw)[:80]}", file=sys.stderr)
        return None

    try:
        price = int(raw.get("price", ""))
    except (TypeError, ValueError):
        print(f"[skip] item {item_id} has non-numeric price", file=sys.stderr)
        return None

    raw_status = raw.get("status", "")
    if raw_status == "STATUS_ON_SALE":
        status = "on_sale"
    elif raw_status == "STATUS_SOLD_OUT":
        status = "sold_out"
    else:
        status = raw_status.lower().replace("status_", "")

    raw_created = raw.get("created")
    raw_updated = raw.get("updated")

    listed_at = None
    if raw_created:
        try:
            listed_at = datetime.fromtimestamp(int(raw_created), tz=timezone.utc).strftime(
                "%Y-%m-%d %H:%M:%S"
            )
        except (TypeError, ValueError):
            pass

    # sold_at: APIに sold_at フィールドがあれば優先、なければ updated を代用
    sold_at = None
    sold_at_source = "none"
    if status == "sold_out":
        if raw.get("sold_at"):
            try:
                sold_at = datetime.fromtimestamp(int(raw["sold_at"]), tz=timezone.utc).strftime(
                    "%Y-%m-%d %H:%M:%S"
                )
                sold_at_source = "sold_at"
            except (TypeError, ValueError):
                pass
        if sold_at is None and raw_updated:
            try:
                sold_at = datetime.fromtimestamp(int(raw_updated), tz=timezone.utc).strftime(
                    "%Y-%m-%d %H:%M:%S"
                )
                sold_at_source = "updated"
            except (TypeError, ValueError):
                pass

    return {
        "item_id": item_id,
        "name": raw.get("name", ""),
        "price": price,
        "status": status,
        "listed_at": listed_at,
        "sold_at": sold_at,
        "sold_at_source": sold_at_source,
        "raw_created": raw_created,
        "raw_updated": raw_updated,
    }


def upsert_items(conn: sqlite3.Connection, items: list) -> int:
    sql = """
        INSERT OR REPLACE INTO items
            (item_id, name, price, status, listed_at, sold_at, sold_at_source,
             raw_created, raw_updated)
        VALUES
            (:item_id, :name, :price, :status, :listed_at, :sold_at, :sold_at_source,
             :raw_created, :raw_updated)
    """
    conn.executemany(sql, items)
    return len(items)


def collect(
    keyword: str,
    days_back: int = 90,
    max_pages: int = 100,
    statuses: list | None = None,
) -> int:
    """ページネーションしながら収集し、SQLiteに保存。収集件数を返す。"""
    if statuses is None:
        statuses = ["STATUS_ON_SALE", "STATUS_SOLD_OUT"]

    cutoff_dt = datetime.now(tz=timezone.utc) - timedelta(days=days_back)
    session = requests.Session()
    session.headers.update(BASE_HEADERS)

    page_token: str | None = None
    pages_fetched = 0
    total_written = 0
    stop_reason = "unknown"

    print(
        f"[collect] keyword={keyword!r} days_back={days_back} "
        f"max_pages={max_pages} statuses={statuses}"
    )
    print(f"[collect] cutoff={cutoff_dt.strftime('%Y-%m-%d %H:%M:%S')} UTC")

    with sqlite3.connect(DB_PATH) as conn:
        init_db(conn)

        while pages_fetched < max_pages:
            try:
                raw_items, page_token = search(session, keyword, statuses, page_token)
            except MercariHTTPError as e:
                if e.status_code == 429:
                    print("[rate-limit] HTTP 429 — waiting 10s ...", file=sys.stderr)
                    time.sleep(10)
                    continue
                print(
                    f"[error] HTTP {e.status_code}\n{e.body}",
                    file=sys.stderr,
                )
                if e.status_code in (401, 403):
                    print(
                        "[hint] DPoP/認証エラーの可能性。"
                        "ブラウザDevToolsからトークンを取得し BASE_HEADERS に追記してください。",
                        file=sys.stderr,
                    )
                raise

            if not raw_items:
                stop_reason = "empty_page"
                break

            parsed = [p for r in raw_items if (p := parse_item(r)) is not None]

            in_range = [
                p for p in parsed
                if p["listed_at"] and
                datetime.strptime(p["listed_at"], "%Y-%m-%d %H:%M:%S").replace(
                    tzinfo=timezone.utc
                ) >= cutoff_dt
            ]
            written = upsert_items(conn, in_range)
            total_written += written
            pages_fetched += 1

            oldest = None
            for p in parsed:
                if p["listed_at"]:
                    dt = datetime.strptime(p["listed_at"], "%Y-%m-%d %H:%M:%S").replace(
                        tzinfo=timezone.utc
                    )
                    if oldest is None or dt < oldest:
                        oldest = dt

            print(
                f"  page={pages_fetched:3d}  items={len(raw_items):3d}  "
                f"in_range={len(in_range):3d}  "
                f"oldest={oldest.strftime('%Y-%m-%d') if oldest else 'N/A'}"
            )

            if oldest and oldest < cutoff_dt:
                stop_reason = "date_cutoff"
                break

            if not page_token:
                stop_reason = "no_more_pages"
                break

            time.sleep(RATE_DELAY)
        else:
            stop_reason = "page_limit"

        conn.commit()

    print(
        f"[collect] done. reason={stop_reason} "
        f"pages={pages_fetched} total_written={total_written}"
    )
    return total_written


def main() -> None:
    p = argparse.ArgumentParser(description="メルカリ商品データを収集してSQLiteに保存")
    p.add_argument("--keyword", default="ビカクシダ", help="検索キーワード")
    p.add_argument("--days-back", type=int, default=90, help="何日前まで遡るか")
    p.add_argument("--max-pages", type=int, default=100, help="最大ページ数")
    p.add_argument(
        "--status",
        choices=["on_sale", "sold_out", "both"],
        default="both",
        help="取得するステータス",
    )
    args = p.parse_args()

    statuses = {
        "on_sale": ["STATUS_ON_SALE"],
        "sold_out": ["STATUS_SOLD_OUT"],
        "both": ["STATUS_ON_SALE", "STATUS_SOLD_OUT"],
    }[args.status]

    collect(args.keyword, args.days_back, args.max_pages, statuses)


if __name__ == "__main__":
    main()
