import Foundation

enum AuthAppError: LocalizedError {
    case invalidQRPayload
    case missingQRField(String)
    case cameraNotAuthorized
    case missingIdentity
    case invalidPrivateKey
    case invalidServiceURL
    case networkError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidQRPayload:
            return "The QR code does not contain a valid DID auth payload."
        case let .missingQRField(fieldName):
            return "The QR code is missing required field: \(fieldName)."
        case .cameraNotAuthorized:
            return "Camera access is required to scan QR codes."
        case .missingIdentity:
            return "No DID identity is installed yet. Import your DID/private key QR first."
        case .invalidPrivateKey:
            return "The private key format is invalid for ES256 signing. Supported formats: raw 32-byte key (base64/base64url/hex), PEM/DER P-256 key, or JWK with d field."
        case .invalidServiceURL:
            return "The login QR does not provide a usable callback URL. If callback is a relative path, import identity with serviceBaseURL or include serviceBaseURL in the login QR."
        case let .networkError(statusCode, message):
            return "Request failed (\(statusCode)): \(message)"
        }
    }
}
