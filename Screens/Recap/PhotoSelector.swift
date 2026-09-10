import Photos
import UIKit
import CoreLocation

/// Finds the photos worth offering for a Night and turns a chosen
/// `PHAsset` into upload bytes. No networking here.
enum PhotoSelector {
    static func requestAccess() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let status = await PHPhotoLibrary.requestAuthorization(
                for: .readWrite
            )
            return status == .authorized || status == .limited
        default:
            return false
        }
    }

    /// Images taken around the Night (a 2-hour grace window on each side,
    /// since people open and close the app late), minus screenshots, and —
    /// when `coordinates` are given and the photo carries GPS — within
    /// ~500 m of the night.
    static func candidates(
        start: Date,
        end: Date,
        near coordinates: [CLLocationCoordinate2D]
    ) -> [PHAsset] {
        // People open AFTR after the night is underway and close it
        // before they get home, so cast a wide net around the window.
        let windowStart = start.addingTimeInterval(-4 * 60 * 60)
        let windowEnd = end.addingTimeInterval(8 * 60 * 60)

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format:
                "mediaType == %d AND creationDate >= %@ AND creationDate <= %@",
            PHAssetMediaType.image.rawValue,
            windowStart as NSDate,
            windowEnd as NSDate
        )
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]

        let routeLocations = coordinates.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }

        var result: [PHAsset] = []

        PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                return
            }

            if let location = asset.location, !routeLocations.isEmpty {
                let isNear = routeLocations.contains {
                    $0.distance(from: location) <= 500
                }
                if !isNear {
                    return
                }
            }

            result.append(asset)
        }

        return result
    }

    static func thumbnail(
        for asset: PHAsset,
        size: CGSize
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    struct MediaBytes {
        let data: Data
        let contentType: String
        let filename: String
    }

    /// A downscaled JPEG of the asset - recap photos don't need 12 MP,
    /// and a ~2048 px JPEG uploads roughly 10x faster than the original.
    static func uploadBytes(
        for asset: PHAsset
    ) async -> MediaBytes? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 2048, height: 2048),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                guard
                    let image,
                    let data = image.jpegData(compressionQuality: 0.8)
                else {
                    continuation.resume(returning: nil)
                    return
                }

                let stub = asset.localIdentifier
                    .replacingOccurrences(of: "/", with: "-")
                    .prefix(12)

                continuation.resume(
                    returning: MediaBytes(
                        data: data,
                        contentType: "image/jpeg",
                        filename: "\(stub).jpg"
                    )
                )
            }
        }
    }

    /// Decode arbitrary image data and re-encode as a downscaled JPEG.
    static func downscaledJPEG(
        from data: Data,
        maxDimension: CGFloat = 2048,
        quality: CGFloat = 0.8
    ) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / max(longest, 1))

        if scale >= 1 {
            return image.jpegData(compressionQuality: quality)
        }

        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resized.jpegData(compressionQuality: quality)
    }
}
