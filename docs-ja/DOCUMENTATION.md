# ドキュメント

CameraGeometryKit は API リファレンスに Swift-DocC を使用します。
ドキュメントカタログは
`Sources/CameraGeometryKit/CameraGeometryKit.docc` にあります。

## ローカルで生成する

パッケージのルートで実行します。

```sh
swift package \
    --triple arm64-apple-ios18.0-simulator \
    --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
    --allow-writing-to-directory docs-site \
    generate-documentation \
    --target CameraGeometryKit \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path CameraGeometryKit \
    --output-path docs-site
```

生成サイトは `docs-site/` に出力されます。このディレクトリは Git の
管理対象外です。編集中にカタログをプレビューするには次を実行します。

```sh
swift package --disable-sandbox \
    preview-documentation --target CameraGeometryKit
```

## GitHub Pages で公開する

`.github/workflows/documentation.yml` が `main` ブランチへの関連変更ごとに
サイトを生成し、GitHub Pages にデプロイします。生成済みサイトを
リポジトリへコミットする必要はありません。

1. リポジトリの **Settings > Pages** を開きます。
2. **Source** を **GitHub Actions** に設定します。
3. ワークフローと DocC カタログを `main` に push するか、**Actions** タブの
   **Run workflow** から手動実行します。
4. Pages 設定画面に表示された URL を開きます。このリポジトリでは通常、次の URL
   です。
   `https://oqzl.github.io/CameraGeometryKit/documentation/camerageometrykit/`

`github.io/CameraGeometryKit/` の下に公開するプロジェクト Pages のため、
`CameraGeometryKit` の hosting base path が必要です。リポジトリ名や Pages の
URL を変更した場合は、ワークフローの `--hosting-base-path` と対象ブランチも
更新してください。
