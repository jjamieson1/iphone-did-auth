import Foundation

enum AuthAppError: LocalizedError {
    case invalidQRPayload
    case cameraNotAuthorized
    case missingIdentity
    case invalidPrivateKey
    case invalidServiceURL
    case networkError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidQRPayload:
            return "The QR code does not contain a valid DID auth payload."
        case .cameraNotAuthorized:
            return "Camera access is required to scan QR codes."
        case .missingIdentity:
            return "No DID identity is installed yet. Import your DID/private key QR first."
        case .invalidPrivateKey:
            return "The private key format is invalid for ES256 signing."
        case .invalidServiceURL:
            return "The login QR does not provide a valid callback URL."
        case let .networkError(statusCode, message):
            return "Request failed (\(statusCode)): \(message)"
        }
    }
}
