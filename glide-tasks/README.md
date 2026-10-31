# Glide

起動直後にメモし、フリックで管理するモバイルファーストのタスクアプリ。

## 実装

- 入力欄は初期HTMLに配置。ログイン・ネットワークの確認を待たず入力できる。下書きは即時保存。
- Enterで追加、Shift+Enterで改行。日本語IME変換中はEnter追加しない。
- 右フリック：完了／解除。左フリック：着手／未着手。しきい値74px、縦スクロールを優先。
- 編集、削除と7秒間の取り消し、期限、優先度、検索、3種の並べ替え。
- 白のリキッドグラスUI。カード追加・フリック・シート・スケルトンにアニメーション。
- 全画面スケルトンは約430msで終了し、入力を遮らない。OSとアプリ内の動き軽減設定に対応。
- 未ログイン：このブラウザに保存。Googleログイン後：D1に保存。端末内タスクの取り込みは明示操作。
- 同期キュー、通信復帰時の再送、バージョン条件による競合検知。競合時はサーバーの内容を採用し通知。
- Workers AIでメモを3〜6タスクに分解。候補を選んで追加。毎分10回／ユーザーに制限。
- Service Workerでオフライン起動の土台を実装。API・認証はキャッシュしない。JSON書き出し。
- 外部フォント、分析トラッキング、装飾用画像、キャッチコピーなし。

## 技術選定と理由

| 採用 | 理由・役割 |
|---|---|
| HTML + JavaScript ES Modules | 初期HTMLだけで入力でき、フレームワーク起動・hydrationを待たない。小さな単一画面アプリなので依存と転送量を抑える。現段階でReact/Nextは不要と判断。 |
| ネイティブCSS | backdrop-filter、半透明グラデーション、光沢・影でガラスを表現。transform/opacity中心の動きと軽減設定を、追加ライブラリなしで実装。 |
| Pointer Events | タッチ・マウス・ペンを同じ実装で扱う。touch-action: pan-yで縦スクロールとフリックを共存。 |
| Cloudflare Workers ESM | HTML配信とAPIを一つに集約。別サーバー・CORS設定を減らし、Web標準APIで移植しやすくする。 |
| Cloudflare D1 / SQL | タスク・セッション・AI利用制限を永続化。user_idを全クエリに含め、複合主キーで分離。SQLとバージョン条件で更新競合を検知。マイグレーションは履歴管理。 |
| Google OpenID Connect | パスワードを持たずGoogleのみで認証。Authorization Code + PKCE、署名付きstate、nonce、Google公開鍵でRS256署名とaud/iss/exp/iat/email_verifiedを検証。 |
| Workers AI / Llama 3.1 8B Instruct | CloudflareのAIで短いタスク分解。独自WorkerではAI binding、SitesではWorkers AI RESTを利用できる。AI候補は自動確定しない。 |
| Web Crypto API | PKCE、HMAC、署名検証、セッショントークンのSHA-256ハッシュ、ランダムIDに標準暗号APIを使用。 |
| localStorage | 小規模なメモ、下書き、アカウント別キャッシュ、送信待ちキューを同期的に復元し速さを優先。クラウドの本体はD1。ブラウザ削除で未ログインデータは失われる。大量運用ではIndexedDB移行を検討。 |
| Service Worker + Manifest | 再訪時のオフライン起動とホーム画面追加の土台。初回オフライン起動、プッシュ通知、ストア配布は範囲外。 |
| Node.js 24 / node:test / node:sqlite | 開発依存ゼロのビルド・テスト。実SQLと暗号署名の異常系を確認。Node.jsは開発用で、本番Workerでは不要。 |
| GitHub / Actions | コード・SQL・テスト・技術選定の履歴管理。CIと明示的な手動Cloudflareデプロイを用意。 |
| Sites | 利用可能なCloudflare Workers/D1の公開基盤。同じアプリをGitHubにも保存。GitHub pushだけでSitesへ自動反映はしない。 |

画像・R2・KV・外部UIキット・外部AIプロバイダーは今回の機能に不要なので採用していない。

## 実行

Node.js 24以降。開発依存のインストールは不要。

```sh
npm run build
npm test
npm run validate
npm run dev -- --port 3000
```

開発サーバーは端末内モードのUI用。Google/AIの資格情報は自動読込しない。`/__qa/mobile?width=390` は開発限定のiframeビューポート。本番ではframe-ancestors 'none' / X-Frame-Options: DENY。

## 接続状態

**Google OAuthとWorkers AIは未接続。実装済みでも、実Googleログイン・実AI推論・本番端末間同期が検証済みという意味ではない。** 端末内の操作を利用できる。D1はSitesでプロビジョニングする。詳細は `docs/verification.md`。

## Google認証

1. Google Cloud ConsoleでWebアプリ用OAuthクライアント・同意画面を作成。
2. 認可済みリダイレクトURIに本番オリジン + `/auth/google/callback` を登録。
3. Workerの秘密環境変数 `GOOGLE_CLIENT_ID`、`GOOGLE_CLIENT_SECRET`、ランダムな32バイト以上の `SESSION_SECRET` を設定し再デプロイ。
4. Googleログイン後、追加→再読込→別ブラウザで同一アカウント→別アカウントから非表示を確認。

セッションは7日。不透明トークンをSecure/HttpOnly/SameSite=Lax/__Host- cookieで保持し、DBにはハッシュのみ保存。更新APIはOrigin一致とJSONを検証する。ログイン先はGoogleだけ。

公式資料：https://developers.google.com/identity/openid-connect/openid-connect

## Workers AI

独自Cloudflareでは `wrangler.jsonc` の `ai.binding = "AI"`。Sitesでは秘密環境変数 `CLOUDFLARE_ACCOUNT_ID` とWorkers AI実行権限の `CLOUDFLARE_AI_TOKEN` を設定して再デプロイ。

モデル：`@cf/meta/llama-3.1-8b-instruct`。AIボタンを押した時だけ入力文を送信し、一覧全体は送信しない。料金・利用可否はCloudflare契約と現行設定に従う。

公式資料：https://developers.cloudflare.com/workers-ai/configuration/bindings/

## 独自Cloudflareへ公開

1. D1を作成して `wrangler.jsonc` の `database_id` を実IDに置換。
2. `npm run build`
3. `npx wrangler d1 migrations apply DB --remote`
4. `npx wrangler secret put GOOGLE_CLIENT_ID`、`GOOGLE_CLIENT_SECRET`、`SESSION_SECRET` をそれぞれ設定。
5. `npx wrangler deploy`。公開URLをGoogleリダイレクトURIに追加。

GitHub ActionsではSecretsに `CLOUDFLARE_API_TOKEN`、Variablesに `CLOUDFLARE_ACCOUNT_ID` と `CLOUDFLARE_D1_DATABASE_ID` を設定し、手動の `Glide Cloudflare deploy` を実行。OAuth秘密情報はCloudflareに事前設定。SitesのD1から独自D1へのデータ移行は自動では行わない。

資格情報をチャットやリポジトリに記載しない。`.env.example` は名前のみ。

## ファイル

- `src/index.html`、`src/style.css`、`src/app.js`：画面
- `src/server.js`：Worker API
- `src/sw.js`：オフライン
- `scripts/build.mjs`：自己完結Workerにバンドル
- `drizzle/`：SQL
- `tests/`：サーバー側検証

長期運用では失効セッション・古いAI利用集計の定期清掃、バックアップ、実機・複数端末試験を追加する。現在の取得上限は1万件／ユーザー。それ以上の運用は未対応。
