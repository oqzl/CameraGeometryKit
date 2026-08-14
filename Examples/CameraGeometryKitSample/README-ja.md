# CameraGeometryKit サンプル

Camera session wrapper、preview rotation、canonical non-mirrored な解析
stream、最新フレーム統計を確認する iOS 18+ / Swift 6 サンプルアプリです。

## ビルド

リポジトリルートから実行します。

```bash
cd Examples/CameraGeometryKitSample
xcodegen generate --spec project.yml
xcodebuild -project CameraGeometryKitSample.xcodeproj \
  -scheme CameraGeometryKitSample \
  -sdk iphoneos \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Xcodeで生成されたプロジェクトを開き、iOS 18+ 実機を選択して実行してください。
カメラ動作、回転、ミラーリング、カメラ切替の確認には実機が必要です。シミュレータは
ビルドと起動確認に限定してください。

このターゲットはリポジトリルートをローカル Swift Package 依存関係として参照します。
生成済みの `.xcodeproj` は checkout 後すぐ開けるように同じディレクトリへ置いています。
`project.yml` を変更した場合は、上記の `xcodegen generate` を再実行してください。
