import Foundation

struct NightMedia: Decodable, Identifiable {
    let id: String
    let media_type: String        // "image" | "video"
    let taken_at: String?
    let latitude: Double?
    let longitude: Double?
    let venue_name: String?
    let url: String?

    var imageURL: URL? {
        guard let url else { return nil }
        return URL(string: url)
    }
}

struct UploadMediaResponse: Decodable {
    let id: String
    let media_type: String
    let url: String?
}
