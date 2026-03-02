import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var installedDID: String?
    @Published var statusMessage: String = "Import DID identity to begin."
    @Published var isBusy: Bool = false

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
    }

    func submitLoginChallenge(from qrText: String) async {
        guard let identity = keychainService.loadIdentity() else {
            statusMessage = AuthAppError.missingIdentity.localizedDescription
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let challengePayload = try QRPayloadParser.parseChallenge(from: qrText)
            let signature = try cryptoService.sign(
                challenge: challengePayload.challenge,
                privateKeyBase64: identity.privateKeyBase64
            )

            try await authServiceClient.submitChallengeResponse(
                payload: challengePayload,
                did: identity.did,
                signatureBase64: signature,
                fallbackServiceBaseURL: identity.serviceBaseURL
            )

            statusMessage = "Challenge response sent successfully."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
