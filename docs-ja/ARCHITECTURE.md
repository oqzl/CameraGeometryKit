# Architecture

CameraGeometryKit は1つの canonical image space を中心に、framework boundary ごとの変換を明示する基盤です。

共通化するのは geometry、frame metadata、rotation/mirroring policy、薄い `CameraCaptureSession`、bounded な Swift-native Vision execution、stale-result suppression、diagnostics までです。

`CameraCaptureSession` は authorization、単一 video input、frame/photo output、直列化された start/stop と camera switch、capture rotation、canonical non-mirroring に加え、任意の単一 audio input とアプリ所有 `AVCaptureMovieFileOutput` を安全に接続する最小の入口を担当します。製品UI、recording の開始/停止とファイル policy、photo result policy、effects、workflow はアプリ側に残します。

`CameraVisionWorker` が live analysis の境界です。`ImageProcessingRequest` または任意の async operation を受け取り、1 in-flight、最新1 pending frame、generation-safe MainActor delivery を保証します。

pre-iOS-18 Vision API の互換レイヤーは持ちません。

万能 `CameraManager` や汎用 runtime pipeline graph にはしません。
