import Foundation

struct IdentityImportPayload: Codable {
    let did: String
    let privateKeyBase64: String
    let serviceBaseURL: String?
}

struct LoginChallengePayload: Codable {
    let challengeId: String
    let challenge: String
    let callbackURL: String?
    let serviceBaseURL: String?
    let responsePath: String?
}

enum QRPayloadParser {
    static func parseIdentity(from qrText: String) throws -> IdentityImportPayload {
        let data = try extractPayloadData(from: qrText)
        return try JSONDecoder().decode(IdentityImportPayload.self, from: data)
    }

    static func parseChallenge(from qrText: String) throws -> LoginChallengePayload {
        let data = try extractPayloadData(from: qrText)
        return try JSONDecoder().decode(LoginChallengePayload.self, from: data)
    }

    private static func extractPayloadData(from qrText: String) throws -> Data {
        if let directData = qrText.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: directData),
           JSONSerialization.isValidJSONObject(object) {
            return directData
        }

        guard let url = URL(string: qrText),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let payloadItem = components.queryItems?.first(where: { $0.name == "payload" }),
              let payloadValue = payloadItem.value else {
            throw AuthAppError.invalidQRPayload
        }

        if let payloadData = Data(base64URLEncoded: payloadValue) ?? Data(base64Encoded: payloadValue) {
            return payloadData
        }

        guard let percentDecoded = payloadValue.removingPercentEncoding,
              let payloadData = percentDecoded.data(using: .utf8) else {
            throw AuthAppError.invalidQRPayload
        }

        return payloadData
    }
}

extension Data {
    init?(base64URLEncoded string: String) {
        var value = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padLength = 4 - (value.count % 4)
        if padLength < 4 {
            value += String(repeating: "=", count: padLength)
        }

        self.init(base64Encoded: value)
    }
}
