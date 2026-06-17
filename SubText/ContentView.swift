// ContentView.swift
// Main window UI — URL input, download button, status feedback.
// Designed to feel like a native macOS utility.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var urlText: String = ""
    @State private var status: StatusMessage = .idle
    @State private var isExtracting: Bool = false

    enum StatusMessage: Equatable {
        case idle
        case working(String)
        case success(String)
        case error(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.bottom, 20)

            // URL input + button
            inputSection
                .padding(.bottom, 16)

            // Status area
            statusSection

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: – Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tint)

            Text("SubText")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("Paste a Reddit post URL to extract it as structured text")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: – Input

    private var inputSection: some View {
        HStack(spacing: 10) {
            TextField("https://www.reddit.com/r/.../comments/...", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .onSubmit { startExtraction() }
                .disabled(isExtracting)

            Button(action: startExtraction) {
                Group {
                    if isExtracting {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    } else {
                        Label("Download", systemImage: "arrow.down.circle.fill")
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isExtracting)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }

    // MARK: – Status

    private var statusSection: some View {
        Group {
            switch status {
            case .idle:
                EmptyView()

            case .working(let msg):
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(msg)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)

            case .success(let msg):
                Label {
                    Text(msg)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .transition(.opacity)

            case .error(let msg):
                Label {
                    Text(msg)
                        .font(.callout)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: status)
        .multilineTextAlignment(.center)
    }

    // MARK: – Extraction

    private func startExtraction() {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        isExtracting = true
        status = .working("Fetching post data…")

        Task {
            do {
                let fileURL = try await extractRedditPost(
                    urlString: url,
                    cookie: appState.cookieString,
                    userAgent: appState.userAgent,
                    saveFolder: appState.saveFolder
                )

                await MainActor.run {
                    status = .success("Saved to: \(fileURL.lastPathComponent)")
                    // Auto-clear the URL field so the user can immediately paste another
                    urlText = ""
                    isExtracting = false
                }
            } catch {
                await MainActor.run {
                    status = .error(error.localizedDescription)
                    isExtracting = false
                }
            }
        }
    }
}
