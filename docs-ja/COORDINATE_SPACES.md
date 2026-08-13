# Coordinate Spaces

## なぜ必要か

カメラアプリでは SwiftUI/UIKit view point、Vision normalized geometry、crop-relative、capture-device focus、upright image pixel、mirrored presentation など複数の座標 domain を跨ぎます。

## Canonical image space

CameraGeometryKit の canonical space は uncropped source image、upright、non-mirrored、0...1 normalized、左上原点、xは右、yは下です。

## 暗黙 clamp をしない

source point は現在の crop 外でも正当です。clip が必要な境界でだけ明示的に行います。

## 写真

UIKit image は読み込み境界で正規化します。

```swift
let image = source.cameraGeometryCanonicalized()
```

結果は orientation `.up`、scale `1` です。

## Crop と custom preview

`ImageCoordinateSpace` が source image から crop/output へ、`ViewportMapping` が upright canonical geometry から aspect-fit / aspect-fill viewport へ変換します。letterbox、crop、presentation mirroring は明示的に扱います。

## Vision

iOS 18+ では Swift-native Vision API の `NormalizedPoint` / `NormalizedRect` を使います。Vision は normalized 左下原点、canonical は normalized 左上原点です。

```text
Vision                        Canonical
(0,1) ───── (1,1)            (0,0) ───── (1,0)
  │           │                 │           │
(0,0) ───── (1,0)            (0,1) ───── (1,1)
```

Vision境界で一度だけ変換します。

```swift
let canonical = VisionGeometry.canonicalRect(from: observation.boundingBox)
let normalized = VisionGeometry.normalizedRect(from: canonical)
```

Swift-native Vision geometry は canonical へ渡るまでは Vision の型のまま保持します。

## Capture-device point-of-interest

`AVCaptureVideoPreviewLayer.captureDevicePointConverted(fromLayerPoint:)` の結果は focus/exposure 用 capture-device coordinate であり、canonical image coordinate ではありません。別型 `CaptureDevicePoint` を使います。

## 所有権ルール

すべての位置値について、どの coordinate space が所有する値か、次の space へ渡る explicit transform は何かを明示します。意味が途中で変わる無印 `CGPoint` を pipeline に流しません。
