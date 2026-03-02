import CryptoKit
import Foundation

struct SignatureResult {
    let signatureBase64: String
    let algorithm: String
}

struct CryptoService {
    func sign(challenge: String, privateKeyBase64: String, preferredAlgorithm: String?) throws -> SignatureResult {
        let keyCandidates = keyDataCandidates(from: privateKeyBase64)
        let challengeData = Data(challenge.utf8)

        let requested = normalizedAlgorithm(preferredAlgorithm)
        let algorithmOrder: [SigningAlgorithm] = switch requested {
        case .es256:
            [.es256]
        case .edDSA:
            [.edDSA]
        case nil:
            [.es256, .edDSA]
        }

        for algorithm in algorithmOrder {
            for keyData in keyCandidates {
                switch algorithm {
                case .es256:
                    if let privateKey = loadP256PrivateKey(from: keyData) {
                        let signature = try privateKey.signature(for: challengeData)
                        return SignatureResult(
                            signatureBase64: signature.derRepresentation.base64EncodedString(),
                            algorithm: "ES256"
                        )
                    }
                case .edDSA:
                    if let privateKey = loadEd25519PrivateKey(from: keyData) {
                        let signature = try privateKey.signature(for: challengeData)
                        return SignatureResult(
                            signatureBase64: signature.base64EncodedString(),
                            algorithm: "EdDSA"
                        )
                    }
                }
            }
        }

        throw AuthAppError.invalidPrivateKey
    }

    private func loadP256PrivateKey(from data: Data) -> P256.Signing.PrivateKey? {
        if let normalizedRawData = normalizedRawKeyData(from: data),
           let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: normalizedRawData) {
            return privateKey
        }

        if let privateKey = try? P256.Signing.PrivateKey(derRepresentation: data) {
            return privateKey
        }

        return nil
    }

    private func loadEd25519PrivateKey(from data: Data) -> Curve25519.Signing.PrivateKey? {
        if data.count == 64 {
            let seed = data.prefix(32)
            return try? Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        }

        if data.count == 32 {
            return try? Curve25519.Signing.PrivateKey(rawRepresentation: data)
        }

        return nil
    }

    private func normalizedRawKeyData(from data: Data) -> Data? {
        if data.count == 32 {
            return data
        }

        if data.count == 33, data.first == 0 {
            return data.dropFirst()
        }

        return nil
    }

    private func keyDataCandidates(from privateKey: String) -> [Data] {
        let trimmed = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let stringCandidates = normalizedStringCandidates(from: trimmed)
        var candidates: [Data] = []
        var seen = Set<Data>()

        func append(_ data: Data) {
            if seen.insert(data).inserted {
                candidates.append(data)
            }
        }

        for value in stringCandidates {
            if let pemData = decodePEM(value) {
                append(pemData)
            }

            if let jwkDValue = extractJWKDValue(from: value),
               let jwkData = Data(base64URLEncoded: jwkDValue) {
                append(jwkData)
            }

            if let data = Data(base64Encoded: value) {
                append(data)
                appendNestedTextCandidates(from: data, append: append)
            }

            if let data = Data(base64URLEncoded: value) {
                append(data)
                appendNestedTextCandidates(from: data, append: append)
            }

            if let data = decodeHex(value) {
                append(data)
            }
        }

        return candidates
    }

    private func normalizedStringCandidates(from text: String) -> [String] {
        var values = [text]

        let unescapedNewlines = text.replacingOccurrences(of: "\\n", with: "\n")
        if unescapedNewlines != text {
            values.append(unescapedNewlines)
        }

        for prefix in ["base64:", "base64url:", "hex:"] {
            if text.lowercased().hasPrefix(prefix) {
                values.append(String(text.dropFirst(prefix.count)))
            }
        }

        return Array(Set(values))
    }

    private func appendNestedTextCandidates(from data: Data, append: (Data) -> Void) {
        guard let text = String(data: data, encoding: .utf8) else {
            return
        }

        let nestedCandidates = normalizedStringCandidates(from: text.trimmingCharacters(in: .whitespacesAndNewlines))

        for nested in nestedCandidates {
            if let pemData = decodePEM(nested) {
                append(pemData)
            }

            if let jwkDValue = extractJWKDValue(from: nested),
               let jwkData = Data(base64URLEncoded: jwkDValue) {
                append(jwkData)
            }

            if let hexData = decodeHex(nested) {
                append(hexData)
            }
        }
    }

    private func decodePEM(_ pemText: String) -> Data? {
        guard pemText.contains("-----BEGIN") else {
            return nil
        }

        let base64Body = pemText
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
            .joined()

        return Data(base64Encoded: base64Body)
    }

    private func extractJWKDValue(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = object["d"] as? String else {
            return nil
        }

        return d
    }

    private func decodeHex(_ text: String) -> Data? {
        let cleaned = text.hasPrefix("0x") ? String(text.dropFirst(2)) : text
        guard cleaned.count % 2 == 0, !cleaned.isEmpty else {
            return nil
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(cleaned.count / 2)

        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            let byteString = cleaned[index..<next]

            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }

            bytes.append(byte)
            index = next
        }

        return Data(bytes)
    }

    private func normalizedAlgorithm(_ value: String?) -> SigningAlgorithm? {
        guard let value else {
            return nil
        }

        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "es256", "p-256", "p256":
            return .es256
        case "eddsa", "ed25519", "ed-25519":
            return .edDSA
        default:
            return nil
        }
    }
}

private enum SigningAlgorithm {
    case es256
    case edDSA
}
