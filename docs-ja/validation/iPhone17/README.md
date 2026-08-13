# iPhone 17 Validation

iPhone 17 系、または開発中に「iPhone 17」と呼んでいる実機について、CameraGeometryKit の検証 run を蓄積するディレクトリです。

marketing name から hardware identifier を推測しません。各 run で実機が返す identifier を記録します。

## Status

CameraGeometryKit としての実機検証結果はまだ未記録です。

## Run file

OS / package version ごとに1fileを追加します。

```text
2026-08-14-ios-26.6.md
```

[`../TEMPLATE.md`](../TEMPLATE.md) をコピーして使います。

## この folder の意味

これまでの camera 実装では、front camera の sensor-native orientation が rear camera や旧世代への仮定と一致しないケースがありました。

対応は固定90°補正ではなく、実機で RotationCoordinator values、connection-applied rotation、mirroring、frame dimensions、visible output を記録することです。

この folder を `if iPhone17 { rotate90() }` の根拠にしてはいけません。
