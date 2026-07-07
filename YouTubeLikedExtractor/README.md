# YouTube Liked Extractor

指定した期間に YouTube で「いいね」した動画の **タイトル・内容（説明）・URL** を抽出してリスト化し、
YouTube 標準カテゴリ（`categoryId` / `topicDetails`）から **自動でトピックを分類・タグ付け**して、
アプリ内表示 / CSV / JSON で出力する iOS アプリです。

SwiftUI + MVVM で構成され、同リポジトリの `InstagramDownloader` と同じ設計パターンを踏襲しています。

## 主な機能

- Google OAuth 2.0（PKCE）でサインイン（スコープは `youtube.readonly` のみ）
- 期間（開始日〜終了日）を指定して、いいねした動画を抽出
- 各動画のカテゴリ・トピックから自動タグ付け（LLM/外部API 不要）
- タグでの絞り込み表示
- CSV / JSON でエクスポート（共有シート）

## 仕組み

1. いいね動画は特別なプレイリスト **`LL`** として取得できます。
   `playlistItems.list(playlistId="LL")` の `snippet.publishedAt` が「いいねした日時（＝プレイリスト追加日時）」で、
   これを使って期間フィルタを行います（新しい順に返るため、範囲より古くなった時点で取得を打ち切ります）。
2. `videos.list(part=snippet,topicDetails)` で各動画の **タイトル / 説明 / `categoryId` / `topicDetails`** を取得。
3. `videoCategories.list(regionCode=JP)` で `categoryId → カテゴリ名` を解決。
4. タグ = カテゴリ名 + `topicDetails.topicCategories` の Wikipedia URL 末尾ラベル（重複排除）。

> ⚠️ **注意**: `LL` プレイリストの `publishedAt`（いいね日時）は YouTube 側の仕様上、
> 完全な精度が保証されるものではありません。期間フィルタの結果は目安としてご利用ください。

## セットアップ

このアプリを実機/シミュレータで動かすには、Google Cloud 側の設定が必要です。

1. **Google Cloud プロジェクトを作成**（[Google Cloud Console](https://console.cloud.google.com/)）。
2. **YouTube Data API v3 を有効化**（APIとサービス → ライブラリ）。
3. **OAuth 同意画面** を設定（テストユーザーに自分の Google アカウントを追加）。
4. **OAuth クライアントID（iOS）** を作成。バンドルIDは
   `com.yourcompany.youtubelikedextractor`（または `project.pbxproj` で設定した値）を指定。
5. 発行された **iOS クライアントID** を 2 箇所に設定します。

   - `YouTubeLikedExtractor/Services/GoogleAuthService.swift`
     ```swift
     var clientID: String = "1234567890-abcdefg.apps.googleusercontent.com"
     ```
   - `YouTubeLikedExtractor/Info.plist` の `CFBundleURLSchemes`（**リバース** クライアントID）
     ```xml
     <string>com.googleusercontent.apps.1234567890-abcdefg</string>
     ```
     ※ リバースクライアントIDは、クライアントIDのドット区切りを逆順にしたものです。

## 動作確認手順（実機 / Xcode）

1. `YouTubeLikedExtractor.xcodeproj` を Xcode 15+ で開く。
2. 上記セットアップの Client ID / URL スキームを設定。
3. 実機またはシミュレータでビルド・起動。
4. 「Googleでサインイン」→ 同意。
5. 開始日・終了日を指定して「抽出する」。
6. タグ（カテゴリ）チップで絞り込み。行タップで詳細（説明全文・YouTubeで開く）。
7. 右上メニューから CSV / JSON をエクスポート（共有シート）。

## テスト

ロジック（期間フィルタ・タグ抽出・CSV/JSON エスケープ・API JSON デコード）を中心に
ユニットテストを用意しています。Xcode 環境で:

```sh
xcodebuild test \
  -project YouTubeLikedExtractor.xcodeproj \
  -scheme YouTubeLikedExtractor \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 構成

```
YouTubeLikedExtractor/
├── App/            アプリのエントリ・ルーティング
├── Models/         LikedVideo / API レスポンスの Codable
├── Services/       GoogleAuth(OAuth) / YouTubeAPI / Export
├── ViewModels/     Auth / LikedVideos
└── Views/          Login / Home / VideoRow / VideoDetail
YouTubeLikedExtractorTests/
├── Mocks/          MockYouTubeAPIService
├── YouTubeAPIServiceTests
├── LikedVideosViewModelTests
└── ExportServiceTests
```
