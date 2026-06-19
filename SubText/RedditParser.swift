// RedditParser.swift
// Core logic: URL validation, fetching, JSON parsing, comment-tree recursion,
// structured text formatting, and file output.
//
// Zero dependencies beyond Foundation — no Reddit API keys needed.

import Foundation

// MARK: – Data models

struct RedditPost {
    let title: String
    let body: String
}

struct RedditComment {
    let id: String
    let depth: Int
    let score: Int
    let author: String
    let body: String
    let replies: [RedditComment]
}

/// Result of a batch extraction — tells the UI how many succeeded/failed.
struct BatchResult {
    let outputURL: URL
    let succeeded: Int
    let failed: Int
    var total: Int { succeeded + failed }
}

// MARK: – Errors

enum ExtractorError: LocalizedError {
    case invalidURL
    case notReddit
    case networkError(String)
    case httpError(Int)
    case invalidJSON
    case emptyPost
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL. Please enter a valid Reddit post link."
        case .notReddit:
            return "This doesn't look like a Reddit post URL.\nExpected: https://www.reddit.com/r/<sub>/comments/<id>/..."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .httpError(let code):
            switch code {
            case 404: return "Post not found (404). Check the URL."
            case 403: return "Access denied (403). Your Reddit cookie may be missing or expired.\nCheck Settings (⌘,) to update it."
            case 429: return "Rate-limited by Reddit. Wait a moment and retry."
            default:  return "Reddit returned HTTP \(code)."
            }
        case .invalidJSON:
            return "Reddit returned data we couldn't parse."
        case .emptyPost:
            return "The post appears to be empty or deleted."
        case .parseError(let msg):
            return "Parse error: \(msg)"
        }
    }
}

// MARK: – Public API (single post)

/// End-to-end extraction: validate → fetch → parse → format → save.
/// Returns the file URL of the saved .txt file.
func extractRedditPost(
    urlString: String,
    cookie: String,
    userAgent: String,
    saveFolder: URL
) async throws -> URL {
    let jsonURL = try validateAndNormalizeURL(urlString)
    let postID = extractPostID(from: urlString)
    let data = try await fetchJSON(from: jsonURL, cookie: cookie, userAgent: userAgent)
    let (post, comments) = try parseResponse(data)
    let formatted = formatOutput(post: post, comments: comments)
    let fileURL = try saveToFile(content: formatted, title: post.title, folder: saveFolder)
    return fileURL
}

// MARK: – Public API (batch extraction)

