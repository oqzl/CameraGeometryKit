# Prohibited Patterns

以下は package invariant として扱います。

1. **機種別 rotation hack を入れない。** 機種差は validation record に残し、一般ロジックを直す。
2. **Front / Back 固定角度表を作らない。** camera position は stable な native rotation を意味しない。
3. **UI orientation を camera resolver にしない。** `UIDeviceOrientation` や interface orientation から capture rotation を逆算しない。
4. **deprecated orientation API を使わない。** `AVCaptureVideoOrientation`、`AVCaptureConnection.videoOrientation`、`isVideoOrientationSupported` は使わず、`AVCaptureDevice.RotationCoordinator`、`videoRotationAngle`、`isVideoRotationAngleSupported(_:)` を使う。
5. **Preview angle と Capture angle を混ぜない。** 別の責務・別の値として扱う。
6. **二重回転しない。** `AVCaptureVideoDataOutput` connection がすでに回転した frame を後段でもう一度回さない。
7. **rotation と mirroring を混ぜない。** Front preview の鏡像表示は analysis / 保存物の identity を変えない。
8. **untyped coordinate soup を作らない。** Screen、Vision、crop、capture-device、canonical は明示的な型・変換境界を通す。
9. **暗黙 clamp をしない。** crop 外 point は clipping が明示的に必要になるまで crop 外のまま保持する。
10. **無制限 frame queue を作らない。** live processing は obsolete work を溜めない。
11. **capture callback / MainActor で重い処理をしない。** callback は hand-off、MainActor は UI state を担当する。
12. **Cancellation だけで stale result 対策完了としない。** generation identity で旧結果の publish を防ぐ。
13. **alignment が必要な派生データで frame ID を混ぜない。** RGB / mask / depth / Vision result は source `CameraFrameID` を保持する。
14. **camera switch 後に old RotationCoordinator を使わない。** coordinator は1つの `AVCaptureDevice` に所属する。
15. **product code から `CameraCaptureSession.captureSession` を変更しない。** capture graph mutation は wrapper 内で直列化する。
16. **pre-iOS-18 Vision compatibility layer を作らない。** Swift-native request / observation と `async` / `await` を使い、旧 request-handler 実行を戻さない。
17. **Swift-native Vision geometry を崩さない。** `NormalizedPoint` / `NormalizedRect` は `VisionGeometry` で canonical に変換するまで Vision の型として扱う。
18. **live Vision の freshness guarantee を迂回しない。** `CameraVisionWorker` または同等実装で bounded work、latest pending frame、frame identity、invalidation cancellation、stale-delivery suppression を守る。
19. **Simulator だけで検証完了にしない。** rotation、front mirror、TrueDepth/depth、機種差は実機で検証し `docs-ja/validation/<device>/` に残す。
