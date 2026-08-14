# CameraGeometryKit サンプル

Camera session wrapper、preview rotation、canonical non-mirrored な解析
stream、最新フレーム統計を確認する iOS 18+ / Swift 6 サンプルアプリです。

## Orientation 診断 HUD

上部のステータスカード右端の chevron で診断 HUD を下方向に展開できます。

HUD は値の出所を分けて表示します。

- `LIBRARY → APP / SESSION`: `CameraCaptureSession` の公開状態と analysis/photo connection の実値
- `LIBRARY → APP / FRAME`: アプリが `CameraFrameGeometry` として実際に受け取った pixel size、rotation、mirroring
- `LIBRARY → APP / PREVIEW`: `CameraGeometryKit` の `CameraRotation` がアプリへ返した preview/capture angle
- `APP / PREVIEW + UI`: `UIDeviceOrientation`、`UIInterfaceOrientation`、PreviewLayer の bounds/gravity/実際の connection rotation/mirroring/transform

たとえば `requested preview` が `90°` なのに `preview actual` が `0°` なら、ライブラリが返した値とサンプルアプリが実際に PreviewLayer へ反映した値の境界で食い違っています。逆に `requested preview` 自体が期待と異なる場合は、ライブラリ側の rotation source を調べます。

この診断 HUD 自体は orientation を補正しません。観測のために `rotationEffect` や追加の transform を入れず、実際の connection 値を表示します。端末姿勢が変化したときは同じ主要値を `[OrientationDebug]` として console に1回出力します。

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
