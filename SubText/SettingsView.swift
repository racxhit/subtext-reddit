// SettingsView.swift
// Native macOS Settings window (⌘,).
// Lets the user configure: cookie string, User-Agent, and save folder.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .environmentObject(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ConnectionSettingsTab()
                .environmentObject(appState)
                .tabItem {
                    Label("Connection", systemImage: "network")
                }
        }
        .frame(width: 520, height: 340)
    }
}

// MARK: – General tab (save folder)

struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var folderLabel: String = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("Save Location") {
                    HStack {
                        Text(displayPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose…") { pickFolder() }
                        
                        if !appState.saveFolderPath.isEmpty {
                            Button("Reset") {
                                appState.saveFolderPath = ""
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("File Output")
            } footer: {
                Text("Extracted .txt files will be saved to this folder. Defaults to Desktop.")
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var displayPath: String {
        if appState.saveFolderPath.isEmpty {
            return "~/Desktop (default)"
        }
        return (appState.saveFolderPath as NSString).abbreviatingWithTildeInPath
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose where extracted files should be saved"

        if panel.runModal() == .OK, let url = panel.url {
            appState.saveFolderPath = url.path
        }
    }
}

// MARK: – Connection tab (cookie + user-agent)

struct ConnectionSettingsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                LabeledContent("Cookie") {
                    TextEditor(text: $appState.cookieString)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 60)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
            } header: {
                Text("Reddit Cookie")
            } footer: {
                Text("Paste your Reddit cookie string here if Reddit starts blocking requests. You can get it from your browser's dev tools → Network tab → copy the Cookie header value.")
                    .foregroundStyle(.tertiary)
            }

            Section {
                LabeledContent("User-Agent") {
                    TextEditor(text: $appState.userAgent)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 60)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
                
                HStack {
                    Spacer()
                    Button("Reset to Default") {
                        appState.resetUserAgent()
                    }
                    .controlSize(.small)
                }
            } header: {
                Text("User-Agent Header")
            } footer: {
                Text("The User-Agent string sent to Reddit. Change this if requests are being blocked. The default mimics Chrome on macOS.")
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
