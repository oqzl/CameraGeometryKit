import CameraGeometryKit
import PhotosUI
import SwiftUI
import UIKit

struct ImageLabView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var canonicalImage: UIImage?
    @State private var downsampledImage: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose Image", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.borderedProminent)

                    if let sourceImage, let canonicalImage, let downsampledImage {
                        imageCard("Source", image: sourceImage, details: sourceDetails(sourceImage))
                        imageCard("Canonical", image: canonicalImage, details: sourceDetails(canonicalImage))
                        imageCard("Downsampled ≤ 1600 px", image: downsampledImage, details: sourceDetails(downsampledImage))
                    } else {
                        ContentUnavailableView(
                            "Select an image",
                            systemImage: "photo",
                            description: Text("Tests UIImage canonicalization and preview downsampling.")
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Image Lab")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: pickerItem) { await loadImage() }
        }
    }

    @ViewBuilder
    private func imageCard(_ title: String, image: UIImage, details: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .frame(maxWidth: .infinity)
                .background(Color.black)
            Text(details).font(.caption2.monospaced())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceDetails(_ image: UIImage) -> String {
        let width = image.cgImage?.width ?? Int(image.size.width * image.scale)
        let height = image.cgImage?.height ?? Int(image.size.height * image.scale)
        return "pixels \(width) × \(height) • scale \(image.scale) • orientation \(image.imageOrientation.rawValue)"
    }

    private func loadImage() async {
        guard let pickerItem else { return }
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Could not decode selected image."
                return
            }
            let canonical = image.cameraGeometryCanonicalized()
            let downsampled = canonical.cameraGeometryDownsampled(maxPixelDimension: 1600)
            sourceImage = image
            canonicalImage = canonical
            downsampledImage = downsampled
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
