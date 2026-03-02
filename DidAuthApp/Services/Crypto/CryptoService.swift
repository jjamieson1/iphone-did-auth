import CryptoKit
import Foundation

struct CryptoService {
    func sign(challenge: String, privateKeyBase64: String) throws -> String {
        let keyCandidates = keyDataCandidates(from: privateKeyBase64)

        for keyData in keyCandidates {
            if let privateKey = loadPrivateKey(from: keyData) {
                let signature = try privateKey.signature(for: Data(challenge.utf8))
                return signature.derRepresentation.base64EncodedString()
            }
        }

        throw AuthAppError.invalidPrivateKey
    }

    private func loadPrivateKey(from data: Data) -> P256.Signing.PrivateKey? {
        if let normalizedRawData = normalizedRawKeyData(from: data),
           let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: normalizedRawData) {
            return privateKey
        }

        if let privateKey = try? P256.Signing.PrivateKey(derRepresentation: data) {
            return privateKey
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
        var candidates: [Data] = []

        if let pemData = decodePEM(trimmed) {
            candidates.append(pemData)
        }

        if let jwkDValue = extractJWKDValue(from: trimmed),
           let jwkData = Data(base64URLEncoded: jwkDValue) {
            candidates.append(jwkData)
        }

        if let data = Data(base64Encoded: trimmed) {
            candidates.append(data)
        }

        if let data = Data(base64URLEncoded: trimmed) {
            candidates.append(data)
        }

        if let data = decodeHex(trimmed) {
            candidates.append(data)
        }

        return candidates
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
}
