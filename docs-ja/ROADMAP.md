# Roadmap

CameraGeometryKit は、実際の camera app で shared semantics が繰り返し必要になった範囲だけ育てます。

## 実装済み foundation

- iOS 18+ / Swift 6
- canonical point / rect
- source / crop mapping
- aspect-fit / aspect-fill mapping
- UIImage canonicalization
- bounded newest-frame stream
- frame ID と geometry snapshot
- RotationCoordinator wrapper
- preview / analysis mirror policy 分離
- Vision coordinate conversion
- `WorkGeneration` stale-result guard
- diagnostics
- 英日ドキュメント
- 機種別 validation structure

## Near-term: CameraGeometryLab

専用 verification app を作ります。front/back switch、各 rotation angle、mirror flags、canonical grid、tap marker、geometry verification rectangle、frozen canonical frame、fit/fill switch、frame ID、dropped/replaced counters、saved-photo replay を確認できるようにします。

## Real-device matrix

まず `docs-ja/validation/iPhone17/` を埋め、使える実機に応じて folder を追加します。OS version ごとの evidence を残し、model-specific production branch にはしません。

## 実需が繰り返したら追加する候補

- photo-output geometry helper
- `AVCaptureVideoPreviewLayer` への canonical overlay mapping
- RGB + depth + mask 用 synchronization token
- depth-frame geometry
- MultiCam per-camera rotation snapshot
- metadata-output geometry adapter
- custom Metal preview mapping
- `AVAssetWriter` orientation helper
- diagnostics export

## 明示的 non-goals

- effects library
- editor UI
- generic processing graph
- universal camera product state machine
- backward-compatibility layer
- model-specific rotation patch
