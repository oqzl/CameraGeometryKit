# Capture Session

`CameraCaptureSession` は、CameraGeometryKit が使う可変な AVFoundation capture graph を所有する薄い wrapper です。

担当するのは camera authorization、単一の video input、video-only または synchronized video/depth frame output、`AVCapturePhotoOutput`、直列化された start/stop と camera switch、capture rotation、canonical non-mirroring までです。

camera chrome、preview layout、focus/exposure UX、photo settings/delegate、movie recording、effects、Vision model selection、製品ワークフローは担当しません。万能 `CameraManager` にはしません。

`AVCaptureSession` の可変操作はすべて private serial queue 上で行います。`startRunning()` / `stopRunning()` も MainActor では実行しません。

公開している `captureSession` は `AVCaptureVideoPreviewLayer` の接続と参照用です。inputs / outputs / running state を外側から変更してはいけません。

## Video-only capture

```swift
let camera = CameraCaptureSession()
try await camera.start(position: .back)

for await frame in camera.frameStream.frames {
    // CameraFrame
}
```

## Synchronized depth capture

Depth は Session 作成時に opt-in します。

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
        // CameraSynchronizedFrame
    }
}
```

指定された `sessionPreset` で active video format を確定してから、その format の `supportedDepthDataFormats` だけを候補に depth type を選びます。Color format を暗黙に別のものへ変更しません。Video / depth outputs は `AVCaptureDataOutputSynchronizer` で同期 delivery します。

Depth を要求したのに選択 camera の active video format で要求した depth type が利用できない場合、Session configuration は明示的に失敗します。

## Preview / photo

```swift
let previewLayer = AVCaptureVideoPreviewLayer(session: camera.captureSession)
let previewRotation = camera.makePreviewRotation(previewLayer: previewLayer)
```

写真撮影直前には capture angle を再同期します。

```swift
try await camera.preparePhotoCapture()
camera.photoOutput.capturePhoto(with: settings, delegate: delegate)
```

`AVCapturePhotoSettings` と結果/delegate policy はアプリ側の責務です。

camera switch では semantic な解析処理を invalidate し、切替完了後に preview rotation も作り直します。

```swift
await vision.invalidate()
try await camera.switchCamera()
let previewRotation = camera.makePreviewRotation(previewLayer: previewLayer)
```

Depth mode で切替先 camera の active video format が要求した depth type を提供できない場合は切替に失敗し、旧 input を復元します。成功時は新しい物理 camera 用の `RotationCoordinator` を再生成し、video / depth / photo connection に capture rotation と non-mirroring policy を再適用します。Front/Back 固定角度表や機種別 angle hack は使いません。
