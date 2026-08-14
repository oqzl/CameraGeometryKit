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

## Synchronized depth capture

0.1.1 では `CameraDepthFrameGeometry`、`CameraDepthFrame`、`CameraSynchronizedFrame` に加え、`AVCaptureDepthDataOutput` と video output の同期 capture を扱います。

Depth は opt-in です。

```swift
let camera = CameraCaptureSession(
    depthConfiguration: CameraDepthCaptureConfiguration()
)

try await camera.start(
    request: CameraDeviceRequest(
        position: .front,
        preferredDeviceTypes: [
            .builtInTrueDepthCamera,
            .builtInWideAngleCamera,
        ]
    )
)

if let stream = camera.synchronizedFrameStream {
    for await frame in stream.frames {
        let color = frame.color
        let depth = frame.depth
    }
}
```

Depth 有効時は `AVCaptureDataOutputSynchronizer` で同時刻の video / depth sample を一つの callback にまとめます。Depth sample だけ drop した場合は `CameraSynchronizedFrame.depth == nil` とし、color frame は有効なまま `CameraFrameID` を保持します。

Session は color 側の video format を勝手に変更しません。指定された `sessionPreset` で device の active video format を確定したあと、その `supportedDepthDataFormats` から要求された depth data type のうち最大解像度を選びます。現在の active video format で要求した depth type が利用できなければ明示的に configuration error にします。

既定の depth type 優先順は `DepthFloat32`、`DepthFloat16` です。Filtering は既定で off で、`CameraDepthCaptureConfiguration` から変更できます。

通常の video-only mode では従来どおり `camera.frameStream.frames` を使います。Depth mode では `camera.synchronizedFrameStream?.frames` を color/depth analysis の source にします。

Video と depth の connection には同じ capture rotation と canonical non-mirroring policy を適用します。ただし RGB と depth の pixel dimensions は一致するとは限らないため、各 frame の geometry metadata を使います。

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
