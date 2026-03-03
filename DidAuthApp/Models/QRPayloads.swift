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
    let signatureAlgorithm: String?
}

enum QRPayloadParser {
    static func parseIdentity(from qrText: String) throws -> IdentityImportPayload {
        let data = try extractPayloadData(from: qrText)

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthAppError.invalidQRPayload
        }

        let root = unwrapPayloadContainer(from: object)

        let did = stringValue(from: root, keys: ["did", "didUri", "did_uri", "identifier"])
        let privateKey = stringValue(from: root, keys: ["privateKeyBase64", "private_key_base64", "privateKey", "private_key", "privateKeyB64", "secretKey"])
        let serviceBaseURL = stringValue(from: root, keys: ["serviceBaseURL", "service_base_url", "serviceBaseUrl", "baseURL", "baseUrl"])

        guard let did, !did.isEmpty else {
            throw AuthAppError.missingQRField("did")
        }

        guard let privateKey, !privateKey.isEmpty else {
            throw AuthAppError.missingQRField("privateKeyBase64 (or privateKey)")
        }

        return IdentityImportPayload(did: did, privateKeyBase64: privateKey, serviceBaseURL: serviceBaseURL)
    }

    static func parseChallenge(from qrText: String) throws -> LoginChallengePayload {
        let data = try extractPayloadData(from: qrText)

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthAppError.invalidQRPayload
        }

        let root = unwrapChallengeContainer(from: unwrapPayloadContainer(from: object))

        let challengeId = stringValue(from: root, keys: ["challengeId", "challenge_id", "requestId", "request_id", "id"])
        let challenge = stringValue(from: root, keys: ["challenge", "nonce", "message", "token"])
        let callbackURL = stringValue(from: root, keys: ["callbackURL", "callbackUrl", "callback_url", "callback", "replyURL", "reply_url"])
        let serviceBaseURL = stringValue(from: root, keys: ["serviceBaseURL", "service_base_url", "serviceBaseUrl", "baseURL", "baseUrl"])
        let responsePath = stringValue(from: root, keys: ["responsePath", "response_path", "callbackPath", "callback_path"])
        let signatureAlgorithm = stringValue(from: root, keys: ["signatureAlgorithm", "signature_algorithm", "algorithm", "alg"])

        guard let challengeId, !challengeId.isEmpty else {
            throw AuthAppError.missingQRField("challengeId")
        }

        guard let challenge, !challenge.isEmpty else {
            throw AuthAppError.missingQRField("challenge")
        }

        return LoginChallengePayload(
            challengeId: challengeId,
            challenge: challenge,
            callbackURL: callbackURL,
            serviceBaseURL: serviceBaseURL,
            responsePath: responsePath,
            signatureAlgorithm: signatureAlgorithm
        )
    }

    private static func extractPayloadData(from qrText: String) throws -> Data {
        if let directData = qrText.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: directData)) != nil {
            return directData
        }

        guard let url = URL(string: qrText),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AuthAppError.invalidQRPayload
        }

        if let payloadItem = components.queryItems?.first(where: {
            ["payload", "data", "q", "qr"].contains($0.name.lowercased())
        }),
           let payloadValue = payloadItem.value {
            if let payloadData = Data(base64URLEncoded: payloadValue) ?? Data(base64Encoded: payloadValue),
               (try? JSONSerialization.jsonObject(with: payloadData)) != nil {
                return payloadData
            }

            if let percentDecoded = payloadValue.removingPercentEncoding,
               let payloadData = percentDecoded.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: payloadData)) != nil {
                return payloadData
            }
        }

        if let queryObject = queryItemsAsJSONObject(components.queryItems),
           let queryData = try? JSONSerialization.data(withJSONObject: queryObject) {
            return queryData
        }

        throw AuthAppError.invalidQRPayload
    }

    private static func unwrapPayloadContainer(from object: [String: Any]) -> [String: Any] {
        if let nested = object["payload"] as? [String: Any] {
            return nested
        }

        if let nestedString = object["payload"] as? String,
           let nestedData = nestedString.data(using: .utf8),
           let nestedObject = try? JSONSerialization.jsonObject(with: nestedData) as? [String: Any] {
            return nestedObject
        }

        if let nested = object["data"] as? [String: Any] {
            return nested
        }

        if let nestedString = object["data"] as? String,
           let nestedData = nestedString.data(using: .utf8),
           let nestedObject = try? JSONSerialization.jsonObject(with: nestedData) as? [String: Any] {
            return nestedObject
        }

        return object
    }

    private static func unwrapChallengeContainer(from object: [String: Any]) -> [String: Any] {
        if let nested = object["challenge"] as? [String: Any] {
            return nested
        }

        if let nested = object["loginChallenge"] as? [String: Any] {
            return nested
        }

        if let nested = object["authRequest"] as? [String: Any] {
            return nested
        }

        return object
    }

    private static func queryItemsAsJSONObject(_ queryItems: [URLQueryItem]?) -> [String: Any]? {
        guard let queryItems, !queryItems.isEmpty else {
            return nil
        }

        var object: [String: Any] = [:]
        for item in queryItems {
            guard let value = item.value, !value.isEmpty else {
                continue
            }

            object[item.name] = value
        }

        return object.isEmpty ? nil : object
    }

    private static func stringValue(from object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String {
                return value
            }
        }

        return nil
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
