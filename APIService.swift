import Foundation

/// App-wide configuration.
///
/// `apiBaseURL` defaults to the local dev server. To point a build at a
/// deployed backend, add an `API_BASE_URL` string key to Info.plist - no
/// code change needed.
///
/// Note: `127.0.0.1` only works in the iOS Simulator. On a physical
/// device, use your Mac's LAN address or a hosted URL.
enum AppConfig {
    static let apiBaseURL: String = {
        if let configured = Bundle.main.object(
            forInfoDictionaryKey: "API_BASE_URL"
        ) as? String,
        !configured.isEmpty {
            return configured
        }

        return "http://127.0.0.1:8000"
    }()
}

extension ISO8601DateFormatter {
    /// The backend (Python's `datetime.isoformat()`) always includes
    /// fractional seconds, which the plain `ISO8601DateFormatter()`
    /// silently fails to parse - every `started_at`/`ended_at` timestamp
    /// from the API needs this, not the default formatter.
    static func aftrDate(from string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) {
            return date
        }
        return ISO8601DateFormatter().date(from: string)
    }
}

struct CreateNightResponse: Decodable {
    let id: String
    let title: String
    let started_at: String
    let ended_at: String?
    let status: String
    let owner_user_id: String?
    let join_code: String?
}

struct NightDetail: Decodable {
    let id: String
    let title: String
    let join_code: String?
    let status: String
    let participant_count: Int
    let participants: [NightDetailParticipant]
}

struct NightDetailParticipant: Decodable, Identifiable {
    let id: String
    let name: String
}

final class APIService {
    private let authService = AuthService()
    private let baseURL = AppConfig.apiBaseURL

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

    func register(name: String) async throws {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/users"
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
            withJSONObject: ["name": name]
        )

        let (_, response) = try await URLSession.shared.data(
            for: request
        )

        try validate(response)
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

    func joinNight(
        code: String
    ) async throws -> CreateNightResponse {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/nights/join"
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
                "code": code
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

    func getNight(
        nightId: String
    ) async throws -> NightDetail {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/nights/\(nightId)"
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
            NightDetail.self,
            from: data
        )
    }

    func getMedia(
        nightId: String
    ) async throws -> [NightMedia] {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/nights/\(nightId)/media"
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
            [NightMedia].self,
            from: data
        )
    }

    func uploadMedia(
        nightId: String,
        data mediaData: Data,
        contentType: String,
        filename: String,
        takenAt: String?,
        latitude: Double?,
        longitude: Double?
    ) async throws -> UploadMediaResponse {
        let token = try await authService.accessToken()

        guard let url = URL(
            string: "\(baseURL)/nights/\(nightId)/media"
        ) else {
            throw URLError(.badURL)
        }

        let boundary = "AFTR-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n"
                    .data(using: .utf8)!
            )
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        if let takenAt {
            appendField("taken_at", takenAt)
        }
        if let latitude {
            appendField("latitude", String(latitude))
        }
        if let longitude {
            appendField("longitude", String(longitude))
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
                .data(using: .utf8)!
        )
        body.append(
            "Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!
        )
        body.append(mediaData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (responseData, response) = try await URLSession.shared.upload(
            for: request,
            from: body
        )

        try validate(response)

        return try JSONDecoder().decode(
            UploadMediaResponse.self,
            from: responseData
        )
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

    func sendLiveActivityPushToken(
        nightId: String,
        token: String
    ) async throws {
        _ = try await sendRaw(
            "/nights/\(nightId)/live-activity-token",
            method: "POST",
            body: ["push_token": token]
        )
    }

    func endNight(
        nightId: String
    ) async throws {
        let token = try await authService.accessToken()

        let lang = Locale.current.language.languageCode?.identifier ?? "en"

        guard let url = URL(
            string: "\(baseURL)/nights/\(nightId)/end?lang=\(lang)"
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

    // MARK: - Home location

    func getHome() async throws -> HomeLocation? {
        try await getJSON("/me/home")
    }

    @discardableResult
    func setHome(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 120
    ) async throws -> HomeLocation {
        try await sendJSON(
            "/me/home",
            method: "PUT",
            body: [
                "latitude": latitude,
                "longitude": longitude,
                "radius_meters": radiusMeters,
            ]
        )
    }

    func clearHome() async throws {
        _ = try await request("/me/home", method: "DELETE")
    }

    // MARK: - Monthly wrap

    func getWrap(month: String? = nil) async throws -> MonthlyWrap {
        let path = month.map { "/wrap?month=\($0)" } ?? "/wrap"
        return try await getJSON(path)
    }

    // MARK: - Get home safe

    func startSafeWalk() async throws -> SafeWalkStart {
        try await sendJSON("/safewalks", method: "POST", body: [:])
    }

    func pingSafeWalk(
        token: String,
        latitude: Double,
        longitude: Double
    ) async throws {
        _ = try await sendRaw(
            "/safewalks/\(token)/ping",
            method: "POST",
            body: ["latitude": latitude, "longitude": longitude]
        )
    }

    func arriveSafeWalk(token: String) async throws {
        _ = try await sendRaw(
            "/safewalks/\(token)/arrive",
            method: "POST",
            body: [:]
        )
    }

    // MARK: - Small JSON helpers

    private func authorizedRequest(
        _ path: String,
        method: String
    ) async throws -> URLRequest {
        let token = try await authService.accessToken()
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }

    private func request(
        _ path: String,
        method: String
    ) async throws -> Data {
        let req = try await authorizedRequest(path, method: method)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return data
    }

    private func getJSON<T: Decodable>(_ path: String) async throws -> T {
        let data = try await request(path, method: "GET")
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func sendRaw(
        _ path: String,
        method: String,
        body: [String: Any]
    ) async throws -> Data {
        var req = try await authorizedRequest(path, method: method)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response)
        return data
    }

    private func sendJSON<T: Decodable>(
        _ path: String,
        method: String,
        body: [String: Any]
    ) async throws -> T {
        let data = try await sendRaw(path, method: method, body: body)
        return try JSONDecoder().decode(T.self, from: data)
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
