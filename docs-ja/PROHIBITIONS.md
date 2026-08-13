# Prohibited Patterns

以下は、実際には座標・回転・スケジューリングの誤りなのに「この機種だけ変」と見えやすい典型パターンです。この文書は package contract の一部として扱います。

## 1. 機種別 rotation hack

```swift
if model == "iPhone17,1" {
    angle += 90
}
```

禁止です。まず device validation に failure を記録し、`RotationCoordinator` と connection state を確認し、一般ロジックの誤りを直します。

## 2. Front / Back 固定角度表

`device.position == .front ? 270 : 90` のような表は禁止。camera module の native orientation は単純な front/back rule ではありません。

## 3. UI orientation を camera angle にする

`windowScene.interfaceOrientation` から capture angle を決めません。UI orientation と camera physical orientation は別 domain です。

## 4. `UIDeviceOrientation` を camera resolver にする

端末姿勢から camera rotation を決めません。`RotationCoordinator` を使います。

## 5. Preview angle を Capture に流用

別値です。代用しません。

## 6. Capture angle で camera chrome を回す

camera chrome は product UI。capture angle の変化で reflow / rotation しません。

## 7. width / height から orientation 推測

禁止。sensor-native orientation と connection rotation は camera ごとに異なります。

## 8. 二重回転

VideoDataOutput connection が frame を物理回転済みなら、Core Image、Viewer、Export で同じ補正を再適用しません。

## 9. Writer が orientation を独自解決

`AVAssetWriter` が `UIDevice`、`UIWindowScene`、front/back、機種名を見て向きを推測しません。resolved capture orientation を受け取るだけです。

## 10. Writer の全 frame を無意味に物理回転

`AVCaptureVideoDataOutput + AVAssetWriter` では metadata transform で済むなら `AVAssetWriterInput.transform` を使います。

## 11. Mirroring を rotation に埋め込む

mirror は別 policy。front preview が鏡像だからといって回転角を足して直しません。

## 12. Front camera は常に mirror 保存

mirror preview と media identity は別です。

## 13. Untyped point soup

Vision point、screen point、crop-relative、image normalized を全部同じ `CGPoint` として流しません。意味型と explicit mapping を使います。

## 14. Raw Vision 座標を UI state に保存

Vision origin は canonical と異なります。Vision 境界で変換します。

## 15. Focus point を canonical として保存

`captureDevicePointConverted` の結果は unrotated capture-device point-of-interest space。`CaptureDevicePoint` のまま扱います。

## 16. 暗黙 clamp

crop 外 point を crop edge に clamp すると意味が変わります。明示的な境界まで out-of-range 値を保持します。

## 17. 無制限 frame queue

camera frame を全部 Vision / image processing queue に積みません。obsolete work は捨てます。

## 18. Capture callback で重い処理

delegate callback では hand-off だけ。Vision、Core Image render、contour、mask scan、file I/O は実行しません。

## 19. MainActor で重い処理

MainActor は UI state の所有者であり image processor ではありません。

## 20. Cancellation だけで stale result を防ぐ

cancel 後でも race して完了することがあります。publish 直前に generation/config identity を確認します。

## 21. Camera switch 後に old result を表示

camera switch は device、RotationCoordinator、mirror policy、processing generation を変えます。old camera の結果を new camera UI へ反映しません。

## 22. Old RotationCoordinator 再利用

coordinator は `AVCaptureDevice` に紐づきます。active camera 変更時に作り直します。

## 23. 別 frame 由来の派生データを混ぜる

alignment が重要なら RGB、mask、depth、Vision result の `CameraFrameID` を揃えます。

## 24. 必須同期データ欠損時の silent fallback

Depth 等が必須なら、欠損時に無関係な current RGB へ黙って fallback しません。最後の valid synchronized state を保つか明示的 unavailable にします。

## 25. Simulatorだけで検証完了

front camera、TrueDepth、rotation、mirror、機種固有 camera 挙動は実機で確認し、`docs-ja/validation/<device>/` に記録します。
