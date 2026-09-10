import Foundation

struct RecapModel: Decodable {
    let night_id: String
    let title: String
    let started_at: String
    let ended_at: String?
    let status: String

    let participants: [RecapParticipant]
    let events: RecapEvents

    let venue_timeline: [VenueTimelineItem]
    let venue_stats: VenueStats
    let movement_stats: MovementStats

    let fun_highlights: [FunHighlight]
}

struct RecapParticipant: Decodable, Identifiable {
    let id: String
    let name: String
}

struct RecapEvents: Decodable {
    let group_splits: [RecapEvent]
    let houdini: [RecapEvent]
    let side_quests: [RecapEvent]
    let dynamic_duo: [RecapEvent]
    let reunions: [RecapEvent]
    let most_independent: [RecapEvent]
    let early_checkout: [RecapEvent]
    let late_arrivals: [RecapEvent]

    let most_distance: MostDistanceEvent?
}

struct RecapEvent: Decodable {
    let participant_id: String?
    let participant_name: String?
    let duration_minutes: Double?
    let distance_meters: Double?
}

struct MostDistanceEvent: Decodable {
    let type: String
    let participant_id: String
    let participant_name: String
    let distance_meters: Double
    let distance_km: Double
}

struct FunHighlight: Decodable, Identifiable {
    var id: String {
        "\(type)-\(title)-\(text)"
    }

    let type: String
    let title: String
    let text: String
}

struct VenueTimelineItem: Decodable, Identifiable {
    var id: String {
        "\(venue_name)-\(arrived_at)"
    }

    let venue_name: String
    let category: String?
    let arrived_at: String
    let left_at: String
    let duration_minutes: Double?
}

struct VenueStats: Decodable {
    let total_places: Int?
    let nightlife_minutes: Double?
    let food_minutes: Double?
}

struct MovementStats: Decodable {
    let stationary_minutes: Double
    let walking_minutes: Double
    let fast_movement_minutes: Double
    let vehicle_minutes: Double
    let unknown_minutes: Double
}
