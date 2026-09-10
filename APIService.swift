import Foundation

struct CreateNightResponse: Decodable {
    let id: String
    let title: String
    let started_at: String
    let ended_at: String?
    let status: String
    let owner_user_id: String?
}

final class APIService {
    private let authService = AuthService()
    private let baseURL = "http://127.0.0.1:8000"

    func createNight(
        title: String
    ) async throws -> CreateNightResponse {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/nights"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        request.httpBody = try JSONSerialization.data(
            withJSONObject: [
                "title": title
            ]
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        try validate(response)

        return try JSONDecoder().decode(
            CreateNightResponse.self,
            from: data
        )
    }

    func getNights() async throws -> [NightSummary] {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/nights"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        try validate(response)

        return try JSONDecoder().decode(
            [NightSummary].self,
            from: data
        )
    }

    func getRecap(
        nightId: String
    ) async throws -> RecapModel {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/nights/\(nightId)/recap"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        try validate(response)

        return try JSONDecoder().decode(
            RecapModel.self,
            from: data
        )
    }

    func joinNight(
        nightId: String
    ) async throws {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/nights/\(nightId)/participants"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        let (_, response) = try await URLSession.shared.data(
            for: request
        )

        try validate(response)
    }

    func sendLocation(
        nightId: String,
        latitude: Double,
        longitude: Double,
        speed: Double?,
        horizontalAccuracy: Double?
    ) async throws {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/nights/\(nightId)/locations"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        var body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]

        if let speed {
            body["speed"] = speed
        }

        if let horizontalAccuracy {
            body["horizontal_accuracy"] = horizontalAccuracy
        }

        request.httpBody = try JSONSerialization.data(
            withJSONObject: body
        )

        let (_, response) = try await URLSession.shared.data(
            for: request
        )

        try validate(response)
    }

    func endNight(
        nightId: String
    ) async throws {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/nights/\(nightId)/end"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )

        let (_, response) = try await URLSession.shared.data(
            for: request
        )

        try validate(response)
    }

    private func validate(
        _ response: URLResponse
    ) throws {
        guard
            let httpResponse = response as? HTTPURLResponse,
            200..<300 ~= httpResponse.statusCode
        else {
            throw URLError(.badServerResponse)
        }
    }
}
