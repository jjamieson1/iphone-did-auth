import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var installedDID: String?
    @Published var statusMessage: String = "Import DID identity to begin."
    @Published var isBusy: Bool = false
    @Published var serviceBaseURLInput: String = ""

    private let keychainService: KeychainService
    private let cryptoService: CryptoService
    private let authServiceClient: AuthServiceClient

    init(
        keychainService: KeychainService = KeychainService(),
        cryptoService: CryptoService = CryptoService(),
        authServiceClient: AuthServiceClient = AuthServiceClient()
    ) {
        self.keychainService = keychainService
        self.cryptoService = cryptoService
        self.authServiceClient = authServiceClient
        refreshIdentityStatus()
    }

    func importIdentity(from qrText: String) {
        do {
            let payload = try QRPayloadParser.parseIdentity(from: qrText)
            try keychainService.saveIdentity(payload)
            installedDID = payload.did
            statusMessage = "Identity imported for DID: \(payload.did)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshIdentityStatus() {
        let identity = keychainService.loadIdentity()
        installedDID = identity?.did
        serviceBaseURLInput = identity?.serviceBaseURL ?? ""
    }

    func saveServiceBaseURL() {
        let value = serviceBaseURLInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.isEmpty {
            keychainService.clearServiceBaseURL()
            statusMessage = "Service base URL cleared."
            return
        }

        guard let url = URL(string: value), url.scheme != nil, url.host != nil else {
            statusMessage = "Enter a valid absolute URL (for example: https://example.com)."
            return
        }

        do {
            try keychainService.saveServiceBaseURL(value)
            statusMessage = "Service base URL saved."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func clearServiceBaseURL() {
        keychainService.clearServiceBaseURL()
        serviceBaseURLInput = ""
        statusMessage = "Service base URL cleared."
    }

    func parseLoginChallenge(from rawValue: String) throws -> LoginChallengePayload {
        try QRPayloadParser.parseChallenge(from: rawValue)
    }

    func submitLoginChallenge(from qrText: String) async {
        do {
            let challengePayload = try QRPayloadParser.parseChallenge(from: qrText)
            await submitLoginChallenge(payload: challengePayload)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func submitLoginChallenge(payload: LoginChallengePayload) async {
        guard let identity = keychainService.loadIdentity() else {
            statusMessage = AuthAppError.missingIdentity.localizedDescription
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let signatureResult = try cryptoService.sign(
                challenge: payload.challenge,
                privateKeyBase64: identity.privateKeyBase64,
                preferredAlgorithm: payload.signatureAlgorithm
            )

            try await authServiceClient.submitChallengeResponse(
                payload: payload,
                did: identity.did,
                signatureBase64: signatureResult.signatureBase64,
                algorithm: signatureResult.algorithm,
                fallbackServiceBaseURL: identity.serviceBaseURL
            )

            statusMessage = "Challenge response sent successfully."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
