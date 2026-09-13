import Foundation

struct Badge: Decodable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let threshold: Int
    let count: Int
    let unlocked: Bool
}
