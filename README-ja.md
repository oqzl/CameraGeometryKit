# CameraGeometryKit

CameraGeometryKit は、写真、画面タッチ、Vision、ライブ動画フレーム、前面／背面カメラ、左右反転、端末回転、クロップ、プレビューについて「画像中の同じ場所」を一貫して扱うための iOS 18+ / Swift 6 専用基盤です。

AVFoundation、Vision、UIKit/SwiftUI、Core Image、写真、動画フレームは、それぞれ正しいものの異なる座標系・向きの規約を持っています。小さなPoCなら場当たり的な変換でも動きますが、カメラアプリが育つと破綻します。

CameraGeometryKit は、アプリ内部に一つの canonical image space を定義し、外部APIとの境界でだけ変換します。

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

## このパッケージが担当するもの

- 型付き canonical point / rect
- クロップと出力画像座標の変換
- aspect fit / aspect fill のプレビュー座標変換
- 写真の canonical 化（`UIImage` を orientation `.up`、scale 1へ）
- 最新1フレーム方式の `AVCaptureVideoDataOutput` ストリーム
- フレームID、timestamp、回転、mirror、解像度のスナップショット
- `AVCaptureDevice.RotationCoordinator` の扱い
- Preview と Analysis の mirror policy 分離
- Vision normalized 座標変換
- bounded frame delivery と stale-result 抑止用 generation token
- diagnostics
- 機種別の実機検証記録

## 担当しないもの

- エフェクト、フィルタ
- アプリ固有のカメラUI
- 万能 `CameraManager`
- Best Shot、Trackingなど製品固有ワークフロー
- 保存・共有ポリシー
- 汎用ランタイムパイプライングラフ

CameraGeometryKit は基盤です。製品機能の composition root は各アプリに残します。

## 導入

Swift Package として追加し、次を import します。

```swift
import CameraGeometryKit
```

Package 自体が iOS 18+ / Swift 6 固定です。

## Canonical 座標

Screen、Vision、crop-relative、image の点を、すべて同じ無印 `CGPoint` で持たないことが基本です。

```swift
let subject = CanonicalPoint(x: 0.42, y: 0.61)
```

Canonical 値は暗黙には clamp しません。現在の crop 外にある点も、source image 上の位置としては正しいからです。

クロップ済み出力への変換:

```swift
let space = ImageCoordinateSpace(
    sourceSize: CGSize(width: 4032, height: 3024),
    cropRect: CGRect(x: 504, y: 0, width: 3024, height: 3024)
)
let outputPoint = space.outputNormalizedPoint(for: subject)
```

表示プレビューへの変換:

```swift
let mapping = ViewportMapping(
    imageSize: image.size,
    viewportSize: viewSize,
    contentMode: .aspectFit,
    isMirrored: false
)
let canonical = mapping.canonicalPoint(fromViewport: touchLocation)
```

aspect fit の余白タップは `nil`。aspect fill の見切れは勝手に clamp せず、そのまま座標差として保持します。

## 写真

写真読込の境界で orientation と scale を正規化します。

```swift
let canonicalImage = image.cameraGeometryCanonicalized()
```

これで orientation `.up` / scale `1` となり、画像処理は「1 unit = 1 pixel」で考えられます。プレビュー用の縮小は normalized 座標を変えません。

## Capture Session との統合

CameraGeometryKit は `AVCaptureSession` 全体を所有しません。permission UX、device selection、session lifecycle、photo/movie output、camera chrome はアプリ側の責務です。パッケージは、それらの経路をまたいで意味を一致させる必要がある部品だけを提供します。

Live analysis では `CameraFrameStream.output` をアプリの session に追加し、active camera が変わるたびに stream の camera position を更新します。

```swift
let frameStream = CameraFrameStream()

session.beginConfiguration()
session.addOutput(frameStream.output)
frameStream.setCameraPosition(device.position)
session.commitConfiguration()
```

カメラ切替時は新しい `AVCaptureDevice` 用に `CameraRotation` を作り直し、connection policy を再適用し、旧 processing generation を invalidate します。

## カメラフレーム

`CameraFrameStream` は `AVCaptureVideoDataOutput` と `AsyncStream<CameraFrame>` を提供します。バッファは最新1件だけです。

```swift
@MainActor
func configureAnalysisConnection(
    frameStream: CameraFrameStream,
    rotation: CameraRotation
) {
    guard let connection = frameStream.output.connection(with: .video) else { return }
    rotation.applyCaptureAngle(to: connection)
    CameraConnectionConfiguration.configureCanonicalAnalysisMirroring(on: connection)
}
```

