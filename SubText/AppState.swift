// AppState.swift
// Shared observable state — holds user settings with UserDefaults persistence.

import SwiftUI

/// Batch output mode: how multi-URL extractions are saved.
enum BatchOutputMode: String, CaseIterable, Identifiable {
    case separateFiles = "separateFiles"
    case singleFile = "singleFile"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .separateFiles: return "Separate files in folder"
        case .singleFile: return "Single combined file"
        }
    }

    var icon: String {
        switch self {
        case .separateFiles: return "folder.badge.plus"
        case .singleFile: return "doc.text"
        }
    }
}

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
    @AppStorage("batchOutputMode") var batchOutputMode: BatchOutputMode = .separateFiles

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
