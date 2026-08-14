# CameraGeometryKit サンプル

Camera session wrapper、preview rotation、canonical non-mirrored な解析
stream、最新フレーム統計を確認する iOS 18+ / Swift 6 サンプルアプリです。

Preview は `AVLayerVideoGravity.resizeAspect`（fit）で表示します。Geometry / rotation の検証では、クロップを伴う fill より fit を推奨します。ライブラリ自体は `videoGravity` を強制しません。

## Preview rotation

通常のアプリでは `CameraRotation.observe()` と `applyPreviewAngle(to:)` を組み合わせる必要はありません。

```swift
previewRotationBinding = camera.bindPreviewRotation(to: previewLayer)
```

`CameraPreviewRotationBinding` が `AVCaptureDevice.RotationCoordinator` の preview angle を初期適用し、その後の角度変更も PreviewLayer connection へ自動反映します。物理カメラを切り替えた場合は、新しい device に対して binding を作り直します。

## Orientation 診断 HUD

上部のステータスカード右端の chevron で診断 HUD を下方向に展開できます。

HUD は値の出所を分けて表示します。

- `LIBRARY → APP / SESSION`: `CameraCaptureSession` の公開状態と analysis/photo connection の実値
- `LIBRARY → APP / FRAME`: アプリが `CameraFrameGeometry` として実際に受け取った pixel size、rotation、mirroring
- `LIBRARY → APP / PREVIEW`: `CameraPreviewRotationBinding` が使用している preview/capture angle
- `APP / PREVIEW + UI`: `UIDeviceOrientation`、`UIInterfaceOrientation`、PreviewLayer の bounds/gravity/実際の connection rotation/mirroring/transform

正常時は `requested preview` と `preview actual` が一致します。不一致なら、binding / PreviewLayer connection の適用境界を調べます。`requested preview` 自体が期待と異なる場合は、ライブラリ側の RotationCoordinator source を調べます。

HUDは独自の `rotationEffect` や補正 transform を追加しません。Preview rotation の適用は `CameraPreviewRotationBinding` の責務で、HUDはその requested/actual の結果を観測します。端末姿勢が変化したときは同じ主要値を `[OrientationDebug]` として console に1回出力します。

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