`AVCaptureVideoDataOutput` は `videoRotationAngle` が設定されると配信する pixel buffer 自体を物理回転します。したがって `CameraFrame.geometry.appliedVideoRotationAngle` は診断情報です。後段でもう一度回してはいけません。

フレームは溜めません。

```text
capture 60 fps
    │
    ├─ frame 100 ── analysis 実行中
    ├─ frame 101 ── 置換
    ├─ frame 102 ── 置換
    └─ frame 103 ── 最新 pending
```

## 回転

active `AVCaptureDevice` ごとに `CameraRotation` を作ります。

```swift
@MainActor
let rotation = CameraRotation(device: device, previewLayer: previewLayer)
```

Preview には preview angle、撮影物／canonical analysis frame には capture angle を使います。

```swift
rotation.applyPreviewAngle(to: previewConnection)
rotation.applyCaptureAngle(to: analysisConnection)
```

interface orientation、`UIDeviceOrientation`、前面／背面、pixel buffer の縦横、iPhone機種表から角度を逆算してはいけません。

詳細は [Camera Rotation](docs-ja/CAMERA_ROTATION.md)。

## Mirroring

Preview の鏡像表示と、保存・解析画像の identity は別物です。

```swift
CameraConnectionConfiguration.configurePreviewMirroring(
    on: previewConnection,
    cameraPosition: device.position
)
CameraConnectionConfiguration.configureCanonicalAnalysisMirroring(on: analysisConnection)
```

標準方針は「Front Preview は mirror、Analysis / 保存物は non-mirror」です。

## Vision

Vision は主要な座標境界なので基盤に含めます。Vision normalized 座標は左下原点です。境界で即座に canonical へ変換します。

```swift
let canonicalBox = VisionGeometry.canonicalRect(
    fromVisionNormalized: observation.boundingBox
)
```

Live Vision は `CameraFrameStream.frames` を逐次 consume します。stream 自体が最新1件だけを buffer するため、解析が遅くても FIFO backlog は成長しません。

旧設定の結果を publish しないために `WorkGeneration` を使います。

```swift
let generation = WorkGeneration()
let workGeneration = generation.current

// Vision は MainActor 外で実行する。
// publish 直前に:
guard generation.isCurrent(workGeneration) else { return }
```

カメラ切替、analyzer 設定変更、画面離脱時:

```swift
generation.invalidate()
request.cancel() // VNRequest 実行中なら cancel
```

Cancellation は resource control、generation comparison が correctness guarantee です。詳細は [Vision Pipeline](docs-ja/VISION_PIPELINE.md)。

## Touch と `AVCaptureVideoPreviewLayer`

Live Preview Layer の focus/exposure 座標は canonical image space ではありません。別の型として保持し、`videoGravity` 等の変換は AVFoundation に任せます。

```swift
let point: CaptureDevicePoint = previewLayer.captureDevicePoint(
    fromLayerPoint: touchLocation
)
device.focusPointOfInterest = point.cgPoint
```

これを `CanonicalPoint` として保存してはいけません。canonical frame/image を custom preview している場合のアプリ意味座標には `ViewportMapping` を使います。

## Diagnostics

座標系バグは推測せず、値を出します。最低限次を実機検証時に記録します。

```text
camera position
preview rotation angle
capture rotation angle
analysis connection angle
preview mirrored
analysis mirrored
frame dimensions
frames delivered
frames dropped by AVFoundation
pending frames replaced by latest-frame buffering
```

詳細は [Validation](docs-ja/VALIDATION.md)。

## 最重要の禁止事項

[PROHIBITIONS.md](docs-ja/PROHIBITIONS.md) に明文化しています。

- 機種別角度表を作らない
- UI orientation から camera angle を計算しない
- 二重回転しない
- Front camera = 保存物も mirror と決めつけない
- Vision raw 座標を UI state に流さない
- フレームを無制限にキューしない
- MainActor / capture callback で重い処理をしない
- generation 変更後の旧結果を publish しない
- width / height から orientation を推測しない

## ドキュメント

- [Architecture](docs-ja/ARCHITECTURE.md)
- [Coordinate Spaces](docs-ja/COORDINATE_SPACES.md)
- [Camera Rotation](docs-ja/CAMERA_ROTATION.md)
- [Vision Pipeline](docs-ja/VISION_PIPELINE.md)
- [Prohibited Patterns](docs-ja/PROHIBITIONS.md)
- [Validation](docs-ja/VALIDATION.md)
- [Roadmap](docs-ja/ROADMAP.md)

## License

MIT
