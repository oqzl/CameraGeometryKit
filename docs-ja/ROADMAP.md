# Roadmap

CameraGeometryKit は、実際の camera app で shared semantics が繰り返し必要になった範囲だけ育てます。

## 実装済み foundation

- iOS 18+ / Swift 6
- canonical point / rect
- source / crop mapping
- aspect-fit / aspect-fill mapping
- UIImage canonicalization
- 薄い `CameraCaptureSession`
- capability-based な `AVCaptureDevice.DiscoverySession` selection
- bounded newest-frame stream
- typed depth-frame geometry / `CameraSynchronizedFrame`
- `AVCaptureDataOutputSynchronizer` による optional video + depth 同期 capture
- frame ID と geometry snapshot
- video/depth capture connection の RotationCoordinator policy
- preview / analysis mirror policy 分離
- Swift-native Vision `NormalizedPoint` / `NormalizedRect` conversion
- actor ベース `CameraVisionWorker` と latest-frame / stale-delivery guarantee
- diagnostics
- 英日ドキュメント
- 機種別 validation structure

## 0.1.1 validation

0.1.1 の tag 前に、video-only path と synchronized depth path を実機で確認します。利用可能な front TrueDepth / rear depth-capable hardware について、rotation、mirroring、RGB/depth dimensions、camera switch 失敗時の rollback を記録します。

結果は `docs-ja/validation/<device>/` に evidence として残し、model-specific production branch にはしません。

## Near-term: CameraGeometryLab

専用 verification app を作ります。device type switching、preview/capture/depth angles、mirror flags、canonical grid、tap marker、frozen canonical frame、fit/fill switch、frame ID、depth availability、dropped/replaced counters を確認できるようにします。

## 実需が繰り返したら追加する候補

- photo-output geometry helper
- `AVCaptureVideoPreviewLayer` への canonical overlay mapping
- RGB + depth + mask + Vision derivatives 用の一般化した Accepted Frame token
- MultiCam stream identity / per-camera rotation snapshot
- metadata-output geometry adapter
- custom Metal preview mapping
- `AVAssetWriter` orientation helper
- diagnostics export

## 明示的 non-goals

- effects library
- editor UI
- generic processing graph
- universal camera product state machine
- ARSession / world tracking ownership
- backward-compatibility layer
- pre-iOS-18 Vision request-handler compatibility
- model-specific rotation / camera-selection patch
