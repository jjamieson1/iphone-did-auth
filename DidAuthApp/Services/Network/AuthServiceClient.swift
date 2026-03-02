import Foundation

final class AuthServiceClient {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func submitChallengeResponse(
        payload: LoginChallengePayload,
        did: String,
        signatureBase64: String,
        algorithm: String,
        fallbackServiceBaseURL: String?
    ) async throws {
        let endpoint = try buildEndpoint(from: payload, fallbackServiceBaseURL: fallbackServiceBaseURL)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "did": did,
            "challengeId": payload.challengeId,
            "challenge": payload.challenge,
            "signature": signatureBase64,
            "algorithm": algorithm
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        guard (200 ... 299).contains(statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthAppError.networkError(statusCode: statusCode, message: message)
        }
    }

    private func buildEndpoint(
        from payload: LoginChallengePayload,
        fallbackServiceBaseURL: String?
    ) throws -> URL {
        if let callbackURL = payload.callbackURL,
           !callbackURL.isEmpty {
            if let absoluteURL = URL(string: callbackURL), absoluteURL.scheme != nil {
                return absoluteURL
            }

            let serviceBaseURL = payload.serviceBaseURL ?? fallbackServiceBaseURL
            if let serviceBaseURL,
               let baseURL = URL(string: serviceBaseURL),
               let relativeURL = URL(string: callbackURL, relativeTo: baseURL)?.absoluteURL {
                return relativeURL
            }
        }

        let serviceBaseURL = payload.serviceBaseURL ?? fallbackServiceBaseURL

        guard let serviceBaseURL,
              var components = URLComponents(string: serviceBaseURL) else {
            throw AuthAppError.invalidServiceURL
        }

        let path = payload.responsePath ?? "/api/did-auth/response"
        components.path = path

        guard let url = components.url else {
            throw AuthAppError.invalidServiceURL
        }

        return url
    }
}
