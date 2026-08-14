# Device Selection / Depth Geometry / ARKit

## Device selection

CameraGeometryKit は iPhone 機種名ではなく、AVFoundation が実行時に報告する capability で camera を選びます。

`CameraDeviceRequest` に優先順の `AVCaptureDevice.DeviceType` を渡し、`CameraDeviceDiscovery` が `AVCaptureDevice.DiscoverySession` で実在 device を解決します。

```swift
let request = CameraDeviceRequest(
    position: .back,
    preferredDeviceTypes: [
        .builtInUltraWideCamera,
        .builtInWideAngleCamera,
    ]
)
try await camera.start(request: request)
```

インカメラも同じです。TrueDepth が利用可能なら優先できます。

```swift
let request = CameraDeviceRequest(
    position: .front,
    preferredDeviceTypes: [
        .builtInTrueDepthCamera,
        .builtInWideAngleCamera,
    ]
)
```

これは capability-based programming であり、機種別 production branch ではありません。

`CameraCaptureSession.activeCaptureDevice` は focus、exposure、zoom など通常の device configuration に使えます。capture graph の変更は `CameraCaptureSession` が所有します。

## Depth geometry

0.1.1 では `CameraDepthFrameGeometry`、`CameraDepthFrame`、`CameraSynchronizedFrame` を追加し、depth-aware pipeline で使う型付き geometry / identity の語彙を用意します。また device/session metadata に `supportsDepthData` を追加します。

`AVCaptureDepthDataOutput` の構成と RGB/depth synchronization 自体はまだ package が所有しません。アプリの video resolution / FPS policy を暗黙に変更しない設計で `AVCaptureDataOutputSynchronizer` を統合することを near-term item とします。

## ARKit adapter

CameraGeometryKit は `ARSession`、tracking configuration、anchor、raycast、world mapping、scene reconstruction を所有しません。

`ARKitFrameAdapter` は `ARFrame` の camera/depth data と canonical image space の boundary だけを担当します。frame geometry は raw captured-image pixel coordinates の `ARCamera.intrinsics` を保持し、向きと mapping の source には ARKit の `displayTransform(for:viewportSize:)` を使います。

```swift
let cameraFrame = ARKitFrameAdapter.cameraFrame(
    from: frame,
    interfaceOrientation: interfaceOrientation
)

let canonical = cameraFrame.geometry.canonicalPoint(
    fromARKitNormalized: normalizedImagePoint
)
```

ARKit の display transform には front-camera presentation mirror が含まれる場合があります。adapter は canonical space に変換するときその reflection を除去し、upright / non-mirrored を維持します。

`capturedDepthData`、`sceneDepth`、`smoothedSceneDepth` を depth adapter から取得できます。

```swift
let depth = ARKitFrameAdapter.depthFrame(
    from: frame,
    source: .sceneDepth,
    interfaceOrientation: interfaceOrientation
)
```

feature availability は app/configuration が capability check し、機種名から推測しません。
