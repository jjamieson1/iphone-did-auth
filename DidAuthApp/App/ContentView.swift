import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var scannerMode: ScannerMode?
    @State private var showStatusPopup = false
    @State private var pendingDeepLinkChallenge: PendingDeepLinkChallenge?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Identity") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.installedDID ?? "No DID imported")
                            .font(.callout)
                            .foregroundStyle(viewModel.installedDID == nil ? .secondary : .primary)

                        Button("Scan DID/Private Key QR") {
                            scannerMode = .importIdentity
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Login") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Scan Login Challenge QR") {
                            scannerMode = .loginChallenge
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.installedDID == nil || viewModel.isBusy)

                        if viewModel.isBusy {
                            ProgressView("Sending challenge response...")
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Service") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("https://your-did-auth-service.example.com", text: $viewModel.serviceBaseURLInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 10) {
                            Button("Save Service URL") {
                                viewModel.saveServiceBaseURL()
                            }
                            .buttonStyle(.bordered)

                            Button("Clear") {
                                viewModel.clearServiceBaseURL()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Text("Latest status")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("View") {
                        showStatusPopup = true
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("DID Auth")
            .onReceive(viewModel.$statusMessage.dropFirst()) { _ in
                showStatusPopup = true
            }
            .sheet(item: $scannerMode) { mode in
                ScannerSheet(mode: mode, viewModel: viewModel)
            }
            .sheet(isPresented: $showStatusPopup) {
                StatusPopupView(message: viewModel.statusMessage)
            }
            .sheet(item: $pendingDeepLinkChallenge) { pending in
                DeepLinkChallengeConfirmView(
                    pending: pending,
                    viewModel: viewModel,
                    onClose: { pendingDeepLinkChallenge = nil }
                )
            }
            .onOpenURL { url in
                do {
                    let payload = try viewModel.parseLoginChallenge(from: url.absoluteString)
                    pendingDeepLinkChallenge = PendingDeepLinkChallenge(sourceURL: url.absoluteString, payload: payload)
                } catch {
                    viewModel.statusMessage = "Failed to parse deep link challenge: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct PendingDeepLinkChallenge: Identifiable {
    let id = UUID()
    let sourceURL: String
    let payload: LoginChallengePayload
}

private struct DeepLinkChallengeConfirmView: View {
    let pending: PendingDeepLinkChallenge
    @ObservedObject var viewModel: AuthViewModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("Challenge") {
                        VStack(alignment: .leading, spacing: 8) {
                            KeyValueRow(title: "challenge_id", value: pending.payload.challengeId)
                            KeyValueRow(title: "challenge/nonce", value: pending.payload.challenge)
                            KeyValueRow(title: "callback", value: pending.payload.callbackURL ?? "(none)")
                            KeyValueRow(title: "serviceBaseURL", value: pending.payload.serviceBaseURL ?? "(none)")
                            KeyValueRow(title: "algorithm", value: pending.payload.signatureAlgorithm ?? "(auto)")
                        }
                    }

                    GroupBox("Source") {
                        Text(pending.sourceURL)
                            .font(.callout)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("Confirm Login")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onClose()
                    }
                    .buttonStyle(.bordered)

                    Button(viewModel.isBusy ? "Sending..." : "Confirm & Send") {
                        Task {
                            await viewModel.submitLoginChallenge(payload: pending.payload)
                            onClose()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBusy)
                }
                .padding()
                .background(.thinMaterial)
            }
        }
        .presentationDetents([.large])
    }
}

private struct KeyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatusPopupView: View {
    let message: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(message)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(copied ? "Copied" : "Copy") {
                        UIPasteboard.general.string = message
                        copied = true
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ScannerSheet: View {
    let mode: ScannerMode
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CameraQRScannerView(
                onCodeScanned: { value in
                    switch mode {
                    case .importIdentity:
                        viewModel.importIdentity(from: value)
                        dismiss()
                    case .loginChallenge:
                        Task {
                            await viewModel.submitLoginChallenge(from: value)
                            dismiss()
                        }
                    }
                },
                onError: { error in
                    viewModel.statusMessage = error.localizedDescription
                    dismiss()
                }
            )
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

enum ScannerMode: String, Identifiable {
    case importIdentity
    case loginChallenge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .importIdentity:
            return "Import Identity"
        case .loginChallenge:
            return "Scan Login"
        }
    }
}
