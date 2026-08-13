# Vision Pipeline

Vision integration では「座標の正しさ」と「リアルタイム結果の鮮度」を別々に保証します。

## Geometry

Vision normalized rect は左下原点です。Vision boundary で `VisionGeometry` を使って `CanonicalRect` へ変換します。raw Vision rect を通常の UI state に保存して後で flip する設計にはしません。

## Frame semantics

VideoDataOutput connection に resolved capture rotation と canonical non-mirror policy が適用済みなら、`CameraFrame.pixelBuffer` は upright canonical analysis data として扱います。`appliedVideoRotationAngle` は「すでに適用された値」で、後段への再回転命令ではありません。

## Bounded scheduling

`CameraFrameStream.frames` は pending を最新1frameだけ保持します。逐次 analyzer が遅くても FIFO backlog は成長しません。

重い解析を MainActor や capture callback で実行しません。

## Stale-result protection

`WorkGeneration` で解析開始時の semantic configuration を snapshot し、publish 直前にもう一度 current generation と比較します。camera/analyzer configuration change や screen departure で generation を進めます。

Cancellation は resource control、generation identity が correctness guarantee です。

## Frame identity

他の派生結果と alignment が必要なら source `CameraFrameID` と timestamp を保持します。「最近のRGB」と「最近のVision」は same accepted frame とは限りません。

## Result boundary

Vision result は canonical geometry と UI に必要な最小 field だけを持つ Sendable value へ変換します。Vision 固有の座標規約を SwiftUI state に持ち込みません。
