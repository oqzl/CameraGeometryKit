# CameraGeometryKit

CameraGeometryKit は、写真、画面タッチ、Vision、ライブ動画フレーム、前面／背面カメラ、左右反転、端末回転、クロップ、プレビューについて「画像中の同じ場所」を一貫して扱うための iOS 18+ / Swift 6 専用基盤です。

AVFoundation、Vision、UIKit/SwiftUI、Core Image、写真、動画フレームは、それぞれ正しいものの異なる座標系・向きの規約を持っています。CameraGeometryKit はアプリ内部に一つの canonical image space を定義し、外部APIとの境界でだけ変換します。

```text
Photo / Camera Frame / Vision / Touch / Crop / Preview
                         │
                         ▼
              Canonical Image Space

原点        左上
x           左 → 右
y           上 → 下
範囲        0...1 正規化
向き        upright
左右反転    なし
```

[English](README.md)

## 要件

- iOS 18+
- Swift 6
- iOS 18+ SDK を含む Xcode
- 外部依存なし
- iOS 18 より前の Vision API 互換レイヤーなし

## このパッケージが担当するもの

- 型付き canonical point / rect
- crop / output image 座標変換
- aspect fit / aspect fill の preview mapping
- `UIImage` の canonical 化（orientation `.up` / scale 1）
- 薄い `CameraCaptureSession` 基盤
- 最新1フレーム方式の `AVCaptureVideoDataOutput` stream
- frame ID / timestamp / rotation / mirror / dimensions
- `AVCaptureDevice.RotationCoordinator` の共通処理
- Preview と Analysis の mirror policy 分離
- Swift-native Vision geometry の canonical 変換
- Swift Concurrency ベースの live Vision scheduling
- generation-safe な result delivery
- diagnostics
- 機種別の実機検証記録

## 担当しないもの

- エフェクト、フィルタ
- アプリ固有の camera chrome
- 万能 `CameraManager`
- 具体的な Vision model / 製品上の意味付け
- Best Shot、Tracking 等の製品ワークフロー
- 保存・共有ポリシー
- 汎用ランタイムパイプライングラフ

製品機能の composition root は各アプリに残します。

## 導入

```swift
import CameraGeometryKit
```

Package 自体が iOS 18+ / Swift 6 固定です。

## サンプルアプリ

`Examples/CameraGeometryKitSample` に SwiftUI のカメラサンプルを追加しています。
[ビルド手順](Examples/CameraGeometryKitSample/README-ja.md)に従って実機で実行できます。

## Canonical 座標

Screen、Vision、crop-relative、image の点を同じ無印 `CGPoint` で持ちません。

```swift
let subject = CanonicalPoint(x: 0.42, y: 0.61)
```

Canonical 値は暗黙には clamp しません。現在の crop 外にある点も source image 上の位置としては正しいからです。

```swift
let space = ImageCoordinateSpace(
    sourceSize: CGSize(width: 4032, height: 3024),
    cropRect: CGRect(x: 504, y: 0, width: 3024, height: 3024)
)
let outputPoint = space.outputNormalizedPoint(for: subject)
```

表示 preview には `ViewportMapping` を使います。aspect fit の余白タップは `nil`、aspect fill の見切れは暗黙 clamp しません。

## 写真

画像読込の境界で orientation と scale を正規化します。

```swift
let canonicalImage = image.cameraGeometryCanonicalized()
let preview = canonicalImage.cameraGeometryDownsampled(maxPixelDimension: 1600)
```

canonical image は orientation `.up` / scale `1` です。

## Capture Session

`CameraCaptureSession` を標準の薄い開始点とします。camera authorization、単一 video input、`CameraFrameStream`、`AVCapturePhotoOutput`、直列化した start/stop と camera switch、capture rotation、canonical non-mirroring を担当します。

```swift
let camera = CameraCaptureSession()
try await camera.start(position: .back)
```

公開している `captureSession` は preview layer 接続用であり、外側から capture graph を独自変更するためのものではありません。

```swift
let previewLayer = AVCaptureVideoPreviewLayer(session: camera.captureSession)
let previewRotation = camera.makePreviewRotation(previewLayer: previewLayer)
```

camera switch 完了後は preview rotation を作り直します。写真撮影直前には photo connection を再同期します。

```swift
try await camera.preparePhotoCapture()
camera.photoOutput.capturePhoto(with: settings, delegate: delegate)
```

