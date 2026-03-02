import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var scannerMode: ScannerMode?
    @State private var showStatusPopup = false

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
