# Architecture

CameraGeometryKit は1つの canonical image space を中心に、framework boundary ごとの変換を明示する基盤です。

共通化するのは geometry、frame metadata、capability-based camera discovery、rotation/mirroring policy、薄い `CameraCaptureSession`、optional synchronized depth delivery、bounded な Swift-native Vision execution、stale-result suppression、ARKit image/depth adapter、diagnostics までです。

`CameraCaptureSession` は authorization、単一 video input、video-only または synchronized video/depth frame outputs、photo output、start/stop、camera switch、capture rotation、canonical non-mirroring を担当します。Depth は opt-in で `AVCaptureDataOutputSynchronizer` を使いますが、万能 camera manager にはしません。

Video-only path は既存の `CameraFrameStream` を維持します。Depth path は `CameraSynchronizedFrame` を出力し、その color `CameraFrame` の identity を time-matched depth と後段 derivative の基準にします。

Camera selection は iPhone 機種名ではなく AVFoundation の device type / capability に基づきます。Depth format は選択 device の current active video format に互換なものだけを使い、color capture policy を暗黙に別のものへ変更しません。

`ARKitFrameAdapter` は ARKit camera/depth geometry の framework boundary だけを変換します。`ARSession`、anchor、world tracking、scene reconstruction は所有しません。

`CameraVisionWorker` が live analysis の境界です。`ImageProcessingRequest` または任意の async operation を受け取り、1 in-flight、最新1 pending frame、generation-safe MainActor delivery を保証します。

製品UI、recording policy、effects、storage、semantic model、workflow はアプリ側に残します。pre-iOS-18 Vision API の互換レイヤーは持ちません。