Photo settings/delegate、preview UI、recording、effects、製品ワークフローはアプリ側の責務です。

詳細は [Capture Session](docs-ja/CAPTURE_SESSION.md)。

## カメラフレーム

`CameraFrameStream` は `AVCaptureVideoDataOutput` と `AsyncStream<CameraFrame>` を提供し、pending は最新1件だけ保持します。標準 Session wrapper が capture angle と canonical non-mirroring を設定します。

`AVCaptureVideoDataOutput` は `videoRotationAngle` を frame 自体へ適用するため、`CameraFrame.geometry.appliedVideoRotationAngle` は診断情報です。後段でもう一度回してはいけません。

```text
capture 60 fps
    │
    ├─ frame 100 ── analysis 実行中
    ├─ frame 101 ── 置換
    ├─ frame 102 ── 置換
    └─ frame 103 ── 最新 pending
```

## 回転

Preview angle と Capture angle は別責務です。`CameraRotation` / `AVCaptureDevice.RotationCoordinator` を使い、interface orientation、`UIDeviceOrientation`、Front/Back、pixel dimensions、iPhone機種表から camera angle を逆算しません。

詳細は [Camera Rotation](docs-ja/CAMERA_ROTATION.md)。

## Mirroring

Preview の鏡像表示と、保存・解析画像の identity は別物です。標準方針は「Front Preview は mirror、Analysis / 保存物は non-mirror」です。

## Vision

CameraGeometryKit は iOS 18+ の Swift-native Vision API を使います。旧 request-handler 互換レイヤーは持ちません。

Vision observation の normalized geometry は `NormalizedRect` などで表現されます。Vision 境界で canonical へ変換します。

```swift
let canonicalBox = VisionGeometry.canonicalRect(from: observation.boundingBox)
```

Live Vision の標準入口は `CameraVisionWorker<Value>` です。actor として、expensive operation は1件だけ in-flight、pending は最新1 frameだけ、obsolete work は Task cancellation を要求し、frame identity と generation-safe delivery を維持します。

```swift
let faces = CameraVisionWorker<[CanonicalRect]>(
    makeRequest: { DetectFaceRectanglesRequest() },
    map: { observations in
        observations.map {
            VisionGeometry.canonicalRect(from: $0.boundingBox)
        }
    },
    delivery: { output in
        faceBoxes = output.value
    }
)

for await frame in camera.frameStream.frames {
    await faces.submit(frame)
}
```

camera identity、analyzer settings、画面の消費主体が変わったら:

```swift
await faces.invalidate()
```

具体的な Vision request と semantic result mapping はアプリ側に残します。詳細は [Vision Pipeline](docs-ja/VISION_PIPELINE.md)。

## Touch と `AVCaptureVideoPreviewLayer`

Preview layer の focus/exposure point は canonical image space ではありません。`CaptureDevicePoint` として区別し、AVFoundation の変換APIを使います。custom preview 上のアプリ意味座標には `ViewportMapping` を使います。

## Diagnostics

実機検証では camera position、preview/capture/analysis rotation angle、mirror flags、frame dimensions、delivered frames、AVFoundation drops、latest-buffer replacement を記録します。

詳細は [Validation](docs-ja/VALIDATION.md)。

## 最重要の禁止事項

[PROHIBITIONS.md](docs-ja/PROHIBITIONS.md) に明文化しています。

- 機種別角度表を作らない
- UI orientation から camera angle を計算しない
- deprecated な `videoOrientation` 系を使わない
- 二重回転しない
- Front camera = 保存物も mirror と決めつけない
- 旧 Vision request-handler 経路を使わない
- Vision raw geometry を UI state に流さない
- フレームを無制限にキューしない
- MainActor / capture callback で重い処理をしない
- generation 変更後の旧結果を publish しない
- width / height から orientation を推測しない
- `CameraCaptureSession` の capture graph を外側から変更しない

## ドキュメント

- [Architecture](docs-ja/ARCHITECTURE.md)
- [Coordinate Spaces](docs-ja/COORDINATE_SPACES.md)
- [Capture Session](docs-ja/CAPTURE_SESSION.md)
- [Camera Rotation](docs-ja/CAMERA_ROTATION.md)
- [Vision Pipeline](docs-ja/VISION_PIPELINE.md)
- [Prohibited Patterns](docs-ja/PROHIBITIONS.md)
- [Validation](docs-ja/VALIDATION.md)
- [Roadmap](docs-ja/ROADMAP.md)

## License

MIT
