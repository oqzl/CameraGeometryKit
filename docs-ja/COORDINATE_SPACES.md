# Coordinate Spaces

## なぜ必要か

カメラアプリでは「型としては正しい `CGPoint`、意味としては間違った `CGPoint`」が頻発します。SwiftUI touch、Vision左下原点 normalized、crop-relative、capture-device focus、orientation-up image pixel、mirror preview は別 space です。

## Canonical image space

CameraGeometryKit の canonical space は uncropped source image、upright、non-mirrored、0...1 normalized、左上原点、xは右、yは下です。画像中心は解像度・preview size・crop に関係なく常に `CanonicalPoint(x: 0.5, y: 0.5)` です。

## 暗黙 clamp をしない

source point は現在の crop 外でも正当です。暗黙 clamp は「crop外」を「crop edge上」へ意味変換します。clip が必要な境界でだけ明示的に行います。

## 写真

UIKit image は orientation metadata と scale を持ち得ます。読み込み境界で:

```swift
let image = source.cameraGeometryCanonicalized()
```

orientation `.up`、scale `1` にし、1 image unit = 1 pixel にします。

## Crop

`ImageCoordinateSpace` は uncropped source pixel size と同じ左上原点 space の crop rect を持ちます。canonical point は source image に所属し、aspect-ratio change では source→output mapping だけが変わります。

## Custom preview

`ViewportMapping` が upright canonical image/frame を View に割り当てます。

- aspect fit: letterbox touch は `nil`
- aspect fill: crop offset を保持し、edgeへ勝手に clamp しない
- mirrored presentation: display x だけ反転し canonical x は不変

canonical x=0.2 は front mirror preview で画面上 x≈0.8 に見えても、保存値は0.2です。

## Vision

Vision bounding box は左下原点 normalized、canonical は左上原点です。

```text
Vision                        Canonical
(0,1) ───── (1,1)            (0,0) ───── (1,0)
  │           │                 │           │
  │           │       →         │           │
(0,0) ───── (1,0)            (0,1) ───── (1,1)
```

Vision境界で一度だけ変換します。

```swift
let rect = VisionGeometry.canonicalRect(
    fromVisionNormalized: observation.boundingBox
)
```

## Capture-device point-of-interest

`captureDevicePointConverted(fromLayerPoint:)` の結果は focus/exposure 用 unrotated picture-area normalized point で、upright canonical image point ではありません。別型 `CaptureDevicePoint` を使います。

## 所有権ルール

すべての位置値について次を答えられるようにします。

1. この値を所有する coordinate space は何か。
2. 次の space へ渡る explicit transform は何か。

「ただの CGPoint だけど、この辺では意味が分かっている」は将来の座標バグです。
