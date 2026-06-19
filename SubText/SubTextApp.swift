// SubTextApp.swift
// Main app entry point — defines the window, menu bar, and settings scene.

import SwiftUI

@main
struct SubTextApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Main utility window
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 520, minHeight: 400)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 540, height: 480)

        // Settings window (⌘,)
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
