# CameraGeometryKit サンプル

CameraGeometryKit の主要機能を実機で検証する iOS 18+ / Swift 6 の Lab アプリです。

## タブ

- `Capture`: Camera session、preview rotation、frame statistics、orientation diagnostics HUD
- `Geometry`: `CanonicalPoint` / `CanonicalRect` / `ViewportMapping` の fit/fill・mirror・tap mapping
- `Vision`: `CameraVisionWorker` + Swift-native `DetectFaceRectanglesRequest`、Vision → canonical → preview overlay
- `Depth`: depth-capable device discovery、exact physical-device selection、synchronized RGB/depth、rotation、pixel dimensions、center depth
- `Image`: PhotosPicker から `UIImage.cameraGeometryCanonicalized()` / `cameraGeometryDownsampled()` を比較

Preview は `AVLayerVideoGravity.resizeAspect`（fit）で表示します。Geometry / rotation の検証では、クロップを伴う fill より fit を推奨します。ライブラリ自体は `videoGravity` を強制しません。

## Preview rotation

通常のアプリでは `CameraRotation.observe()` と `applyPreviewAngle(to:)` を組み合わせる必要はありません。

```swift
previewRotationBinding = camera.bindPreviewRotation(to: previewLayer)
```

`CameraPreviewRotationBinding` が `AVCaptureDevice.RotationCoordinator` の preview angle を初期適用し、その後の角度変更も PreviewLayer connection へ自動反映します。物理カメラを切り替えた場合は、新しい device に対して binding を作り直します。

## Orientation 診断 HUD

Capture タブ上部のステータスカード右端の chevron で診断 HUD を展開できます。

- `LIBRARY → APP / SESSION`: `CameraCaptureSession` の公開状態と analysis/photo connection の実値
- `LIBRARY → APP / FRAME`: `CameraFrameGeometry` として届いた pixel size、rotation、mirroring
- `LIBRARY → APP / PREVIEW`: `CameraPreviewRotationBinding` が使用している preview/capture angle
- `APP / PREVIEW + UI`: device/interface orientation、PreviewLayer bounds/gravity/connection rotation/mirroring/transform

正常時は `requested preview` と `preview actual` が一致します。HUDは独自の `rotationEffect` や補正 transform を追加しません。JSON は Copy / Share できます。

## Feature matrix

| Library feature | Sample surface |
|---|---|
| `CameraCaptureSession` / `CameraFrameStream` | Capture |
| `CameraPreviewRotationBinding` / `CameraRotation` | Capture / Vision / Depth |
| `CameraDeviceDiscovery` / exact `CameraDeviceRequest` | Depth |
| `CanonicalPoint` / `CanonicalRect` / `ViewportMapping` | Geometry / Vision |
| `CameraVisionWorker` / `VisionGeometry` | Vision |
| synchronized RGB + depth / `CameraDepthFrame` | Depth |
| UIImage canonicalization / downsampling | Image |
| orientation diagnostics JSON | Capture |

`ImageCoordinateSpace`、`CaptureDevicePoint`、`ARKitFrameAdapter`、photo capture を追加の検証面として残しています。これらも sample から到達可能にして feature matrix を完全に埋める方針です。

## ビルド

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

Xcodeで生成されたプロジェクトを開き、iOS 18+ 実機を選択して実行してください。カメラ動作、rotation/mirroring、TrueDepth/LiDAR、camera switching の確認には実機が必要です。
