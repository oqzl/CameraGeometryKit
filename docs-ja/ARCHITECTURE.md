# Architecture

CameraGeometryKit は1つの canonical image space を中心に、framework boundary ごとの変換を明示する基盤です。

共通化するのは geometry、frame metadata、capability-based camera discovery、rotation/mirroring policy、薄い `CameraCaptureSession`、optional synchronized depth delivery、bounded な Swift-native Vision execution、stale-result suppression、diagnostics までです。

`CameraCaptureSession` は authorization、単一 video input、単一 color `AVCaptureVideoDataOutput`、optional synchronized depth output、photo output、start/stop、camera switch、capture rotation、canonical non-mirroring を担当します。Depth は opt-in で `AVCaptureDataOutputSynchronizer` を使いますが、万能 camera manager にはしません。

`CameraFrameStream` は video-only / depth mode のどちらでも単一の color-frame source です。Depth 有効時は `CameraSynchronizedFrameStream` が同じ color output と `AVCaptureDepthDataOutput` を同期し、`CameraSynchronizedFrame` を出力します。その color frame は `CameraFrameStream` が流すものと同じ `CameraFrame` identity で、time-matched depth と後段 derivative の基準にします。

Camera selection は iPhone 機種名ではなく AVFoundation の device type / capability に基づきます。Depth-enabled session は depth-capable device を要求し、depth format は選択 device の current active video format に互換なものだけを使います。color capture policy を暗黙に別のものへ変更しません。

`CameraVisionWorker` が live analysis の境界です。`ImageProcessingRequest` または任意の async operation を受け取り、1 in-flight、最新1 pending frame、generation-safe MainActor delivery を保証します。

製品UI、recording policy、effects、storage、semantic model、workflow はアプリ側に残します。pre-iOS-18 Vision API の互換レイヤーは持ちません。
