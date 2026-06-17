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
                .frame(minWidth: 500, minHeight: 320, maxHeight: 400)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 350)

        // Settings window (⌘,)
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
