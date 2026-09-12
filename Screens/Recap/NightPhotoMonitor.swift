import Photos
import Foundation

/// Watches the photo library for the length of an active Night and
/// uploads any new photo the moment it's taken, so the recap already has
/// photos by the time the Night ends - no need to open "Add Photos"
/// afterward. That manual flow (AddPhotosView) still exists as a
/// catch-all for anything this misses (access denied at the time,
/// photos synced in later from another device, etc.) and cross-checks
/// against `source_asset_id` so nothing gets added twice.
///
/// This only works because location tracking already keeps the app
/// process alive in the background for the whole Night
/// (`allowsBackgroundLocationUpdates` + the `location` background mode
/// in NightSession/LocationManager) - a `PHPhotoLibraryChangeObserver`
/// only fires while the process is alive, so without that this would
/// silently do nothing once the phone is put away.
@MainActor
final class NightPhotoMonitor: NSObject, PHPhotoLibraryChangeObserver {
    private let nightId: String
    private let startedAt: Date
    private let apiService = APIService()

    private var fetchResult: PHFetchResult<PHAsset>?
    private var knownAssetIds: Set<String> = []
    private var isObserving = false

    init(nightId: String, startedAt: Date) {
        self.nightId = nightId
        self.startedAt = startedAt
    }

    func start() {
        Task {
            guard await PhotoSelector.requestAccess() else {
                print("[PhotoMonitor] Photo access not granted - skipping live capture.")
                return
            }

            // Covers a relaunch mid-Night, or photos the manual "Add
            // Photos" flow already added - never re-upload those.
            if let existing = try? await apiService.getMedia(nightId: nightId) {
                knownAssetIds = Set(existing.compactMap(\.source_asset_id))
            }

            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "mediaType == %d AND creationDate >= %@",
                PHAssetMediaType.image.rawValue,
                startedAt as NSDate
            )
            options.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: true)
            ]

            let result = PHAsset.fetchAssets(with: options)
            fetchResult = result
            PHPhotoLibrary.shared().register(self)
            isObserving = true

            await uploadNew(in: result)
        }
    }

    func stop() {
        guard isObserving else { return }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        isObserving = false
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self, let fetchResult = self.fetchResult,
                  let details = changeInstance.changeDetails(for: fetchResult)
            else { return }

            self.fetchResult = details.fetchResultAfterChanges
            await self.uploadNew(in: details.fetchResultAfterChanges)
        }
    }

    private func uploadNew(in result: PHFetchResult<PHAsset>) async {
        var newAssets: [PHAsset] = []

        result.enumerateObjects { [knownAssetIds] asset, _, _ in
            guard !asset.mediaSubtypes.contains(.photoScreenshot),
                  !knownAssetIds.contains(asset.localIdentifier)
            else { return }
            newAssets.append(asset)
        }

        guard !newAssets.isEmpty else { return }

        let formatter = ISO8601DateFormatter()

        for asset in newAssets {
            knownAssetIds.insert(asset.localIdentifier)

            guard let bytes = await PhotoSelector.uploadBytes(for: asset)
            else { continue }

            do {
                _ = try await apiService.uploadMedia(
                    nightId: nightId,
                    data: bytes.data,
                    contentType: bytes.contentType,
                    filename: bytes.filename,
                    takenAt: asset.creationDate.map(formatter.string(from:)),
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude,
                    sourceAssetId: asset.localIdentifier
                )
                print("[PhotoMonitor] Auto-uploaded a photo from the Night.")
            } catch {
                print("[PhotoMonitor] Auto-upload failed:", error)
            }
        }
    }
}
