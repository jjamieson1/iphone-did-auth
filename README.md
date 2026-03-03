# iPhone DID Auth App (MVP)

[![iOS Build](https://github.com/jjamieson1/iphone-did-auth/actions/workflows/ios-build.yml/badge.svg)](https://github.com/jjamieson1/iphone-did-auth/actions/workflows/ios-build.yml)

This workspace contains a SwiftUI iPhone app implementation that:

1. Imports `did` + `privateKeyBase64` from an identity QR code.
2. Scans a login challenge QR code.
3. Signs the challenge with ES256 (`P-256`) and sends response back to your `did-auth-service`.

## 1) Open the included Xcode project

1. Open `DidAuthApp.xcodeproj` in Xcode.
2. Select the `DidAuthApp` scheme and an iPhone simulator/device.
3. In **Signing & Capabilities**, set your Team and (if needed) change bundle identifier (`com.example.DidAuthApp`).
4. Build and run.

Camera permission is already set in `DidAuthApp/Resources/Info.plist`.

## 2) Identity Import QR format

Supported as either:

- Raw JSON text in QR, or
- URL containing `payload=` query param with base64url/base64/percent-encoded JSON.

JSON shape:

```json
{
  "did": "did:key:z6Mk...",
  "privateKeyBase64": "<BASE64_32_BYTE_P256_PRIVATE_KEY>",
  "serviceBaseURL": "https://your-did-auth-service.example.com"
}
```

## 3) Login Challenge QR format

Supported the same way as above.

JSON shape:

```json
{
  "challengeId": "abc123",
  "challenge": "random-string-or-nonce",
  "callbackURL": "https://your-did-auth-service.example.com/api/did-auth/response",
  "serviceBaseURL": "https://your-did-auth-service.example.com",
  "responsePath": "/api/did-auth/response"
}
```

Endpoint resolution logic:

- Use `callbackURL` if present.
- Else use `serviceBaseURL` (from login QR, or imported identity) + `responsePath` (default `/api/did-auth/response`).

## 4) Challenge Response POST body

The app sends:

```json
{
  "did": "did:key:z6Mk...",
  "challengeId": "abc123",
  "challenge": "random-string-or-nonce",
  "signature": "<BASE64_DER_ECDSA_SIGNATURE>",
  "algorithm": "ES256"
}
```

## 5) Important integration notes

- `privateKeyBase64` is expected to be raw P-256 private key bytes compatible with `CryptoKit.P256.Signing.PrivateKey(rawRepresentation:)`.
- Signature is DER-encoded ECDSA, then base64 encoded.
- If your backend expects JWS compact, JOSE-style R|S signature, or different field names, update:
  - `DidAuthApp/Services/Crypto/CryptoService.swift`
  - `DidAuthApp/Services/Network/AuthServiceClient.swift`

## 6) Files in this workspace

- `DidAuthApp/App/DidAuthApp.swift`
- `DidAuthApp/App/ContentView.swift`
- `DidAuthApp/ViewModels/AuthViewModel.swift`
- `DidAuthApp/Services/QRScanner/CameraQRScannerView.swift`
- `DidAuthApp/Services/Crypto/KeychainService.swift`
- `DidAuthApp/Services/Crypto/CryptoService.swift`
- `DidAuthApp/Services/Network/AuthServiceClient.swift`
- `DidAuthApp/Models/QRPayloads.swift`
- `DidAuthApp/Models/AuthAppError.swift`

## 7) CI build workflow

- GitHub Actions workflow: `.github/workflows/ios-build.yml`
- Runs on every push and pull request.
- Builds `DidAuthApp.xcodeproj` with scheme `DidAuthApp` for iOS Simulator using `CODE_SIGNING_ALLOWED=NO`.

## 8) CI status badge

Badge is configured for this repo:

```markdown
[![iOS Build](https://github.com/jjamieson1/iphone-did-auth/actions/workflows/ios-build.yml/badge.svg)](https://github.com/jjamieson1/iphone-did-auth/actions/workflows/ios-build.yml)
```

## 9) Release checklist (TestFlight / App Store)

1. In Xcode, set a unique bundle identifier and your Apple Developer Team.
2. In target settings, update `Version` and `Build` for each release.
3. Confirm `NSCameraUsageDescription` text is accurate for production.
4. Validate login flow against your production `did-auth-service` endpoint.
5. Archive in Xcode (**Product → Archive**) and upload to App Store Connect.
6. In App Store Connect, complete app metadata, privacy details, and screenshots.
7. Distribute first to TestFlight, then submit for App Store review.

## 10) Deep link challenge format

The app registers URL scheme `didauth://` and supports receiving a challenge by deep link.

Example deep link:

```text
didauth://login?challenge_id=chal_4MGbFvw4T_s&nonce=MnrWDpe5coQ3pP5FNJFm3ext1m1LD27oGIVztvQ7xHY&callback=%2Fapi%2Fauth%2Frespond&did=did%3Aexample%3Ademo
```

You can also pass JSON payload as `payload=` (base64url/base64/percent-encoded), same as QR support.

When opened from deep link, the app shows a confirmation screen with challenge details and only sends the response after user taps **Confirm & Send**.

Simulator test command:

```bash
xcrun simctl openurl booted "didauth://login?challenge_id=chal_test&nonce=nonce_test&callback=%2Fapi%2Fauth%2Frespond"
```

## 11) App icon generation

Use one 1024x1024 PNG as the source icon and generate all iOS icon sizes:

```bash
./scripts/generate_app_icons.sh /absolute/path/to/master-icon-1024.png
```

This writes all required icon files into:

- `DidAuthApp/Resources/Assets.xcassets/AppIcon.appiconset`

The project is already configured to use the `AppIcon` set for home screen icons.