/// Batch extraction with a delay between requests.
/// Calls `onProgress` after each URL is processed.
/// Returns a BatchResult with the output path and success/failure counts.
func extractBatch(
    urls: [String],
    cookie: String,
    userAgent: String,
    saveFolder: URL,
    mode: BatchOutputMode,
    delaySeconds: Double = 2.5,
    onProgress: @escaping (Int, Int, String) -> Void  // (current, total, status)
) async throws -> BatchResult {
    var failedCount = 0

    // Create a timestamped batch folder name.
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let timestamp = dateFormatter.string(from: Date())
    let batchFolderName = "SubText_Batch_\(timestamp)"

    switch mode {
    case .separateFiles:
        // Create the batch folder.
        let batchFolder = saveFolder.appendingPathComponent(batchFolderName)
        try FileManager.default.createDirectory(at: batchFolder, withIntermediateDirectories: true)

        for (index, urlString) in urls.enumerated() {
            let num = index + 1
            onProgress(num, urls.count, "Extracting \(num)/\(urls.count)…")

            do {
                let jsonURL = try validateAndNormalizeURL(urlString)
                let postID = extractPostID(from: urlString)
                let data = try await fetchJSON(from: jsonURL, cookie: cookie, userAgent: userAgent)
                let (post, comments) = try parseResponse(data)
                let formatted = formatOutput(post: post, comments: comments)

                // Name: 01_postID_Title.txt
                let prefix = String(format: "%02d", num)
                let safeName = sanitizeFilename(post.title, maxLength: 60)
                let filename = "\(prefix)_\(postID)_\(safeName).txt"
                let fileURL = batchFolder.appendingPathComponent(filename)

                try formatted.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                failedCount += 1
                // Write an error marker file so the user knows which URL failed.
                let prefix = String(format: "%02d", num)
                let postID = extractPostID(from: urlString)
                let errorFile = batchFolder.appendingPathComponent("\(prefix)_\(postID)_ERROR.txt")
                let errorContent = "Failed to extract: \(urlString)\nError: \(error.localizedDescription)\n"
                try? errorContent.write(to: errorFile, atomically: true, encoding: .utf8)
            }

            // Wait between requests (skip delay after the last one).
            if index < urls.count - 1 {
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }

        return BatchResult(outputURL: batchFolder, succeeded: urls.count - failedCount, failed: failedCount)

    case .singleFile:
        // Collect all formatted outputs into one big file.
        var allSections: [String] = []
        let separator = "\n\n" + String(repeating: "═", count: 80) + "\n\n"

        for (index, urlString) in urls.enumerated() {
            let num = index + 1
            onProgress(num, urls.count, "Extracting \(num)/\(urls.count)…")

            do {
                let jsonURL = try validateAndNormalizeURL(urlString)
                let data = try await fetchJSON(from: jsonURL, cookie: cookie, userAgent: userAgent)
                let (post, comments) = try parseResponse(data)
                let formatted = formatOutput(post: post, comments: comments)

                let header = "[ Thread \(num)/\(urls.count) ]"
                allSections.append(header + "\n\n" + formatted)
            } catch {
                failedCount += 1
                let header = "[ Thread \(num)/\(urls.count) — ERROR ]"
                let errorMsg = "Failed to extract: \(urlString)\nError: \(error.localizedDescription)"
                allSections.append(header + "\n\n" + errorMsg)
            }

            // Wait between requests (skip delay after the last one).
            if index < urls.count - 1 {
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }

        let combined = allSections.joined(separator: separator)
        let filename = "\(batchFolderName).txt"
        let fileURL = saveFolder.appendingPathComponent(filename)
        try combined.write(to: fileURL, atomically: true, encoding: .utf8)

        return BatchResult(outputURL: fileURL, succeeded: urls.count - failedCount, failed: failedCount)
    }
}

// MARK: – URL helpers

private func validateAndNormalizeURL(_ raw: String) throws -> URL {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw ExtractorError.invalidURL }

    // Must be a Reddit post URL
    let pattern = #"https?://([a-zA-Z0-9-]+\.)?reddit\.com/r/\w+/comments/\w+"#
    guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
        throw ExtractorError.notReddit
    }

    // Strip query params, ensure .json suffix
    var clean = trimmed.components(separatedBy: "?").first!
    while clean.hasSuffix("/") { clean.removeLast() }
    if !clean.hasSuffix(".json") { clean += ".json" }

    guard let url = URL(string: clean) else { throw ExtractorError.invalidURL }
    return url
}

/// Extract the Reddit post ID from a URL (the part after /comments/).
func extractPostID(from urlString: String) -> String {
    // URL format: .../comments/<postID>/...
    let pattern = #"/comments/(\w+)"#
    if let range = urlString.range(of: pattern, options: .regularExpression) {
        let match = urlString[range]
        // Drop "/comments/" prefix to get the ID
        let id = match.dropFirst("/comments/".count)
        return String(id)
    }
    return "unknown"
}

// MARK: – Fetching

private func fetchJSON(from url: URL, cookie: String, userAgent: String) async throws -> Data {
    var request = URLRequest(url: url, timeoutInterval: 30)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    if !cookie.isEmpty {
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
    }
    // Ask Reddit for JSON explicitly
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response): (Data, URLResponse)
    do {
        (data, response) = try await URLSession.shared.data(for: request)
    } catch {
        throw ExtractorError.networkError(error.localizedDescription)
    }

    if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
        throw ExtractorError.httpError(httpResp.statusCode)
    }

    return data
}

// MARK: – JSON parsing

