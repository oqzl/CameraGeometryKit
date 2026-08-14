# Device・Depth・ARKit Geometry

0.1.1 では shared geometry の範囲を device selection、depth、ARKit 境界へ広げます。

## Device selection

`CameraDeviceRequest` の `preferredDeviceTypes` を優先順に指定し、`AVCaptureDevice.DiscoverySession` で利用可能な camera を解決します。

```swift
let request = CameraDeviceRequest(
    position: .front,
    preferredDeviceTypes: [
        .builtInTrueDepthCamera,
        .builtInWideAngleCamera,
    ]
)
```

機種名による分岐は行いません。AVFoundation が報告する device type と capability を使います。

## Depth

`CameraCaptureSession(depthConfiguration:)` で opt-in します。利用可能なら同期された `AVDepthData` が `CameraFrame.depth` に入ります。RGB と depth はそれぞれの dimensions と geometry を保持し、同じ `CameraFrame.id` に属します。

要求した depth format が active video format で利用できない場合は configuration error にします。

## ARKit

`ARFrameGeometry` は ARKit captured-image normalized coordinates と canonical coordinates の変換だけを担当します。ARKit の API 契約に従い `ARFrame.displayTransform(for:viewportSize:)` を使用します。

AVFoundation の `videoRotationAngle` を interface orientation から計算するものではありません。`ARSession`、anchors、world tracking、scene reconstruction も担当しません。
