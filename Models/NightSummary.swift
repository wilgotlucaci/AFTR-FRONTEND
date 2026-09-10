import Foundation

struct NightSummary: Identifiable, Decodable {
    let id: String
    let title: String
    let started_at: String
    let ended_at: String?
    let status: String
    let owner_user_id: String?
}
