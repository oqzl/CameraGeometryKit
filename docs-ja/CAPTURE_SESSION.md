# Capture Session

`CameraCaptureSession` は、CameraGeometryKit が使う可変な AVFoundation capture graph を所有する薄い wrapper です。

担当するのは camera authorization、単一の video input、`CameraFrameStream.output`、`AVCapturePhotoOutput`、直列化された start/stop と camera switch、capture rotation、canonical non-mirroring までです。

camera chrome、preview layout、focus/exposure UX、photo settings/delegate、movie recording、effects、Vision model selection、製品ワークフローは担当しません。万能 `CameraManager` にはしません。

`AVCaptureSession` の可変操作はすべて private serial queue 上で行います。`startRunning()` / `stopRunning()` も MainActor では実行しません。

公開している `captureSession` は `AVCaptureVideoPreviewLayer` の接続と参照用です。inputs / outputs / running state を外側から変更してはいけません。

```swift
let camera = CameraCaptureSession()
try await camera.start(position: .back)

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
vision.invalidate()
try await camera.switchCamera()
let previewRotation = camera.makePreviewRotation(previewLayer: previewLayer)
```

wrapper は新しい物理 camera 用の capture `RotationCoordinator` を再生成し、frame の camera identity、capture rotation、non-mirroring を再適用します。Front/Back 固定角度表や機種別 angle hack は使いません。
