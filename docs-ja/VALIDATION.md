# Device Validation

## なぜリポジトリに残すか

Camera の sensor orientation、利用可能 camera、mirror default、supported rotation angle、depth capability、性能は実機差があります。

対応は「機種別 branch」ではなく「機種別 evidence」です。

```text
docs/validation/<device>/
docs-ja/validation/<device>/
```

例:

```text
docs-ja/validation/iPhone17/
```

OS更新ごとに run を残し、古い結果を上書きしません。

## 必須 metadata

marketing device name、hardware identifier、iOS version/build、package/app commit SHA、Xcode version、rotation-lock state、camera device type/position、必要な active format/FPS を記録します。

## 最低 rotation matrix

各 camera で portrait、landscape left/right、必要なら upside down、rotation lock OFF/ON を確認します。

各姿勢で preview angle、capture angle、VideoDataOutput connection angle、preview/analysis mirror、delivered dimensions、preview/canonical frozen frame/saved photo の uprightness、Vision overlay alignment を記録します。

## Camera matrix

hardware が持つ範囲で back wide、ultra wide、telephoto、front、TrueDepth、virtual camera、利用する MultiCam combination を確認します。存在しない capability は unavailable と記録します。

## Timing / lifecycle

launch直後、posture change直後、front/back switch直後、rapid switch、background→foreground、session interruption/recovery、Vision実行中settings change、screen departureを確認します。

switch/change 後に旧 generation result が出ないことを確認します。

## Preview / touch

canonical custom preview では center tap→`(0.5, 0.5)`、四隅 marker、aspect-fit letterbox reject、aspect-fill mapping、front mirror時の canonical x 不変を確認します。

`AVCaptureVideoPreviewLayer` focus/exposure は AVFoundation conversion を使い、`CaptureDevicePoint` を canonical と誤解しません。

## Vision

source `CameraFrameID`、result frame ID、canonical bbox/point、全 posture alignment、camera switch 後、front mirror 時、invalidation 後 stale result の有無を記録します。

## Performance

capture FPS、analyzer latency、AVFoundation dropped frames、newest-buffer replacement、UI responsiveness、必要なら thermal behavior を記録します。負荷時の期待動作は queue growth ではなく frame drop です。

## Failure evidence

```text
Device: iPhone 17 Pro / iPhone18,3
OS: iOS 26.6
Camera: front
Posture: landscape left
Rotation lock: on

Preview angle: ...
Capture angle: ...
Analysis connection angle: ...
Preview mirrored: ...
Analysis mirrored: ...
Frame dimensions: ...
Frame ID: ...
Vision result frame ID: ...

Observed:
Expected:
Screenshot/video:
```

「Front cameraが90°ズレる」だけでは情報不足です。

## Production code への昇格ルール

機種別観測から generic code を変えるのは、generic invariant が誤っているか Apple API が capability-specific branch を要求するときだけです。validation folder があること自体を理由に device branch を作りません。
