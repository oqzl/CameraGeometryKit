# Roadmap

CameraGeometryKit は、実際の camera app で共有が必要になった範囲だけ育てます。

## 実装済み

- iOS 18+ / Swift 6
- canonical point / rect
- crop / fit / fill mapping
- UIImage canonicalization
- 薄い `CameraCaptureSession`
- `AVCaptureDevice.DiscoverySession` による device selection
- device type の優先順と front/back switching
- bounded newest-frame stream
- optional RGB + depth synchronization
- depth frame geometry metadata
- frame ID / rotation / mirroring
- Swift-native Vision geometry / `CameraVisionWorker`
- ARKit captured-image / canonical geometry adapter
- diagnostics
- 英日ドキュメント
- 実機 validation structure

## 0.1.1 validation

Tag 前に wide-angle path と、利用可能な TrueDepth / LiDAR 等の depth-capable hardware で実機確認します。結果は validation evidence として残し、機種別 production branch にはしません。

## 次候補

- CameraGeometryLab
- photo-output geometry helper
- `AVCaptureVideoPreviewLayer` canonical overlay mapping
- RGB + depth + mask + Vision 用 Accepted Frame token
- MultiCam stream identity
- metadata-output geometry adapter
- custom Metal preview mapping
- `AVAssetWriter` orientation helper
- diagnostics export

## Non-goals

- effects / editor UI
- generic processing graph
- universal camera product state machine
- ARSession / world tracking ownership
- backward compatibility
- old Vision request-handler path
- model-specific rotation / camera-selection patch
