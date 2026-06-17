// AppState.swift
// Shared observable state — holds user settings with UserDefaults persistence.

import SwiftUI

class AppState: ObservableObject {
    // Default realistic Chrome User-Agent
    private static let defaultUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
        "AppleWebKit/537.36 (KHTML, like Gecko) " +
        "Chrome/125.0.0.0 Safari/537.36"

    // MARK: – Persisted settings

    @AppStorage("cookieString") var cookieString: String = ""
    @AppStorage("userAgent") var userAgent: String = AppState.defaultUserAgent
    @AppStorage("saveFolder") var saveFolderPath: String = ""

    /// Resolved save folder — falls back to Desktop if nothing is set.
    var saveFolder: URL {
        if !saveFolderPath.isEmpty {
            return URL(fileURLWithPath: saveFolderPath)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    /// Reset User-Agent back to default.
    func resetUserAgent() {
        userAgent = AppState.defaultUserAgent
    }
}