private func parseResponse(_ data: Data) throws -> (RedditPost, [RedditComment]) {
    // Reddit returns an array of two listings: [postListing, commentsListing]
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
          root.count >= 2 else {
        throw ExtractorError.invalidJSON
    }

    // --- Post ---
    guard let postChildren = (root[0]["data"] as? [String: Any])?["children"] as? [[String: Any]],
          let postData = postChildren.first?["data"] as? [String: Any] else {
        throw ExtractorError.parseError("Could not locate post data.")
    }

    let title = postData["title"] as? String ?? "[No title]"
    let selftext = (postData["selftext"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let body = selftext.isEmpty ? "[No body text]" : selftext

    if title == "[No title]" && body == "[No body text]" {
        throw ExtractorError.emptyPost
    }

    let post = RedditPost(title: title, body: body)

    // --- Comments ---
    let commentChildren = (root[1]["data"] as? [String: Any])?["children"] as? [[String: Any]] ?? []
    let comments = parseComments(children: commentChildren, depth: 0)

    return (post, comments)
}

/// Recursively parse the comment tree.
/// Skips "more" nodes (load-more stubs).
/// Preserves deleted/removed comments with placeholder text.
private func parseComments(children: [[String: Any]], depth: Int) -> [RedditComment] {
    var results: [RedditComment] = []

    for child in children {
        let kind = child["kind"] as? String ?? ""

        // Skip "load more comments" stubs — they contain no useful text.
        if kind == "more" { continue }
        // Only process actual comments (t1).
        guard kind == "t1" else { continue }

        guard let cData = child["data"] as? [String: Any] else { continue }

        let id = cData["id"] as? String ?? "unknown"
        let score = cData["score"] as? Int ?? 0
        let author = cData["author"] as? String ?? "[deleted]"
        var body = (cData["body"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // Gracefully handle deleted / removed comments.
        if author == "[deleted]" && body.isEmpty { body = "[deleted]" }
        if body == "[removed]" || body.isEmpty { body = body.isEmpty ? "[deleted]" : body }

        // Recurse into replies.
        var nested: [RedditComment] = []
        if let repliesDict = cData["replies"] as? [String: Any],
           let repliesData = repliesDict["data"] as? [String: Any],
           let replyChildren = repliesData["children"] as? [[String: Any]] {
            nested = parseComments(children: replyChildren, depth: depth + 1)
        }

        results.append(RedditComment(
            id: id, depth: depth, score: score,
            author: author, body: body, replies: nested
        ))
    }

    return results
}

// MARK: – Structured text formatting (LLM-optimized)

private let indentUnit = "    " // 4 spaces per depth level

private func formatOutput(post: RedditPost, comments: [RedditComment]) -> String {
    var lines: [String] = []

    lines.append("POST TITLE: \(post.title)")
    lines.append("")
    lines.append("POST BODY:")
    lines.append("")
    lines.append(post.body)
    lines.append("")
    lines.append("COMMENTS:")
    lines.append("")

    let flat = flattenComments(comments)
    for c in flat {
        lines.append(formatComment(c))
        lines.append("") // blank line between comments
    }

    return lines.joined(separator: "\n")
}

private func formatComment(_ c: RedditComment) -> String {
    let indent = String(repeating: indentUnit, count: c.depth)
    var lines: [String] = []

    lines.append("\(indent)[Comment id=\(c.id) depth=\(c.depth) score=\(c.score)]")
    lines.append("\(indent)Author: \(c.author)")

    let bodyLines = c.body.components(separatedBy: .newlines)
    if bodyLines.count <= 1 {
        lines.append("\(indent)Text: \(c.body)")
    } else {
        lines.append("\(indent)Text:")
        for bl in bodyLines {
            lines.append("\(indent)\(bl)")
        }
    }

    return lines.joined(separator: "\n")
}

/// Flatten the nested tree into depth-first order for linear iteration.
private func flattenComments(_ comments: [RedditComment]) -> [RedditComment] {
    var flat: [RedditComment] = []
    for c in comments {
        flat.append(c)
        if !c.replies.isEmpty {
            flat.append(contentsOf: flattenComments(c.replies))
        }
    }
    return flat
}

// MARK: – File output

func sanitizeFilename(_ title: String, maxLength: Int = 80) -> String {
    // Remove characters invalid in filenames.
    var name = title
    let invalid = CharacterSet(charactersIn: "\\/*?:\"<>|")
    name = name.unicodeScalars.filter { !invalid.contains($0) }.map(String.init).joined()
    // Collapse whitespace.
    name = name.components(separatedBy: .whitespaces)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    // Truncate.
    if name.count > maxLength {
        name = String(name.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
    }
    return name.isEmpty ? "reddit_post" : name
}

private func saveToFile(content: String, title: String, folder: URL) throws -> URL {
    let baseName = sanitizeFilename(title)
    var fileURL = folder.appendingPathComponent("\(baseName).txt")

    // Avoid overwriting — append a number if the file exists.
    var counter = 1
    while FileManager.default.fileExists(atPath: fileURL.path) {
        fileURL = folder.appendingPathComponent("\(baseName) (\(counter)).txt")
        counter += 1
    }

    do {
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    } catch {
        throw ExtractorError.networkError("Could not write file: \(error.localizedDescription)")
    }

    return fileURL
}
