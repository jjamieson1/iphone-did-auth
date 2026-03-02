import CryptoKit
import Foundation

struct CryptoService {
    func sign(challenge: String, privateKeyBase64: String) throws -> String {
        guard let keyData = Data(base64Encoded: privateKeyBase64) else {
            throw AuthAppError.invalidPrivateKey
        }

        do {
            let privateKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
            let signature = try privateKey.signature(for: Data(challenge.utf8))
            return signature.derRepresentation.base64EncodedString()
        } catch {
            throw AuthAppError.invalidPrivateKey
        }
    }
}
