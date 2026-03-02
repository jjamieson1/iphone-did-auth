import Foundation
import Security

struct StoredIdentity {
    let did: String
    let privateKeyBase64: String
    let serviceBaseURL: String?
}

final class KeychainService {
    private enum Keys {
        static let did = "did_auth.did"
        static let privateKey = "did_auth.private_key"
        static let serviceBaseURL = "did_auth.service_base_url"
    }

    func saveIdentity(_ payload: IdentityImportPayload) throws {
        try saveString(payload.did, key: Keys.did)
        try saveString(payload.privateKeyBase64, key: Keys.privateKey)

        if let serviceBaseURL = payload.serviceBaseURL {
            try saveString(serviceBaseURL, key: Keys.serviceBaseURL)
        }
    }

    func loadIdentity() -> StoredIdentity? {
        guard let did = readString(key: Keys.did),
              let privateKeyBase64 = readString(key: Keys.privateKey) else {
            return nil
        }

        let serviceBaseURL = readString(key: Keys.serviceBaseURL)
        return StoredIdentity(did: did, privateKeyBase64: privateKeyBase64, serviceBaseURL: serviceBaseURL)
    }

    func saveServiceBaseURL(_ serviceBaseURL: String) throws {
        try saveString(serviceBaseURL, key: Keys.serviceBaseURL)
    }

    func clearServiceBaseURL() {
        deleteString(key: Keys.serviceBaseURL)
    }

    func loadServiceBaseURL() -> String? {
        readString(key: Keys.serviceBaseURL)
    }

    private func saveString(_ value: String, key: String) throws {
        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private func readString(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteString(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
