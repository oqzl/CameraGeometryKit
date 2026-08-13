# Architecture

CameraGeometryKit は1つの canonical image space を中心に、framework boundary ごとの変換を明示する基盤です。

共通化するのは geometry、frame metadata、rotation/mirroring policy、薄い `CameraCaptureSession`、bounded な Swift-native Vision execution、stale-result suppression、diagnostics までです。

`CameraCaptureSession` は authorization、単一 video input、frame/photo output、start/stop、camera switch、capture rotation、canonical non-mirroring を担当します。製品UI、recording、photo result policy、effects、workflow はアプリ側に残します。

`CameraVisionWorker` が live analysis の境界です。`ImageProcessingRequest` または任意の async operation を受け取り、1 in-flight、最新1 pending frame、generation-safe MainActor delivery を保証します。

pre-iOS-18 Vision API の互換レイヤーは持ちません。

万能 `CameraManager` や汎用 runtime pipeline graph にはしません。
