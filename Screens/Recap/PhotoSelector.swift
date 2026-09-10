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
        let grace: TimeInterval = 2 * 60 * 60
        let windowStart = start.addingTimeInterval(-grace)
        let windowEnd = end.addingTimeInterval(grace)

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

    static func uploadBytes(
        for asset: PHAsset
    ) async -> MediaBytes? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, uti, _, _ in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }

                let contentType: String
                let ext: String

                switch uti {
                case "public.png":
                    contentType = "image/png"
                    ext = "png"
                case "public.heic", "public.heif":
                    contentType = "image/heic"
                    ext = "heic"
                default:
                    contentType = "image/jpeg"
                    ext = "jpg"
                }

                let stub = asset.localIdentifier
                    .replacingOccurrences(of: "/", with: "-")
                    .prefix(12)

                continuation.resume(
                    returning: MediaBytes(
                        data: data,
                        contentType: contentType,
                        filename: "\(stub).\(ext)"
                    )
                )
            }
        }
    }
}
