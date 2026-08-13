# Camera Rotation

## 方針

Camera rotation は UI orientation ではなく camera geometry です。

`AVCaptureDevice.RotationCoordinator` を唯一の authoritative resolver とします。Preview と Capture は別の問題なので、別の角度を使います。

この文書には CamLab で蓄積した実機上の知見を吸収し、CameraGeometryKit 単体で方針が完結するよう再整理しています。主要な設計根拠は CamLab の [`docs/iOS_Camera_Rotate.md`](https://github.com/oqzl/CamLab/blob/main/docs/iOS_Camera_Rotate.md) です。CamLab 側を歴史的・アプリ実装由来の evidence、本書をそこから一般化した CameraGeometryKit の再利用規約として扱います。

## 分離すべき値

| 関心事 | Source / API | 意味 |
|---|---|---|
| App UI orientation policy | UIKit / SwiftUI | camera chrome を回すか |
| 端末物理姿勢 | `UIDeviceOrientation` | UI補助・debug用途 |
| Preview rotation | `videoRotationAngleForHorizonLevelPreview` | gravity に対して level な preview |
| Capture rotation | `videoRotationAngleForHorizonLevelCapture` | gravity に対して level な撮影物 |
| VideoDataOutput applied rotation | `AVCaptureConnection.videoRotationAngle` | 配信 frame にすでに適用された物理回転 |
| Mirroring | `isVideoMirrored` | rotation と独立した左右反転 |
| Writer transform | `AVAssetWriterInput.transform` | custom recording の playback orientation metadata |

これらを1個の `orientation` 変数へ潰してはいけません。

## RotationCoordinator が source of truth

```swift
let rotation = CameraRotation(device: device, previewLayer: previewLayer)
rotation.applyPreviewAngle(to: previewConnection)
rotation.applyCaptureAngle(to: captureConnection)
```

カメラ切替時は新しい `AVCaptureDevice` 用に coordinator を再生成します。

## Preview と Capture は別

camera chrome が portrait-native のままでも preview/capture の向きは物理カメラ姿勢に応じて変わり得ます。UI は camera orientation sensor ではありません。

interface orientation から capture angle を作る、preview angle を capture に流用する、capture angle で chrome を回す、といった実装は禁止です。

## `AVCaptureVideoDataOutput` は frame 自体を回転する

VideoDataOutput connection に `videoRotationAngle` を設定すると、AVFoundation は配信する pixel buffer 自体を回転します。

```text
Camera sensor
    ↓
AVCaptureVideoDataOutput connection rotation
    ↓
CameraFrame.pixelBuffer
    = すでに upright canonical frame
```

`CameraFrame.geometry.appliedVideoRotationAngle` は「すでに何が起きたか」の diagnostic metadata です。後段で同じ90°補正を再適用しません。

## VideoDataOutput を使う custom preview

custom preview の表示目的だけで VideoDataOutput connection rotation を変更しません。reconfiguration は frame delivery を途切れさせ得て、毎 frame rotation は memory/energy cost を持ちます。presentation を preview angle で回す設計を優先します。

canonical analysis stream は別用途です。Vision / image processing の意味を単純化するため、意図的に upright frame を使います。性能が問題になった場合は計測して raw path を別に設け、frame semantics を黙って変えません。

## Photo

capture 前に photo output connection へ capture angle を設定し、その後 Viewer で固定 EXIF / UIImage / Core Image / SwiftUI 補正を重ねません。

## MovieFileOutput

録画開始前に capture angle を設定します。録画開始時の angle を固定し、preview は追従可、次回録画で再解決する方針を基本とします。

## `AVCaptureVideoDataOutput + AVAssetWriter`

custom recording では orientation metadata で十分なら毎 frame 物理回転しません。

```text
sensor-native / unrotated sample buffer
        +
resolved capture angle
        ↓
AVAssetWriterInput.transform
        ↓
movie track metadata
```

Writer 用 connection を 0° とし、writer transform が rotation を単独所有する形が分かりやすいです。Writer が `UIDeviceOrientation`、`UIWindowScene`、front/back、device model を見て推測してはいけません。

## Front camera / 新機種

sensor-native orientation は camera module / generation で異なり得ます。`if deviceModel.contains("iPhone17") { angle += 90 }` のような補正は禁止です。

機種固有に見える不具合は `docs-ja/validation/<device>/` に angle と出力を記録し、誤った一般仮定を探します。

## Mirroring は別

| 対象 | Back | Front |
|---|---:|---:|
| Preview | non-mirror | mirror |
| Analysis frame | non-mirror | non-mirror |
| Saved photo | non-mirror | 原則 non-mirror |
| Saved video | non-mirror | 原則 non-mirror |

mirror を rotation-angle logic に埋め込みません。

## Camera switch

1. old coordinator の observe を止める
2. serialized session context で input を切替
3. new device 用 coordinator を生成
4. preview angle 適用
5. capture/analysis angle 適用
6. preview mirror policy 適用
7. analysis/save mirror policy 適用
8. old Vision/configuration generation を invalidate
9. diagnostics 更新

old coordinator は再利用しません。

## UI orientation lock

camera chrome を portrait-native に固定する製品設計はあり得ます。その場合でも supported interface orientation policy / scene geometry は UI の責務で、camera preview/capture rotation と独立です。

`requestGeometryUpdate` だけを lock とみなしたり、UI orientation を camera angle へ変換したりしません。CameraGeometryKit は product UI orientation policy 自体は所有しません。

## プロジェクト由来資料

- [CamLab: `docs/iOS_Camera_Rotate.md`](https://github.com/oqzl/CamLab/blob/main/docs/iOS_Camera_Rotate.md) — 本パッケージが一般化した、アプリレベルの詳細な回転・向き補正設計。
- [CamLab: `docs/CAMERA_FRAME_ORIENTATION.md`](https://github.com/oqzl/CamLab/blob/main/docs/CAMERA_FRAME_ORIENTATION.md) — `AVCaptureVideoDataOutput` の適用済み回転と downstream double rotation を防ぐ実戦上の規約。

## Apple 公式資料

- [AVCaptureDevice.RotationCoordinator](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator)
- [Preview rotation angle](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator/videorotationangleforhorizonlevelpreview)
- [Capture rotation angle](https://developer.apple.com/documentation/avfoundation/avcapturedevice/rotationcoordinator/videorotationangleforhorizonlevelcapture)
- [AVCaptureConnection.videoRotationAngle](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/videorotationangle)
- [AVAssetWriterInput.transform](https://developer.apple.com/documentation/avfoundation/avassetwriterinput/transform)
- [WWDC23: Support external cameras in your iPadOS app](https://developer.apple.com/videos/play/wwdc2023/10106/)
