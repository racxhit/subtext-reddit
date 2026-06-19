// ContentView.swift
// Main window UI — URL input, download button, batch mode, status feedback.
// Designed to feel like a native macOS utility.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var urlText: String = ""
    @State private var status: StatusMessage = .idle
    @State private var isExtracting: Bool = false
    @State private var batchProgress: (current: Int, total: Int)? = nil
    @State private var showBatchOptions: Bool = false

    enum StatusMessage: Equatable {
        case idle
        case working(String)
        case success(String)
        case error(String)
    }

    /// Detect single vs batch based on number of non-empty lines.
    private var parsedURLs: [String] {
        urlText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var isBatch: Bool { parsedURLs.count > 1 }
    private var urlCount: Int { parsedURLs.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.bottom, 16)

            // URL input area (multi-line)
            inputSection
                .padding(.bottom, 12)

            // Batch options (only visible when multiple URLs detected)
            if showBatchOptions {
                batchOptionsSection
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Download button (below input)
            downloadButton
                .padding(.bottom, 14)

            // Status area
            statusSection

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: urlText) { _ in
            let shouldShow = parsedURLs.count > 1
            if shouldShow != showBatchOptions {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBatchOptions = shouldShow
                }
            }
        }
    }

    // MARK: – Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 28))
                .foregroundStyle(.tint)

            Text("SubText")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Text("Paste Reddit URLs — one per line for batch extraction")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: – Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // URL count badge
            HStack {
                if urlCount > 0 {
                    Text("\(urlCount) URL\(urlCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isBatch ? Color.orange.opacity(0.15) : Color.accentColor.opacity(0.15))
                        .foregroundStyle(isBatch ? .orange : .accentColor)
                        .clipShape(Capsule())
                }
                Spacer()
                if !urlText.isEmpty {
                    Button {
                        urlText = ""
                        status = .idle
                        batchProgress = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all")
                }
            }

            // Multi-line text editor for URLs
            TextEditor(text: $urlText)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 60, maxHeight: 120)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if urlText.isEmpty {
                        Text("Paste a Reddit URL, or multiple URLs (one per line)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.blue.opacity(0.45))
                            .padding(.leading, 14)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .disabled(isExtracting)
        }
    }

    // MARK: – Batch options

    private var batchOptionsSection: some View {
        HStack(spacing: 12) {
            Text("Batch output:")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: $appState.batchOutputMode) {
                ForEach(BatchOutputMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: – Download button

    private var downloadButton: some View {
        Button(action: startExtraction) {
            HStack(spacing: 8) {
                if isExtracting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 14, height: 14)
                    Text("Extracting…")
                } else {
                    Image(systemName: isBatch ? "arrow.down.doc.fill" : "arrow.down.circle.fill")
                    Text(isBatch ? "Download All (\(urlCount))" : "Download")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 18)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(parsedURLs.isEmpty || isExtracting)
        .keyboardShortcut(.return, modifiers: .command)
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
                        .font(.callout)
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
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        let lines = msg.components(separatedBy: "\n")
                        // First line: primary error
                        Text(lines.first ?? msg)
                            .font(.callout)
                            .foregroundStyle(.primary)
                        // Remaining lines: secondary detail (e.g. expected URL format)
                        if lines.count > 1 {
                            ForEach(Array(lines.dropFirst().enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: status)
        .multilineTextAlignment(.center)
    }

    // MARK: – Extraction

    private func startExtraction() {
        let urls = parsedURLs
        guard !urls.isEmpty else { return }

        isExtracting = true
        batchProgress = nil

        if urls.count == 1 {
            // Single URL mode — same as before.
            status = .working("Fetching post data…")
            Task {
                do {
                    let fileURL = try await extractRedditPost(
                        urlString: urls[0],
                        cookie: appState.cookieString,
                        userAgent: appState.userAgent,
                        saveFolder: appState.saveFolder
                    )
                    await MainActor.run {
                        status = .success("Saved: \(fileURL.lastPathComponent)")
                        urlText = ""
                        isExtracting = false
                        batchProgress = nil
                    }
                } catch {
                    await MainActor.run {
                        status = .error(error.localizedDescription)
                        isExtracting = false
                        batchProgress = nil
                    }
                }
            }
        } else {
            // Batch mode.
            status = .working("Starting batch extraction…")
            Task {
                do {
                    let result = try await extractBatch(
                        urls: urls,
                        cookie: appState.cookieString,
                        userAgent: appState.userAgent,
                        saveFolder: appState.saveFolder,
                        mode: appState.batchOutputMode,
                        delaySeconds: 2.5,
                        onProgress: { current, total, message in
                            Task { @MainActor in
                                batchProgress = (current, total)
                                status = .working(message)
                            }
                        }
                    )
                    await MainActor.run {
                        let name = result.outputURL.lastPathComponent
                        if result.failed == 0 {
                            // All succeeded — clean green.
                            status = .success("All \(result.succeeded) saved → \(name)")
                        } else if result.succeeded > 0 {
                            // Partial — warn but still clear the field.
                            status = .error("Done: \(result.succeeded) saved, \(result.failed) failed → \(name)")
                        } else {
                            // All failed.
                            status = .error("All \(result.failed) failed. Check files in \(name)")
                        }
                        urlText = ""
                        isExtracting = false
                        batchProgress = nil
                    }
                } catch {
                    await MainActor.run {
                        status = .error(error.localizedDescription)
                        isExtracting = false
                        batchProgress = nil
                    }
                }
            }
        }
    }
}
