# Documentation

CameraGeometryKit uses Swift-DocC for API reference documentation. The
documentation catalog is in
`Sources/CameraGeometryKit/CameraGeometryKit.docc`.

## Build locally

From the package root:

```sh
swift package \
    --triple arm64-apple-ios18.0-simulator \
    --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
    --allow-writing-to-directory docs-site \
    generate-documentation \
    --target CameraGeometryKit \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path CameraGeometryKit \
    --output-path docs-site
```

The generated site is written to `docs-site/`, which is intentionally ignored
by Git. Preview the catalog during authoring with:

```sh
swift package --disable-sandbox \
    preview-documentation --target CameraGeometryKit
```

## Publish on GitHub Pages

`.github/workflows/documentation.yml` builds the site on every relevant push
to `main` and deploys it through GitHub Pages. The generated site is not
committed to the repository.

1. In the repository, open **Settings > Pages**.
2. Set **Source** to **GitHub Actions**.
3. Push the workflow and the DocC catalog to `main`, or run the workflow from
   the **Actions** tab with **Run workflow**.
4. Open the URL shown on the Pages settings screen. For this repository it is
   normally:
   `https://oqzl.github.io/CameraGeometryKit/documentation/camerageometrykit/`

The `CameraGeometryKit` hosting base path is required because this is a
project Pages site served below `github.io/CameraGeometryKit/`. If the
repository name or Pages URL changes, update `--hosting-base-path` and the
workflow trigger branch accordingly.
