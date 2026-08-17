# Device Selection / Depth Geometry

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

Live depth が必須なら `requiresDepthData` を指定します。Discovery は、depth data と組み合わせ可能な video format を1つ以上持つ device だけを残します。実際の active video/depth format の組み合わせは、session preset によって active video format が決まったあとで改めて検証します。

```swift
let request = CameraDeviceRequest(
    position: .front,
    preferredDeviceTypes: [
        .builtInTrueDepthCamera,
        .builtInWideAngleCamera,
    ],
    requiresDepthData: true
)
```

`depthConfiguration` 付きで作成した `CameraCaptureSession` は常に depth requirement を強制します。`start(position:)`、`setCameraPosition(_:)`、`switchCamera()` の convenience 経路では、実行時に発見した device type から depth-capable device を探します。明示的な `CameraDeviceRequest` を渡した場合は、指定した device type の優先順と `uniqueID` を維持したまま depth requirement を追加します。

これは capability-based programming であり、機種別 production branch ではありません。

`CameraCaptureSession.activeCaptureDevice` は focus、exposure、zoom など通常の device configuration に使えます。capture graph の変更は `CameraCaptureSession` が所有します。

## Synchronized depth capture

0.1.1 では `CameraDepthFrameGeometry`、`CameraDepthFrame`、`CameraSynchronizedFrame` に加え、`AVCaptureDepthDataOutput` と video output の同期 capture を扱います。

Depth は opt-in です。

```swift
let camera = CameraCaptureSession(
    depthConfiguration: CameraDepthCaptureConfiguration()
)

try await camera.start(position: .front)

if let stream = camera.synchronizedFrameStream {
    for await frame in stream.frames {
        let color = frame.color
        let depth = frame.depth
    }
}
```

Depth 有効時は `AVCaptureDataOutputSynchronizer` で同時刻の video / depth sample を一つの callback にまとめます。Depth sample だけ drop した場合は `CameraSynchronizedFrame.depth == nil` とし、color frame は有効なまま `CameraFrameID` を保持します。

Synchronized path は video-only capture と同じ `CameraFrameStream.output` を再利用します。そのため depth を有効にしても `camera.frameStream.frames` は color-only source として有効で、指定済みの color pixel format も維持されます。さらに `CameraSynchronizedFrame.color` と同じ `CameraFrame` identity を流します。Depth との時刻同期が必要な consumer だけ `synchronizedFrameStream.frames` を使います。

Session は color 側の video format を勝手に変更しません。指定された `sessionPreset` で device の active video format を確定したあと、その `supportedDepthDataFormats` から要求された depth data type のうち最大解像度を選びます。現在の active video format で要求した depth type が利用できなければ明示的に configuration error にします。

既定の depth type 優先順は `DepthFloat32`、`DepthFloat16` です。Filtering は既定で off で、`CameraDepthCaptureConfiguration` から変更できます。

`CameraSynchronizedFrameStream.statistics()` では synchronized delivery 数、color sample drop、depth sample drop、latest-frame buffer での置換数を取得できます。`CameraFrameStream.statistics()` も従来どおり color delivery の統計を返します。

Video と depth の connection には同じ capture rotation と canonical non-mirroring policy を適用します。ただし RGB と depth の pixel dimensions は一致するとは限らないため、各 frame の geometry metadata を使います。
