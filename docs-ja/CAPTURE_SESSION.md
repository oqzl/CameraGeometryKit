# Capture Session

`CameraCaptureSession` は、CameraGeometryKit が使う可変な AVFoundation capture graph を所有する薄い wrapper です。

担当するのは camera authorization、単一の video input、`CameraFrameStream.output`、`AVCapturePhotoOutput`、直列化された start/stop と camera switch、capture rotation、canonical non-mirroring に加え、任意の単一 audio input とアプリ所有 `AVCaptureMovieFileOutput` を接続する最小の入口までです。

camera chrome、preview layout、focus/exposure UX、photo settings/delegate、movie recording の開始/停止、temporary file / persistence policy、effects、Vision model selection、製品ワークフローは担当しません。万能 `CameraManager` にはしません。

`AVCaptureSession` の可変操作はすべて private serial queue 上で行います。`startRunning()` / `stopRunning()` も MainActor では実行しません。

公開している `captureSession` は `AVCaptureVideoPreviewLayer` の接続と参照用です。inputs / outputs / preset / running state を外側から変更してはいけません。

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

## Optional audio / movie output

`AVCaptureMovieFileOutput` を使うアプリでも、output object と recording lifecycle はアプリ側に残します。`CameraCaptureSession` が担当するのは、同じ serial queue 上で capture graph を変更し、movie connection に capture rotation と canonical non-mirroring を適用するところまでです。

microphone authorization と device 選択もアプリ側の policy です。認可後、選択した audio device とアプリ所有 movie output を wrapper 経由で接続します。

```swift
let movieOutput = AVCaptureMovieFileOutput()
let microphone = AVCaptureDevice.default(for: .audio)!

try await camera.setAudioCaptureDevice(microphone)
try await camera.setMovieFileOutput(movieOutput, sessionPreset: .high)

movieOutput.startRecording(to: url, recordingDelegate: delegate)
```

photo mode に戻す場合も、アプリが capture graph を直接変更せずに movie output と audio input を外せます。

```swift
try await camera.setMovieFileOutput(nil, sessionPreset: .photo)
try await camera.setAudioCaptureDevice(nil)
```

これらのAPIは microphone permission request、recording format 選択、録画開始/停止、temporary file 作成、media 保存を行いません。それらはアプリ側の責務です。

camera switch では semantic な解析処理を invalidate し、切替完了後に preview rotation も作り直します。

```swift
vision.invalidate()
try await camera.switchCamera()
let previewRotation = camera.makePreviewRotation(previewLayer: previewLayer)
```

wrapper は新しい物理 camera 用の capture `RotationCoordinator` を再生成し、frame の camera identity、capture rotation、non-mirroring を frame / photo / 接続済み movie connection に再適用します。Front/Back 固定角度表や機種別 angle hack は使いません。
