import Foundation
import CoreLocation

struct HomeLocation: Codable {
    let latitude: Double
    let longitude: Double
    let radius_meters: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

struct SafeWalkStart: Decodable {
    let token: String
    let url: String
}

struct MonthlyWrap: Decodable {
    let month: String
    let nights: Int
    let hours_out: Double
    let distance_km: Double
    let venues_visited: Int
    let unique_venues: Int
    let top_venues: [WrapCount]
    let top_people: [WrapCount]
    /// Monday = 0 ... Sunday = 6. Language-agnostic - localized to a
    /// weekday name on-device via Foundation's Calendar.
    let busiest_weekday_index: Int?
    let latest_end_hour: Double?
}

struct WrapCount: Decodable, Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}
