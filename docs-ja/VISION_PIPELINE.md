# Vision Pipeline

CameraGeometryKit は iOS 18+ / Swift 6 専用です。Vision も iOS 18 で導入された Swift-native API のみを使います。旧 request-handler 互換レイヤーは持ちません。

## Request

Swift-native request は `ImageProcessingRequest` に準拠し、`CVPixelBuffer` に直接 `perform()` できます。

```swift
let request = DetectFaceRectanglesRequest()
let observations = try await request.perform(
    on: frame.pixelBuffer,
    orientation: frame.geometry.visionOrientation
)
```

## `CameraVisionWorker`

`CameraVisionWorker<Value>` は actor です。

- expensive operation は1件だけ in-flight
- pending は最新1 frameだけ
- Swift Task ベース
- invalidate 時に Task cancellation を要求
- `CameraFrameID` / timestamp を保持
- generation で stale result を排除
- MainActor gate を通して delivery

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

camera identity、analyzer settings、画面の所有者が変わったら:

```swift
await faces.invalidate()
```

Cancellation は resource control、generation identity が correctness guarantee です。

## Geometry

Swift-native Vision observation は `NormalizedPoint` / `NormalizedRect` / `BoundingBoxProviding` などを使います。Vision は normalized 左下原点、CameraGeometryKit canonical は normalized 左上原点です。

```swift
let canonical = VisionGeometry.canonicalRect(from: observation.boundingBox)
```

raw Vision geometry を通常の UI state に持ち込まず、Vision boundary で canonical へ変換します。

## Frame semantics

`CameraFrame.geometry.visionOrientation` を request に渡します。`appliedVideoRotationAngle` は AVFoundation がすでに適用した回転の記録であり、後段への再回転命令ではありません。

## 参考

- Apple Vision documentation
- WWDC24「VisionフレームワークにおけるSwiftの機能強化」
- `ImageProcessingRequest`
- `DetectFaceRectanglesRequest`
- `NormalizedRect`
